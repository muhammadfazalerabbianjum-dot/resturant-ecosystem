import 'package:flutter_test/flutter_test.dart';
import 'package:halal_boyz/app/core_config_adapter.dart';
import 'package:halal_boyz/app/demo_config.dart';

/// PERF-1 (T-6) — unit coverage for the generated per-app config adapter.
/// The adapter is the shell's ONLY bridge between client_config.json and the
/// core config interface, so every getter's fallback chain is pinned here:
/// present → non-empty string wins; missing / wrong-type / empty falls back.
/// The fail-fast `clientId` contract (never silently inherit another app's
/// identity) is asserted for BOTH the debug-assert and the release guard.

void main() {
  group('ClientCoreConfig — currency (OFFLINE_FALLBACK money display)', () {
    test('a present currency.code wins', () {
      const config = ClientCoreConfig({
        'currency': {'code': 'AED'},
      });
      expect(config.currencyCode, 'AED');
    });

    test('missing / empty / wrong-type currency.code falls back to USD', () {
      expect(
        const ClientCoreConfig({}).currencyCode,
        'USD',
        reason: 'no currency block at all',
      );
      expect(
        const ClientCoreConfig({
          'currency': {'code': ''},
        }).currencyCode,
        'USD',
        reason: 'an empty code is not a code',
      );
      expect(
        const ClientCoreConfig({
          'currency': {'code': 42},
        }).currencyCode,
        'USD',
        reason: 'a non-string value must not crash the shell',
      );
      expect(
        const ClientCoreConfig({'currency': 'not-a-map'}).currencyCode,
        'USD',
        reason: 'a malformed block falls back too',
      );
    });
  });

  group('ClientCoreConfig — identity fail-fast (B7-2)', () {
    test('a present app.bundleId is returned verbatim', () {
      const config = ClientCoreConfig({
        'app': {'bundleId': 'com.carnama.halalboyz'},
      });
      expect(config.clientId, 'com.carnama.halalboyz');
    });

    test(
      'a MISSING app.bundleId fails fast (never inherits another identity)',
      () {
        const config = ClientCoreConfig({});
        // Debug builds (tests included) hit the assert; release hits the
        // StateError guard. Both are hard failures — never a silent default.
        expect(() => config.clientId, throwsA(isA<Error>()));
      },
    );

    test('an EMPTY app.bundleId fails fast too', () {
      const config = ClientCoreConfig({
        'app': {'bundleId': ''},
      });
      expect(() => config.clientId, throwsA(isA<Error>()));
    });
  });

  group(
    'ClientCoreConfig — environment-block getters (injected credentials)',
    () {
      test('present non-empty environment values win', () {
        const config = ClientCoreConfig({
          'environment': {
            'cloudinaryUploadPreset': 'client_preset',
            'cloudinaryCloudName': 'client_cloud',
            'kitchenLanEndpoint': 'http://192.168.1.50:8080',
          },
        });
        expect(config.cloudinaryUploadPreset, 'client_preset');
        expect(config.cloudinaryCloudName, 'client_cloud');
        expect(config.kitchenLanEndpoint, 'http://192.168.1.50:8080');
      });

      test('missing / empty environment values default to EMPTY (fail-closed — '
          'no silent upload into the reference app account)', () {
        const empty = ClientCoreConfig({});
        expect(empty.cloudinaryUploadPreset, '');
        expect(empty.cloudinaryCloudName, '');
        expect(empty.kitchenLanEndpoint, '');

        const malformed = ClientCoreConfig({
          'environment': {
            'cloudinaryUploadPreset': '',
            'cloudinaryCloudName': 7,
            'kitchenLanEndpoint': null,
          },
        });
        expect(malformed.cloudinaryUploadPreset, '');
        expect(malformed.cloudinaryCloudName, '');
        expect(malformed.kitchenLanEndpoint, '');
      });
    },
  );

  group('ClientCoreConfig — demo mirror + owner emails', () {
    test(
      'isDemoMode mirrors the build-time kDemoMode constant (OPS-CONFIG-1)',
      () {
        const config = ClientCoreConfig({});
        expect(config.isDemoMode, kDemoMode);
      },
    );

    test('ownerEmails stays the config-free const []', () {
      const config = ClientCoreConfig({});
      expect(config.ownerEmails, isEmpty);
    });
  });
}
