@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';

void main() {
  // CARNAMA CONSTITUTION Law 30: Strict Emulator Wrapping
  setUpAll(() async {
    await bootstrapEmulators();
  });

  group('Firestore Security Rules Deterministic Bounds', () {
    testWidgets(
      'Unauthenticated user mathematically rejected from reading core data',
      (WidgetTester tester) async {
        // Ensure absolute logout
        await FirebaseAuth.instance.signOut();

        Object? capture;
        try {
          await FirebaseFirestore.instance.collection('users').get();
        } catch (e) {
          capture = e;
        }

        expect(capture, isNotNull);
        expect(
          (capture as FirebaseException).code,
          'permission-denied',
          reason: 'Rules must universally ban unauthenticated reads.',
        );
      },
    );

    testWidgets(
      'Authenticated User mathematically rejected from writing to another user ID',
      (WidgetTester tester) async {
        await FirebaseAuth.instance.signInAnonymously();

        const targetUid = 'someone_else_123';

        Object? capture;
        try {
          // Attempting to overwrite someone else's document profile
          await FirebaseFirestore.instance
              .collection('users')
              .doc(targetUid)
              .set({'hacked': true});
        } catch (e) {
          capture = e;
        }

        expect(capture, isNotNull);
        expect(
          (capture as FirebaseException).code,
          'permission-denied',
          reason: 'Rules must strictly validate resource.id == auth.uid.',
        );

        await FirebaseAuth.instance.signOut();
      },
    );

    testWidgets(
      'Valid resource bindings grant successful mutating boundaries',
      (WidgetTester tester) async {
        // p34 cluster A: current rules deny ALL anonymous user-doc writes
        // (!isAnonymous at L400), so the binding grant is exercised with a
        // real account carrying the `app_id` claim — same assertion, current
        // rules vocabulary.
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'binding_${DateTime.now().millisecondsSinceEpoch}@test.com',
          password: 'TestPass123!',
        );
        await grantAppIdClaim(cred.user!);
        final currentUid = FirebaseAuth.instance.currentUser!.uid;

        // Should succeed because currentUid matches target mutating ID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .set({'active': true});

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        expect(doc.exists, isTrue);

        await FirebaseAuth.instance.signOut();
      },
    );
  });
}
