@Tags(['gate_fast'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/client_config.dart';
import 'package:labs/app/config/config_validation_error_screen.dart';
import 'package:labs/app/config/screen_variants.dart';

/// WL-2 (W6.4/W6.5): the REAL REQUIRED-field config schema validator, the
/// REAL projectId dual-read, and the REAL load-failure surfacing. Fixtures
/// are injected through the mocked asset channel; the golden fixtures are
/// the REAL repo configs read from disk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> validConfig() => <String, dynamic>{
    'tenantId': 'client_app',
    '_meta': <String, dynamic>{
      'schemaVersion': ClientConfig.supportedSchemaVersion,
    },
    'app': <String, dynamic>{
      'name': 'Client App',
      'bundleId': 'com.client.app',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': 'AIzaSyA-real-key',
      'firebaseIosApiKey': 'AIzaSyA-real-key',
    },
    'firebase': <String, dynamic>{'projectId': 'client-project'},
    'theme': <String, dynamic>{
      'injection': ClientConfig.requiredInjectionMode,
      'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
    },
    'navigation': <String, dynamic>{
      'entryPoint': '/',
      'routes': <String, dynamic>{'home': '/', 'menu': '/menu'},
    },
  };

  /// Runs the REAL validator and asserts it throws with [pathFragment].
  void expectThrowsWith(Map<String, dynamic> json, String pathFragment) {
    try {
      ClientConfig.fromMap(json);
      fail('expected ConfigException for "$pathFragment"');
    } on ConfigException catch (error) {
      expect(error.toString(), contains(pathFragment));
    }
  }

  group('T-3 golden: valid fixtures parse', () {
    test('schema-valid fixture parses without throwing', () {
      expect(() => ClientConfig.fromMap(validConfig()), returnsNormally);
    });

    test('golden: the REAL core_app template config parses', () {
      final file = File('assets/client_config.json');
      expect(file.existsSync(), isTrue, reason: 'run from core_app/');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });

    test('golden: the REAL generated halal_boyz config parses', () {
      final file = File('../apps/halal_boyz/assets/client_config.json');
      expect(file.existsSync(), isTrue, reason: 'repo-root sibling lookup');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });
  });

  group('T-3: missing REQUIRED fields reject with the exact JSON path', () {
    // P0-6: tenancy identity. Absent and malformed both fail closed AT THE
    // VALIDATOR, which is what lets P0-6 promise "refused before generation".
    test('missing tenantId', () {
      final json = validConfig()..remove('tenantId');
      expectThrowsWith(json, '"tenantId"');
    });

    test('malformed tenantId (uppercase/spaces/punctuation)', () {
      final json = validConfig()..['tenantId'] = 'Halal Boyz!';
      expectThrowsWith(json, '"tenantId"');
    });

    test('malformed tenantId (leading separator)', () {
      final json = validConfig()..['tenantId'] = '_halal';
      expectThrowsWith(json, '"tenantId"');
    });

    test('non-string tenantId is refused, not coerced', () {
      final json = validConfig()..['tenantId'] = 42;
      expectThrowsWith(json, '"tenantId"');
    });

    test('missing _meta.schemaVersion', () {
      final json = validConfig()..remove('_meta');
      expectThrowsWith(json, '"_meta.schemaVersion"');
    });

    test('missing app.name', () {
      final json = validConfig();
      (json['app'] as Map<String, dynamic>).remove('name');
      expectThrowsWith(json, '"app.name"');
    });

    test('missing app.bundleId', () {
      final json = validConfig();
      (json['app'] as Map<String, dynamic>).remove('bundleId');
      expectThrowsWith(json, '"app.bundleId"');
    });

    test('missing theme.injection (the enum mode)', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>).remove('injection');
      expectThrowsWith(json, '"theme.injection"');
    });

    test('missing theme.colors.primary', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>).remove('colors');
      expectThrowsWith(json, '"theme.colors.primary"');
    });

    test('missing navigation.entryPoint', () {
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>).remove('entryPoint');
      expectThrowsWith(json, '"navigation.entryPoint"');
    });
  });

  group('T-3: wrong-typed REQUIRED fields reject with the exact JSON path', () {
    test('app.name as int', () {
      final json = validConfig();
      (json['app'] as Map<String, dynamic>)['name'] = 42;
      expectThrowsWith(json, '"app.name"');
    });

    test('app.bundleId as int', () {
      final json = validConfig();
      (json['app'] as Map<String, dynamic>)['bundleId'] = 42;
      expectThrowsWith(json, '"app.bundleId"');
    });

    test('_meta.schemaVersion as int', () {
      final json = validConfig();
      (json['_meta'] as Map<String, dynamic>)['schemaVersion'] = 42;
      expectThrowsWith(json, '"_meta.schemaVersion"');
    });

    test('theme.injection as int', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['injection'] = 42;
      expectThrowsWith(json, '"theme.injection"');
    });

    test('theme.colors.primary as int', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['colors'] = <String, dynamic>{
        'primary': 42,
      };
      expectThrowsWith(json, '"theme.colors.primary"');
    });

    test('theme.colors.primary not a parseable hex color', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['colors'] = <String, dynamic>{
        'primary': 'brand-orange',
      };
      expectThrowsWith(json, '"theme.colors.primary"');
    });

    test('navigation.entryPoint as int', () {
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>)['entryPoint'] = 42;
      expectThrowsWith(json, '"navigation.entryPoint"');
    });

    test('navigation.entryPoint not a route path', () {
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>)['entryPoint'] = 'home';
      expectThrowsWith(json, '"navigation.entryPoint"');
    });
  });

  group('T-3: enum mode (theme.injection) is a closed set', () {
    test('the required mode passes', () {
      final json = validConfig();
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });

    test('an unknown mode rejects', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['injection'] = 'remote-config';
      expectThrowsWith(json, '"theme.injection"');
    });
  });

  // ADR-01 (P0-10): the payment surface is schema-only and OPTIONAL — absent
  // must stay valid, present-but-wrong-typed must fail closed.
  group('ADR-01: optional card-present payment fields', () {
    test('absent stripeAccountId / terminalLocationId still parse', () {
      final json = validConfig();
      expect(json.containsKey('stripeAccountId'), isFalse);
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });

    test('stripeAccountId accepts a string and the empty-string default', () {
      for (final value in <String>['acct_1Example', '']) {
        final json = validConfig()..['stripeAccountId'] = value;
        expect(
          () => ClientConfig.fromMap(json),
          returnsNormally,
          reason: 'value: "$value"',
        );
      }
    });

    test('stripeAccountId rejects a non-string', () {
      final json = validConfig()..['stripeAccountId'] = 42;
      expectThrowsWith(json, '"stripeAccountId"');
    });

    test('terminalLocationId accepted flat and per-branch', () {
      final flat = validConfig()
        ..['branches'] = <String, dynamic>{
          'defaultBranchId': 'main',
          'terminalLocationId': 'tml_123',
        };
      expect(() => ClientConfig.fromMap(flat), returnsNormally);

      final nested = validConfig()
        ..['branches'] = <String, dynamic>{
          'main': <String, dynamic>{'terminalLocationId': 'tml_123'},
        };
      expect(() => ClientConfig.fromMap(nested), returnsNormally);
    });

    test('per-branch terminalLocationId rejects a non-string', () {
      final json = validConfig()
        ..['branches'] = <String, dynamic>{
          'main': <String, dynamic>{'terminalLocationId': 7},
        };
      expectThrowsWith(json, '"branches.main.terminalLocationId"');
    });
  });

  group('T-4: unknown route keys reject', () {
    test('unknown navigation.routes key -> load error naming the key', () {
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>)['routes'] =
          <String, dynamic>{'notARealRoute': '/nope'};
      expectThrowsWith(json, '"navigation.routes.notARealRoute"');
    });

    test('malformed route path rejects', () {
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>)['routes'] =
          <String, dynamic>{'menu': 'menu'};
      expectThrowsWith(json, '"navigation.routes.menu"');
    });

    test('every known route key passes', () {
      final routes = <String, dynamic>{
        for (final key in ClientConfig.knownRouteKeys) key: '/$key',
      };
      final json = validConfig();
      (json['navigation'] as Map<String, dynamic>)['routes'] = routes;
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });
  });

  /// Mocks the flutter/assets channel so `rootBundle` resolves exactly
  /// [assets] (anything else is reported missing).
  void mockAssets(Map<String, String> assets) {
    const channel = 'flutter/assets';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, (message) async {
          if (message == null) return null;
          final key = utf8.decode(message.buffer.asUint8List());
          final content = assets[key];
          if (content == null) return null;
          return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
        });
  }

  String schemaValidConfigJson({
    String? environmentFirebaseProjectId,
    String? firebaseProjectId,
  }) => jsonEncode(<String, dynamic>{
    'tenantId': 'client_app',
    '_meta': <String, dynamic>{
      'schemaVersion': ClientConfig.supportedSchemaVersion,
    },
    'app': <String, dynamic>{
      'name': 'Client App',
      'bundleId': 'com.client.app',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    if (environmentFirebaseProjectId != null)
      'environment': <String, dynamic>{
        'firebaseProjectId': environmentFirebaseProjectId,
      },
    'firebase': <String, dynamic>{
      if (firebaseProjectId != null) 'projectId': firebaseProjectId,
    },
    'theme': <String, dynamic>{
      'injection': ClientConfig.requiredInjectionMode,
      'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
    },
    'navigation': <String, dynamic>{
      'entryPoint': '/',
      'routes': <String, dynamic>{'home': '/', 'menu': '/menu'},
    },
  });

  group('T-1: projectId dual-read (dotenv > env key > legacy key)', () {
    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('only firebase.projectId in JSON -> the JSON value is used', () async {
      AppConfig.resetForTest();
      mockAssets({
        'assets/client_config.json': schemaValidConfigJson(
          firebaseProjectId: 'json-legacy-project',
        ),
      });
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.schemaError, isNull);
      expect(AppConfig.firebaseProjectId, 'json-legacy-project');
    });

    test(
      'both JSON keys populated -> environment.firebaseProjectId wins',
      () async {
        AppConfig.resetForTest();
        mockAssets({
          'assets/client_config.json': schemaValidConfigJson(
            environmentFirebaseProjectId: 'json-env-project',
            firebaseProjectId: 'json-legacy-project',
          ),
        });
        await AppConfig.loadConfig();
        expect(AppConfig.firebaseProjectId, 'json-env-project');
      },
    );

    test('dotenv populated wins over both JSON keys (W6.4(1))', () async {
      AppConfig.resetForTest();
      mockAssets({
        '.env': 'FIREBASE_PROJECT_ID=dotenv-project\n',
        'assets/client_config.json': schemaValidConfigJson(
          environmentFirebaseProjectId: 'json-env-project',
          firebaseProjectId: 'json-legacy-project',
        ),
      });
      await dotenv.load(fileName: '.env');
      await AppConfig.loadConfig();
      expect(AppConfig.firebaseProjectId, 'dotenv-project');
      dotenv.env.clear();
    });
  });

  group('T-2: loadFailed is surfaced (never silent)', () {
    test(
      'malformed asset -> loadFailed + loadError, no typed schemaError',
      () async {
        AppConfig.resetForTest();
        mockAssets({'assets/client_config.json': '{ not valid json'});
        await AppConfig.loadConfig();
        expect(AppConfig.loadFailed, isTrue);
        expect(AppConfig.loadError, isNotNull);
        expect(AppConfig.schemaError, isNull);
      },
    );

    test('schema-invalid asset -> typed schemaError + loadFailed', () async {
      AppConfig.resetForTest();
      final broken =
          jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
      (broken['app'] as Map<String, dynamic>).remove('name');
      mockAssets({'assets/client_config.json': jsonEncode(broken)});
      await AppConfig.loadConfig();
      expect(AppConfig.loadFailed, isTrue);
      expect(AppConfig.schemaError, isA<ConfigException>());
      expect(AppConfig.schemaError!.jsonPath, 'app.name');
    });

    test('the recorded failure reaches the log file through the exact '
        'LoggerService.error call app_bootstrap.dart makes', () async {
      AppConfig.resetForTest();
      mockAssets({'assets/client_config.json': '{ not valid json'});
      await AppConfig.loadConfig();
      final tempDir = await Directory.systemTemp.createTemp('wl2_t2_logs_');
      addTearDown(() => tempDir.delete(recursive: true));
      final logger = LoggerService(testDirectory: tempDir);
      await logger.init();
      // Mirrors core_app/lib/app_bootstrap.dart's W6.4(2) consumption verbatim.
      final loadError =
          AppConfig.loadError ?? (fail('loadError must be recorded'));
      await logger.error(loadError, 'ClientConfigLoadFailed');
      final logs = await logger.readLogs();
      expect(logs.join('\n'), contains('ClientConfigLoadFailed'));
      // LoggerService URL-encodes the JSON context: decode the line and
      // assert the recorded error made it through the round trip.
      final line = logs.lastWhere(
        (entry) => entry.contains('ClientConfigLoadFailed'),
      );
      final context =
          jsonDecode(Uri.decodeComponent(line.split(' | ').last))
              as Map<String, dynamic>;
      expect(context['error'], loadError);
    });

    testWidgets('W6.4(2): the debug banner renders the failure message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: ConfigLoadFailureBanner()),
        ),
      );
      // Banner paints its message with TextPainter (no Text widget), so the
      // assertion reads the widget's properties. debugShowCheckedModeBanner
      // is off so MaterialApp's own Banner cannot collide with this lookup.
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, 'CONFIG LOAD FAILED');
      expect(banner.location, BannerLocation.topEnd);
    });

    testWidgets('W6.5: the validation screen renders the typed violations', (
      tester,
    ) async {
      final broken =
          jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
      (broken['app'] as Map<String, dynamic>).remove('name');
      Object? captured;
      try {
        ClientConfig.fromMap(broken);
      } on ConfigException catch (error) {
        captured = error;
      }
      expect(captured, isA<ConfigException>());
      await tester.pumpWidget(
        MaterialApp(
          home: ConfigValidationErrorScreen(
            error: captured! as ConfigException,
          ),
        ),
      );
      expect(find.text('Invalid client configuration'), findsOneWidget);
      expect(find.textContaining('"app.name"'), findsOneWidget);
    });
  });

  group(
    'TOKENS: malformed optional design tokens fail CLOSED (exact path)',
    () {
      test('shape.cardRadius non-numeric', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
          'cardRadius': '16',
        };
        expectThrowsWith(json, '"theme.shape.cardRadius"');
      });

      test('shape.ctaRadius negative', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
          'ctaRadius': -4,
        };
        expectThrowsWith(json, '"theme.shape.ctaRadius"');
      });

      test('components.navigationBar.activeColor not hex', () {
        final json = validConfig();
        (json['theme']
            as Map<String, dynamic>)['components'] = <String, dynamic>{
          'navigationBar': <String, dynamic>{'activeColor': 'maroon'},
        };
        expectThrowsWith(json, '"theme.components.navigationBar.activeColor"');
      });

      test('components.input.radius non-numeric', () {
        final json = validConfig();
        (json['theme']
            as Map<String, dynamic>)['components'] = <String, dynamic>{
          'input': <String, dynamic>{'radius': '8'},
        };
        expectThrowsWith(json, '"theme.components.input.radius"');
      });

      test('components.chip.radius zero', () {
        final json = validConfig();
        (json['theme']
            as Map<String, dynamic>)['components'] = <String, dynamic>{
          'chip': <String, dynamic>{'radius': 0},
        };
        expectThrowsWith(json, '"theme.components.chip.radius"');
      });

      test('background.color not hex', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['background'] =
            <String, dynamic>{'color': 'not-a-color'};
        expectThrowsWith(json, '"theme.background.color"');
      });

      test('background.overlayAsset absolute path rejected', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['background'] =
            <String, dynamic>{'overlayAsset': '/etc/city_map.png'};
        expectThrowsWith(json, '"theme.background.overlayAsset"');
      });

      test('background.overlayAsset with .. rejected', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['background'] =
            <String, dynamic>{'overlayAsset': 'assets/../secret.png'};
        expectThrowsWith(json, '"theme.background.overlayAsset"');
      });

      test('animationStyle invalid enum', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['animationStyle'] = 'extreme';
        expectThrowsWith(json, '"theme.animationStyle"');
      });

      // Q3 (semantic state palette): `colors.soldOut` joins the engine-read
      // surface, so it is validated STRICTLY WHEN PRESENT — the same b10 rule
      // the other optional visual tokens follow (absent = AppColors default).
      test('colors.soldOut not hex', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['colors'] = <String, dynamic>{
          'primary': '0xFF2E7D32',
          'soldOut': 'not-a-color',
        };
        expectThrowsWith(json, '"theme.colors.soldOut"');
      });

      test('valid colors.soldOut parses', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['colors'] = <String, dynamic>{
          'primary': '0xFF2E7D32',
          'soldOut': '0xFF616161',
        };
        expect(() => ClientConfig.fromMap(json), returnsNormally);
      });

      // Q1 (signature identity): `theme.signature.style` is engine-read
      // (it builds AppSignatureTokens) and CLOSED-SET — rejected at its exact
      // path when the block is present; absent = stock UI (b10 byte contract).
      test('signature.style outside the closed style set', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['signature'] =
            <String, dynamic>{'style': 'neon'};
        expectThrowsWith(json, '"theme.signature.style"');
      });

      test('signature block without style', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['signature'] =
            <String, dynamic>{};
        expectThrowsWith(json, '"theme.signature.style"');
      });

      test('valid signature.style parses', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['signature'] =
            <String, dynamic>{'style': 'rule'};
        expect(() => ClientConfig.fromMap(json), returnsNormally);
      });

      // p35 W6.5 runtime parity: `theme.shape.style` and `theme.depth` are
      // engine-read CLOSED-SET keys. The generator's validate() has always
      // rejected an unknown value; the runtime validator now fails closed at
      // the same paths too (previously a typo silently degraded at boot and
      // only the generator — run at stamp time — could catch it).
      test('shape.style outside the preset vocabulary', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
          'style': 'blobby',
        };
        expectThrowsWith(json, '"theme.shape.style"');
      });

      test('depth outside the preset vocabulary', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['depth'] = 'chunky';
        expectThrowsWith(json, '"theme.depth"');
      });

      test('valid shape.style and depth parse', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)
          ..['shape'] = <String, dynamic>{'style': 'round'}
          ..['depth'] = 'soft';
        expect(() => ClientConfig.fromMap(json), returnsNormally);
      });

      test('typography.headingFont non-string', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)['typography'] =
            <String, dynamic>{'headingFont': 12};
        expectThrowsWith(json, '"theme.typography.headingFont"');
      });

      test('valid optional tokens parse', () {
        final json = validConfig();
        (json['theme'] as Map<String, dynamic>)
          ..['shape'] = <String, dynamic>{'cardRadius': 12, 'ctaRadius': 100}
          ..['animationStyle'] = 'subtle'
          ..['components'] = <String, dynamic>{
            'navigationBar': <String, dynamic>{
              'background': '0xFF1A1A1A',
              'activeColor': '0xFFFFA500',
            },
          }
          ..['background'] = <String, dynamic>{'color': '0xFFF5EFEB'};
        (json['theme']
            as Map<String, dynamic>)['typography'] = <String, dynamic>{
          'headingFont': 'PlayfairDisplay',
          'bodyFont': 'Inter',
        };
        expect(() => ClientConfig.fromMap(json), returnsNormally);
      });
    },
  );

  group('TOKENS: parser hydration (theme.background.overlayAsset)', () {
    test('loadConfig hydrates AppConfig.scaffoldOverlayAsset', () async {
      AppConfig.resetForTest();
      final config =
          jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
      (config['theme'] as Map<String, dynamic>)['background'] =
          <String, dynamic>{'overlayAsset': 'assets/images/city_map.png'};
      mockAssets({'assets/client_config.json': jsonEncode(config)});
      await AppConfig.loadConfig();
      expect(AppConfig.scaffoldOverlayAsset, 'assets/images/city_map.png');
    });

    test('absent overlay stays empty', () async {
      AppConfig.resetForTest();
      mockAssets({'assets/client_config.json': schemaValidConfigJson()});
      await AppConfig.loadConfig();
      expect(AppConfig.scaffoldOverlayAsset, '');
    });
  });

  group(
    'PERF-5: screens[].variant fails CLOSED through the real load gate',
    () {
      test(
        'unknown variant -> typed schemaError naming screens[0].variant',
        () async {
          AppConfig.resetForTest();
          final config =
              jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
          config['screens'] = <dynamic>[
            {'id': 'HomeScreen', 'route': '/', 'variant': 'carousel'},
          ];
          mockAssets({'assets/client_config.json': jsonEncode(config)});
          await AppConfig.loadConfig();
          expect(AppConfig.loadFailed, isTrue);
          expect(AppConfig.schemaError, isA<ConfigException>());
          expect(AppConfig.schemaError!.jsonPath, 'screens[0].variant');
          expect(AppConfig.schemaError.toString(), contains('carousel'));
        },
      );

      test(
        'variant on a screen id outside the catalog -> typed schemaError',
        () async {
          AppConfig.resetForTest();
          final config =
              jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
          config['screens'] = <dynamic>[
            {'id': 'MenuScreen', 'route': '/menu', 'variant': 'showcase'},
          ];
          mockAssets({'assets/client_config.json': jsonEncode(config)});
          await AppConfig.loadConfig();
          expect(AppConfig.schemaError, isA<ConfigException>());
          expect(AppConfig.schemaError!.jsonPath, 'screens[0].variant');
          expect(
            AppConfig.schemaError.toString(),
            contains('no variant vocabulary'),
          );
        },
      );

      test(
        'valid pilot variant parses and resolves through the registry',
        () async {
          AppConfig.resetForTest();
          final config =
              jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
          config['screens'] = <dynamic>[
            {'id': 'HomeScreen', 'route': '/', 'variant': 'showcase'},
          ];
          mockAssets({'assets/client_config.json': jsonEncode(config)});
          await AppConfig.loadConfig();
          expect(AppConfig.loadFailed, isFalse);
          expect(AppConfig.schemaError, isNull);
          // The parse passes the variant through the screens registry...
          expect(AppConfig.screens, hasLength(1));
          expect(AppConfig.screens.first['variant'], 'showcase');
          // ...and the registry provider resolves it for the home feed.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          expect(
            container.read(screenVariantProvider(ScreenVariants.homeScreenId)),
            ScreenVariants.homeShowcaseVariant,
          );
        },
      );

      test(
        'no variant key -> the byte-for-byte default resolves (grid)',
        () async {
          AppConfig.resetForTest();
          final config =
              jsonDecode(schemaValidConfigJson()) as Map<String, dynamic>;
          config['screens'] = <dynamic>[
            {'id': 'HomeScreen', 'route': '/'},
          ];
          mockAssets({'assets/client_config.json': jsonEncode(config)});
          await AppConfig.loadConfig();
          expect(AppConfig.loadFailed, isFalse);
          expect(AppConfig.schemaError, isNull);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          expect(
            container.read(screenVariantProvider(ScreenVariants.homeScreenId)),
            ScreenVariants.homeGridVariant,
            reason: 'the default MUST be today\'s layout (acceptance 2)',
          );
        },
      );
    },
  );
}
