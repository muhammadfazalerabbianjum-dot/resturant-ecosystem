@Tags(['e2e', 'needs-emulator'])
library;

// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/main.dart' as app;
import 'test_helpers/navigation.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/test_users.dart';
import 'test_helpers/cleanup.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Law 17 & 47 — Golden A-Z Flow
/// This test verifies a high-resolution "Golden Flow" from Auth to Content.
void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup before each test
  setUp(() async => await TestCleanup.cleanCurrentUser());

  testWidgets(
    'A-Z Constitution Flow: Auth -> Menu -> Profile (Golden Snapshot)',
    (tester) async {
      // 1. Initialize Firebase
      await bootstrapEmulators();

      // CARNAMA CONSTITUTION Law 30: Create test user via factory
      final credential = await TestUserFactory.createCustomer();
      // createUserWithEmailAndPassword AUTO-SIGNS-IN the new user (Firebase
      // contract). A signed-in boot + the router's logged-in redirect
      // (app_router.dart:301-303: /login -> /) lands on home with no login
      // fields (red: green_r2_full_battery_final.txt - Bad state: No element
      // in enterText). Sign out first so the credential flow below actually
      // drives the login screen.
      await FirebaseAuth.instance.signOut();

      // 2. Launch the app
      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));
      // p34 T-2: a signed-out boot lands on the PUBLIC guest entry
      // (publicPaths in app_router.dart), never /login - route through the
      // REAL go_router before the credential flow.
      await tester.goToLoginScreen();

      // 3. Login with test user
      await tester.enterText(
        find.byType(TextField).first,
        credential.user!.email!,
      );
      await tester.enterText(find.byType(TextField).at(1), 'TestPass123!');
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 4. Verify login successful
      expect(FirebaseAuth.instance.currentUser, isNotNull);
      expect(FirebaseAuth.instance.currentUser!.email, credential.user!.email);

      // 5. Navigate to Menu
      final menuTab = find.byIcon(Icons.restaurant_menu);
      if (menuTab.evaluate().isNotEmpty) {
        await tester.tap(menuTab);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Verify menu loaded
      expect(find.textContaining('Menu'), findsWidgets);

      // 6. Navigate to Profile through the REAL production router
      // (/profile, app_router.dart:510) — the soft shell icon taps could
      // not reach it deterministically (red: green_r2_full_battery_v3.txt
      // - the sign-out assertion saw the session still live because the
      // logout button was never tapped).
      await tester.goToProfileScreen();

      // Verify profile screen
      expect(find.textContaining('Profile'), findsWidgets);

      // 7. Verify no exceptions occurred
      expect(tester.takeException(), isNull);

      // 8. Logout via the profile AppBar affordance
      // (profile_screen.dart:34-44, Icons.logout in AppBar actions).
      // Assert it EXISTS instead of a soft if-guard: a missing button must
      // fail the sign-out flow, not silently skip it.
      final logoutButton = find.byIcon(Icons.logout);
      expect(
        logoutButton,
        findsOneWidget,
        reason: 'profile AppBar must render the sign-out button',
      );
      await tester.tap(logoutButton);
      // authRepository.signOut() clears Isar/analytics/prefs/Firestore
      // before the auth state flips — allow the full cleanup to settle.
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify logged out
      expect(FirebaseAuth.instance.currentUser, isNull);
    },
  );
}
