// UI-7 (p17) T-5 RED/GREEN — aggregate-backed dashboard data.
//
// Contract: WHITE_LABEL_p17_analytics1.md T-5 ("NEW per-dish order counts …
// via a Firestore aggregate query (cloud_firestore 6.3 aggregate)"), L4
// (no new dependencies; BigQuery/Looker stay console work) and L5 (fail-safe:
// the dashboard never throws on missing aggregates).
//
// What is pinned here:
//   * the headline numbers come from a real Firestore AGGREGATE (count + sum),
//     so they are NOT bounded by a document-download cap;
//   * the per-dish rows come from the bounded day window (Law 10) — Firestore
//     has no group-by and dish ids live inside an array-of-maps, so per-dish
//     ranking over full history is the BigQuery query in
//     `core_app/tool/analytics_funnel_queries.sql` (documented in the report);
//   * every failure path degrades to a zeroed/empty snapshot instead of a throw.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/analytics_provider.dart';
import 'package:mocktail/mocktail.dart';

class _ExplodingFirestore extends Mock implements FirebaseFirestore {}

/// D-057: every analytics query carries the tenant constraint, so every seed and
/// every call names one. `kOtherTenant` seeds a decoy that must never be counted.
const String kTenant = 'tenant_a';
const String kOtherTenant = 'tenant_other';

void main() {
  late FakeFirebaseFirestore db;
  final now = DateTime(2026, 8, 20, 12);
  final startOfDay = DateTime(now.year, now.month, now.day);

  setUp(() => db = FakeFirebaseFirestore());

  /// A CartItemModel-shaped JSON line, exactly as the order document stores it.
  Map<String, dynamic> line(String name, int qty) => {
    'item': {
      'id': name.toLowerCase().replaceAll(' ', '_'),
      'name': name,
      'priceCents': 1000,
    },
    'quantity': qty,
    'selectedOptions': <Map<String, dynamic>>[],
  };

  Future<void> seedOrder({
    required DateTime createdAt,
    required int totalCents,
    List<Map<String, dynamic>> items = const [],
    String status = 'confirmed',
  }) => db.collection('orders').add({
    'tenantId': kTenant,
    'createdAt': Timestamp.fromDate(createdAt),
    'totalCents': totalCents,
    'status': status,
    'items': items,
  });

  group('fetchTodayAnalytics — Firestore aggregate (count + sum)', () {
    test('counts and sums only TODAY orders', () async {
      await seedOrder(
        createdAt: startOfDay.add(const Duration(hours: 1)),
        totalCents: 1000,
      );
      await seedOrder(
        createdAt: startOfDay.add(const Duration(hours: 8)),
        totalCents: 2500,
      );
      // yesterday — must be excluded by the day window
      await seedOrder(
        createdAt: startOfDay.subtract(const Duration(hours: 3)),
        totalCents: 9999,
      );

      final snapshot = await fetchTodayAnalytics(
        db,
        tenantId: kTenant,
        now: now,
      );

      expect(snapshot.todaysOrders, 2);
      expect(snapshot.todaysRevenue, 3500);
    });

    test(
      'active orders are counted by status (aggregate, same window gate)',
      () async {
        await seedOrder(
          createdAt: startOfDay.add(const Duration(hours: 2)),
          totalCents: 100,
          status: 'confirmed',
        );
        await seedOrder(
          createdAt: startOfDay.add(const Duration(hours: 3)),
          totalCents: 100,
          status: 'preparing',
        );
        await seedOrder(
          createdAt: startOfDay.add(const Duration(hours: 4)),
          totalCents: 100,
          status: 'ready',
        );
        await seedOrder(createdAt: now, totalCents: 100, status: 'delivered');

        final snapshot = await fetchTodayAnalytics(
          db,
          tenantId: kTenant,
          now: now,
        );

        expect(snapshot.activeOrders, 3);
      },
    );

    test(
      'an empty collection is a zeroed snapshot (never null, never throw)',
      () async {
        final snapshot = await fetchTodayAnalytics(
          db,
          tenantId: kTenant,
          now: now,
        );

        expect(snapshot.todaysOrders, 0);
        expect(snapshot.todaysRevenue, 0);
        expect(snapshot.activeOrders, 0);
      },
    );

    test(
      'the headline count is NOT bounded by a document-download cap',
      () async {
        for (var i = 0; i < 250; i++) {
          await seedOrder(
            createdAt: startOfDay.add(Duration(minutes: i)),
            totalCents: 10,
          );
        }

        final snapshot = await fetchTodayAnalytics(
          db,
          tenantId: kTenant,
          now: now,
        );

        // A client-side `.get()` path would stop at its cap; the aggregate
        // counts every matching document.
        expect(snapshot.todaysOrders, 250);
        expect(snapshot.todaysRevenue, 2500);
      },
    );

    test('fail-safe: an exploding Firestore degrades to zeros', () async {
      final exploding = _ExplodingFirestore();
      when(() => exploding.collection(any())).thenThrow(Exception('offline'));

      final snapshot = await fetchTodayAnalytics(
        exploding,
        tenantId: kTenant,
        now: now,
      );

      expect(snapshot.todaysOrders, 0);
      expect(snapshot.todaysRevenue, 0);
      expect(snapshot.activeOrders, 0);
    });
  });

  group('fetchTopDishes — per-dish rows (bounded day window, Law 10)', () {
    test('groups today orders per dish, sorted desc, capped at 5', () async {
      await seedOrder(
        createdAt: startOfDay.add(const Duration(hours: 1)),
        totalCents: 3000,
        items: [line('Shawarma', 2), line('Ayran', 1)],
      );
      await seedOrder(
        createdAt: startOfDay.add(const Duration(hours: 2)),
        totalCents: 1500,
        items: [line('Shawarma', 1)],
      );
      for (final name in ['Falafel', 'Kebab', 'Baklava', 'Hummus']) {
        await seedOrder(
          createdAt: startOfDay.add(const Duration(hours: 3)),
          totalCents: 500,
          items: [line(name, 1)],
        );
      }
      // yesterday — excluded from today's ranking
      await seedOrder(
        createdAt: startOfDay.subtract(const Duration(hours: 5)),
        totalCents: 500,
        items: [line('Shawarma', 50)],
      );

      final rows = await fetchTopDishes(db, tenantId: kTenant, now: now);

      expect(rows, hasLength(kAnalyticsTopDishCap));
      expect(rows.first.dishName, 'Shawarma');
      // quantities are summed per dish across today's orders: 2 + 1
      expect(rows.first.orderCount, 3);
      expect(
        rows.map((r) => r.dishName).toList(),
        isNot(contains('ShawarmaYesterday')),
      );
    });

    test(
      'reads the legacy FLAT line shape too (chart-compatible fixture)',
      () async {
        // The existing Top Items chart and its fixtures store lines as
        // {name, quantity, priceCents} (flat) while OrderModel writes the
        // nested {item, quantity, selectedOptions} shape — the ranking must
        // rank correctly over BOTH, or a client's historical orders vanish.
        await db.collection('orders').add({
          'tenantId': kTenant,
          'createdAt': Timestamp.fromDate(now),
          'totalCents': 1500,
          'status': 'delivered',
          'items': [
            {'name': 'Shawarma', 'quantity': 2, 'priceCents': 750},
          ],
        });

        final rows = await fetchTopDishes(db, tenantId: kTenant, now: now);

        expect(rows, hasLength(1));
        expect(rows.first.dishName, 'Shawarma');
        expect(rows.first.orderCount, 2);
      },
    );

    test(
      'no orders today => empty list (the UI shows the empty state)',
      () async {
        expect(await fetchTopDishes(db, tenantId: kTenant, now: now), isEmpty);
      },
    );

    test(
      'fail-safe: an exploding Firestore degrades to an empty list',
      () async {
        final exploding = _ExplodingFirestore();
        when(() => exploding.collection(any())).thenThrow(Exception('offline'));

        expect(
          await fetchTopDishes(exploding, tenantId: kTenant, now: now),
          isEmpty,
        );
      },
    );
  });

  group('D-057 — the tenant constraint is in the QUERY, not left to rules', () {
    test("another tenant's orders are never counted", () async {
      await db.collection('orders').add({
        'tenantId': kOtherTenant,
        'createdAt': Timestamp.fromDate(now),
        'totalCents': 7777,
        'status': 'confirmed',
        'items': [line('Other Tenant Dish', 5)],
      });

      final snapshot = await fetchTodayAnalytics(
        db,
        tenantId: kTenant,
        now: now,
      );
      final rows = await fetchTopDishes(db, tenantId: kTenant, now: now);

      expect(snapshot.todaysOrders, 0);
      expect(snapshot.todaysRevenue, 0);
      expect(snapshot.activeOrders, 0);
      expect(rows, isEmpty);
    });

    test(
      'a missing tenant claim is an ERROR, never a dashboard of zeroes',
      () async {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            tenantIdProvider.overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(analyticsProvider.future),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('providers — the dashboard reads the aggregate, fail-safe', () {
    test('analyticsProvider yields the aggregate snapshot', () async {
      // The provider resolves its OWN clock (DateTime.now()), so this seed is
      // anchored to the real today — unlike the fetch tests above, which pass
      // an injectable `now`.
      await seedOrder(createdAt: DateTime.now(), totalCents: 4200);
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          tenantIdProvider.overrideWith((ref) async => kTenant),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(analyticsProvider.future);

      expect(snapshot.todaysOrders, greaterThanOrEqualTo(1));
      expect(snapshot.todaysRevenue, greaterThanOrEqualTo(4200));
    });

    test('topDishesProvider yields the per-dish rows', () async {
      await seedOrder(
        createdAt: DateTime.now(),
        totalCents: 2000,
        items: [line('Shawarma', 4)],
      );
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          tenantIdProvider.overrideWith((ref) async => kTenant),
        ],
      );
      addTearDown(container.dispose);

      final rows = await container.read(topDishesProvider.future);

      expect(rows, isNotEmpty);
      expect(rows.first.dishName, 'Shawarma');
      expect(rows.first.orderCount, 4);
    });
  });
}
