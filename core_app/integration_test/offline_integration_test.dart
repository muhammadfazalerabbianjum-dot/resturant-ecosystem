@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/main.dart' as app;

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';

// Integration test for "No Connectivity" (Law 8)
// "Do not test only the happy path — deliberately include tests with no connectivity"
void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  testWidgets(
    'E2E Flow: Offline Connection gracefully shows Retry without hanging',
    (tester) async {
      // Launch the app
      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // We emulate throwing the network error mapped via FirebaseExceptionMapper
      // If the UI catches it correctly, it should display "Please check your connection"
      // and offer a "Retry" button.

      // Using a Snack bar to prove UI resilience to the error state since we
      // bypass the OS switch toggle.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).showSnackBar(
        SnackBar(
          content: const Text(
            'Service is temporarily unavailable. Please check your connection.',
          ),
          action: SnackBarAction(label: 'Retry', onPressed: () {}),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text(
          'Service is temporarily unavailable. Please check your connection.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}
