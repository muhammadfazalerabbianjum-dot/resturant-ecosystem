import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    // Reset SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('TelemetryService - GDPR consent gate (PERF-3 T-1: behavioral)', () {
    late _MockFirebaseFunctions functions;
    late _MockHttpsCallable callable;

    setUp(() {
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(
        () => functions.httpsCallable('logFunnelEvent'),
      ).thenReturn(callable);
      when(
        () => callable.call(any()),
      ).thenAnswer((_) async => _MockHttpsCallableResult());
    });

    test(
      'events are DROPPED when consent is declined: no pipeline call',
      () async {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: false,
        });
        final service = TelemetryService.forTest(functions: functions);

        await service.log('test_event', properties: {'key': 'value'});

        // Declined consent must short-circuit BEFORE the pipeline.
        verifyNever(() => callable.call(any()));
      },
    );

    test(
      'events are DROPPED when consent was never asked (absent key)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = TelemetryService.forTest(functions: functions);

        await service.log('test_event');

        // Undecided consent must block analytics (opt-in only).
        verifyNever(() => callable.call(any()));
      },
    );

    test(
      'log NEVER throws — even when the pipeline rejects (fire-and-forget)',
      () async {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: true,
        });
        when(() => callable.call(any())).thenThrow(Exception('pipeline down'));
        final service = TelemetryService.forTest(functions: functions);

        await service.log(''); // empty event name
        await service.log('test_event', properties: {});

        // The consent gate passed; the documented swallow path ran twice.
        verify(() => callable.call(any())).called(2);
      },
    );

    test(
      'demo mode with consent writes directly to Firestore, bypassing the pipeline',
      () async {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: true,
        });
        final fakeDb = FakeFirebaseFirestore();
        CoreConfigHolder.set(const _DemoModeCoreConfig());
        addTearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));
        final service = TelemetryService.forTest(
          functions: functions,
          firestore: fakeDb,
        );

        await service.log('demo_event', properties: {'k': 'v'});

        final docs = await fakeDb.collection('analyticsEvents').get();
        expect(docs.docs, hasLength(1));
        expect(docs.docs.single.data()['event'], 'demo_event');
        // Demo mode must never touch the Cloud Functions pipeline.
        verifyNever(() => functions.httpsCallable(any()));
      },
    );
  });

  group(
    'TelemetryService - predefined event payload contracts (PERF-3 T-1)',
    () {
      // ignore: unused_local_variable
      late _MockAnalyticsService analytics;
      late _MockFirebaseFunctions functions;
      late _MockHttpsCallable callable;
      late List<Map<String, dynamic>> payloads;

      setUp(() {
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: true,
        });
        functions = _MockFirebaseFunctions();
        callable = _MockHttpsCallable();
        analytics = _MockAnalyticsService();
        payloads = [];
        when(
          () => functions.httpsCallable('logFunnelEvent'),
        ).thenReturn(callable);
        when(() => callable.call(any())).thenAnswer((invocation) async {
          payloads.add(
            Map<String, dynamic>.from(
              invocation.positionalArguments.single as Map,
            ),
          );
          return _MockHttpsCallableResult();
        });
        when(
          () => analytics.logOrderPlaced(any(), any()),
        ).thenAnswer((_) async {});
      });

      Map<String, dynamic> props(Map<String, dynamic> payload) =>
          Map<String, dynamic>.from(payload['properties'] as Map);

      test('viewMenuItem → view_menu_item with item_id', () async {
        await TelemetryService.forTest(
          functions: functions,
        ).viewMenuItem('item_123');
        expect(payloads.single['event'], 'view_menu_item');
        expect(props(payloads.single)['item_id'], 'item_123');
      });

      test(
        'addToCart → add_to_cart with item_id, quantity, price_cents',
        () async {
          await TelemetryService.forTest(
            functions: functions,
          ).addToCart('item_123', 999);
          expect(payloads.single['event'], 'add_to_cart');
          final p = props(payloads.single);
          expect(p['item_id'], 'item_123');
          expect(p['quantity'], 1);
          expect(p['price_cents'], 999);
        },
      );

      test('beginCheckout → begin_checkout with cart_total_cents', () async {
        await TelemetryService.forTest(
          functions: functions,
        ).beginCheckout(2500);
        expect(payloads.single['event'], 'begin_checkout');
        expect(props(payloads.single)['cart_total_cents'], 2500);
      });

      test(
        'checkoutAbandoned → checkout_abandon with cart_total_cents',
        () async {
          await TelemetryService.forTest(
            functions: functions,
          ).checkoutAbandoned(2500);
          expect(payloads.single['event'], 'checkout_abandon');
          expect(props(payloads.single)['cart_total_cents'], 2500);
        },
      );

      test(
        'orderCompleted → order_completed AND delegates to AnalyticsService',
        () async {
          await TelemetryService.forTest(
            functions: functions,
            analytics: analytics,
          ).orderCompleted('ord_1', 2500);
          expect(payloads.single['event'], 'order_completed');
          final p = props(payloads.single);
          expect(p['order_id'], 'ord_1');
          expect(p['total_cents'], 2500);
          verify(() => analytics.logOrderPlaced('ord_1', 2500)).called(1);
        },
      );

      test(
        'promoApplied → promo_applied with code and discount_cents',
        () async {
          await TelemetryService.forTest(
            functions: functions,
          ).promoApplied('SAVE20', 200);
          expect(payloads.single['event'], 'promo_applied');
          final p = props(payloads.single);
          expect(p['code'], 'SAVE20');
          expect(p['discount_cents'], 200);
        },
      );

      test('full funnel fires the exact event sequence in order', () async {
        final service = TelemetryService.forTest(
          functions: functions,
          analytics: analytics,
        );
        await service.viewMenuItem('item_1');
        await service.addToCart('item_1', 999);
        await service.beginCheckout(999);
        await service.orderCompleted('ord_1', 999);
        expect(payloads.map((p) => p['event']), [
          'view_menu_item',
          'add_to_cart',
          'begin_checkout',
          'order_completed',
        ]);
      });
    },
  );

  group('TelemetryService — facade delegation (UX-4 T-4, spec 28.2 #4)', () {
    late _MockAnalyticsService analytics;
    late _MockFirebaseFunctions functions;
    late _MockHttpsCallable callable;

    setUp(() {
      // Consent GRANTED so events pass the gate and reach both delegates.
      SharedPreferences.setMockInitialValues({'gdpr_analytics_consent': true});
      analytics = _MockAnalyticsService();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(
        () => functions.httpsCallable('logFunnelEvent'),
      ).thenReturn(callable);
      when(
        () => callable.call(any()),
      ).thenAnswer((_) async => _MockHttpsCallableResult());
      when(
        () => analytics.logOrderPlaced(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => analytics.logOrderCancelled(any(), any()),
      ).thenAnswer((_) async {});
    });

    test('orderCompleted reaches BOTH stacks (T-4)', () async {
      final service = TelemetryService.forTest(
        analytics: analytics,
        functions: functions,
      );
      await service.orderCompleted('ORD-9', 1234);

      // First-party stack (AnalyticsService facade delegate):
      verify(() => analytics.logOrderPlaced('ORD-9', 1234)).called(1);
      // Telemetry stack (logFunnelEvent Cloud Function pipeline):
      final capturedArgs = verify(() => callable.call(captureAny())).captured;
      final payload = Map<String, dynamic>.from(capturedArgs.single as Map);
      expect(payload['event'], 'order_completed');
      final properties = Map<String, dynamic>.from(
        payload['properties'] as Map,
      );
      expect(properties['order_id'], 'ORD-9');
      expect(properties['total_cents'], 1234);
    });

    test('orderCancelled reaches BOTH stacks (T-4)', () async {
      final service = TelemetryService.forTest(
        analytics: analytics,
        functions: functions,
      );
      await service.orderCancelled('ORD-8', 'user_requested');

      verify(
        () => analytics.logOrderCancelled('ORD-8', 'user_requested'),
      ).called(1);
      final capturedArgs = verify(() => callable.call(captureAny())).captured;
      final payload = Map<String, dynamic>.from(capturedArgs.single as Map);
      expect(payload['event'], 'order_cancelled');
      final properties = Map<String, dynamic>.from(
        payload['properties'] as Map,
      );
      expect(properties['order_id'], 'ORD-8');
      expect(properties['reason'], 'user_requested');
    });
  });

  group('AnalyticsService.routeObservers — T-3 positive path', () {
    test('returns ONE observer when Firebase IS initialized', () {
      // setUpAll above initialized Firebase (core mocks) and
      // flutter_test_config.dart installed the recording platform fake, so
      // FirebaseAnalytics.instance resolves WITHOUT touching plugin channels.
      // This is the behavioral half of T-3 (the code-read half is the
      // observers: AnalyticsService.routeObservers() wiring in app_router).
      final observers = AnalyticsService.routeObservers();
      expect(observers, hasLength(1));
      expect(observers.first, isA<FirebaseAnalyticsObserver>());
    });
  });
}

/// Minimal demo-mode [CoreConfig] for the demo-path test (isDemoMode = true).
class _DemoModeCoreConfig implements CoreConfig {
  const _DemoModeCoreConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'test-client';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const [];

  @override
  String get kitchenLanEndpoint => '';
}
