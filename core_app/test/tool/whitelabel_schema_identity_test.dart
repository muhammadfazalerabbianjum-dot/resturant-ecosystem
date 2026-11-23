import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/config/client_config.dart';
import 'package:labs/app/config/screen_variants.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// WL-2 (W6.4(4)/(5) + W6.6): the generator's tightened validate()
/// (schemaVersion pin + required currency with the --allow-usd-fallback
/// opt-in), the widened forbidden-token guard, the post-generation identity
/// check, and the platform display-name alignment. The identity check is also
/// run LIVE against the checked-in halal_boyz shell (T-6).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_wl2_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  List<String> validateJson(
    Map<String, dynamic> json, {
    bool allowUsdFallback = false,
  }) {
    final file = File('${tempDir.path}${Platform.pathSeparator}config.json');
    file.writeAsStringSync(jsonEncode(json));
    // p36 T-4: validate() requires `app.icon` to resolve to a real PNG >=512
    // next to the config — stage the synthetic master with every fixture.
    File(
      '${tempDir.path}${Platform.pathSeparator}app_icon.png',
    ).writeAsBytesSync(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
    ]);
    return whitelabel.ClientConfig.load(
      file.path,
    ).validate(allowUsdFallback: allowUsdFallback);
  }

  Map<String, dynamic> validConfig() => <String, dynamic>{
    'tenantId': 'halal_boyz',
    '_meta': <String, dynamic>{
      'schemaVersion': whitelabel.whitelabelSupportedSchemaVersion,
    },
    'app': <String, dynamic>{
      'icon': 'app_icon.png',
      'name': 'Halal Boyz',
      'bundleId': 'labs.carnama.halalboys',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': 'AIzaSyA-real-android-key',
      'firebaseIosApiKey': 'AIzaSyA-real-ios-key',
    },
    'firebase': <String, dynamic>{'projectId': 'demo-tenant'},
    'theme': <String, dynamic>{
      'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
    },
    'navigation': <String, dynamic>{'entryPoint': '/'},
    'features': <String, dynamic>{
      'flags': <String, dynamic>{'smartReorder': true},
      'unknownFlagDefault': false,
    },
  };

  group('schema version constant sync (tool vs runtime validator)', () {
    test(
      'whitelabelSupportedSchemaVersion == ClientConfig.supportedSchemaVersion',
      () {
        expect(
          whitelabel.whitelabelSupportedSchemaVersion,
          ClientConfig.supportedSchemaVersion,
        );
      },
    );
  });

  group('W6.4(4): validate() pins _meta.schemaVersion', () {
    test('missing _meta -> error naming the path', () {
      final json = validConfig()..remove('_meta');
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"_meta.schemaVersion"')),
        isTrue,
        reason: 'errors: $errors',
      );
    });

    test('wrong schemaVersion -> error', () {
      final json = validConfig();
      (json['_meta'] as Map<String, dynamic>)['schemaVersion'] = '9.9.9';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"_meta.schemaVersion"')),
        isTrue,
        reason: 'errors: $errors',
      );
    });

    test('supported schemaVersion passes', () {
      expect(validateJson(validConfig()), isEmpty);
    });
  });

  group('W6.4(5): validate() requires currency (USD fallback opt-in)', () {
    test('missing currency -> error naming currency.code', () {
      final json = validConfig()..remove('currency');
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"currency.code"')),
        isTrue,
        reason: 'errors: $errors',
      );
    });

    test('empty currency.code -> error', () {
      final json = validConfig();
      (json['currency'] as Map<String, dynamic>)['code'] = '';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"currency.code"')),
        isTrue,
        reason: 'errors: $errors',
      );
    });

    test('--allow-usd-fallback accepts a missing currency section', () {
      final json = validConfig()..remove('currency');
      expect(validateJson(json, allowUsdFallback: true), isEmpty);
    });
  });

  group('W6.6: forbidden-token guard covers Carnama Firebase fragments', () {
    void writeConfigAndCheck(String content) {
      final file = File('${tempDir.path}${Platform.pathSeparator}config.json');
      file.writeAsStringSync(content);
      whitelabel.checkConfigForbiddenTokens(file.path);
    }

    test('sender-id fragment is refused', () {
      expect(
        // Assembled from fragments so this test source itself never carries
        // the live identity literal.
        () => writeConfigAndCheck(
          '{"firebase": {"messagingSenderId": "${'69700'}7956550"}}',
        ),
        throwsStateError,
      );
    });

    test('project-id fragment is refused', () {
      expect(
        () => writeConfigAndCheck(
          '{"firebase": {"projectId": "${'resturants-'}8547d"}}',
        ),
        throwsStateError,
      );
    });

    test('a clean config passes the guard', () {
      expect(
        () => writeConfigAndCheck(
          '{"firebase": {"projectId": "client-project", '
          '"messagingSenderId": "123456789012"}}',
        ),
        returnsNormally,
      );
    });
  });

  group('W6.6: generatedIdentityErrors (T-6)', () {
    const bundleId = 'com.client.app';

    void writeIdentityFixture({
      required String applicationId,
      required List<String> pbxIds,
    }) {
      Directory(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app',
      ).createSync(recursive: true);
      File(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app${Platform.pathSeparator}build.gradle.kts',
      ).writeAsStringSync('applicationId = "$applicationId"\n');
      final iosDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner.xcodeproj',
      )..createSync(recursive: true);
      final pbx = StringBuffer()
        ..writeln(
          pbxIds.map((id) => 'PRODUCT_BUNDLE_IDENTIFIER = $id;').join('\n'),
        );
      File(
        '${iosDir.path}${Platform.pathSeparator}project.pbxproj',
      ).writeAsStringSync(pbx.toString());
    }

    test('aligned identity -> no errors', () {
      writeIdentityFixture(
        applicationId: bundleId,
        pbxIds: [bundleId, '$bundleId.RunnerTests'],
      );
      expect(
        whitelabel.generatedIdentityErrors(tempDir.path, bundleId),
        isEmpty,
      );
    });

    test('applicationId drift -> error naming both ids', () {
      writeIdentityFixture(
        applicationId: 'com.client.other',
        pbxIds: [bundleId],
      );
      final errors = whitelabel.generatedIdentityErrors(tempDir.path, bundleId);
      expect(errors, hasLength(1));
      expect(errors.first, contains('com.client.other'));
      expect(errors.first, contains(bundleId));
    });

    test('pbxproj Runner drift -> error', () {
      writeIdentityFixture(
        applicationId: bundleId,
        pbxIds: ['com.client.other'],
      );
      expect(
        whitelabel.generatedIdentityErrors(tempDir.path, bundleId),
        isNotEmpty,
      );
    });

    test('pbxproj RunnerTests suffix drift -> error', () {
      writeIdentityFixture(
        applicationId: bundleId,
        pbxIds: [bundleId, 'com.client.other.RunnerTests'],
      );
      expect(
        whitelabel.generatedIdentityErrors(tempDir.path, bundleId),
        isNotEmpty,
      );
    });
  });

  group(
    'W6.6: T-6 LIVE â€” the checked-in halal_boyz shell passes the identity '
    'check',
    () {
      test('applicationId == pbxproj == app.bundleId', () {
        final appPath = Directory('../apps/halal_boyz');
        expect(appPath.existsSync(), isTrue, reason: 'repo-root sibling');
        final errors = whitelabel.generatedIdentityErrors(
          appPath.path,
          'labs.carnama.halalboys',
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    },
  );

  group('W6.6: alignPlatformIdentity rewrites gradle/pbxproj/labels', () {
    test('aligns a drifted fixture, escapes XML, and is idempotent', () {
      Directory(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app${Platform.pathSeparator}src'
        '${Platform.pathSeparator}main',
      ).createSync(recursive: true);
      Directory(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner.xcodeproj',
      ).createSync(recursive: true);
      Directory(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner',
      ).createSync(recursive: true);

      File(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app${Platform.pathSeparator}build.gradle.kts',
      ).writeAsStringSync('applicationId = "org.old.slug"\n');
      File(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app${Platform.pathSeparator}src'
        '${Platform.pathSeparator}main${Platform.pathSeparator}AndroidManifest.xml',
      ).writeAsStringSync(
        '<manifest><application android:label="old_slug">'
        '</application></manifest>\n',
      );
      File(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner.xcodeproj'
        '${Platform.pathSeparator}project.pbxproj',
      ).writeAsStringSync(
        'PRODUCT_BUNDLE_IDENTIFIER = com.old.id;\n'
        'PRODUCT_BUNDLE_IDENTIFIER = com.old.id.RunnerTests;\n',
      );
      File(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner${Platform.pathSeparator}Info.plist',
      ).writeAsStringSync(
        '<dict>\n\t<key>CFBundleDisplayName</key>\n\t<string>Old</string>\n</dict>\n',
      );

      whitelabel.alignPlatformIdentity(
        appPath: tempDir.path,
        bundleId: 'com.client.app',
        displayName: "McDonald's & Sons",
      );

      expect(
        whitelabel.generatedIdentityErrors(tempDir.path, 'com.client.app'),
        isEmpty,
      );
      final manifest = File(
        '${tempDir.path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}app${Platform.pathSeparator}src'
        '${Platform.pathSeparator}main'
        '${Platform.pathSeparator}AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="McDonald&apos;s &amp; Sons"'));
      final plist = File(
        '${tempDir.path}${Platform.pathSeparator}ios'
        '${Platform.pathSeparator}Runner${Platform.pathSeparator}Info.plist',
      ).readAsStringSync();
      expect(plist, contains('<string>McDonald&apos;s &amp; Sons</string>'));

      // Idempotent second run.
      whitelabel.alignPlatformIdentity(
        appPath: tempDir.path,
        bundleId: 'com.client.app',
        displayName: "McDonald's & Sons",
      );
      expect(
        whitelabel.generatedIdentityErrors(tempDir.path, 'com.client.app'),
        isEmpty,
      );
    });
  });

  group(
    'W6.5 mirror discipline: single-sourced shell files are byte-synced',
    () {
      test('client_config.dart shell mirror is GONE (PERF-6c, ARCH-2)', () {
        // ARCH-2 moved the shell onto the shared config engine; the
        // hand-mirrored shell file was a dead pre-ARCH-2 artifact (zero
        // importers — proven by the full shell suite passing after
        // deletion). PERF-6c deleted it; this pins its absence so the
        // stale mirror can never silently return and drift from core.
        final core = File('lib/app/config/client_config.dart');
        final shell = File('../apps/halal_boyz/lib/app/client_config.dart');
        expect(
          core.existsSync(),
          isTrue,
          reason: 'the core-side config stays the single source',
        );
        expect(
          shell.existsSync(),
          isFalse,
          reason:
              'the shell mirror was deleted (PERF-6c) — a reappearing '
              'mirror would drift from core again',
        );
      });

      // ARCH-2 architecture (recorded in its batch ledger): the OLD
      // hand-mirrored `config_validation_error_screen.dart` was DELETED from
      // the shell ("stale client_config.dart/config_validation_error_screen
      // .dart/currency_config.dart DELETED") â€” the shell's W6.5 blocking
      // screen is now the generator-emitted `lib/app/config_error_screen.dart`
      // (labs l10n, template-owned; regen proves byte-identity, ARCH-2 T-5).
      // The core-side screen remains core-owned and is exercised by
      // `client_config_schema_test.dart`.
      test('shell blocking screen is the generator-emitted config_error_screen '
          '.dart (ARCH-2)', () {
        final core = File('lib/app/config/config_validation_error_screen.dart');
        final shellScreen = File(
          '../apps/halal_boyz/lib/app/config_error_screen.dart',
        );
        expect(core.existsSync(), isTrue);
        expect(shellScreen.existsSync(), isTrue);
        expect(shellScreen.readAsStringSync(), isNotEmpty);
      });
    },
  );

  group('TOKENS: rule identity â€” generator validate() and runtime '
      'ClientConfig.fromMap reject the same malformed tokens', () {
    /// A fixture that satisfies BOTH validators: the generator's required
    /// sections AND the runtime's REQUIRED fields (theme.injection etc.),
    /// with one malformed token applied per test.
    Map<String, dynamic> bothValid() => <String, dynamic>{
      // P0-6: tenancy identity is part of the schema both validators enforce.
      'tenantId': 'halal_boyz',
      '_meta': <String, dynamic>{
        'schemaVersion': ClientConfig.supportedSchemaVersion,
      },
      'app': <String, dynamic>{
        'icon': 'app_icon.png',
        'name': 'Halal Boyz',
        'bundleId': 'labs.carnama.halalboys',
      },
      'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
      'environment': <String, dynamic>{
        'firebaseAndroidApiKey': 'AIzaSyA-real-android-key',
        'firebaseIosApiKey': 'AIzaSyA-real-ios-key',
      },
      'firebase': <String, dynamic>{'projectId': 'demo-tenant'},
      'theme': <String, dynamic>{
        'injection': ClientConfig.requiredInjectionMode,
        'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
      },
      'navigation': <String, dynamic>{'entryPoint': '/'},
      'features': <String, dynamic>{
        'flags': <String, dynamic>{'smartReorder': true},
      },
    };

    void expectBothReject(Map<String, dynamic> json, String path) {
      // Generator validate() returns the errors as a list.
      final generatorErrors = validateJson(json);
      expect(
        generatorErrors.any((e) => e.contains('"$path"')),
        isTrue,
        reason: 'generator must reject "$path", got: $generatorErrors',
      );
      // Runtime fromMap throws a ConfigException naming the same path.
      try {
        ClientConfig.fromMap(json);
        fail('runtime must reject "$path" but parsed silently');
      } on ConfigException catch (error) {
        expect(error.toString(), contains(path));
      }
    }

    test('shape.cardRadius wrong TYPE rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
        'cardRadius': '16',
      };
      expectBothReject(json, 'theme.shape.cardRadius');
    });

    test('navigationBar.activeColor invalid hex rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['components'] = <String, dynamic>{
        'navigationBar': <String, dynamic>{'activeColor': 'not-hex'},
      };
      expectBothReject(json, 'theme.components.navigationBar.activeColor');
    });

    test('animationStyle invalid enum rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['animationStyle'] = 'warp';
      expectBothReject(json, 'theme.animationStyle');
    });
    // p35 V3: the `theme.shape.style` preset. BOTH validators fail CLOSED on
    // an unknown style: the generator's validate() (a typo never ships) and
    // the runtime ClientConfig.fromMap (W6.5 parity — a typo never boots).
    // The engine itself still degrades gracefully when a theme is built
    // directly from a raw map (AppShapePreset.fromStyle -> null -> today),
    // tested in core_ui's app_shape_preset_test. The shared vocabulary is
    // pinned below so tool, runtime and engine can never drift.
    test('shape.style invalid enum rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
        'style': 'blobby',
      };
      expectBothReject(json, 'theme.shape.style');
    });

    test('shape.style valid enum accepted by both validators', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
        'style': 'round',
      };
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('theme.shape.style')),
        isFalse,
        reason: 'errors: $errors',
      );
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });

    test(
      'shape.style vocabulary: runtime, generator and core_ui AppShapePreset '
      'all pin the curated set',
      () {
        expect(ClientConfig.knownShapeStyles, AppShapePreset.vocabulary);
        expect(AppShapePreset.vocabulary, <String>{
          'sharp',
          'soft',
          'round',
          'pill',
        });
      },
    );
    // p35 scope B: the `theme.depth` preset — same fail-closed BOTH-validator
    // gate + shared-vocabulary pin as shape.style, so tool, runtime and
    // engine never drift.
    test('theme.depth invalid enum rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['depth'] = 'chunky';
      expectBothReject(json, 'theme.depth');
    });

    test('theme.depth valid enum accepted by both validators', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['depth'] = 'soft';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('theme.depth')),
        isFalse,
        reason: 'errors: $errors',
      );
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });

    test(
      'theme.depth vocabulary: runtime, generator and core_ui AppDepthPreset '
      'all pin the curated set',
      () {
        expect(ClientConfig.knownDepthStyles, AppDepthPreset.vocabulary);
        expect(AppDepthPreset.vocabulary, <String>{'flat', 'soft', 'elevated'});
      },
    );
    // Q3: the sold-out state token is engine-read, so the generator's
    // validate() must reject a malformed hex at the SAME path the runtime
    // validator names — the mirror this group exists to pin.
    test('colors.soldOut not hex rejected by both', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['colors'] = <String, dynamic>{
        'primary': '0xFF2E7D32',
        'soldOut': 'not-a-color',
      };
      expectBothReject(json, 'theme.colors.soldOut');
    });

    // Q1 mirror: the generator's validate() rejects the same out-of-set
    // closed-set style at the SAME path the runtime validator names.
    test('signature.style outside the style set rejected by both', () {
      final json = bothValid();
      (json['theme'] as Map<String, dynamic>)['signature'] = <String, dynamic>{
        'style': 'neon',
      };
      expectBothReject(json, 'theme.signature.style');
    });

    test('both validators ACCEPT a token-valid fixture', () {
      final json = bothValid();
      final theme = json['theme'] as Map<String, dynamic>;
      theme['shape'] = <String, dynamic>{'cardRadius': 12, 'ctaRadius': 100};
      theme['components'] = <String, dynamic>{
        'navigationBar': <String, dynamic>{
          'background': '0xFF1A1A1A',
          'activeColor': '0xFFFFA500',
        },
      };
      theme['animationStyle'] = 'none';
      expect(validateJson(json), isEmpty);
      expect(() => ClientConfig.fromMap(json), returnsNormally);
    });
  });

  group('PERF-5: variant vocabulary â€” generator validate() and the runtime '
      'ScreenVariants registry reject the same unknown variants', () {
    // The generator mirrors the runtime vocabulary BY DESIGN (the tool never
    // imports app lib code â€” the schemaVersion rule). First pin the
    // constants themselves, then pin both validators to the same fixtures.
    test(
      'catalog constant identity: tool == runtime ScreenVariants.catalog',
      () {
        const toolCatalog = whitelabel.ClientConfig.screenVariantCatalog;
        expect(toolCatalog.keys, ScreenVariants.catalog.keys);
        for (final entry in ScreenVariants.catalog.entries) {
          expect(
            toolCatalog[entry.key],
            entry.value,
            reason: 'variant values for "${entry.key}" must be identical',
          );
        }
      },
    );

    /// A fixture that satisfies BOTH validators (the generator's required
    /// sections AND the runtime's REQUIRED fields) â€” the variant fixtures
    /// below hang a `screens` registry off it.
    Map<String, dynamic> variantValid() => <String, dynamic>{
      'tenantId': 'halal_boyz',
      '_meta': <String, dynamic>{
        'schemaVersion': ClientConfig.supportedSchemaVersion,
      },
      'app': <String, dynamic>{
        'icon': 'app_icon.png',
        'name': 'Halal Boyz',
        'bundleId': 'labs.carnama.halalboys',
      },
      'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
      'environment': <String, dynamic>{
        'firebaseAndroidApiKey': 'AIzaSyA-real-android-key',
        'firebaseIosApiKey': 'AIzaSyA-real-ios-key',
      },
      'firebase': <String, dynamic>{'projectId': 'demo-tenant'},
      'theme': <String, dynamic>{
        'injection': ClientConfig.requiredInjectionMode,
        'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
      },
      'navigation': <String, dynamic>{'entryPoint': '/'},
      'features': <String, dynamic>{
        'flags': <String, dynamic>{'smartReorder': true},
      },
    };

    /// The generator's validate() must error naming [pathFragment]; the
    /// runtime registry must return a violation at the SAME JSON path.
    void expectBothReject(Map<String, dynamic> json, String pathFragment) {
      final generatorErrors = validateJson(json);
      expect(
        generatorErrors.any((e) => e.contains(pathFragment)),
        isTrue,
        reason: 'generator must reject "$pathFragment", got: $generatorErrors',
      );
      final violations = ScreenVariants.validateScreens(json['screens']);
      expect(
        violations.map((v) => v.path),
        contains(pathFragment.replaceAll('"', '')),
        reason: 'runtime must reject "$pathFragment", got: $violations',
      );
    }

    test('unknown variant value rejected by both', () {
      final json = variantValid();
      json['screens'] = <dynamic>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 'carousel'},
      ];
      expectBothReject(json, '"screens[0].variant"');
    });

    test('variant on a screen id outside the catalog rejected by both', () {
      final json = variantValid();
      json['screens'] = <dynamic>[
        {'id': 'MenuScreen', 'route': '/menu', 'variant': 'showcase'},
      ];
      expectBothReject(json, '"screens[0].variant"');
    });

    test('non-string variant rejected by both', () {
      final json = variantValid();
      json['screens'] = <dynamic>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 7},
      ];
      expectBothReject(json, '"screens[0].variant"');
    });

    test('valid pilot variant accepted by both', () {
      final json = variantValid();
      json['screens'] = <dynamic>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 'showcase'},
      ];
      expect(validateJson(json), isEmpty);
      expect(ScreenVariants.validateScreens(json['screens']), isEmpty);
    });

    test('absent variant key accepted by both (byte-for-byte default)', () {
      final json = variantValid();
      json['screens'] = <dynamic>[
        {'id': 'HomeScreen', 'route': '/'},
        {'id': 'MenuScreen', 'route': '/menu'},
      ];
      expect(validateJson(json), isEmpty);
      expect(ScreenVariants.validateScreens(json['screens']), isEmpty);
    });
  });

  /// UI-9 (p19) T-1: the delivery-platform vocabulary is mirrored in the
  /// generator BY DESIGN (the tool never imports app lib code) — this group
  /// pins the two validators to the SAME shared fixture, so a platform id, a
  /// credential-ref rule or a JSON path can never drift between the runtime
  /// gate and the generator gate.
  group('UI-9 (p19): deliveryPlatforms mirror', () {
    Map<String, dynamic> deliveryCases() {
      final file = File(
        'functions/test/fixtures/platform/delivery_platforms_config.json',
      );
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    test('the generator catalog mirrors DeliveryPlatforms.catalog', () {
      expect(
        whitelabel.ClientConfig.deliveryPlatformIds,
        DeliveryPlatforms.catalog,
      );
      expect(
        whitelabel.ClientConfig.deliveryForbiddenCredentialPrefixes,
        DeliveryPlatforms.forbiddenCredentialPrefixes,
      );
      expect(
        whitelabel.ClientConfig.deliveryCredentialRefPattern.pattern,
        DeliveryPlatforms.credentialRefPattern.pattern,
      );
    });

    test('both reject the same invalid cases at the same JSON paths', () {
      final cases = deliveryCases();
      for (final caseName in <String>[
        'unknown_id',
        'duplicate_id',
        'non_bool_enabled',
        'missing_store_when_enabled',
        'secret_literal',
        'not_a_list',
      ]) {
        final section =
            (cases[caseName] as Map<String, dynamic>)['deliveryPlatforms'];
        final json = validConfig()..['deliveryPlatforms'] = section;
        final generatorErrors = validateJson(json);
        final runtimePaths = DeliveryPlatforms.validatePlatforms(
          section,
        ).map((v) => v.path).toList();
        expect(
          runtimePaths,
          isNotEmpty,
          reason: '$caseName must fail the runtime validator',
        );
        for (final path in runtimePaths) {
          expect(
            generatorErrors.any((e) => e.contains('"$path"')),
            isTrue,
            reason:
                'generator must reject "$path" for $caseName, '
                'got: $generatorErrors',
          );
        }
      }
    });

    test('both accept the shared valid case and the absent section', () {
      final cases = deliveryCases();
      final valid = validConfig()
        ..['deliveryPlatforms'] =
            (cases['valid'] as Map<String, dynamic>)['deliveryPlatforms'];
      expect(validateJson(valid), isEmpty);
      expect(
        DeliveryPlatforms.validatePlatforms(valid['deliveryPlatforms']),
        isEmpty,
      );

      expect(validateJson(validConfig()), isEmpty);
      expect(DeliveryPlatforms.validatePlatforms(null), isEmpty);
    });
  });
}
