import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

/// UI-7 (p17 T-5): named caps beside the W8.7 precedent — Law 10 (bounded
/// reads). Firestore has no GROUP BY, so per-dish ranking runs client-side
/// over at most this many of today's orders; the dashboard renders at most
/// [kAnalyticsTopDishCap] rows.
const int kAnalyticsTopDishesQueryCap = 200;
const int kAnalyticsTopDishCap = 5;

/// Statuses the dashboard counts as ACTIVE — byte-identical to the pre-T-5
/// query (`whereIn` on confirmed/preparing/ready), so the number the owner
/// already watches does not move under this change.
const List<String> kAnalyticsActiveStatuses = <String>[
  'confirmed',
  'preparing',
  'ready',
];

/// One per-dish ranking row. [orderCount] is the quantity sold TODAY (the
/// same quantity aggregation [TopItemsChartWidget] does for its 7-day view).
class TopDishRow {
  const TopDishRow({required this.dishName, required this.orderCount});

  final String dishName;
  final int orderCount;
}

/// Holds the analytics snapshot for the Owner Dashboard.
class AnalyticsSnapshotData {
  final int todaysOrders;
  final int todaysRevenue;
  final int activeOrders;

  const AnalyticsSnapshotData({
    required this.todaysOrders,
    required this.todaysRevenue,
    required this.activeOrders,
  });
}

/// UI-7 (p17 T-5): today's headline numbers from a Firestore **aggregate**
/// (`count` + `sum('totalCents')`) — the count is NOT bounded by a
/// document-download cap, and the two aggregations run concurrently
/// (B5-11 waterfall guard).
///
/// Fail-safe (L5): any failure degrades to a zeroed snapshot — the dashboard
/// never throws on a missing aggregate. The best-effort log uses the same
/// double-fault guard as the telemetry layer (the logger itself can be
/// unavailable in tests/embeds).
/// D-057: `tenantId` is a REQUIRED input, not resolved here, because Firestore
/// rules are not filters — `tenantOk()` tests `resource.data`, so a list query
/// that does not carry the tenant constraint is DENIED outright (the P2-1a shell
/// proved exactly this: constrained 200/2 rows, unconstrained 403). Passing it in
/// keeps this function testable and makes a caller that forgot the tenant a
/// compile error instead of an empty dashboard.
Future<AnalyticsSnapshotData> fetchTodayAnalytics(
  FirebaseFirestore db, {
  required String tenantId,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final startOfDay = DateTime(clock.year, clock.month, clock.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  try {
    final results = await Future.wait([
      db
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .aggregate(sum('totalCents'), count())
          .get(),
      db
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where('status', whereIn: kAnalyticsActiveStatuses)
          .aggregate(count())
          .get(),
    ]);
    final todayAgg = results[0];
    final activeAgg = results[1];

    return AnalyticsSnapshotData(
      todaysOrders: todayAgg.count ?? 0,
      todaysRevenue: (todayAgg.getSum('totalCents') ?? 0).round(),
      activeOrders: activeAgg.count ?? 0,
    );
  } catch (e, stack) {
    try {
      await LoggerService().error(
        e,
        'fetchTodayAnalytics_failed',
        stack: stack,
      );
    } catch (_) {
      // Swallow — fail-safe means the caller still gets zeros (L5).
    }
    return const AnalyticsSnapshotData(
      todaysOrders: 0,
      todaysRevenue: 0,
      activeOrders: 0,
    );
  }
}

/// UI-7 (p17 T-5): per-dish ranking for TODAY — grouped client-side over the
/// bounded day window ([kAnalyticsTopDishesQueryCap]), sorted desc, capped at
/// [kAnalyticsTopDishCap].
///
/// Reads BOTH stored line shapes: the nested `{item:{...}, quantity}` that
/// [CartItemModel] writes and the flat `{name, quantity}` shape the existing
/// Top Items chart fixtures use — historical orders must not vanish from the
/// ranking. Fail-safe (L5): any failure yields an empty list.
Future<List<TopDishRow>> fetchTopDishes(
  FirebaseFirestore db, {
  required String tenantId,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final startOfDay = DateTime(clock.year, clock.month, clock.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  try {
    final snap = await db
        .collection('orders')
        // D-057: without this constraint the rules deny the whole list read.
        .where('tenantId', isEqualTo: tenantId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .limit(kAnalyticsTopDishesQueryCap)
        .get();

    final quantities = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final lines = data['items'] as List<dynamic>? ?? const [];
      for (final raw in lines) {
        if (raw is! Map) continue;
        final line = Map<String, dynamic>.from(raw);
        final nested = line['item'];
        final name = nested is Map
            ? nested['name'] as String?
            : line['name'] as String?;
        if (name == null || name.isEmpty) continue;
        final qty = (line['quantity'] as num?)?.toInt() ?? 1;
        if (qty <= 0) continue;
        quantities[name] = (quantities[name] ?? 0) + qty;
      }
    }

    final sorted = quantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in sorted.take(kAnalyticsTopDishCap))
        TopDishRow(dishName: entry.key, orderCount: entry.value),
    ];
  } catch (e, stack) {
    try {
      await LoggerService().error(e, 'fetchTopDishes_failed', stack: stack);
    } catch (_) {
      // Swallow — fail-safe means the caller still gets [] (L5).
    }
    return const [];
  }
}

/// T-5: the dashboard's headline numbers, read through the AGGREGATE fetch
/// above (fail-safe: a failed aggregate yields a zeroed snapshot, never an
/// error state — L5). Same autoDispose lifecycle the widget already had.
final analyticsProvider = StreamProvider.autoDispose<AnalyticsSnapshotData>((
  ref,
) async* {
  final tenantId = await requireTenantIdFromRef(ref, 'The analytics dashboard');
  final db = ref.watch(firestoreProvider);
  yield await fetchTodayAnalytics(db, tenantId: tenantId);
});

/// T-5: today's per-dish rows for the new "Top Dishes Today" section.
final topDishesProvider = FutureProvider.autoDispose<List<TopDishRow>>((
  ref,
) async {
  final tenantId = await requireTenantIdFromRef(ref, 'The analytics dashboard');
  final db = ref.watch(firestoreProvider);
  return fetchTopDishes(db, tenantId: tenantId);
});
