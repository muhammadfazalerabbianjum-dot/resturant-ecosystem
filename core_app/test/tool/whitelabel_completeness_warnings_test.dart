import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// Resolves the real Dart SDK binary.
///
/// Under `flutter test` the test runs inside `flutter_tester.exe`, so
/// [Platform.resolvedExecutable] is NOT a Dart VM and passing it to
/// [Process.run] hangs forever (p25 T-1 found this the hard way). Walk up to
/// the SDK's `dart-sdk/bin/dart.exe`; fail loudly rather than hang.
String _dartExecutable() {
  final resolved = File(Platform.resolvedExecutable);
  final fileName = resolved.path.split(Platform.pathSeparator).last;
  if (fileName == 'dart.exe' || fileName == 'dart') return resolved.path;

  Directory dir = resolved.parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${dir.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}dart.exe',
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('p25 T-1: no dart executable found from ${resolved.path}');
}

/// UI-14 (p25) T-1 — F-8 completeness WARNINGS.
///
/// Law L-P1: a completeness finding is a warning, never an error. It must not
/// fail a generation that succeeds today, and it must not change an emitted
/// byte. These tests cover the three halves of that contract:
///   1. the warnings channel reports unset engine-read visual keys,
///   2. `validate()`'s ERROR list is byte-identical with or without the sink,
///   3. the real generator still exits 0 on a config that carries warnings.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('p25_completeness_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File writeConfig(Map<String, dynamic> json) {
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
    return file;
  }

  /// A schema-valid config whose theme block carries EVERY engine-read visual
  /// key (see `AppTheme._themeFromConfig` / `_brandColorsFor`).
  Map<String, dynamic> completeConfig() => <String, dynamic>{
    '_meta': <String, dynamic>{'schemaVersion': '1.0.0'},
    'app': <String, dynamic>{
      'icon': 'app_icon.png',
      'name': 'Warning Probe',
      'bundleId': 'labs.carnama.warningprobe',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': 'AIzaSyA-real-android-key',
      'firebaseIosApiKey': 'AIzaSyA-real-ios-key',
    },
    'firebase': <String, dynamic>{'projectId': 'warning-probe-c1604'},
    'navigation': <String, dynamic>{'entryPoint': '/'},
    'features': <String, dynamic>{
      'source': 'settings/featureFlags',
      'flags': <String, dynamic>{'smartReorder': true},
      'unknownFlagDefault': false,
    },
    'theme': <String, dynamic>{
      'typography': <String, dynamic>{
        'fontFamily': 'System',
        'headingFont': 'System',
        'bodyFont': 'System',
      },
      'shape': <String, dynamic>{
        'cardRadius': 16.0,
        'ctaRadius': 100.0,
        'smallRadius': 8.0,
      },
      'components': <String, dynamic>{
        'navigationBar': <String, dynamic>{
          'background': '0xFF1A1A1A',
          'activeColor': '0xFFFFA500',
        },
        'input': <String, dynamic>{
          'fillColor': '0xFFFFFFFF',
          'borderColor': '0xFF900000',
          'radius': 8.0,
        },
        'chip': <String, dynamic>{'radius': 100.0},
      },
      'background': <String, dynamic>{
        'color': '0xFFF9F9F9',
        'overlayAsset': 'assets/backdrop/city_map.png',
      },
      'animationStyle': 'full',
      'colors': <String, dynamic>{
        'primary': '0xFF900000',
        'secondary': '0xFFFFA500',
        'accent': '0xFFFFA500',
        'background': '0xFFF9F9F9',
        'surface': '0xFFFFFFFF',
        'textPrimary': '0xFF111111',
        'textSecondary': '0xFF666666',
        'error': '0xFFE60000',
        'success': '0xFF2E7D32',
        'warning': '0xFFFFC107',
        'soldOut': '0xFF616161',
        'textPrimary12': '0x1F111111',
      },
      'darkTheme': <String, dynamic>{
        'background': '0xFF121212',
        'surface': '0xFF1E1E1E',
      },
    },
  };

  /// The same config with `theme.components.input.*` nulled out and
  /// `theme.animationStyle` removed — the F-8 gap this batch repairs.
  Map<String, dynamic> incompleteConfig() {
    final json = completeConfig();
    final theme = json['theme'] as Map<String, dynamic>;
    (theme['components'] as Map<String, dynamic>)['input'] = <String, dynamic>{
      'fillColor': null,
      'borderColor': null,
      'radius': null,
    };
    theme.remove('animationStyle');
    return json;
  }

  group('T-1: completeness warnings are warnings, not errors (L-P1)', () {
    test('an unset engine-read visual key produces the named warning', () {
      final config = whitelabel.ClientConfig.load(
        writeConfig(incompleteConfig()).path,
      );
      final warnings = <String>[];
      final errors = config.validate(warnings: warnings);

      expect(
        errors,
        isEmpty,
        reason:
            'a completeness finding must NEVER become an error (L-P1); '
            'got errors: $errors',
      );
      expect(
        warnings,
        contains(
          'WARNING: theme.components.input.* unset — Material default will '
          'render',
        ),
        reason: 'the F-8 gap must be reported by name, got: $warnings',
      );
      expect(
        warnings,
        contains(
          'WARNING: theme.animationStyle unset — the full-motion default will '
          'render',
        ),
        reason: 'the removed key must be reported too, got: $warnings',
      );
    });

    test('a complete config produces no warnings at all', () {
      final config = whitelabel.ClientConfig.load(
        writeConfig(completeConfig()).path,
      );
      final warnings = <String>[];
      final errors = config.validate(warnings: warnings);

      expect(errors, isEmpty, reason: 'got errors: $errors');
      expect(
        warnings,
        isEmpty,
        reason: 'nothing is unset, so nothing may be reported: $warnings',
      );
    });

    test('the warnings sink leaves the ERROR list byte-identical', () {
      for (final json in <Map<String, dynamic>>[
        completeConfig(),
        incompleteConfig(),
      ]) {
        final file = writeConfig(json);
        final withoutSink = whitelabel.ClientConfig.load(file.path).validate();
        final sink = <String>[];
        final withSink = whitelabel.ClientConfig.load(
          file.path,
        ).validate(warnings: sink);

        expect(
          withSink,
          equals(withoutSink),
          reason:
              'L-P1: adding the warnings channel must not move a single '
              'error string — without: $withoutSink / with: $withSink',
        );
      }
    });

    test(
      'the real generator dry-run PRINTS the warning and still exits 0',
      () async {
        final file = writeConfig(incompleteConfig());
        final dart = _dartExecutable();
        final result = await Process.run(
          dart,
          <String>[
            'run',
            'tool/whitelabel.dart',
            '--config',
            file.path,
            '--dry-run',
          ],
          workingDirectory: Directory.current.path,
        ).timeout(const Duration(minutes: 2));
        final out = result.stdout.toString();

        expect(
          result.exitCode,
          0,
          reason:
              'warnings must never change the exit code (L-P1). dart: $dart\n'
              'stderr: ${result.stderr}',
        );
        expect(
          out,
          contains('WARNING: theme.components.input.* unset'),
          reason: 'the operator must SEE the warning. stdout:\n$out',
        );
        expect(out, contains('DRY RUN - no files were modified.'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
