import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mock_firebase.dart';
import 'helpers/recording_logger.dart';

/// In-memory [AuthRepository] double for the Riverpod wiring tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Stream<User?>? authState, this.userData})
    : _authState = authState ?? const Stream<User?>.empty();

  final Stream<User?> _authState;
  final UserModel? userData;

  @override
  Stream<User?> authStateChanges() => _authState;

  @override
  User? get currentUser => null;

  @override
  Future<UserModel?> getUserData(String uid) async => userData;

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {}

  @override
  Future<void> signUp(String email, String password, String name) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

/// CORE-COV Tier-1 AUTH suite: sign-in error mapping, the signUp profile-doc
/// contract, the signOut FCM-cleanup sequence (RULES-2 T-1 extension),
/// getUserData (incl. QUEUE-2 permanent-failure classification), the Riverpod
/// auth providers, and the [UserModel] serialization contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingLogger logger;
  late MockFirebaseAuth auth;
  late MockFirebaseUser user;
  late MockUserCredential credential;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    logger = RecordingLogger();
    auth = MockFirebaseAuth();
    user = MockFirebaseUser();
    credential = MockUserCredential();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FirebaseAuthRepository — sign-in error mapping (Law 46)', () {
    test(
      'email sign-in RETHROWS the typed auth failure (PERF-1 H-1: the login '
      'screen maps the code — a generic wrap was silently swallowed)',
      () async {
        final repo = FirebaseAuthRepository(
          auth,
          FakeFirebaseFirestore(),
          logger,

          cache: const NoOpLocalCache(),
        );
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          FirebaseAuthException(code: 'wrong-password', message: 'invalid'),
        );

        await expectLater(
          repo.signInWithEmailAndPassword('a@b.com', 'pw'),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(
          logger.errors,
          contains('FirebaseAuthRepository_signInWithEmailAndPassword'),
        );
      },
    );

    test('anonymous sign-in maps the auth failure', () async {
      final repo = FirebaseAuthRepository(
        auth,
        FakeFirebaseFirestore(),
        logger,

        cache: const NoOpLocalCache(),
      );
      when(() => auth.signInAnonymously()).thenThrow(
        FirebaseException(
          plugin: 'firebase_auth',
          code: 'network-request-failed',
        ),
      );

      await expectLater(
        repo.signInAnonymously(),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString().contains('Please check your internet connection.'),
          ),
        ),
      );
    });
  });
  group('FirebaseAuthRepository — signUp profile-doc contract', () {
    test(
      'new users get a customer profile with push locale + zero loyalty',
      () async {
        final fake = FakeFirebaseFirestore();
        final repo = FirebaseAuthRepository(
          auth,
          fake,
          logger,
          cache: const NoOpLocalCache(),
        );
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);
        when(() => user.uid).thenReturn('u-signup');
        when(() => user.email).thenReturn('a@b.com');
        when(() => user.displayName).thenReturn(null);
        when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
        when(() => user.reload()).thenAnswer((_) async {});

        await repo.signUp('a@b.com', 'pw', 'Amira');

        final doc = await fake.collection('users').doc('u-signup').get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['role'], 'customer');
        expect(data['locale'], 'en');
        expect(data['loyaltyPoints'], 0);
        expect(data['tier'], 'starter');
        expect(data['name'], 'Amira');
        expect(data['assignedOrderIds'], <String>[]);
      },
    );
  });

  group('FirebaseAuthRepository — signOut FCM cleanup (RULES-2 T-1)', () {
    test(
      'clears users/{uid}.fcmToken BEFORE terminating Firestore, then signs out',
      () async {
        final fake = FakeFirebaseFirestore();
        await fake.collection('users').doc('u-out').set(<String, dynamic>{
          'fcmToken': 'tok',
          'fcmLastUpdated': Timestamp.now(),
          'role': 'manager',
        });
        final db = MockFirebaseFirestore();
        when(() => db.collection('users')).thenReturn(fake.collection('users'));
        bool? tokenClearedAtTerminate;
        when(() => db.terminate()).thenAnswer((_) async {
          final doc = await fake.collection('users').doc('u-out').get();
          tokenClearedAtTerminate = !doc.data()!.containsKey('fcmToken');
        });
        when(() => db.clearPersistence()).thenAnswer((_) async {});
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u-out');
        when(() => auth.signOut()).thenAnswer((_) async {});

        var navigated = 0;
        final repo = FirebaseAuthRepository(
          auth,
          db,
          logger,
          onSignOutNavigated: () => navigated++,

          cache: const NoOpLocalCache(),
        );
        await repo.signOut();

        // The FCM field wipe (leak-proof on shared devices) ran BEFORE the
        // Firestore SDK was terminated — the ordering the fix depends on.
        expect(tokenClearedAtTerminate, isTrue);
        final doc = await fake.collection('users').doc('u-out').get();
        expect(doc.data()!.containsKey('fcmToken'), isFalse);
        expect(doc.data()!.containsKey('fcmLastUpdated'), isFalse);
        verify(() => db.terminate()).called(1);
        verify(() => db.clearPersistence()).called(1);
        verify(() => auth.signOut()).called(1);
        expect(navigated, 1);
        // Platform-channel cleanup steps (Isar/FCM/Analytics) are best-effort
        // and MAY log in a test VM without platform channels — but the
        // TOP-LEVEL sign-out must never have failed.
        expect(
          logger.errors.where((e) => e == 'FirebaseAuthRepository_signOut'),
          isEmpty,
        );
      },
    );

    test('cleanup failure still signs the user out (no auth limbo)', () async {
      final db = MockFirebaseFirestore();
      when(() => db.collection('users')).thenThrow(StateError('db down'));
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u-out');
      when(() => auth.signOut()).thenAnswer((_) async {});
      var navigated = 0;
      final repo = FirebaseAuthRepository(
        auth,
        db,
        logger,
        onSignOutNavigated: () => navigated++,

        cache: const NoOpLocalCache(),
      );

      await expectLater(repo.signOut(), throwsA(isA<Exception>()));
      verify(() => auth.signOut()).called(1);
      expect(navigated, 1);
    });
  });
  group('FirebaseAuthRepository.getUserData', () {
    test(
      'parses the profile doc (id injected, typed role, timestamp)',
      () async {
        final fake = FakeFirebaseFirestore();
        await fake.collection('users').doc('u1').set(<String, dynamic>{
          'name': 'Sara',
          'role': 'manager',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
        });
        final repo = FirebaseAuthRepository(
          auth,
          fake,
          logger,
          cache: const NoOpLocalCache(),
        );

        final model = await repo.getUserData('u1');

        expect(model, isNotNull);
        expect(model!.id, 'u1');
        expect(model.name, 'Sara');
        expect(model.role, UserRole.manager);
        expect(model.createdAt, DateTime(2026, 1, 2));
      },
    );

    test('missing profile doc resolves null', () async {
      final repo = FirebaseAuthRepository(
        auth,
        FakeFirebaseFirestore(),
        logger,

        cache: const NoOpLocalCache(),
      );
      expect(await repo.getUserData('ghost'), isNull);
    });

    test(
      'permission-denied fails CLOSED with the mapped message and NO backoff',
      () async {
        final db = MockFirebaseFirestore();
        when(() => db.collection('users')).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
        final repo = FirebaseAuthRepository(
          auth,
          db,
          logger,
          cache: const NoOpLocalCache(),
        );
        final stopwatch = Stopwatch()..start();

        await expectLater(
          repo.getUserData('u1'),
          throwsA(
            predicate<Object>(
              (e) => e.toString().contains('You do not have permission'),
            ),
          ),
        );
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              'a permanent authz error must rethrow IMMEDIATELY '
              '(QUEUE-2: no backoff ladder when isRetryable is false)',
        );
        expect(logger.errors, contains('FirebaseAuthRepository_getUserData'));
      },
    );
  });

  group('auth providers (Riverpod wiring)', () {
    Future<ProviderContainer> buildContainer(FakeAuthRepository repo) async {
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repo),
          loggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);
      // Drive the authState emission BEFORE reading the derived providers so
      // the derived reads see the emitted value deterministically. `.future`
      // resolves on the first emission (Stream.value closes after it).
      await container.read(authStateProvider.future);
      return container;
    }

    test(
      'currentUserIdProvider reflects the stream; profile loads for non-anonymous users',
      () async {
        const model = UserModel(id: 'u1', name: 'Sara', role: UserRole.manager);
        when(() => user.uid).thenReturn('u1');
        when(() => user.isAnonymous).thenReturn(false);
        final container = await buildContainer(
          FakeAuthRepository(
            authState: Stream<User?>.value(user),
            userData: model,
          ),
        );

        expect(container.read(currentUserIdProvider), 'u1');
        expect(
          (await container.read(currentUserProvider.future))!.name,
          'Sara',
        );
      },
    );

    test('anonymous users skip the profile load', () async {
      when(() => user.uid).thenReturn('anon');
      when(() => user.isAnonymous).thenReturn(true);
      final container = await buildContainer(
        FakeAuthRepository(authState: Stream<User?>.value(user)),
      );

      expect(container.read(currentUserIdProvider), 'anon');
      expect(await container.read(currentUserProvider.future), isNull);
    });

    test('signed-out users have a null id and null profile', () async {
      final container = await buildContainer(
        FakeAuthRepository(authState: Stream<User?>.value(null)),
      );

      expect(container.read(currentUserIdProvider), isNull);
      expect(await container.read(currentUserProvider.future), isNull);
    });
  });
  group('UserModel serialization', () {
    test('fromJson/toJson round-trips role, tier and loyalty', () {
      const model = UserModel(
        id: 'u1',
        email: 'a@b.com',
        name: 'Sara',
        role: UserRole.manager,
        loyaltyPoints: 42,
        tier: 'gold',
      );

      final back = UserModel.fromJson(model.toJson());

      expect(back, model);
      expect(model.toJson()['role'], 'manager');
    });

    test('unknown/missing role strings fall back to customer (B3 P2)', () {
      expect(
        UserModel.fromJson(<String, dynamic>{'id': 'u1', 'role': 'chief'}).role,
        UserRole.customer,
      );
      expect(
        UserModel.fromJson(<String, dynamic>{'id': 'u1'}).role,
        UserRole.customer,
      );
    });

    test('displayTitle: username > name > displayName > email > id', () {
      expect(const UserModel(id: 'u1').displayTitle, 'u1');
      expect(
        const UserModel(id: 'u1', email: 'a@b.com').displayTitle,
        'a@b.com',
      );
      expect(
        const UserModel(
          id: 'u1',
          email: 'a@b.com',
          displayName: 'D',
        ).displayTitle,
        'D',
      );
      expect(
        const UserModel(id: 'u1', displayName: 'D', name: 'N').displayTitle,
        'N',
      );
      expect(
        const UserModel(id: 'u1', name: 'N', username: 'U').displayTitle,
        'U',
      );
    });

    test('fromDoc normalizes a Firestore Timestamp createdAt', () {
      final model = UserModel.fromDoc(<String, dynamic>{
        'name': 'S',
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 3)),
      }, 'u9');

      expect(model.id, 'u9');
      expect(model.createdAt, DateTime(2026, 2, 3));
    });
  });

  group('resolvePushLocale (fail-closed dictionary)', () {
    test('Arabic variants map to ar; everything else (incl. null) to en', () {
      expect(resolvePushLocale('ar'), 'ar');
      expect(resolvePushLocale('Ar-EG'), 'ar');
      expect(resolvePushLocale('ar_EG'), 'ar');
      expect(resolvePushLocale('en'), 'en');
      expect(resolvePushLocale('en-GB'), 'en');
      expect(resolvePushLocale('es'), 'en');
      expect(resolvePushLocale(''), 'en');
      expect(resolvePushLocale(null), 'en');
    });
  });

  group('FallbackAuthRepository (fail-safe default)', () {
    test(
      'is inert: null user, null profile, empty stream, safe signOut',
      () async {
        final fallback = FallbackAuthRepository(logger);
        expect(fallback.currentUser, isNull);
        expect(await fallback.getUserData('u1'), isNull);
        expect(await fallback.authStateChanges().toList(), isEmpty);
        await fallback.signOut();
      },
    );

    test('every auth surface is a logged no-op (never throws)', () async {
      final fallback = FallbackAuthRepository(logger);

      await fallback.signInAnonymously();
      await fallback.signInWithApple();
      await fallback.signInWithGoogle();
      await fallback.signInWithEmailAndPassword('a@b.com', 'pw');
      await fallback.signUp('a@b.com', 'pw', 'Name');
      await fallback.sendPasswordResetEmail('a@b.com');

      expect(
        logger.infos,
        hasLength(6),
        reason: 'each inert surface announces itself exactly once',
      );
      expect(logger.errors, isEmpty);
    });
  });

  group('FirebaseAuthRepository — direct getters + reset seam (PERF-1)', () {
    test('authStateChanges and currentUser delegate to the SDK', () async {
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => const Stream<User?>.empty());
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u-9');

      final repo = FirebaseAuthRepository(
        auth,
        FakeFirebaseFirestore(),
        logger,

        cache: const NoOpLocalCache(),
      );

      expect(await repo.authStateChanges().toList(), isEmpty);
      expect(repo.currentUser?.uid, 'u-9');
    });

    test('PERF-1 H-1: a failed password reset RETHROWS the typed exception '
        '(the login screen snackbar path maps it)', () async {
      final repo = FirebaseAuthRepository(
        auth,
        FakeFirebaseFirestore(),
        logger,

        cache: const NoOpLocalCache(),
      );
      when(
        () => auth.sendPasswordResetEmail(email: any(named: 'email')),
      ).thenThrow(
        FirebaseAuthException(code: 'too-many-requests', message: 'raw'),
      );

      await expectLater(
        repo.sendPasswordResetEmail('a@b.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(
        logger.errors,
        contains('FirebaseAuthRepository_sendPasswordResetEmail'),
      );
    });

    test('a social sign-in failure (Apple/Google) still wraps into the '
        'mapped user-safe Exception (unchanged seams)', () async {
      final repo = FirebaseAuthRepository(
        auth,
        FakeFirebaseFirestore(),
        logger,

        cache: const NoOpLocalCache(),
      );

      // In the test environment the Apple/Google platform channels are
      // absent — the flows fail before any credential is built, exercising
      // the catch-log-wrap seam.
      await expectLater(repo.signInWithApple(), throwsA(isA<Exception>()));
      expect(logger.errors, contains('FirebaseAuthRepository_signInWithApple'));

      await expectLater(repo.signInWithGoogle(), throwsA(isA<Exception>()));
      expect(
        logger.errors,
        contains('FirebaseAuthRepository_signInWithGoogle'),
      );
    });
  });

  group('syncUserProfile — create-if-absent transaction (idempotent)', () {
    test('a brand-new user gets the canonical customer profile doc', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirebaseAuthRepository(
        auth,
        db,
        logger,
        cache: const NoOpLocalCache(),
      );

      when(() => user.uid).thenReturn('u-new');
      when(() => user.email).thenReturn('new@example.com');
      when(() => user.displayName).thenReturn('SDK Display');

      await repo.syncUserProfile(user, displayName: 'Given Display');

      final doc = await db.collection('users').doc('u-new').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['id'], 'u-new');
      expect(doc.data()!['email'], 'new@example.com');
      expect(
        doc.data()!['name'],
        'Given Display',
        reason: 'the explicit displayName wins over the SDK one',
      );
      expect(doc.data()!['role'], 'customer');
      expect(doc.data()!['loyaltyPoints'], 0);
      expect(doc.data()!['tier'], 'starter');
      expect(doc.data()!['locale'], 'en');
    });

    test('the locale parameter resolves through the push dictionary '
        '(Arabic variants → ar, unknown → en)', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirebaseAuthRepository(
        auth,
        db,
        logger,
        cache: const NoOpLocalCache(),
      );

      when(() => user.uid).thenReturn('u-ar');
      when(() => user.email).thenReturn('ar@example.com');
      when(() => user.displayName).thenReturn(null);

      await repo.syncUserProfile(user, locale: 'Ar-EG');
      expect(
        (await db.collection('users').doc('u-ar').get()).data()!['locale'],
        'ar',
      );

      when(() => user.uid).thenReturn('u-es');
      when(() => user.email).thenReturn('es@example.com');
      await repo.syncUserProfile(user, locale: 'es');
      expect(
        (await db.collection('users').doc('u-es').get()).data()!['locale'],
        'en',
        reason: 'an unsupported locale fails closed to en',
      );
    });

    test('an EXISTING profile is never clobbered (idempotent sync)', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirebaseAuthRepository(
        auth,
        db,
        logger,
        cache: const NoOpLocalCache(),
      );

      await db.collection('users').doc('u-exists').set({
        'id': 'u-exists',
        'loyaltyPoints': 420,
        'role': 'manager',
      });

      when(() => user.uid).thenReturn('u-exists');
      when(() => user.email).thenReturn('x@example.com');
      when(() => user.displayName).thenReturn('Clobber Attempt');

      await repo.syncUserProfile(user, displayName: 'Clobber Attempt');

      final doc = await db.collection('users').doc('u-exists').get();
      expect(
        doc.data()!['loyaltyPoints'],
        420,
        reason: 'a re-sync must NEVER reset loyalty',
      );
      expect(doc.data()!['role'], 'manager');
    });
  });

  group('signUp — full success path (profile doc persisted)', () {
    test('auth + profile sync both complete', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirebaseAuthRepository(
        auth,
        db,
        logger,
        cache: const NoOpLocalCache(),
      );

      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.uid).thenReturn('u-signup');
      when(() => user.email).thenReturn('signup@example.com');
      when(() => user.displayName).thenReturn('Sign Up');
      when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
      when(() => user.reload()).thenAnswer((_) async {});

      await repo.signUp('signup@example.com', 'password123', 'Sign Up');

      final doc = await db.collection('users').doc('u-signup').get();
      expect(doc.exists, isTrue, reason: 'signUp persists the profile doc');
      expect(doc.data()!['name'], 'Sign Up');
    });
  });

  group('FirebaseAuthRepository — signUp empty-user failure (p28 T-2)', () {
    test(
      'a create-user result without a user RETHROWS the typed code and logs',
      () async {
        final repo = FirebaseAuthRepository(
          auth,
          FakeFirebaseFirestore(),
          logger,

          cache: const NoOpLocalCache(),
        );
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(null);

        await expectLater(
          repo.signUp('ghost@b.com', 'pw', 'Ghost'),
          throwsA(
            predicate<Object>(
              (e) =>
                  e is FirebaseAuthException &&
                  e.code == 'create-user-empty-result',
            ),
          ),
        );
        expect(logger.errors, contains('FirebaseAuthRepository_signUp'));
      },
    );
  });

  group('FirebaseAuthRepository — signOut fallback cascade (p28 T-2)', () {
    test(
      'a signOut whose every step fails still retries, logs '
      'AuthSignOutError + AuthSignOutFinalNavError and ends mapped',
      () async {
        final fake = FakeFirebaseFirestore();
        final db = MockFirebaseFirestore();
        when(() => db.collection('users')).thenReturn(fake.collection('users'));
        when(() => db.terminate()).thenAnswer((_) async {});
        when(() => db.clearPersistence()).thenAnswer((_) async {});
        when(() => auth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('u-fallback');
        when(() => auth.signOut()).thenThrow(StateError('signOut blows up'));

        final repo = FirebaseAuthRepository(
          auth,
          db,
          logger,
          onSignOutNavigated: () => throw StateError('nav exploded'),

          cache: const NoOpLocalCache(),
        );

        await expectLater(repo.signOut(), throwsA(isA<Exception>()));
        expect(
          logger.errors,
          containsAll(<String>[
            'FirebaseAuthRepository_signOut',
            'AuthSignOutError',
            'AuthSignOutFinalNavError',
          ]),
          reason:
              'the fallback cascade must log every recovery step before '
              'the mapped rethrow (fail-closed, never silent)',
        );
      },
    );
  });

  group('authRepositoryProvider — fail-safe default (PERF-1)', () {
    test('an un-overridden container resolves the FallbackAuthRepository', () {
      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(logger)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(authRepositoryProvider),
        isA<FallbackAuthRepository>(),
      );
    });
  });
}
