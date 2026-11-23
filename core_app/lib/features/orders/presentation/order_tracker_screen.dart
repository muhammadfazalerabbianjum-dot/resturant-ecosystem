import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/app/a11y/text_scale_clamp.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import '../domain/order_model.dart';
import 'order_provider.dart';
import 'order_tracker_steps_widget.dart';

/// Streams a single order document for the tracker screen.
final singleOrderProvider = StreamProvider.autoDispose
    .family<OrderModel?, String>((ref, orderId) {
      return ref.watch(orderRepositoryProvider).streamOrder(orderId);
    });

/// PURE `OrderStatus -> InfoTone` mapping for the tracker's status header
/// (p20 B1). DISPLAY ONLY (L16): this picks a banner tone and nothing else —
/// the order's state machine, timers and listeners are untouched. The switch is
/// exhaustive, so a new status must be classified here rather than silently
/// inheriting a tone. The frozen [StatusTile] table keeps the row-badge tones
/// (p20 A1); this is the banner-level complement of it.
InfoTone trackerInfoToneFor(OrderStatus status) => switch (status) {
  OrderStatus.pending ||
  OrderStatus.confirmed ||
  OrderStatus.preparing ||
  OrderStatus.cooking => InfoTone.info,
  OrderStatus.ready || OrderStatus.pickedUp => InfoTone.warning,
  OrderStatus.delivered => InfoTone.success,
  OrderStatus.cancelled => InfoTone.error,
};

class OrderTrackerScreen extends ConsumerWidget {
  final String orderId;
  const OrderTrackerScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final orderAsync = ref.watch(singleOrderProvider(orderId));
    // Multi-app (Law 3): money is formatted through the shared [moneyCents]
    // helper driven by the restaurant's configured currency.
    final currencyCode = ref
        .watch(restaurantConfigProvider)
        .valueOrNull
        ?.currency;

    return ClampedTextScale(
      child: Scaffold(
        appBar: AppBar(title: Text(loc.orderTrackerTitle(orderId))),
        body: orderAsync.when(
          loading: () => const _OrderTrackerSkeleton(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(loc.couldNotLoadOrder, textAlign: TextAlign.center),
            ),
          ),
          data: (order) {
            if (order == null) {
              return Center(child: Text(loc.orderNotFound));
            }
            return _OrderTrackerBody(order: order, currencyCode: currencyCode);
          },
        ),
      ),
    );
  }
}

/// The tracker's presentational body (p20 B1): the bare centered header becomes
/// an [InfoBanner] carrying the status tone, the total becomes a display-only
/// [PriceTag] (L13 — the integer cents are forwarded verbatim, never
/// recomputed), and the column enters through [StaggeredEntrance] (L12.3).
///
/// L16 SANCTUARY: [OrderTrackerStepsWidget] is passed through untouched — every
/// timer, listener and ordered-state transition still lives where it lived, and
/// the status text/`Step n of m` live-region semantics are preserved.
class _OrderTrackerBody extends StatelessWidget {
  const _OrderTrackerBody({required this.order, required this.currencyCode});

  final OrderModel order;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: StaggeredEntrance(
        children: [
          InfoBanner(
            tone: trackerInfoToneFor(order.status),
            title: loc.deliveryStatusTitle,
            child: Text(
              loc.trackerCurrentStatus(orderStatusLabel(loc, order.status)),
            ),
          ),
          Gap.v16,
          OrderTrackerStepsWidget(order: order, currentStatus: order.status),
          Gap.v16,
          Center(
            child: PriceTag(
              cents: order.totalCents,
              currencyCode: currencyCode,
              large: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading counterpart of the tracker (L12.4): tile skeletons in the live
/// tiles' documented footprints instead of a bare spinner — the 72-high
/// SettingTile row (the status banner's band), the 96-high MenuTile row (the
/// steps strip) and the 160x88 stat block (the total).
class _OrderTrackerSkeleton extends StatelessWidget {
  const _OrderTrackerSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppDimensions.paddingM),
    children: [
      TileSkeletons.setting(),
      Gap.v16,
      TileSkeletons.menu(),
      Gap.v16,
      Center(child: TileSkeletons.stat()),
    ],
  );
}
