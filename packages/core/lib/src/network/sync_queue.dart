import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';
import 'package:core/src/cache/isar_service.dart';
import 'package:core/src/cache/isar_schemas.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/network/network_retry.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Unique name of the periodic Workmanager task that flushes the offline
/// queue as a safety net (QUEUE-1 / W5.1(b)(3)). Mirrors the kitchen
/// heartbeat constant (`kKitchenHeartbeatTask`) — the app's background
/// dispatcher routes on this name.
const kQueueSyncTask = 'carnama.queue.sync';

/// The minimal Firestore WRITE surface the offline queue needs.
///
/// Production wires the canonical client via [FirestoreQueueWriter]; tests
/// inject a fault-injecting double. This seam mirrors the repo's ChaosFirestore
/// facade pattern (`src/network/chaos_firestore.dart`) and keeps the queue
/// deterministically testable without implementing the sealed
/// cloud_firestore `Query`/`DocumentReference` types.
abstract class QueueFirestoreWriter {
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  });

  Future<void> delete(String collectionName, String id);
}

/// Production adapter from the canonical [FirebaseFirestore] to
/// [QueueFirestoreWriter].
class FirestoreQueueWriter implements QueueFirestoreWriter {
  FirestoreQueueWriter(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) {
    // `doc([String? path])` with a null path auto-generates an id — this
    // mirrors the pre-QUEUE-1 `.doc(id)` behaviour for create ops.
    return _firestore.collection(collectionName).doc(id).set(data, options);
  }

  @override
  Future<void> delete(String collectionName, String id) {
    return _firestore.collection(collectionName).doc(id).delete();
  }
}

abstract class SyncQueue {
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  );
  Future<void> processQueue();
  Future<void> removeOperation(String operation, String id);
  Future<List<IsarDeadLetter>> getDeadLetters();

  /// Retries a dead-letter entry: re-enqueues it as a fresh pending operation
  /// (retryCount reset) and removes the DLQ entry.
  Future<void> retryDeadLetter(Id id);

  /// Dismisses a dead-letter entry WITHOUT re-enqueueing it. The queued
  /// mutation is intentionally dropped — the operator judged it unrecoverable
  /// (e.g. a stale order intent the customer already completed online).
  Future<void> dismissDeadLetter(Id id);
}

class IsarSyncQueue implements SyncQueue {
  final IsarService _isar;
  final LoggerService _logger;
  final QueueFirestoreWriter _firestore;

  /// Maximum retry attempts before an operation is moved to the dead-letter queue.
  static const int kMaxRetries = 5;

  /// W8.9 (04-P2-9): hard cap for the dead-letter queue. When exceeded, the
  /// OLDEST dead letters (by timestamp) are FIFO-evicted on enqueue — the DLQ
  /// must never grow unbounded (Law 20).
  static const int kMaxDeadLetters = 200;

  /// Delay injection seam for tests (FIX-B5 T-3 / AUD1-17 — mirrors
  /// [NetworkRetry.delay]). Production code MUST NOT reassign this: the
  /// default is a real [Future.delayed], so the shipped outbox ladder
  /// (2s → 4s → 8s → 16s → 32s = `1 << retryCount.clamp(0, 5)` for
  /// retryCount 1..5) stays fully live. Tests swap in a recorder to pin
  /// the ladder without wall-clock waits.
  @visibleForTesting
  static Future<void> Function(Duration duration) delay = Future<void>.delayed;

  /// QUEUE-1 (W5.1(c)) + FIX-B5 QUEUE-3 (AUD1-03): rules rejections and
  /// other PERMANENT failures move STRAIGHT to the visible DLQ — retrying
  /// them burns exponential backoff on a condition that cannot change.
  ///
  /// T-1 (one classifier): this is a delegating SHIM over the single
  /// canonical predicate [NetworkRetry.isRetryable]; the public signature is
  /// kept so every existing caller and pinned test compiles unchanged. Both
  /// retry entry points now share ONE table, decided by gRPC/Firebase
  /// error-code semantics (never by picking a side):
  ///
  /// | code                | verdict     | rationale (gRPC name)                  |
  /// |---------------------|-------------|----------------------------------------|
  /// | permission-denied   | PERMANENT   | PERMISSION_DENIED — rules/authz denial is deterministic |
  /// | not-found           | PERMANENT   | NOT_FOUND — missing doc/function, replay hits the same absence |
  /// | invalid-argument    | PERMANENT   | INVALID_ARGUMENT — client bug; re-sending cannot fix the payload |
  /// | unauthenticated     | PERMANENT   | UNAUTHENTICATED — expired/absent token needs re-auth, not a retry |
  /// | failed-precondition | PERMANENT   | FAILED_PRECONDITION — server-state veto that will not heal in the backoff window |
  /// | already-exists      | PERMANENT   | ALREADY_EXISTS — conflicting create collides every replay |
  /// | unavailable / deadline-exceeded / internal / network-request-failed / ... | transient | transient infrastructure — retry with backoff |
  /// | transport & unknown errors (SocketException, TimeoutException, ...) | transient | fail-closed: retried but BOUNDED by [kMaxRetries] |
  ///
  /// The five codes this shim historically disagreed on (not-found,
  /// invalid-argument, unauthenticated, failed-precondition, already-exists)
  /// are resolved toward the spec's QUEUE-2 contract-1 set: a permanent error
  /// must never be retried, a transient one never dropped early, and an
  /// unknown one always bounded (§0.7). Firestore Security Rules denials
  /// surface as `permission-denied` — an offline create replayed against an
  /// EXISTING confirmed order is rules-DENIED, so it lands in the visible
  /// DLQ at the original retryCount (0), payload preserved for the operator.
  static bool isPermanentFailure(Object error) =>
      !NetworkRetry.isRetryable(error);

  IsarSyncQueue(
    this._isar,
    this._logger, {
    required QueueFirestoreWriter firestore,
  }) : _firestore = firestore;

  @override
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await _isar.db;
      final pending = IsarPendingOperation()
        ..operation = operation
        ..collectionName = collectionName
        ..dataString = jsonEncode(data)
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await db.writeTxn(() async {
        await db.isarPendingOperations.put(pending);
      });
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_enqueue', stack: stack);
    }
  }

  @override
  Future<void> removeOperation(String operation, String id) async {
    try {
      final db = await _isar.db;
      final ops = await db.isarPendingOperations.where().findAll();
      final toDelete = ops
          .where((op) {
            if (op.operation != operation) return false;
            try {
              final data = jsonDecode(op.dataString) as Map<String, dynamic>;
              return data['id'] == id;
            } catch (_) {
              return false;
            }
          })
          .map((op) => op.id)
          .toList();
      if (toDelete.isNotEmpty) {
        await db.writeTxn(() async {
          await db.isarPendingOperations.deleteAll(toDelete);
        });
      }
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_removeOperation', stack: stack);
    }
  }

  @override
  Future<List<IsarDeadLetter>> getDeadLetters() async {
    try {
      final db = await _isar.db;
      return await db.isarDeadLetters.where().findAll();
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_getDeadLetters', stack: stack);
      return [];
    }
  }

  @override
  Future<void> retryDeadLetter(Id id) async {
    try {
      final db = await _isar.db;
      final dlqEntry = await db.isarDeadLetters.get(id);
      if (dlqEntry == null) return;

      // Re-enqueue the operation with a fresh retry count.
      final pending = IsarPendingOperation()
        ..operation = dlqEntry.operation
        ..collectionName = dlqEntry.collectionName
        ..dataString = dlqEntry.dataString
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await db.writeTxn(() async {
        await db.isarPendingOperations.put(pending);
        await db.isarDeadLetters.delete(id);
      });
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_retryDeadLetter', stack: stack);
    }
  }

  @override
  Future<void> dismissDeadLetter(Id id) async {
    try {
      final db = await _isar.db;
      await db.writeTxn(() async {
        await db.isarDeadLetters.delete(id);
      });
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_dismissDeadLetter', stack: stack);
    }
  }

  /// W8.9 (04-P2-9): dead-letter enqueue with a FIFO hard cap — the SINGLE
  /// DLQ put site in the codebase (both the max-retries path and the
  /// rules-denial path route through here).
  ///
  /// The DLQ must NEVER grow unbounded (a poison-message storm would eat the
  /// 1 GiB Isar budget). When [kMaxDeadLetters] would be exceeded, the OLDEST
  /// entries (by [IsarDeadLetter.timestamp]) are evicted first — the classic
  /// bounded-queue discipline (SQS/RabbitMQ DLQ equivalents). Runs INSIDE the
  /// caller's write transaction, so cap-enforcement and the enqueue commit or
  /// roll back together.
  ///
  /// [lastError] overrides the default reason so the rules-denial path
  /// preserves the exact operator-facing error.
  Future<void> _enqueueDeadLetter(
    Isar db,
    IsarPendingOperation op, {
    String? lastError,
  }) async {
    final count = await db.isarDeadLetters.count();
    if (count >= kMaxDeadLetters) {
      // Evict enough oldest entries to make room for exactly one new one.
      // The branch above guarantees count >= kMaxDeadLetters, so the limit
      // is always >= 1 — no clamping needed.
      final overflow = await db.isarDeadLetters
          .where()
          .sortByTimestamp()
          .limit(count - kMaxDeadLetters + 1)
          .findAll();
      if (overflow.isNotEmpty) {
        await db.isarDeadLetters.deleteAll(overflow.map((e) => e.id).toList());
      }
    }
    await db.isarDeadLetters.put(
      IsarDeadLetter()
        ..operation = op.operation
        ..collectionName = op.collectionName
        ..dataString = op.dataString
        ..timestamp = op.timestamp
        ..retryCount = op.retryCount
        ..lastError = lastError ?? 'Max retries exceeded',
    );
  }

  @override
  Future<void> processQueue() async {
    try {
      final db = await _isar.db;
      final pendingOps = await db.isarPendingOperations
          .where()
          .sortByTimestamp()
          .findAll();

      for (var op in pendingOps) {
        // Dead-letter queue: operations that exceed max retries are moved to
        // the DLQ instead of being silently skipped forever (Law 15).
        if (op.retryCount >= kMaxRetries) {
          await db.writeTxn(() async {
            // W8.9 (04-P2-9): capped, FIFO-evicting enqueue (single DLQ put
            // site in the codebase).
            await _enqueueDeadLetter(db, op);
            await db.isarPendingOperations.delete(op.id);
          });
          await _logger.error(
            Exception('Operation moved to DLQ after $kMaxRetries retries'),
            'SyncQueue_max_retries',
            stack: StackTrace.current,
          );
          continue;
        }

        // NOTE: Orders NEVER expire by age. Idempotent writes handle
        // duplicates (see P0-06). If an order doc already exists, the
        // set(merge:true) simply updates it — no data loss (Law 15).

        try {
          final data = jsonDecode(op.dataString) as Map<String, dynamic>;
          if (op.operation == 'create' || op.operation == 'update') {
            final id = data['id'] as String?;
            data['updatedAt'] = FieldValue.serverTimestamp();
            await _firestore.set(
              op.collectionName,
              id,
              data,
              options: SetOptions(merge: true),
            );
          } else if (op.operation == 'delete') {
            final id = data['id'] as String?;
            if (id == null) {
              // Fail-closed, never a silent drop: a delete without an id
              // cannot be sent, so it takes the error path (retry/DLQ).
              throw ArgumentError('delete op "$op.id" has no target id');
            }
            await _firestore.delete(op.collectionName, id);
          }

          await db.writeTxn(() async {
            await db.isarPendingOperations.delete(op.id);
          });
        } catch (e, stack) {
          await _logger.error(e, 'SyncQueue_processOp', stack: stack);
          if (isPermanentFailure(e)) {
            // QUEUE-1 (W5.1(c)): rules/permission rejections never heal — move
            // STRAIGHT to the visible DLQ at retryCount 0 (no retry burn). The
            // DLQ entry preserves the exact payload so an operator can inspect
            // or re-enqueue it from the DLQ screen.
            await db.writeTxn(() async {
              await _enqueueDeadLetter(db, op, lastError: e.toString());
              await db.isarPendingOperations.delete(op.id);
            });
            continue;
          }
          await db.writeTxn(() async {
            op.retryCount += 1;
            await db.isarPendingOperations.put(op);
          });
          await delay(Duration(seconds: 1 << op.retryCount.clamp(0, 5)));
        }
      }
    } catch (e, stack) {
      await _logger.error(e, 'SyncQueue_process', stack: stack);
    }
  }
}
