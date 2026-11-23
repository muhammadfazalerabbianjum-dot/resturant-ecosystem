import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import '../../cart/presentation/cart_provider.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/presentation/order_tracker_screen.dart'
    show singleOrderProvider;

/// Customer delivery tracker (M-5).
///
/// UI-13 (p21) phase F: the three hand-rolled stage rows (each a decorated
/// `Container` pill) are replaced by the frozen library progress model
/// ([OrderTimeline]) plus a [StatusTile]/[BrandBadge] current-status badge and a
/// `SkeletonLoader` loading state, and every failure path renders an
/// [InfoBanner] instead of a bare centred string. L16: the tracking/listener
/// logic — the `singleOrderProvider` stream, `_contactDriver`'s dial handling
/// and `_reorder`'s cart replay — is untouched.
class DeliveryTrackerScreen extends ConsumerStatefulWidget {
  final String orderId;
  const DeliveryTrackerScreen({super.key, required this.orderId});

  /// The customer-facing delivery progress model (pure, directly assertable).
  ///
  /// `OrderModel` carries one status, never a stage history, so the three stages
  /// are derived from it and nothing is fabricated (L13/L14): no per-step
  /// timestamps are invented, and a cancelled order reports no reached stage —
  /// the cancellation is carried by the status badge and the status label, not
  /// by an invented timeline position.
  static List<OrderTimelineStep> timelineStepsFor(
    AppLocalizations loc,
    OrderStatus status,
  ) {
    final stages = switch (status) {
      OrderStatus.pending ||
      OrderStatus.confirmed ||
      OrderStatus.preparing ||
      OrderStatus.cooking => const [
        TimelineStepState.current,
        TimelineStepState.future,
        TimelineStepState.future,
      ],
      OrderStatus.ready || OrderStatus.pickedUp => const [
        TimelineStepState.completed,
        TimelineStepState.current,
        TimelineStepState.future,
      ],
      OrderStatus.delivered => const [
        TimelineStepState.completed,
        TimelineStepState.completed,
        TimelineStepState.completed,
      ],
      OrderStatus.cancelled => const [
        TimelineStepState.future,
        TimelineStepState.future,
        TimelineStepState.future,
      ],
    };
    final labels = <String>[loc.preparingFood, loc.onTheWay, loc.arrived];
    return <OrderTimelineStep>[
      for (var index = 0; index < labels.length; index++)
        OrderTimelineStep(label: labels[index], state: stages[index]),
    ];
  }

  /// The badge tone for the current status (pure, directly assertable).
  static TileStatus tileStatusFor(OrderStatus status) => switch (status) {
    OrderStatus.delivered => TileStatus.ok,
    OrderStatus.cancelled => TileStatus.failed,
    _ => TileStatus.pending,
  };

  @override
  ConsumerState<DeliveryTrackerScreen> createState() =>
      _DeliveryTrackerScreenState();
}

class _DeliveryTrackerScreenState extends ConsumerState<DeliveryTrackerScreen> {
  Future<void> _contactDriver() async {
    final order = ref.read(singleOrderProvider(widget.orderId)).value;
    if (order == null) return;
    // The restaurant contact phone is runtime-editable via Firestore
    // `settings/restaurantConfig.contactPhone` — never a hardcoded number.
    //
    // PERF-8 W2: the config arrives over a stream. A cold deep-link can reach
    // this screen before the settings doc lands, and reading only the current
    // value would report "not configured" on the very first tap even though a
    // phone IS configured. While the provider is still loading, await its
    // first value; a failed stream falls through to the same snackbar.
    final configAsync = ref.read(restaurantConfigProvider);
    var config = configAsync.valueOrNull;
    if (config == null && configAsync.isLoading) {
      try {
        config = await ref.read(restaurantConfigProvider.future);
      } catch (_) {
        config = null; // fail-closed: report "not configured", never hang
      }
    }
    final contactPhone = config?.contactPhone;
    if (contactPhone == null || contactPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).contactNotConfigured),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$contactPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _reorder() async {
    final order = ref.read(singleOrderProvider(widget.orderId)).value;
    if (order == null) return;
    final notifier = ref.read(cartProvider.notifier);
    // PERF-8 W2: the cart loads asynchronously on first read, and
    // CartNotifier.addItem returns early while its value is still null — a
    // reorder tapped before that load finished silently dropped every item
    // and sent the customer to an empty cart. Await the load first.
    if (ref.read(cartProvider).value == null) {
      await notifier.loadCart();
    }
    for (final item in order.items) {
      await notifier.addItem(item.item, selectedOptions: item.selectedOptions);
    }
    if (!mounted) return;
    context.goNamed(RouteNames.cart);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final orderAsync = ref.watch(singleOrderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: Text(loc.orderTrackerTitle(widget.orderId))),
      // P37 T-2: the live delivery-tracking view is gated by `deliveryTracking`
      // (default-true — shipped rendering unchanged).
      body: FlagGate(
        flag: 'deliveryTracking',
        child: orderAsync.when(
          // P21 F1: the raw spinner becomes the frozen skeleton list; the error
          // copy and the not-found copy become tone-carrying `InfoBanner`s, so a
          // failure is a handled state, never a bare centred string.
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            separatorBuilder: (_, __) => Gap.v8,
            itemBuilder: (_, __) => SkeletonLoader.listTile(),
          ),
          error: (e, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InfoBanner(
                tone: InfoTone.error,
                child: Text(loc.couldNotLoadOrder),
              ),
            ),
          ),
          data: (order) {
            if (order == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: InfoBanner(
                    tone: InfoTone.warning,
                    child: Text(loc.orderNotFound),
                  ),
                ),
              );
            }
            final statusLabel = orderStatusLabel(
              loc,
              order.status,
            ).toUpperCase();
            return Center(
              // P21 F2: a scrollable body so the longer library composition never
              // overflows on a 3x-font-scale / short-viewport device.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: loc.deliveryStatusTitle,
                      child: SectionHeader(title: loc.deliveryStatusTitle),
                    ),
                    const SizedBox(height: 24),
                    // P21 F1: the three hand-rolled stage pills become the frozen
                    // progress model, driven by the assertable pure mapping
                    // `timelineStepsFor` (never a fabricated timestamp, L13/L14).
                    OrderTimeline(
                      steps: DeliveryTrackerScreen.timelineStepsFor(
                        loc,
                        order.status,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // P21 F1: the raw uppercase status line becomes the frozen
                    // badge tile; the `orderStatusLabel` composition is unchanged.
                    StatusTile(
                      status: DeliveryTrackerScreen.tileStatusFor(order.status),
                      label: statusLabel,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: loc.contactDriver,
                      button: true,
                      child: ElevatedButton.icon(
                        onPressed: _contactDriver,
                        icon: const Icon(Icons.phone),
                        label: Text(loc.contactDriver),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // P37 T-2: one-tap cart replay is gated by `smartReorder`.
                    FlagGate(
                      flag: 'smartReorder',
                      child: Semantics(
                        label: loc.reorderItems,
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: _reorder,
                          icon: const Icon(Icons.replay),
                          label: Text(loc.reorderItems),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
