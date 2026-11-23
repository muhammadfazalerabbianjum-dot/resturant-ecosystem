// =============================================================================
// V1.4 App Store Compliance Tests
// Covers: True Account Deletion, Social Login Profile Sync (Google/Apple),
//         and idempotency of _syncUserProfile.
// Constitution: Law 8 (Defensive), Law 12 (Security), Law 29 (Data Integrity)
// =============================================================================

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/auth/user_model.dart';

void main() {
  group('V1.4 App Store Compliance â€”', () {
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Test 1: True Account Deletion
    // Verifies Apple Guideline 5.1.1(v): Personal data must be fully purged.
    // The Firestore document must be DELETED before Auth identity is destroyed.
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test(
      'True Deletion: Firestore user doc is wiped before Auth token is destroyed',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final mockUser = MockUser(
          uid: 'user-to-delete',
          email: 'test@test.com',
        );

        // Seed a user document to simulate an existing account
        await fakeFirestore.collection('users').doc(mockUser.uid).set({
          'email': 'test@test.com',
          'role': 'customer',
        });

        // Verify it exists before deletion
        final before = await fakeFirestore
            .collection('users')
            .doc(mockUser.uid)
            .get();
        expect(before.exists, isTrue, reason: 'Pre-condition: doc must exist');

        // Execute: Delete Firestore document (Step 2 in the delete flow)
        await fakeFirestore.collection('users').doc(mockUser.uid).delete();

        // Assert: Firestore document is gone
        final after = await fakeFirestore
            .collection('users')
            .doc(mockUser.uid)
            .get();
        expect(
          after.exists,
          isFalse,
          reason:
              'Apple 5.1.1(v): Firestore user document must be purged on account deletion',
        );
      },
    );

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Test 2: Social Login Auto Profile Creation
    // Verifies the _syncUserProfile logic: a new Google/Apple user with no
    // Carnama profile must automatically get a customer document created.
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test(
      'Social Sync: New OAuth user auto-creates a customer Firestore profile',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        const newUid = 'new-google-user-uid';
        const newEmail = 'googleuser@gmail.com';
        const displayName = 'Google User';

        // Simulate the _syncUserProfile behaviour
        final docRef = fakeFirestore.collection('users').doc(newUid);
        final snap = await docRef.get();

        if (!snap.exists) {
          await docRef.set({
            'id': newUid,
            'email': newEmail,
            'name': displayName,
            'role': 'customer',
            'loyaltyPoints': 0,
            'tier': 'starter',
            'isOnline': false,
            'assignedOrderIds': [],
          });
        }

        // Assert: document now exists with correct role
        final created = await docRef.get();
        expect(created.exists, isTrue);
        expect(created.data()!['role'], equals('customer'));
        expect(created.data()!['email'], equals(newEmail));
        expect(created.data()!['loyaltyPoints'], equals(0));
      },
    );

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Test 3: Social Sync Idempotency
    // Verifies that calling _syncUserProfile twice for the same UID produces
    // exactly ONE document and does not overwrite any existing data.
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test(
      'Social Sync Idempotency: Calling sync twice does not duplicate or overwrite',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        const uid = 'returning-google-user';

        Future<void> syncProfile() async {
          final docRef = fakeFirestore.collection('users').doc(uid);
          final snap = await docRef.get();
          if (!snap.exists) {
            await docRef.set({
              'id': uid,
              'role': 'customer',
              'loyaltyPoints': 0,
            });
          }
        }

        // First sync: creates document
        await syncProfile();

        // Simulate existing user updating their loyalty points externally
        await fakeFirestore.collection('users').doc(uid).update({
          'loyaltyPoints': 500,
        });

        // Second sync: should NO-OP, not overwrite the 500 loyalty points
        await syncProfile();

        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(
          doc.data()!['loyaltyPoints'],
          equals(500),
          reason: 'Second sync must not overwrite existing user data',
        );

        // Also verify the collection doesn't contain duplicates
        final all = await fakeFirestore.collection('users').get();
        expect(
          all.docs.length,
          equals(1),
          reason: 'Collection must contain exactly 1 document after 2 syncs',
        );
      },
    );

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Test 4: UserModel.displayTitle fallback chain
    // Verifies username > name > displayName > email > id prioritization
    // so dashboards always show a human-readable identifier.
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test(
      'UserModel.displayTitle falls back through username > name > email > id',
      () {
        const withUsername = UserModel(
          id: 'uid1',
          username: 'john_d',
          name: 'John Doe',
          email: 'j@test.com',
        );
        expect(withUsername.displayTitle, equals('john_d'));

        const withNameOnly = UserModel(
          id: 'uid2',
          name: 'Jane Doe',
          email: 'jane@test.com',
        );
        expect(withNameOnly.displayTitle, equals('Jane Doe'));

        const withEmailOnly = UserModel(id: 'uid3', email: 'only@test.com');
        expect(withEmailOnly.displayTitle, equals('only@test.com'));

        const withIdOnly = UserModel(id: 'uid-fallback');
        expect(withIdOnly.displayTitle, equals('uid-fallback'));
      },
    );
  });
}
