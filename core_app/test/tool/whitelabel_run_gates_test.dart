import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// p36 T-3 (spec `WHITE_LABEL_p36_generator_grade.md` A3/S2/S3): `run()` must
/// be fail-closed end-to-end. This pins the two pure decision points the
/// pipeline consults:
///
/// - `resolveStripePublishableKey`: platform env `STRIPE_PUBLISHABLE_KEY`
///   wins; otherwise a real `pk_*` config value is accepted; placeholders
///   (`REPLACE_ME`, empty) throw StateError instead of producing a debug APK
///   that boots to the fail-closed ConfigErrorScreen (p34 root cause 2).
/// - `wantsSkipFirebase`: the ONLY way past the flutterfire fail-closed gate
///   (p36 A3) â€” a failed `flutterfire configure` must never warn-and-continue.
void main() {
  group('T-3: resolveStripePublishableKey fails closed', () {
    test('platform env wins over the config value', () {
      expect(
        whitelabel.resolveStripePublishableKey(
          configValue: 'pk_test_REPLACE_ME_USE_DART_DEFINE',
          platformEnvironment: {'STRIPE_PUBLISHABLE_KEY': 'pk_test_ENV_WINS'},
        ),
        equals('pk_test_ENV_WINS'),
      );
    });

    test('valid config key is used when the env var is absent', () {
      expect(
        whitelabel.resolveStripePublishableKey(
          configValue: 'pk_test_REAL_FROM_CONFIG',
          platformEnvironment: const {},
        ),
        equals('pk_test_REAL_FROM_CONFIG'),
      );
    });

    test('empty env value falls through to a valid config key', () {
      expect(
        whitelabel.resolveStripePublishableKey(
          configValue: 'pk_test_REAL_FROM_CONFIG',
          platformEnvironment: {'STRIPE_PUBLISHABLE_KEY': ''},
        ),
        equals('pk_test_REAL_FROM_CONFIG'),
      );
    });

    test('placeholder config value + no env throws StateError', () {
      expect(
        () => whitelabel.resolveStripePublishableKey(
          configValue: 'pk_test_REPLACE_ME_USE_DART_DEFINE',
          platformEnvironment: const {},
        ),
        throwsStateError,
      );
    });

    test('empty config value + no env throws StateError', () {
      expect(
        () => whitelabel.resolveStripePublishableKey(
          configValue: '',
          platformEnvironment: const {},
        ),
        throwsStateError,
      );
    });
  });

  group('T-3: --skip-firebase flag', () {
    test('present -> true (the explicit flutterfire opt-out)', () {
      expect(
        whitelabel.wantsSkipFirebase(['--config', 'x.json', '--skip-firebase']),
        isTrue,
      );
    });

    test('absent -> false (flutterfire runs and is fail-closed)', () {
      expect(whitelabel.wantsSkipFirebase(['--config', 'x.json']), isFalse);
    });
  });

  group('T-5 (S7): workspace registration is unconditional', () {
    // The pre-p36 run() guarded registration behind `!appDir.existsSync()` â€”
    // dead code, because flutter create already made the directory. Fresh
    // stamps therefore never joined the workspace and `flutter pub get`
    // failed with `resolution: workspace` + no workspace root (the phase-1
    // attestation receipt). The dead guard must not come back.
    test(
      'run() registers the workspace entry and keys melos on the result',
      () {
        final root = _findRepoRoot();
        final sep = Platform.pathSeparator;
        final source = File(
          '${root.path}${sep}core_app${sep}tool${sep}whitelabel.dart',
        ).readAsStringSync();
        expect(
          source,
          contains('final workspaceChanged = _registerWorkspacePackage();'),
        );
        expect(source, contains('if (workspaceChanged)'));
        expect(
          source,
          isNot(
            contains(
              'if (!appDir.existsSync()) {\n      _registerWorkspacePackage();',
            ),
          ),
        );
      },
    );

    test('router harness template drops the post-p27 redundant firebase_auth '
        'import (the analyze gate caught it live: unnecessary_import)', () {
      final root = _findRepoRoot();
      final sep = Platform.pathSeparator;
      final source = File(
        '${root.path}${sep}core_app${sep}tool${sep}whitelabel.dart',
      ).readAsStringSync();
      // p27 made `package:core/core.dart` re-export User/FirebaseAuth â€” the
      // shipped halal harness imports only core; the template must match or
      // every fresh stamp fails `flutter analyze --fatal-infos` (exit 70,
      // phase-1 attestation receipt).
      expect(
        source,
        isNot(contains("import 'package:firebase_auth/firebase_auth.dart'")),
      );
    });
  });

  group(
    'T-8 (S8): the stripe styles gate is the LAST writer after branding',
    () {
      // Attestation L red: `_runBrandingTools()` (flutter_native_splash
      // `[Android] Updating styles...`) rewrites values-v31/styles.xml AFTER
      // the aligner ran, re-introducing stock `@android:style/*` parents.
      // The rebuilt stamp then dies in flutter_stripe on API-31+ devices and
      // boots the fail-closed ConfigErrorScreen. The aligner must run again
      // after branding, or the gate is decorative.
      test('run() re-runs alignStripeAndroidGate after _runBrandingTools', () {
        final root = _findRepoRoot();
        final sep = Platform.pathSeparator;
        final source = File(
          '${root.path}${sep}core_app${sep}tool${sep}whitelabel.dart',
        ).readAsStringSync();
        const alignCalls = 'alignStripeAndroidGate(appPath: appPath);';
        const branding = 'await _runBrandingTools();';
        expect(source.contains(alignCalls), isTrue);
        final lastAlign = source.lastIndexOf(alignCalls);
        final brandingAt = source.indexOf(branding);
        expect(
          brandingAt,
          greaterThan(0),
          reason: 'branding step must exist in run()',
        );
        expect(
          lastAlign,
          greaterThan(brandingAt),
          reason:
              'the final alignStripeAndroidGate call must come after '
              '_runBrandingTools so flutter_native_splash cannot leave stock '
              'values-v31 parents behind (S8)',
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
