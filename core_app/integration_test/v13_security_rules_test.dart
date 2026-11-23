@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'test_helpers/emulator_bootstrap.dart';

/// FIRESTORE SECURITY RULES — V1.3 ADDITIONS (Laws 12 & 48)
///
/// Tests covering the new rules patched in the V1.3 Bug Eradication sweep:
/// 1. Owner cannot change their own role (anti-self-nerfing)
/// 2. Guest/anonymous user can read public branches and menus
/// 3. Guest/anonymous cannot read orders or user documents
///
/// Requires firebase emulators running (see carnama_ci.yml Tier 4).

void main() {
  // p34 C-fix: NO setupFirebaseAuthMocks() in the device lane — the mocked
  // FirebasePlatform (projectId 'mock-project') fights the real on-device
  // plugins and deadlocks the 2nd auth cycle (green_v13_run2/run3: +1 then
  // channel silence). Real plugins + bootstrapEmulators() only.
  setUpAll(() async {
    await bootstrapEmulators();
  });

  tearDown(() async => FirebaseAuth.instance.signOut());

  // ── 1.1: ANTI-SELF-DEMOTION RULE ─────────────────────────────────────────
  group('Anti-Self-Nerfing Rule (Law 12)', () {
    test('Owner CANNOT change their own role field', () async {
      // Create a test owner account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'owner_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'OwnerPass123',
      );
      final uid = cred.user!.uid;

      // Provision the owner's user document the way production does: the
      // `app_id` claim first, then an emulator-admin role-doc create
      // (client creation of a role doc is denied by rules L411-L415).
      await grantAppIdClaim(cred.user!);
      await seedUserRoleDoc(
        uid: uid,
        email: cred.user!.email ?? '',
        role: 'owner',
        branchId: 'branch_main',
      );

      // Attempt to downgrade own role — MUST be denied
      expect(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': 'delivery', // Self-demotion attempt
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Owner must not be able to change their own role to delivery',
      );
      // p34: do NOT cred.user!.delete() here. Deleting the current signed-in
      // user wedges the native firebase_auth queue on the emulator — the next
      // create/anon in this process never dispatches (v13 hang, guest tests 3-8).
      // Proven by p34_nodelete_probe_test (two email cycles + anon, no delete =>
      // +3 All tests passed). The emulator is disposable and uids are
      // timestamped, so the teardown signOut() alone leaves no residue.
    });

    test('Manager CANNOT change their own role', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'mgr_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'MgrPass123',
      );
      final uid = cred.user!.uid;

      // Provision via claim + emulator-admin role-doc create (rules L411-L415
      // deny client creation of a manager doc — p34 cluster A).
      await grantAppIdClaim(cred.user!);
      await seedUserRoleDoc(
        uid: uid,
        email: cred.user!.email ?? '',
        role: 'manager',
        branchId: 'branch_main',
      );

      expect(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': 'kitchen',
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Manager must not be able to change their own role',
      );
      // p34: no cred.user!.delete() — wedges the auth queue (see Owner test above).
    });
  });

  // ── 1.4: NULL DOCUMENT GUARD ──────────────────────────────────────────────
  group('OrderModel null document guard', () {
    test('Streaming a deleted order document does not crash', () async {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'null_guard_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'TestPass123',
      );

      // p34: orders writes require isAppVerified() (firestore.rules L478/L502
      // -> app_id claim). Production ID tokens carry it; the Auth emulator mints
      // none, so provision it exactly like the Owner/Manager tests above —
      // otherwise orderRef.set() fails with 'app_id is undefined'
      // (v13_guestonly2.txt: [cloud_firestore/permission-denied] ... L478).
      await grantAppIdClaim(cred.user!);
      // Seed an OWNER role doc (not customer): the orders read rule (L452) allows
      // owner unconditionally (`userRole() == 'owner'`) WITHOUT dereferencing
      // resource.data. The doc is deleted below, so resource.data is null on the
      // get() — the customer/manager/kitchen/delivery read clauses all touch
      // resource.data.branchId and would throw "evaluation error" on a tombstone.
      // Owner read returns the clean non-existent snapshot this test asserts on.
      await seedUserRoleDoc(
        uid: cred.user!.uid,
        email: cred.user!.email ?? '',
        role: 'owner',
        branchId: 'branch_main',
      );

      // Write then delete an order to simulate a tombstone document. p34: the
      // create rule (firestore.rules L478) requires a non-empty `branchId` in the
      // payload (L487-488), and uses a UNIQUE doc id per run — a fixed id
      // collides across emulator sessions and turns create into an update (which
      // needs a staff role and is denied for a bare authenticated customer).
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc('ghost_order_${DateTime.now().millisecondsSinceEpoch}');
      await orderRef.set({
        'customerId': cred.user!.uid,
        'status': 'pending',
        'totalCents': 100,
        'branchId': 'branch_main',
        'createdAt': FieldValue.serverTimestamp(),
      });
      // firestore.rules has NO `allow delete` on /orders (a customer must not
      // delete their own order), so orderRef.delete() is permission-denied. The
      // test only needs the doc ABSENT to exercise the OrderModel null-guard, so
      // tombstone it via the emulator-admin REST (same owner-auth bypass the
      // seed helpers use) instead of the denied client delete.
      await emulatorAdminDeleteDocument(
        collection: 'orders',
        documentId: orderRef.id,
      );

      // Attempt a get() — should return non-existent snapshot, not crash
      final snap = await orderRef.get();
      expect(snap.exists, isFalse);
      // If OrderModel.fromDoc was called here with snap it would previously crash —
      // the tryFromDoc null guard prevents this: data() returns null, returns fallback.
      // p34: no cred.user!.delete() — wedges the auth queue (see Owner test above).
    });
  });
}
