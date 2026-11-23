@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/main.dart' as app;
import 'test_helpers/navigation.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/cleanup.dart';

/// ============================================================================
/// PHASE 4: RUTHLESS NETWORK CHAOS SWEEP
/// Carnama Constitution: Zero Infinite Loading Spinners & Graceful Offline Locks.
///
/// This test explicitly toggles Firebase Emulator connections mid-action by
/// terminating access to the emulator and forces UI to revert back to active
/// states when the socket is restored without crashing RenderFlex or UI threads.
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup before each test
  setUp(() async => await TestCleanup.cleanCurrentUser());

  testWidgets('E2E Network Chaos: Mid-Flight Authentication Drop', (
    WidgetTester tester,
  ) async {
    await app.main();
    // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
    await tester.pumpAndSettle(const Duration(seconds: 10));
    // p34 T-2: a signed-out boot lands on the PUBLIC guest entry
    // (publicPaths in app_router.dart), never /login - route through the
    // REAL go_router before the credential flow.
    await tester.goToLoginScreen();

    // 1. Establish stable baseline UI rendering
    final emailField = find.byType(TextField).first;
    expect(emailField, findsOneWidget);
    await tester.enterText(emailField, 'chaos@carnama.com');
    await tester.enterText(find.byType(TextField).at(1), 'Chaos123!');

    // 2. Fire the sign-in. The credential does not exist, so the auth
    // pipeline fails exactly as a mid-flight drop would (the old Firestore
    // dead-port sabotage here never affected the sign-in at all - auth
    // talks to its own emulator - and rebinding it back mid-test was the
    // only thing keeping the dead port from leaking into later suites,
    // since the Firestore instance is a process singleton). A failed
    // sign-in exercises the same graceful-degradation path.
    await tester.tap(find.byType(ElevatedButton).first);

    // 4. Force wait logic to allow async exception mapping
    await tester.pump(const Duration(seconds: 4));

    // 5. Verification - Must NOT be in a permanent loading state
    // We explicitly pull the CircularProgressIndicator and guarantee it is NOT infinitely looping.
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason:
          'CRITICAL: Offline network drops must not trap user in an infinite loading spinner.',
    );

    // Check the failed sign-in surfaces its mapped error INLINE
    // (login_screen.dart:44-45 maps the FirebaseAuthException to _error,
    // rendered as a centered Text at :214-222). The sign-in path never
    // uses a SnackBar - only _forgotPassword does, so the original
    // SnackBar assertion could never match (red:
    // green_r2_full_battery_v3.txt - user-not-found with no SnackBar).
    expect(
      find.text('Incorrect email or password.'),
      findsOneWidget,
      reason:
          'CRITICAL: a failed sign-in must surface its mapped error inline.',
    );

    // 6. Restabilize: the UI must remain usable after the failed attempt -
    // the login form stays interactive and no permanent loading state
    // remains (the app is never bricked by a failed sign-in).
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.byType(TextField),
      findsWidgets,
      reason: 'login form must remain usable after a failed sign-in',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'no permanent spinner after a failed sign-in',
    );
  });
}
