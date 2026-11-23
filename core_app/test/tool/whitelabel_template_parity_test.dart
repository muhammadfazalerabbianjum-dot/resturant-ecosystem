import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// p36 T-2 (spec `WHITE_LABEL_p36_generator_grade.md` A2/M1, mirror rule):
/// the `core_app` TEMPLATE must carry the same stripe-gated Android posture
/// as the shipped shell â€” Material parents in every `res/values*/styles.xml`
/// and a `FlutterFragmentActivity` MainActivity â€” and the shipped
/// `apps/halal_boyz` files must stay byte-pinned to the `d76bcdd2` on-device
/// truth. A plain `@android:style/*` parent anywhere = RED (deferred p34-4).
void main() {
  final repoRoot = _findRepoRoot();
  final sep = Platform.pathSeparator;

  const lightPin = '@style/Theme.MaterialComponents.Light.NoActionBar';
  const darkPin = '@style/Theme.MaterialComponents.NoActionBar';

  Directory coreRes() => Directory(
    '${repoRoot.path}$sep${'core_app'}$sep${'android'}$sep${'app'}'
    '$sep${'src'}$sep${'main'}$sep${'res'}',
  );

  List<String> themeParents(String xml) => RegExp(
    r'parent="([^"]+)"',
  ).allMatches(xml).map((m) => m.group(1)!).toList();

  group('T-2: template + shell stripe parity (mirror rule)', () {
    test('core_app template: every values*/styles.xml parent is Material', () {
      final styleFiles = coreRes()
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split(sep).last.startsWith('values'))
          .map((d) => File('${d.path}${sep}styles.xml'))
          .where((f) => f.existsSync())
          .toList();
      expect(styleFiles, isNotEmpty, reason: 'template must ship styles');
      for (final file in styleFiles) {
        final dir = file.parent.path.split(sep).last;
        final expected = dir.contains('night') ? darkPin : lightPin;
        final parents = themeParents(file.readAsStringSync());
        expect(
          parents,
          equals([expected, expected]),
          reason:
              '${file.path} must pin $expected twice '
              '(LaunchTheme + NormalTheme)',
        );
      }
    });

    test('core_app template: MainActivity extends FlutterFragmentActivity', () {
      final kotlin = Directory(
        '${repoRoot.path}$sep${'core_app'}$sep${'android'}$sep${'app'}'
        '$sep${'src'}$sep${'main'}$sep${'kotlin'}',
      );
      final activity = kotlin
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('MainActivity.kt'));
      final text = activity.readAsStringSync();
      expect(text, contains('class MainActivity : FlutterFragmentActivity()'));
      expect(text, isNot(contains(': FlutterActivity()')));
    });

    test('halal shipped styles stay pinned to the d76bcdd2 truth', () {
      final values = File(
        '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep${'android'}'
        '$sep${'app'}$sep${'src'}$sep${'main'}$sep${'res'}$sep${'values'}'
        '$sep${'styles.xml'}',
      ).readAsStringSync();
      final night = File(
        '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep${'android'}'
        '$sep${'app'}$sep${'src'}$sep${'main'}$sep${'res'}$sep'
        '${'values-night'}$sep${'styles.xml'}',
      ).readAsStringSync();
      expect(themeParents(values), equals([lightPin, lightPin]));
      expect(themeParents(night), equals([darkPin, darkPin]));
    });

    test('halal shipped MainActivity stays FlutterFragmentActivity', () {
      final text = File(
        '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep${'android'}'
        '$sep${'app'}$sep${'src'}$sep${'main'}$sep${'kotlin'}$sep${'labs'}'
        '$sep${'carnama'}$sep${'halal_boyz'}$sep${'MainActivity.kt'}',
      ).readAsStringSync();
      expect(text, contains('class MainActivity : FlutterFragmentActivity()'));
    });
  });

  // p36 T-6 (S4-drift class, phase-1 attestation receipt
  // tool_uilib/p36/receipts/fresh_stamp_phase1c.txt â€” EMITTED TESTS FAILED):
  // the emitted demo_mode_wiring template asserted the pre-p27
  // `useAuthEmulator` while the shipped halal copy (and the REAL shared init)
  // use `usePlatformAuthEmulator` â€” every fresh stamp went red on its own
  // guard battery. Mirror rule: every `labsSource.contains(...)` pin in the
  // shipped shell test must also appear verbatim in the emitted template.
  group('T-6: emitted demo_mode_wiring template mirrors the shipped shell', () {
    final shipped = File(
      '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep${'test'}'
      '$sep${'demo_mode_wiring_test.dart'}',
    ).readAsStringSync();
    final source = File(
      '${repoRoot.path}$sep${'core_app'}$sep${'tool'}$sep${'whitelabel.dart'}',
    ).readAsStringSync();

    test('every shipped labsSource.contains pin exists in the template', () {
      final pins = RegExp(
        r'labsSource\.contains\((.+?)\),',
      ).allMatches(shipped).map((m) => m.group(0)!).toList();
      expect(pins, isNotEmpty);
      for (final pin in pins) {
        expect(
          source,
          contains(pin),
          reason: 'emitted template dropped shipped pin: $pin',
        );
      }
    });

    test('the stale pre-p27 useAuthEmulator pin is gone from the template', () {
      expect(
        source,
        contains("labsSource.contains('usePlatformAuthEmulator'),"),
      );
      expect(
        source,
        isNot(contains("labsSource.contains('useAuthEmulator'),")),
      );
    });
  });

  // p36 T-6 (D2, phase-1c receipt): flutterfire_cli gates every Apple
  // service-file write behind `Platform.isMacOS`, so a Windows host gets
  // google-services.json + firebase_options.dart but NO
  // ios/Runner/GoogleService-Info.plist â€” and the emitted
  // firebase_config_truth_test.dart then crashes loading it. The generator
  // must patch the ios fileOutput entry into the stamp's firebase.json and
  // run the cross-platform `flutterfire reconfigure` writer, fail-closed.
  group('T-6: Windows Apple-plist step is wired fail-closed', () {
    final source = File(
      '${repoRoot.path}$sep${'core_app'}$sep${'tool'}$sep${'whitelabel.dart'}',
    ).readAsStringSync();

    test('run() patches the ios entry and runs flutterfire reconfigure', () {
      expect(source, contains("'reconfigure'"));
      expect(source, contains('ios/Runner/GoogleService-Info.plist'));
      expect(source, contains('_ensureAppleServiceFiles'));
    });

    test(
      'a missing plist after reconfigure is a hard failure, not a warning',
      () {
        final ensure = RegExp(
          r'Future<void> _ensureAppleServiceFiles\(\)[\s\S]*?\n  \}',
        ).firstMatch(source);
        expect(ensure, isNotNull, reason: '_ensureAppleServiceFiles missing');
        expect(
          ensure!.group(0),
          contains('exit'),
          reason: 'must exit non-zero when the plist is still absent',
        );
        expect(ensure.group(0), isNot(contains('WARNING')));
      },
    );
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
