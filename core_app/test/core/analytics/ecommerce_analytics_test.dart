// UI-7 (p17) T-1 RED/GREEN — GA4 ecommerce taxonomy on the SINGLE consent gate.
//
// Contract: WHITE_LABEL_p17_analytics1.md §0.9/§0.10, L1 (consent gate in one
// place, fail-closed), L2 (zero money math — value comes from the model),
// L3 (GA4 limits pinned by a unit test), L6 (logOrderPlaced stays the internal
// lifecycle event; the GA4 purchase layer is additive).
//
// The L1 proof is behavioural: consent not granted => ZERO calls on the GA4
// substrate (AnalyticsService) AND zero calls on the funnel pipeline.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

const _kCurrency = 'USD';

/// The dish used across the params-snapshot assertions.
const _shawarma = AnalyticsItem(
  itemId: 'dish_shawarma',
  itemName: 'Chicken Shawarma',
  priceCents: 1850,
  quantity: 2,
);

/// A second cart line — proves items[] carries EVERY line, not just the first.
const _ayran = AnalyticsItem(
  itemId: 'dish_ayran',
  itemName: 'Ayran',
  priceCents: 350,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    // mocktail needs a fallback instance for every custom type used with any().
    registerFallbackValue(_viewItemEvent());
    registerFallbackValue(_addToCartEvent());
    registerFallbackValue(_beginCheckoutEvent());
    registerFallbackValue(_paymentInfoEvent());
    registerFallbackValue(_purchaseEvent());
  });

  group('T-1 L1 — consent gate is the ONLY switch (fail-closed)', () {
    late _MockFirebaseFunctions functions;
    late _MockHttpsCallable callable;
    late _MockAnalyticsService analytics;
    late TelemetryService sut;

    setUp(() {
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(
        () => functions.httpsCallable('logFunnelEvent'),
      ).thenReturn(callable);
      when(
        () => callable.call(any()),
      ).thenAnswer((_) async => _MockHttpsCallableResult());
      analytics = _MockAnalyticsService();
      sut = TelemetryService.forTest(
        analytics: analytics,
        functions: functions,
      );
    });

    test(
      'consent DECLINED => zero GA4 calls and zero pipeline calls',
      () async {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: false,
        });

        await sut.viewItem(_viewItemEvent());
        await sut.addToCartItem(_addToCartEvent());
        await sut.beginCheckoutItems(_beginCheckoutEvent());
        await sut.addPaymentInfo(_paymentInfoEvent());
        await sut.purchase(_purchaseEvent());

        verifyNever(() => analytics.logViewItem(any()));
        verifyNever(() => analytics.logAddToCart(any()));
        verifyNever(() => analytics.logBeginCheckout(any()));
        verifyNever(() => analytics.logAddPaymentInfo(any()));
        verifyNever(() => analytics.logPurchase(any()));
        verifyNever(() => callable.call(any()));
      },
    );

    test('consent NEVER ASKED (absent key) => zero calls', () async {
      SharedPreferences.setMockInitialValues({});

      await sut.viewItem(_viewItemEvent());
      await sut.addToCartItem(_addToCartEvent());
      await sut.beginCheckoutItems(_beginCheckoutEvent());
      await sut.addPaymentInfo(_paymentInfoEvent());
      await sut.purchase(_purchaseEvent());

      verifyNever(() => analytics.logViewItem(any()));
      verifyNever(() => analytics.logPurchase(any()));
      verifyNever(() => callable.call(any()));
    });
  });

  group(
    'T-1 — typed GA4 params per the documented vocabulary (consent granted)',
    () {
      late _MockFirebaseFunctions functions;
      late _MockHttpsCallable callable;
      late _MockAnalyticsService analytics;
      late TelemetryService sut;

      setUp(() {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: true,
        });
        functions = _MockFirebaseFunctions();
        callable = _MockHttpsCallable();
        when(
          () => functions.httpsCallable('logFunnelEvent'),
        ).thenReturn(callable);
        when(
          () => callable.call(any()),
        ).thenAnswer((_) async => _MockHttpsCallableResult());
        analytics = _MockAnalyticsService();
        when(() => analytics.logViewItem(any())).thenAnswer((_) async {});
        when(() => analytics.logAddToCart(any())).thenAnswer((_) async {});
        when(() => analytics.logBeginCheckout(any())).thenAnswer((_) async {});
        when(() => analytics.logAddPaymentInfo(any())).thenAnswer((_) async {});
        when(() => analytics.logPurchase(any())).thenAnswer((_) async {});
        sut = TelemetryService.forTest(
          analytics: analytics,
          functions: functions,
        );
      });

      test('view_item carries the dish as items[] + value/currency', () async {
        await sut.viewItem(_viewItemEvent());

        final captured =
            verify(() => analytics.logViewItem(captureAny())).captured.single
                as ViewItemEvent;
        expect(captured.item.itemId, 'dish_shawarma');
        expect(captured.item.toEventItem().itemId, 'dish_shawarma');
        expect(captured.item.toEventItem().itemName, 'Chicken Shawarma');
        // integer cents -> GA4 units, straight from the MODEL price (L2)
        expect(captured.item.toEventItem().price, 18.5);
        expect(captured.item.toEventItem().quantity, 2);
        expect(captured.currency, _kCurrency);
        // funnel parity: the internal event keeps firing with the same key
        expect(_capturedPipelineEvent(callable)['event'], 'view_item');
      });

      test(
        'add_to_cart carries items[] and the internal funnel event',
        () async {
          await sut.addToCartItem(_addToCartEvent());

          final captured =
              verify(() => analytics.logAddToCart(captureAny())).captured.single
                  as AddToCartEvent;
          expect(captured.currency, _kCurrency);
          expect(captured.item.toEventItem().quantity, 2);
          final payload = _capturedPipelineEvent(callable);
          expect(payload['event'], 'add_to_cart');
          final props = Map<String, dynamic>.from(payload['properties'] as Map);
          expect(props['item_id'], 'dish_shawarma');
          expect(props['quantity'], 2);
        },
      );

      test(
        'begin_checkout carries EVERY cart line (items[] is complete)',
        () async {
          await sut.beginCheckoutItems(_beginCheckoutEvent());

          final captured =
              verify(
                    () => analytics.logBeginCheckout(captureAny()),
                  ).captured.single
                  as BeginCheckoutEvent;
          expect(captured.items.map((i) => i.itemId).toList(), [
            'dish_shawarma',
            'dish_ayran',
          ]);
          expect(captured.valueCents, 4050);
          expect(captured.currency, _kCurrency);
          final props = Map<String, dynamic>.from(
            _capturedPipelineEvent(callable)['properties'] as Map,
          );
          expect(props['cart_total_cents'], 4050);
        },
      );

      test('add_payment_info fires at the payment step', () async {
        await sut.addPaymentInfo(_paymentInfoEvent());

        final captured =
            verify(
                  () => analytics.logAddPaymentInfo(captureAny()),
                ).captured.single
                as AddPaymentInfoEvent;
        expect(captured.valueCents, 4050);
        expect(captured.paymentType, 'card');
        expect(captured.items, hasLength(2));
      });

      test(
        'purchase params snapshot: transaction_id + items[] + tax/shipping',
        () async {
          await sut.purchase(_purchaseEvent());

          final captured =
              verify(() => analytics.logPurchase(captureAny())).captured.single
                  as PurchaseEvent;
          expect(captured.transactionId, 'ORD-2026-0001');
          expect(captured.currency, _kCurrency);
          expect(captured.valueCents, 4050);
          expect(captured.taxCents, 405);
          expect(captured.shippingCents, 500);
          final items = captured.items.map((i) => i.toEventItem()).toList();
          expect(items, hasLength(2));
          expect(items[0].itemId, 'dish_shawarma');
          expect(items[0].itemName, 'Chicken Shawarma');
          expect(items[0].price, 18.5);
          expect(items[0].quantity, 2);
          expect(items[1].itemId, 'dish_ayran');
          expect(items[1].price, 3.5);
          expect(items[1].quantity, 1);
        },
      );
    },
  );

  group('T-1 L3 — GA4 limits pinned on the taxonomy table', () {
    test('the shipped taxonomy validates clean', () {
      expect(EcommerceTaxonomy.violations(), isEmpty);
    });

    test('the five ecommerce events use the canonical GA4 names', () {
      expect(
        EcommerceTaxonomy.events.map((e) => e.name).toList(),
        containsAll(<String>[
          'view_item',
          'add_to_cart',
          'begin_checkout',
          'add_payment_info',
          'purchase',
        ]),
      );
    });

    test(
      'every event name is lowercase_snake and every param name <= 40 chars',
      () {
        final snake = RegExp(r'^[a-z][a-z0-9_]*$');
        for (final event in EcommerceTaxonomy.events) {
          expect(
            snake.hasMatch(event.name),
            isTrue,
            reason: 'event name must be lowercase_snake: ${event.name}',
          );
          expect(
            event.params.length,
            lessThanOrEqualTo(EcommerceTaxonomy.maxParamsPerEvent),
            reason: 'GA4 allows <= 25 params per event: ${event.name}',
          );
          for (final param in event.params) {
            expect(
              param.length,
              lessThanOrEqualTo(EcommerceTaxonomy.maxParamNameLength),
              reason: 'GA4 param names are <= 40 chars: $param',
            );
            expect(snake.hasMatch(param), isTrue, reason: 'param: $param');
          }
        }
      },
    );

    test('violationsOf() catches a bad table (negative control)', () {
      const bad = EcommerceEventSpec(
        name: 'View_Item',
        params: [
          'item_id',
          'a_param_name_deliberately_longer_than_forty_chars',
        ],
      );
      final issues = EcommerceTaxonomy.violationsOf(const [
        bad,
        EcommerceEventSpec(name: 'ok_event', params: ['item_id']),
      ]);
      expect(issues, hasLength(2));
      expect(issues.join(' '), contains('View_Item'));
      expect(issues.join(' '), contains('40'));
    });
  });

  group('T-1 — fire-and-forget safety (residual 28.5)', () {
    test('a null SDK instance is a silent no-op for every new event', () async {
      SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
      final sut = TelemetryService.forTest(analytics: AnalyticsService(null));

      await sut.viewItem(_viewItemEvent());
      await sut.addToCartItem(_addToCartEvent());
      await sut.beginCheckoutItems(_beginCheckoutEvent());
      await sut.addPaymentInfo(_paymentInfoEvent());
      await sut.purchase(_purchaseEvent());
    });
  });
}

ViewItemEvent _viewItemEvent() =>
    const ViewItemEvent(item: _shawarma, currency: _kCurrency);

AddToCartEvent _addToCartEvent() =>
    const AddToCartEvent(item: _shawarma, currency: _kCurrency);

BeginCheckoutEvent _beginCheckoutEvent() => const BeginCheckoutEvent(
  items: [_shawarma, _ayran],
  currency: _kCurrency,
  valueCents: 4050,
);

AddPaymentInfoEvent _paymentInfoEvent() => const AddPaymentInfoEvent(
  items: [_shawarma, _ayran],
  currency: _kCurrency,
  valueCents: 4050,
  paymentType: 'card',
);

PurchaseEvent _purchaseEvent() => const PurchaseEvent(
  transactionId: 'ORD-2026-0001',
  items: [_shawarma, _ayran],
  currency: _kCurrency,
  valueCents: 4050,
  taxCents: 405,
  shippingCents: 500,
);

/// Reads the LAST captured `logFunnelEvent` payload.
Map<String, dynamic> _capturedPipelineEvent(_MockHttpsCallable callable) {
  final args = verify(() => callable.call(captureAny())).captured;
  return Map<String, dynamic>.from(args.last as Map);
}
