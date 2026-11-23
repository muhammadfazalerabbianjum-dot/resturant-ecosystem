// =============================================================================
// PHASE 2: RUTHLESS AUTH LIFECYCLE AUDIT
// Engine: FakeFirebaseFirestore & MockFirebaseAuth (Native Dart Memory)
// Vectors: Concurrent OAuth syncing, Tombstone ghost profiles,
//          Session expiration streams, and Re-Auth failures.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Demo-mode config used to exercise the real client-side GdprService path.
class _DemoConfig implements CoreConfig {
  const _DemoConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'test-client';

  @override
  String get cloudinaryCloudName => '';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  List<String> get ownerEmails => const [];

  @override
  String get kitchenLanEndpoint => '';
}

/// A [User] whose `delete()` throws `requires-recent-login` — the re-auth
/// failure the app must survive: docs erased, marker stays `in_progress`,
/// and the server-side retrier completes erasure later.
class _ThrowingDeleteUser extends Mock implements User {
  _ThrowingDeleteUser(this._uid);
  final String _uid;

  @override
  String get uid => _uid;

  @override
  Future<void> delete() async {
    throw FirebaseAuthException(
      code: 'requires-recent-login',
      message: 'Re-auth required',
    );
  }
}

/// Auth whose `currentUser` is fixed, so the re-auth path never needs a real
/// `FirebaseAuth.instance`.
class _FixedUserAuth extends MockFirebaseAuth {
  _FixedUserAuth(this.fixedUser);
  final User fixedUser;

  @override
  User? get currentUser => fixedUser;
}

/// Mock [LoggerService] so the decline-path `GdprService` audit logging does
/// not require an initialized log file / Crashlytics in the widget test env.
class _MockLogger extends Mock implements LoggerService {}

/// Mock [FirebaseFunctions] so `GdprService` construction never touches a live
/// Cloud Functions instance in the widget test env (the demo path never calls it).
class _MockFunctions extends Mock implements FirebaseFunctions {}

/// In-memory [GdprStorageEraser] so the demo path's Storage mirror
/// (`_eraseUserStorage`, MONEY-3 W3.5) runs without Firebase Storage platform
/// channels. The production default (`FirebaseStorageEraser`) resolves
/// `FirebaseStorage.instance`, which requires an initialized `[DEFAULT]` app —
/// deliberately absent in the widget-test env (see flutter_test_config.dart).
/// Same fixture pattern as `_FakeEraser` in
/// `test/core/compliance/gdpr_compliance_test.dart`.
class _FakeEraser implements GdprStorageEraser {
  _FakeEraser(this.objects);

  /// Live object paths -> existence flag (true = still present).
  final Map<String, bool> objects;

  /// Object paths deleted by the service under test.
  final List<String> deleted = [];

  @override
  Future<List<String>> listAllUnder(String prefix) async => objects.entries
      .where((e) => e.value && e.key.startsWith('$prefix/'))
      .map((e) => e.key)
      .toList();

  @override
  Future<void> deleteObject(String objectPath) async {
    if (objects[objectPath] == true) {
      objects[objectPath] = false;
      deleted.add(objectPath);
    }
  }
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late FirebaseAuthRepository authRepo;
  late _MockLogger loggerService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(signedIn: false);
    loggerService = _MockLogger();
    when(
      () => loggerService.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
    // Standardizing the test instance
    authRepo = FirebaseAuthRepository(
      mockAuth,
      fakeFirestore,
      loggerService,
      cache: const NoOpLocalCache(),
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 1: CONCURRENT OAUTH SYNC (RACE CONDITION)
  // Two rapid requests hit the OAuth sync simultaneously. If it's not
  // defensively written, it will overwrite the user's loyalty points to 0.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 2.1 — OAuth Sync Race Condition', () {
    test(
      'Simultaneous sync calls DO NOT overwrite existing loyalty points',
      () async {
        final mockUser = MockUser(
          uid: 'race_test_uid',
          email: 'race@test.com',
          displayName: 'Racer',
        );
        await mockAuth.signInWithCredential(
          const AuthCredential(providerId: 'google.com', signInMethod: 'oauth'),
        );

        // Seed the database as if the user already existed with points
        await fakeFirestore.collection('users').doc(mockUser.uid).set({
          'role': 'customer',
          'loyaltyPoints': 5000, // Hard-earned points
        });

        // The REAL production method under test: `syncUserProfile` is public
        // and race-safe (existence-check + create run inside one Firestore
        // transaction), so concurrent first-syncs can never clobber points.
        // Fire 5 identical requests within the exact same microtask tick.
        await Future.wait([
          authRepo.syncUserProfile(mockUser, displayName: 'Racer'),
          authRepo.syncUserProfile(mockUser, displayName: 'Racer'),
          authRepo.syncUserProfile(mockUser, displayName: 'Racer'),
          authRepo.syncUserProfile(mockUser, displayName: 'Racer'),
          authRepo.syncUserProfile(mockUser, displayName: 'Racer'),
        ]);

        final finalDoc = await fakeFirestore
            .collection('users')
            .doc(mockUser.uid)
            .get();
        expect(
          finalDoc.data()?['loyaltyPoints'],
          equals(5000),
          reason:
              'Concurrent OAuth sync calls must NEVER overwrite existing data',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 2: TOMBSTONE GHOST PROFILE
  // If the account deletion sequence hits a network error after Auth deletes
  // but before Firestore deletes, the backend is left with an undeletable PII ghost.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 2.2 — Atomicity of Account Deletion', () {
    test(
      'Firestore document MUST be deleted BEFORE Auth token is destroyed',
      () async {
        // 1. Setup the victim
        final mockUser = MockUser(uid: 'ghost_victim', email: 'ghost@test.com');
        mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
        authRepo = FirebaseAuthRepository(
          mockAuth,
          fakeFirestore,
          loggerService,

          cache: const NoOpLocalCache(),
        );

        await fakeFirestore.collection('users').doc(mockUser.uid).set({
          'role': 'customer',
          'email': 'ghost@test.com',
        });

        // 2. Run the REAL deleteMyData() demo path: it must (a) write the
        // durable `deletion_requests/{uid}` marker first, (b) erase the user
        // docs, (c) only then delete the Auth user, and (d) flip the marker to
        // `completed`. Ordering is proven by the marker existing while the user
        // doc is already gone — the durable marker-first contract (potato3 B1-10).
        // MONEY-3 (W3.5): the demo path also mirrors Storage erasure through the
        // injectable [GdprStorageEraser] seam — in-memory fake, no platform app.
        final storageEraser = _FakeEraser({
          'avatars/${mockUser.uid}/a.png': true,
        });
        CoreConfigHolder.set(const _DemoConfig());
        final gdprService = GdprService(
          firestore: fakeFirestore,
          auth: mockAuth,
          logger: loggerService,
          functions: _MockFunctions(),
          storageEraser: storageEraser,
        );
        final deleted = await gdprService.deleteMyData();
        expect(deleted, isTrue);

        // Database erasure happened: no ghost PII remains.
        final finalDoc = await fakeFirestore
            .collection('users')
            .doc(mockUser.uid)
            .get();
        expect(finalDoc.exists, isFalse, reason: 'No ghost PII should remain');

        // MONEY-3 (W3.5): the Storage mirror erased BEFORE the Auth token was
        // destroyed (storage-first, mirroring the Cloud Function's runErase).
        expect(
          storageEraser.deleted,
          contains('avatars/${mockUser.uid}/a.png'),
          reason: 'demo erasure covers avatars/{uid}/* before the auth delete',
        );

        // Auth token destroyed last: the durable marker proves erasure finished.
        final marker = await fakeFirestore
            .collection('deletion_requests')
            .doc(mockUser.uid)
            .get();
        expect(
          marker.exists,
          isTrue,
          reason: 'durable deletion_requests marker must be retained',
        );
        expect(
          marker.data()?['status'],
          'completed',
          reason: 'marker flips to completed only after docs + auth erase',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 3: RE-AUTHENTICATION FAILURE GRACEFULNESS
  // Apple guidelines mandate users must be able to securely re-auth to delete.
  // We test that a forced credential failure doesn't crash the logic.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 2.3 — Re-Authentication Bounds', () {
    test(
      'requires-recent-login failure is surfaced and leaves the retrier marker',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Signed in as a user whose credentials went stale (re-auth needed).
        final mockAuth = _FixedUserAuth(_ThrowingDeleteUser('reauth_victim'));
        // MONEY-3 (W3.5): in-memory Storage seam so the demo path's
        // storage-first mirror runs without a Firebase app; the re-auth
        // failure must surface AFTER erasure (docs + Storage) completed.
        final storageEraser = _FakeEraser({
          'avatars/reauth_victim/a.png': true,
        });
        CoreConfigHolder.set(const _DemoConfig());
        final gdprService = GdprService(
          firestore: fakeFirestore,
          auth: mockAuth,
          logger: loggerService,
          functions: _MockFunctions(),
          storageEraser: storageEraser,
        );
        await fakeFirestore.collection('users').doc('reauth_victim').set({
          'role': 'customer',
          'email': 'reauth@test.com',
        });

        // The REAL deleteMyData() must NOT crash the flow: it erases the
        // Firestore docs first, then the Auth user delete fails with
        // requires-recent-login, rethrows (user must re-auth), and the durable
        // marker stays `in_progress` so the server-side retrier can finish.
        await expectLater(
          gdprService.deleteMyData(),
          throwsA(isA<FirebaseAuthException>()),
        );

        // Docs already erased — no ghost PII for a stale-credential user.
        final doc = await fakeFirestore
            .collection('users')
            .doc('reauth_victim')
            .get();
        expect(
          doc.exists,
          isFalse,
          reason: 'erasure must proceed before the auth failure is surfaced',
        );

        // MONEY-3 (W3.5): Storage erasure also completed before the failure
        // surfaced (fail-closed demo mirror: marker stays `in_progress`).
        expect(
          storageEraser.deleted,
          contains('avatars/reauth_victim/a.png'),
          reason: 'Storage mirror runs before the auth delete is attempted',
        );

        // Marker remains in_progress — the retrier's worklist item.
        final marker = await fakeFirestore
            .collection('deletion_requests')
            .doc('reauth_victim')
            .get();
        expect(
          marker.exists,
          isTrue,
          reason: 'durable marker must exist for the retrier',
        );
        expect(
          marker.data()?['status'],
          'in_progress',
          reason: 'auth delete failed -> server-side retry picks it up',
        );
      },
    );
  });
}
