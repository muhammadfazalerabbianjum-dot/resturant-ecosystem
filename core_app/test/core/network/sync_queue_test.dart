import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:core/core.dart';

/// Helper to create an in-memory Isar instance for testing.
Future<Isar> createTestIsar() async {
  final dir = Directory.systemTemp.createTempSync('isar_sync_test_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  return isar;
}

/// A test double for LoggerService that captures logs in memory.
class TestLoggerService extends LoggerService {
  final List<String> errorMessages = [];
  final List<String> infoMessages = [];

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    errorMessages.add('$message: $error');
  }

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {
    infoMessages.add('$message: $context');
  }
}

/// A test double for IsarService that uses an in-memory Isar instance.
class TestIsarService extends IsarService {
  final Isar testIsar;

  TestIsarService(this.testIsar) : super.forTesting() {
    db = Future.value(testIsar);
  }
}

// ── QUEUE-1 test doubles (T-3) ─────────────────────────────────────────────
// The queue's Firestore write surface is constructor-injected as a
// [QueueFirestoreWriter] (W5.1, the repo's ChaosFirestore facade pattern), so
// tests drive the EXACT failure the Firestore SDK would surface:
//   • transient = FirebaseException('unavailable')  → existing retry path
//   • permanent = FirebaseException('permission-denied') → instant DLQ
class _FailingQueueWriter implements QueueFirestoreWriter {
  _FailingQueueWriter({this.failure});

  /// The failure thrown by every write; `null` = writes succeed.
  final Object? failure;

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> delete(String collectionName, String id) async {
    if (failure != null) throw failure!;
  }
}

final QueueFirestoreWriter _transientFailingWriter = _FailingQueueWriter(
  failure: FirebaseException(
    code: 'unavailable',
    message: 'The service is currently unavailable.',
    plugin: 'cloud_firestore',
  ),
);

final QueueFirestoreWriter _permissionDeniedWriter = _FailingQueueWriter(
  failure: FirebaseException(
    code: 'permission-denied',
    message: 'Missing or insufficient permissions.',
    plugin: 'cloud_firestore',
  ),
);

/// P8(W3): a writer that fails a SPECIFIC document's set() a scripted
/// number of times (then succeeds) and records every set() in call order —
/// the assertion surface for replay ordering.
class _ScriptedQueueWriter implements QueueFirestoreWriter {
  final List<String> setOrder = [];
  final Map<String, int> failuresRemaining;

  _ScriptedQueueWriter({this.failuresRemaining = const {}});

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    final key = '$collectionName/$id';
    setOrder.add(key);
    final remaining = failuresRemaining[key] ?? 0;
    if (remaining > 0) {
      failuresRemaining[key] = remaining - 1;
      throw FirebaseException(
        code: 'unavailable',
        message: 'transient outage',
        plugin: 'cloud_firestore',
      );
    }
  }

  @override
  Future<void> delete(String collectionName, String id) async {}
}

void main() {
  setUpAll(() async {
    await ensureIsarCoreForTests();
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('IsarSyncQueue', () {
    late Isar isar;
    late String isarDir;
    late TestIsarService isarService;
    late TestLoggerService logger;
    late IsarSyncQueue queue;

    setUp(() async {
      isar = await createTestIsar();
      isarDir = isar.directory!;
      isarService = TestIsarService(isar);
      logger = TestLoggerService();
      queue = IsarSyncQueue(
        isarService,
        logger,
        firestore: _transientFailingWriter,
      );
    });

    tearDown(() async {
      await isar.close();
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('enqueue adds a pending operation', () async {
      await queue.enqueue('create', 'orders', {'id': 'ord_1', 'total': 1500});

      final ops = await isar.isarPendingOperations.where().findAll();
      expect(ops.length, 1);
      expect(ops.first.operation, 'create');
      expect(ops.first.collectionName, 'orders');
      expect(ops.first.retryCount, 0);
    });

    test('enqueue multiple operations', () async {
      await queue.enqueue('create', 'orders', {'id': 'ord_1'});
      await queue.enqueue('update', 'cart', {'id': 'cart_1'});
      await queue.enqueue('delete', 'orders', {'id': 'ord_2'});

      final ops = await isar.isarPendingOperations.where().findAll();
      expect(ops.length, 3);
    });

    test('processQueue processes create operations', () async {
      await queue.enqueue('create', 'orders', {'id': 'ord_1', 'total': 1500});

      // The queue's Firestore surface is constructor-injected
      // (QueueFirestoreWriter, LEDGER:QUEUE-1); this suite wires a
      // transient-failing writer, so the op either delivers (writer had no
      // queued failure) or stays pending with retryCount>=1 on failure.
      await queue.processQueue();

      // After processing, the operation should be deleted from Isar
      // (or retried if it fails - since FakeFirebaseFirestore won't match
      // the instance used by the queue, it will fail and retry)
      final ops = await isar.isarPendingOperations.where().findAll();
      // Injected writer fails transiently on every set() → the op MUST stay
      // pending with an incremented retry count (never silently dropped).
      expect(ops, hasLength(1));
      expect(ops.first.retryCount, greaterThanOrEqualTo(1));
    });

    test('retry count increments on failure', () async {
      await queue.enqueue('create', 'orders', {'id': 'ord_1'});

      // The injected writer fails transiently on every set().
      await queue.processQueue();

      final ops = await isar.isarPendingOperations.where().findAll();
      expect(ops, hasLength(1));
      expect(ops.first.retryCount, greaterThanOrEqualTo(1));
    });

    test(
      'W8.9 T-2: DLQ FIFO cap — oldest entries evicted on overflow',
      () async {
        // Pre-seed the DLQ to exactly the cap with strictly increasing
        // timestamps so "oldest" is deterministic.
        final now = DateTime.now();
        await isar.writeTxn(() async {
          for (var i = 0; i < IsarSyncQueue.kMaxDeadLetters; i++) {
            await isar.isarDeadLetters.put(
              IsarDeadLetter()
                ..operation = 'seed'
                ..collectionName = 'orders'
                ..dataString = '{"seed":$i}'
                ..timestamp = now.subtract(
                  Duration(minutes: IsarSyncQueue.kMaxDeadLetters - i),
                )
                ..retryCount = IsarSyncQueue.kMaxRetries
                ..lastError = 'seed $i',
            );
          }
          // One over-retried pending op — processQueue moves it to the DLQ.
          await isar.isarPendingOperations.put(
            IsarPendingOperation()
              ..operation = 'create'
              ..collectionName = 'orders'
              ..dataString = '{"id":"poison-1"}'
              ..timestamp = now
              ..retryCount = IsarSyncQueue.kMaxRetries,
          );
        });

        await queue.processQueue();

        // Cap enforced: still exactly 200 after enqueueing one more.
        final count = await isar.isarDeadLetters.count();
        expect(count, IsarSyncQueue.kMaxDeadLetters);

        // FIFO: the OLDEST seed was evicted, its successor survived, and the
        // newly dead-lettered op is the newest row.
        final letters = await isar.isarDeadLetters
            .where()
            .sortByTimestamp()
            .findAll();
        expect(letters.any((d) => d.dataString == '{"seed":0}'), isFalse);
        expect(letters.any((d) => d.dataString == '{"seed":1}'), isTrue);
        expect(letters.last.dataString, '{"id":"poison-1"}');

        // The pending op was consumed by the DLQ move.
        final pending = await isar.isarPendingOperations.where().findAll();
        expect(pending, isEmpty);
      },
    );

    test(
      'operations with retryCount >= 5 move to DLQ (not silently skipped)',
      () async {
        final op = IsarPendingOperation()
          ..operation = 'create'
          ..collectionName = 'orders'
          ..dataString = '{"id":"ord_1"}'
          ..timestamp = DateTime.now()
          ..retryCount = 5;

        await isar.writeTxn(() async {
          await isar.isarPendingOperations.put(op);
        });

        await queue.processQueue();

        // The op should be moved to the DLQ, not silently skipped
        final pendingOps = await isar.isarPendingOperations.where().findAll();
        expect(pendingOps.length, 0);

        final dlqOps = await isar.isarDeadLetters.where().findAll();
        expect(dlqOps.length, 1);
        expect(dlqOps.first.operation, 'create');
        expect(dlqOps.first.collectionName, 'orders');
        expect(dlqOps.first.retryCount, 5);
        expect(dlqOps.first.lastError, 'Max retries exceeded');
      },
    );

    test(
      'stale orders older than 1 hour are STILL synced (not deleted)',
      () async {
        final staleOp = IsarPendingOperation()
          ..operation = 'create'
          ..collectionName = 'orders'
          ..dataString = '{"id":"ord_stale"}'
          ..timestamp = DateTime.now().subtract(const Duration(hours: 2))
          ..retryCount = 0;

        await isar.writeTxn(() async {
          await isar.isarPendingOperations.put(staleOp);
        });

        await queue.processQueue();

        // Stale order should NOT be deleted - it should still be in the queue
        // (it will fail to sync because there's no real Firestore, but it
        // must NOT be silently dropped by age)
        final ops = await isar.isarPendingOperations.where().findAll();
        expect(ops.length, 1);
        expect(ops.first.collectionName, 'orders');
        expect(ops.first.retryCount, greaterThanOrEqualTo(1));
      },
    );

    test('non-order stale operations are not rejected', () async {
      final staleOp = IsarPendingOperation()
        ..operation = 'update'
        ..collectionName = 'cart'
        ..dataString = '{"id":"cart_stale"}'
        ..timestamp = DateTime.now().subtract(const Duration(hours: 2))
        ..retryCount = 0;

      await isar.writeTxn(() async {
        await isar.isarPendingOperations.put(staleOp);
      });

      await queue.processQueue();

      // Non-order stale ops should remain (only orders are rejected)
      final ops = await isar.isarPendingOperations.where().findAll();
      expect(ops.length, 1);
    });

    test('removeOperation removes a specific queued op', () async {
      await queue.enqueue('createOrder', 'orders', {'id': 'ord_1'});
      await queue.enqueue('createOrder', 'orders', {'id': 'ord_2'});

      await queue.removeOperation('createOrder', 'ord_1');

      final ops = await isar.isarPendingOperations.where().findAll();
      expect(ops.length, 1);
      final data = ops.first.dataString;
      expect(data, contains('ord_2'));
    });

    test('retryDeadLetter re-enqueues a DLQ entry', () async {
      final dlq = IsarDeadLetter()
        ..operation = 'create'
        ..collectionName = 'orders'
        ..dataString = '{"id":"ord_1"}'
        ..timestamp = DateTime.now()
        ..retryCount = 5
        ..lastError = 'Max retries exceeded';

      await isar.writeTxn(() async {
        await isar.isarDeadLetters.put(dlq);
      });

      await queue.retryDeadLetter(dlq.id);

      // DLQ entry should be removed
      final dlqOps = await isar.isarDeadLetters.where().findAll();
      expect(dlqOps.length, 0);

      // Re-enqueued as a fresh pending op
      final pendingOps = await isar.isarPendingOperations.where().findAll();
      expect(pendingOps.length, 1);
      expect(pendingOps.first.retryCount, 0);
      expect(pendingOps.first.operation, 'create');
    });

    test('enqueue handles errors with isar db failure', () async {
      // Create a new IsarService that returns a broken future
      final brokenIsarService = TestIsarService(isar);
      // Override db with a failing future
      brokenIsarService.db = Future.error(Exception('DB error'));
      final brokenQueue = IsarSyncQueue(
        brokenIsarService,
        logger,
        firestore: _transientFailingWriter,
      );

      // Should not throw - caught by try/catch in enqueue
      await brokenQueue.enqueue('create', 'orders', {'id': 'ord_1'});

      // Error should be logged
      expect(logger.errorMessages.length, greaterThanOrEqualTo(1));
    });

    // ── QUEUE-1 T-3 (W5.1(c)) ──────────────────────────────────────────────
    test('rules-rejection (permission-denied) moves the op STRAIGHT to DLQ at '
        'retryCount 0 — permanent failures never burn retries', () async {
      final rulesDeniedQueue = IsarSyncQueue(
        isarService,
        logger,
        firestore: _permissionDeniedWriter,
      );
      await rulesDeniedQueue.enqueue('create', 'orders', {
        'id': 'ord_perm',
        'status': 'pending',
        'offlineQueued': true,
      });

      await rulesDeniedQueue.processQueue();

      // The pending op must be GONE (no retry burn, no silent skip).
      final pending = await isar.isarPendingOperations.where().findAll();
      expect(pending, isEmpty, reason: 'DLQ move must remove the pending op');

      // It must appear in the DLQ immediately with the ORIGINAL retryCount
      // (0) and the exact rules-rejection reason.
      final dlq = await isar.isarDeadLetters.where().findAll();
      expect(dlq.length, 1);
      expect(dlq.first.operation, 'create');
      expect(dlq.first.collectionName, 'orders');
      expect(dlq.first.retryCount, 0);
      expect(dlq.first.dataString, contains('"status":"pending"'));
      expect(dlq.first.lastError, contains('permission-denied'));
    });

    test('transient failures (unavailable) still retry — not DLQ', () async {
      // setUp's queue already injects a transient-failing firestore.
      await queue.enqueue('create', 'orders', {'id': 'ord_transient'});
      await queue.processQueue();

      final pending = await isar.isarPendingOperations.where().findAll();
      expect(pending.length, 1, reason: 'transient failure must stay pending');
      expect(pending.first.retryCount, greaterThanOrEqualTo(1));

      final dlq = await isar.isarDeadLetters.where().findAll();
      expect(dlq, isEmpty, reason: 'no DLQ move for a transient failure');
    });

    test(
      'replay preserves submission order after two enqueues and one forced '
      'failure (FIFO by enqueue timestamp — a failure never reorders)',
      () async {
        final writer = _ScriptedQueueWriter(
          failuresRemaining: {'orders/ordB': 1},
        );
        final scriptedQueue = IsarSyncQueue(
          isarService,
          logger,
          firestore: writer,
        );
        await scriptedQueue.enqueue('create', 'orders', {
          'id': 'ordA',
          'status': 'pending',
          'offlineQueued': true,
        });
        // Distinct enqueue timestamps: the replay contract is "older enqueue
        // replays first", so the two ops must not share one millisecond.
        await Future<void>.delayed(const Duration(milliseconds: 15));
        await scriptedQueue.enqueue('create', 'orders', {
          'id': 'ordB',
          'status': 'pending',
          'offlineQueued': true,
        });

        // First drain: ordA lands; ordB's write fails ONCE (transient).
        await scriptedQueue.processQueue();
        expect(
          writer.setOrder,
          ['orders/ordA', 'orders/ordB'],
          reason: 'the drain must attempt writes in submission order',
        );

        final pending = await isar.isarPendingOperations.where().findAll();
        expect(
          pending,
          hasLength(1),
          reason: 'only the failed op stays pending',
        );
        expect(pending.single.dataString, contains('"id":"ordB"'));
        expect(pending.single.retryCount, 1);
        expect(
          await isar.isarDeadLetters.where().findAll(),
          isEmpty,
          reason: 'a transient failure must never dead-letter',
        );

        // Second drain: the retried op replays FIRST (its enqueue timestamp
        // is the oldest) — a failed op must never be pushed behind newer work.
        await scriptedQueue.processQueue();
        expect(writer.setOrder, ['orders/ordA', 'orders/ordB', 'orders/ordB']);
        final remaining = await isar.isarPendingOperations.where().findAll();
        expect(remaining, isEmpty, reason: 'a succeeded replay deletes the op');
      },
    );

    test('isPermanentFailure classifies permission-denied vs transient', () {
      expect(
        IsarSyncQueue.isPermanentFailure(
          FirebaseException(
            code: 'permission-denied',
            message: 'denied',
            plugin: 'cloud_firestore',
          ),
        ),
        isTrue,
      );
      expect(
        IsarSyncQueue.isPermanentFailure(
          FirebaseException(
            code: 'unavailable',
            message: 'unavailable',
            plugin: 'cloud_firestore',
          ),
        ),
        isFalse,
      );
      expect(IsarSyncQueue.isPermanentFailure(Exception('boom')), isFalse);
    });

    test(
      'dismissDeadLetter removes the DLQ entry without re-enqueueing',
      () async {
        final dlq = IsarDeadLetter()
          ..operation = 'create'
          ..collectionName = 'orders'
          ..dataString = '{"id":"ord_1"}'
          ..timestamp = DateTime.now()
          ..retryCount = 3
          ..lastError = 'operator-inspected permanent rejection';

        await isar.writeTxn(() async {
          await isar.isarDeadLetters.put(dlq);
        });

        await queue.dismissDeadLetter(dlq.id);

        final dlqOps = await isar.isarDeadLetters.where().findAll();
        expect(dlqOps, isEmpty, reason: 'dismiss must delete the DLQ entry');
        final pendingOps = await isar.isarPendingOperations.where().findAll();
        expect(
          pendingOps,
          isEmpty,
          reason: 'dismiss must NOT re-enqueue a pending operation',
        );
      },
    );
  });
}
