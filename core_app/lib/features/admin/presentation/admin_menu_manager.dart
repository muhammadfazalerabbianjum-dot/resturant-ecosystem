import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:core/core.dart' show UserRole;

import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/app/config/restaurant_config_service.dart';

class AdminMenuManager extends ConsumerWidget {
  const AdminMenuManager({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.owner, UserRole.manager},
      builder: (_) => _buildSurface(context, ref),
    );
  }

  Widget _buildSurface(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final menuAsync = ref.watch(mergedMenuProvider);
    // W9.3: explicit config currency — no silent USD default.
    final currency =
        ref.watch(restaurantConfigProvider).valueOrNull?.currency ?? 'USD';
    return Scaffold(
      appBar: AppBar(
        title: Semantics(label: loc.manageMenu, child: Text(loc.manageMenu)),
      ),
      body: menuAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, __) =>
              SkeletonLoader.block(width: double.infinity, height: 64),
        ),
        error: (e, _) => Center(child: Text('${loc.error}: $e')),
        data: (_) {
          final items = menuAsync.requireValue;
          if (items.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.restaurant_menu,
              title: loc.noMenuItemsYet,
              subtitle: '',
            );
          }
          final content = ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final item = items[i];
              return Semantics(
                label:
                    '${item.name}, ${formatAmount(item.priceCents, currency)}${item.isAvailable ? "" : ", ${loc.outOfStock}"}',
                child: MenuTile(
                  title: item.name,
                  cents: item.priceCents,
                  currencyCode: currency,
                  trailing: Semantics(
                    label: item.isAvailable ? loc.available : loc.outOfStock,
                    child: BrandBadge(
                      label: item.isAvailable ? loc.available : loc.outOfStock,
                      tone: item.isAvailable
                          ? BadgeTone.positive
                          : BadgeTone.negative,
                    ),
                  ),
                ),
              );
            },
          );
          if (menuAsync.isRefreshing) {
            return Stack(
              children: [
                content,
                const PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: SkeletonLoader(
                      width: 24,
                      height: 24,
                      borderRadius: 12,
                    ),
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
}
