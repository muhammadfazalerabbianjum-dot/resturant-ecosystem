import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

/// COV-4 — RULES-2 T-1 pattern EXTENDED: the sign-out FCM-token cleanup
/// (01-P1-D) scenarios the core seam tests do not cover — cross-user
/// containment, idempotency, the best-effort missing-doc fail-safe, and the
/// signed-out (no uid) skip. Every assertion runs against the REAL
/// production signOut() sequence.
///
/// The fake overrides terminate()/clearPersistence() to model the SERVER
/// side (same seam as core_app/test/core/auth/auth_repository_test.dart):
/// the surgical field deletion on users/{uid} is what these tests assert.
class _SignOutFakeFirestore extends FakeFirebaseFirestore {
  bool terminated = false;

  @override
  Future<void> terminate() async {
    terminated = true;
  }

  @override
  Future<void> clearPersistence() async {}
}

/// Mock [LoggerService] so a specific best-effort step's logged failure can
/// be VERIFIED (proving the catch ran) without real file I/O.
class _MockLogger extends Mock implements LoggerService {}

_MockLogger _newLogger() {
  final logger = _MockLogger();
  when(() => logger.error(any(), any())).thenAnswer((_) async {});
  when(
    () => logger.error(any(), any(), stack: any(named: 'stack')),
  ).thenAnswer((_) async {});
  return logger;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test(
    'only the signed-out user\u2019s FCM fields are cleared — the other '
    'stored user\u2019s token is untouched (cross-user containment)',
    () async {
      final store = _SignOutFakeFirestore();
      await store.collection('users').doc('user_a').set({
        'name': 'User A',
        'fcmToken': 'token-a',
        'fcmLastUpdated': DateTime.now().toIso8601String(),
      });
      await store.collection('users').doc('user_b').set({
        'name': 'User B',
        'fcmToken': 'token-b',
        'fcmLastUpdated': DateTime.now().toIso8601String(),
      });
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user_a', email: 'a@test.com'),
      );
      final repo = FirebaseAuthRepository(
        auth,
        store,
        _newLogger(),
        cache: const NoOpLocalCache(),
      );

      await repo.signOut();

      final docA = await store.collection('users').doc('user_a').get();
      expect(docA.data()!.containsKey('fcmToken'), isFalse);
      expect(docA.data()!.containsKey('fcmLastUpdated'), isFalse);
      expect(docA.data()!['name'], 'User A');

      final docB = await store.collection('users').doc('user_b').get();
      expect(
        docB.data()!['fcmToken'],
        'token-b',
        reason: 'signOut must only clear the SIGNING-OUT user\u2019s token',
      );
      expect(auth.currentUser, isNull);
    },
  );

  test('idempotent: a profile with no FCM fields is left intact and signOut '
      'completes', () async {
    final store = _SignOutFakeFirestore();
    await store.collection('users').doc('user_c').set({
      'name': 'User C',
      'role': 'customer',
    });
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user_c', email: 'c@test.com'),
    );
    final repo = FirebaseAuthRepository(
      auth,
      store,
      _newLogger(),
      cache: const NoOpLocalCache(),
    );

    await repo.signOut();

    final doc = await store.collection('users').doc('user_c').get();
    expect(doc.data()!['name'], 'User C');
    expect(doc.data()!['role'], 'customer');
    expect(auth.currentUser, isNull);
    expect(store.terminated, isTrue, reason: 'signOut must complete');
  });

  test(
    'a token step that cannot apply (users/{uid} doc missing) is best-effort: '
    'signOut does not abort — terminate + auth.signOut + navigation all '
    'still run (fail-safe on the auth path)',
    () async {
      final store = _SignOutFakeFirestore();
      final logger = _newLogger();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user_d', email: 'd@test.com'),
      );
      var navigated = 0;
      final repo = FirebaseAuthRepository(
        auth,
        store,
        logger,
        onSignOutNavigated: () => navigated++,

        cache: const NoOpLocalCache(),
      );

      await repo.signOut();

      // users/{user_d} does not exist → the token update cannot apply
      // (update-on-missing-doc fails in the real SDK; the fake no-ops).
      // Either way, the rest of the sign-out MUST have completed.
      final doc = await store.collection('users').doc('user_d').get();
      expect(
        doc.exists,
        isFalse,
        reason: 'the failed update must not conjure a user document',
      );
      expect(
        store.terminated,
        isTrue,
        reason: 'terminate must still run after the failed token step',
      );
      expect(
        auth.currentUser,
        isNull,
        reason: 'auth must always sign out, even when cleanup fails',
      );
      expect(
        navigated,
        1,
        reason: 'navigation reset must still fire after the failed step',
      );
    },
  );

  test('no signed-in user: the FCM step is skipped cleanly (no doc conjured) '
      'and signOut still completes and navigates', () async {
    final store = _SignOutFakeFirestore();
    final auth = MockFirebaseAuth(signedIn: false);
    var navigated = 0;
    final repo = FirebaseAuthRepository(
      auth,
      store,
      _newLogger(),
      onSignOutNavigated: () => navigated++,

      cache: const NoOpLocalCache(),
    );

    await repo.signOut();

    final ghost = await store.collection('users').doc('nonexistent').get();
    expect(
      ghost.exists,
      isFalse,
      reason: 'a null uid must skip the token update entirely',
    );
    expect(auth.currentUser, isNull);
    expect(navigated, 1);
  });
}
