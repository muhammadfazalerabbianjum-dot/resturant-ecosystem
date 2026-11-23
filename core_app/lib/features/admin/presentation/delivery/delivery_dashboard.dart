import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/driver/proof_of_delivery_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';

/// (driverUid, branchId) — b10 P-2: [DeliveryService.myOrders] is
/// branch-scoped, so the family key carries both values.
final myOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, (String, String)>((ref, key) {
      final (driverUid, branchId) = key;
      return ref.read(deliveryServiceProvider).myOrders(driverUid, branchId);
    });

final availableOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, String>((ref, branchId) {
      return ref.read(deliveryServiceProvider).availableOrders(branchId);
    });

class DeliveryDashboard extends ConsumerWidget {
  const DeliveryDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.delivery},
      builder: (_) => _buildDashboard(context, ref),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final loc = AppLocalizations.of(context);

    return userAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text(loc.authError(FirebaseExceptionMapper.map(e))),
        ),
      ),
      data: (_) {
        final user = userAsync.requireValue;
        if (user == null) {
          return Scaffold(body: Center(child: Text(loc.notSignedIn)));
        }
        final branchId = user.branchId;
        if (branchId == null || branchId.isEmpty) {
          return Scaffold(
            body: Center(child: Text(loc.noBranchAssignedContactManager)),
          );
        }
        final content = _DeliveryTabs(branchId: branchId, driverUid: user.id);
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

class _DeliveryTabs extends StatefulWidget {
  final String branchId;
  final String driverUid;
  const _DeliveryTabs({required this.branchId, required this.driverUid});

  @override
  State<_DeliveryTabs> createState() => _DeliveryTabsState();
}

class _DeliveryTabsState extends State<_DeliveryTabs>
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
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.deliveryDashboardTitle),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.delivery_dining), text: loc.myOrdersTab),
            Tab(icon: const Icon(Icons.inbox), text: loc.availableTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyOrdersTab(driverUid: widget.driverUid, branchId: widget.branchId),
          _AvailableOrdersTab(
            branchId: widget.branchId,
            driverUid: widget.driverUid,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── MY ORDERS ─────────────────────────────────

class _MyOrdersTab extends ConsumerWidget {
  final String driverUid;
  final String branchId;
  const _MyOrdersTab({required this.driverUid, required this.branchId});

  Future<void> _markDelivered(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    final loc = AppLocalizations.of(context);
    // A4 (p22): the POD gate adopts the library dialog. moneyConfirming
    // DECISION (recorded in the p22 report): this barrier confirms a
    // settlement-triggering delivery, so it keeps the L25 non-dismissable
    // default (barrierDismissible: false — identical to the legacy dialog);
    // cancel stays a deliberate button, never a barrier tap.
    final isarSuccess = await BrandDialog.show<bool>(
      context,
      builder: (dialogContext) => BrandDialog(
        title: loc.captureProofOfDelivery,
        // No confirm action — the PROOF button is the confirm path.
        cancelLabel: loc.cancel,
        // The pop itself is the cancel effect (legacy pop(false) behaviour);
        // `isarSuccess == true` below keeps the identical guard.
        onCancel: () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.cannotBeUndone, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ProofOfDeliveryButton(
              orderId: orderId,
              driverId: driverUid,
              onSuccess: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (isarSuccess == true) {
      try {
        await ref.read(deliveryServiceProvider).stopGpsTracking();
      } on Exception catch (e, stack) {
        final logger = ref.read(loggerProvider);
        await logger.error(e, 'stop_gps_failed_on_delivered', stack: stack);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FirebaseExceptionMapper.map(e))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(myOrdersProvider((driverUid, branchId)));
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return ordersAsync.when(
      // A3 (p22): skeleton placeholders instead of a bare spinner.
      loading: () => _deliverySkeletonList(),
      error: (e, _) => Center(child: Text(FirebaseExceptionMapper.map(e))),
      data: (_) {
        final orders = ordersAsync.requireValue;
        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.local_shipping_outlined,
            title: loc.noActiveDeliveries,
            subtitle: '',
          );
        }
        final content = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final order = orders[i];
            // A1 (p22): raw Card replaced by the library ticket card;
            // L12.3 entrance per item (stream capped at kOrdersStreamCap —
            // a single Column-wrapped stagger would be unbounded layout work).
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
                          _statusBadge(context, order.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${loc.itemsCount(order.items.length)} · ${formatAmount(order.totalCents, currency)}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          if (order.status == OrderStatus.pickedUp)
                            BrandButton(
                              text: loc.goLiveGPS,
                              icon: Icons.sensors,
                              onPressed: () async {
                                final service = ref.read(
                                  deliveryServiceProvider,
                                );
                                try {
                                  await service.startGpsTracking(order.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.gpsLivestreamingMessage,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e, stack) {
                                  final logger = ref.read(loggerProvider);
                                  await logger.error(
                                    e,
                                    'start_gps_failed',
                                    stack: stack,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          FirebaseExceptionMapper.map(e),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          if (order.customerLocation != null)
                            BrandButton(
                              text: loc.navigateToCustomer,
                              icon: Icons.navigation,
                              onPressed: () async {
                                final lat = order.customerLocation!.latitude;
                                final lng = order.customerLocation!.longitude;
                                final url = Uri.parse(
                                  'google.navigation:q=$lat,$lng',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                } else {
                                  final fallback = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                  );
                                  unawaited(launchUrl(fallback));
                                }
                              },
                            ),
                          // PERF-7: only a `pickedUp` order is actually
                          // deliverable — `OrderStatus.canTransitionTo(delivered)`
                          // permits the edge from `pickedUp` alone, so rendering
                          // this for a `ready` order offered a button that
                          // ALWAYS failed with "Invalid status transition:
                          // ready -> delivered" (the domain guard is the
                          // authority; the UI must not offer the dead end).
                          if (order.status == OrderStatus.pickedUp)
                            BrandButton(
                              text: loc.markDelivered,
                              icon: Icons.check,
                              onPressed: () =>
                                  _markDelivered(context, ref, order.id),
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
        if (ordersAsync.isRefreshing) {
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

  Widget _statusBadge(BuildContext context, OrderStatus status) {
    final loc = AppLocalizations.of(context);
    // A1 (p22): raw Chip with `Colors.orange`/`Colors.blue` replaced by the
    // frozen badge tone table (COLOR-1 — token hues only, no raw colours).
    final (tone, label) = switch (status) {
      OrderStatus.ready => (BadgeTone.warning, loc.readyForPickup),
      OrderStatus.pickedUp => (BadgeTone.neutral, loc.enRoute),
      _ => (deliveryStatusTone(status), orderStatusLabel(loc, status)),
    };
    return BrandBadge(label: label, tone: tone);
  }
}

/// A1 (p22): frozen `BrandBadge` tone table for delivery statuses (display
/// only — the status write path is untouched, L17).
BadgeTone deliveryStatusTone(OrderStatus status) => switch (status) {
  OrderStatus.ready => BadgeTone.warning,
  OrderStatus.delivered => BadgeTone.positive,
  OrderStatus.cancelled => BadgeTone.negative,
  OrderStatus.pending ||
  OrderStatus.confirmed ||
  OrderStatus.preparing ||
  OrderStatus.cooking ||
  OrderStatus.pickedUp => BadgeTone.neutral,
};

/// A3 (p22): loading placeholders at the ticket footprint. The live-refresh
/// overlay spinner stays (background refresh over present data — see p22
/// report DECISIONS).
Widget _deliverySkeletonList() => ListView.separated(
  padding: const EdgeInsets.all(12),
  itemCount: 3,
  separatorBuilder: (_, __) => const SizedBox(height: 8),
  itemBuilder: (_, __) => SkeletonLoader.block(
    width: double.infinity,
    height: 160,
    borderRadius: BrandShapes.large,
  ),
);

// ─────────────────────── AVAILABLE ORDERS ────────────────────────────

class _AvailableOrdersTab extends ConsumerWidget {
  final String branchId;
  final String driverUid;
  const _AvailableOrdersTab({required this.branchId, required this.driverUid});

  Future<void> _assignToMe(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    final loc = AppLocalizations.of(context);
    try {
      await ref.read(deliveryServiceProvider).assignToMe(orderId, driverUid);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.orderAssignedPickup)));
      }
    } catch (e, stack) {
      final logger = ref.read(loggerProvider);
      await logger.error(e, 'assign_order_to_driver_failed', stack: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(availableOrdersProvider(branchId));
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return ordersAsync.when(
      // A3 (p22): skeleton placeholders instead of a bare spinner.
      loading: () => _deliverySkeletonList(),
      error: (e, _) => Center(child: Text(FirebaseExceptionMapper.map(e))),
      data: (_) {
        final orders = ordersAsync.requireValue;
        // A1 (p22): the duplicated Card+ListTile builders collapse into ONE
        // library-card list (raw ListTile/Card/FilledButton are sweep gaps
        // F3-10/F3-11 — and the trailing FilledButton sat below the 48 dp
        // operator floor, L19).
        final list = orders.isEmpty
            ? _availableEmpty(loc)
            : _availableList(context, ref, loc, orders, currency);
        if (ordersAsync.isRefreshing) {
          return Stack(
            children: [
              list,
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
        return list;
      },
    );
  }

  /// A3 (p22): healthy-case empty state (wording unchanged — perf7 pins
  /// 'No orders available').
  Widget _availableEmpty(AppLocalizations loc) => EmptyStateWidget(
    icon: Icons.hourglass_empty_outlined,
    title: loc.noOrdersAvailable,
    subtitle: '',
  );

  Widget _availableList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    List<OrderModel> orders,
    String currency,
  ) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: orders.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, i) {
      final order = orders[i];
      // L12.3 entrance motion (A3) — per item, stream-capped.
      return StaggeredEntrance(
        children: [
          BrandCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${safeOrderToken(order.id)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (OrderSource.isPlatformOrder(order.orderSource)) ...[
                      const SizedBox(width: 8),
                      BrandBadge(
                        label: OrderSource.platformOf(order.orderSource)!,
                        tone: BadgeTone.neutral,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${loc.itemsCount(order.items.length)} · ${formatAmount(order.totalCents, currency)}',
                  style: TextStyle(
                    color: BrandColors.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // A1 (p22): the assign action is the frozen BrandButton, kept
                // in the same Wrap action row as the sibling my-orders and
                // kitchen tickets. A BrandButton placed DIRECTLY on a Row's
                // main axis receives an unbounded width constraint and its
                // internal Flexible label then asserts; the Wrap bounds it.
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    BrandButton(
                      text: loc.assignToMe,
                      onPressed: () => _assignToMe(context, ref, order.id),
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
}
