import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';

/// PERF-1 (T-6) — TelemetryService: the ONE canonical GDPR analytics-consent
/// gate (W9.8), the demo-mode direct Firestore write, the full predefined
/// event surface, and the never-throw fire-and-forget guarantee.

class _TestCoreConfig implements CoreConfig {
  const _TestCoreConfig({this.isDemoMode = false});

  @override
  final bool isDemoMode;

  @override
  String get clientId => 'perf1-test';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const [];

  @override
  String get kitchenLanEndpoint => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // A STABLE system-temp path: the logger fallback may write after the
    // test ends (dropped futures) — never delete it per-test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  tearDown(() {
    // Restore the safe production-like default for any later reader.
    CoreConfigHolder.set(const DefaultCoreConfig());
  });

  test('the singleton factory returns the same instance', () {
    expect(identical(TelemetryService(), TelemetryService()), isTrue);
  });

  test('W9.8 consent gate: never-asked (absent) AND declined (false) '
      'both block the event', () async {
    final db = FakeFirebaseFirestore();
    final svc = TelemetryService.forTest(firestore: db);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await svc.cartViewed();
    expect((await db.collection('analyticsEvents').get()).docs, isEmpty);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: false,
    });
    await svc.cartViewed();
    expect((await db.collection('analyticsEvents').get()).docs, isEmpty);
  });

  test('consented + demo mode writes the event with its properties', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: true,
    });
    CoreConfigHolder.set(const _TestCoreConfig(isDemoMode: true));

    final db = FakeFirebaseFirestore();
    final svc = TelemetryService.forTest(firestore: db);

    await svc.addToCart('item-9', 1999, quantity: 2);

    final docs = (await db.collection('analyticsEvents').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['event'], 'add_to_cart');
    expect(docs.single.data()['properties'], <String, dynamic>{
      'item_id': 'item-9',
      'quantity': 2,
      'price_cents': 1999,
    });
  });

  test('every predefined event funnels through the consent gate '
      '(all blocked while consent is absent)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CoreConfigHolder.set(const _TestCoreConfig(isDemoMode: true));
    final db = FakeFirebaseFirestore();
    final svc = TelemetryService.forTest(firestore: db);

    await svc.cartViewed();
    await svc.viewMenuItem('m1');
    await svc.addToCart('m1', 100);
    await svc.beginCheckout(100);
    await svc.checkoutAbandoned(100);
    await svc.orderCompleted('o1', 100);
    await svc.orderCancelled('o1', 'user-request');
    await svc.promoApplied('PERF1', 10);
    await svc.orderFailed('o1', reason: 'server-reject');
    await svc.paymentDeclined(reason: 'insufficient-funds');
    await svc.offlineQueueDepth(3);

    expect(
      (await db.collection('analyticsEvents').get()).docs,
      isEmpty,
      reason: 'no consent → no telemetry, for EVERY event on the surface',
    );
  });

  test('a production-mode backend failure never escapes '
      '(the fire-and-forget contract)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: true,
    });
    // Default config: isDemoMode false → the Cloud Functions path — the
    // functions runtime is absent in tests; the service must swallow that.
    CoreConfigHolder.set(const DefaultCoreConfig());

    final db = FakeFirebaseFirestore();
    final svc = TelemetryService.forTest(firestore: db);

    await svc.cartViewed();

    expect(
      (await db.collection('analyticsEvents').get()).docs,
      isEmpty,
      reason:
          'the failed production attempt must not fall back to a '
          'direct write',
    );
  });
}
