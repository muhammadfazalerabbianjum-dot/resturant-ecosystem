import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mock_firebase.dart';

class _DemoCoreConfig implements CoreConfig {
  const _DemoCoreConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'carnama-test';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const <String>[];

  @override
  String get kitchenLanEndpoint => '';
}

/// CORE-COV Tier-1 ANALYTICS suite: the W9.8 GDPR consent gate (the ONE
/// canonical key — declined and never-asked both block every sink), the
/// demo/production sink split, the dual-stack order events, and the
/// [AnalyticsService] typed facade + fire-and-forget containment.
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  tearDown(() {
    CoreConfigHolder.set(const DefaultCoreConfig());
  });

  group('TelemetryService — GDPR consent gate (W9.8)', () {
    late FakeFirebaseFirestore db;

    setUp(() {
      db = FakeFirebaseFirestore();
    });

    TelemetryService demoService() {
      CoreConfigHolder.set(const _DemoCoreConfig());
      return TelemetryService.forTest(firestore: db);
    }

    test('never-asked consent blocks every sink', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await TelemetryService.forTest(
        firestore: db,
      ).log('cart_viewed', properties: <String, Object>{'item': 'x'});

      expect((await db.collection('analyticsEvents').get()).docs, isEmpty);
    });

    test(
      'declined consent (false) blocks every sink — durable opt-out',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: false,
        });
        await demoService().log('cart_viewed');

        expect((await db.collection('analyticsEvents').get()).docs, isEmpty);
      },
    );

    test(
      'accepted consent + demo mode writes the analyticsEvents doc',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });
        await demoService().log(
          'cart_viewed',
          properties: <String, Object>{'item': 'x'},
        );

        final docs = await db.collection('analyticsEvents').get();
        expect(docs.docs, hasLength(1));
        expect(docs.docs.first.data()['event'], 'cart_viewed');
        expect((docs.docs.first.data()['properties'] as Map)['item'], 'x');
      },
    );
    test(
      'accepted consent + production mode calls the aggregation pipeline',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });
        CoreConfigHolder.set(const DefaultCoreConfig());
        final functions = MockFirebaseFunctions();
        final callable = MockHttpsCallable();
        final result = MockCallableResult();
        when(() => result.data).thenReturn(<String, dynamic>{});
        when(
          () => functions.httpsCallable('logFunnelEvent'),
        ).thenReturn(callable);
        when(
          () => callable.call(captureAny<dynamic>()),
        ).thenAnswer((_) async => result);

        await TelemetryService.forTest(
          functions: functions,
          firestore: db,
        ).log('add_to_cart', properties: <String, Object>{'item_id': 'd1'});

        final captured =
            verify(() => callable.call(captureAny<dynamic>())).captured.single
                as Map<dynamic, dynamic>;
        expect(captured['event'], 'add_to_cart');
        expect((captured['properties'] as Map)['item_id'], 'd1');
        expect((await db.collection('analyticsEvents').get()).docs, isEmpty);
      },
    );

    test(
      'a failing sink never escapes to the fire-and-forget callers',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });
        CoreConfigHolder.set(const DefaultCoreConfig());
        final functions = MockFirebaseFunctions();
        final callable = MockHttpsCallable();
        when(
          () => functions.httpsCallable('logFunnelEvent'),
        ).thenReturn(callable);
        when(() => callable.call(any<dynamic>())).thenThrow(StateError('down'));

        await TelemetryService.forTest(
          functions: functions,
          firestore: db,
        ).log('order_failed');

        // Reached here without throwing — the containment held.
      },
    );
  });

  group('TelemetryService — dual-stack order events (P3-4)', () {
    test(
      'orderCompleted reaches BOTH the funnel and Firebase Analytics',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });
        CoreConfigHolder.set(const _DemoCoreConfig());
        final db = FakeFirebaseFirestore();
        final analytics = MockFirebaseAnalytics();
        when(
          () => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ),
        ).thenAnswer((_) async {});

        await TelemetryService.forTest(
          firestore: db,
          analytics: AnalyticsService(analytics),
        ).orderCompleted('o1', 2500);

        final docs = await db.collection('analyticsEvents').get();
        expect(docs.docs.single.data()['event'], 'order_completed');
        expect(
          (docs.docs.single.data()['properties'] as Map)['total_cents'],
          2500,
        );
        verify(
          () => analytics.logEvent(
            name: 'order_placed',
            parameters: <String, Object>{'order_id': 'o1', 'total_cents': 2500},
          ),
        ).called(1);
      },
    );

    test('orderCancelled reaches BOTH stacks with the reason', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kGdprAnalyticsConsentKey: true,
      });
      CoreConfigHolder.set(const _DemoCoreConfig());
      final db = FakeFirebaseFirestore();
      final analytics = MockFirebaseAnalytics();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});

      await TelemetryService.forTest(
        firestore: db,
        analytics: AnalyticsService(analytics),
      ).orderCancelled('o2', 'user_back');

      final docs = await db.collection('analyticsEvents').get();
      expect(docs.docs.single.data()['event'], 'order_cancelled');
      verify(
        () => analytics.logEvent(
          name: 'order_cancelled',
          parameters: <String, Object>{'order_id': 'o2', 'reason': 'user_back'},
        ),
      ).called(1);
    });
  });
  group('AnalyticsService — typed facade', () {
    test(
      'a null Firebase instance is a safe no-op (analytics never crashes)',
      () async {
        await AnalyticsService(null).logOrderPlaced('o1', 500);
        await AnalyticsService(null).logOrderCancelled('o1', 'r');
        await AnalyticsService(null).logAdminAction('refund', 'o1');
      },
    );

    test(
      'logOrderPlaced forwards the typed event to Firebase Analytics',
      () async {
        final analytics = MockFirebaseAnalytics();
        when(
          () => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ),
        ).thenAnswer((_) async {});

        await AnalyticsService(analytics).logOrderPlaced('o9', 1999);

        verify(
          () => analytics.logEvent(
            name: 'order_placed',
            parameters: <String, Object>{'order_id': 'o9', 'total_cents': 1999},
          ),
        ).called(1);
      },
    );

    test('logAdminAction carries the action + target id', () async {
      final analytics = MockFirebaseAnalytics();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});

      await AnalyticsService(analytics).logAdminAction('menu_delete', 'd1');

      verify(
        () => analytics.logEvent(
          name: 'admin_action',
          parameters: <String, Object>{
            'action': 'menu_delete',
            'target_id': 'd1',
          },
        ),
      ).called(1);
    });

    test(
      'routeObservers returns an EMPTY list when Firebase is not initialized '
      '(router construction must never crash for analytics)',
      () {
        expect(AnalyticsService.routeObservers(), isEmpty);
      },
    );
  });
}
