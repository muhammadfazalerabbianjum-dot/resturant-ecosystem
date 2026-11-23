import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// WL-1 (W6.1/W6.2): the generator's `validate()` is the fail-closed gate for
/// every generated shell. These tests run the REAL validator on REAL config
/// fixtures written to a temp dir, plus the REAL repo config assets.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_validate_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// A syntactically-valid 1024x1024 PNG master next to the temp config —
  /// validate() requires `app.icon` to resolve to a real PNG >=512 (p36 T-4).
  void writeFakeIcon() {
    File(
      '${tempDir.path}${Platform.pathSeparator}app_icon.png',
    ).writeAsBytesSync(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00, // 512x512
      0x08, 0x06, 0x00, 0x00, 0x00, // depth/color/interlace
    ]);
  }

  /// Writes [json] to a temp file (plus the required synthetic icon master)
  /// and runs the real validator on it.
  List<String> validateJson(Map<String, dynamic> json) {
    final file = File('${tempDir.path}${Platform.pathSeparator}config.json');
    file.writeAsStringSync(jsonEncode(json));
    writeFakeIcon();
    return whitelabel.ClientConfig.load(file.path).validate();
  }

  Map<String, dynamic> validConfig() => <String, dynamic>{
    // W6.4(4)/(5): a schema-valid config now also carries the pinned
    // _meta.schemaVersion and a required currency section.
    // P0-6: and the tenant identity the fleet will key on.
    'tenantId': 'halal_boyz',
    '_meta': <String, dynamic>{'schemaVersion': '1.0.0'},
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
      'source': 'settings/featureFlags',
      'flags': <String, dynamic>{'smartReorder': true, 'loyaltyPoints': true},
      'unknownFlagDefault': false,
    },
  };

  // ADR-01 (P0-10): mirror of the runtime gate — optional, type-checked.
  group('ADR-01: optional card-present payment fields', () {
    test('absent fields produce no errors', () {
      expect(validateJson(validConfig()), isEmpty);
    });

    test('stripeAccountId and per-branch terminalLocationId are accepted', () {
      final json = validConfig()
        ..['stripeAccountId'] = 'acct_1Example'
        ..['branches'] = <String, dynamic>{
          'defaultBranchId': 'main',
          'main': <String, dynamic>{'terminalLocationId': 'tml_123'},
        };
      expect(validateJson(json), isEmpty);
    });

    test('non-string stripeAccountId is refused', () {
      final json = validConfig()..['stripeAccountId'] = 42;
      expect(
        validateJson(json).any((String e) => e.contains('stripeAccountId')),
        isTrue,
      );
    });

    test('non-string branch terminalLocationId is refused', () {
      final json = validConfig()
        ..['branches'] = <String, dynamic>{
          'main': <String, dynamic>{'terminalLocationId': 7},
        };
      expect(
        validateJson(
          json,
        ).any((String e) => e.contains('branches.main.terminalLocationId')),
        isTrue,
      );
    });
  });

  group('T-1: validate() rejects empty/placeholder Firebase credentials', () {
    test(
      'empty android key -> error naming environment.firebaseAndroidApiKey',
      () {
        final json = validConfig();
        (json['environment'] as Map<String, dynamic>)['firebaseAndroidApiKey'] =
            '';
        final errors = validateJson(json);
        expect(
          errors.any((e) => e.contains('"environment.firebaseAndroidApiKey"')),
          isTrue,
          reason: 'the error must name the exact JSON path, got: $errors',
        );
      },
    );

    test('placeholder android key is rejected (case-insensitive)', () {
      for (final placeholder in <String>[
        'REPLACE_ME_KEY',
        'changeme',
        '<your key here>',
        'Replace_Me',
      ]) {
        final json = validConfig();
        (json['environment'] as Map<String, dynamic>)['firebaseAndroidApiKey'] =
            placeholder;
        final errors = validateJson(json);
        expect(
          errors.any((e) => e.contains('"environment.firebaseAndroidApiKey"')),
          isTrue,
          reason: '"$placeholder" must be rejected, got: $errors',
        );
      }
    });

    test('empty ios key -> error naming environment.firebaseIosApiKey', () {
      final json = validConfig();
      (json['environment'] as Map<String, dynamic>)['firebaseIosApiKey'] = '';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"environment.firebaseIosApiKey"')),
        isTrue,
        reason: 'the error must name the exact JSON path, got: $errors',
      );
    });

    test('placeholder ios key is rejected', () {
      final json = validConfig();
      (json['environment'] as Map<String, dynamic>)['firebaseIosApiKey'] =
          'REPLACE_ME_IOS_KEY';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"environment.firebaseIosApiKey"')),
        isTrue,
        reason: '$errors',
      );
    });

    test('empty projectId -> error naming firebase.projectId', () {
      final json = validConfig();
      (json['firebase'] as Map<String, dynamic>)['projectId'] = '';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"firebase.projectId"')),
        isTrue,
        reason: 'the error must name the exact JSON path, got: $errors',
      );
    });

    test('placeholder projectId is rejected', () {
      final json = validConfig();
      (json['firebase'] as Map<String, dynamic>)['projectId'] =
          'REPLACE_ME_PROJECT';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"firebase.projectId"')),
        isTrue,
        reason: '$errors',
      );
    });

    test('fully valid config produces no errors', () {
      expect(validateJson(validConfig()), isEmpty);
    });

    test(
      'the real template config (core_app/assets) is REJECTED while it still '
      'carries documented placeholders (fail-closed template)',
      () {
        final template = File('assets/client_config.json');
        expect(
          template.existsSync(),
          isTrue,
          reason: 'run from core_app: assets/client_config.json must exist',
        );
        final config = whitelabel.ClientConfig.load(template.absolute.path);
        final errors = config.validate();
        expect(
          errors.any((e) => e.contains('"environment.firebaseAndroidApiKey"')),
          isTrue,
          reason: 'template must document placeholder keys: $errors',
        );
        expect(
          errors.any((e) => e.contains('"environment.firebaseIosApiKey"')),
          isTrue,
          reason: 'template must document placeholder keys: $errors',
        );
        expect(
          errors.any((e) => e.contains('"firebase.projectId"')),
          isTrue,
          reason: 'template must document a placeholder project id: $errors',
        );
      },
    );
  });

  group('T-2: validate() rejects object-valued flags (W6.2)', () {
    test('{"flag":{"enabled":true}} -> error naming features.flags', () {
      final json = validConfig();
      (json['features'] as Map<String, dynamic>)['flags'] = <String, dynamic>{
        'smartReorder': <String, dynamic>{'enabled': true},
      };
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"features.flags"')),
        isTrue,
        reason: 'object-valued flags must fail generation, got: $errors',
      );
    });

    test('empty flags map -> error', () {
      final json = validConfig();
      (json['features'] as Map<String, dynamic>)['flags'] = <String, dynamic>{};
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"features.flags"')),
        isTrue,
        reason: 'an empty flag map must fail generation, got: $errors',
      );
    });

    test('missing flags key -> error', () {
      final json = validConfig();
      (json['features'] as Map<String, dynamic>).remove('flags');
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"features.flags"')),
        isTrue,
        reason: 'missing flags must fail generation, got: $errors',
      );
    });

    test('non-empty all-bool flags pass', () {
      expect(validateJson(validConfig()), isEmpty);
    });
  });

  group('T-4: both real repo configs carry flattened non-empty bool flags', () {
    void expectFlagsAreBool(Map<String, dynamic> json, String label) {
      final features = json['features'] as Map<String, dynamic>;
      final flags = features['flags'];
      expect(flags, isA<Map<String, dynamic>>(), reason: label);
      final map = flags as Map<String, dynamic>;
      expect(map, isNotEmpty, reason: label);
      for (final entry in map.entries) {
        expect(
          entry.value,
          isA<bool>(),
          reason: '$label: flag "${entry.key}" must be a bool',
        );
      }
    }

    test('core_app template config', () {
      final file = File('assets/client_config.json');
      expect(file.existsSync(), isTrue);
      expectFlagsAreBool(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        'core_app/assets/client_config.json',
      );
    });

    test('halal_boyz generated config', () {
      final file = File('../apps/halal_boyz/assets/client_config.json');
      expect(file.existsSync(), isTrue);
      expectFlagsAreBool(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        'apps/halal_boyz/assets/client_config.json',
      );
    });
  });

  group('TOKENS: generator validate() rejects malformed design tokens', () {
    test('shape.cardRadius non-numeric -> error naming the path', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
        'cardRadius': '16',
      };
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"theme.shape.cardRadius"')),
        isTrue,
        reason: 'got: $errors',
      );
    });

    test('shape.ctaRadius negative -> error', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['shape'] = <String, dynamic>{
        'ctaRadius': -4,
      };
      final errors = validateJson(json);
      expect(errors.any((e) => e.contains('"theme.shape.ctaRadius"')), isTrue);
    });

    test('navigationBar.activeColor not hex -> error', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['components'] = <String, dynamic>{
        'navigationBar': <String, dynamic>{'activeColor': 'maroon'},
      };
      final errors = validateJson(json);
      expect(
        errors.any(
          (e) => e.contains('"theme.components.navigationBar.activeColor"'),
        ),
        isTrue,
        reason: 'got: $errors',
      );
    });

    test('background.overlayAsset absolute path -> error', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['background'] = <String, dynamic>{
        'overlayAsset': '/etc/city_map.png',
      };
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"theme.background.overlayAsset"')),
        isTrue,
        reason: 'got: $errors',
      );
    });

    test('animationStyle invalid enum -> error', () {
      final json = validConfig();
      (json['theme'] as Map<String, dynamic>)['animationStyle'] = 'extreme';
      final errors = validateJson(json);
      expect(
        errors.any((e) => e.contains('"theme.animationStyle"')),
        isTrue,
        reason: 'got: $errors',
      );
    });

    test('token-valid config passes generation validation', () {
      final json = validConfig();
      final theme = json['theme'] as Map<String, dynamic>;
      theme['shape'] = <String, dynamic>{'cardRadius': 12, 'ctaRadius': 100};
      theme['components'] = <String, dynamic>{
        'navigationBar': <String, dynamic>{
          'background': '0xFF1A1A1A',
          'activeColor': '0xFFFFA500',
        },
      };
      theme['animationStyle'] = 'subtle';
      expect(validateJson(json), isEmpty);
    });
  });
}
