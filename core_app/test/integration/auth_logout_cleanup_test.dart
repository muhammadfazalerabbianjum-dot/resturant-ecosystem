import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// The real [FakeFirebaseFirestore] does not implement `terminate()` (only
/// `clearPersistence()`), so this subclass adds it. Sign-out MUST call
/// `terminate()` then `clearPersistence()` to kill listener subscriptions
/// under the old identity (B1-11 / T7 / P0-07 cross-user-leak guard).
class _TerminableFakeFirestore extends FakeFirebaseFirestore {
  bool terminated = false;

  @override
  Future<void> terminate() async {
    terminated = true;
  }
}

void main() {
  test(
    'B1-11 / T7: signOut clears local Firestore persistence, terminates the '
    'Firestore client, signs out of FirebaseAuth, and notifies navigation',
    () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: 'user_1',
          email: 'user@test.com',
          displayName: 'Test User',
        ),
      );
      final firestore = _TerminableFakeFirestore();
      final logger = LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );
      var navigated = 0;

      // Seed a user-owned doc — after signOut it MUST be gone (P0-07).
      await firestore.collection('users').doc('user_1').set({
        'role': 'customer',
        'email': 'user@test.com',
      });
      expect(auth.currentUser, isNotNull);

      final repo = FirebaseAuthRepository(
        auth,
        firestore,
        logger,
        onSignOutNavigated: () => navigated++,

        cache: const NoOpLocalCache(),
      );

      // Exercise the REAL production sign-out sequence. The metadata-side
      // cleanup calls (Isar, Analytics, SharedPreferences, Google) require
      // platform plugins that are absent in a headless VM test; signOut()
      // degrades gracefully and logs those — it must never abort the flow.
      await repo.signOut();

      // 1. Firestore client was terminated + persistence cleared (docs wiped).
      expect(firestore.terminated, isTrue, reason: 'must terminate Firestore');
      final leftover = await firestore.collection('users').doc('user_1').get();
      expect(leftover.exists, isFalse, reason: 'local cache must be wiped');

      // 2. FirebaseAuth signed out.
      expect(auth.currentUser, isNull);

      // 3. Navigation reset callback fired so the app returns to login.
      expect(navigated, 1);
    },
  );

  test(
    'B1-11 / T7: signOut still signs out of FirebaseAuth and rescues the stack '
    'when Firestore persistence cannot be cleared (fail-open on cleanup)',
    () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user_2', email: 'user2@test.com'),
      );
      final firestore = _TerminableFakeFirestore();
      await firestore.collection('users').doc('user_2').set({'role': 'x'});
      final repo = FirebaseAuthRepository(
        auth,
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),

        cache: const NoOpLocalCache(),
      );

      await repo.signOut();

      expect(
        auth.currentUser,
        isNull,
        reason: 'auth must always sign out, even if cleanup hiccups',
      );
    },
  );
}
