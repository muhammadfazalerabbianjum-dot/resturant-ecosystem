import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// W8.7 (04-P1-QUERY): named cap beside its precedent
/// (kMenuMaxItemsSafetyCap, menu_repository.dart:16) — a live kitchen stream
/// must never grow unbounded with a branch's order volume.
const int kKitchenOrdersStreamCap = 200;

/// Service encapsulating kitchen business logic.

/// Service encapsulating kitchen business logic.
///
/// Extracted from [KitchenDashboard] to enable unit testing.
/// All platform dependencies (FirebaseFirestore) are injected
/// so they can be mocked in tests.
class KitchenService {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  /// STAFF-QUEUE (W5.4): the offline sync queue. The status mutation is
  /// durably enqueued BEFORE the Firestore write and removed on success, so a
  /// flaky network can no longer silently lose it (02-P1-STAFF).
  final SyncQueue _syncQueue;

  /// D-057: the tenant the kitchen stream must constrain its query by.
  final TenantScope _scope;

  KitchenService({
    required FirebaseFirestore firestore,
    required LoggerService logger,
    required SyncQueue syncQueue,
    TenantClaimReader? tenantClaim,
  }) : _firestore = firestore,
       _logger = logger,
       _syncQueue = syncQueue,
       _scope = TenantScope(tenantClaim);

  /// Stream orders for a given branch filtered by statuses.
  ///
  /// W8.7 (04-P1-QUERY): the FIFO `orderBy createdAt` (ascending) pairs with
  /// [kKitchenOrdersStreamCap] so a pathological day truncates at the NEWEST
  /// tail (the docs kitchen staff have not reached yet) instead of streaming
  /// unbounded.
  Stream<List<OrderModel>> streamOrders(
    String branchId,
    List<String> statuses,
  ) async* {
    final tenantId = await _scope.require('KitchenService');
    yield* _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('branchId', isEqualTo: branchId)
        .where('status', whereIn: statuses)
        .orderBy('createdAt', descending: false)
        .limit(kKitchenOrdersStreamCap)
        .snapshots()
        .map((snap) => snap.docs.map((d) => OrderModel.fromDoc(d)).toList())
        .handleError((Object e, StackTrace stack) {
          unawaited(
            _logger.error(
              e,
              'streamOrders failed for branchId: $branchId',
              stack: stack,
            ),
          );
          throw e;
        });
  }

  /// Shared W8.3/STAFF-QUEUE guard: throws the documented not-found /
  /// invalid-transition errors for a raw order doc snapshot. Used BOTH by the
  /// STAFF-QUEUE pre-flight (before enqueueing, so a business-invalid request
  /// never leaves a pending op that a later replay could apply out-of-band)
  /// and inside the transaction (the authoritative online re-check — the
  /// pre-flight read and the transactional read can race).
  static void _assertTransitionLegal(
    Map<String, dynamic>? data,
    OrderStatus next,
    String orderId,
  ) {
    if (data == null) {
      // Preserve the pre-existing failure contract: a missing order
      // surfaces as a Firestore not-found error (the unconditional
      // update() on a missing doc threw FirebaseException too).
      throw FirebaseException(
        plugin: 'firestore',
        code: 'not-found',
        message: 'Order $orderId not found',
      );
    }
    final current = OrderStatus.fromString(
      data['status'] as String? ?? 'pending',
    );
    if (!current.canTransitionTo(next)) {
      throw Exception(
        'Invalid status transition: ${current.name} -> ${next.name} '
        '(order $orderId)',
      );
    }
  }

  /// Update the status of an order.
  ///
  /// W8.3 (03-P1-TRANSITION): transaction-guarded like
  /// [DeliveryService.assignToMe] — reads the CURRENT server status and
  /// writes `{status, updatedAt}` only when
  /// `current.canTransitionTo(newStatus)` holds; otherwise fails closed with
  /// a thrown error and NO write, so stale snapshots can no longer flip
  /// dead/delivered orders. Firestore rules (W4.1) remain the server guard.
  ///
  /// STAFF-QUEUE (W5.4): the write is bracketed by the offline queue — the
  /// rules-legal update payload (buildKitchenStatusUpdatePayload) is
  /// enqueued BEFORE the transaction and removed once the transaction
  /// commits. If the network kills the transaction, the pending op is
  /// replayed by the QUEUE-1 auto-triggers as an idempotent last-write-wins
  /// merge-set. The pre-flight guard runs on the latest known snapshot
  /// (server online, cache offline) so only transitions that can actually
  /// land are ever queued.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      // STAFF-QUEUE pre-flight — must precede the enqueue (fail-closed before
      // any durable side effect).
      final preFlight = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();
      _assertTransitionLegal(preFlight.data(), newStatus, orderId);

      await _syncQueue.enqueue(
        'update',
        'orders',
        buildKitchenStatusUpdatePayload(orderId, newStatus.name),
      );
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('orders').doc(orderId);
        final snapshot = await transaction.get(docRef);
        _assertTransitionLegal(snapshot.data(), newStatus, orderId);
        transaction.update(docRef, {
          'status': newStatus.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await _syncQueue.removeOperation('update', orderId);
    } catch (e, stack) {
      await _logger.error(
        e,
        'updateOrderStatus failed for orderId: $orderId',
        stack: stack,
      );
      rethrow;
    }
  }
}

/// STAFF-QUEUE (W5.4): the RULES-LEGAL replay payload for a staff status
/// write, enqueued through [IsarSyncQueue] BEFORE the Firestore write.
///
/// `IsarSyncQueue.processQueue` (packages/core/lib/src/network/sync_queue.dart)
/// addresses the target doc by `data['id']` and merge-sets the WHOLE payload
/// with a queue-stamped `updatedAt` (FieldValue.serverTimestamp()). The rules'
/// kitchen clause (firestore.rules:397-402) admits only
/// `affectedKeys().hasOnly(['status', 'updatedAt'])` — true here because every
/// stored order doc carries its own `id` field equal to the doc id (CF
/// `createOrder` index.ts:1155 writes it; the QUEUE-1 offline create replay
/// persists it from OrderModel.toJson), so the merged `id` is UNCHANGED and
/// never appears in affectedKeys(). This payload must stay EXACTLY these two
/// keys — any extra key would rules-DENY the replay into the DLQ.
Map<String, dynamic> buildKitchenStatusUpdatePayload(
  String orderId,
  String status,
) => {'id': orderId, 'status': status};

/// Riverpod provider for [KitchenService].
final kitchenServiceProvider = Provider<KitchenService>((ref) {
  return KitchenService(
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
    syncQueue: ref.watch(syncQueueProvider),
  );
});
