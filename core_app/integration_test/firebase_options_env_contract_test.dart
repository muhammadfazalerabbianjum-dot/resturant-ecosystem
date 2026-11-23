@Tags(['e2e'])
library;

// p34 §0-3a CONTRACT — the --dart-define lane into firebase_options.dart.
//
// RED LAW context: the first-ever integration_test/ run (tool_uilib/p34_e2e/
// red_r2_first_run.txt) failed every app-boot suite with
// "Missing --dart-define=FIREBASE_ANDROID_API_KEY" even though the runner
// passed the define. Root cause: `_requireEnv` reads the environment through
// `String.fromEnvironment(key)` with a RUNTIME key — an environment query can
// only be resolved at compile time from a literal, so the value is always
// '' and the fail-closed guard can never be satisfied by any build.
//
// This test pins the contract both ways:
//  1. the literal environment query DOES receive the lane's define;
//  2. DefaultFirebaseOptions.android resolves to that SAME value
//     (i.e. _requireEnv stops swallowing it).
//
// Run through tool/run_integration_tests.ps1 STEP 5 (defines) — the same
// invocation the e2e lane uses.
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/firebase_options.dart';

void main() {
  test(
    'the lane define FIREBASE_ANDROID_API_KEY reaches DefaultFirebaseOptions',
    () {
      const passed = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
      expect(
        passed,
        isNotEmpty,
        reason:
            'run via tool/run_integration_tests.ps1 (STEP 5 passes the '
            'FIREBASE_ANDROID_API_KEY dart-define)',
      );
      expect(
        DefaultFirebaseOptions.android.apiKey,
        passed,
        reason:
            '_requireEnv must forward the compiled-in define; a runtime key '
            'query silently resolves to an empty string (p34 §0-3a)',
      );
    },
  );
}
