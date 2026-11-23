@Tags(['e2e'])
library;

// p34 §0-3a (T-1 RED→GREEN) — the missing --dart-define layer for
// FIREBASE_PROJECT_ID.
//
// The documented boot precedence is `.env -> --dart-define -> config`
// (app_bootstrap.dart loadEnvLayer doc). RED PROOF
// (tool_uilib/p34_e2e/red_r2_first_run.txt): every app-boot e2e suite wedged
// on `FATAL: firebase.projectId resolved: ""` because the dart-define layer
// had NO implementation — AppConfig read FIREBASE_PROJECT_ID from dotenv
// ONLY, and the e2e lane bundles no `.env`. So projectId (fed into
// firebase_options.dart projectId/storageBucket) stayed empty and the
// Firebase chain was withheld.
//
// The green contract: FIREBASE_PROJECT_ID passed as --dart-define resolves
// into AppConfig.firebaseProjectId when dotenv has no value — WITHOUT
// requiring an .env asset. This pins the middle layer of the precedence
// chain that was previously only documented, never coded.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';

void main() {
  setUp(() async {
    // Isolate the dart-define layer: no .env in this host, so dotenv is the
    // (absent) top layer and the dart-define layer is the one under test.
    if (!dotenv.isInitialized) {
      await dotenv.load(isOptional: true);
    }
  });

  test(
    'FIREBASE_PROJECT_ID --dart-define resolves into AppConfig when .env is absent',
    () async {
      const passed = String.fromEnvironment('FIREBASE_PROJECT_ID');
      expect(
        passed,
        isNotEmpty,
        reason:
            'run via tool/run_integration_tests.ps1 (STEP 5 passes the '
            'FIREBASE_PROJECT_ID dart-define for the emulator lane)',
      );
      await AppConfig.loadConfig();
      expect(
        AppConfig.firebaseProjectId,
        passed,
        reason:
            'AppConfig must honour the --dart-define layer of the documented '
            '`.env -> --dart-define -> config` precedence; at RED it read '
            'dotenv only and resolved to empty, withholding the Firebase '
            'chain (p34 §0-3a).',
      );
    },
  );
}
