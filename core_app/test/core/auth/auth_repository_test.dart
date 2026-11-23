import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core/core.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggerService extends Mock implements LoggerService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

/// Test seam for signOut's SDK-teardown steps (packages/core auth_repository).
///
/// WHY this exists (neither step is under test — both are real production
/// behavior that the fake cannot model):
/// 1. `terminate()` — FakeFirebaseFirestore inherits the REAL cloud_firestore
///    implementation, which calls the platform channel and has no
///    test-platform backing (fake_cloud_firestore ships no terminate
///    override), so it throws in unit tests.
/// 2. `clearPersistence()` — the fake's override WIPES ITS ENTIRE in-memory
///    store, but on devices clearPersistence only drops the OFFLINE cache;
///    server documents survive. A no-op keeps the fake's store modeling the
///    SERVER side, so the test can assert the SURGICAL fcmToken /
///    fcmLastUpdated field deletion (with the rest of the doc intact).
///
/// Every data operation under test (seeds, the users/{uid} update, reads)
/// runs on the real in-memory store — nothing about the signOut data
/// contract is suppressed.
class _SignOutFakeFirestore extends FakeFirebaseFirestore {
  @override
  Future<void> terminate() async {}

  @override
  Future<void> clearPersistence() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('FirebaseAuthRepository — Firestore Logic', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockLoggerService mockLogger;
    late FirebaseAuthRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockLogger = MockLoggerService();
      when(
        () => mockLogger.error(any(), any(), stack: any(named: 'stack')),
      ).thenAnswer((_) async {});
      repository = FirebaseAuthRepository(
        MockFirebaseAuth(),
        fakeFirestore,
        mockLogger,
        // P2-1a: the wipe is injected; these tests assert Firestore logic.
        cache: const NoOpLocalCache(),
      );
    });

    group('getUserData', () {
      test('returns null when user document does not exist', () async {
        final result = await repository.getUserData('nonexistent_uid');
        expect(result, isNull);
      });

      test('returns UserModel when user document exists', () async {
        await fakeFirestore.collection('users').doc('uid_1').set({
          'id': 'uid_1',
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'customer',
          'loyaltyPoints': 0,
          'tier': 'starter',
          'isOnline': false,
          'assignedOrderIds': [],
          'createdAt': Timestamp.now(),
        });

        final result = await repository.getUserData('uid_1');
        expect(result, isNotNull);
        expect(result!.id, equals('uid_1'));
        expect(result.email, equals('test@example.com'));
        expect(result.name, equals('Test User'));
        expect(result.role, equals(UserRole.customer));
      });

      test('returns UserModel even with empty data doc', () async {
        await fakeFirestore.collection('users').doc('empty_uid').set({
          'id': 'empty_uid',
        });

        final result = await repository.getUserData('empty_uid');
        expect(result, isNotNull);
        expect(result!.id, equals('empty_uid'));
        expect(result.role, equals(UserRole.customer));
      });
    });

    group('syncUserProfile (B8-1 locale write)', () {
      late MockUser mockUser;

      setUp(() {
        mockUser = MockUser();
        when(() => mockUser.uid).thenReturn('uid_locale');
        when(() => mockUser.email).thenReturn('locale@example.com');
        when(() => mockUser.displayName).thenReturn('Locale User');
      });

      test('writes the resolved Arabic locale when requested', () async {
        await repository.syncUserProfile(mockUser, locale: 'ar');
        final doc = await fakeFirestore
            .collection('users')
            .doc('uid_locale')
            .get();
        expect(doc.data(), isNotNull);
        expect(doc.data()!['locale'], equals('ar'));
        expect(doc.data()!['role'], equals('customer'));
      });

      test('defaults to the platform locale (en in the test env)', () async {
        await repository.syncUserProfile(mockUser);
        final doc = await fakeFirestore
            .collection('users')
            .doc('uid_locale')
            .get();
        expect(doc.data(), isNotNull);
        expect(doc.data()!['locale'], equals('en'));
      });

      test('is idempotent: an existing profile is never overwritten', () async {
        await fakeFirestore.collection('users').doc('uid_locale').set({
          'role': 'owner',
          'locale': 'fr',
        });
        await repository.syncUserProfile(mockUser, locale: 'ar');
        final doc = await fakeFirestore
            .collection('users')
            .doc('uid_locale')
            .get();
        expect(doc.data()!['role'], equals('owner'));
        expect(doc.data()!['locale'], equals('fr'));
      });
    });

    group('signOut — FCM token cleanup (01-P1-D, batch RULES-2)', () {
      test(
        'removes fcmToken/fcmLastUpdated from users/{uid} (no cross-user push leak)',
        () async {
          final signOutStore = _SignOutFakeFirestore();
          final mockAuth = MockFirebaseAuth();
          final mockUser = MockUser();
          when(() => mockUser.uid).thenReturn('uid_fcm');
          when(() => mockAuth.currentUser).thenReturn(mockUser);
          when(() => mockAuth.signOut()).thenAnswer((_) async {});
          final fcmRepo = FirebaseAuthRepository(
            mockAuth,
            signOutStore,
            mockLogger,
            cache: const NoOpLocalCache(),
          );

          await signOutStore.collection('users').doc('uid_fcm').set({
            'name': 'Shared Device User',
            'fcmToken': 'stale-device-token',
            'fcmLastUpdated': Timestamp.now(),
          });

          await fcmRepo.signOut();

          final doc = await signOutStore
              .collection('users')
              .doc('uid_fcm')
              .get();
          expect(doc.data(), isNotNull);
          expect(
            doc.data()!.containsKey('fcmToken'),
            isFalse,
            reason: 'signOut must delete users/{uid}.fcmToken (01-P1-D)',
          );
          expect(
            doc.data()!.containsKey('fcmLastUpdated'),
            isFalse,
            reason: 'signOut must delete users/{uid}.fcmLastUpdated',
          );
          expect(
            doc.data()!['name'],
            equals('Shared Device User'),
            reason: 'only the FCM fields are removed — the rest survives',
          );
        },
      );

      test(
        'best-effort: a missing user document never breaks signOut',
        () async {
          final signOutStore = _SignOutFakeFirestore();
          final mockAuth = MockFirebaseAuth();
          final mockUser = MockUser();
          when(() => mockUser.uid).thenReturn('uid_ghost');
          when(() => mockAuth.currentUser).thenReturn(mockUser);
          when(() => mockAuth.signOut()).thenAnswer((_) async {});
          final fcmRepo = FirebaseAuthRepository(
            mockAuth,
            signOutStore,
            mockLogger,
            cache: const NoOpLocalCache(),
          );

          await fcmRepo.signOut();

          final doc = await signOutStore
              .collection('users')
              .doc('uid_ghost')
              .get();
          expect(
            doc.exists,
            isFalse,
            reason:
                'update() on a missing doc is caught best-effort — '
                'signOut must not conjure a user document',
          );
        },
      );
    });

    group('FallbackAuthRepository', () {
      late FallbackAuthRepository fallback;

      setUp(() {
        fallback = FallbackAuthRepository(
          LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
        );
      });

      test('returns null for currentUser', () {
        expect(fallback.currentUser, isNull);
      });

      test('returns empty stream for authStateChanges', () {
        expect(fallback.authStateChanges(), isA<Stream<User?>>());
      });

      test('getUserData returns null', () async {
        final result = await fallback.getUserData('any_uid');
        expect(result, isNull);
      });

      test('signOut does not throw', () async {
        await fallback.signOut();
      });

      test('signInAnonymously does not throw', () async {
        await fallback.signInAnonymously();
      });

      test('signInWithApple does not throw', () async {
        await fallback.signInWithApple();
      });

      test('signInWithGoogle does not throw', () async {
        await fallback.signInWithGoogle();
      });

      test('getUserData returns null for empty uid', () async {
        final result = await fallback.getUserData('');
        expect(result, isNull);
      });

      test('authStateChanges returns a stream', () {
        final stream = fallback.authStateChanges();
        expect(stream, isA<Stream<User?>>());
      });
    });
  });

  group('FallbackAuthRepository - Edge Cases', () {
    late FallbackAuthRepository fallback;

    setUp(() {
      fallback = FallbackAuthRepository(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
    });

    test(
      'signInAnonymously can be called multiple times without error',
      () async {
        await fallback.signInAnonymously();
        await fallback.signInAnonymously();
        await fallback.signInAnonymously();
      },
    );

    test('signInWithGoogle handles repeated calls', () async {
      await fallback.signInWithGoogle();
      await fallback.signInWithGoogle();
    });

    test('signInWithApple handles repeated calls', () async {
      await fallback.signInWithApple();
      await fallback.signInWithApple();
    });

    test('getUserData with null uid returns null', () async {
      final result = await fallback.getUserData(null as String? ?? '');
      expect(result, isNull);
    });

    test('authStateChanges stream can be listened multiple times', () async {
      final stream1 = fallback.authStateChanges();
      final stream2 = fallback.authStateChanges();
      expect(stream1, isA<Stream<User?>>());
      expect(stream2, isA<Stream<User?>>());
    });
  });

  // P2-1a (D-050): the sign-out wipe is now INJECTED. These two cases are the
  // contract that keeps the P0-07 cross-user leak closed while the store moved
  // behind an interface: it must still be called, exactly once, and a broken
  // store must not turn sign-out into a failure.
  group('P2-1a — the local-cache wipe is injected', () {
    late FakeFirebaseFirestore firestore;
    late MockLoggerService logger;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      logger = MockLoggerService();
      when(
        () => logger.error(any(), any(), stack: any(named: 'stack')),
      ).thenAnswer((_) async {});
    });

    test('signOut clears the injected cache exactly once', () async {
      final cache = _SpyLocalCache();
      final repo = FirebaseAuthRepository(
        MockFirebaseAuth(),
        firestore,
        logger,
        cache: cache,
      );

      await repo.signOut();

      expect(cache.calls, 1);
    });

    test('a throwing cache is logged and sign-out still completes', () async {
      final cache = _SpyLocalCache(throwOnClear: true);
      final repo = FirebaseAuthRepository(
        MockFirebaseAuth(),
        firestore,
        logger,
        cache: cache,
      );

      await repo.signOut();

      expect(cache.calls, 1);
      verify(
        () => logger.error(
          any(),
          'AuthSignOutClearAllError',
          stack: any(named: 'stack'),
        ),
      ).called(1);
    });
  });
}

/// Records the wipe without owning a store.
class _SpyLocalCache implements LocalCache {
  _SpyLocalCache({this.throwOnClear = false});

  final bool throwOnClear;
  int calls = 0;

  @override
  Future<void> clearAll() async {
    calls++;
    if (throwOnClear) throw StateError('cache is broken');
  }
}
