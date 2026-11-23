import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import '../domain/order_model.dart';
import 'order_provider.dart';

/// Presentational grouping of the order history (p20 A1) — DISPLAY ONLY.
/// The order's own state machine, timers and listeners are untouched (L16).
enum OrderHistoryGroup { active, delivered, cancelled }

/// PURE `OrderStatus -> OrderHistoryGroup` mapping. Exhaustive: a new status
/// must be classified here rather than silently landing in a bucket.
OrderHistoryGroup orderHistoryGroupFor(OrderStatus status) => switch (status) {
  OrderStatus.pending ||
  OrderStatus.confirmed ||
  OrderStatus.preparing ||
  OrderStatus.cooking ||
  OrderStatus.ready ||
  OrderStatus.pickedUp => OrderHistoryGroup.active,
  OrderStatus.delivered => OrderHistoryGroup.delivered,
  OrderStatus.cancelled => OrderHistoryGroup.cancelled,
};

/// PURE `OrderStatus -> TileStatus` mapping for the row badge.
TileStatus orderHistoryTileStatusFor(OrderStatus status) => switch (status) {
  OrderStatus.pending => TileStatus.pending,
  OrderStatus.confirmed => TileStatus.pending,
  OrderStatus.preparing => TileStatus.pending,
  OrderStatus.cooking => TileStatus.pending,
  OrderStatus.ready => TileStatus.pending,
  OrderStatus.pickedUp => TileStatus.pending,
  OrderStatus.delivered => TileStatus.ok,
  OrderStatus.cancelled => TileStatus.failed,
};

/// The row badge tone — resolved through the frozen [StatusTile.toneFor] table
/// so the fleet keeps ONE tri-state tone mapping.
BadgeTone orderHistoryToneFor(OrderStatus status) =>
    StatusTile.toneFor(orderHistoryTileStatusFor(status));

/// Localized group header. Existing `AppLocalizations` keys only — no new
/// strings are introduced, so the l10n en+ar parity surface is untouched.
String orderHistoryGroupLabel(AppLocalizations loc, OrderHistoryGroup group) =>
    switch (group) {
      OrderHistoryGroup.active => loc.activeOrders,
      OrderHistoryGroup.delivered => loc.orderStatus_delivered,
      OrderHistoryGroup.cancelled => loc.orderStatus_cancelled,
    };

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(userOrdersProvider);
    // Multi-app (Law 3): money is formatted through the shared [moneyCents]
    // helper driven by the restaurant's configured currency — never a literal
    // symbol baked into this screen.
    final currencyCode = ref
        .watch(restaurantConfigProvider)
        .valueOrNull
        ?.currency;

    return Scaffold(
      appBar: AppBar(title: Text(loc.orderHistory)),
      body: ordersAsync.when(
        loading: () => const _OrderHistorySkeleton(),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              loc.couldNotLoadOrdersRetry,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (orders) => orders.isEmpty
            ? EmptyStateWidget(
                icon: Icons.history,
                title: loc.noOrdersYet,
                subtitle: loc.orderNow,
                ctaText: loc.orderNow,
                onCtaPressed: () => context.goNamed(RouteNames.menu),
              )
            : _OrderHistoryList(orders: orders, currencyCode: currencyCode),
      ),
    );
  }
}

/// Loading state (L12.4): the documented tile-skeleton footprint per row —
/// [TileSkeletons.setting] is the SettingTile list-row footprint (72 high).
class _OrderHistorySkeleton extends StatelessWidget {
  const _OrderHistorySkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppDimensions.paddingM),
    children: [
      for (var i = 0; i < 6; i++) ...[TileSkeletons.setting(), Gap.v8],
    ],
  );
}

/// The grouped history: one [SectionHeader] per status group, one row per
/// order, entering through [StaggeredEntrance] (L12.3). Bounded by design: the
/// repository stream is capped at 20 orders (`getUserOrders` → `.limit(20)`),
/// so the Column inside the entrance animation is never unbounded work.
class _OrderHistoryList extends StatelessWidget {
  const _OrderHistoryList({required this.orders, required this.currencyCode});

  final List<OrderModel> orders;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final grouped = <OrderHistoryGroup, List<OrderModel>>{};
    for (final order in orders) {
      grouped
          .putIfAbsent(orderHistoryGroupFor(order.status), () => [])
          .add(order);
    }

    final children = <Widget>[];
    for (final group in OrderHistoryGroup.values) {
      final groupOrders = grouped[group];
      if (groupOrders == null) continue;
      children
        ..add(SectionHeader(title: orderHistoryGroupLabel(loc, group)))
        ..add(Gap.v8);
      for (final order in groupOrders) {
        children
          ..add(_OrderHistoryRow(order: order, currencyCode: currencyCode))
          ..add(Gap.v8);
      }
      children.add(Gap.v16);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: StaggeredEntrance(children: children),
    );
  }
}

/// One order row: a [SettingTile] composition carrying the state badge
/// ([BrandBadge], tone from the frozen [StatusTile] table) and a display-only
/// [PriceTag] total (L13: cents forwarded verbatim, never recomputed). The
/// composed Semantics label of the pre-p20 row is preserved verbatim (L14).
class _OrderHistoryRow extends StatelessWidget {
  const _OrderHistoryRow({required this.order, required this.currencyCode});

  final OrderModel order;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final statusLabel = orderStatusLabel(loc, order.status);
    final amountLabel = moneyCents(
      order.totalCents,
      currencyCode: currencyCode,
    );
    final orderToken = safeOrderToken(order.id);

    return Semantics(
      label: '${loc.orderNumber(orderToken)}, $statusLabel, $amountLabel',
      button: true,
      child: SettingTile(
        icon: Icons.receipt_long,
        title: loc.orderNumberShort(orderToken),
        subtitle: statusLabel,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PriceTag(cents: order.totalCents, currencyCode: currencyCode),
            Gap.h8,
            BrandBadge(
              label: statusLabel,
              tone: orderHistoryToneFor(order.status),
            ),
          ],
        ),
        onTap: () => context.goNamed(
          RouteNames.orderTracker,
          pathParameters: {'orderId': order.id},
        ),
      ),
    );
  }
}
