import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// FIRESTORE SECURITY RULES TDD (Laws 12 & 30)
///
/// This suite programmatically asserts that the actual `firestore.rules`
/// file is functioning as mandated. It connects strictly to the local
/// Firebase Emulators — NEVER to production.
///
/// Requires: firebase emulators:exec wrapping (see carnama_ci.yml tier 4)

void main() {
  // Skip entire suite when Firebase Emulator is not running
  const emulatorAvailable = bool.fromEnvironment(
    'EMULATOR_AVAILABLE',
    defaultValue: false,
  );
  if (!emulatorAvailable) {
    test('Firestore Rules — requires emulator (skipped when offline)', () {
      expect(emulatorAvailable, isFalse);
    });
    return;
  }
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    // Law 30: Strict emulator binding — any real-project hit is a bug
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  });

  tearDown(() async => FirebaseAuth.instance.signOut());

  group('Firestore Security Rules — Unauthenticated (Law 12)', () {
    test('UNAUTH cannot read users collection', () async {
      await FirebaseAuth.instance.signOut();
      expect(
        () => FirebaseFirestore.instance.collection('users').get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('UNAUTH cannot write to menus collection', () async {
      await FirebaseAuth.instance.signOut();
      expect(
        () => FirebaseFirestore.instance.collection('menus').add({
          'name': 'Injected Item',
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('UNAUTH cannot read orders collection', () async {
      await FirebaseAuth.instance.signOut();
      expect(
        () => FirebaseFirestore.instance.collection('orders').get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('UNAUTH cannot write to reservations collection', () async {
      await FirebaseAuth.instance.signOut();
      expect(
        () => FirebaseFirestore.instance.collection('reservations').add({
          'userId': 'hacker',
          'date': DateTime.now().toIso8601String(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('UNAUTH cannot read carts collection', () async {
      await FirebaseAuth.instance.signOut();
      expect(
        () => FirebaseFirestore.instance.collection('carts').get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });

  group('Firestore Security Rules — User Isolation (Law 12)', () {
    test('User A CANNOT read User B document', () async {
      // Sign in as User A
      final userA = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'user_a_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      // Create User B's document directly via admin-style path
      final userBDocId = 'user_b_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('users').doc(userBDocId).set({
        'email': 'user_b@test.com',
        'role': 'customer',
      });

      // Still signed in as User A — attempt to read User B's document
      expect(
        () => FirebaseFirestore.instance
            .collection('users')
            .doc(userBDocId)
            .get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'User A must not be able to read User B\'s profile',
      );

      await userA.user!.delete();
    });

    test('User can read their OWN document', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'self_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );
      final uid = cred.user!.uid;

      // Write own document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': 'self@test.com',
        'role': 'customer',
      });

      // Read own document — must succeed
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      expect(snap.exists, isTrue);
      await cred.user!.delete();
    });

    test('User A CANNOT list User B\'s orders', () async {
      final userA = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'ord_a_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      expect(
        () => FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: 'some_other_user_uid_9999')
            .get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      await userA.user!.delete();
    });
  });

  group('Firestore Security Rules — Admin/Owner Privileges (Law 12)', () {
    test('Admin/Owner CAN write to menus collection', () async {
      // Requires admin seed user set up in emulator (see test/seed_emulator.dart)
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@carnama.com',
        password: 'AdminPass123',
      );

      final doc = await FirebaseFirestore.instance.collection('menus').add({
        'name': 'Test Burger (CI)',
        'priceCents': 1000,
        'branchId': 'branch_01',
        'isAvailable': true,
        'modifiers': [],
      });
      expect(doc.id, isNotNull);

      // Cleanup for idempotency
      await doc.delete();
    });
  });

  group('Firestore Security Rules — Data Shape Rejection (Law 12)', () {
    test('Writing invalid status string is rejected by rules', () async {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'shape_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      // Attempt to write an order with a status string not in the enum
      // Rules should enforce: status in ['pending','confirmed','preparing','ready','pickedUp','delivered','cancelled']
      expect(
        () => FirebaseFirestore.instance.collection('orders').add({
          'customerId': FirebaseAuth.instance.currentUser!.uid,
          'status': 'HACKED_VALUE', // Invalid — not in allowed enum
          'totalCents': 100,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Rules must enforce valid status enum values',
      );
    });

    test('Writing totalCents as negative is rejected by rules', () async {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'neg_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      expect(
        () => FirebaseFirestore.instance.collection('orders').add({
          'customerId': FirebaseAuth.instance.currentUser!.uid,
          'status': 'pending',
          'totalCents': -99, // Invalid — must be >= 0
          'createdAt': FieldValue.serverTimestamp(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Rules must reject negative totalCents (financial integrity)',
      );
    });
  });

  group('Firestore Security Rules — Presence & Auxiliary Collections', () {
    test('User cannot delete presence documents', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'pres_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'pass1234',
      );

      // Write presence doc (allowed)
      await FirebaseFirestore.instance
          .collection('presence')
          .doc(cred.user!.uid)
          .set({
            'status': 'online',
            'lastActive': FieldValue.serverTimestamp(),
          });

      // Attempt to delete (denied by rules 'allow delete: if false')
      expect(
        () => FirebaseFirestore.instance
            .collection('presence')
            .doc(cred.user!.uid)
            .delete(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('Customer cannot write to promoCodes', () async {
      expect(
        () => FirebaseFirestore.instance.collection('promoCodes').add({
          'code': 'FREE100',
          'discount': 100,
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });
}
