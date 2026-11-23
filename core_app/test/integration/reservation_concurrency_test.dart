import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  // Skip when Firebase Emulator is not running
  const emulatorAvailable = bool.fromEnvironment(
    'EMULATOR_AVAILABLE',
    defaultValue: false,
  );
  if (!emulatorAvailable) {
    test(
      'Reservation concurrency — requires emulator (skipped when offline)',
      () {
        expect(emulatorAvailable, isFalse);
      },
    );
    return;
  }

  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  testWidgets(
    'Concurrency test - 5 simultaneous requests for the same reservation lock slot',
    (WidgetTester tester) async {
      // 1. Sign in a user to satisfy authentication rules
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'test_concurrency@carnama.com',
          password: 'Password123!',
        );
      } catch (e) {
        // User might already exist in emulator, sign in
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'test_concurrency@carnama.com',
          password: 'Password123!',
        );
      }

      const String mockLockId = 'branchX_20261010_1800';
      final firestore = FirebaseFirestore.instance;

      // Teardown: purge test data (Law 30 — deterministic cleanup)
      addTearDown(() async {
        try {
          await firestore
              .collection('reservation_locks')
              .doc(mockLockId)
              .delete();
        } catch (_) {}
      });

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 2. Fire 5 concurrent requests to create the exact same lock
      final requests = List.generate(5, (index) {
        // Intentionally NOT awaiting directly here to fire them all simultaneously
        return firestore.collection('reservation_locks').doc(mockLockId).set({
          'userId': uid,
          'slot': mockLockId,
          'expiresAt': FieldValue.serverTimestamp(),
        });
      });

      int successCount = 0;
      int failureCount = 0;

      // Wait for all to complete and tally successes/failures
      for (var future in requests) {
        try {
          await future;
          successCount++;
        } catch (e) {
          failureCount++;
        }
      }

      // Because Firestore 'create' or even 'set' without merge might allow overwrites,
      // wait... in Dart, .set() creates or overwrites!
      // If it overwrites, successCount will be 5!
      // Let's see how our frontend implements it.
      // To ensure concurrency protection, the frontend or Firestore rules MUST prevent overwrites.
      // Our rule allows create but doesn't explicitly restrict update if we use set!
      // Wait, the rule says `allow create: ... allow delete: ...`. It DOES NOT `allow update`.
      // Therefore, any `set()` on an existing document acts as an overwrite (update), which is DENIED by rules!
      // So 1 should succeed (the create), and 4 should fail with permission-denied (the updates).

      expect(
        successCount,
        1,
        reason: 'Only the very first request should succeed as a fresh create.',
      );
      expect(
        failureCount,
        4,
        reason:
            'Subsequent simultaneous requests must be rejected by Firestore rules as illegal updates.',
      );
    },
  );
}
