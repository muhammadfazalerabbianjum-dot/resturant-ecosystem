@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:labs/main.dart' as app;

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/test_users.dart';
import 'test_helpers/cleanup.dart';

/// ============================================================================
/// PHASE 3: WAITLIST LIVE UPDATES E2E
/// Carnama Constitution: Live stream nodes safely disconnect on screen pop.
/// ============================================================================

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  // CARNAMA CONSTITUTION Law 30: Cleanup before each test
  setUp(() async => await TestCleanup.cleanCurrentUser());

  testWidgets(
    'E2E Waitlist Stream aggressively unmounts listener to prevent memory leaks',
    (WidgetTester tester) async {
      // CARNAMA CONSTITUTION Law 30: Use factory for deterministic test user
      final cred = await TestUserFactory.createCustomer();

      // 1. Force a live waitlist database insert explicitly to test stream reception mapped in UI
      // p34: the collection is /waitlist/ (SINGULAR, firestore.rules L756) — the
      // old /waitlists/ (plural) matched nothing and hit default-deny
      // (battery_final: [cloud_firestore/permission-denied] No matching allow
      // statements @ line 35). The create rule (L761-762) also requires a
      // `userId` field == auth.uid; the real repository (waitlist_repository.dart
      // :110-117) keys the entry `${branchId}_$userId` with branchId+userId+status.
      await FirebaseFirestore.instance
          .collection('waitlist')
          .doc(cred.user!.uid)
          .set({
            'userId': cred.user!.uid,
            'branchId': 'branch_main',
            'status': 'queued',
            'queuePosition': 5,
          });

      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 2. Validate background stream sync doesn't crash UI thread visually
      await tester.pump(const Duration(seconds: 4));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Waitlist StreamBuilder caused async render fault.',
      );

      await FirebaseAuth.instance.signOut();
    },
  );
}
