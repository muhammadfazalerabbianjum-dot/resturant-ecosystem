// FIX-B5 (QUEUE-3) — T-2 TWIN-2 parity matrix + T-5 fail-closed contract.
//
// ONE retry classifier (T-1): `NetworkRetry.isRetryable` is the single
// source of truth and `IsarSyncQueue.isPermanentFailure` is its delegating
// shim. This suite drives the 9-code matrix through BOTH entry points and
// pins the fail-closed laws (§0.7):
//   • a PERMANENT error is never retried (it must not burn budget),
//   • a TRANSIENT error is never dropped to the DLQ before kMaxRetries,
//   • an UNKNOWN error is transient but always BOUNDED by kMaxRetries.
//
// RED at write time: 5 of 9 rows DIVERGE (not-found, invalid-argument,
// unauthenticated, failed-precondition, already-exists — the queue retried
// them while NetworkRetry called them permanent). GREEN = 9/9 AGREE.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:isar_community/isar.dart';

import 'helpers/isar_native.dart';
import 'helpers/mock_firebase.dart';
import 'helpers/recording_logger.dart';

/// The 9 TWIN-2 codes (the exact row set from
/// `tool_audit/aud1/receipts/c3_parity_run.log`): the 6 permanent codes of
/// batch contract 1 plus 3 transient controls.
const kPermanentCodes = <String>[
  'permission-denied',
  'not-found',
  'invalid-argument',
  'unauthenticated',
  'failed-precondition',
  'already-exists',
];
const kTransientCodes = <String>[
  'unavailable',
  'deadline-exceeded',
  'internal',
];
const kMatrixCodes = <String>[...kPermanentCodes, ...kTransientCodes];

/// Per-code rationale for ALL 9 rows — Firebase/gRPC error-code semantics,
/// never "we picked a side". The classifier verdict for [code] MUST match
/// whether it sits in the permanent set below.
const kRationale = <String, String>{
  'permission-denied':
      'gRPC PERMISSION_DENIED — Firestore Security Rules rejection is '
      'deterministic; replaying the same write is denied again, so retrying '
      'only burns backoff and hammers the backend.',
  'not-found':
      'gRPC NOT_FOUND — the target document/function does not exist; a retry '
      'redraws the identical request against the identical absence.',
  'invalid-argument':
      'gRPC INVALID_ARGUMENT — a client bug in the payload; re-sending the '
      'same invalid request cannot become valid.',
  'unauthenticated':
      'gRPC UNAUTHENTICATED — expired/absent credentials; the fix is a '
      're-authentication flow, not a blind retry with the same token.',
  'failed-precondition':
      'gRPC FAILED_PRECONDITION — server-side state veto (e.g. promo '
      'exhausted, order already finalised); the state will not heal within '
      'the backoff window.',
  'already-exists':
      'gRPC ALREADY_EXISTS — conflicting create; replaying it collides with '
      'the same existing resource every time.',
  'unavailable':
      'gRPC UNAVAILABLE — transient infrastructure outage (depot, restart, '
      'flaky link); retrying with backoff is exactly right.',
  'deadline-exceeded':
      'gRPC DEADLINE_EXCEEDED — transport stall/timeout; the server may well '
      'complete the retry (Firestore writes are idempotent merge:set here).',
  'internal':
      'gRPC INTERNAL — server-side anomaly that is frequently transient; '
      'bounded retry is the safe default.',
};

/// Always-failing [QueueFirestoreWriter]: every set/delete throws [failure]
/// so the queue drives its real classification path.
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

FirebaseException _firestoreError(String code) => FirebaseException(
  plugin: 'cloud_firestore',
  code: code,
  message: 'b5 probe: $code',
);

void main() {
  setUpAll(ensureIsarCoreForTests);

  var instanceSeq = 0;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('b5_parity');
    instanceSeq++;
  });

  tearDown(() async {
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {}
  });

  /// A queue whose writer fails EVERY write with [failure], plus its open
  /// Isar handle and recording logger (same harness as sync_queue_test).
  Future<(IsarSyncQueue, Isar, RecordingLogger)> failingQueue(
    Object failure,
  ) async {
    final logger = RecordingLogger();
    final service = IsarService.forTesting(
      null,
      logger,
      'b5-parity-${instanceSeq++}',
      temp.path,
    );
    final isar = await service.db;
    final queue = IsarSyncQueue(
      service,
      logger,
      firestore: _AlwaysFailingWriter(failure),
    );
    return (queue, isar, logger);
  }

  group('T-2 — TWIN-2 parity matrix (both entry points, 9 rows)', () {
    test('every code classifies identically through BOTH entry points', () {
      final rows = <String>[];
      final diverge = <String>[];
      for (final code in kMatrixCodes) {
        final netPermanent = !NetworkRetry.isRetryable(_firestoreError(code));
        final callablePermanent = !NetworkRetry.isRetryable(
          TestFunctionsException(code),
        );
        final queuePermanent = IsarSyncQueue.isPermanentFailure(
          _firestoreError(code),
        );
        final agree =
            netPermanent == queuePermanent && netPermanent == callablePermanent;
        if (!agree) diverge.add(code);
        rows.add(
          '${code.padRight(20)} | NetworkRetry(fs) permanent=$netPermanent'
          ' | NetworkRetry(callable) permanent=$callablePermanent'
          ' | IsarSyncQueue permanent=$queuePermanent'
          ' | ${agree ? 'AGREE' : 'DIVERGE'}',
        );
      }
      // ignore: avoid_print
      print('=== TWIN-2 matrix (9 rows) ===\n${rows.join('\n')}');
      // ignore: avoid_print
      print('=== TWIN-2 divergent codes: ${diverge.join(', ')} ===');

      expect(
        diverge,
        isEmpty,
        reason:
            'TWIN-2 must be 9/9 AGREE through NetworkRetry.isRetryable and '
            'IsarSyncQueue.isPermanentFailure (FIX-B5 resolves the 5 '
            'historically divergent codes: ${diverge.join(', ')})',
      );
      expect(rows, hasLength(9));
    });

    test('the permanent set is exactly the 6 contract-1 codes — both entry '
        'points, both Firebase exception families', () {
      for (final code in kPermanentCodes) {
        expect(
          NetworkRetry.isRetryable(_firestoreError(code)),
          isFalse,
          reason: '$code: ${kRationale[code]}',
        );
        expect(
          NetworkRetry.isRetryable(TestFunctionsException(code)),
          isFalse,
          reason: '$code (callable family): ${kRationale[code]}',
        );
        expect(
          IsarSyncQueue.isPermanentFailure(_firestoreError(code)),
          isTrue,
          reason: 'queue shim must agree — $code: ${kRationale[code]}',
        );
      }
      for (final code in kTransientCodes) {
        expect(
          NetworkRetry.isRetryable(_firestoreError(code)),
          isTrue,
          reason: '$code: ${kRationale[code]}',
        );
        expect(
          NetworkRetry.isRetryable(TestFunctionsException(code)),
          isTrue,
          reason: '$code (callable family): ${kRationale[code]}',
        );
        expect(
          IsarSyncQueue.isPermanentFailure(_firestoreError(code)),
          isFalse,
          reason: 'queue shim must agree — $code: ${kRationale[code]}',
        );
      }
    });

    test('the rationale table covers all 9 matrix rows', () {
      expect(kRationale.keys.toSet(), kMatrixCodes.toSet());
      expect(kRationale.length, 9);
      for (final code in kMatrixCodes) {
        expect(kRationale[code], isNotEmpty, reason: '$code needs a rationale');
      }
    });
  });

  group('T-5 — fail-closed both directions (§0.7)', () {
    test('UNKNOWN error via NetworkRetry: retried but BOUNDED', () async {
      final delays = <Duration>[];
      final original = NetworkRetry.delay;
      addTearDown(() => NetworkRetry.delay = original);
      NetworkRetry.delay = (d) async => delays.add(d);

      var attempts = 0;
      await expectLater(
        NetworkRetry.withExponentialBackoff<int>(() async {
          attempts++;
          throw StateError('unknown-but-transient #$attempts');
        }),
        throwsA(isA<StateError>()),
        reason: 'the ORIGINAL unknown error surfaces after exhaustion',
      );

      expect(attempts, 4, reason: 'bounded: initial attempt + maxRetries(3)');
      expect(delays, const [
        Duration(milliseconds: 1000),
        Duration(milliseconds: 2000),
        Duration(milliseconds: 4000),
      ]);
    });

    test(
      'PERMANENT error via NetworkRetry: never consumes the budget',
      () async {
        final delays = <Duration>[];
        final original = NetworkRetry.delay;
        addTearDown(() => NetworkRetry.delay = original);
        NetworkRetry.delay = (d) async => delays.add(d);

        var attempts = 0;
        await expectLater(
          NetworkRetry.withExponentialBackoff<int>(() async {
            attempts++;
            throw _firestoreError('failed-precondition');
          }),
          throwsA(isA<FirebaseException>()),
        );

        expect(attempts, 1, reason: 'a permanent error rethrows at once');
        expect(delays, isEmpty, reason: 'zero backoff for a permanent error');
      },
    );

    test('PERMANENT errors via the queue: straight to DLQ at retryCount 0 '
        '(never a retry burn) — all 6 codes', () async {
      final stillRetrying = <String>[];
      for (final code in kPermanentCodes) {
        final (queue, isar, _) = await failingQueue(_firestoreError(code));
        await queue.enqueue('create', 'orders', {'id': 'perm-$code'});
        await queue.processQueue();

        final pending = await isar.isarPendingOperations.where().findAll();
        final dead = await isar.isarDeadLetters.where().findAll();
        if (pending.isNotEmpty || dead.length != 1) stillRetrying.add(code);
        if (dead.length == 1) {
          expect(
            dead.single.retryCount,
            0,
            reason: '$code must land at retryCount 0: ${kRationale[code]}',
          );
          expect(dead.single.lastError, contains(code));
        }
      }
      expect(
        stillRetrying,
        isEmpty,
        reason:
            'a permanent error must never be retried (budget burn) — these '
            'still consumed retries: ${stillRetrying.join(', ')}',
      );
    });

    test(
      'TRANSIENT error via the queue: never DLQ before kMaxRetries',
      () async {
        final (queue, isar, logger) = await failingQueue(
          _firestoreError('unavailable'),
        );
        await queue.enqueue('create', 'orders', {'id': 'transient-1'});
        await queue.processQueue();

        final pending = await isar.isarPendingOperations.where().findAll();
        expect(pending, hasLength(1), reason: 'stays pending for a retry');
        expect(pending.single.retryCount, 1);
        expect(
          await isar.isarDeadLetters.where().findAll(),
          isEmpty,
          reason: 'a transient error must NOT be dropped to the DLQ early',
        );
        expect(logger.errors, contains('SyncQueue_processOp'));
      },
    );

    test(
      'UNKNOWN error via the queue: retried, then BOUNDED by kMaxRetries',
      () async {
        final (queue, isar, _) = await failingQueue(
          const SocketException('unknown transport failure'),
        );
        await queue.enqueue('create', 'orders', {'id': 'unknown-1'});
        await queue.processQueue();

        var pending = await isar.isarPendingOperations.where().findAll();
        expect(
          pending,
          hasLength(1),
          reason: 'unknown => transient => retried',
        );
        expect(pending.single.retryCount, 1);
        expect(await isar.isarDeadLetters.where().findAll(), isEmpty);

        // Age the op to the budget boundary exactly as repeated drains would:
        // the next drain must DEAD-LETTER it — bounded, never infinite.
        await isar.writeTxn(() async {
          pending.single.retryCount = IsarSyncQueue.kMaxRetries;
          await isar.isarPendingOperations.put(pending.single);
        });
        await queue.processQueue();

        expect(
          await isar.isarPendingOperations.where().findAll(),
          isEmpty,
          reason: 'the budget bound consumed the op',
        );
        final dead = await isar.isarDeadLetters.where().findAll();
        expect(dead, hasLength(1));
        expect(dead.single.lastError, contains('Max retries exceeded'));
      },
    );
  });
}
