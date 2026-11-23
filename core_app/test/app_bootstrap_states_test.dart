// PERF-2 S1 — the ARCH-2 boot chain's failable states, exercised against the
// REAL production init sequence (no mirrors, no re-implementations):
//
//  * the W6.1 fail-closed Firebase key gate (shell policy): a placeholder
//    credential must block the boot on the caller's screen and NEVER reach
//    `Firebase.initializeApp` (evidence: the recorded platform calls stay
//    empty + the gate's own operator-facing FATAL surface);
//  * the STEP 14 fail-closed Firebase-chain policy: a thrown chain is
//    RECORDED by the logger (never silent) and blocks the shell, while the
//    template app (null builder) keeps its logged-continue semantics and
//    STILL installs the STEP 16 push bridge;
//  * the merged boot options contract: config ids win when non-empty, the
//    apiKey ALWAYS comes from the caller's generated defaults;
//  * STEP 09 (CoreConfigHolder injection) and STEP 15 (Isar open, logged)
//    both run on the real chain.
//
// HOST CONTRACT (proven empirically on this runner): `flutter test` installs
// `AutomatedTestWidgetsFlutterBinding` for plain `test()`s too — STEP 05's
// `ensureInitialized` resolves it, so STEP 16's `runApp` cannot mount a root
// (the inTest assertion throws and the chain's own try/catch contains it —
// the boot future still completes, which is itself an asserted invariant).
// The on-device boot RENDER is the emulator lane's proof (ARCH-2 boot
// verify); this suite proves every DECISION the chain makes up to that
// point. Async plugin noise from the continued boot is contained by the same
// guarded-zone pattern the production chain itself uses (STEP 02).
//
// FIX-B7 T-1 (F-W4-01) — this file used to read the machine-global
// `%TEMP%/app_logs.txt` WHOLE (`_bootLogContains`), so any leftover
// `ClientConfigLoadFailed` line — from a previous run of any suite on this
// machine, or a sibling worktree's run — turned its absence assertion red
// with no code change (`tool_fix/b7/red_flake.txt` is that seeded red).
// It now runs on the shared BootHarness, which OWNS the log generations per
// test (snapshot + clear in install(), byte-exact restore in tearDown), reads
// back ONLY the boot's own bytes, and pins the config-load contract on
// process-local state (`AppConfig.loadFailed` — the exact condition STEP 11
// keys on) instead of on shared files. Determinism law §0.7: no test outcome
// may depend on state that survives a run.

import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart';
import 'package:labs/app/config/app_config.dart';

import 'helpers/boot_env_harness.dart';

/// The shell's fail-closed blocking screen (same key vocabulary the shared
/// harness exports; kept local so this file proves the CALLER-supplied screen
/// is what the gate mounts).
const ValueKey<String> _blockedScreenKey = ValueKey<String>(
  'boot-blocked-shell-screen',
);

Widget _shellBlockingScreen() => const Scaffold(
  key: _blockedScreenKey,
  body: Text('Firebase configuration missing - contact the operator'),
);

FirebaseOptions _opts(
  String apiKey, {
  String appId = 'boot-test-default-app',
}) => FirebaseOptions(
  apiKey: apiKey,
  appId: appId,
  messagingSenderId: 'boot-test-default-sender',
  projectId: 'boot-test-default-project',
);

CarnamaBootstrap _bootstrap({
  required FirebaseOptions options,
  Widget Function()? errorScreen,
}) => CarnamaBootstrap(
  firebaseOptions: options,
  coreConfig: const DefaultCoreConfig(),
  appBuilder: () => const SizedBox.shrink(),
  firebaseErrorScreenBuilder: errorScreen,
);

void main() {
  group('firebaseKeyConfigured — the W6.1 placeholder vocabulary', () {
    test('a real key passes', () {
      expect(
        firebaseKeyConfigured(_opts('AIzaSyA1234567890abcdefghijk')),
        isTrue,
      );
    });

    test('the documented REPLACE_ME placeholder is rejected', () {
      expect(firebaseKeyConfigured(_opts('REPLACE_ME')), isFalse);
    });

    test('the vocabulary is case-insensitive', () {
      expect(firebaseKeyConfigured(_opts('Replace_Me')), isFalse);
    });

    test('changeme and <your placeholders are rejected', () {
      expect(firebaseKeyConfigured(_opts('changeme')), isFalse);
      expect(firebaseKeyConfigured(_opts('<your-api-key-here>')), isFalse);
    });

    test('an empty or whitespace key is rejected', () {
      expect(firebaseKeyConfigured(_opts('')), isFalse);
      expect(firebaseKeyConfigured(_opts('   ')), isFalse);
    });
  });

  group('pushNavigationBridge — the no-router fail-safe', () {
    test(
      'a tap arriving before the router exists is logged and ignored',
      () async {
        // activeRouter is null until a mounted CoreApp builds the router —
        // exactly the pre-mount state this guard exists for. Completing
        // without throwing IS the contract (log-and-ignore, never a crash on
        // an early notification tap).
        await pushNavigationBridge('/orders/order-1');
      },
    );
  });

  group('initCarnamaApp — the real production boot states', () {
    // ONE harness for the whole file (the recording platform + the captured
    // debugPrint surface live in test/helpers/boot_env_harness.dart, so every
    // boot test in the fleet shares ONE ownership implementation).
    // FIX-B7 T-1 (F-W4-01): install() also TAKES OWNERSHIP of the
    // machine-global boot-log generations (snapshot + clear; restore() writes
    // the bytes back), so freshBootLog() below can only ever return what THIS
    // boot wrote — never the residue that used to decide this suite's
    // outcome. ONE platform double for the whole isolate: `Firebase._delegate`
    // caches its platform resolution, so per-test replacements are silently
    // ignored; the harness's @visibleForTesting cache reset forces
    // re-resolution instead.
    final BootHarness harness = BootHarness();

    setUp(harness.install);
    tearDown(harness.restore);

    test(
      'W6.1 fail-closed: placeholder key + shell policy blocks the boot BEFORE Firebase.initializeApp',
      () async {
        await harness.runBoot(
          () => initCarnamaApp(
            bootstrap: _bootstrap(
              options: _opts('REPLACE_ME'),
              errorScreen: _shellBlockingScreen,
            ),
          ),
        );

        expect(
          harness.platform.initializeAppCalls,
          isEmpty,
          reason:
              'the W6.1 gate must never initialize Firebase with a '
              'placeholder credential',
        );
        expect(
          identical(CoreConfigHolder.instance, const DefaultCoreConfig()),
          isTrue,
          reason: 'STEP 09 ran before the gate — the caller config is injected',
        );
        expect(
          harness.debugPrintLines.join('\n'),
          contains('Firebase API key missing or placeholder'),
          reason: 'the W6.1 gate blocks with its operator-facing FATAL surface',
        );
        // FIX-B7 T-1 (F-W4-01): "the real bundled config loaded cleanly
        // (STEP 07/11)" is a PROCESS-LOCAL fact — STEP 11's never-silent
        // branch is keyed on AppConfig.loadFailed (app_bootstrap.dart
        // :545-554). Pinning the condition itself cannot be moved by any
        // shared file, so this assertion is deterministic by construction.
        expect(
          AppConfig.loadFailed,
          isFalse,
          reason:
              'the real bundled config loaded cleanly (STEP 07/11) — '
              "STEP 11's ClientConfigLoadFailed branch cannot fire",
        );
        // ...and the log evidence is read from THIS boot's OWN bytes.
        final String bootLog = await harness.freshBootLog();
        expect(
          bootLog,
          isNot(contains('ClientConfigLoadFailed')),
          reason:
              'this boot wrote no ClientConfigLoadFailed marker '
              '(owned window: ${bootLog.length} B)',
        );
      },
    );

    test('STEP 14 fail-closed: a thrown Firebase chain blocks the shell on its '
        'screen — and the merged options carry config ids over caller defaults '
        'with the apiKey from the caller', () async {
      harness.platform.throwOnInitializeApp = StateError(
        'no Firebase in test host',
      );
      const String callerKey = 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY';
      await harness.runBoot(
        () => initCarnamaApp(
          bootstrap: _bootstrap(
            options: _opts(callerKey),
            errorScreen: _shellBlockingScreen,
          ),
        ),
      );

      expect(harness.platform.initializeAppCalls, hasLength(1));
      final FirebaseOptions merged = harness.platform.initializeAppCalls.single;
      expect(
        merged.apiKey,
        callerKey,
        reason: 'the config never carries the API key — caller defaults only',
      );
      expect(
        merged.projectId,
        'boot-test-default-project',
        reason:
            'FIX-B1 T-2 / F-AUD2-05: the bundled template config carries '
            'REPLACE_ME_FIREBASE_PROJECT_ID, which is EXCLUDED from the '
            "merge - the caller's generated default is the safe fallback",
      );
      expect(
        merged.appId,
        AppConfig.firebaseAndroidAppId,
        reason: 'the test host reports android — the android app id merges',
      );
      expect(merged.messagingSenderId, AppConfig.firebaseMessagingSenderId);
      final String bootLog = await harness.freshBootLog();
      expect(
        bootLog,
        contains('FirebaseInitError'),
        reason:
            'the failed chain is recorded by the logger — never silent '
            "(this boot's own bytes: ${bootLog.length} B)",
      );
      expect(
        harness.debugPrintLines.join('\n'),
        isNot(contains('Firebase API key missing')),
        reason:
            'the real key passed the W6.1 gate — the block came from the '
            'chain failure, not the key gate',
      );
    });

    test(
      'template policy: a failed Firebase chain is logged and the boot '
      'CONTINUES — STEP 16 installs the push bridge and the real app mounts',
      () async {
        harness.platform.throwOnInitializeApp = StateError(
          'no Firebase in test host',
        );
        await harness.runBoot(
          () => initCarnamaApp(
            bootstrap: _bootstrap(
              options: _opts('AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY'),
            ),
          ),
        );

        expect(harness.platform.initializeAppCalls, hasLength(1));
        expect(
          PushNotificationService.navigationHandler,
          isNotNull,
          reason:
              'STEP 16 installs the push bridge BEFORE the runApp attempt — '
              'the boot continued past the logged-continue failure',
        );
        final String bootLog = await harness.freshBootLog();
        expect(
          bootLog,
          contains('FirebaseInitError'),
          reason:
              'template fail-OPEN semantics: the chain failure is logged, '
              'not silent',
        );
        expect(
          bootLog,
          contains('IsarInitError'),
          reason:
              'STEP 15 ran past the failure — Isar openDB attempted and its '
              'failure logged (fail-closed, never silent)',
        );
        expect(
          identical(CoreConfigHolder.instance, const DefaultCoreConfig()),
          isTrue,
          reason: 'STEP 09 injected the caller config on the continued boot',
        );
      },
    );
  });
}
