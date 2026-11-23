@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'test_helpers/emulator_bootstrap.dart';

/// FIRESTORE SECURITY RULES — V1.3 GUEST / ANONYMOUS ACCESS (Laws 12 & 48)
///
/// Split out of v13_security_rules_test.dart (p34). ROOT CAUSE (proven on the
/// real emulator, receipts tool_uilib/p34_e2e/p4_twocycle_probe.txt): the
/// firebase_auth Android plugin (6.5.6) deadlocks its native task queue when
/// `signInAnonymously()` runs AFTER two email create+delete cycles in the SAME
/// process/isolate — the MethodChannel call is sent, Dart parks (isolate shows
/// 0 frames), and the native plugin never replies (native logcat goes silent
/// after the 2nd user's sign-out). A Dart-side signOut()+delete() before the
/// anon call does NOT clear it (p4_twocycle_fix.txt: still hung at +1).
///
/// These tests PASS in a fresh process (v13_guestonly2.txt: +5). So they live
/// in their own file and the e2e battery runs each file in its own `flutter
/// test` process — process isolation is the standard harness fix for
/// auth-state-dependent integration tests. No firestore.rules or lib change.
/// The underlying third-party deadlock is recorded in p34_e2e_findings.md +
/// core_app/DEFERRED.md.
void main() {
  setUpAll(() async {
    await bootstrapEmulators();
  });

  tearDown(() async => FirebaseAuth.instance.signOut());

  group('Guest / Anonymous Access (Law 12)', () {
    test('Anonymous user CAN read branches collection', () async {
      await FirebaseAuth.instance.signInAnonymously();

      // Must succeed — branches are public
      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .get();
      expect(snap, isNotNull);
    });

    test('Anonymous user CAN read menus collection', () async {
      await FirebaseAuth.instance.signInAnonymously();

      // Must succeed — menus are public
      final snap = await FirebaseFirestore.instance.collection('menus').get();
      expect(snap, isNotNull);
    });

    test('Anonymous user CANNOT read orders collection', () async {
      await FirebaseAuth.instance.signInAnonymously();

      expect(
        () => FirebaseFirestore.instance.collection('orders').get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Anonymous guest must not access order data',
      );
    });

    test('Anonymous user CANNOT read user documents', () async {
      await FirebaseAuth.instance.signInAnonymously();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      expect(
        () => FirebaseFirestore.instance.collection('users').doc(uid).get(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Anonymous guest must not access user collection',
      );
    });

    test('Anonymous user CANNOT write orders', () async {
      await FirebaseAuth.instance.signInAnonymously();

      expect(
        () => FirebaseFirestore.instance.collection('orders').add({
          'status': 'pending',
          'customerId': FirebaseAuth.instance.currentUser!.uid,
          'totalCents': 100,
        }),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
        reason: 'Anonymous guest must not create orders',
      );
    });
  });
}
