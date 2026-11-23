import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';

// Spec: OrderModel contract:
// - Required: id, customerId, status, totalCents, createdAt
// - Optional: branchId, items, updatedAt
// - Status defaults to pending, totalCents defaults to 0
// Tests verify model structure — repository requires Firebase initialization

void main() {
  group('OrderModel — Spec Contract', () {
    test('Model has all required fields per spec', () {
      final order = OrderModel(
        id: 'order_1',
        customerId: 'user_1',
        status: OrderStatus.confirmed,
        totalCents: 2500,
        createdAt: DateTime.now(),
      );
      expect(order.id, equals('order_1'));
      expect(order.customerId, equals('user_1'));
      expect(order.status, equals(OrderStatus.confirmed));
      expect(order.totalCents, equals(2500));
      expect(order.createdAt, isNotNull);
    });

    test('OrderModel round-trips through JSON per spec', () {
      final original = OrderModel(
        id: 'order_abc',
        customerId: 'user123',
        status: OrderStatus.cooking,
        totalCents: 1500,
        createdAt: DateTime(2025, 1, 1, 12, 0),
        branchId: 'branch_nyc',
        items: const [],
      );

      final json = original.toJson();
      final restored = OrderModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.customerId, equals(original.customerId));
      expect(restored.status, equals(original.status));
      expect(restored.totalCents, equals(original.totalCents));
      expect(restored.branchId, equals(original.branchId));
    });

    test('Missing status defaults to pending per spec', () {
      final order = OrderModel(
        id: 'test',
        customerId: 'user',
        totalCents: 1000,
        createdAt: DateTime.now(),
      );
      expect(order.status, equals(OrderStatus.pending));
    });

    test('Missing totalCents defaults to 0 per spec', () {
      final order = OrderModel(
        id: 'test',
        customerId: 'user',
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );
      expect(order.totalCents, equals(0));
    });

    test('All OrderStatus values are valid per spec', () {
      for (final status in OrderStatus.values) {
        final order = OrderModel(
          id: 'test',
          customerId: 'user',
          status: status,
          totalCents: 1000,
          createdAt: DateTime.now(),
        );
        expect(order.status, equals(status));
      }
    });

    test('Zero-cent order is valid per spec', () {
      final order = OrderModel(
        id: 'zero_order',
        customerId: 'user',
        status: OrderStatus.pending,
        totalCents: 0,
        createdAt: DateTime.now(),
      );
      expect(order.totalCents, equals(0));
      expect(order.id, equals('zero_order'));
    });
  });
}
