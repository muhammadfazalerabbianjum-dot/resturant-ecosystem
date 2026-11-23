import 'package:core_ui/core_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/l10n/app_localizations.dart';

/// WHY: Revenue chart reads the last 7 days of delivered orders from Firestore
/// and groups them by day client-side. Law 10: cursor-based; data limited to
/// 200 docs max.
///
/// W8.7 (04-P1-QUERY): window + cap are NAMED constants beside their
/// precedents (streamOverviewStats 24 h window / kMenuMaxItemsSafetyCap).
const Duration kRevenueChartWindow = Duration(days: 7);
const int kRevenueChartDeliveredCap = 200;

/// W8.5 (04-P1-STREAM): the delivered-orders snapshot subscription lives in
/// this provider — NOT in build — so chart rebuilds (config refresh, parent
/// setState) no longer re-subscribe Firestore or reset the chart to a
/// spinner. The 7-day anchor is computed once per provider lifetime;
/// autoDispose re-anchors on the next mount (same lifecycle as
/// streamOverviewStats).
final deliveredRevenueProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((
      ref,
    ) async* {
      // D-057: the tenant constraint must be IN the query — `tenantOk()` tests
      // `resource.data`, so an unconstrained list read is denied outright.
      final tenantId = await requireTenantIdFromRef(ref, 'The revenue chart');
      final db = ref.watch(firestoreProvider);
      final sevenDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(kRevenueChartWindow),
      );
      yield* db
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where('status', isEqualTo: 'delivered')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .limit(kRevenueChartDeliveredCap) // Law 10: bounded query
          .snapshots();
    });

class RevenueChartWidget extends ConsumerWidget {
  const RevenueChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final currency = ref.watch(restaurantConfigProvider).valueOrNull?.currency;
    final revenueAsync = ref.watch(deliveredRevenueProvider);

    return revenueAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      // W8.5 fail-visible: the pre-conversion StreamBuilder had NO error
      // branch (a stream error silently rendered the "no revenue data" empty
      // state); errors now surface through the repo's mapper.
      error: (e, _) => SizedBox(
        height: 200,
        child: Center(
          child: Text(
            FirebaseExceptionMapper.map(e),
            style: TextStyle(color: BrandColors.of(context).error),
          ),
        ),
      ),
      data: (snap) {
        if (snap.docs.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                loc.noRevenueData,
                style: TextStyle(color: BrandColors.of(context).textSecondary),
              ),
            ),
          );
        }

        final dayTotals = <int, int>{};
        final now = DateTime.now();
        for (final doc in snap.docs) {
          final data = doc.data();
          final ts = data['createdAt'];
          final date = ts is Timestamp ? ts.toDate() : now;
          final offset = now
              .difference(DateTime(date.year, date.month, date.day))
              .inDays;
          if (offset < 7) {
            dayTotals[6 - offset] =
                (dayTotals[6 - offset] ?? 0) +
                ((data['totalCents'] as num?)?.toInt() ?? 0);
          }
        }

        final spots = List.generate(
          7,
          (i) => FlSpot(i.toDouble(), (dayTotals[i] ?? 0) / 100),
        );
        final maxY =
            (spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b) * 1.2)
                .ceilToDouble();

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: loc.revenueLast7Days,
                  child: Text(
                    loc.revenueLast7Days,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  // UX-2 (05-P2-A11Y-CHART): teeth chart exposes a data-table
                  // summary to screen readers ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â lines alone are color-only/visual-only..
                  child: Semantics(
                    container: true,
                    label:
                        '${loc.revenueLast7Days}: ${spots.asMap().entries.map((e) => '${DateFormat("EEE", loc.localeName).format(now.subtract(Duration(days: 6 - e.key)))}: ${formatCurrencyCents(e.value.y.toInt(), currencyCode: currency)}').join('; ')}',
                    child: SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: maxY == 0 ? 100 : maxY,
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, _) => Text(
                                  formatCurrencyCents(
                                    value.toInt(),
                                    currencyCode: currency,
                                  ),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final date = now.subtract(
                                    Duration(days: 6 - value.toInt()),
                                  );
                                  return Text(
                                    DateFormat(
                                      'E',
                                      loc.localeName,
                                    ).format(date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
