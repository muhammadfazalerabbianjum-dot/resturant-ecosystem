@Tags(['e2e', 'needs-emulator'])
library;

// =============================================================================
// PHASE 1: RUTHLESS SECURITY RULES AUDIT (V1.5)
// Engine: Firebase Local Emulator Suite (REAL Java server, REAL Firestore rules)
// Vectors: Price spoofing, privilege escalation, lateral movement,
//          impersonation, branch injection, order hijacking, PII probe,
//          promo code tampering.
// Run: firebase emulators:start (in a separate terminal), then:
//      flutter test test/wiring/v15_phase1_security_audit_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'test_helpers/emulator_bootstrap.dart';

/// Helper: create a fresh auth user and return their UID
Future<Map<String, dynamic>> _createUser(
  String prefix,
  String role,
  String branchId,
) async {
  final email = '${prefix}_${DateTime.now().millisecondsSinceEpoch}@test.com';
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'TestPass123!',
  );
  final uid = cred.user!.uid;
  // p34 cluster A: rules L411-L415 deny client creation of role docs other
  // than 'customer' (C-1 removed the old first-write backdoor this comment
  // once relied on), and L400 needs the `app_id` claim emulator tokens lack.
  // Provision via claim + emulator-admin create instead.
  await grantAppIdClaim(cred.user!);
  await seedUserRoleDoc(
    uid: uid,
    email: email,
    role: role,
    branchId: branchId,
    name: prefix,
  );
  return {'uid': uid, 'email': email, 'user': cred.user};
}

void main() {
  // p34 C-fix: no FirebasePlatform mock on the device lane (see
  // v13_security_rules_test.dart setUpAll — mock/real split deadlocks).
  setUpAll(() async {
    await bootstrapEmulators();
  });

  tearDown(() async => FirebaseAuth.instance.signOut());

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 1: PRICE SPOOFING
  // Customer creates an order with totalCents: 0 to get a free meal.
  // The rules allow totalCents >= 0 but the client must still send a real value.
  // The attack is: altering the object mid-flight so totalCents = 0.
  // Since rules check request.resource.data.totalCents >= 0, this technically
  // passes — THIS IS A KNOWN LIMITATION documented intentionally.
  // The true guard lives in the Stripe backend + CartValidatorService.
  // We test that a NEGATIVE totalCents is blocked by the server.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 1 — Price Spoofing', () {
    test('Customer CANNOT create order with negative totalCents', () async {
      final uid =
          (await _createUser('attacker_price', 'customer', 'branch_a'))['uid']
              as String;

      await expectLater(
        FirebaseFirestore.instance.collection('orders').add({
          'customerId': uid,
          'branchId': 'branch_a',
          'status': 'confirmed',
          'totalCents': -500, // Negative price attack
          'createdAt': FieldValue.serverTimestamp(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Negative totalCents must be blocked by firestore.rules',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });

    test(
      'Customer CANNOT create order with someone else\'s customerId',
      () async {
        await _createUser('attacker_impersonation', 'customer', 'branch_a');
        await expectLater(
          FirebaseFirestore.instance.collection('orders').add({
            'customerId': 'some_other_uid_12345', // Spoofed as another user
            'branchId': 'branch_a',
            'status': 'confirmed',
            'totalCents': 1000,
            'createdAt': FieldValue.serverTimestamp(),
          }),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
          reason:
              'Order customerId must equal authenticated UID — spoofing must be rejected',
        );

        await FirebaseAuth.instance.currentUser?.delete();
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 2: PRIVILEGE ESCALATION
  // A customer attempts to change their own Firestore role to 'owner'.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 2 — Privilege Escalation', () {
    test('Customer CANNOT self-promote their role to owner', () async {
      final uid =
          (await _createUser('attacker_priv', 'customer', 'branch_a'))['uid']
              as String;

      await expectLater(
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': 'owner',
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Customer must never be able to write role:owner to their own document',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });

    test('Customer CANNOT self-promote their role to manager', () async {
      final uid =
          (await _createUser('attacker_mgr', 'customer', 'branch_a'))['uid']
              as String;

      await expectLater(
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': 'manager',
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Customer must never be able to self-promote to manager',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 3: LATERAL MOVEMENT (Cross-branch data access)
  // A kitchen staff from branch_a attempts to read orders from branch_b.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 3 — Lateral Movement (Cross-Branch)', () {
    test('Kitchen staff from branch_a CANNOT read order from branch_b', () async {
      // Seed the victim order HEADLESSLY via the emulator-admin REST (owner
      // token) — a client .set() with no app-verified user signed in is denied
      // by the create rule (L478), so the seed itself threw before the real
      // assertion (v15_recheck.txt: false for 'create' @ L478). Unique id per
      // run avoids cross-session collisions turning create into an update.
      final victimOrderId = await emulatorAdminCreateDocument(
        collection: 'orders',
        fields: {
          'customerId': 'some_customer',
          'branchId': 'branch_b', // Different branch
          'status': 'confirmed',
          'totalCents': 2500,
        },
      );

      // Sign in as kitchen staff assigned to branch_a only
      await _createUser('attacker_kitchen', 'kitchen', 'branch_a');

      await expectLater(
        FirebaseFirestore.instance
            .collection('orders')
            .doc(victimOrderId)
            .get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Kitchen staff from branch_a must be denied access to branch_b orders',
      );

      await FirebaseAuth.instance.currentUser?.delete();
      await emulatorAdminDeleteDocument(
        collection: 'orders',
        documentId: victimOrderId,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 4: DRIVER IMPERSONATION
  // A delivery driver updates the status of an order they were NOT assigned to.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 4 — Driver Impersonation', () {
    test(
      'Driver CANNOT update status of an order not assigned to them',
      () async {
        // Seed an order assigned to a DIFFERENT driver — HEADLESSLY via the
        // emulator-admin REST. A client .set() with no app-verified user is
        // denied by the create rule (L478), so the seed threw before the real
        // assertion (v15_recheck.txt: false for 'create' @ L478).
        final victimOrderId = await emulatorAdminCreateDocument(
          collection: 'orders',
          fields: {
            'customerId': 'real_customer',
            'branchId': 'branch_a',
            'status': 'ready',
            'totalCents': 1200,
            'assignedDriverId': 'legitimate_driver_uid_xyz', // Not our attacker
          },
        );

        // Sign in as a DIFFERENT delivery driver (branch_a) so the update is
        // denied for the RIGHT reason: the order is assigned to another driver
        // (delivery clause L545-552 requires assignedDriverId == auth.uid),
        // not merely because nobody was signed in.
        await _createUser('attacker_driver', 'delivery', 'branch_a');

        await expectLater(
          FirebaseFirestore.instance
              .collection('orders')
              .doc(victimOrderId)
              .update({'status': 'delivered'}),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
          reason:
              'Driver must be denied update on orders not assigned to their UID',
        );

        await FirebaseAuth.instance.currentUser?.delete();
        await emulatorAdminDeleteDocument(
          collection: 'orders',
          documentId: victimOrderId,
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 5: FAKE BRANCH INJECTION
  // A customer creates a fake branch document to redirect orders / manipulate
  // delivery radius calculations.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 5 — Fake Branch Injection', () {
    test('Customer CANNOT write to branches collection', () async {
      await _createUser('attacker_branch', 'customer', 'branch_real');

      await expectLater(
        FirebaseFirestore.instance
            .collection('branches')
            .doc('fake_branch')
            .set({
              'name': 'Evil Branch',
              'lat': 0.0,
              'lng': 0.0,
              'deliveryRadiusMiles': 99999.0,
            }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Only owner can write branch documents — customer injection must fail',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });

    test('Manager CANNOT write to branches collection', () async {
      await _createUser('attacker_branch_mgr', 'manager', 'branch_real');

      await expectLater(
        FirebaseFirestore.instance
            .collection('branches')
            .doc('malicious_branch')
            .set({'name': 'Manager Takeover', 'lat': 0.0, 'lng': 0.0}),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Only owner can write branch documents — manager injection must fail',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 6: PROMO CODE TAMPERING
  // A customer or kitchen staff attempts to create or modify promo codes.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 6 — Promo Code Tampering', () {
    test('Customer CANNOT write promo codes', () async {
      await _createUser('attacker_promo', 'customer', 'branch_a');

      await expectLater(
        FirebaseFirestore.instance.collection('promoCodes').doc('HACKFREE').set(
          {'discountPercent': 100, 'usageLimit': 9999, 'usedCount': 0},
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Customer must never be allowed to create promo codes',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });

    test('Kitchen staff CANNOT write promo codes', () async {
      await _createUser('attacker_promo_kitchen', 'kitchen', 'branch_a');

      await expectLater(
        FirebaseFirestore.instance
            .collection('promoCodes')
            .doc('KITCHENHACK')
            .set({'discountPercent': 50, 'usageLimit': 99}),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Kitchen staff must never be allowed to write promo codes',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 7: PII PROBE
  // An unauthenticated request (no user) attempts to read the users collection.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 7 — Unauthenticated PII Probe', () {
    test('Unauthenticated request CANNOT read users collection', () async {
      // Ensure no user is signed in
      await FirebaseAuth.instance.signOut();

      await expectLater(
        FirebaseFirestore.instance.collection('users').get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Unauthenticated request must be completely denied from accessing user PII',
      );
    });

    test(
      'Unauthenticated request CANNOT read a specific user document',
      () async {
        await FirebaseAuth.instance.signOut();

        await expectLater(
          FirebaseFirestore.instance.collection('users').doc('any_uid').get(),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
          reason:
              'Unauthenticated request must not even be able to probe a specific UID',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 8: CUSTOMER ORDER DELETION
  // A customer attempts to DELETE their own confirmed order to evade charges
  // or the kitchen's ticketing system.
  // ══════════════════════════════════════════════════════════════════════════
  group('Attack Vector 8 — Order Deletion Evasion', () {
    test('Customer CANNOT delete their own order once created', () async {
      final result = await _createUser(
        'attacker_delete',
        'customer',
        'branch_a',
      );
      final uid = result['uid'] as String;

      // Create a valid order as the customer. p34: the create rule (L478/L491)
      // requires status == 'pending' — 'confirmed' is denied on create, so the
      // .add() below threw before the delete could even be attempted
      // (v15_recheck.txt: false for 'create' @ L478). Use 'pending' so the
      // create succeeds and the DELETE attempt is what gets denied.
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
            'customerId': uid,
            'branchId': 'branch_a',
            'status': 'pending',
            'totalCents': 3000,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Now attempt to delete it (evade charges / disrupt kitchen)
      await expectLater(
        orderRef.delete(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason:
            'Customer must not be able to delete orders — no delete rule exists for customers',
      );

      await FirebaseAuth.instance.currentUser?.delete();
    });
  });
}
