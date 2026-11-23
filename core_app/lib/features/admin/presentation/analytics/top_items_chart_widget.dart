import 'package:core_ui/core_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/l10n/app_localizations.dart';

/// WHY: Top Items bar chart aggregates CartItemModel.name quantities from
/// recently delivered orders to surface best-selling dishes to the owner.
class TopItemsChartWidget extends ConsumerWidget {
  final FirebaseFirestore? firestore;
  const TopItemsChartWidget({super.key, this.firestore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final FirebaseFirestore db = firestore ?? ref.watch(firestoreProvider);
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                loc.noItemOrdersData,
                style: TextStyle(color: BrandColors.of(context).textSecondary),
              ),
            ),
          );
        }

        final counts = <String, int>{};
        for (final doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final name = (itemMap['name'] as String?) ?? 'Unknown';
            final qty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
            counts[name] = (counts[name] ?? 0) + qty;
          }
        }

        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = sorted.take(5).toList();

        if (top5.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                loc.noItemsData,
                style: TextStyle(color: BrandColors.of(context).textSecondary),
              ),
            ),
          );
        }

        // COLOR-1 / W10.4: chart series colors read from the client palette
        // (BrandColors) instead of raw Color(0x...) literals — mapping:
        // orange→accent, teal→success, purple→secondary, blue→warning.
        final brand = BrandColors.of(context);
        final colors = [
          Theme.of(context).colorScheme.primary,
          brand.accent,
          brand.success,
          brand.secondary,
          brand.warning,
        ];

        final maxY = (top5.first.value * 1.2).ceilToDouble();

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
                  label: loc.topItemsLast7Days,
                  child: Text(
                    loc.topItemsLast7Days,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  // UX-2 (05-P2-A11Y-CHART): teeth chart exposes a data-table
                  // summary to screen readers — bars alone are color-only/visual-only.
                  child: Semantics(
                    container: true,
                    label:
                        '${loc.topItemsLast7Days}: ${top5.map((e) => '${e.key}, ${e.value}').join('; ')}',
                    child: BarChart(
                      BarChartData(
                        maxY: maxY == 0 ? 10 : maxY,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= top5.length) {
                                  return const SizedBox();
                                }
                                final name = top5[idx].key;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    name.length > 8
                                        ? '${name.substring(0, 7)}…'
                                        : name,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, _) => Text(
                                '${value.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        barGroups: List.generate(top5.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: top5[i].value.toDouble(),
                                color: colors[i % colors.length],
                                width: 24,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        }),
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
