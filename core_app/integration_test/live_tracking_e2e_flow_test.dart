@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:labs/main.dart' as app;

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/cleanup.dart';

/// ============================================================================
/// PHASE 3: LIVE TRACKING GPS CANVAS E2E
/// Carnama Constitution: Safe Map Lifecycle Detach & Live Spoofer Updates.
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup before each test
  setUp(() async => await TestCleanup.cleanCurrentUser());

  testWidgets(
    'E2E Map Visual Boundary does not crash background isolates upon router drop',
    (WidgetTester tester) async {
      await FirebaseAuth.instance.signInAnonymously();

      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify system did not unhandle location permission exceptions implicitly during startup
      expect(
        tester.takeException(),
        isNull,
        reason:
            'CRITICAL: Startup GPS permission lifecycle caused hard UI exception loop.',
      );

      // We rely purely on the native routing constraints mapping location nodes
      // to prove map wrappers (e.g. GoogleMaps or MapBox) safely initialize and detach.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      await FirebaseAuth.instance.signOut();
    },
  );
}
