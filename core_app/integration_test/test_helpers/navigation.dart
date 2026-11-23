import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:labs/app/app_router.dart';

/// CARNAMA CONSTITUTION Law 43: Standardized navigation helpers
/// Prevents flaky tests from inconsistent tap/verify patterns

extension NavigationHelpers on WidgetTester {
  /// Drives the REAL production go_router to `/login` (p34 T-2).
  ///
  /// A signed-out boot lands on the PUBLIC guest entry (`/` is listed in
  /// app_router.dart's publicPaths) — never `/login`. The e2e suites were
  /// written against an auth-wall at `/` that does not exist (they had never
  /// run before p34), so credential flows must navigate explicitly. Uses the
  /// exported `activeRouter` — the same object the PUSH-2 tap bridge
  /// exercises — so tests go through production navigation code, not a mirror.
  Future<void> goToLoginScreen() async {
    final router = activeRouter;
    expect(
      router,
      isNotNull,
      reason: 'activeRouter is null — await app.main() must run first',
    );
    router!.go('/login');
    await pumpAndSettle(const Duration(seconds: 5));
  }

  /// Drives the REAL production go_router to `/menu` (p34 T-2).
  ///
  /// `/menu` is listed in app_router.dart's publicPaths, so a signed-out
  /// guest reaches the menu screen — the surface that renders the sold-out
  /// affordance (menu_screen.dart:258-306, the add-button's Semantics label
  /// + IconButton tooltip). The home grid tile carries no sold-out
  /// affordance (home_screen.dart:592-645), and dish detail is auth-gated
  /// (router redirect sends guests to /login — red: green_r2_realtime_v13.txt),
  /// so this is the guest-reachable availability surface. Same real-router
  /// discipline as [goToLoginScreen].
  Future<void> goToMenuScreen() async {
    final router = activeRouter;
    expect(
      router,
      isNotNull,
      reason: 'activeRouter is null — await app.main() must run first',
    );
    router!.go('/menu');
    await pumpAndSettle(const Duration(seconds: 5));
  }

  /// Drives the REAL production go_router to the setup screen (p34 T-2).
  ///
  /// Config-mode routing (app_router.dart:250-255 + client_config.json)
  /// registers RestaurantSetupScreen directly at /admin/setup/restaurant -
  /// the OwnerDashboard (/owner) belongs to the static route table and does
  /// NOT exist in this mode (red: GoException 'no routes for location:
  /// /owner'). Requires an authenticated session (the route is not in
  /// publicPaths). Same real-router discipline as the other helpers.
  Future<void> goToSetupScreen() async {
    final router = activeRouter;
    expect(
      router,
      isNotNull,
      reason: 'activeRouter is null — await app.main() must run first',
    );
    router!.go('/admin/setup/restaurant');
    await pumpAndSettle(const Duration(seconds: 5));
  }

  /// Drives the REAL production go_router to `/profile` (p34 T-2).
  ///
  /// `/profile` (app_router.dart:510) is reachable once authenticated; the
  /// profile AppBar renders the sign-out affordance
  /// (profile_screen.dart:34-44). Soft icon taps in the shell cannot reach
  /// it deterministically (red: green_r2_full_battery_v3.txt - the sign-out
  /// assertion saw the session still live), so navigation goes through the
  /// real router like [goToLoginScreen] / [goToMenuScreen].
  Future<void> goToProfileScreen() async {
    final router = activeRouter;
    expect(
      router,
      isNotNull,
      reason: 'activeRouter is null — await app.main() must run first',
    );
    router!.go('/profile');
    await pumpAndSettle(const Duration(seconds: 5));
  }

  /// Safely navigate to login screen and enter credentials
  Future<void> loginAs(UserCredential userCredential) async {
    // p34 T-2: boot does NOT land on login (public guest entry) — route
    // there through the real router before verifying the screen.
    await goToLoginScreen();
    // Wait for login screen
    await pumpAndSettle(const Duration(seconds: 10));

    // Verify we're on login screen
    final emailField = find.byType(TextField).first;
    expect(emailField, findsOneWidget, reason: 'Login screen not found');

    // Enter credentials
    await enterText(emailField, userCredential.user?.email ?? '');
    await enterText(find.byType(TextField).at(1), 'password123');
    await pumpAndSettle();

    // Tap login button
    await tap(find.byType(ElevatedButton).first);

    // Wait for auth + navigation to complete
    await pump(const Duration(seconds: 3));
    await pumpAndSettle(const Duration(seconds: 10));

    // Verify login succeeded
    expect(
      FirebaseAuth.instance.currentUser,
      isNotNull,
      reason: 'Login failed',
    );
    expect(
      FirebaseAuth.instance.currentUser!.uid,
      equals(userCredential.user?.uid ?? ''),
    );
  }

  /// Logout if logout button exists
  Future<void> logoutIfPossible() async {
    final logoutButton = find.byIcon(Icons.logout);
    if (logoutButton.evaluate().isNotEmpty) {
      await tap(logoutButton.first);
      await pumpAndSettle(const Duration(seconds: 5));
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Verify no exceptions occurred
  void verifyNoExceptions() {
    final exception = takeException();
    expect(exception, isNull, reason: 'Unexpected exception: $exception');
  }
}
