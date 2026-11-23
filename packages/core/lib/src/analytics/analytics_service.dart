import 'package:core/src/analytics/ecommerce_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart' show NavigatorObserver;

/// Typed façade over the FIRST-PARTY `FirebaseAnalytics` event surface.
///
/// UX-4 (07-P1-7 / W9.12) decision: the 13 methods that had ZERO production
/// call sites were DELETED (not silently kept — dead code violates Law 3).
/// The three methods with natural production call sites are kept and wired,
/// and `TelemetryService` delegates to these where both stacks exist so the
/// checkout funnel reaches BOTH the first-party Firebase Analytics surface
/// AND the `logFunnelEvent` Cloud Function/`analyticsEvents` pipeline.
///
/// Every method is fire-and-forget-safe: the underlying `FirebaseAnalytics`
/// instance is optional (null in test/offline contexts via [AnalyticsService
/// .safe]), and a missing instance is a no-op — analytics must never crash
/// the ordering path.
class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  AnalyticsService([this._analytics]);

  factory AnalyticsService.safe() {
    try {
      return AnalyticsService(FirebaseAnalytics.instance);
    } catch (_) {
      return AnalyticsService(null);
    }
  }

  /// Fired by `TelemetryService.orderPlaced` (createOrder success, facade).
  Future<void> logOrderPlaced(String orderId, int totalCents) async =>
      _analytics?.logEvent(
        name: 'order_placed',
        parameters: {'order_id': orderId, 'total_cents': totalCents},
      );

  /// Fired by the order-cancel flow (user cancels a pending/confirmed order).
  Future<void> logOrderCancelled(String orderId, String reason) async =>
      _analytics?.logEvent(
        name: 'order_cancelled',
        parameters: {'order_id': orderId, 'reason': reason},
      );

  /// Fired on destructive admin actions (owner/manager dashboards).
  Future<void> logAdminAction(String action, String targetId) async =>
      _analytics?.logEvent(
        name: 'admin_action',
        parameters: {'action': action, 'target_id': targetId},
      );

  // ── GA4 canonical ecommerce layer (UI-7 p17, T-1) ────────────────────────
  //
  // WHY these live here: this façade is the ONLY first-party
  // `FirebaseAnalytics` surface in the fleet (`TelemetryService` delegates to
  // it). The SDK's own typed ecommerce helpers are used — it owns the wire
  // encoding of `items[]`, so the param names/limits in
  // `EcommerceTaxonomy` stay Google's documented vocabulary (L3) instead of a
  // hand-rolled map.
  //
  // CONSENT: nothing here reads consent — the goal is ONE gate in ONE place
  // (L1). `TelemetryService` (the gated façade every call site uses) is the
  // only caller; the consent=false ⇒ ZERO calls proof lives in
  // `test/core/analytics/ecommerce_analytics_test.dart`.

  /// GA4 `view_item` — dish detail opened. GA4 attaches `engagement_time_msec`
  /// automatically, which is the per-dish dwell-time source (no custom timer).
  Future<void> logViewItem(ViewItemEvent event) async {
    await _analytics?.logViewItem(
      items: [event.item.toEventItem()],
      value: event.value,
      currency: event.currency,
    );
  }

  /// GA4 `add_to_cart` — one dish added (menu list or dish detail).
  Future<void> logAddToCart(AddToCartEvent event) async {
    await _analytics?.logAddToCart(
      items: [event.item.toEventItem()],
      value: event.value,
      currency: event.currency,
    );
  }

  /// GA4 `begin_checkout` — the cart opened the checkout flow, with EVERY line.
  Future<void> logBeginCheckout(BeginCheckoutEvent event) async {
    await _analytics?.logBeginCheckout(
      items: event.items.map((i) => i.toEventItem()).toList(),
      value: event.value,
      currency: event.currency,
    );
  }

  /// GA4 `add_payment_info` — the payment step was reached.
  Future<void> logAddPaymentInfo(AddPaymentInfoEvent event) async {
    await _analytics?.logAddPaymentInfo(
      items: event.items.map((i) => i.toEventItem()).toList(),
      value: event.value,
      currency: event.currency,
      paymentType: event.paymentType,
      coupon: event.coupon,
    );
  }

  /// GA4 `purchase` — the ecommerce-standard conversion event. `transactionId`
  /// is the ORDER id, so Firestore/GA4 retries collapse onto one conversion.
  Future<void> logPurchase(PurchaseEvent event) async {
    await _analytics?.logPurchase(
      transactionId: event.transactionId,
      items: event.items.map((i) => i.toEventItem()).toList(),
      value: event.value,
      currency: event.currency,
      tax: event.tax,
      shipping: event.shipping,
      coupon: event.coupon,
    );
  }

  /// UX-4 (07-P1-7 / W9.12 contract #2): the navigator observers for the
  /// ACTIVE [GoRouter] — one [FirebaseAnalyticsObserver] emitting
  /// `screen_view` on every named route push/pop (routes carry their
  /// registered name via `FadeSlideTransitionPage(name:)`).
  ///
  /// Returns an EMPTY list when Firebase is not initialized (demo mode,
  /// tests, the pre-init crash window): `Firebase.apps.isEmpty` is the
  /// documented test contract (flutter_test_config.dart) and
  /// `FirebaseAnalytics.instance` THROWS before init — router construction
  /// must never crash for analytics. Screen-view emission inside the
  /// observer is fire-and-forget (PlatformException → debugPrint) and the
  /// test binary messenger is served by the recording fake
  /// (test/helpers/fake_firebase_analytics_platform.dart).
  static List<NavigatorObserver> routeObservers() {
    try {
      if (Firebase.apps.isEmpty) return const [];
      return [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)];
    } catch (_) {
      return const [];
    }
  }
}
