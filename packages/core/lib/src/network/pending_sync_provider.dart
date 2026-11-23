import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:core/src/cache/isar_service.dart';
import 'package:core/src/cache/isar_schemas.dart';
import 'package:core/src/error_logger/logger_provider.dart';
import 'package:core/src/network/firestore_client.dart';
import 'package:core/src/network/sync_queue.dart';

/// The app-wide [IsarService]. Resolves to the production singleton by
/// default; widget/unit tests override it with an in-memory Isar instance
/// (see the QUEUE-1 DLQ screen tests). QUEUE-1 introduced this seam so the
/// queue providers (and thus every consumer of the pending/DLQ streams) are
/// testable without touching the real on-device database.
final isarServiceProvider = Provider<IsarService>(
  (ref) => IsarService.shared(),
);

/// The offline sync queue, shared by checkout (enqueue), the app startup /
/// connectivity / periodic auto-triggers (processQueue) and the DLQ screen
/// (retry/dismiss). Constructor-injecting [FirestoreClient.instance.db] keeps
/// the queue's Firestore access inside the canonical client wrapper (QUEUE-1).
/// Typed as the [SyncQueue] INTERFACE so widget tests can inject a real
/// in-memory double (the repo convention — `runtime_audit_flow_test.dart`
/// overrides the queue providers).
final syncQueueProvider = Provider<SyncQueue>((ref) {
  return IsarSyncQueue(
    ref.watch(isarServiceProvider),
    ref.watch(loggerProvider),
    firestore: FirestoreQueueWriter(FirestoreClient.instance.db),
  );
});

/// Provider that exposes the count of pending (unsynced) operations from Isar.
///
/// Uses a [StreamProvider] so the UI reflects the CURRENT queue state
/// reactively. Isar's `watchLazy()` re-emits whenever the collection changes,
/// so the badge updates immediately after enqueue, sync, or DLQ moves
/// (Law 15: Offline-First).
final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final isarService = ref.watch(isarServiceProvider);
  final db = await isarService.db;
  // Re-emit whenever the pending-operations collection changes:
  yield* db.isarPendingOperations.watchLazy().asyncMap((_) async {
    final ops = await db.isarPendingOperations.where().findAll();
    // Only count ops that are still retryable (not dead letters). Uses the
    // sync queue's own max-retry constant as the single source of truth so a
    // future retry-policy change cannot silently desync the badge count.
    return ops.where((op) => op.retryCount < IsarSyncQueue.kMaxRetries).length;
  });
});

/// Provider that exposes the count of dead-letter queue entries.
///
/// The DLQ holds operations that exceeded max retries (or were rejected as
/// permanent, QUEUE-1) and await manual intervention. The badge should reflect
/// this count so ops can alert (Law 11: Silent Telemetry).
final deadLetterCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final db = await ref.watch(isarServiceProvider).db;
  yield* db.isarDeadLetters.watchLazy().asyncMap((_) async {
    return db.isarDeadLetters.where().count();
  });
});

/// Provider exposing the FULL dead-letter list for the DLQ screen.
///
/// Re-emits on any Isar DLQ mutation (add on permanent failure / max retries,
/// removal on retry or dismiss) so the operator UI stays live.
final deadLettersProvider = StreamProvider.autoDispose<List<IsarDeadLetter>>((
  ref,
) async* {
  final db = await ref.watch(isarServiceProvider).db;
  yield* db.isarDeadLetters.watchLazy().asyncMap((_) async {
    return db.isarDeadLetters.where().findAll();
  });
});
