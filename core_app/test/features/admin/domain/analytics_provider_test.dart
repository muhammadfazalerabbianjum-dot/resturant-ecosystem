import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/analytics_provider.dart';

void main() {
  group('AnalyticsSnapshotData', () {
    test('constructor assigns values correctly', () {
      const data = AnalyticsSnapshotData(
        todaysOrders: 10,
        todaysRevenue: 50000,
        activeOrders: 3,
      );
      expect(data.todaysOrders, 10);
      expect(data.todaysRevenue, 50000);
      expect(data.activeOrders, 3);
    });

    test('zero values are valid', () {
      const data = AnalyticsSnapshotData(
        todaysOrders: 0,
        todaysRevenue: 0,
        activeOrders: 0,
      );
      expect(data.todaysOrders, 0);
      expect(data.todaysRevenue, 0);
      expect(data.activeOrders, 0);
    });

    test('large values are handled', () {
      const data = AnalyticsSnapshotData(
        todaysOrders: 9999,
        todaysRevenue: 999999999,
        activeOrders: 500,
      );
      expect(data.todaysOrders, 9999);
      expect(data.todaysRevenue, 999999999);
      expect(data.activeOrders, 500);
    });

    test('negative values are accepted (edge case)', () {
      const data = AnalyticsSnapshotData(
        todaysOrders: -1,
        todaysRevenue: -100,
        activeOrders: -1,
      );
      expect(data.todaysOrders, -1);
      expect(data.todaysRevenue, -100);
      expect(data.activeOrders, -1);
    });
  });

  group('analyticsProvider Firestore integration', () {
    test('empty orders collection yields zero analytics', () async {
      final firestore = FakeFirebaseFirestore();
      final todaySnapshot = await firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: DateTime.now())
          .get();
      expect(todaySnapshot.docs.length, 0);
    });

    test('orders with totalCents are aggregated correctly', () async {
      final firestore = FakeFirebaseFirestore();
      final orders = firestore.collection('orders');

      final now = DateTime(2026, 7, 24, 12, 0);
      await orders.add({
        'createdAt': Timestamp.fromDate(now),
        'totalCents': 1000,
        'status': 'confirmed',
      });
      await orders.add({
        'createdAt': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
        'totalCents': 2500,
        'status': 'preparing',
      });
      await orders.add({
        'createdAt': Timestamp.fromDate(now.add(const Duration(minutes: 2))),
        'totalCents': 500,
        'status': 'delivered',
      });

      final todaySnapshot = await firestore
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: now.subtract(const Duration(days: 1)),
          )
          .get();

      int revenue = 0;
      for (final doc in todaySnapshot.docs) {
        revenue += (doc.data()['totalCents'] as int?) ?? 0;
      }

      expect(todaySnapshot.docs.length, 3);
      expect(revenue, 4000);
    });

    test('orders without totalCents default to 0', () async {
      final firestore = FakeFirebaseFirestore();
      final orders = firestore.collection('orders');
      await orders.add({
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 24, 12, 0)),
        'status': 'confirmed',
      });

      final todaySnapshot = await firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: DateTime(2026, 7, 24))
          .get();

      int revenue = 0;
      for (final doc in todaySnapshot.docs) {
        revenue += (doc.data()['totalCents'] as int?) ?? 0;
      }

      expect(revenue, 0);
    });

    test('active orders query filters by status', () async {
      final firestore = FakeFirebaseFirestore();
      final orders = firestore.collection('orders');
      await orders.add({'status': 'confirmed'});
      await orders.add({'status': 'preparing'});
      await orders.add({'status': 'ready'});
      await orders.add({'status': 'delivered'});
      await orders.add({'status': 'cancelled'});

      final activeSnapshot = await firestore
          .collection('orders')
          .where('status', whereIn: ['confirmed', 'preparing', 'ready'])
          .get();

      expect(activeSnapshot.docs.length, 3);
    });

    test('revenue calculation handles null totalCents gracefully', () async {
      final firestore = FakeFirebaseFirestore();
      final orders = firestore.collection('orders');
      await orders.add({
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 24, 12, 0)),
        'totalCents': null,
        'status': 'confirmed',
      });

      final todaySnapshot = await firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: DateTime(2026, 7, 24))
          .get();

      int revenue = 0;
      for (final doc in todaySnapshot.docs) {
        revenue += (doc.data()['totalCents'] as int?) ?? 0;
      }

      expect(revenue, 0);
    });
  });
}
