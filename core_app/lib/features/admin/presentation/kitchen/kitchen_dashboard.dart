import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/app/l10n/status_role_labels.dart';

/// W8.5 (04-P1-STREAM): ONE live subscription per (branchId, statuses) key —
/// the Firestore stream is created in this provider, NOT in build, so widget
/// rebuilds (tab switches, parent setState) no longer re-subscribe the
/// listener or reset the snapshot to `waiting` (spinner flash + churn).
///
/// Family-key design note: the statuses dimension is carried as a
/// comma-joined string because record fields compare by `==` and a freshly
/// built List would defeat the family cache on every rebuild. Statuses are
/// code-fixed and never contain commas. Same (String, String) record shape
/// as delivery_dashboard.dart's myOrdersProvider.
final kitchenOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, (String, String)>((ref, key) {
      final (branchId, statusesKey) = key;
      return ref
          .watch(kitchenServiceProvider)
          .streamOrders(branchId, statusesKey.split(','));
    });

/// Statuses shown on the Preparing tab (W8.5 family-key dimension).
const String _kPreparingStatusesKey = 'confirmed,preparing';

/// Statuses shown on the Ready tab (W8.5 family-key dimension).
const String _kReadyStatusesKey = 'ready';

class KitchenDashboard extends ConsumerWidget {
  const KitchenDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.kitchen},
      builder: (_) => _buildDashboard(context, ref),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
      ),
      error: (e, _) => Scaffold(
        body: EmptyStateWidget(
          icon: Icons.store_mall_directory_outlined,
          title: FirebaseExceptionMapper.map(e),
          subtitle: '',
        ),
      ),
      data: (_) {
        final user = userAsync.requireValue;
        if (user == null) {
          return Scaffold(
            body: EmptyStateWidget(
              icon: Icons.store_mall_directory_outlined,
              title: loc.notSignedIn,
              subtitle: loc.signInKitchenAccount,
            ),
          );
        }
        final branchId = user.branchId;
        if (branchId == null || branchId.isEmpty) {
          return Scaffold(
            body: EmptyStateWidget(
              icon: Icons.store_mall_directory_outlined,
              title: loc.branchUnavailable,
              subtitle: loc.failedToLoadBranch,
            ),
          );
        }
        final content = _KitchenTabs(branchId: branchId);
        if (userAsync.isRefreshing) {
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
    );
  }
}

class _KitchenTabs extends StatefulWidget {
  final String branchId;
  const _KitchenTabs({required this.branchId});
  @override
  State<_KitchenTabs> createState() => _KitchenTabsState();
}

class _KitchenTabsState extends State<_KitchenTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final branchId = widget.branchId;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: loc.kitchenDashboardTitle,
          child: Text(loc.kitchenDashboardTitle),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Semantics(
            label: loc.kitchenDashboardTitle,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: const Icon(Icons.restaurant), text: loc.preparingTab),
                Tab(
                  icon: const Icon(Icons.check_circle_outline),
                  text: loc.readyTab,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PreparingTab(branchId: branchId),
          _ReadyTab(branchId: branchId),
        ],
      ),
    );
  }
}

class _PreparingTab extends ConsumerWidget {
  final String branchId;
  const _PreparingTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(
      kitchenOrdersProvider((branchId, _kPreparingStatusesKey)),
    );
    return _buildOrderList(context, ref, loc, ordersAsync);
  }

  Widget _buildOrderList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    AsyncValue<List<OrderModel>> ordersAsync,
  ) {
    return ordersAsync.when(
      // A3 (p22): ticket-list loading adopts the skeleton pattern instead of a
      // bare spinner — placeholder chrome at the ticket footprint.
      loading: () => _ticketSkeletonList(),
      error: (e, _) => Center(child: Text(FirebaseExceptionMapper.map(e))),
      data: (orders) {
        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: loc.noActiveOrders,
            subtitle: '',
          );
        }
        final content = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final order = orders[i];
            final canStart = order.status == OrderStatus.confirmed;
            final canReady = order.status == OrderStatus.preparing;
            // L12.3 entrance motion (A3): each ticket enters through the
            // library stagger. Kept PER ITEM — the family stream caps at
            // kKitchenOrdersStreamCap (200), so a single Column-wrapped
            // StaggeredEntrance would be unbounded eager layout work.
            return StaggeredEntrance(
              children: [
                BrandCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#${safeOrderToken(order.id)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (OrderSource.isPlatformOrder(
                                order.orderSource,
                              )) ...[
                                const SizedBox(width: 8),
                                BrandBadge(
                                  label: OrderSource.platformOf(
                                    order.orderSource,
                                  )!,
                                  tone: BadgeTone.neutral,
                                ),
                              ],
                            ],
                          ),
                          BrandBadge(
                            label: orderStatusLabel(loc, order.status),
                            tone: kitchenStatusTone(order.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Text(
                          loc.kitchenOrderItemLine(
                            item.item.name,
                            item.quantity.toString(),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          if (canStart)
                            BrandButton(
                              text: loc.startPreparing,
                              icon: Icons.play_arrow,
                              onPressed: () => _updateStatus(
                                context,
                                ref,
                                order.id,
                                OrderStatus.preparing,
                              ),
                            ),
                          if (canReady)
                            BrandButton(
                              text: loc.markReady,
                              icon: Icons.check,
                              onPressed: () => _updateStatus(
                                context,
                                ref,
                                order.id,
                                OrderStatus.ready,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
        // W8.5: a live stream in the data state is `active` with data — the
        // pre-conversion StreamBuilder overlaid the live-refresh chip exactly
        // in that state; rendering is preserved 1:1.
        return Stack(
          children: [
            content,
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: SizedBox(
                width: 24,
                height: 24,
                child: SkeletonLoader(width: 24, height: 24, borderRadius: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    OrderStatus newStatus,
  ) async {
    final kitchenService = ref.read(kitchenServiceProvider);
    try {
      await kitchenService.updateOrderStatus(orderId, newStatus);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
    }
  }
}

class _ReadyTab extends ConsumerWidget {
  final String branchId;
  const _ReadyTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(
      kitchenOrdersProvider((branchId, _kReadyStatusesKey)),
    );
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';
    return _buildReadyList(context, loc, ordersAsync, currency);
  }

  Widget _buildReadyList(
    BuildContext context,
    AppLocalizations loc,
    AsyncValue<List<OrderModel>> ordersAsync,
    String currency,
  ) {
    return ordersAsync.when(
      // A3 (p22): skeleton placeholders instead of a bare spinner.
      loading: () => _ticketSkeletonList(),
      error: (e, _) => Center(child: Text(FirebaseExceptionMapper.map(e))),
      data: (orders) {
        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: loc.noReadyOrders,
            subtitle: '',
          );
        }
        final content = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final order = orders[i];
            // A1 (p22): raw Card + ListTile composition replaced by the
            // library card; row layout keeps the exact information order.
            return StaggeredEntrance(
              children: [
                BrandCard(
                  // COLOR-1: "ready" card tint follows the client success hue.
                  color: BrandColors.of(context).success.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: BrandColors.of(context).success,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#${safeOrderToken(order.id)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (OrderSource.isPlatformOrder(
                                  order.orderSource,
                                )) ...[
                                  const SizedBox(width: 8),
                                  BrandBadge(
                                    label: OrderSource.platformOf(
                                      order.orderSource,
                                    )!,
                                    tone: BadgeTone.neutral,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              loc.itemsCount(order.items.length),
                              style: TextStyle(
                                color: BrandColors.of(context).textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatAmount(order.totalCents, currency),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
        // W8.5: a live stream in the data state is `active` with data — the
        // pre-conversion StreamBuilder overlaid the live-refresh chip exactly
        // in that state; rendering is preserved 1:1.
        return Stack(
          children: [
            content,
            const PositionedDirectional(
              top: 8,
              end: 8,
              child: SizedBox(
                width: 24,
                height: 24,
                child: SkeletonLoader(width: 24, height: 24, borderRadius: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A1 (p22): frozen `BrandBadge` tone table replaces the legacy `Chip` colors
/// (display-only mapping — COLOR-1's semantic hues survive through the badge
/// tones: warning = preparing/cooking, positive = ready/delivered,
/// negative = cancelled, neutral = everything else).
BadgeTone kitchenStatusTone(OrderStatus status) => switch (status) {
  OrderStatus.ready || OrderStatus.delivered => BadgeTone.positive,
  OrderStatus.cancelled => BadgeTone.negative,
  OrderStatus.preparing || OrderStatus.cooking => BadgeTone.warning,
  OrderStatus.pending ||
  OrderStatus.confirmed ||
  OrderStatus.pickedUp => BadgeTone.neutral,
};

/// A3 (p22): loading placeholders at the ticket footprint (three ticket-sized
/// skeleton blocks). The live-refresh overlay spinner is intentionally NOT
/// part of this swap — it signals background refresh over PRESENT data
/// (W8.5), where a skeleton would blank live tickets (see p22 report DECISIONS).
Widget _ticketSkeletonList() => ListView.separated(
  padding: const EdgeInsets.all(12),
  itemCount: 3,
  separatorBuilder: (_, __) => const SizedBox(height: 8),
  itemBuilder: (_, __) => SkeletonLoader.block(
    width: double.infinity,
    height: 160,
    borderRadius: BrandShapes.large,
  ),
);
