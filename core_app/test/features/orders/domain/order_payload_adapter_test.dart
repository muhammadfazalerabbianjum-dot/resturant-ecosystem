import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_payload_adapter.dart';

/// PERF-2 S1 — the KitchenOfflineService payload bridge contract: the core
/// offline service only needs a JSON round-trip of the feature order, so the
/// adapter must lose NOTHING on that round trip (the replayed offline order
/// is consumed field-by-field by the kitchen heartbeat).
void main() {
  final DateTime createdAt = DateTime.parse('2026-09-14T10:00:00.000');
  final OrderModel order = OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    status: OrderStatus.pending,
    totalCents: 2450,
    taxCents: 195,
    createdAt: createdAt,
  );

  group('OrderPayloadAdapter — the kitchen heartbeat JSON bridge', () {
    test('implements the core OrderPayload contract', () {
      expect(OrderPayloadAdapter(order), isA<OrderPayload>());
    });

    test('toJson delegates to the real OrderModel serialization', () {
      final Map<String, dynamic> json = OrderPayloadAdapter(order).toJson();
      expect(json['id'], 'order-1');
      expect(json['customerId'], 'customer-1');
      expect(json['totalCents'], 2450);
      expect(json['status'], 'pending');
      expect(json['createdAt'], createdAt.toIso8601String());
    });

    test('fromJson round-trips into an equal OrderModel (replay fidelity)', () {
      final Map<String, dynamic> json = OrderPayloadAdapter(order).toJson();
      final OrderModel reparsed = OrderPayloadAdapter.fromJson(json).order;
      expect(reparsed, equals(order));
    });
  });
}
