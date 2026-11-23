import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/client_config.dart';

/// COV-1 — SPLASH config-load contract.
///
/// The splash init funnel starts with `AppConfig.loadConfig()`
/// (splash_screen.dart splashInitProvider step 1). This suite pins its
/// three-way contract against the REAL production seam — the asset is served
/// through the same `flutter/assets` platform channel `rootBundle.loadString`
/// reads, so no platform channel is touched and the loader's try/catch,
/// layering, and fail-closed schema gate are exercised for real:
///   1. valid config        -> layers resolve, no error, no gate;
///   2. malformed / missing -> graceful defaults + `loadError` (NO crash);
///   3. REQUIRED-field      -> typed `ConfigException` in `schemaError`
///      (the fail-closed gate the boot must honor on
///      ConfigValidationErrorScreen — W6.5).

/// Serves canned asset bytes on the `flutter/assets` channel. The requested
/// keys are recorded so tests can assert the loader asked for the real path.
class _AssetServer {
  _AssetServer(this.assetsByPath);

  final Map<String, String> assetsByPath;
  final List<String> requestedPaths = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final key = utf8.decode(Uint8List.sublistView(message!));
          requestedPaths.add(key);
          final asset = assetsByPath[key];
          if (asset == null) return null;
          return ByteData.sublistView(utf8.encode(asset));
        });
  }
}

const String _kValidConfig = '''
{
  "_meta": {"schemaVersion": "1.0.0"},
  "app": {"name": "COV1 Test Eatery", "bundleId": "com.cov1.eatery"},
  "theme": {
    "injection": "local-config-file",
    "colors": {"primary": "0xFF1D3557"}
  },
  "environment": {"cloudinaryCloudName": "cov1_cloud"},
  "features": {"flags": {"liveMenu": true}, "unknownFlagDefault": false},
  "navigation": {"entryPoint": "/splash", "tabs": ["menu", "cart"]}
}
''';

void main() {
  setUp(() {
    // The test seam resets every resolved static so each test loads against
    // a fresh config (the `_loaded` guard would otherwise be one-shot).
    AppConfig.resetForTest();
  });

  group('splash config load — success path (COV-1)', () {
    test(
      'a valid client_config.json resolves layers with no error and no gate',
      () async {
        final server = _AssetServer({
          'assets/client_config.json': _kValidConfig,
        });
        server.install();

        await AppConfig.loadConfig();

        expect(AppConfig.isLoaded, isTrue);
        expect(AppConfig.loadFailed, isFalse);
        expect(AppConfig.loadError, isNull);
        expect(AppConfig.schemaError, isNull);
        // Layer 3 (JSON) resolved the per-client identity.
        expect(AppConfig.appName, 'COV1 Test Eatery');
        expect(AppConfig.bundleId, 'com.cov1.eatery');
        expect(AppConfig.cloudinaryCloudName, 'cov1_cloud');
        expect(AppConfig.navigationEntryPoint, '/splash');
        expect(AppConfig.featureEnabled('liveMenu'), isTrue);
        expect(server.requestedPaths, hasLength(1));
        expect(
          server.requestedPaths.single,
          contains('client_config.json'),
          reason: 'the loader reads the REAL bundled asset path',
        );
      },
    );

    test(
      'loadConfig is idempotent — a second call does not re-read the asset',
      () async {
        final server = _AssetServer({
          'assets/client_config.json': _kValidConfig,
        });
        server.install();

        await AppConfig.loadConfig();
        await AppConfig.loadConfig();

        expect(
          server.requestedPaths,
          hasLength(1),
          reason: 'the `_loaded` guard means one load per boot (W6.4(2))',
        );
      },
    );
  });

  group('splash config load — graceful degradation (COV-1)', () {
    test(
      'a malformed asset degrades to defaults + a recorded error (never crashes)',
      () async {
        final server = _AssetServer({
          'assets/client_config.json': '{ this is not json',
        });
        server.install();

        await AppConfig.loadConfig();

        expect(AppConfig.isLoaded, isTrue);
        expect(AppConfig.loadFailed, isTrue);
        expect(AppConfig.loadError, isNotEmpty);
        expect(
          AppConfig.schemaError,
          isNull,
          reason:
              'a non-schema parse failure is NOT a fail-closed gate — the '
              'graceful defaults+dotenv boot stays intact',
        );
        // The in-code defaults survive (identity never goes empty).
        expect(AppConfig.appName, isNotEmpty);
        expect(AppConfig.bundleId, isNotEmpty);
      },
    );

    test('a MISSING asset degrades to defaults + a recorded error', () async {
      // No asset registered -> the platform channel answers "asset absent".
      final server = _AssetServer({});
      server.install();

      await AppConfig.loadConfig();

      expect(AppConfig.isLoaded, isTrue);
      expect(AppConfig.loadFailed, isTrue);
      expect(AppConfig.loadError, isNotEmpty);
      expect(AppConfig.schemaError, isNull);
      expect(AppConfig.appName, isNotEmpty);
    });
  });

  group('splash config load — fail-closed schema gate (W6.5, COV-1)', () {
    test(
      'a REQUIRED-field violation surfaces the typed ConfigException the boot must honor',
      () async {
        // Empty app.name + entryPoint missing its leading "/" — two distinct
        // REQUIRED-field violations.
        final server = _AssetServer({
          'assets/client_config.json': '''
{
  "_meta": {"schemaVersion": "1.0.0"},
  "app": {"name": "", "bundleId": "com.cov1.eatery"},
  "theme": {"injection": "local-config-file", "colors": {"primary": "0xFF1D3557"}},
  "navigation": {"entryPoint": "splash"}
}
''',
        });
        server.install();

        await AppConfig.loadConfig();

        expect(AppConfig.isLoaded, isTrue);
        expect(AppConfig.loadFailed, isTrue);
        final schemaError = AppConfig.schemaError;
        expect(
          schemaError,
          isNotNull,
          reason:
              'a config that PARSES but violates the REQUIRED schema sets the '
              'fail-closed gate (main.dart blocks on ConfigValidationErrorScreen)',
        );
        expect(schemaError, isA<ConfigException>());
        final exception = schemaError!;
        expect(
          exception.jsonPath,
          'app.name',
          reason: 'the first violation carries its exact JSON path',
        );
        expect(
          exception.violations.any((v) => v.path == 'navigation.entryPoint'),
          isTrue,
          reason:
              'EVERY REQUIRED-field violation is surfaced, not just the first',
        );
        expect(
          exception.toString(),
          contains('app.name'),
          reason: 'the operator-facing message names the violating path',
        );
      },
    );

    test(
      'an out-of-band schemaVersion is rejected (newer config never boots an older app)',
      () async {
        // The out-of-band schema pin.
        final server = _AssetServer({
          'assets/client_config.json': '''
{
  "_meta": {"schemaVersion": "9.9.9"},
  "app": {"name": "COV1 Test Eatery", "bundleId": "com.cov1.eatery"},
  "theme": {"injection": "local-config-file", "colors": {"primary": "0xFF1D3557"}},
  "navigation": {"entryPoint": "/splash"}
}
''',
        });
        server.install();

        await AppConfig.loadConfig();

        final schemaError = AppConfig.schemaError;
        expect(schemaError, isNotNull);
        expect(schemaError!.jsonPath, '_meta.schemaVersion');
      },
    );
  });
}
