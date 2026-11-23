import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/feature_flags_service.dart';

// Spec: FeatureFlagsService contract:
// - Default flags: smartReorder, loyaltyPoints, tourMode, waitlist, deliveryTracking, promoCode = all true
//   (D-2 / F3-05: `referrals` was removed from the default set by UI-13 p21 —
//   it is asserted ABSENT below, in both the service defaults and the bundled
//   template config.)
// - Firestore doc can override any flag to false
// - Unknown flags return false (fail-closed)
// - Null/bool values handled gracefully
// - An ORPHAN key the parser does not know (e.g. `referrals` still shipped by
//   `apps/halal_boyz/assets/client_config.json:43`, a p25 handoff row this
//   wave may not edit) is tolerated: parsed, never thrown on, never allowed to
//   disturb the flags that are in the default set.
// Tests assert against hard-coded spec values — no mirroring.

void main() {
  group('FeatureFlagsService — Spec Contract', () {
    test('All 6 default flags are true per spec (D-2: referrals removed)', () {
      // Spec: every flag in _defaultFlags must be true when Firestore returns empty doc
      final svc = FeatureFlagsService({});
      expect(svc.isEnabled('smartReorder'), equals(true));
      expect(svc.isEnabled('loyaltyPoints'), equals(true));
      expect(svc.isEnabled('tourMode'), equals(true));
      expect(svc.isEnabled('waitlist'), equals(true));
      expect(svc.isEnabled('deliveryTracking'), equals(true));
      expect(svc.isEnabled('promoCode'), equals(true));
      // D-2 (F3-05): the removed flag is ABSENT from the default set, so it
      // resolves fail-closed instead of silently staying on.
      expect(svc.flags.containsKey('referrals'), equals(false));
      expect(svc.isEnabled('referrals'), equals(false));
    });

    test('Firestore override sets loyaltyPoints to false per spec', () {
      // Spec: Firestore doc {'loyaltyPoints': false} overrides default
      final svc = FeatureFlagsService({'loyaltyPoints': false});
      expect(svc.isEnabled('loyaltyPoints'), equals(false));
    });

    test('Unknown flag returns false per spec (fail-closed)', () {
      // Spec: any flag not in _defaultFlags returns false
      final svc = FeatureFlagsService({});
      expect(svc.isEnabled('nonExistentFlag'), equals(false));
      expect(svc.isEnabled('unknownFeature'), equals(false));
      expect(svc.isEnabled(''), equals(false));
    });

    test('Override does not affect other flags', () {
      // Spec: setting one flag to false must not change defaults for others
      final svc = FeatureFlagsService({'loyaltyPoints': false});
      expect(svc.isEnabled('smartReorder'), equals(true));
      expect(svc.isEnabled('deliveryTracking'), equals(true));
      expect(svc.isEnabled('promoCode'), equals(true));
    });

    test('Null value in Firestore doc falls back to default', () {
      // Spec: null value for a known flag falls back to default (true)
      final svc = FeatureFlagsService({'loyaltyPoints': null});
      expect(svc.isEnabled('loyaltyPoints'), equals(true));
    });

    test('Multiple overrides apply independently', () {
      // Spec: multiple flags can be overridden in same doc
      final svc = FeatureFlagsService({
        'loyaltyPoints': false,
        'deliveryTracking': false,
        'promoCode': false,
      });
      expect(svc.isEnabled('loyaltyPoints'), equals(false));
      expect(svc.isEnabled('deliveryTracking'), equals(false));
      expect(svc.isEnabled('promoCode'), equals(false));
      expect(svc.isEnabled('smartReorder'), equals(true)); // untouched
    });
  });

  group('D-2 — bundled template config + orphan tolerance (F3-05)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      AppConfig.resetForTest();
    });

    test('the bundled template no longer ships the referrals flag', () async {
      final raw = File('assets/client_config.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final flags =
          ((json['features'] as Map<String, dynamic>)['flags']
              as Map<String, dynamic>);
      expect(
        flags.keys,
        isNot(contains('referrals')),
        reason: 'D-2 removes the orphan from the template (F3-05)',
      );
      expect(flags.keys, contains('promoCode'));
      expect(flags.values.every((v) => v is bool), isTrue);
    });

    test(
      'the config parser tolerates a stale orphan key (apps/halal_boyz row)',
      () async {
        // The shape an already-installed build still carries: `referrals` was
        // an orphan flag key (apps/** is FORBIDDEN here — never edited). The
        // fixture must satisfy the W6.5 required schema first, or the load
        // fails for a missing `tenantId` (P0-6) and this test measures the
        // wrong failure — which is exactly what it did until C-4.
        const orphan = '''
{
  "_meta": {"schemaVersion": "1.0.0"},
  "tenantId": "halal_boyz",
  "app": {"name": "Client App", "bundleId": "com.client.app"},
  "currency": {"code": "USD", "symbol": ""},
  "environment": {"firebaseAndroidApiKey": "AIzaSyA-real-key", "firebaseIosApiKey": "AIzaSyA-real-key"},
  "firebase": {"projectId": "client-project"},
  "theme": {"injection": "local-config-file", "colors": {"primary": "0xFF2E7D32"}},
  "navigation": {"entryPoint": "/splash"},
  "features": {
    "source": "settings/featureFlags",
    "flags": {
      "smartReorder": true,
      "referrals": true,
      "promoCode": true
    },
    "unknownFlagDefault": false
  },
  "screens": []
}
''';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
              if (message == null) return null;
              final key = utf8.decode(message.buffer.asUint8List());
              if (key != 'assets/client_config.json') return null;
              return ByteData.view(
                Uint8List.fromList(utf8.encode(orphan)).buffer,
              );
            });
        AppConfig.resetForTest();
        await AppConfig.loadConfig();

        expect(AppConfig.loadFailed, isFalse);
        expect(AppConfig.featureEnabled('smartReorder'), isTrue);
        expect(AppConfig.featureEnabled('promoCode'), isTrue);
        // The orphan is tolerated (parsed as a plain bool), never a crash.
        expect(AppConfig.featureEnabled('referrals'), isTrue);
        // Unknown flags still fail closed to the configured default.
        expect(AppConfig.featureEnabled('flagThatDoesNotExist'), isFalse);
      },
    );
  });
}
