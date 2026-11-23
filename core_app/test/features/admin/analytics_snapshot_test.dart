import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';
import 'package:labs/features/admin/presentation/analytics/revenue_chart_widget.dart';
import 'package:labs/features/admin/presentation/analytics/top_items_chart_widget.dart';

/// Seeds [count] delivered orders into [fakeFirestore], spread across the
/// last [daysSpread] days, with random items and revenue amounts.
Future<void> _seedOrders(
  FakeFirebaseFirestore fakeFirestore, {
  int count = 52,
  int daysSpread = 7,
}) async {
  final now = DateTime.now();
  final batch = fakeFirestore.batch();

  final menuItems = [
    'Shawarma',
    'Burger',
    'Pizza',
    'Fries',
    'Salad',
    'Pasta',
    'Tacos',
    'Sushi',
    'Ramen',
    'Steak',
  ];

  for (int i = 0; i < count; i++) {
    final dayOffset = i % daysSpread;
    final createdAt = now.subtract(Duration(days: dayOffset, hours: i % 24));
    final itemName = menuItems[i % menuItems.length];
    final totalCents = 500 + (i * 97) % 5000; // spread from $5 to $55

    final ref = fakeFirestore.collection('orders').doc('order_$i');
    batch.set(ref, {
      'status': 'delivered',
      'totalCents': totalCents,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': 'user_${i % 10}',
      'branchId': 'branch_${i % 3}',
      'items': [
        {'name': itemName, 'quantity': (i % 3) + 1, 'priceCents': totalCents},
      ],
    });
  }

  await batch.commit();
}

/// Pumps any chart widget inside a ProviderScope with the fake firestore and a
/// default restaurant config so the widget's `firestoreProvider` /
/// `restaurantConfigProvider` reads resolve (the charts are ConsumerWidgets).
Future<void> _pumpChart(
  WidgetTester tester,
  FirebaseFirestore fakeFirestore,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
        firestoreProvider.overrideWithValue(fakeFirestore),
        restaurantConfigProvider.overrideWith(
          (_) => Stream<RestaurantConfigModel>.value(
            const RestaurantConfigModel(currency: 'USD'),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('Analytics Dashboard — Part 18 Boundary Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
    });

    // ──────────────────── REVENUE CHART ─────────────────────
    group('RevenueChartWidget', () {
      testWidgets('renders without exceptions with 52 seeded orders', (
        tester,
      ) async {
        await _seedOrders(fakeFirestore);

        await _pumpChart(tester, fakeFirestore, const RevenueChartWidget());

        // Initial pump shows shimmer/loading
        await tester.pump(const Duration(milliseconds: 100));

        // Second pump lets StreamBuilder resolve
        await tester.pump(const Duration(milliseconds: 100));

        // Critical: no uncaught exceptions from fl_chart math
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows "No revenue data" message when collection is empty', (
        tester,
      ) async {
        // No seed - empty firestore

        await _pumpChart(tester, fakeFirestore, const RevenueChartWidget());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Should display empty state text
        expect(find.textContaining('No revenue data'), findsOneWidget);
      });

      testWidgets(
        'handles single-day all-orders edge case without divide-by-zero',
        (tester) async {
          // Seed all 10 orders on the same day (today)
          final now = DateTime.now();
          for (int i = 0; i < 10; i++) {
            await fakeFirestore.collection('orders').add({
              'status': 'delivered',
              'totalCents': 1000,
              'createdAt': Timestamp.fromDate(now),
              'items': [
                {'name': 'Pizza', 'quantity': 1, 'priceCents': 1000},
              ],
            });
          }

          await _pumpChart(
            tester,
            fakeFirestore,
            const SizedBox(height: 400, child: RevenueChartWidget()),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
        },
      );
    });

    // ──────────────────── TOP ITEMS CHART ───────────────────
    group('TopItemsChartWidget', () {
      testWidgets('renders top 5 bar chart with 52 seeded orders', (
        tester,
      ) async {
        await _seedOrders(fakeFirestore);

        await _pumpChart(
          tester,
          fakeFirestore,
          TopItemsChartWidget(firestore: fakeFirestore),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows empty message when no orders exist', (tester) async {
        await _pumpChart(
          tester,
          fakeFirestore,
          TopItemsChartWidget(firestore: fakeFirestore),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('No'), findsOneWidget);
      });

      testWidgets('handles orders with missing items array gracefully', (
        tester,
      ) async {
        // Orders without an items field should not crash
        for (int i = 0; i < 5; i++) {
          await fakeFirestore.collection('orders').add({
            'status': 'delivered',
            'totalCents': 500,
            'createdAt': Timestamp.fromDate(DateTime.now()),
            // Deliberately no 'items' key
          });
        }

        await _pumpChart(
          tester,
          fakeFirestore,
          TopItemsChartWidget(firestore: fakeFirestore),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    });

    // ──────────────────── FULL ANALYTICS SNAPSHOT ───────────
    group('AnalyticsSnapshot', () {
      testWidgets(
        'renders full screen with KPI cards and charts without crashing',
        (tester) async {
          await _seedOrders(fakeFirestore, count: 52);

          // Seed reservations
          await fakeFirestore.collection('reservations').add({
            'startTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 3)),
            ),
          });

          // Seed online staff
          await fakeFirestore.collection('presence').add({'isOnline': true});

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
                firestoreProvider.overrideWithValue(fakeFirestore),
                // W2.9: AnalyticsSnapshot is owner/manager-gated — authorize.
                currentUserProvider.overrideWith(
                  (ref) async =>
                      const UserModel(id: 'u1', role: UserRole.owner),
                ),
                restaurantConfigProvider.overrideWith(
                  (_) => Stream<RestaurantConfigModel>.value(
                    const RestaurantConfigModel(currency: 'USD'),
                  ),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: AnalyticsSnapshot(),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
