// FIX-B1 T-2 (F-AUD2-05) — the placeholder projectId guard.
//
// The REAL bundled template config carries
// firebase.projectId = REPLACE_ME_FIREBASE_PROJECT_ID; at HEAD that
// placeholder WINS the options merge and reaches Firebase.initializeApp —
// a silent init against a bogus project (RED proof:
// tool_fix/b1/red_t2.txt).
//
// The green contract (spec §3 T-2):
//  * the documented placeholder is EXCLUDED from the merge (the caller's
//    generated default survives);
//  * a resolved placeholder/empty id is CAUGHT before init and the message
//    NAMES THE KEY (`firebase.projectId`) — never a silent bogus init;
//  * shell policy blocks the boot; template policy withholds the Firebase
//    chain and still reaches STEP 16 (logged-continue preserved).
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app_bootstrap.dart';

import 'helpers/boot_env_harness.dart';

void main() {
  final BootHarness harness = BootHarness();

  setUp(harness.install);
  tearDown(harness.restore);

  const String realKey = 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY';
  const String templatePlaceholder = 'REPLACE_ME_FIREBASE_PROJECT_ID';

  test(
    'T-2a (shell): a resolved placeholder is caught BEFORE init and the message names the key',
    () async {
      await harness.runBoot(
        () => initCarnamaApp(
          bootstrap: bootstrapFor(
            options: bootOptions(
              apiKey: realKey,
              projectId: templatePlaceholder,
            ),
            errorScreen: shellBlockingScreen,
          ),
        ),
      );

      expect(
        harness.platform.initializeAppCalls,
        isEmpty,
        reason:
            'the gate must never initialize Firebase against a REPLACE_ME '
            'project (F-AUD2-05). Recorded calls: '
            '${harness.platform.initializeAppCalls.map((o) => o.projectId)}',
      );
      final String printed = harness.debugPrintLines.join('\n');
      expect(
        printed,
        contains('FATAL: firebase.projectId'),
        reason: 'the failure must be CLEAR and NAME THE KEY firebase.projectId',
      );
      expect(
        printed,
        contains(templatePlaceholder),
        reason: 'the message must show the resolved placeholder (actionable)',
      );
      expect(
        AppConfig.firebaseProjectId,
        templatePlaceholder,
        reason:
            'precondition: the REAL bundled template config carries the '
            'placeholder the gate faced',
      );
    },
  );

  test(
    'T-2b (shell): the placeholder is excluded from the merge — the caller default wins',
    () async {
      harness.platform.throwOnInitializeApp = StateError(
        'no Firebase in test host',
      );
      await harness.runBoot(
        () => initCarnamaApp(
          bootstrap: bootstrapFor(
            options: bootOptions(
              apiKey: realKey,
              projectId: 'client-real-project',
            ),
            errorScreen: shellBlockingScreen,
          ),
        ),
      );

      expect(
        harness.platform.initializeAppCalls,
        hasLength(1),
        reason: 'a REAL caller default must boot normally through the gate',
      );
      final FirebaseOptions merged = harness.platform.initializeAppCalls.single;
      expect(
        merged.projectId,
        'client-real-project',
        reason:
            'F-AUD2-05: the bundled REPLACE_ME placeholder must NOT win the '
            "merge over the caller's generated default",
      );
      expect(
        merged.apiKey,
        realKey,
        reason: 'apiKey still always from the caller (unchanged contract)',
      );
      expect(
        harness.debugPrintLines.join('\n'),
        isNot(contains('FATAL: firebase.projectId')),
        reason: 'the gate stays quiet when a real id resolves',
      );
      expect(
        AppConfig.firebaseProjectId,
        templatePlaceholder,
        reason:
            'precondition: the config value that was excluded really was the '
            'placeholder',
      );
    },
  );

  test(
    'T-2c (template): placeholder id never reaches a silent init; boot continues',
    () async {
      await harness.runBoot(
        () => initCarnamaApp(
          bootstrap: bootstrapFor(
            options: bootOptions(
              apiKey: realKey,
              projectId: templatePlaceholder,
            ),
          ),
        ),
      );

      expect(
        harness.platform.initializeAppCalls,
        isEmpty,
        reason:
            'template policy withholds the Firebase chain: a REPLACE_ME '
            'project id must never be silently initialized (F-AUD2-05)',
      );
      final String printed = harness.debugPrintLines.join('\n');
      expect(
        printed,
        contains('FATAL: firebase.projectId'),
        reason:
            'clear failure naming the key — template policy logs it and '
            'continues',
      );
      expect(
        PushNotificationService.navigationHandler,
        isNotNull,
        reason:
            'logged-continue semantics preserved: STEP 16 still installs the '
            'push bridge',
      );
    },
  );
}
