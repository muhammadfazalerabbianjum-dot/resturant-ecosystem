/// GA4 canonical ecommerce vocabulary for the client analytics layer (UI-7).
///
/// Source of truth: `firebase.google.com/docs/analytics/measure-ecommerce`
/// (researched in `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md`, Track 1). The five
/// events below are GA4's RECOMMENDED (reserved) ecommerce events, so funnels,
/// BigQuery export tables and Looker templates work with zero bespoke mapping.
///
/// Laws honoured here:
/// * **L2 — zero money math.** Every `int` here is an integer-cent value read
///   straight off a model (`MenuItemModel.priceCents`, `CartItemModel.
///   unitPriceCents`/`totalCents`, `OrderModel.totalCents`/`taxCents`/
///   `deliveryFeeCents`). The ONLY transformation is the cents -> currency-unit
///   scaling GA4 itself mandates (`1850 -> 18.5`); no total is recomputed.
/// * **L3 — GA4 limits.** [EcommerceTaxonomy] carries the shipped table and its
///   limits; `EcommerceTaxonomy.violations()` is asserted empty by
///   `test/core/analytics/ecommerce_analytics_test.dart`.
/// * **L6 — coexistence.** The internal funnel vocabulary (`view_menu_item`,
///   `add_to_cart`, `begin_checkout`, `order_completed`, `order_cancelled`, …)
///   keeps firing through `TelemetryService.log`; the GA4 events are the
///   ecommerce-standard layer on top. See
///   [EcommerceTaxonomy.internalFunnelPairing].
library;

import 'package:firebase_analytics/firebase_analytics.dart';

/// ISO 4217 fallback used when the runtime restaurant config has not resolved
/// yet — mirrors `RestaurantConfigModel.currency`'s `@Default('USD')`, so the
/// GA4 `currency` param is never null or empty (spec T-1 requires
/// `currency`/`value` together).
const String kDefaultAnalyticsCurrency = 'USD';

/// One `items[]` entry: the GA4 item shape used by every ecommerce event.
///
/// Only the four fields the owner's questions need are modelled
/// (`item_id`, `item_name`, `price`, `quantity`); dishes are referenced by id
/// and name — never by customer-identifying data (rule 0.10, no PII).
class AnalyticsItem {
  /// Dish/menu identifier (`item_id`).
  final String itemId;

  /// Human-readable dish name (`item_name`).
  final String itemName;

  /// Integer cents, EXACTLY as the model stores it (never reformatted).
  final int priceCents;

  /// Units ordered (`quantity`); defaults to 1 for a dish-detail view.
  final int quantity;

  const AnalyticsItem({
    required this.itemId,
    required this.itemName,
    required this.priceCents,
    this.quantity = 1,
  });

  /// GA4 `price`: integer cents expressed in currency units (`1850 -> 18.5`).
  double get price => priceCents / 100;

  /// GA4 `value` for a SINGLE-item event (`price * quantity` of that line).
  ///
  /// Multi-line events (begin_checkout / add_payment_info / purchase) take
  /// their `value` from the cart or order model instead — never from this
  /// getter — so no order total is ever recomputed client-side.
  int get lineTotalCents => priceCents * quantity;

  /// The SDK-typed item the `firebase_analytics` ecommerce helpers take.
  AnalyticsEventItem toEventItem() => AnalyticsEventItem(
    itemId: itemId,
    itemName: itemName,
    price: price,
    quantity: quantity,
  );

  /// The same four fields as GA4 param names — used for the internal funnel
  /// event that keeps riding beside the GA4 event (L6).
  Map<String, Object?> toParams() => <String, Object?>{
    'item_id': itemId,
    'item_name': itemName,
    'price': price,
    'quantity': quantity,
  };

  @override
  bool operator ==(Object other) =>
      other is AnalyticsItem &&
      other.itemId == itemId &&
      other.itemName == itemName &&
      other.priceCents == priceCents &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(itemId, itemName, priceCents, quantity);

  @override
  String toString() =>
      'AnalyticsItem($itemId, $itemName, ${priceCents}c x$quantity)';
}

/// `begin_checkout` — the cart proceeded to checkout; carries EVERY line.
class BeginCheckoutEvent {
  const BeginCheckoutEvent({
    required this.items,
    required this.currency,
    required this.valueCents,
  });

  /// Every cart line (GA4 `items[]`) — never just the first.
  final List<AnalyticsItem> items;
  final String currency;

  /// GA4 `value` in integer cents, read from `CartModel.totalCents` (L2).
  final int valueCents;

  /// GA4 `value` in currency units.
  double get value => valueCents / 100;
}

/// `add_payment_info` — the payment step was reached.
class AddPaymentInfoEvent {
  const AddPaymentInfoEvent({
    required this.items,
    required this.currency,
    required this.valueCents,
    this.paymentType,
    this.coupon,
  });

  final List<AnalyticsItem> items;
  final String currency;

  /// GA4 `value` in integer cents, read from `CartModel.totalCents` (L2).
  final int valueCents;

  /// GA4 `payment_type` (e.g. `card`); optional.
  final String? paymentType;

  /// GA4 `coupon` — the applied promo code, when one is active.
  final String? coupon;

  double get value => valueCents / 100;
}

/// `purchase` — the order succeeded. `transactionId` is the ORDER id, so GA4
/// de-duplicates retries of the same order (the same id the internal
/// `order_completed` event carries).
class PurchaseEvent {
  const PurchaseEvent({
    required this.transactionId,
    required this.items,
    required this.currency,
    required this.valueCents,
    this.taxCents,
    this.shippingCents,
    this.coupon,
  });

  /// GA4 `transaction_id` — the order document id.
  final String transactionId;
  final List<AnalyticsItem> items;
  final String currency;

  /// GA4 `value` in integer cents, read from `OrderModel.totalCents` (L2).
  final int valueCents;

  /// GA4 `tax` in integer cents, read from `OrderModel.taxCents` (L2).
  final int? taxCents;

  /// GA4 `shipping` in integer cents, read from
  /// `OrderModel.deliveryFeeCents` (L2).
  final int? shippingCents;

  /// GA4 `coupon` — the promo code, when one was applied.
  final String? coupon;

  double get value => valueCents / 100;
  double? get tax => taxCents == null ? null : taxCents! / 100;
  double? get shipping => shippingCents == null ? null : shippingCents! / 100;
}

/// One row of the GA4 taxonomy table: event name + the params it may carry.
class EcommerceEventSpec {
  const EcommerceEventSpec({required this.name, required this.params});

  /// GA4 event name (lowercase_snake).
  final String name;

  /// GA4 parameter names the event carries.
  final List<String> params;
}

/// The shipped GA4 taxonomy + its limits (L3), pinned by a unit test.
///
/// Limits come from the GA4 documented ceilings: at most **25** params per
/// event, param names at most **40** characters, param values at most **100**
/// characters. [violations] is asserted empty for [events]; [violationsOf]
/// exists so the same rule set can judge any candidate table (the negative
/// control in the test suite).
abstract final class EcommerceTaxonomy {
  /// GA4: at most 25 custom params per event.
  static const int maxParamsPerEvent = 25;

  /// GA4: parameter names are at most 40 characters.
  static const int maxParamNameLength = 40;

  /// GA4: parameter values are at most 100 characters.
  static const int maxValueLength = 100;

  /// The five ecommerce events this batch logs, with the params each carries.
  static const List<EcommerceEventSpec> events = <EcommerceEventSpec>[
    EcommerceEventSpec(
      name: 'view_item',
      params: [
        'item_id',
        'item_name',
        'price',
        'quantity',
        'currency',
        'value',
      ],
    ),
    EcommerceEventSpec(
      name: 'add_to_cart',
      params: [
        'item_id',
        'item_name',
        'price',
        'quantity',
        'currency',
        'value',
      ],
    ),
    EcommerceEventSpec(
      name: 'begin_checkout',
      params: [
        'item_id',
        'item_name',
        'price',
        'quantity',
        'currency',
        'value',
        'coupon',
      ],
    ),
    EcommerceEventSpec(
      name: 'add_payment_info',
      params: [
        'item_id',
        'item_name',
        'price',
        'quantity',
        'currency',
        'value',
        'payment_type',
        'coupon',
      ],
    ),
    EcommerceEventSpec(
      name: 'purchase',
      params: [
        'transaction_id',
        'item_id',
        'item_name',
        'price',
        'quantity',
        'currency',
        'value',
        'tax',
        'shipping',
        'coupon',
      ],
    ),
  ];

  /// L6: the internal funnel vocabulary that KEEPS firing beside the GA4 layer
  /// (nothing is replaced, nothing carries two meanings).
  static const Map<String, String> internalFunnelPairing = <String, String>{
    'cart_viewed': 'funnel step 1 (unchanged; GA4 has no equivalent)',
    'view_menu_item': 'view_item',
    'add_to_cart': 'add_to_cart',
    'begin_checkout': 'begin_checkout',
    'checkout_abandon': 'begin_checkout with no purchase (abandonment)',
    'order_completed': 'purchase',
    'order_cancelled': 'refund (not logged in v1 - no roll-up function)',
  };

  /// `^[a-z][a-z0-9_]*$` — GA4 event and param names are lowercase_snake.
  static final RegExp namePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Violations for the SHIPPED table (empty == valid).
  static List<String> violations() => violationsOf(events);

  /// Violations for an arbitrary table. Each entry names the offending event.
  static List<String> violationsOf(List<EcommerceEventSpec> specs) {
    final issues = <String>[];
    for (final spec in specs) {
      if (!namePattern.hasMatch(spec.name)) {
        issues.add('event "${spec.name}" is not lowercase_snake');
      }
      if (spec.params.length > maxParamsPerEvent) {
        issues.add(
          'event "${spec.name}" has ${spec.params.length} params '
          '(GA4 allows $maxParamsPerEvent)',
        );
      }
      for (final param in spec.params) {
        if (param.length > maxParamNameLength) {
          issues.add(
            'event "${spec.name}" param "$param" is ${param.length} chars '
            '(GA4 allows $maxParamNameLength)',
          );
        } else if (!namePattern.hasMatch(param)) {
          issues.add(
            'event "${spec.name}" param "$param" is not lowercase_snake',
          );
        }
      }
    }
    return issues;
  }
}

/// which is the per-dish dwell-time source; no custom timer needed).
class ViewItemEvent {
  const ViewItemEvent({required this.item, required this.currency});
  final AnalyticsItem item;
  final String currency;

  /// GA4 `value` — this line's value (see [AnalyticsItem.lineTotalCents]).
  double get value => item.lineTotalCents / 100;
}

/// `add_to_cart` — a dish was added from the menu or the dish detail.
class AddToCartEvent {
  const AddToCartEvent({required this.item, required this.currency});
  final AnalyticsItem item;
  final String currency;

  /// GA4 `value` — this line's value.
  double get value => item.lineTotalCents / 100;
}
