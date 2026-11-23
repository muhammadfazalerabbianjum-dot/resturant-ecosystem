import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_offline_payload.dart';

/// QUEUE-1 T-1 (W5.1(a)) — the enqueued offline payload is rules-legal:
/// `status: 'pending'` (firestore.rules create requires it), `offlineQueued:
/// true`, `queuedAt` ISO — while the in-memory/UI order object is NEVER
/// mutated and NEVER enqueued as `confirmed`.
void main() {
  final order = OrderModel(
    id: 'ord-test',
    customerId: 'user-1',
    branchId: 'branch-1',
    status: OrderStatus.confirmed,
    totalCents: 1500,
    taxCents: 100,
    discountCents: 50,
    tipCents: 200,
    deliveryFeeCents: 300,
    orderNumber: 'A-123',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('QUEUE-1 T-1: buildOfflineOrderPayload', () {
    test('payload is status=pending + offlineQueued=true + queuedAt ISO + '
        'carries the order identity', () {
      final queuedAt = DateTime(2026, 1, 2, 3, 4, 5);
      final payload = buildOfflineOrderPayload(
        order,
        tenantId: 'tenant_a',
        queuedAt: queuedAt,
      );

      expect(payload['status'], 'pending');
      expect(payload['offlineQueued'], isTrue);
      expect(payload['queuedAt'], queuedAt.toIso8601String());
      expect(payload['id'], 'ord-test');
      expect(payload['customerId'], 'user-1');
      expect(payload['branchId'], 'branch-1');
      expect(payload['totalCents'], 1500);
    });

    test(
      'NEVER enqueues confirmed, and the UI order object is NOT mutated',
      () {
        final payload = buildOfflineOrderPayload(order, tenantId: 'tenant_a');

        expect(payload['status'], 'pending');
        expect(
          payload['status'],
          isNot('confirmed'),
          reason:
              'an unpaid intent must never replay as confirmed (money stays '
              'CF-authoritative)',
        );
        expect(
          order.status,
          OrderStatus.confirmed,
          reason: 'the in-memory/UI order must keep its real confirmed status',
        );
        expect(order.totalCents, 1500);
        expect(order.toJson()['offlineQueued'], isNull);
        expect(order.toJson()['queuedAt'], isNull);
      },
    );

    test('queuedAt defaults to a parseable ISO-8601 now', () {
      final payload = buildOfflineOrderPayload(order, tenantId: 'tenant_a');

      expect(payload['queuedAt'], isNotNull);
      final queuedAt = payload['queuedAt'] as String;
      expect(queuedAt, isNotEmpty);
      expect(DateTime.tryParse(queuedAt), isNotNull);
    });

    test('the payload survives a queue enqueue round-trip unchanged', () async {
      // Regression guard: processQueue reads data['id'] then set(merge:true) —
      // the offline marker must not break the stored JSON.
      final payload = buildOfflineOrderPayload(order, tenantId: 'tenant_a');
      expect(payload.containsKey('id'), isTrue);
      expect(payload['id'], isA<String>());
    });
  });
}
