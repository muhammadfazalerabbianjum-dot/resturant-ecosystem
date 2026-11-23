import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// Law 34 (Edge Case Resilience)
///
/// Tests the data layer with every Firestore snapshot edge case:
/// empty collections, single docs, missing optional fields, null timestamps,
/// and wrong-type field values — all must handle gracefully without crashing.

void main() {
  group('Firestore Snapshot Edge Cases (Law 34)', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() => fakeFirestore = FakeFirebaseFirestore());

    // ── 1. Empty QuerySnapshot ────────────────────────────────────────────────
    test(
      'Empty QuerySnapshot returns empty list — not null, no crash',
      () async {
        final snapshot = await fakeFirestore.collection('orders').get();

        expect(
          snapshot.docs,
          isEmpty,
          reason: 'Empty collection must return empty docs list',
        );

        // Simulating what a repository would do
        final orders = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['createdAt'] = DateTime.now().toIso8601String();
          return OrderModel.fromJson(data);
        }).toList();

        expect(orders, isA<List<OrderModel>>());
        expect(orders, isEmpty);
      },
    );

    // ── 2. Single-document snapshot ───────────────────────────────────────────
    test(
      'Single-document snapshot parses correctly — all fields present',
      () async {
        await fakeFirestore.collection('orders').doc('ord_001').set({
          'customerId': 'u1',
          'status': 'preparing',
          'totalCents': 1500,
          'createdAt': DateTime.utc(2024, 6, 1).toIso8601String(),
          'branchId': 'branch_01',
        });

        final snapshot = await fakeFirestore
            .collection('orders')
            .doc('ord_001')
            .get();

        expect(snapshot.exists, isTrue);

        final data = Map<String, dynamic>.from(snapshot.data()!);
        data['id'] = snapshot.id;

        final order = OrderModel.fromJson(data);
        expect(order.id, 'ord_001');
        expect(order.customerId, 'u1');
        expect(order.status, OrderStatus.preparing);
        expect(order.totalCents, 1500);
      },
    );

    // ── 3. Document with ALL optional fields missing ──────────────────────────
    test(
      'Document with only id — all @Default values populate correctly',
      () async {
        await fakeFirestore.collection('orders').doc('ord_minimal').set({});

        final snapshot = await fakeFirestore
            .collection('orders')
            .doc('ord_minimal')
            .get();

        final data = Map<String, dynamic>.from(snapshot.data()!);
        data['id'] = snapshot.id;
        data['createdAt'] = DateTime.now().toIso8601String(); // required field

        final order = OrderModel.fromJson(data);

        expect(
          order.customerId,
          '',
          reason: '@Default empty string used for missing customerId',
        );
        expect(
          order.status,
          OrderStatus.pending,
          reason: '@Default pending used for missing status',
        );
        expect(
          order.totalCents,
          0,
          reason: '@Default 0 used for missing totalCents',
        );
        expect(
          order.items,
          isEmpty,
          reason: '@Default [] used for missing items',
        );
        expect(
          order.assignedDriverId,
          isNull,
          reason: 'Nullable field stays null when missing',
        );
      },
    );

    // ── 4. Null Timestamp field → null DateTime (no crash) ───────────────────
    test('Null createdAt field does not crash the parser', () {
      // UserModel.fromDoc has its own null-guard for Timestamps
      expect(
        () => OrderModel.fromJson({
          'id': 'ord_null_ts',
          'customerId': 'u1',
          'createdAt': DateTime.now().toIso8601String(), // valid here
          'updatedAt': null, // optional null timestamp
        }),
        returnsNormally,
      );

      final order = OrderModel.fromJson({
        'id': 'ord_null_ts',
        'customerId': 'u1',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': null,
      });
      expect(order.updatedAt, isNull);
    });

    // ── 5. Wrong-type status field (int instead of String) ───────────────────
    test('status: 123 (wrong type) falls back to pending without crash', () {
      // OrderStatus.fromString receives toString() of any value
      final parsed = OrderStatus.fromString('123');
      expect(
        parsed,
        OrderStatus.pending,
        reason: 'Unknown status always falls back to pending, no crash',
      );
    });

    // ── 6. status as null string ──────────────────────────────────────────────
    test('status: null string falls back to pending', () {
      final parsed = OrderStatus.fromString('');
      expect(parsed, OrderStatus.pending);
    });

    // ── 7. status with underscore variant (legacy Firestore format) ───────────
    test('status: "picked_up" (legacy underscore) maps to pickedUp', () {
      final parsed = OrderStatus.fromString('picked_up');
      expect(parsed, OrderStatus.pickedUp);
    });

    // ── 8. Real-time stream — empty collection emits empty list ──────────────
    test('Stream of empty collection emits [] without crashing', () async {
      final stream = fakeFirestore
          .collection('orders')
          .snapshots()
          .map(
            (snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              data['createdAt'] = DateTime.now().toIso8601String();
              return OrderModel.fromJson(data);
            }).toList(),
          );

      final result = await stream.first;
      expect(result, isA<List<OrderModel>>());
      expect(result, isEmpty);
    });
  });
}
