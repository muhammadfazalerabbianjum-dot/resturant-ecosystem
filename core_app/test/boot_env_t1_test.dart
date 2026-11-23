// FIX-B1 T-1 (F-AUD2-01, CRITICAL) — the template's env step (STEP 06) with
// `loadEnv: true` and NO `.env` bundled asset must degrade GRACEFULLY:
//
// At HEAD the non-optional `dotenv.load()` threw FileNotFoundError and the
// whole boot aborted through handleBootFailure BEFORE runApp — the CRITICAL
// this batch fixes (RED proof: tool_fix/b1/red_t1.txt).
//
// The green contract (spec §3 T-1):
//  * no throw — the boot reaches STEP 16;
//  * ABSENCE IS EXPLICIT — an EnvFileMissing marker documents the precedence
//    `.env -> --dart-define -> config`;
//  * NOTHING is fabricated — the dotenv layer stays empty;
//  * absent security keys stay FAIL-CLOSED (never a permissive default).
//
// Everything runs against the REAL production initCarnamaApp chain (shared
// harness: test/helpers/boot_env_harness.dart) — no mirrors.
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart';

import 'helpers/boot_env_harness.dart';

void main() {
  final BootHarness harness = BootHarness();

  // ONE boot for the whole file (setUpAll): every assertion below observes
  // the SAME template-policy boot, and a second same-isolate boot would hit
  // the test-host IsarService double-open hang at STEP 15 (the first open
  // fails with the workmanager MissingPlugin; the memoized future never
  // settles again). At HEAD this single boot still dies at STEP 06, so all
  // four assertions fail exactly as the RED capture shows
  // (tool_fix/b1/red_t1.txt).
  setUpAll(() async {
    await harness.install();
    await harness.runBoot(
      () => initCarnamaApp(
        bootstrap: bootstrapFor(
          options: bootOptions(apiKey: 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY'),
          loadEnv: true,
        ),
      ),
    );
  });
  tearDownAll(harness.restore);

  test(
    'T-1a: the boot never dies with FileNotFoundError (the HEAD failure)',
    () async {
      final String crashLog = await harness.freshCrashLog();
      expect(
        crashLog,
        isNot(contains('FileNotFoundError')),
        reason:
            'FIX-B1 T-1: a missing .env must degrade, not abort the boot '
            'through handleBootFailure (F-AUD2-01). '
            'Fresh fatal-crash bytes: "$crashLog"',
      );
    },
  );

  test(
    'T-1b: STEP 16 runs — the push bridge installs on the continued boot',
    () async {
      expect(
        PushNotificationService.navigationHandler,
        isNotNull,
        reason:
            'STEP 16 (push bridge + runApp) must be reached: the env step may '
            'not abort the chain',
      );
    },
  );

  test('T-1c: the absence is EXPLICIT and documents the precedence', () async {
    final String printed = harness.debugPrintLines.join('\n');
    expect(
      printed,
      contains('EnvFileMissing'),
      reason: 'STEP 06 must surface the degradation — never silent',
    );
    expect(
      printed,
      contains('Precedence: .env -> --dart-define -> config'),
      reason: 'the marker states the documented env precedence',
    );
    expect(
      printed,
      contains('No values were fabricated'),
      reason: 'the marker states that absence fabricates nothing',
    );
  });

  test(
    'T-1d: nothing is fabricated and an absent security key stays fail-closed',
    () async {
      expect(
        dotenv.isInitialized,
        isTrue,
        reason:
            'the optional load still marks the layer loaded (explicit absence)',
      );
      expect(
        dotenv.env,
        isEmpty,
        reason:
            'no .env => the dotenv layer stays EMPTY — absence never '
            'fabricates values',
      );

      final String absentApiKey = dotenv.isInitialized
          ? (dotenv.maybeGet('FIREBASE_ANDROID_API_KEY') ?? '')
          : '';
      expect(
        firebaseKeyConfigured(
          FirebaseOptions(
            apiKey: absentApiKey,
            appId: 'probe',
            messagingSenderId: 'probe',
            projectId: 'probe',
          ),
        ),
        isFalse,
        reason:
            'fail-closed proof: an absent security key must NOT become a '
            'permissive default',
      );

      final String absentStripeKey = dotenv.isInitialized
          ? (dotenv.maybeGet('STRIPE_PUBLISHABLE_KEY') ?? '')
          : '';
      expect(
        absentStripeKey,
        isEmpty,
        reason:
            'an absent STRIPE_PUBLISHABLE_KEY stays empty — never defaulted',
      );
    },
  );
}
