import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/admin/domain/analytics_provider.dart';
import 'package:labs/features/admin/presentation/analytics/revenue_chart_widget.dart';
import 'package:labs/features/admin/presentation/analytics/top_items_chart_widget.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:core/core.dart' show UserRole;
import 'package:core_ui/core_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// UI-7 (p17 T-5): deep link to the operator's analytics console — the
/// BigQuery editor where `core_app/tool/analytics_funnel_queries.sql` (T-3)
/// runs and where the Looker Studio report is attached. The property- and
/// project-specific URL is operator console work; the exact pin-down steps
/// live in `tool_uilib/p17/RUNBOOK_ANALYTICS.md` (T-4).
const String kAnalyticsConsoleDeepLink =
    'https://console.cloud.google.com/bigquery';

/// Opens the analytics console (fire-and-forget from the button; never
/// throws into the UI — an unavailable link degrades to a snackbar).
Future<void> _openAnalyticsConsole(
  BuildContext context,
  AppLocalizations loc,
) async {
  try {
    final opened = await launchUrl(
      Uri.parse(kAnalyticsConsoleDeepLink),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.externalLinkUnavailable)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.externalLinkUnavailable)));
    }
  }
}

class AnalyticsSnapshot extends ConsumerWidget {
  const AnalyticsSnapshot({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.owner, UserRole.manager},
      builder: (_) => _buildSurface(context, ref),
    );
  }

  Widget _buildSurface(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final analyticsAsync = ref.watch(analyticsProvider);
    final currency = ref.watch(restaurantConfigProvider).valueOrNull?.currency;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: loc.analyticsOverview,
          child: Text(loc.analyticsOverview),
        ),
      ),
      // L5 fail-safe surface: loading is the library skeleton (never a bare
      // spinner), errors degrade to a message — the aggregate fetch itself
      // never throws (it yields zeros/[] instead).
      body: analyticsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SkeletonLoader.card(height: 104),
              Gap.v16,
              SkeletonLoader.card(height: 104),
              Gap.v16,
              SkeletonLoader.card(height: 220),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('${loc.error}: $e')),
        data: (snapshot) {
          final content = SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // T-5: headline KPIs as library StatTiles (token radius,
                // BrandColors text — L1/L12; replacing the raw Texts).
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: loc.todaysOrders,
                        value: '${snapshot.todaysOrders}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    Gap.h16,
                    Expanded(
                      child: StatTile(
                        label: loc.todaysRevenue,
                        value: formatAmount(
                          snapshot.todaysRevenue,
                          currency ?? 'USD',
                        ),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                Gap.v16,
                StatTile(
                  label: loc.activeOrders,
                  value: '${snapshot.activeOrders}',
                  icon: Icons.pending_actions_outlined,
                ),
                Gap.v24,
                // Charts kept as-is (T-5) — each carries its own ARB title.
                const RevenueChartWidget(),
                Gap.v16,
                const TopItemsChartWidget(),
                Gap.v24,
                // T-5: NEW per-dish counts for TODAY (aggregate-backed
                // provider — fail-safe to zeros/[]).
                SectionHeader(title: loc.topDishesToday),
                Gap.v8,
                _buildTopDishes(ref, loc),
                Gap.v24,
                // T-5: the abandoned-cart funnel lives in BigQuery/Looker
                // (console work — L4), so this section is an honest link +
                // freshness note, not an in-app chart over missing data.
                SectionHeader(title: loc.abandonedCarts),
                Gap.v8,
                BrandCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.externalDataDailyNote,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Gap.v16,
                      ElevatedButton.icon(
                        onPressed: () =>
                            unawaited(_openAnalyticsConsole(context, loc)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(64, 48),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(loc.openAnalyticsConsole),
                      ),
                    ],
                  ),
                ),
                Gap.v16,
              ],
            ),
          );
          if (analyticsAsync.isRefreshing) {
            return Stack(
              children: [
                content,
                const PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            );
          }
          return content;
        },
      ),
    );
  }

  /// T-5 per-dish section: skeleton while loading, the ranked StatTile rows
  /// when ready, the ARB empty state when today has no orders — and an error
  /// line if the provider itself faults (the fetch already degraded to []).
  Widget _buildTopDishes(WidgetRef ref, AppLocalizations loc) {
    final topDishesAsync = ref.watch(topDishesProvider);
    return topDishesAsync.when(
      loading: () => Column(
        children: [
          SkeletonLoader.card(height: 88),
          Gap.v8,
          SkeletonLoader.card(height: 88),
        ],
      ),
      error: (e, _) => Text(
        '${loc.error}: $e',
        style: TextStyle(color: Theme.of(ref.context).colorScheme.error),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Text(
            loc.noItemsData,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(ref.context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Gap.v8,
              StatTile(
                label: rows[i].dishName,
                value: '${rows[i].orderCount}',
                icon: Icons.restaurant_outlined,
              ),
            ],
          ],
        );
      },
    );
  }
}
