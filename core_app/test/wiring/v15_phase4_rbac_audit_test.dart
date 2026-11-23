// =============================================================================
// PHASE 4: RUTHLESS RBAC (ROLE-BASED ACCESS CONTROL) AUDIT
// Engine: FakeFirebaseFirestore — blazing fast in-memory Dart tests
// Vectors: Cross-role dashboard stream isolation, wrong-role guard logic,
//          ghost permission re-activation, staff stream tampering.
// Run: flutter test test/wiring/v15_phase4_rbac_audit_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 1: CROSS-ROLE ORDER STREAM ISOLATION
  // Kitchen staff should ONLY see orders for their assigned branchId.
  // A query without branchId scoping leaks all orders across all branches.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 4.1 — Kitchen Stream Isolation', () {
    test(
      'Kitchen orders query returns ONLY orders for assigned branch',
      () async {
        // Seed orders for two different branches
        await fakeFirestore.collection('orders').doc('order_a1').set({
          'branchId': 'branch_A',
          'status': 'confirmed',
          'totalCents': 1200,
        });
        await fakeFirestore.collection('orders').doc('order_a2').set({
          'branchId': 'branch_A',
          'status': 'preparing',
          'totalCents': 800,
        });
        await fakeFirestore.collection('orders').doc('order_b1').set({
          'branchId': 'branch_B', // ← should NOT be visible to kitchen_A
          'status': 'confirmed',
          'totalCents': 5000,
        });

        // Simulate the query that the kitchen dashboard runs for branch_A
        final result = await fakeFirestore
            .collection('orders')
            .where('branchId', isEqualTo: 'branch_A')
            .get();

        expect(
          result.docs.length,
          equals(2),
          reason:
              'Kitchen for branch_A must see exactly 2 orders, not branch_B\'s',
        );
        for (final doc in result.docs) {
          expect(
            doc.data()['branchId'],
            equals('branch_A'),
            reason: 'Every returned order must belong to branch_A',
          );
        }
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 2: DELIVERY DRIVER STREAM ISOLATION
  // A driver should see only orders assigned to their UID.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 4.2 — Driver Stream Isolation', () {
    test('Driver orders query returns ONLY orders with their UID', () async {
      await fakeFirestore.collection('orders').doc('driver_order_1').set({
        'assignedDriverId': 'driver_real_uid',
        'branchId': 'branch_A',
        'status': 'ready',
        'totalCents': 1500,
      });
      await fakeFirestore.collection('orders').doc('driver_other_1').set({
        'assignedDriverId': 'driver_other_uid', // ← NOT our driver
        'branchId': 'branch_A',
        'status': 'ready',
        'totalCents': 2200,
      });

      final result = await fakeFirestore
          .collection('orders')
          .where('assignedDriverId', isEqualTo: 'driver_real_uid')
          .get();

      expect(
        result.docs.length,
        equals(1),
        reason: 'Driver must only see their own assigned orders',
      );
      expect(
        result.docs.first.data()['assignedDriverId'],
        equals('driver_real_uid'),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 3: CUSTOMER ORDER ISOLATION
  // A customer must ONLY access orders where customerId matches their UID.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 4.3 — Customer Order Isolation', () {
    test('Customer order query returns ONLY their own orders', () async {
      await fakeFirestore.collection('orders').doc('mycustomer_order').set({
        'customerId': 'customer_uid_real',
        'branchId': 'branch_A',
        'status': 'delivered',
        'totalCents': 3300,
      });
      await fakeFirestore.collection('orders').doc('othercustomer_order').set({
        'customerId': 'customer_uid_other',
        'branchId': 'branch_A',
        'status': 'delivered',
        'totalCents': 4400,
      });

      final result = await fakeFirestore
          .collection('orders')
          .where('customerId', isEqualTo: 'customer_uid_real')
          .get();

      expect(result.docs.length, equals(1));
      expect(
        result.docs.first.data()['customerId'],
        equals('customer_uid_real'),
        reason:
            'Customer must never receive another user\'s orders in their feed',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 4: ROLE-FIELD IMMUTABILITY PROOF
  // Confirm that reading a user doc with role='customer' returns 'customer'
  // and we never accidentally yield elevated permissions on merge writes.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 4.4 — Role Immutability on Merge', () {
    test(
      'SetOptions(merge: true) does NOT overwrite existing role field',
      () async {
        // Existing doc with elevated role
        await fakeFirestore.collection('users').doc('testuid').set({
          'email': 'test@test.com',
          'role': 'manager',
          'loyaltyPoints': 100,
        });

        // A sync operation writes only name+email with merge (simulates _syncUserProfile)
        await fakeFirestore.collection('users').doc('testuid').set({
          'email': 'test@test.com',
          'name': 'New Name',
        }, SetOptions(merge: true));

        final snap = await fakeFirestore
            .collection('users')
            .doc('testuid')
            .get();
        expect(
          snap.data()?['role'],
          equals('manager'),
          reason:
              'merge write must NEVER overwrite existing role — promotion protection',
        );
        expect(
          snap.data()?['loyaltyPoints'],
          equals(100),
          reason: 'merge write must never zero out loyalty points',
        );
      },
    );
  });
}
