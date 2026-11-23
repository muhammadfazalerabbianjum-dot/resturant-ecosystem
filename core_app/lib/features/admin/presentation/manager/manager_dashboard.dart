import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';

/// W8.5 (04-P1-STREAM) + W8.7 (04-P1-QUERY): ONE live subscription per
/// (branchId, window) key; the BOUNDED query (24 h history window,
/// newest-first, hard cap — admin_data_service.dart) is created here, NOT in
/// build, so rebuilds no longer re-subscribe the entire branch order history
/// (the pre-conversion bug) or reset the list to empty on every rebuild.
final branchOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, (String, Duration)>((ref, key) {
      final (branchId, window) = key;
      return ref
          .watch(adminDataServiceProvider)
          .streamOrdersByBranch(branchId, window: window);
    });

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGate(
      allowedRoles: const {UserRole.manager},
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
      error: (e, _) =>
          Scaffold(body: Center(child: Text(FirebaseExceptionMapper.map(e)))),
      data: (_) {
        final user = userAsync.requireValue;
        if (user == null) {
          return Scaffold(body: Center(child: Text(loc.notSignedIn)));
        }
        final branchId = user.branchId;
        if (branchId == null) {
          return Scaffold(body: Center(child: Text(loc.noBranchAssigned)));
        }
        final content = _BranchDashboard(branchId: branchId);
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

class _BranchDashboard extends ConsumerWidget {
  final String branchId;
  const _BranchDashboard({required this.branchId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final ordersAsync = ref.watch(
      branchOrdersProvider((branchId, kManagerOrdersHistoryWindow)),
    );
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: loc.branchOrders,
          child: Text(loc.branchOrders),
        ),
      ),
      body: ordersAsync.when(
        // Preserved behavior: the pre-conversion StreamBuilder rendered an
        // empty list while waiting (no spinner) — and the family provider now
        // also KEEPS the previous list across rebuilds.
        loading: () => _orderList(loc, currency, const []),
        // W8.5 fail-visible: stream errors were silently swallowed into an
        // empty list before; they now surface through the repo's mapper.
        error: (e, _) => Center(child: Text(FirebaseExceptionMapper.map(e))),
        data: (orders) => _orderList(loc, currency, orders),
      ),
    );
  }

  /// B1 (p22): frozen `SectionHeader` + `StatTile` chrome above the list and
  /// `BrandCard` rows instead of raw `ListTile`s — display-only (L16).
  ///
  /// The bounded/capped list itself is UNTOUCHED: `STATE-2`'s contract is read
  /// straight off the `ListView`'s delegate by
  /// `manager_bounded_history_stream_test.dart`, so this stays the ONE lazy
  /// `ListView.separated` with `itemCount == orders.length` and no header row
  /// inside it (the header/metrics live outside, in the parent `Column`).
  Widget _orderList(
    AppLocalizations loc,
    String currency,
    List<OrderModel> orders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: loc.orders),
              Gap.v8,
              StatTile(
                label: loc.branchOrders,
                value: '${orders.length}',
                icon: Icons.receipt_long,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => Gap.v8,
            itemBuilder: (context, i) =>
                _orderRow(context, loc, currency, orders[i]),
          ),
        ),
      ],
    );
  }

  /// B1 (p22): one `BrandCard` row. The W9 semantics label and the
  /// `#TOKEN` / status / amount strings are exactly the pre-adoption ones —
  /// this is a chrome swap, not a data change.
  Widget _orderRow(
    BuildContext context,
    AppLocalizations loc,
    String currency,
    OrderModel order,
  ) {
    final brand = BrandColors.of(context);
    return Semantics(
      label: loc.orderSemanticsLabel(
        safeOrderToken(order.id),
        orderStatusLabel(loc, order.status),
        formatAmount(order.totalCents, currency),
      ),
      child: BrandCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${safeOrderToken(order.id)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: brand.textPrimary,
                    ),
                  ),
                  Gap.v8,
                  Text(
                    orderStatusLabel(loc, order.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: brand.textSecondary),
                  ),
                ],
              ),
            ),
            Gap.h8,
            Text(
              formatAmount(order.totalCents, currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: brand.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
