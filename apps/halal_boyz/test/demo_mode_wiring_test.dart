import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halal_boyz/app/core_config_adapter.dart';
import 'package:halal_boyz/app/demo_config.dart' show kDemoMode;

/// OPS-CONFIG-1 ADDENDUM-D wiring guard.
///
/// The free-plan demo (no Cloud Functions deployed — Firebase Spark plan)
/// rides on two build-time defines:
///   * `--dart-define=DEMO_MODE=true` — the local Dart mocks in packages/core
///     route on `CoreConfigHolder.instance.isDemoMode` (orders written
///     directly to Firestore, Stripe simulated, GDPR client-side).
///   * `--dart-define=USE_EMULATORS=true` — Firestore+Auth wired to the local
///     Firebase Emulator Suite for the fully-local loop (DEMO_PHASE0_LOG.md).
///
/// ARCH-2 moved the entire init into the SHARED `initCarnamaApp`
/// (`package:labs` `app_bootstrap.dart`) — the emulator wiring, the
/// safe-build release guard, and the platform-aware hosts live there now,
/// so this guard asserts the SHARED source plus the shell's per-project
/// `firebase_options.dart`.
void main() {
  final packageRoot = Directory.current.path;
  final labsSource = File(
    '$packageRoot/../../core_app/lib/app_bootstrap.dart',
  ).readAsStringSync();

  test('kDemoMode defaults to false (production) without the define', () {
    expect(kDemoMode, isFalse);
  });

  test('adapter mirrors kDemoMode instead of the old hardcoded false', () {
    const config = ClientCoreConfig(<String, dynamic>{
      'app': <String, dynamic>{'bundleId': 'labs.carnama.halalboys'},
    });
    expect(config.isDemoMode, kDemoMode);
  });

  test('boot wiring contract: safe-build guard + emulator hooks in the SHARED '
      'init (app_bootstrap.dart)', () {
    expect(
      labsSource.contains('_assertSafeBuildConfig'),
      isTrue,
      reason: 'release+DEMO_MODE boot rejection missing from the shared init',
    );
    expect(
      labsSource.contains('usePlatformAuthEmulator'),
      isTrue,
      reason: 'Auth emulator wiring missing from the shared init',
    );
    expect(
      labsSource.contains('useFirestoreEmulator'),
      isTrue,
      reason: 'Firestore emulator wiring missing from the shared init',
    );
    expect(
      labsSource.contains("bool.fromEnvironment('USE_EMULATORS')"),
      isTrue,
      reason: 'USE_EMULATORS gate missing from the shared init',
    );
    expect(
      labsSource.contains('10.0.2.2'),
      isTrue,
      reason: 'platform-aware Android emulator host missing',
    );
    expect(
      labsSource.contains("String.fromEnvironment('EMULATOR_HOST')"),
      isTrue,
      reason: 'physical-device override (EMULATOR_HOST) missing',
    );
  });

  test('the shell main is a THIN wrapper that calls the shared init', () {
    final mainSource = File('$packageRoot/lib/main.dart').readAsStringSync();
    expect(
      mainSource.contains('initCarnamaApp'),
      isTrue,
      reason: 'the shell boot must route through the shared initCarnamaApp',
    );
    expect(
      mainSource.contains('Firebase.initializeApp('),
      isFalse,
      reason: 'no duplicate init path may live in the shell main',
    );
  });

  test('the shell carries its OWN per-project firebase_options.dart', () {
    final optionsSource = File(
      '$packageRoot/lib/firebase_options.dart',
    ).readAsStringSync();
    expect(
      optionsSource.contains('class DefaultFirebaseOptions'),
      isTrue,
      reason: 'the shell needs its own DefaultFirebaseOptions (ARCH-2)',
    );
    expect(
      optionsSource.contains('TargetPlatform.android'),
      isTrue,
      reason: 'the emitted options must cover android',
    );
    expect(
      optionsSource.contains('TargetPlatform.iOS'),
      isTrue,
      reason: 'the emitted options must cover ios',
    );
  });

  test('demo_config.dart keeps the DEMO_MODE dart-define contract', () {
    final source = File(
      '$packageRoot/lib/app/demo_config.dart',
    ).readAsStringSync();
    expect(
      source.contains("bool.fromEnvironment('DEMO_MODE', defaultValue: false)"),
      isTrue,
      reason: 'kDemoMode must stay a build-time define defaulting to false',
    );
  });
}
