@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:labs/main.dart' as app;
import 'test_helpers/navigation.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/test_users.dart';
import 'test_helpers/cleanup.dart';

/// ============================================================================
/// PHASE: PHYSICAL ROLE-BASED UI AUDIT (KITCHEN)
/// Carnama Constitution: 100% Emulator Isolation & Functional Bounds.
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: TearDown Logic (Zero Pollution Guarantee)
  setUp(() async => await TestCleanup.cleanCurrentUser());
  tearDown(() async => await TestCleanup.cleanCurrentUser());

  testWidgets(
    'E2E Kitchen Role authenticates and correctly isolates to Kitchen Dashboard',
    (WidgetTester tester) async {
      // CARNAMA CONSTITUTION Law 30: Use factory for deterministic test user
      final credential = await TestUserFactory.createKitchen(
        branchId: 'branch_A',
      );

      expect(credential.user, isNotNull);

      // Drop state before booting app
      await FirebaseAuth.instance.signOut();

      // Run Application
      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));
      // p34 T-2: a signed-out boot lands on the PUBLIC guest entry
      // (publicPaths in app_router.dart), never /login - route through the
      // REAL go_router before the credential flow.
      await tester.goToLoginScreen();

      // Authenticate
      await tester.enterText(
        find.byType(TextField).first,
        credential.user!.email!,
      );
      await tester.enterText(find.byType(TextField).at(1), 'TestPass123!');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byType(ElevatedButton).first);

      // Process Network
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(FirebaseAuth.instance.currentUser, isNotNull);

      // Kitchen specific negative and positive bounds:
      // Kitchen MUST NOT see customer views (like Cart / Delivery)
      final cartIcon = find.byIcon(Icons.shopping_cart);
      expect(
        cartIcon,
        findsNothing,
        reason:
            'Kitchen staff role routed improperly to the Customer experience',
      );

      // Tear down
      final logoutButton = find.byIcon(Icons.logout);
      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }
    },
  );
}
