import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/demo_config.dart';
import '../domain/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final LoggerService _logger;

  OrderRepository(
    this._firestore,
    this._logger, {
    required FirebaseFunctions functions,
  }) : _functions = functions;

  Stream<OrderModel?> streamOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .handleError((Object e, stack) {
          _logger.error(
            e,
            'streamOrder failed for id: $orderId',
            stack: stack as StackTrace,
          );
          throw e;
        })
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return OrderModel.fromDoc(snapshot);
        });
  }

  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .handleError((Object e, stack) {
          _logger.error(
            e,
            'getUserOrders failed for userId: $userId',
            stack: stack as StackTrace,
          );
          throw e;
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) => OrderModel.fromDoc(doc)).toList();
        });
  }

  Future<void> cancelOrder(String orderId) async {
    // ── DEMO MODE: Direct Firestore status update ─────────────────────────
    if (kDemoMode) {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // UX-4 (07-P1-7): the kept-but-dead AnalyticsService.logOrderCancelled
      // is wired at its natural site — through the single facade. Never
      // awaited (a telemetry failure must not break the cancel path).
      unawaited(TelemetryService().orderCancelled(orderId, 'user_requested'));
      return;
    }
    // ── PRODUCTION MODE: Cloud Function (atomic inventory refund) ─────────
    try {
      final callable = _functions.httpsCallable('cancelOrder');
      await NetworkRetry.withExponentialBackoff(
        () => callable.call({'orderId': orderId}),
        maxRetries: 2,
        timeout: const Duration(seconds: 15),
      );
      // UX-4: same wiring on the production path (facade is consent-gated
      // and never throws — see TelemetryService.log).
      unawaited(TelemetryService().orderCancelled(orderId, 'user_requested'));
    } catch (e, stack) {
      await _logger.error(
        e,
        'cancelOrder failed for orderId: $orderId',
        stack: stack,
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  // MONEY-3 (P-5 / verification_report 6.4): the dead test-only flat-payload
  // order-submission path was removed in B3-P3; this class now exposes exactly
  // one order-submission contract. The production order path is
  // `CheckoutService.createOrder` (checkout_service.dart) which sends the
  // `createOrder` callable payload `{paymentIntentId, order, userId,
  // idempotencyKey}`; that exact payload shape is asserted by
  // test/idempotency_test.dart.
}
