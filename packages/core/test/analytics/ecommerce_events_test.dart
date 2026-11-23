// UI-7 (p17 §5) — package-level contract test for the NEW taxonomy file.
//
// Purpose: `packages/core` coverage is measured from THIS package's own suite
// (`flutter test --coverage` → lcov), while the consent/telemetry integration
// lives in core_app's `test/core/analytics/ecommerce_analytics_test.dart`.
// This file pins the same GA4 contract at the package boundary AND carries
// the 100%-lines receipt for `src/analytics/ecommerce_events.dart`.
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsItem — GA4 item shape', () {
    test('price/lineTotalCents scale cents exactly (L2 — no reformatting)', () {
      const item = AnalyticsItem(
        itemId: 'd1',
        itemName: 'Shawarma',
        priceCents: 1850,
        quantity: 2,
      );
      expect(item.price, 18.5);
      expect(item.lineTotalCents, 3700);

      const viewDefault = AnalyticsItem(
        itemId: 'd2',
        itemName: 'Fries',
        priceCents: 500,
      );
      expect(viewDefault.quantity, 1);
      expect(viewDefault.lineTotalCents, 500);
    });

    test('toEventItem maps the four fields onto the SDK type', () {
      const item = AnalyticsItem(
        itemId: 'd3',
        itemName: 'Shawarma Wrap',
        priceCents: 1250,
        quantity: 3,
      );
      final sdk = item.toEventItem();
      expect(sdk.itemId, 'd3');
      expect(sdk.itemName, 'Shawarma Wrap');
      expect(sdk.price, 12.5);
      expect(sdk.quantity, 3);
    });

    test('toParams mirrors GA4 param names (L6 internal pairing)', () {
      const item = AnalyticsItem(
        itemId: 'd4',
        itemName: 'Burger',
        priceCents: 900,
        quantity: 2,
      );
      expect(item.toParams(), <String, Object?>{
        'item_id': 'd4',
        'item_name': 'Burger',
        'price': 9.0,
        'quantity': 2,
      });
    });

    test('value equality, hashCode and toString', () {
      const a = AnalyticsItem(
        itemId: 'd5',
        itemName: 'Shawarma',
        priceCents: 1850,
        quantity: 2,
      );
      const b = AnalyticsItem(
        itemId: 'd5',
        itemName: 'Shawarma',
        priceCents: 1850,
        quantity: 2,
      );
      const other = AnalyticsItem(
        itemId: 'd6',
        itemName: 'Shawarma',
        priceCents: 1850,
      );
      expect(a, b);
      expect(a, isNot(other));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), 'AnalyticsItem(d5, Shawarma, 1850c x2)');
    });

    test('non-const construction executes the factory at runtime', () {
      // A list index is not a constant expression, so this is a genuine
      // runtime constructor call (keeps the factory line in lcov).
      final qty = [1, 2][1];
      final item = AnalyticsItem(
        itemId: 'd7',
        itemName: 'Shawarma',
        priceCents: 1850,
        quantity: qty,
      );
      expect(item.lineTotalCents, 3700);
    });
  });

  group('event value getters — cents to currency units', () {
    test('BeginCheckoutEvent / ViewItemEvent / AddToCartEvent', () {
      const line = AnalyticsItem(
        itemId: 'd1',
        itemName: 'Shawarma',
        priceCents: 1850,
        quantity: 2,
      );
      expect(
        const BeginCheckoutEvent(
          items: [line],
          currency: 'USD',
          valueCents: 3700,
        ).value,
        37.0,
      );
      expect(const ViewItemEvent(item: line, currency: 'USD').value, 37.0);
      expect(const AddToCartEvent(item: line, currency: 'USD').value, 37.0);
    });

    test('AddPaymentInfoEvent keeps optional payment_type + coupon', () {
      const withOptionals = AddPaymentInfoEvent(
        items: [
          AnalyticsItem(itemId: 'd1', itemName: 'Shawarma', priceCents: 1850),
        ],
        currency: 'USD',
        valueCents: 1850,
        paymentType: 'card',
        coupon: 'WELCOME10',
      );
      const bare = AddPaymentInfoEvent(
        items: [
          AnalyticsItem(itemId: 'd1', itemName: 'Shawarma', priceCents: 1850),
        ],
        currency: 'USD',
        valueCents: 1850,
      );
      expect(withOptionals.value, 18.5);
      expect(withOptionals.paymentType, 'card');
      expect(withOptionals.coupon, 'WELCOME10');
      expect(bare.paymentType, isNull);
      expect(bare.coupon, isNull);
    });

    test(
      'PurchaseEvent value/tax/shipping with and without optional cents',
      () {
        const full = PurchaseEvent(
          transactionId: 'o1',
          items: [
            AnalyticsItem(
              itemId: 'd1',
              itemName: 'Shawarma',
              priceCents: 1850,
              quantity: 2,
            ),
          ],
          currency: 'USD',
          valueCents: 4000,
          taxCents: 300,
          shippingCents: 500,
          coupon: 'WELCOME10',
        );
        const bare = PurchaseEvent(
          transactionId: 'o2',
          items: [
            AnalyticsItem(itemId: 'd2', itemName: 'Fries', priceCents: 500),
          ],
          currency: 'USD',
          valueCents: 500,
        );
        expect(full.value, 40.0);
        expect(full.tax, 3.0);
        expect(full.shipping, 5.0);
        expect(full.coupon, 'WELCOME10');
        expect(bare.value, 5.0);
        expect(bare.tax, isNull);
        expect(bare.shipping, isNull);
        expect(bare.coupon, isNull);
      },
    );
  });

  group('EcommerceTaxonomy — L3 limits', () {
    test('the shipped table is violation-free', () {
      expect(EcommerceTaxonomy.violations(), isEmpty);
      expect(EcommerceTaxonomy.maxParamsPerEvent, 25);
      expect(EcommerceTaxonomy.maxParamNameLength, 40);
      expect(EcommerceTaxonomy.maxValueLength, 100);
      expect(EcommerceTaxonomy.events, hasLength(5));
      expect(
        EcommerceTaxonomy.internalFunnelPairing['order_completed'],
        'purchase',
      );
      expect(EcommerceTaxonomy.namePattern.hasMatch('add_to_cart'), isTrue);
      expect(EcommerceTaxonomy.namePattern.hasMatch('Bad Name'), isFalse);
    });

    test('violationsOf judges a bad-name spec', () {
      final issues = EcommerceTaxonomy.violationsOf(const [
        EcommerceEventSpec(name: 'Bad Name', params: ['item_id']),
      ]);
      expect(issues, hasLength(1));
      expect(issues.single, contains('not lowercase_snake'));
    });

    test('violationsOf flags an event over the 25-param ceiling', () {
      final params = [for (var i = 0; i < 26; i++) 'p$i'];
      final issues = EcommerceTaxonomy.violationsOf([
        EcommerceEventSpec(name: 'over_limit', params: params),
      ]);
      expect(issues.single, contains('GA4 allows 25'));
    });

    test('violationsOf flags a >40-char param name', () {
      final longName = 'a' * 41;
      final issues = EcommerceTaxonomy.violationsOf([
        EcommerceEventSpec(name: 'long_param', params: [longName]),
      ]);
      expect(issues.single, contains('GA4 allows 40'));
    });

    test('violationsOf flags a non-snake param name', () {
      final issues = EcommerceTaxonomy.violationsOf(const [
        EcommerceEventSpec(name: 'bad_param_name', params: ['BadParam']),
      ]);
      expect(issues.single, contains('"BadParam" is not lowercase_snake'));
    });
  });
}
