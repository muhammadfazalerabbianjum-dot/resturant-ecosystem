import 'package:flutter/material.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/l10n/app_localizations.dart';

/// P1-7 — branch × channel breakdown for the owner dashboard.
///
/// The aggregation is a pure function of ledger-shaped rows, mirroring
/// `functions/src/rollups.ts` exactly: a `sale` row adds revenue and one order;
/// a `reversal` row subtracts from revenue and is counted as a refund; a sale is
/// never erased from `ordersCount` by its reversal. Keeping the two
/// implementations identical is the point — the dashboard must not disagree with
/// the nightly rollup about the same day's money.
///
/// The widget takes data, not a provider: the panel is what the widget test
/// sizes at 390 px and 1024 px, and a Firestore subscription would make that test
/// depend on a network.
const String kUnknownChannel = 'unknown';

/// One branch's totals for the day.
class BranchTotal {
  const BranchTotal({
    required this.branchId,
    required this.revenueCents,
    required this.ordersCount,
    required this.refundsCents,
    required this.revenueByChannel,
  });

  final String branchId;
  final int revenueCents;
  final int ordersCount;
  final int refundsCents;
  final Map<String, int> revenueByChannel;
}

/// The whole day, by branch and by channel.
class BranchChannelBreakdown {
  const BranchChannelBreakdown({
    required this.branches,
    required this.revenueByChannel,
    required this.ordersCount,
    required this.refundsCents,
  });

  /// Branches with any activity, richest first.
  final List<BranchTotal> branches;

  /// Project-wide revenue per channel (a branch's channels summed).
  final Map<String, int> revenueByChannel;

  final int ordersCount;
  final int refundsCents;

  int get revenueCents => branches.fold(0, (sum, b) => sum + b.revenueCents);

  /// Builds the breakdown from ledger rows (`transactions` documents).
  ///
  /// Rows with no `branchId` are grouped under [kUnknownChannel]'s branch
  /// equivalent — `unknown` — rather than dropped, because quietly losing money
  /// from a report is worse than showing it in an unnamed bucket.
  factory BranchChannelBreakdown.fromRows(List<Map<String, dynamic>> rows) {
    final byBranch = <String, Map<String, int>>{};
    final refundsByBranch = <String, int>{};
    final ordersByBranch = <String, int>{};
    final channels = <String, int>{};
    var ordersCount = 0;
    var refundsCents = 0;

    for (final row in rows) {
      final branch = _stringOr(row['branchId'], 'unknown');
      final channel = _stringOr(row['channel'], kUnknownChannel);
      final cents = row['totalCents'];
      if (cents is! int) continue;

      byBranch.putIfAbsent(branch, () => <String, int>{});
      ordersByBranch.putIfAbsent(branch, () => 0);
      refundsByBranch.putIfAbsent(branch, () => 0);

      if (row['kind'] == 'reversal') {
        final refund = cents.abs();
        refundsByBranch[branch] = refundsByBranch[branch]! + refund;
        refundsCents += refund;
        byBranch[branch]![channel] = (byBranch[branch]![channel] ?? 0) - refund;
        channels[channel] = (channels[channel] ?? 0) - refund;
        continue;
      }

      if (row['kind'] != 'sale') continue;

      ordersByBranch[branch] = ordersByBranch[branch]! + 1;
      ordersCount += 1;
      byBranch[branch]![channel] = (byBranch[branch]![channel] ?? 0) + cents;
      channels[channel] = (channels[channel] ?? 0) + cents;
    }

    final branches = byBranch.keys.map((branch) {
      final perChannel = byBranch[branch]!;
      return BranchTotal(
        branchId: branch,
        revenueCents: perChannel.values.fold(0, (sum, v) => sum + v),
        ordersCount: ordersByBranch[branch] ?? 0,
        refundsCents: refundsByBranch[branch] ?? 0,
        revenueByChannel: Map<String, int>.unmodifiable(perChannel),
      );
    }).toList()..sort((a, b) => b.revenueCents.compareTo(a.revenueCents));

    return BranchChannelBreakdown(
      branches: List<BranchTotal>.unmodifiable(branches),
      revenueByChannel: Map<String, int>.unmodifiable(channels),
      ordersCount: ordersCount,
      refundsCents: refundsCents,
    );
  }
}

String _stringOr(Object? value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value : fallback;

/// Owner dashboard panel: total revenue, then per-branch rows with their channel
/// split.
///
/// 390 px (phone) and 1024 px (tablet/web) are the two supported classes per the
/// handoff; the layout switches at 720 px and every text is wrapped in
/// `Flexible`/`Expanded` so neither size can overflow.
class BranchChannelBreakdownPanel extends StatelessWidget {
  const BranchChannelBreakdownPanel({
    super.key,
    required this.data,
    required this.currencyCode,
  });

  static const double kWideLayoutBreakpoint = 720;

  final BranchChannelBreakdown data;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (data.branches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(loc.noRevenueData, style: theme.textTheme.bodyMedium),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideLayoutBreakpoint;
        final header = _SummaryHeader(data: data, currencyCode: currencyCode);
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final branch in data.branches)
              _BranchRow(
                branch: branch,
                currencyCode: currencyCode,
                wide: wide,
              ),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, const SizedBox(height: 12), list],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: header),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: list),
          ],
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.data, required this.currencyCode});

  final BranchChannelBreakdown data;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.todaysRevenue, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          formatAmount(data.revenueCents, currencyCode),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        for (final entry in data.revenueByChannel.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatAmount(entry.value, currencyCode),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.branch,
    required this.currencyCode,
    required this.wide,
  });

  final BranchTotal branch;
  final String currencyCode;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final details = Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final entry in branch.revenueByChannel.entries)
          Text(
            '${entry.key} · ${formatAmount(entry.value, currencyCode)}',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          branch.branchId,
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${formatAmount(branch.revenueCents, currencyCode)} · '
          '${branch.ordersCount} ${loc.branchOrders}',
          style: theme.textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        if (branch.refundsCents > 0)
          Text(
            '-${formatAmount(branch.refundsCents, currencyCode)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: summary),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: details),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 8), details],
              ),
      ),
    );
  }
}
