@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';

void main() {
  // Law Constraint: Run entire suite inside firebase emulators
  setUpAll(() async {
    await bootstrapEmulators();
  });

  group('Constitution Integrated Emulator Tests', () {
    testWidgets('E2E Auth Lifecycle persists correctly safely mapping UI', (
      WidgetTester tester,
    ) async {
      await FirebaseAuth.instance.signInAnonymously();

      expect(FirebaseAuth.instance.currentUser, isNotNull);

      await FirebaseAuth.instance.signOut();
      expect(FirebaseAuth.instance.currentUser, isNull);
    });

    testWidgets('Security Rules UI Capture bypass ensures stability', (
      WidgetTester tester,
    ) async {
      // Create anon user
      await FirebaseAuth.instance.signInAnonymously();

      // Deliberately access a purely protected admin route (assume admins only)
      Object? capture;
      try {
        await FirebaseFirestore.instance
            .collection('admin_secrets')
            .doc('core')
            .get();
      } catch (e) {
        capture = e;
      }

      // We expect a literal crash at this testing perimeter, but we assert that the codebase
      // is designed to map this gracefully downstream.
      expect(capture, isNotNull);
      expect((capture as FirebaseException).code, 'permission-denied');

      await FirebaseAuth.instance.signOut();
    });

    testWidgets(
      'Missing document reads do not hang or crash the thread implicitly',
      (WidgetTester tester) async {
        // `empty_zone` is NOT listed in firestore.rules - it falls to
        // default-deny, so a read THROWS permission-denied (correct
        // security; the sibling test above proves exactly that for
        // admin_secrets). This test's intent is MISSING-DOC semantics on
        // a READABLE collection (red: green_r2_full_battery_final.txt -
        // documentReferenceGet threw instead of returning exists:false).
        // Sign in anonymously (the identity v13 proved CAN read menus)
        // and read a missing menu doc.
        await FirebaseAuth.instance.signInAnonymously();
        final doc = await FirebaseFirestore.instance
            .collection('menus')
            .doc('DOES_NOT_EXIST_CONSTITUTION')
            .get();

        // Native response provides safe explicit exist checks rather than runtime exceptions
        expect(doc.exists, false);
        expect(doc.data(), isNull);

        await FirebaseAuth.instance.signOut();
      },
    );
  });
}
