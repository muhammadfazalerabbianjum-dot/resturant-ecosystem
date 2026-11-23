import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/features/admin/presentation/owner/tabs/confirm_destructive_dialog.dart';
import 'package:labs/features/admin/presentation/owner/tabs/menu_item_editor.dart';
import 'package:labs/l10n/app_localizations.dart';

class OwnerMenuTab extends ConsumerWidget {
  const OwnerMenuTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final adminService = ref.read(adminDataServiceProvider);
    final globalStream = adminService.streamGlobalMenu();
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.globalMenu),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: loc.addItem,
            // E1 F3-13: the library sheet (E-DEC moneyConfirming: false — the
            // editor is admin data entry, no charge is confirmed here; the
            // barrier stays dismissable exactly as today, L14).
            onPressed: () => BrandSheet.show(
              context,
              barrierDismissible: true,
              builder: (_) =>
                  BrandSheet(title: loc.addItem, child: const MenuItemEditor()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<MenuItemModel>>(
        stream: globalStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: SkeletonLoader.block(width: double.infinity, height: 64),
            );
          }
          final items = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.only(
              left: 12,
              top: 12,
              right: 12,
              bottom: 90,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final item = items[i];
              // E1 F3-10/L13: MenuTile renders the same moneyCents string that
              // formatAmount produced (formatAmount is a thin delegate), and
              // the screen-reader label keeps the price + availability.
              return Semantics(
                label:
                    '${item.name}, ${formatAmount(item.priceCents, currency)}'
                    '${item.isAvailable ? "" : ", ${loc.outOfStock}"}',
                child: MenuTile(
                  title: item.name,
                  cents: item.priceCents,
                  currencyCode: currency,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item.isAvailable,
                        onChanged: (v) =>
                            adminService.toggleMenuItemAvailability(item.id, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: loc.editMenuItem,
                        onPressed: () => BrandSheet.show(
                          context,
                          barrierDismissible: true,
                          builder: (_) => BrandSheet(
                            title: loc.editItem,
                            child: MenuItemEditor(existing: item),
                          ),
                        ),
                      ),
                      // UX-2 (05-P2-UX-CONFIRM): destructive delete must be
                      // confirmed before the menu item is mutated..
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: BrandColors.of(context).error,
                        ),
                        tooltip: loc.deleteMenuItem,
                        onPressed: () async {
                          final ok = await confirmDestructive(
                            context,
                            loc.deleteMenuItem,
                            loc.deleteMenuItemConfirm,
                          );
                          if (ok == true) {
                            await adminService.deleteMenuItem(item.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
