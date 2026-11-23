import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/l10n/app_localizations.dart';

class OwnerOrdersTab extends ConsumerStatefulWidget {
  const OwnerOrdersTab({super.key});

  @override
  ConsumerState<OwnerOrdersTab> createState() => _OwnerOrdersTabState();
}

class _OwnerOrdersTabState extends ConsumerState<OwnerOrdersTab> {
  final List<OrderModel> _orders = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final adminService = ref.read(adminDataServiceProvider);
    final page = await adminService.loadOrders(
      startAfter: _lastDoc,
      limit: _pageSize,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        if (page.items.length < _pageSize) _hasMore = false;
        if (page.items.isNotEmpty) {
          _lastDoc = page.lastDoc; // ← STORE cursor for next page
          _orders.addAll(page.items);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final configAsync = ref.watch(restaurantConfigProvider);
    final currency = configAsync.valueOrNull?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: Text(loc.allOrders)),
      body: ListView.separated(
        padding: const EdgeInsets.only(
          left: 12,
          top: 12,
          right: 12,
          bottom: 90,
        ),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          if (i == _orders.length) {
            return Center(
              child: _loading
                  ? SkeletonLoader.block(width: 120, height: 40)
                  : TextButton(onPressed: _loadMore, child: Text(loc.loadMore)),
            );
          }
          final order = _orders[i];
          // E1 F3-11: the row shell is BrandCard (token radius); the money
          // string is still formatAmount's (L13 byte-identical).
          return BrandCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${safeOrderToken(order.id)}'),
                      Text(
                        loc.branchStatusLine(
                          order.branchId ?? loc.noBranchAssigned,
                          orderStatusLabel(loc, order.status),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(formatAmount(order.totalCents, currency)),
              ],
            ),
          );
        },
      ),
    );
  }
}
