// TDD Master Suite — Compliance (GDPR)
// Category: Compliance
// Invariant: GDPR consent must persist. Delete Account must erase ALL user
//            scoped data (demo path), keep the durable marker, and mirror the
//            production Cloud Function's erasure set (potato4 B0 T0-1..T0-5).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Demo-mode configuration: isDemoMode true (drives the client-side erasure).
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

/// Production-mode configuration: isDemoMode false (Cloud Function path).
class _ProdConfig implements CoreConfig {
  const _ProdConfig();
  @override
  bool get isDemoMode => false;
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

class MockLoggerService extends Mock implements LoggerService {}

class MockFunctions extends Mock implements FirebaseFunctions {}

class MockCallable extends Mock implements HttpsCallable {}

/// In-memory [GdprStorageEraser] proving the demo mirror erases EXACTLY the
/// server's canonical Storage prefixes (avatars/{uid}/*, PODs of the user's
/// own + driver-assigned orders) without Firebase Storage platform channels.
class _FakeEraser implements GdprStorageEraser {
  _FakeEraser(this.objects);
  final Map<String, bool> objects;
  final List<String> deleted = [];
  Object? throwError;

  @override
  Future<List<String>> listAllUnder(String prefix) async {
    if (throwError != null) throw throwError!;
    return objects.entries
        .where((e) => e.value && e.key.startsWith('$prefix/'))
        .map((e) => e.key)
        .toList();
  }

  @override
  Future<void> deleteObject(String objectPath) async {
    if (throwError != null) throw throwError!;
    if (objects[objectPath] == true) {
      objects[objectPath] = false;
      deleted.add(objectPath);
    }
  }
}

/// Auth whose currentUser is fixed, so demo/paths don't need `FirebaseAuth.instance`.
class _FixedUserAuth extends MockFirebaseAuth {
  _FixedUserAuth(this.fixedUser);
  final User fixedUser;

  @override
  User? get currentUser => fixedUser;
}

/// A signed-in user whose `delete()` fails (simulates Auth outage).
class _ThrowingDeleteUser extends Mock implements User {
  _ThrowingDeleteUser(this._uid);
  final String _uid;

  @override
  String get uid => _uid;

  @override
  Future<void> delete() async {
    throw FirebaseAuthException(
      code: 'network-error',
      message: 'Simulated Auth outage',
    );
  }
}

/// A Firestore whose batch() throws, proving the durable marker was written
/// BEFORE any user-doc delete (marker-first ordering).
class _FailingBatchDb extends FakeFirebaseFirestore {
  bool failBatch = false;

  @override
  WriteBatch batch() {
    if (failBatch) {
      throw StateError('Simulated Firestore batch failure');
    }
    return super.batch();
  }
}

/// Seeds every user-scoped document shape of the erasure set into `db`.
Future<void> seedUserData(FakeFirebaseFirestore db, String uid) async {
  await db.collection('users').doc(uid).set({
    'email': '$uid@test.com',
    'role': 'customer',
    'branchId': '',
  });
  await db.collection('orders').doc('order-$uid-1').set({
    'customerId': uid,
    'status': 'confirmed',
    'totalCents': 2500,
  });
  await db.collection('reservations').doc('res-$uid-1').set({
    'userId': uid,
    'branchId': 'branch-1',
    'customerName': 'Test',
    'startTime': DateTime.now(),
    'partySize': 2,
  });
  await db.collection('reservation_locks').doc('lock-$uid-1').set({
    'userId': uid,
    'lockedAt': DateTime.now(),
  });
  await db.collection('waitlist').doc('wl-$uid-1').set({
    'userId': uid,
    'branchId': 'branch-1',
  });
  await db.collection('promo_usage').doc('pu-$uid-1').set({
    'userId': uid,
    'code': 'HELLO10',
  });
  await db
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .doc('n1')
      .set({'title': 'hello'});
  await db.collection('carts').doc(uid).set({'items': []});
  await db.collection('presence').doc(uid).set({'lastSeen': DateTime.now()});
  await db.collection('loyalty').doc(uid).set({'points': 10});
  await db.collection('driverLocations').doc(uid).set({'lat': 1.0, 'lng': 2.0});
}

void main() {
  // QUEUE-2: production now retries transient failures with REAL exponential
  // backoff (NetworkRetry). The marker-ordering tests assert rethrow +
  // marker state regardless of classification, so the delay is neutralized
  // to keep them fast and under the default per-test timeout. Retry
  // semantics are proven in test/core/network/retry_wrapping_test.dart.
  setUp(() {
    NetworkRetry.delay = (_) async {};
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Because GdprService defaults `_fn` to FirebaseFunctions.instance, the
    // core mock platform + app must exist even when functions are injected
    // later per-test. Mirrors runtime_audit_flow_test.dart.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDown(() {
    CoreConfigHolder.set(const _ProdConfig());
  });

  group('B0 T0-1 demo erasure completeness', () {
    test(
      'deleteMyData (demo) erases the FULL user-scoped set and keeps the marker',
      () async {
        final db = FakeFirebaseFirestore();
        const uid = 'gdpr-user';
        await seedUserData(db, uid);

        // The legacy wrong-key reservation (customerId only) must NOT be erased —
        // reservations are keyed by userId; this is the query-key guard.
        await db.collection('reservations').doc('res-legacy-customerid').set({
          'customerId': uid,
          'branchId': 'branch-1',
        });

        final auth = _FixedUserAuth(MockUser(uid: uid, email: '$uid@test.com'));
        final logger = MockLoggerService();
        when(
          () => logger.error(any(), any(), stack: any(named: 'stack')),
        ).thenAnswer((_) async {});

        CoreConfigHolder.set(const _DemoConfig());
        // MONEY-3 (W3.5): the demo mirror must ALSO erase the user's Storage
        // objects through the same seam contract as the Cloud Function.
        final eraser = _FakeEraser({
          'avatars/$uid/a.png': true,
          'proof_of_delivery/order-$uid-1/pod.jpg': true,
          'avatars/keep-me/b.png': true,
          'proof_of_delivery/order-other-1/pod.jpg': true,
        });
        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: logger,
          storageEraser: eraser,
        );

        final deleted = await service.deleteMyData();

        expect(deleted, isTrue, reason: 'demo erasure must report success');
        // Every user-scoped doc is gone.
        expect(
          (await db.collection('reservations').doc('res-gdpr-user-1').get())
              .exists,
          isFalse,
        );
        expect(
          (await db
                  .collection('reservation_locks')
                  .doc('lock-gdpr-user-1')
                  .get())
              .exists,
          isFalse,
        );
        expect(
          (await db.collection('orders').doc('order-gdpr-user-1').get()).exists,
          isFalse,
        );
        expect(
          (await db.collection('waitlist').doc('wl-gdpr-user-1').get()).exists,
          isFalse,
        );
        expect(
          (await db.collection('promo_usage').doc('pu-gdpr-user-1').get())
              .exists,
          isFalse,
        );
        expect(
          (await db.collection('notifications').doc(uid).get()).exists,
          isFalse,
        );
        expect(
          (await db
                  .collection('notifications')
                  .doc(uid)
                  .collection('items')
                  .get())
              .docs,
          isEmpty,
        );
        expect((await db.collection('carts').doc(uid).get()).exists, isFalse);
        expect(
          (await db.collection('presence').doc(uid).get()).exists,
          isFalse,
        );
        expect((await db.collection('loyalty').doc(uid).get()).exists, isFalse);
        expect(
          (await db.collection('driverLocations').doc(uid).get()).exists,
          isFalse,
        );
        expect((await db.collection('users').doc(uid).get()).exists, isFalse);

        // The customerId-only reservation survives (not this user's data key).
        expect(
          (await db
                  .collection('reservations')
                  .doc('res-legacy-customerid')
                  .get())
              .exists,
          isTrue,
          reason:
              'a reservation not keyed by userId must not be collected/erased',
        );

        // The durable marker is the audit proof: completed, NOT deleted.
        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(marker.exists, isTrue);
        expect(marker.data()?['status'], 'completed');

        // MONEY-3 (W3.5): Storage mirror — own avatar + own-order POD erased;
        // other users' objects SURVIVE (no over-erasure).
        expect(
          eraser.objects['avatars/$uid/a.png'],
          isFalse,
          reason: 'demo mirror must erase the user avatar',
        );
        expect(
          eraser.objects['proof_of_delivery/order-$uid-1/pod.jpg'],
          isFalse,
          reason: "POD of the user's own order must be erased",
        );
        expect(eraser.deleted.length, 2);
        expect(
          eraser.objects['avatars/keep-me/b.png'],
          isTrue,
          reason: "another user's avatar must survive",
        );
        expect(
          eraser.objects['proof_of_delivery/order-other-1/pod.jpg'],
          isTrue,
          reason: "another order's POD must survive",
        );
      },
    );

    test(
      'storage erasure failure keeps the durable marker in_progress (fail-closed)',
      () async {
        final db = FakeFirebaseFirestore();
        const uid = 'gdpr-user';
        await seedUserData(db, uid);

        final auth = _FixedUserAuth(MockUser(uid: uid, email: '$uid@test.com'));
        final logger = MockLoggerService();
        when(
          () => logger.error(any(), any(), stack: any(named: 'stack')),
        ).thenAnswer((_) async {});

        final eraser = _FakeEraser({})
          ..throwError = StateError('storage outage');
        CoreConfigHolder.set(const _DemoConfig());
        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: logger,
          storageEraser: eraser,
        );

        await expectLater(service.deleteMyData(), throwsA(isA<StateError>()));

        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(
          marker.data()?['status'],
          'in_progress',
          reason: 'a Storage failure must NOT complete the erasure marker',
        );
        verify(
          () => logger.error(any(), any(), stack: any(named: 'stack')),
        ).called(1);
      },
    );
  });
  group('B0 T0-4 marker ordering (demo path)', () {
    test('auth-delete failure leaves the durable marker in_progress', () async {
      final db = FakeFirebaseFirestore();
      const uid = 'gdpr-user';
      await seedUserData(db, uid);

      final auth = _FixedUserAuth(_ThrowingDeleteUser(uid));
      final logger = MockLoggerService();
      when(
        () => logger.error(any(), any(), stack: any(named: 'stack')),
      ).thenAnswer((_) async {});

      CoreConfigHolder.set(const _DemoConfig());
      final eraser = _FakeEraser({
        'avatars/$uid/a.png': true,
        'proof_of_delivery/order-$uid-1/pod.jpg': true,
      });
      final service = GdprService(
        firestore: db,
        auth: auth,
        logger: logger,
        storageEraser: eraser,
      );

      await expectLater(
        service.deleteMyData(),
        throwsA(isA<FirebaseAuthException>()),
      );

      final marker = await db.collection('deletion_requests').doc(uid).get();
      expect(marker.exists, isTrue);
      expect(
        marker.data()?['status'],
        'in_progress',
        reason: 'auth delete failed -> server-side retry must pick it up',
      );
      // All Firestore data were erased before the auth step.
      expect(
        (await db
                .collection('reservations')
                .where('userId', isEqualTo: uid)
                .get())
            .docs,
        isEmpty,
      );
      // MONEY-3 (W3.5): Storage objects were ALSO erased before the auth step.
      expect(eraser.objects['avatars/$uid/a.png'], isFalse);
      expect(eraser.objects['proof_of_delivery/order-$uid-1/pod.jpg'], isFalse);
    });

    test(
      'batch failure proves the marker is written BEFORE any user-doc delete',
      () async {
        final db = _FailingBatchDb();
        const uid = 'gdpr-user';
        await seedUserData(db, uid);

        final auth = _FixedUserAuth(MockUser(uid: uid, email: '$uid@test.com'));
        final logger = MockLoggerService();
        when(
          () => logger.error(any(), any(), stack: any(named: 'stack')),
        ).thenAnswer((_) async {});

        CoreConfigHolder.set(const _DemoConfig());
        final eraser = _FakeEraser({
          'avatars/$uid/a.png': true,
          'proof_of_delivery/order-$uid-1/pod.jpg': true,
        });
        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: logger,
          storageEraser: eraser,
        );

        db.failBatch = true;
        await expectLater(service.deleteMyData(), throwsA(isA<StateError>()));

        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(
          marker.exists,
          isTrue,
          reason: 'durable in_progress marker must exist before erasure',
        );
        expect(marker.data()?['status'], 'in_progress');
      },
    );
  });

  group('B0 T0-4 marker ordering (production path)', () {
    test(
      'marker-first write then CF; CF failure keeps marker in_progress',
      () async {
        final db = FakeFirebaseFirestore();
        const uid = 'gdpr-user';
        await db.collection('users').doc(uid).set({'role': 'customer'});

        final auth = _FixedUserAuth(MockUser(uid: uid, email: '$uid@test.com'));
        final logger = MockLoggerService();
        when(
          () => logger.error(any(), any(), stack: any(named: 'stack')),
        ).thenAnswer((_) async {});

        final functions = MockFunctions();
        final callable = MockCallable();
        when(
          () => functions.httpsCallable('deleteUserData'),
        ).thenReturn(callable);
        when(() => callable.call()).thenThrow(
          FirebaseFunctionsException(
            code: 'internal',
            message: 'CF unreachable',
          ),
        );

        CoreConfigHolder.set(const _ProdConfig());
        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: logger,
          functions: functions,
        );

        await expectLater(service.deleteMyData(), throwsA(anything));

        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(
          marker.exists,
          isTrue,
          reason:
              'durable marker must be written before the Cloud Function call',
        );
        expect(
          marker.data()?['status'],
          'in_progress',
          reason: 'a server-side retrier completes the erasure later',
        );
      },
    );
  });
}
