// TDD Master Suite — Analytics Event Tests
// Category: Analytics
// Invariant: every KEPT AnalyticsService event fires with correct parameters,
// the facade is fire-and-forget-safe, and the observer guard never throws.
//
// UX-4 (spec 28.2 contract #3, decision recorded): of the original 16 typed
// methods, the 13 with ZERO production call sites were DELETED. T-2
// ("deleted methods absent") is enforced at COMPILE time — any reference to a
// deleted method is a flutter analyze error — and by reverse-grep (see
// FIX_VERIFICATION_cline-task-5.md, UX-4 section). The funnel surface now
// lives on TelemetryService; its delegation to this facade is proven in
// telemetry_service_test.dart (T-4).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:core/core.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late AnalyticsService sut;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    sut = AnalyticsService(mockAnalytics);

    when(
      () => mockAnalytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
  });

  group('AnalyticsService — kept facade events (spec 28.2 #3)', () {
    test(
      'logOrderPlaced fires order_placed with order_id and total_cents',
      () async {
        await sut.logOrderPlaced('ORD-001', 4800);
        verify(
          () => mockAnalytics.logEvent(
            name: 'order_placed',
            parameters: {'order_id': 'ORD-001', 'total_cents': 4800},
          ),
        ).called(1);
      },
    );

    test('logOrderCancelled fires with order_id and reason', () async {
      await sut.logOrderCancelled('ORD-002', 'user_cancelled');
      verify(
        () => mockAnalytics.logEvent(
          name: 'order_cancelled',
          parameters: {'order_id': 'ORD-002', 'reason': 'user_cancelled'},
        ),
      ).called(1);
    });

    test('logAdminAction fires with action and target_id', () async {
      await sut.logAdminAction('add_admin', 'admin@test.com');
      verify(
        () => mockAnalytics.logEvent(
          name: 'admin_action',
          parameters: {'action': 'add_admin', 'target_id': 'admin@test.com'},
        ),
      ).called(1);
    });
  });

  group('AnalyticsService — fire-and-forget safety (residual 28.5)', () {
    test('null analytics instance is a silent no-op', () async {
      // No Firebase instance available (demo/offline/test): every facade
      // method must complete without throwing (analytics must never break
      // the ordering path).
      final sut = AnalyticsService(null);
      await sut.logOrderPlaced('ORD-003', 100);
      await sut.logOrderCancelled('ORD-003', 'demo');
      await sut.logAdminAction('noop', 'n/a');
    });
  });

  group('AnalyticsService.routeObservers — T-3 guard path', () {
    test('returns EMPTY when Firebase is NOT initialized', () {
      // This file never initializes Firebase (no setupFirebaseCoreMocks), so
      // Firebase.apps is empty: the router must receive no observers instead
      // of crashing on FirebaseAnalytics.instance (which throws pre-init).
      expect(AnalyticsService.routeObservers(), isEmpty);
    });
  });
}
