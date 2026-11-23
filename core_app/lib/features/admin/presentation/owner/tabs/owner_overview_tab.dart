import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/owner/tabs/panic_switch_banner.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final adminService = ref.watch(adminDataServiceProvider);
    final statsStream = adminService.streamOverviewStats();
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: Text(loc.ownerOverview)),
      body: StreamBuilder<AdminOverviewStats>(
        stream: statsStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            // L12: the KPI block previews as tile skeletons (UI-10 E2).
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TileSkeletons.stat(),
                  Gap.v16,
                  TileSkeletons.stat(),
                  Gap.v16,
                  TileSkeletons.stat(),
                ],
              ),
            );
          }
          final stats = snap.data!;
          // Scrollable: the three stacked metrics + banner no longer fit the
          // smallest supported viewport (the fixed Column overflowed by 16px).
          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              top: 16,
              right: 16,
              bottom: 90,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanicSwitchBanner(),
                Gap.v16,
                // UI-10 E1: the KPI block gets a section header + StatTile
                // metrics. DISPLAY ONLY — every number below comes verbatim
                // from [AdminOverviewStats]; nothing here derives, rounds or
                // re-formats money (p17 owns the analytics surface).
                SectionHeader(title: loc.ownerOverview),
                Gap.v16,
                StatTile(
                  label: loc.todaysOrders,
                  value: '${stats.todayOrders}',
                  icon: Icons.receipt_long,
                ),
                Gap.v16,
                StatTile(
                  label: loc.todaysRevenue,
                  value: formatAmount(stats.todayRevenue, currency),
                  icon: Icons.attach_money,
                ),
                Gap.v16,
                StatTile(
                  label: loc.activeOrders,
                  value: '${stats.activeOrders}',
                  icon: Icons.local_shipping,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
