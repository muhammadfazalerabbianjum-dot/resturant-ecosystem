import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:labs/features/tracking/data/driver_location_service_provider.dart';

/// W8.7 (04-P1-QUERY): named cap beside its precedent
/// (kMenuMaxItemsSafetyCap, menu_repository.dart:16) — driver streams stay
/// operationally small (transient statuses), but a hostile/pathological day
/// must never stream unbounded into the driver dashboard.
const int kDriverOrdersStreamCap = 100;

/// Service encapsulating all delivery business logic.

/// Service encapsulating all delivery business logic.
///
/// Extracted from [DeliveryDashboard] to enable unit testing.
/// All platform dependencies (FirebaseFirestore, DriverLocationService)
/// are injected so they can be mocked in tests.
class DeliveryService {
  final FirebaseFirestore _firestore;
  final DriverLocationService _locationService;
  final LoggerService _logger;

  /// STAFF-QUEUE (W5.4): the offline sync queue — markDelivered/assignToMe
  /// mutations are durably enqueued BEFORE the Firestore write and removed on
  /// success, so a flaky network can no longer silently lose them
  /// (02-P1-STAFF).
  final SyncQueue _syncQueue;

  /// D-057: the tenant both order streams must constrain their queries by.
  final TenantScope _scope;

  DeliveryService({
    required FirebaseFirestore firestore,
    required DriverLocationService locationService,
    required LoggerService logger,
    required SyncQueue syncQueue,
    TenantClaimReader? tenantClaim,
  }) : _firestore = firestore,
       _locationService = locationService,
       _logger = logger,
       _syncQueue = syncQueue,
       _scope = TenantScope(tenantClaim);

  /// Stream orders assigned to a specific driver that are ready or picked up.
  ///
  /// b10 P-2: branch-scoped (mirrors [availableOrders]) — the orders read rule
  /// grants delivery-role reads only for `resource.data.branchId ==
  /// userBranch()`, so an unscoped query was runtime-denied (rules are not
  /// filters).
  Stream<List<OrderModel>> myOrders(String driverUid, String branchId) async* {
    final tenantId = await _scope.require('DeliveryService');
    yield* _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('branchId', isEqualTo: branchId)
        .where('assignedDriverId', isEqualTo: driverUid)
        .where(
          'status',
          whereIn: [OrderStatus.ready.name, OrderStatus.pickedUp.name],
        )
        .orderBy('createdAt', descending: false)
        .limit(kDriverOrdersStreamCap)
        .snapshots()
        .map((s) => s.docs.map((d) => OrderModel.fromDoc(d)).toList())
        .handleError((Object e, StackTrace stack) {
          unawaited(
            _logger.error(
              e,
              'myOrders failed for driverUid: $driverUid, branchId: $branchId',
              stack: stack,
            ),
          );
          throw e;
        });
  }

  /// Stream available (unassigned, ready) orders for a branch.
  Stream<List<OrderModel>> availableOrders(String branchId) async* {
    final tenantId = await _scope.require('DeliveryService');
    yield* _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: 'ready')
        .orderBy('createdAt', descending: false)
        .limit(kDriverOrdersStreamCap)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => OrderModel.fromDoc(d))
              .where((o) => o.assignedDriverId == null)
              .toList(),
        )
        .handleError((Object e, StackTrace stack) {
          unawaited(
            _logger.error(
              e,
              'availableOrders failed for branchId: $branchId',
              stack: stack,
            ),
          );
          throw e;
        });
  }

  /// Shared W8.3/STAFF-QUEUE guard for the delivered transition: throws the
  /// documented not-found / invalid-transition errors for a raw order doc
  /// snapshot. Used BOTH by the STAFF-QUEUE pre-flight (before enqueueing, so
  /// a business-invalid request never leaves a pending op that a later replay
  /// could apply out-of-band) and inside the transaction (the authoritative
  /// online re-check — the pre-flight read and the transactional read race).
  static void _assertDeliverable(Map<String, dynamic>? data, String orderId) {
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
    if (!current.canTransitionTo(OrderStatus.delivered)) {
      throw Exception(
        'Invalid status transition: ${current.name} -> delivered '
        '(order $orderId)',
      );
    }
  }

  /// Mark an order as delivered and stop GPS tracking.
  ///
  /// W8.3 (03-P1-TRANSITION): transaction-guarded like [assignToMe] — only a
  /// `pickedUp` order may transition to `delivered`; any other current status
  /// fails closed (error thrown, NO write, GPS keeps running). Firestore
  /// rules (W4.1) remain the server guard.
  ///
  /// STAFF-QUEUE (W5.4): the write is bracketed by the offline queue — the
  /// rules-legal payload (buildDeliveryStatusUpdatePayload) is enqueued
  /// BEFORE the transaction and removed once it commits; a network-killed
  /// transaction leaves the op pending for the QUEUE-1 auto-triggers to
  /// replay as an idempotent last-write-wins merge-set.
  Future<void> markDelivered(String orderId) async {
    try {
      // STAFF-QUEUE pre-flight — must precede the enqueue (fail-closed before
      // any durable side effect).
      final preFlight = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();
      _assertDeliverable(preFlight.data(), orderId);

      await _syncQueue.enqueue(
        'update',
        'orders',
        buildDeliveryStatusUpdatePayload(orderId, OrderStatus.delivered.name),
      );
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('orders').doc(orderId);
        final snapshot = await transaction.get(docRef);
        _assertDeliverable(snapshot.data(), orderId);
        transaction.update(docRef, {
          'status': OrderStatus.delivered.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await _syncQueue.removeOperation('update', orderId);
      // Only stop GPS once the delivered write actually committed.
      await _locationService.stopTracking();
    } catch (e, stack) {
      await _logger.error(
        e,
        'markDelivered failed for orderId: $orderId',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Assign an order to the current driver using a Firestore transaction.
  /// Throws if the order is already assigned to someone else.
  ///
  /// STAFF-QUEUE (W5.4): the write is bracketed by the offline queue — the
  /// rules-legal claim payload (buildDeliveryClaimPayload) is enqueued
  /// BEFORE the transaction and removed once it commits. The pre-flight
  /// guards below mirror the in-transaction ones so a claim that can never
  /// land (missing doc / already assigned) is never queued.
  Future<void> assignToMe(String orderId, String driverUid) async {
    try {
      // STAFF-QUEUE pre-flight — must precede the enqueue (fail-closed before
      // any durable side effect). Error messages preserved 1:1.
      final preFlight = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();
      final preData = preFlight.data();
      if (preData == null) throw Exception('Order not found');
      if (preData['assignedDriverId'] != null) {
        throw Exception('Order already assigned to someone else');
      }

      await _syncQueue.enqueue(
        'update',
        'orders',
        buildDeliveryClaimPayload(orderId, driverUid),
      );
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('orders').doc(orderId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data();
        if (data == null) throw Exception('Order not found');
        if (data['assignedDriverId'] != null) {
          throw Exception('Order already assigned to someone else');
        }
        transaction.update(docRef, {
          'assignedDriverId': driverUid,
          'status': OrderStatus.pickedUp.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await _syncQueue.removeOperation('update', orderId);
    } catch (e, stack) {
      await _logger.error(
        e,
        'assignToMe failed for orderId: $orderId',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Start GPS livestreaming for a given order.
  Future<void> startGpsTracking(String orderId) async {
    await _locationService.startTracking(orderId);
  }

  /// Stop GPS tracking.
  Future<void> stopGpsTracking() async {
    await _locationService.stopTracking();
  }
}

/// STAFF-QUEUE (W5.4): the RULES-LEGAL replay payload for a delivery status
/// write ({id, status}), enqueued through [IsarSyncQueue] BEFORE the Firestore
/// write. `IsarSyncQueue.processQueue` merge-sets the WHOLE payload with a
/// queue-stamped `updatedAt`; the delivery rules clause
/// (firestore.rules:403-427) admits only
/// `affectedKeys().hasOnly(['status', 'assignedDriverId', 'updatedAt',
/// 'proofOfDelivery'])` — true here because every stored order doc carries its
/// own `id` field equal to the doc id (CF `createOrder` index.ts:1155; the
/// QUEUE-1 offline create replay persists it), so the merged `id` is
/// UNCHANGED and never appears in affectedKeys(). Extra keys would
/// rules-DENY the replay into the DLQ — keep this payload minimal.
Map<String, dynamic> buildDeliveryStatusUpdatePayload(
  String orderId,
  String status,
) => {'id': orderId, 'status': status};

/// STAFF-QUEUE (W5.4): the RULES-LEGAL replay payload for the assignToMe
/// CLAIM of an unassigned ready order — models the rules' claim branch
/// (firestore.rules:420-423): assignedDriverId = self, status 'pickedUp'.
Map<String, dynamic> buildDeliveryClaimPayload(
  String orderId,
  String driverUid,
) => {
  'id': orderId,
  'assignedDriverId': driverUid,
  'status': OrderStatus.pickedUp.name,
};

/// Riverpod provider for [DeliveryService].
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(
    firestore: ref.watch(firestoreProvider),
    locationService: ref.watch(driverLocationServiceProvider),
    logger: ref.watch(loggerProvider),
    syncQueue: ref.watch(syncQueueProvider),
  );
});
