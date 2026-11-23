import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/feature_flag_gate.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../../locations/data/location_repository.dart';
import '../../cart/presentation/cart_provider.dart';
import '../../cart/domain/cart_model.dart';
import '../../orders/domain/order_model.dart';
import '../../../services/notification_service.dart';
import '../../menu/presentation/merged_menu_provider.dart';
import '../../cart/domain/cart_validator_service.dart';
import '../../../app/tenancy/tenant_claim.dart';
import '../../../app/config/restaurant_config_service.dart';
import '../domain/checkout_service.dart';
import '../../orders/domain/order_offline_payload.dart';
import '../../../app/a11y/text_scale_clamp.dart';

/// UI-7 (p17 T-2): the GA4 `items[]` mapping for checkout events — EVERY cart
/// line becomes one item entry (item_id, item_name, price, quantity). Values
/// are READ from the cart model (L2 — zero money math at this call site).
List<AnalyticsItem> _gaItemsFrom(Iterable<CartItemModel> lines) => [
  for (final line in lines)
    AnalyticsItem(
      itemId: line.item.id,
      itemName: line.item.name,
      priceCents: line.unitPriceCents,
      quantity: line.quantity,
    ),
];

/// Pre-set tip percentage options shown at checkout (UI-13 / p21 A2: the
/// pre-adoption list, unchanged — No Tip / 10 / 15 / 20 / 25).
const List<int> _kTipPercentages = <int>[0, 10, 15, 20, 25];

/// The pre-adoption integer tip expression, moved VERBATIM out of the deleted
/// `tip_selector_widget.dart` (UI-13 / p21 A2, L28): same operands, same
/// truncating `~/`, one single site — adoption adds no new cents arithmetic
/// and the value handed to the charge path is byte-identical.
@visibleForTesting
int tipCentsForPercent(int subtotalCents, int percent) =>
    (subtotalCents * percent) ~/ 100;

/// The pre-adoption option label, byte-identical to the deleted
/// `tip_selector_widget.dart` (UI-13 / p21 A2): `tipNoTip` for the zero
/// option, otherwise the `tipOptionLabel(pct, amount)` message. Every string
/// comes from the ARB catalogue (p18 owns the ARB files — nothing inlined);
/// the amount is preformatted through the shared [moneyCents] helper so the
/// frozen `TipSelector` only ever echoes strings (b4 / L24).
@visibleForTesting
String tipOptionLabelFor(
  AppLocalizations loc,
  int subtotalCents,
  int percent,
  String? currencyCode,
) {
  if (percent == 0) return loc.tipNoTip;
  // Integer money math (Law 3): multiply BEFORE divide, use ~/
  final amount = moneyCents(
    tipCentsForPercent(subtotalCents, percent),
    currencyCode: currencyCode,
  );
  return loc.tipOptionLabel('$percent', amount);
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with RestorationMixin {
  bool _isProcessing = false;
  bool _promoApplying = false;
  String? _appliedPromoCode;
  LatLng? _selectedLatLng;
  String _selectedAddress = '';
  int _tipCents = 0;

  /// UI-13 (p21 A2): the tip SELECTION lives here now that
  /// `tip_selector_widget.dart` was deleted in favour of the library
  /// `TipSelector` (W-1). Default 15% — and, exactly as before, nothing is
  /// charged until the customer taps a chip (`_tipCents` still starts at 0).
  int _selectedTipPercent = 15;
  final RestorableTextEditingController _promoController =
      RestorableTextEditingController();
  final RestorableInt _discountCents = RestorableInt(0);
  late final CheckoutService _checkoutSvc;
  late final String _sessionOrderId;

  @override
  String? get restorationId => 'checkout_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_promoController, 'checkout_promo');
    registerForRestoration(_discountCents, 'checkout_discount');
  }

  @override
  void initState() {
    super.initState();
    _checkoutSvc = ref.read(checkoutServiceProvider);
    final uid = ref.read(currentUserIdProvider) ?? 'anon';
    _sessionOrderId = _checkoutSvc.generateSessionOrderId(uid);
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  LatLng? _mapInitialCenter() {
    final locations = ref.read(locationsProvider).valueOrNull ?? const [];
    if (locations.isEmpty) return null;
    final first = locations.first;
    if (first.lat == 0.0 && first.lng == 0.0) return null;
    return LatLng(first.lat, first.lng);
  }

  void _openMapPicker() {
    // UI-13 (p21 A3/H2): the map-picker HOST routes through the library
    // `BrandSheet.show` (F3-13's adoption half) while the
    // `LiveMapPickerWidget` composition itself is preserved verbatim (L31 —
    // same widget, same callbacks, same labels, same initialCenter, same
    // 0.88-height + clip chrome). Behaviour is unchanged: the pre-adoption
    // `showModalBottomSheet` call used the Material defaults, so the sheet
    // stays dismissible (`barrierDismissible: true` == the old
    // `isDismissible`/`enableDrag` defaults).
    BrandSheet.show<void>(
      context,
      barrierDismissible: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: LiveMapPickerWidget(
            onLocationPicked: (latlng, address) {
              setState(() {
                _selectedLatLng = latlng;
                _selectedAddress = address;
              });
            },
            title: AppLocalizations.of(context).mapPickerTitle,
            confirmLabel: AppLocalizations.of(context).mapPickerConfirm,
            positioningLabel: AppLocalizations.of(context).mapPickerPositioning,
            movePinLabel: AppLocalizations.of(context).mapPickerMovePin,
            lookingUpLabel: AppLocalizations.of(context).mapPickerLookingUp,
            deliveringToLabel: AppLocalizations.of(
              context,
            ).mapPickerDeliveringTo,
            initialCenter: _mapInitialCenter(),
            userAgentPackageName: AppConfig.bundleId,
          ),
        ),
      ),
    );
  }

  Future<void> _applyPromo() async {
    final loc = AppLocalizations.of(context);
    final code = _promoController.value.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (_promoApplying) return;

    final cartState = ref.read(cartProvider);
    final cartTotal = cartState.value?.totalCents ?? 0;

    setState(() => _promoApplying = true);
    try {
      final result = await _checkoutSvc.validatePromo(code, cartTotal);
      if (!mounted) return;
      if (result.isValid) {
        setState(() {
          _discountCents.value = result.discountCents;
          _appliedPromoCode = code;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? loc.promoApplied)),
        );
      } else {
        setState(() {
          _discountCents.value = 0;
          _appliedPromoCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? loc.promoInvalid)),
        );
      }
    } finally {
      if (mounted) setState(() => _promoApplying = false);
    }
  }

  Future<void> _processPayment(int subtotalCents) async {
    final loc = AppLocalizations.of(context);
    if (_isProcessing) return;
    // P8(W3) concurrency fence: the flag must be set SYNCHRONOUSLY, before
    // the first await. The old code set it only at the charge — after the
    // fraud/panic/cart/location/tax pre-flight — so a double-tap inside that
    // window ran TWO concurrent money pipelines (each invoking
    // createPaymentIntent and createOrder; server idempotency dedupes the
    // WRITE, but the client must never open a second pipeline). Every early
    // return below therefore resets the flag before bailing out.
    setState(() => _isProcessing = true);

    // Fraud screening
    final allowed = await _checkoutSvc.screenPayment();
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.tooManyTransactions),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Panic switch check
    final isAccepting = await _checkoutSvc.isOrdersAccepting();
    if (!isAccepting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.ordersTemporarilyPaused),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Cart validation
    final cartForValidation =
        ref
            .read(cartProvider)
            .value
            ?.items
            .map(
              (i) => {
                'id': i.item.id,
                'name': i.item.name,
                'priceCents': i.item.priceCents,
              },
            )
            .toList() ??
        [];
    if (cartForValidation.isNotEmpty) {
      final validationResult = await _checkoutSvc.validateCart(
        cartForValidation,
      );
      if (validationResult is CartValidationFailed) {
        if (mounted) {
          final reasons = validationResult.failures
              .map((f) => f.reason)
              .join('\n');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.cartIssue(reasons)),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
    }

    // Location check
    if (_selectedLatLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.setDeliveryLocationFirst)));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Resolve the restaurant's delivery fee (runtime-editable via Firestore).
    final restaurantConfig = ref.read(restaurantConfigProvider).valueOrNull;
    final deliveryFeeCents = restaurantConfig?.deliveryFeeCents ?? 0;

    // Calculate final total via Cloud Functions — FAIL-CLOSED (Law 8):
    // if tax cannot be computed, abort checkout. Never proceed with $0 tax.
    // Total = subtotal + tax − promo + tip + delivery (Law 3 integer math).
    // B1: tax comes from `calculateTax` and the promo discount from the
    // server-authoritative `applyPromo`; the same server-derived amounts are
    // returned by `createPaymentIntent` and stored on the order (Law 12).
    InvoiceTotal invoice;
    try {
      invoice = await _checkoutSvc.calculateFinalTotal(
        subtotalCents,
        promoCode: _appliedPromoCode,
        userId: ref.read(currentUserIdProvider),
        tipCents: _tipCents,
        deliveryFeeCents: deliveryFeeCents,
      );
    } catch (e, stackTrace) {
      await ref
          .read(loggerProvider)
          .error(e, 'checkout_tax_calculation_failed', stack: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.taxCouldNotBeCalculated),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }
    final finalTotal = invoice.netCents;
    if (_checkoutSvc.isBelowMinimumOrderTotal(finalTotal)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.orderMinTotal(
                moneyCents(
                  CheckoutService.minimumOrderCents,
                  currencyCode: restaurantConfig?.currency,
                ),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.pleaseSignIn)));
        }
        return;
      }

      final cartState = ref.read(cartProvider);
      if (cartState.isLoading ||
          cartState.hasError ||
          cartState.value == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.cartStateInvalid)));
        }
        return;
      }

      // 1. Mint the idempotency key for THIS order attempt (MONEY-4, Law 9).
      //    The key is scoped to the cart being charged, so a retry of this
      //    attempt reuses it (Stripe returns the existing PaymentIntent — no
      //    double charge, no duplicate order), while a DIFFERENT cart in the
      //    same session mints a different key, so `createOrder` can never
      //    resolve the new order to an earlier order's id.
      final idempotencyKey = await _checkoutSvc.getOrCreateSessionId(
        cart: cartState.value,
        userId: userId,
      );
      if (!mounted) return;

      // Build order model (needed for offline queue + createOrder)
      final branchId = ref.read(currentBranchIdProvider);
      final orderNumber = await _checkoutSvc.nextOrderNumber();
      if (!mounted) return;
      if (branchId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.pleaseSelectBranch)));
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final branchDoc = await _checkoutSvc.fetchBranch(branchId);
      if (!mounted) return;
      if (!branchDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.branchUnavailable)));
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      var order = OrderModel(
        id: _sessionOrderId,
        customerId: userId,
        branchId: branchId,
        customerLat: _selectedLatLng?.latitude,
        customerLng: _selectedLatLng?.longitude,
        status: OrderStatus.confirmed,
        totalCents: finalTotal,
        // B1: server-derived money provenance — the stored order carries the
        // same tax/discount the server will stamp on the PaymentIntent so
        // createOrder's belt-and-suspenders check passes (or the charge fails
        // closed first — never a mismatched stored order).
        taxCents: invoice.taxCents,
        discountCents: invoice.discountCents,
        tipCents: _tipCents,
        deliveryFeeCents: deliveryFeeCents,
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: cartState.value!.items,
      );

      // Persist order intent for offline resilience (Law 15: Offline-First).
      // The order JSON carries its own id → idempotent on replay.
      // NOTE: op-name MUST be 'create' — IsarSyncQueue.processQueue() only
      // handles 'create'/'update'/'delete'. 'createOrder' would never sync.
      //
      // QUEUE-1 (W5.1(a)): the enqueued payload is a SEPARATE rules-legal
      // object — status 'pending' (firestore.rules create requires it) +
      // offlineQueued + queuedAt ISO. The in-memory/UI `order` object keeps
      // its real 'confirmed' status and is NEVER mutated.
      // D-039: the create rule compares `tenantId` to the caller's claim, so it
      // is read from the token - config can drift and would deny every order.
      final String? tenantId = await ref.read(tenantClaimProvider).read();
      if (!mounted) return;
      if (tenantId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.error)));
        setState(() => _isProcessing = false);
        return;
      }
      final syncQueue = ref.read(syncQueueProvider);
      await syncQueue.enqueue(
        'create',
        'orders',
        buildOfflineOrderPayload(order, tenantId: tenantId),
      );

      // UI-7 (p17 T-2): GA4 `add_payment_info` — the payment step is reached
      // (every pre-flight gate above passed; the card charge starts below).
      // Money values are READ from the order/invoice models (L2); the applied
      // promo rides along as `coupon`. Fire-and-forget through the single
      // consent gate — a telemetry failure never breaks the charge path.
      unawaited(
        TelemetryService().addPaymentInfo(
          AddPaymentInfoEvent(
            items: _gaItemsFrom(order.items),
            currency: restaurantConfig?.currency ?? kDefaultAnalyticsCurrency,
            valueCents: finalTotal,
            paymentType: 'card',
            coupon: _appliedPromoCode,
          ),
        ),
      );

      // 2. Process Stripe payment (reuses existing intent on retry).
      //    The client sends ONLY the promo code — the server derives tax,
      //    discount and currency and returns them in the result.
      StripePaymentResult? payment;
      try {
        payment = await _checkoutSvc.processStripePayment(
          finalTotal: invoice.netCents,
          cart: cartState.value!,
          idempotencyKey: idempotencyKey,
          tipCents: _tipCents,
          deliveryFeeCents: deliveryFeeCents,
          promoCode: _appliedPromoCode,
          orderId: _sessionOrderId,
        );
      } catch (e) {
        // Offline resilience (Law 15): the order intent is already queued in
        // Isar. Show a user-facing message so they know it will sync later.
        // UX-4 (07-P1-7): the charge did not complete → payment_declined; the
        // order is now awaiting connectivity → offline_queue_depth. Both are
        // fire-and-forget — a telemetry failure must not break this path.
        unawaited(TelemetryService().paymentDeclined(reason: e.toString()));
        // Depth read is best-effort: the provider may be cold (never watched)
        // in some embedding — fail-open to 0, never crash the offline path.
        var queueDepth = 0;
        try {
          queueDepth = ref.read(pendingSyncCountProvider).valueOrNull ?? 0;
        } catch (_) {
          queueDepth = 0;
        }
        unawaited(TelemetryService().offlineQueueDepth(queueDepth));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.orderSavedOffline),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      if (payment == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) return;

      // Re-stamp the order with the ACTUAL server-charged values (Law 12) —
      // the display-derived tax/discount must equal them; this snapshots the
      // authority so createOrder verifies against the PaymentIntent metadata.
      order = order.copyWith(
        taxCents: payment.taxCents,
        discountCents: payment.discountCents,
      );

      // 3. Create order (idempotent server-side — same key = same doc)
      try {
        await _checkoutSvc.createOrder(
          paymentIntentId: payment.paymentIntentId,
          order: order,
          userId: userId,
          idempotencyKey: idempotencyKey,
        );
      } catch (e) {
        // CRITICAL (Law 9): do NOT clear the session key here — retry
        // reuses the SAME PaymentIntent, preventing a double charge.
        // UX-4 (07-P1-7): the server authority rejected or threw — the funnel
        // must see the drop-off (order_failed). Fire-and-forget: a telemetry
        // failure must not break this recovery path (residual 28.5).
        unawaited(
          TelemetryService().orderFailed(_sessionOrderId, reason: e.toString()),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.orderNotConfirmedRetry),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) return;

      // 4. Only on FULL success — clear the idempotency key + cart.
      //    Remove the queued offline op — the order is now confirmed.
      //    Promo usage is tracked by the SERVER at charge time (idempotent,
      //    uid-scoped) — no client-side usage write is needed (B1).
      // UI-7 (p17 T-2): snapshot the applied promo BEFORE the cleanup below
      // nulls `_appliedPromoCode` — the GA4 `purchase` fires with the coupon.
      final gaCoupon = _appliedPromoCode;
      await syncQueue.removeOperation('create', _sessionOrderId);
      await _checkoutSvc.clearSessionId();
      await ref.read(cartProvider.notifier).clearCart();
      _appliedPromoCode = null;

      if (mounted) {
        // UX-4 (07-P1-7): createOrder succeeded → the conversion event. The
        // facade emits `order_completed` to the logFunnelEvent pipeline AND
        // delegates to AnalyticsService.logOrderPlaced (first-party stack).
        // Fire-and-forget — a telemetry failure must never break the success
        // path (residual 28.5).
        unawaited(
          TelemetryService().orderCompleted(_sessionOrderId, finalTotal),
        );
        // UI-7 (p17 T-2): GA4 `purchase` — the ecommerce-standard conversion,
        // fired from the SAME order-success point as `order_completed` (L6:
        // BOTH fire, neither replaces the other; the taxonomy documents the
        // pairing). `transaction_id` = the order id, so GA4 collapses retries
        // onto one conversion; money values are READ from the order model
        // (server-stamped tax + delivery fee included — L2, zero money math).
        unawaited(
          TelemetryService().purchase(
            PurchaseEvent(
              transactionId: _sessionOrderId,
              items: _gaItemsFrom(order.items),
              currency: restaurantConfig?.currency ?? kDefaultAnalyticsCurrency,
              valueCents: order.totalCents,
              taxCents: order.taxCents,
              shippingCents: order.deliveryFeeCents,
              coupon: gaCoupon,
            ),
          ),
        );
        final messenger = ScaffoldMessenger.of(context);
        await LocalNotificationService.initialize();
        await LocalNotificationService.showOrderStatusNotification(
          _sessionOrderId,
          loc.orderPlacedSuccessfully,
        );
        if (!mounted) return;
        ConfettiOverlay.show(
          context,
          duration: const Duration(milliseconds: 1500),
          colors: AppConfig.confettiColors,
        );
        messenger.showSnackBar(SnackBar(content: Text(loc.paymentSuccessful)));
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            context.goNamed(
              RouteNames.orderTracker,
              pathParameters: {'orderId': _sessionOrderId},
              extra: order,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FirebaseExceptionMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// UX-2 (05-P1-UX-POPSCOPE): while a payment or promo request is in flight
  /// the route must not pop — a back press during an in-flight charge could
  /// leave the customer charged without ever seeing the result. Mirrors the
  /// `home_screen.dart` PopScope precedent, with a blocking in-flight dialog
  /// instead of a snackbar because the lost state here is money.
  void _showInFlightDialog() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    // UI-13 (p21 A4): the dialog surface is the library `BrandDialog` (W-4).
    // Behaviour is unchanged — non-dismissible barrier, un-poppable route, one
    // acknowledgement action that closes ONLY the dialog (BrandDialog pops
    // before it invokes the callback, so the no-op confirm keeps the old
    // "OK dismisses the dialog" contract).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: BrandDialog(
          title: loc.inFlightTitle,
          confirmLabel: loc.ok,
          onConfirm: () {},
          child: Text(loc.inFlightBody),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return ClampedTextScale(
      child: PopScope(
        canPop: !_isProcessing && !_promoApplying,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // UX-4 (07-P1-7): a blocked back press while a charge/promo is in
          // flight is an abandon signal — record it on the funnel. Never
          // awaited (analytics must never block the dialog or throw).
          unawaited(
            TelemetryService().checkoutAbandoned(
              ref.read(cartProvider).value?.totalCents ?? 0,
            ),
          );
          _showInFlightDialog();
        },
        child: Scaffold(
          appBar: AppBar(title: Text(loc.checkout)),
          body: cartAsync.when(
            // UI-13 (p21 F3-09): the raw loading spinner is adopted as the
            // library skeleton placeholder (L12.4 async surfaces skeleton).
            // The localized Semantics label is preserved verbatim (L14).
            loading: () => Semantics(
              label: loc.loadingCheckout,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TileSkeletons.setting(),
                      Gap.v8,
                      TileSkeletons.setting(),
                      Gap.v8,
                      TileSkeletons.setting(),
                    ],
                  ),
                ),
              ),
            ),
            // UI-13 (p21 A4): the load-failure surface renders through the
            // library `InfoBanner` (never a bare string); the mapped message
            // text itself is byte-identical (L29's mapper path untouched).
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: InfoBanner(
                  tone: InfoTone.error,
                  child: Text(FirebaseExceptionMapper.map(err)),
                ),
              ),
            ),
            data: (_) {
              final cart = cartAsync.requireValue;
              if (cart.items.isEmpty) {
                // UX-2 (05-P2-UX-STATES): empty checkout gets the same
                // recoverable CTA as the empty cart screen — never a dead end.
                return EmptyStateWidget(
                  icon: Icons.shopping_cart_outlined,
                  title: loc.yourCartIsEmpty,
                  subtitle: loc.noItemsYet,
                  ctaText: loc.browseMenu,
                  onCtaPressed: () => context.pushNamed(RouteNames.menu),
                );
              }

              final subtotal = cart.totalCents;
              final restaurantConfig = ref
                  .watch(restaurantConfigProvider)
                  .valueOrNull;
              final deliveryFeeCents = restaurantConfig?.deliveryFeeCents ?? 0;
              // Multi-app (Law 3): money displays use the configured currency code
              // through the shared [moneyCents] formatter — never a hardcoded symbol.
              final currencyCode = restaurantConfig?.currency;
              // UI-13 (p21 A2): the tip options are preformatted HERE — this
              // screen stays the single money authority (L28): the frozen
              // `TipSelector` below only echoes the opaque `int` selection
              // token and these already-localized strings (b4 / L24).
              final tipOptions = <TipOption<int>>[
                for (final percent in _kTipPercentages)
                  TipOption<int>(
                    value: percent,
                    label: tipOptionLabelFor(
                      loc,
                      subtotal,
                      percent,
                      currencyCode,
                    ),
                  ),
              ];
              // Display-only preview: subtotal − discount + tip + delivery.
              // Tax is shown as an estimate and finalised only at charge time.
              final previewTotal =
                  (subtotal -
                          _discountCents.value +
                          _tipCents +
                          deliveryFeeCents)
                      .clamp(0, double.infinity)
                      .toInt();

              final content = Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // UI-13 (p21 A1): section titles adopt the library
                        // `SectionHeader`; spacing adopts the `Gap` tokens.
                        SectionHeader(title: loc.deliveryDetails),
                        Gap.v16,
                        Semantics(
                          label: loc.setDeliveryLocationFirst,
                          button: true,
                          child: GestureDetector(
                            onTap: _openMapPicker,
                            // UI-13 (p21 A1, F3-15): the hand-rolled decorated
                            // container (box + border + radius + tint) is adopted
                            // as the token-radius `BrandCard`; the tap path,
                            // Semantics label, icon swap and copy are unchanged.
                            child: BrandCard(
                              borderColor: _selectedLatLng != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedLatLng != null
                                        ? Icons.location_on
                                        : Icons.add_location_alt_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 28,
                                  ),
                                  Gap.h(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.deliveryLocation,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                        Gap.v(4),
                                        Text(
                                          _selectedLatLng == null
                                              ? loc.pickLocationOnMap
                                              : _selectedAddress,
                                          style: theme.textTheme.bodyMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ).animate().slideX(begin: 0.1),
                        Gap.v(32),
                        // UI-13 (p21 A1): the promo form adopts the library
                        // `BrandTextField` (F3-12) + `BrandButton`; both keep
                        // the pre-adoption wiring (input sanitiser, done-key
                        // submit, Semantics labels) and the ambient input theme
                        // owns the field chrome (b10 contract).
                        // P37 T-2: the promo form is gated by `promoCode`
                        // (default-true — shipped rendering unchanged).
                        FlagGate(
                          flag: 'promoCode',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionHeader(title: loc.promoCode),
                              Gap.v16,
                              Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      label: loc.promoCodeHint,
                                      textField: true,
                                      child: BrandTextField(
                                        controller: _promoController.value,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.deny(
                                            RegExp(r'[<>]'),
                                          ),
                                        ],
                                        // UX-2 (05-P2-UX-KEYBOARD): the keyboard's
                                        // action key applies the promo instead of
                                        // doing nothing.
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _applyPromo(),
                                        hintText: loc.promoCodeHint,
                                      ),
                                    ),
                                  ),
                                  Gap.h16,
                                  // UI-13 (p21 A1): the promo APPLY button stays the
                                  // pre-adoption `ElevatedButton` BYTE-IDENTICAL
                                  // (DECISIONS): a Row gives its non-flex children
                                  // unbounded main-axis width, and the shared
                                  // `BrandButton` requires a bounded slot (its
                                  // inner `Flexible`). A1 names BrandCard /
                                  // SectionHeader / Gap — not buttons — so the
                                  // call-site is preserved rather than altering the
                                  // shared component's rendering (frozen w4 dialog
                                  // goldens stay untouched, L27).
                                  Semantics(
                                    label: loc.promoCodeApply,
                                    button: true,
                                    child: ElevatedButton(
                                      onPressed: _applyPromo,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 56),
                                      ),
                                      child: Text(loc.promoCodeApply),
                                    ),
                                  ),
                                ],
                              ).animate().slideX(begin: 0.1, delay: 100.ms),
                            ],
                          ),
                        ),
                        Gap.v(32),
                        SectionHeader(title: loc.orderSummary),
                        Gap.v16,
                        ...cart.items.map(
                          (cartItem) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${cartItem.quantity}x ${cartItem.item.name}',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                Text(
                                  moneyCents(
                                    cartItem.item.priceCents *
                                        cartItem.quantity,
                                    currencyCode: currencyCode,
                                  ),
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // UI-13 (p21 H2, F3-15): the hand-rolled bottom tray (raw
                  // `Container` + `BoxDecoration` shadow) adopts the library's
                  // surface component — SAME 24 px padding and SAME surface
                  // fill; the frozen set ships no shadowed tray, so the
                  // token-radius card surface is the disclosed replacement.
                  BrandCard(
                    padding: const EdgeInsets.all(24),
                    color: theme.colorScheme.surface,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // UI-13 (p21 A1): the pre-adoption label/value rows
                          // are structurally PLAIN rows — the library has no
                          // money-row component (p23 §8 frozen set), so the
                          // structure is preserved verbatim while the spacing
                          // between rows adopts the `Gap` tokens.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.subtotal,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                moneyCents(
                                  subtotal,
                                  currencyCode: currencyCode,
                                ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          if (_discountCents.value > 0) ...[
                            Gap.v8,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.discount,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '-${moneyCents(_discountCents.value, currencyCode: currencyCode)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Gap.v8,
                          // Display-only tax preview
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.taxEstimated,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              Text(
                                loc.calculatedAtCheckout,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.totalEstimate,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // P2-2 (p31): money NEVER renders in the
                              // heading font — the config displaySmall
                              // (PlayfairDisplay) painted its raised `$` as a
                              // stray glyph floating over the digits. The
                              // shared display-only PriceTag (body family,
                              // the same widget the cart total uses) owns
                              // the total; cents forwarded verbatim (L13).
                              PriceTag(
                                cents: previewTotal,
                                currencyCode: currencyCode,
                                large: true,
                              ),
                            ],
                          ),
                          Gap.v8,
                          // UI-13 (p21 A2): the frozen library `TipSelector`
                          // (W-1) replaces the deleted `TipSelectorWidget` —
                          // caller-preformatted labels, caller-formatted
                          // summary, and NO summary line for the "No Tip"
                          // selection (callback null == the pre-adoption
                          // behaviour). Selection + emission live in this
                          // State: default 15% is a visual default only —
                          // `_tipCents` stays 0 until the customer taps
                          // (unchanged; nothing is charged implicitly).
                          if (restaurantConfig?.tipEnabled ?? false)
                            TipSelector<int>(
                              options: tipOptions,
                              selectedOption: tipOptions.firstWhere(
                                (option) => option.value == _selectedTipPercent,
                                orElse: () => tipOptions.first,
                              ),
                              title: loc.tipAddForDriver,
                              onChanged: (option) => setState(() {
                                _selectedTipPercent = option.value;
                                _tipCents = tipCentsForPercent(
                                  subtotal,
                                  option.value,
                                );
                              }),
                              selectedSummaryLabel: _selectedTipPercent == 0
                                  ? null
                                  : (option) => loc.tipSelectedLabel(
                                      moneyCents(
                                        tipCentsForPercent(
                                          subtotal,
                                          option.value,
                                        ),
                                        currencyCode: currencyCode,
                                      ),
                                    ),
                            ),
                          Gap.v24,
                          Semantics(
                            label: loc.placeOrder,
                            button: true,
                            child: BrandButton(
                              text: loc.placeOrder,
                              isLoading: _isProcessing,
                              onPressed: () => _processPayment(subtotal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(
                    begin: 1.0,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),
                ],
              );
              if (cartAsync.isRefreshing) {
                return Stack(
                  children: [
                    content,
                    const PositionedDirectional(
                      top: 8,
                      end: 8,
                      // UI-13 (p21 F3-09): the refresh indicator adopts the
                      // library skeleton block (same 24×24 footprint, library
                      // radius default) — no raw `CircularProgressIndicator`
                      // remains.
                      child: SkeletonLoader(width: 24, height: 24),
                    ),
                  ],
                );
              }
              return content;
            },
          ),
        ),
      ),
    );
  }
}
