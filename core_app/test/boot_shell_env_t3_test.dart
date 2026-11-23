// FIX-B1 T-3 — shell non-regression (zero blast radius for shipping
// clients). Every generated shell (apps/halal_boyz) boots with the
// CarnamaBootstrap default `loadEnv: false` and must NEVER touch the dotenv
// layer — the B1 fix lives entirely behind the loadEnv guard.
//
// RED-AT-HEAD: written before the T-1 helper existed — this file failed to
// compile (Undefined: `loadEnvLayer`; receipt tool_fix/b1/red_t3.txt),
// which is this task's TDD red. It turns green with T-1's helper; this file
// is the batch's durable proof of the shells-unaffected invariant.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart';

import 'helpers/boot_env_harness.dart';

void main() {
  final BootHarness harness = BootHarness();

  setUp(harness.install);
  tearDown(harness.restore);

  test(
    'T-3a: loadEnvLayer(enabled: false) returns false and never touches dotenv',
    () async {
      expect(await loadEnvLayer(enabled: false), isFalse);
      expect(
        dotenv.isInitialized,
        isFalse,
        reason:
            'a shell must never initialize the dotenv layer — zero blast '
            'radius',
      );
    },
  );

  test(
    'T-3b: a full boot with loadEnv:false leaves dotenv untouched',
    () async {
      await harness.runBoot(
        () => initCarnamaApp(
          bootstrap: bootstrapFor(
            options: bootOptions(apiKey: 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY'),
            errorScreen: shellBlockingScreen,
          ),
        ),
      );

      expect(
        dotenv.isInitialized,
        isFalse,
        reason:
            'the boot chain must not touch dotenv when loadEnv is false '
            '(the default every shell ships with)',
      );
      expect(
        harness.debugPrintLines.join('\n'),
        isNot(contains('EnvFileMissing')),
        reason: 'the env-absence marker belongs to the template path only',
      );
    },
  );
}
