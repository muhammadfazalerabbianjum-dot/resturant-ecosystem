import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// p36 T-4 (spec `WHITE_LABEL_p36_generator_grade.md` A4/S5): icon+splash
/// stamping fails closed. A stamp without a valid `app.icon` master ships the
/// stock Flutter launcher (S5) — so `validate()` must reject: a missing key,
/// a missing file, a non-PNG, a broken PNG, and any master below 512x512.
/// The emitted YAML builders + the dev-only tool block are pinned byte-wise,
/// and BOTH shipped configs must carry a real, valid master (mirror rule).
void main() {
  late Directory tempDir;
  final repoRoot = _findRepoRoot();
  final sep = Platform.pathSeparator;

  final halalConfigPath =
      '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}'
      '$sep${'assets'}$sep${'client_config.json'}';
  final coreConfigPath =
      '${repoRoot.path}$sep${'core_app'}$sep${'assets'}'
      '$sep${'client_config.json'}';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_icon_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A syntactically-valid PNG header carrying `w`x`h` IHDR dimensions —
  /// enough for validate()'s signature+IHDR gate (the real raster work is the
  /// branding tool's job, gated separately at run time).
  List<int> fakePngBytes(int w, int h) => <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    (w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF,
    (h >> 24) & 0xFF, (h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF,
    0x08, 0x06, 0x00, 0x00, 0x00, // depth/color/interlace + padding
  ];

  /// A temp config copied from the real halal config (schema, firebase,
  /// theme all valid) with `app.icon` controlled per test.
  File tempConfig({String? icon}) {
    final raw =
        jsonDecode(File(halalConfigPath).readAsStringSync())
            as Map<String, dynamic>;
    final app = (raw['app'] as Map<String, dynamic>).cast<String, dynamic>();
    if (icon == null) {
      app.remove('icon');
    } else {
      app['icon'] = icon;
    }
    raw['app'] = app;
    final file = File('${tempDir.path}$sep${'client_config.json'}');
    file.writeAsStringSync(jsonEncode(raw));
    return file;
  }

  List<String> iconErrors(File config) {
    final errors = whitelabel.ClientConfig.load(config.path).validate();
    return errors.where((e) => e.contains('app.icon')).toList();
  }

  group('T-4: validate() fails closed on the launcher-icon master', () {
    test('missing app.icon key is an error', () {
      expect(iconErrors(tempConfig()), isNotEmpty);
    });

    test('pointing at a nonexistent file is an error', () {
      expect(iconErrors(tempConfig(icon: 'nope.png')), isNotEmpty);
    });

    test('a non-.png extension is an error', () {
      File(
        '${tempDir.path}$sep${'logo.jpg'}',
      ).writeAsBytesSync(fakePngBytes(1024, 1024));
      expect(iconErrors(tempConfig(icon: 'logo.jpg')), isNotEmpty);
    });

    test('a corrupt PNG (bad signature) is an error', () {
      File(
        '${tempDir.path}$sep${'bad.png'}',
      ).writeAsStringSync('not a png at all, really');
      expect(iconErrors(tempConfig(icon: 'bad.png')), isNotEmpty);
    });

    test('a master below 512x512 is an error', () {
      File(
        '${tempDir.path}$sep${'small.png'}',
      ).writeAsBytesSync(fakePngBytes(192, 192));
      expect(iconErrors(tempConfig(icon: 'small.png')), isNotEmpty);
    });

    test('a valid 1024x1024 PNG master passes the icon gate', () {
      File(
        '${tempDir.path}$sep${'good.png'}',
      ).writeAsBytesSync(fakePngBytes(1024, 1024));
      expect(iconErrors(tempConfig(icon: 'good.png')), isEmpty);
    });
  });

  group(
    'T-4: BOTH shipped configs carry a real valid master (mirror rule)',
    () {
      test('halal_boyz config app.icon resolves to a valid PNG >=512', () {
        final errors = iconErrors(File(halalConfigPath));
        expect(errors, isEmpty, reason: errors.join('\n'));
      });

      test(
        'core_app template config app.icon resolves to a valid PNG >=512',
        () {
          final errors = iconErrors(File(coreConfigPath));
          expect(errors, isEmpty, reason: errors.join('\n'));
        },
      );

      test('theme color getters walk NESTED paths on the real config', () {
        // _string historically only read [first, last] — a 3-level path
        // silently skipped the middle hop and the splash emitted `color: "#"`
        // (the phase-1 attestation receipt).
        final config = whitelabel.ClientConfig.load(halalConfigPath);
        expect(config.themeBackgroundColor, equals('0xFFF9F9F9'));
        expect(config.themeDarkBackgroundColor, equals('0xFF121212'));
      });
    },
  );

  group('T-4: emitted stamp configs are pinned to config-driven values', () {
    test('launcherIconsYaml pins the root key + master path + targets', () {
      final yaml = whitelabel.launcherIconsYaml(
        iconPath: 'tool/branding/app_icon.png',
      );
      // Both tools parse yaml['<tool_key>'] — a file without the root key
      // dies with NoConfigFoundException (phase-1 attestation receipt).
      expect(yaml, startsWith('flutter_launcher_icons:'));
      expect(yaml, contains('android: true'));
      expect(yaml, contains('ios: true'));
      expect(yaml, contains('image_path: "tool/branding/app_icon.png"'));
      expect(yaml, contains('min_sdk_android: 21'));
    });

    test('nativeSplashYaml converts the Dart-hex theme colors to #RRGGBB', () {
      final yaml = whitelabel.nativeSplashYaml(
        dayDartHex: '0xFFF9F9F9',
        nightDartHex: '0xFF1A1A1A',
      );
      expect(yaml, startsWith('flutter_native_splash:'));
      expect(yaml, contains('color: "#F9F9F9"'));
      expect(yaml, contains('color_dark: "#1A1A1A"'));
      expect(yaml, contains('android: true'));
      expect(yaml, contains('ios: true'));
    });

    test(
      'nativeSplashYaml falls back to the day color when dark is absent',
      () {
        final yaml = whitelabel.nativeSplashYaml(
          dayDartHex: '0xFF000000',
          nightDartHex: null,
        );
        expect(yaml, contains('color: "#000000"'));
        expect(yaml, contains('color_dark: "#000000"'));
      },
    );

    test(
      'the generatorToolDevDependencies block carries both branding tools',
      () {
        expect(
          whitelabel.generatorToolDevDependencies,
          contains('flutter_launcher_icons: ^0.14.4'),
        );
        expect(
          whitelabel.generatorToolDevDependencies,
          // 2.4.7 = newest release whose meta constraint (^1.16.0) accepts the
          // SDK-pinned meta 1.17.0; 2.4.8 needs ^1.18.0 and cannot resolve.
          contains('flutter_native_splash: ^2.4.7'),
        );
      },
    );
  });

  group('T-4: A4 wiring — template, emission, and tool gates (source pins)', () {
    final source = File(
      '${repoRoot.path}$sep${'core_app'}$sep${'tool'}$sep${'whitelabel.dart'}',
    ).readAsStringSync();

    test('the emitted pubspec template interpolates the tool block', () {
      expect(source, contains(r'${generatorToolDevDependencies}'));
    });

    test('_writeProjectFiles emits both stamp YAMLs from the builders', () {
      expect(source, contains("'flutter_launcher_icons.yaml'"));
      expect(source, contains("'flutter_native_splash.yaml'"));
      expect(source, contains('launcherIconsYaml('));
      expect(source, contains('nativeSplashYaml('));
    });

    test('run() copies the master and gates the branding tools (exit 75)', () {
      expect(source, contains('_copyBrandingAssets'));
      expect(source, contains('_runBrandingTools'));
      expect(source, contains('exit(75)'));
    });
  });
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(
      '${dir.path}${Platform.pathSeparator}WHITE_LABEL_BATCHES.md',
    ).existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
