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
/// PHASE: PHYSICAL ROLE-BASED UI AUDIT (MANAGER)
/// Carnama Constitution: 100% Emulator Isolation & Bounds Verification.
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: TearDown Logic (Zero Pollution Guarantee)
  setUp(() async => await TestCleanup.cleanCurrentUser());
  tearDown(() async => await TestCleanup.cleanCurrentUser());

  testWidgets('E2E Manager Role authenticates and strictly avoids Admin logic', (
    WidgetTester tester,
  ) async {
    // CARNAMA CONSTITUTION Law 30: Use factory for deterministic test user
    final credential = await TestUserFactory.createManager(
      branchId: 'branch_e2e_1',
    );

    expect(credential.user, isNotNull);

    // Drop state before booting app
    await FirebaseAuth.instance.signOut();

    // Boot App
    await app.main();
    // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
    await tester.pumpAndSettle(const Duration(seconds: 10));
    // p34 T-2: a signed-out boot lands on the PUBLIC guest entry
    // (publicPaths in app_router.dart), never /login - route through the
    // REAL go_router before the credential flow.
    await tester.goToLoginScreen();

    // Verify Login Screen
    final emailField = find.byType(TextField).first;
    expect(emailField, findsOneWidget);

    await tester.enterText(emailField, credential.user!.email!);
    await tester.enterText(find.byType(TextField).at(1), 'TestPass123!');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Login Action
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(FirebaseAuth.instance.currentUser, isNotNull);

    // Negative Assertion (Constitution Requirement):
    // Manager MUST NOT visibly see Admin Control Panels
    final adminControlPanel = find.textContaining(
      'Admin Control',
      skipOffstage: false,
    );

    // We expect NO Admin controls to render for a Manager
    expect(
      adminControlPanel,
      findsNothing,
      reason:
          'CRITICAL SECURITY: Manager role visibly exposed to Admin boundaries',
    );

    // Conclude test with proper cleanup
    final logoutButton = find.byIcon(Icons.logout);
    if (logoutButton.evaluate().isNotEmpty) {
      await tester.tap(logoutButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 10));
    }
  });
}
