import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart'
    as shared
    show CarnamaBootstrap, firebaseKeyConfigured, initCarnamaApp;
import 'package:labs/labs.dart' show AppConfig;

import 'package:halal_boyz/app/app.dart';
import 'package:halal_boyz/app/client_config_loader.dart';
import 'package:halal_boyz/app/config_error_screen.dart';
import 'package:halal_boyz/app/core_config_adapter.dart';

/// W6.1: the shell boots FAIL-CLOSED. The Firebase key gate and the
/// Firebase-init failure path live in the SHARED 16-step init
/// (`package:labs` `initCarnamaApp`, STEP 13); the shell's thin `main.dart`
/// supplies its per-project options + the blocking `ConfigErrorScreen`
/// builder. W6.3: a missing/malformed client_config.json degrades to
/// defaults + a recorded error and must never crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FirebaseOptions options({String apiKey = 'AIzaSyA-real-android-key'}) =>
      FirebaseOptions(
        apiKey: apiKey,
        appId: 'present-app-id',
        messagingSenderId: '1234567890',
        projectId: 'client-project',
      );

  Map<String, dynamic> configWithKey(String key) => <String, dynamic>{
    'app': <String, dynamic>{
      'name': 'Client App',
      'bundleId': 'labs.client.app',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': key,
      'firebaseIosApiKey': key,
    },
    'firebase': <String, dynamic>{'projectId': 'client-project'},
    'navigation': <String, dynamic>{
      'entryPoint': '/',
      'routes': <String, dynamic>{
        'home': '/',
        'menu': '/menu',
        'cart': '/cart',
        'checkout': '/checkout',
      },
    },
    'theme': <String, dynamic>{
      'injection': 'local-config-file',
      'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
    },
  };

  group('firebaseKeyConfigured — the SHARED resolved-options gate (W6.1)', () {
    test('rejects an empty resolved api key', () {
      expect(shared.firebaseKeyConfigured(options(apiKey: '')), isFalse);
    });

    test('rejects documented placeholders (case-insensitive)', () {
      expect(
        shared.firebaseKeyConfigured(options(apiKey: 'REPLACE_ME_API_KEY')),
        isFalse,
      );
      expect(
        shared.firebaseKeyConfigured(options(apiKey: 'please changeme now')),
        isFalse,
      );
      expect(
        shared.firebaseKeyConfigured(options(apiKey: '<your-api-key>')),
        isFalse,
      );
    });

    test('accepts a real key', () {
      expect(shared.firebaseKeyConfigured(options()), isTrue);
    });
  });

  group(
    'loader firebaseKeyConfigured — the client_config.json gate (W6.1)',
    () {
      test('rejects an empty key', () {
        expect(firebaseKeyConfigured(configWithKey('')), isFalse);
      });

      test('rejects documented placeholders (case-insensitive)', () {
        expect(
          firebaseKeyConfigured(configWithKey('REPLACE_ME_API_KEY')),
          isFalse,
        );
        expect(
          firebaseKeyConfigured(configWithKey('please changeme now')),
          isFalse,
        );
        expect(firebaseKeyConfigured(configWithKey('<your-api-key>')), isFalse);
      });

      test('accepts a real key', () {
        expect(
          firebaseKeyConfigured(configWithKey('AIzaSyA-real-key')),
          isTrue,
        );
      });

      test('rejects a config without an environment section', () {
        expect(firebaseKeyConfigured(<String, dynamic>{}), isFalse);
      });
    },
  );

  testWidgets(
    'empty firebase key blocks the SHARED init on ConfigErrorScreen and '
    'never initializes Firebase',
    (tester) async {
      AppConfig.resetForTest();
      final originalOnError = PlatformDispatcher.instance.onError;
      final originalErrorWidget = ErrorWidget.builder;
      try {
        // The REAL production boot function — with a placeholder-resolved
        // key the shell policy (blocking screen builder) must stop the boot
        // at STEP 13, BEFORE Firebase.initializeApp.
        //
        // tester.runAsync: the boot body performs REAL async I/O (asset
        // reads, logger file writes) that can never complete under the
        // test binding's fake async. runAsync escapes to the real event
        // loop — exactly like production — while keeping the resulting
        // widget tree inspectable afterwards.
        await tester.runAsync(
          () => shared.initCarnamaApp(
            bootstrap: shared.CarnamaBootstrap(
              firebaseOptions: options(apiKey: ''),
              coreConfig: const ClientCoreConfig(<String, dynamic>{
                'app': <String, dynamic>{'bundleId': 'labs.client.app'},
              }),
              appBuilder: () => const GeneratedApp(config: <String, dynamic>{}),
              firebaseErrorScreenBuilder: ConfigErrorScreen.new,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(ConfigErrorScreen), findsOneWidget);
        expect(find.byType(GeneratedApp), findsNothing);
        expect(
          Firebase.apps,
          isEmpty,
          reason: 'the blocked boot path must skip Firebase.initializeApp',
        );
      } finally {
        // flutter_test verifies at the end of the test body that the
        // error-widget builder is unset, so restore inline (addTearDown
        // runs too late for that verification).
        ErrorWidget.builder = originalErrorWidget;
        PlatformDispatcher.instance.onError = originalOnError;
        AppConfig.resetForTest();
      }
    },
  );

  group('loadClientConfig (W6.3 resilience)', () {
    test(
      'malformed JSON degrades to defaults + recorded error, no crash',
      () async {
        final loaded = await loadClientConfig(
          readAsset: (assetKey) async => '{ not valid json',
        );
        expect(loaded.config, isEmpty);
        expect(loaded.error, isA<FormatException>());
      },
    );

    test(
      'missing asset degrades to defaults + recorded error, no crash',
      () async {
        final loaded = await loadClientConfig(
          readAsset: (assetKey) =>
              throw StateError('asset not found: $assetKey'),
        );
        expect(loaded.config, isEmpty);
        expect(loaded.error, isA<StateError>());
      },
    );

    test('valid JSON parses through unchanged', () async {
      final loaded = await loadClientConfig(
        readAsset: (assetKey) async => '{"app": {"name": "Client App"}}',
      );
      expect(loaded.error, isNull);
      expect(loaded.config['app'], isA<Map<dynamic, dynamic>>());
    });
  });
}
