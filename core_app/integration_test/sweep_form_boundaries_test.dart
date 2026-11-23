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
/// PHASE 4: RUTHLESS RENDERFLEX OVERFLOW SWEEP
/// Carnama Constitution: Zero Blank Screens & Zero RenderFlex Overflow Crashes.
///
/// This automation natively scans the widget tree semantics, locating every
/// raw text input without relying on explicit keys. It injects mathematically
/// extreme payloads (10,000+ characters, emojis, negative decimals).
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup after each test
  tearDown(() async => await TestCleanup.cleanCurrentUser());

  testWidgets('E2E Semantic Form Node Exploitation & Constraint Padding', (
    WidgetTester tester,
  ) async {
    // 1. Force the App Rendering loop
    await app.main();
    // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
    await tester.pumpAndSettle(const Duration(seconds: 10));
    // p34 T-2: a signed-out boot lands on the PUBLIC guest entry
    // (publicPaths in app_router.dart), never /login - route through the
    // REAL go_router before the credential flow.
    await tester.goToLoginScreen();

    // The ruthless constraint payload
    final overflowPayload = 'A' * 10000 + '🤪👽👾👹' + '-99.999% DROP';

    // 2. Locate ALL TextField semantics aggressively via native type finder
    final textFields = find.byType(TextField);

    // We expect the auth screen or home bounds to have at least one field
    expect(
      textFields,
      findsWidgets,
      reason: 'Semantic Sweep failed to mount initial visual form bounds.',
    );

    // 3. Systematically explode every single field natively
    for (var i = 0; i < textFields.evaluate().length; i++) {
      final field = textFields.at(i);

      // Ensure element is visible in the physical viewport natively before typing
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();

      // Inject the overflow payload physically
      await tester.enterText(field, overflowPayload);

      // Force the render engine to layout the 10,000 character boundaries
      await tester.pumpAndSettle();

      // Check if the system correctly trapped the overflow or if the engine threw an exception
      expect(
        tester.takeException(),
        isNull,
        reason:
            'CRITICAL: RenderFlex overflow triggered. Field index $i lacks scroll physics or proper Expanded boundaries.',
      );
    }

    // 4. Force state commit (tap all submit buttons simultaneously if mapped)
    final submitButtons = find.byType(ElevatedButton);
    if (submitButtons.evaluate().isNotEmpty) {
      await tester.ensureVisible(submitButtons.first);
      await tester.tap(submitButtons.first);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Error handling rule check -> We assert the app did not literally crash after bad validation
      expect(
        tester.takeException(),
        isNull,
        reason: 'App crashed parsing massive boundary inputs internally.',
      );
    }
  });
}
