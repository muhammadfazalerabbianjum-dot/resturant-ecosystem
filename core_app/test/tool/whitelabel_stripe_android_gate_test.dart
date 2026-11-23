import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// p36 T-1 (spec `WHITE_LABEL_p36_generator_grade.md` A1/S1): the generator
/// must gate the two `flutter create` Android files flutter_stripe rejects —
/// `MainActivity.kt` (`FlutterActivity` -> `FlutterFragmentActivity`) and every
/// `res/values*/styles.xml` (plain `@android:style/*` parents ->
/// `Theme.MaterialComponents*` pins) — using the proven aligner contract:
///
/// - stock baseline -> pinned shipped bytes (the `d76bcdd2` on-device truth),
/// - second run byte-identical (idempotent),
/// - half-applied or unrecognized shape -> StateError (fail-closed).
void main() {
  late Directory tempDir;
  late Directory repoRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_stripe_gate_');
    repoRoot = _findRepoRoot();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final sep = Platform.pathSeparator;
  const stockActivity = '''
package com.scratch.client

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''';

  String stockStyles(String parent) =>
      '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="$parent">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="$parent">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''';

  Directory scratchAndroidApp() {
    final app = Directory('${tempDir.path}${sep}scratch_app');
    final activity = File(
      '${app.path}${sep}android${sep}app${sep}src${sep}main${sep}kotlin'
      '${sep}com${sep}scratch${sep}client${sep}MainActivity.kt',
    );
    activity.parent.createSync(recursive: true);
    activity.writeAsStringSync(stockActivity);
    final values = File(
      '${app.path}${sep}android${sep}app${sep}src${sep}main${sep}res'
      '${sep}values${sep}styles.xml',
    );
    values.parent.createSync(recursive: true);
    values.writeAsStringSync(
      stockStyles('@android:style/Theme.Light.NoTitleBar'),
    );
    final night = File(
      '${app.path}${sep}android${sep}app${sep}src${sep}main${sep}res'
      '${sep}values-night${sep}styles.xml',
    );
    night.parent.createSync(recursive: true);
    night.writeAsStringSync(
      stockStyles('@android:style/Theme.Black.NoTitleBar'),
    );
    return app;
  }

  String activityPath(Directory app) =>
      '${app.path}$sep${'android'}$sep${'app'}$sep${'src'}$sep${'main'}'
      '$sep${'kotlin'}$sep${'com'}$sep${'scratch'}$sep${'client'}'
      '$sep${'MainActivity.kt'}';

  String valuesPath(Directory app, String dir) =>
      '${app.path}$sep${'android'}$sep${'app'}$sep${'src'}$sep${'main'}'
      '$sep${'res'}$sep$dir$sep${'styles.xml'}';

  group(
    'T-1: alignStripeAndroidGate gates the stock flutter create baseline',
    () {
      test(
        'MainActivity lands on the shipped FlutterFragmentActivity bytes',
        () {
          final app = scratchAndroidApp();
          whitelabel.alignStripeAndroidGate(appPath: app.path);
          final gated = File(activityPath(app)).readAsStringSync();
          final shipped = File(
            '${repoRoot.path}$sep${'apps'}$sep${'halal_boyz'}$sep${'android'}'
            '$sep${'app'}$sep${'src'}$sep${'main'}$sep${'kotlin'}$sep${'labs'}'
            '$sep${'carnama'}$sep${'halal_boyz'}$sep${'MainActivity.kt'}',
          ).readAsStringSync();
          // The package line and EOL style are project-specific by design; the
          // gated import + class lines must equal the shipped on-device truth
          // byte-for-byte.
          List<String> gatedSignature(String text) => text
              .split(RegExp(r'\r?\n'))
              .where(
                (line) =>
                    line.contains('io.flutter.embedding.android.Flutter') ||
                    line.startsWith('class MainActivity'),
              )
              .toList();
          expect(gatedSignature(gated), equals(gatedSignature(shipped)));
          expect(gated, isNot(contains('android.FlutterActivity\n')));
        },
      );

      test('values parents land on the shipped Material pins', () {
        final app = scratchAndroidApp();
        whitelabel.alignStripeAndroidGate(appPath: app.path);
        final values = File(valuesPath(app, 'values')).readAsStringSync();
        final night = File(valuesPath(app, 'values-night')).readAsStringSync();
        final lightCount =
            values.split('Theme.MaterialComponents.Light.NoActionBar').length -
            1;
        final nightCount =
            night.split('Theme.MaterialComponents.NoActionBar').length - 1;
        expect(
          lightCount,
          equals(2),
          reason: 'LaunchTheme + NormalTheme pinned',
        );
        expect(
          nightCount,
          equals(2),
          reason: 'LaunchTheme + NormalTheme pinned',
        );
        expect(values, isNot(contains('@android:style')));
        expect(night, isNot(contains('@android:style')));
      });

      test('second run is a byte-identical no-op (idempotent)', () {
        final app = scratchAndroidApp();
        whitelabel.alignStripeAndroidGate(appPath: app.path);
        final first = <String, String>{
          activityPath(app): File(activityPath(app)).readAsStringSync(),
          valuesPath(app, 'values'): File(
            valuesPath(app, 'values'),
          ).readAsStringSync(),
          valuesPath(app, 'values-night'): File(
            valuesPath(app, 'values-night'),
          ).readAsStringSync(),
        };
        whitelabel.alignStripeAndroidGate(appPath: app.path);
        for (final entry in first.entries) {
          expect(
            File(entry.key).readAsStringSync(),
            equals(entry.value),
            reason: '${entry.key} must be byte-untouched on the second run',
          );
        }
      });

      test('unrecognized MainActivity shape fails closed with StateError', () {
        final app = scratchAndroidApp();
        File(activityPath(app)).writeAsStringSync(
          'package com.scratch.client\n\n'
          'import androidx.appcompat.app.AppCompatActivity\n\n'
          'class MainActivity : AppCompatActivity()\n',
        );
        expect(
          () => whitelabel.alignStripeAndroidGate(appPath: app.path),
          throwsStateError,
        );
      });

      test('half-applied styles (one gated parent, one stock) fail closed', () {
        final app = scratchAndroidApp();
        // LaunchTheme already gated, NormalTheme still stock = half-applied.
        File(valuesPath(app, 'values')).writeAsStringSync(
          stockStyles('@android:style/Theme.Light.NoTitleBar').replaceFirst(
            '@android:style/Theme.Light.NoTitleBar',
            '@style/Theme.MaterialComponents.Light.NoActionBar',
          ),
        );
        expect(
          () => whitelabel.alignStripeAndroidGate(appPath: app.path),
          throwsStateError,
        );
      });

      test('missing MainActivity fails closed with StateError', () {
        final app = scratchAndroidApp();
        File(activityPath(app)).deleteSync();
        expect(
          () => whitelabel.alignStripeAndroidGate(appPath: app.path),
          throwsStateError,
        );
      });
    },
  );
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
