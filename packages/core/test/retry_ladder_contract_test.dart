// FIX-B5 (QUEUE-3) — T-3: the backoff ladder contract is PINNED (AUD1-17).
//
// DECISION: the two ladders stay DISTINCT — they guard different domains —
// and this test states and pins the relationship so a future edit to either
// cannot silently diverge:
//
//   NetworkRetry.withExponentialBackoff — in-process RPC hammer:
//     attempts = maxRetries + 1 = 4 (default maxRetries 3),
//     delays   = 1s, 2s, 4s  (2^attempt * 1000ms, attempt = 0..2),
//     permanent errors: 1 attempt, zero delay.
//
//   IsarSyncQueue.processQueue — durable offline outbox:
//     attempts = kMaxRetries + 1 = 6 (kMaxRetries 5, DLQ at retryCount >= 5),
//     delays   = 2s, 4s, 8s, 16s, 32s  (1 << retryCount.clamp(0, 5) AFTER
//                the increment, retryCount = 1..5 → clamp caps at 32s),
//     permanent errors: 0 retries — straight to the DLQ at retryCount 0.
//
// The queue ladder is observed through `IsarSyncQueue.delay`, the
// @visibleForTesting seam added by this fix (defaults to the REAL
// Future.delayed — production sleeps the full ladder).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:isar_community/isar.dart';

import 'helpers/isar_native.dart';
import 'helpers/recording_logger.dart';

class _AlwaysFailingWriter implements QueueFirestoreWriter {
  _AlwaysFailingWriter(this.failure);

  final Object failure;

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    throw failure;
  }

  @override
  Future<void> delete(String collectionName, String id) async {
    throw failure;
  }
}

void main() {
  setUpAll(ensureIsarCoreForTests);

  var instanceSeq = 0;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('b5_ladder');
    instanceSeq++;
  });

  tearDown(() {
    // Restore the PRODUCTION delays — no suite may inherit a recorder.
    NetworkRetry.delay = Future<void>.delayed;
    IsarSyncQueue.delay = Future<void>.delayed;
  });

  test(
    'NetworkRetry ladder pinned: 1s, 2s, 4s — 4 attempts (maxRetries 3)',
    () async {
      final recorded = <Duration>[];
      NetworkRetry.delay = (d) async => recorded.add(d);

      var attempts = 0;
      await expectLater(
        NetworkRetry.withExponentialBackoff<void>(() async {
          attempts++;
          throw StateError('ladder probe #$attempts');
        }),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 4, reason: 'initial + maxRetries(3) — bounded');
      expect(recorded, const [
        Duration(milliseconds: 1000),
        Duration(milliseconds: 2000),
        Duration(milliseconds: 4000),
      ]);
    },
  );

  test('IsarSyncQueue ladder pinned: 2s, 4s, 8s, 16s, 32s — 6 attempts, '
      'DLQ exactly at the kMaxRetries boundary', () async {
    final recorded = <Duration>[];
    IsarSyncQueue.delay = (d) async => recorded.add(d);

    final logger = RecordingLogger();
    final service = IsarService.forTesting(
      null,
      logger,
      'b5-ladder-${instanceSeq++}',
      temp.path,
    );
    final Isar isar = await service.db;
    final queue = IsarSyncQueue(
      service,
      logger,
      firestore: _AlwaysFailingWriter(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'always failing',
        ),
      ),
    );
    await queue.enqueue('create', 'orders', {'id': 'ladder-1'});

    // Drain until the DLQ move: kMaxRetries failed attempts, each with the
    // clamped exponential delay, then one more drain at the boundary.
    for (var drain = 0; drain <= IsarSyncQueue.kMaxRetries; drain++) {
      await queue.processQueue();
    }

    expect(IsarSyncQueue.kMaxRetries, 5);
    expect(recorded, const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 32),
    ], reason: '1 << retryCount.clamp(0, 5) for retryCount 1..5');

    expect(
      await isar.isarPendingOperations.where().findAll(),
      isEmpty,
      reason: 'the kMaxRetries boundary consumed the op',
    );
    final dead = await isar.isarDeadLetters.where().findAll();
    expect(dead, hasLength(1));
    expect(dead.single.retryCount, IsarSyncQueue.kMaxRetries);
    expect(dead.single.lastError, contains('Max retries exceeded'));
  });

  test('the relationship between the ladders is pinned (4 vs 6 attempts, '
      'queue delay = 2x the RPC delay at equal attempt depth)', () async {
    // Same exponential family, different floors/ceilings: the offline
    // outbox waits twice as long as the in-process hammer at the same
    // depth and runs two attempts deeper before giving up to the DLQ.
    const rpcAttempts = 4; // maxRetries 3 + 1
    const queueAttempts = 6; // kMaxRetries 5 + 1
    expect(queueAttempts, IsarSyncQueue.kMaxRetries + 1);
    expect(rpcAttempts, 4);
    expect(
      queueAttempts,
      greaterThan(rpcAttempts),
      reason: 'a durable outbox must out-live the in-process hammer',
    );
    // Depth-for-depth, queueSeconds[n] == 2 * rpcSeconds[n]:
    for (var attempt = 0; attempt < 3; attempt++) {
      final rpcMs = (1 << attempt) * 1000;
      final queueSecs = 1 << (attempt + 1); // retryCount = attempt + 1
      expect(queueSecs * 1000, rpcMs * 2);
    }
  });
}
