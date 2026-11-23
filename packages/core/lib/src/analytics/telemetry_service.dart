import 'dart:async' show unawaited;

import 'package:core/src/network/firestore_client.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/src/compliance/gdpr_consent.dart';
import 'package:core/src/config/core_config.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/analytics/analytics_service.dart';
import 'package:core/src/analytics/ecommerce_events.dart';
import 'package:flutter/foundation.dart';

/// Lightweight wrapper around the `logFunnelEvent` Cloud Function.
/// In demo mode, writes events directly to Firestore analyticsEvents collection.
/// Drop-in replacement for a Mixpanel/Amplitude SDK.
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._();
  factory TelemetryService() => _instance;

  final FirebaseFunctions? _functions;
  final FirebaseFirestore? _firestore;
  final AnalyticsService? _analytics;

  TelemetryService._({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    AnalyticsService? analytics,
  }) : _functions = functions,
       _firestore = firestore,
       _analytics = analytics;

  /// Test-only constructor: a NON-singleton instance with injected backends,
  /// so the consent gate can be proven against a [FakeFirebaseFirestore]
  /// without touching Firebase platform channels (W9.8 T-1 seam).
  @visibleForTesting
  factory TelemetryService.forTest({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    AnalyticsService? analytics,
  }) => TelemetryService._(
    functions: functions,
    firestore: firestore,
    analytics: analytics,
  );

  HttpsCallable get _fn => (_functions ?? FirebaseFunctions.instance)
      .httpsCallable('logFunnelEvent');

  FirebaseFirestore get _db => _firestore ?? FirestoreClient.instance.db;

  /// THE consent gate — ONE place, fail-closed (L1).
  ///
  /// Reads the canonical W9.8 key: `true` only when the customer ACCEPTED.
  /// Absent (never asked) and `false` (declined) both block — analytics is
  /// opt-in. Every gated method below funnels through this single read.
  /// A preference-store failure blocks TOO (fail-closed): if we cannot prove
  /// consent, nothing is sent.
  Future<bool> _hasConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kGdprAnalyticsConsentKey) ?? false;
    } catch (_) {
      // Fail-closed (L1): unreadable consent state == no consent. The gate
      // must never throw into a fire-and-forget call site (residual 28.5).
      return false;
    }
  }

  /// Fire-and-forget. Never throws — analytics must never crash the app.
  Future<void> log(String event, {Map<String, dynamic>? properties}) async {
    try {
      // W9.8: the ONE canonical consent key (gdpr_analytics_consent). Before
      // UX-3 this service read the canonical key while the dialog wrote the
      // LEGACY key — an accepted consent dialog never enabled telemetry.
      // Decline (false) and never-asked (absent) both block here.
      if (!await _hasConsent()) return;

      // ── DEMO MODE: Direct Firestore write ─────────────────────────────────
      if (CoreConfigHolder.instance.isDemoMode) {
        await _db.collection('analyticsEvents').add({
          'event': event,
          'properties': properties ?? {},
          'timestamp': FieldValue.serverTimestamp(),
        });
        return;
      }
      // ── PRODUCTION MODE: Cloud Function aggregation pipeline ──────────────
      await _fn.call({'event': event, 'properties': properties ?? {}});
    } catch (e, stack) {
      // Double-fault guard: the logger itself can be unavailable (disk full,
      // unmocked path_provider channel) — a telemetry failure must NEVER
      // escape to its fire-and-forget callers (residual 28.5).
      try {
        await LoggerService().error(e, 'TelemetryLogEventError', stack: stack);
      } catch (_) {
        // Swallow — analytics must never break its caller.
      }
    }
  }

  // ── Predefined events ──────────────────────────────────────────────────────
  /// `cart_viewed` — fired by [CartScreen] initState (funnel step 1).
  Future<void> cartViewed() => log('cart_viewed', properties: {});

  Future<void> viewMenuItem(String itemId) =>
      log('view_menu_item', properties: {'item_id': itemId});

  Future<void> addToCart(String itemId, int priceCents, {int? quantity}) => log(
    'add_to_cart',
    properties: {
      'item_id': itemId,
      'quantity': quantity ?? 1,
      'price_cents': priceCents,
    },
  );

  /// `begin_checkout` — fired by [CartScreen] when the cart proceeds to
  /// checkout (funnel step 2, "checkout open").
  Future<void> beginCheckout(int cartTotalCents) =>
      log('begin_checkout', properties: {'cart_total_cents': cartTotalCents});

  /// `checkout_abandon` — fired when the customer leaves checkout without
  /// completing (PopScope-blocked back press / in-flight exit / payment fail).
  Future<void> checkoutAbandoned(int cartTotalCents) =>
      log('checkout_abandon', properties: {'cart_total_cents': cartTotalCents});

  // ── GA4 ecommerce layer (UI-7 p17, T-1/T-2) ───────────────────────────────
  //
  // Every method below is a NO-OP unless GDPR analytics consent was granted:
  // the gate is read ONCE through `_hasConsent()` (the same single read `log`
  // uses) BEFORE the first-party GA4 substrate is touched, so a declined /
  // never-asked customer produces ZERO GA4 calls and ZERO pipeline calls —
  // asserted in `test/core/analytics/ecommerce_analytics_test.dart`.
  //
  // Call sites stay gate-free: they only build the typed event objects.
  // L6: where an internal funnel event already existed for the same step it
  // keeps firing beside the GA4 event (documented pairing in
  // `EcommerceTaxonomy.internalFunnelPairing`) — nothing is replaced.

  /// Fire-and-forget GA4 dispatch that can NEVER throw into a call site.
  ///
  /// A null call (no SDK instance: demo mode, offline, tests) is a silent
  /// no-op; a failing SDK call is logged through the same double-fault guard
  /// `log` uses (the logger itself can be unavailable) — an analytics failure
  /// must never surface to the customer.
  Future<void> _dispatchGa4(Future<void>? call) async {
    if (call == null) return;
    try {
      await call;
    } catch (e, stack) {
      try {
        await LoggerService().error(
          e,
          'AnalyticsGa4DispatchError',
          stack: stack,
        );
      } catch (_) {
        // Swallow — analytics must never break its caller.
      }
    }
  }

  /// GA4 `view_item` (dish detail opened) + the internal `view_item` step.
  Future<void> viewItem(ViewItemEvent event) async {
    if (!await _hasConsent()) return;
    unawaited(_dispatchGa4(_analytics?.logViewItem(event)));
    return log('view_item', properties: event.item.toParams());
  }

  /// GA4 `add_to_cart` (one dish added) + the internal `add_to_cart` step.
  Future<void> addToCartItem(AddToCartEvent event) async {
    if (!await _hasConsent()) return;
    unawaited(_dispatchGa4(_analytics?.logAddToCart(event)));
    return log('add_to_cart', properties: event.item.toParams());
  }

  /// GA4 `begin_checkout` (cart opened checkout, EVERY line) + the internal
  /// `begin_checkout` step, which keeps its `cart_total_cents` property.
  Future<void> beginCheckoutItems(BeginCheckoutEvent event) async {
    if (!await _hasConsent()) return;
    unawaited(_dispatchGa4(_analytics?.logBeginCheckout(event)));
    return log(
      'begin_checkout',
      properties: {'cart_total_cents': event.valueCents},
    );
  }

  /// GA4 `add_payment_info` (payment step reached). The internal vocabulary has
  /// no equivalent step — only the GA4 event fires here.
  Future<void> addPaymentInfo(AddPaymentInfoEvent event) async {
    if (!await _hasConsent()) return;
    return _dispatchGa4(_analytics?.logAddPaymentInfo(event));
  }

  /// GA4 `purchase` (order succeeded, `transaction_id` = order id). Fired
  /// BESIDE the existing internal `order_completed` call, from the same
  /// order-success point (L6) — the internal event is not replaced.
  Future<void> purchase(PurchaseEvent event) async {
    if (!await _hasConsent()) return;
    return _dispatchGa4(_analytics?.logPurchase(event));
  }

  /// `order_completed` — fired on createOrder success; ALSO delegates to the
  /// first-party [AnalyticsService.logOrderPlaced] so the conversion event
  /// reaches BOTH stacks (P3-4 single facade — "where both exist").
  Future<void> orderCompleted(String orderId, int totalCents) {
    unawaited(_analytics?.logOrderPlaced(orderId, totalCents));
    return log(
      'order_completed',
      properties: {'order_id': orderId, 'total_cents': totalCents},
    );
  }

  /// `order_cancelled` — fired by [OrderRepository.cancelOrder] (its natural
  /// site). ALSO delegates to the first-party
  /// [AnalyticsService.logOrderCancelled] so BOTH stacks record it (P3-4
  /// single facade — "where both exist").
  Future<void> orderCancelled(String orderId, String reason) {
    unawaited(_analytics?.logOrderCancelled(orderId, reason));
    return log(
      'order_cancelled',
      properties: {'order_id': orderId, 'reason': reason},
    );
  }

  Future<void> promoApplied(String code, int discountCents) => log(
    'promo_applied',
    properties: {'code': code, 'discount_cents': discountCents},
  );

  // ── Failure events (UX-4 / 07-P1-7 — previously absent from both stacks) ──
  /// `order_failed` — emitted when `createOrder` (the server authority)
  /// rejects or throws, so the funnel sees the drop-off.
  Future<void> orderFailed(String orderId, {String? reason}) => log(
    'order_failed',
    properties: {'order_id': orderId, if (reason != null) 'reason': reason},
  );

  /// `payment_declined` — emitted when the Stripe charge itself is declined.
  Future<void> paymentDeclined({String? reason}) => log(
    'payment_declined',
    properties: {if (reason != null) 'reason': reason},
  );

  /// `offline_queue_depth` — emitted when an order is queued for offline
  /// sync; the depth shows how many orders are awaiting connectivity.
  Future<void> offlineQueueDepth(int pendingCount) =>
      log('offline_queue_depth', properties: {'pending_count': pendingCount});
}
