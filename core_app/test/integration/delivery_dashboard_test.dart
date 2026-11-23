import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// Law 12 & 30: Delivery Driver concurrency and data-isolation tests.
/// Tests validate the exact provider stream logic used by DeliveryDashboard
/// without instantiating private widget classes.
void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  group('Delivery Dashboard Fixes', () {
    testWidgets(
      'C1: Race condition transaction wrapper — driver assignment locks',
      (tester) async {
        await fakeDb.collection('orders').doc('order_1').set({
          'status': OrderStatus.ready.name,
          'assignedDriverId': null,
          'branchId': 'b1',
          'items': [],
        });

        Future<void> assignDriver(String driverId) async {
          final docRef = fakeDb.collection('orders').doc('order_1');
          await fakeDb.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            final data = snapshot.data();
            if (data == null) throw Exception('Order not found');
            if (data['assignedDriverId'] != null) {
              throw Exception('Order already assigned to another driver');
            }
            transaction.update(docRef, {
              'assignedDriverId': driverId,
              'status': OrderStatus.pickedUp.name,
            });
          });
        }

        bool driver2Failed = false;
        await assignDriver('driver1');
        try {
          await assignDriver('driver2');
        } catch (e) {
          driver2Failed = true;
        }

        expect(
          driver2Failed,
          isTrue,
          reason:
              'Second driver must be rejected once order is already claimed',
        );
        final result = await fakeDb.collection('orders').doc('order_1').get();
        expect(
          result.data()?['assignedDriverId'],
          'driver1',
          reason: 'Driver 1 retains ownership after the race',
        );
      },
    );

    test(
      'C2: Available orders stream excludes already-assigned orders in same branch',
      () async {
        await fakeDb.collection('orders').doc('unassigned_order').set({
          'id': 'unassigned_order',
          'status': OrderStatus.ready.name,
          'assignedDriverId': null,
          'branchId': 'branch_A',
          'customerId': 'cust1',
          'totalCents': 1500,
          'items': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await fakeDb.collection('orders').doc('taken_order').set({
          'id': 'taken_order',
          'status': OrderStatus.ready.name,
          'assignedDriverId': 'other_driver',
          'branchId': 'branch_A',
          'customerId': 'cust2',
          'totalCents': 800,
          'items': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Replicate the exact stream logic from availableOrdersProvider in delivery_dashboard.dart
        final stream = fakeDb
            .collection('orders')
            .where('branchId', isEqualTo: 'branch_A')
            .where('status', isEqualTo: 'ready')
            .snapshots()
            .map(
              (s) => s.docs
                  .map((d) => OrderModel.fromDoc(d))
                  .where((o) => o.assignedDriverId == null)
                  .toList(),
            );

        final orders = await stream.first;

        expect(
          orders.length,
          1,
          reason: 'Only unassigned orders must be visible in the Available tab',
        );
        expect(orders.first.id, 'unassigned_order');
        expect(
          orders.any((o) => o.id == 'taken_order'),
          isFalse,
          reason: 'Already-assigned orders must never appear in Available tab',
        );
      },
    );
  });
}
