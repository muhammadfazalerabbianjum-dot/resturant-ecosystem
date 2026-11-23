import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mock_firebase.dart';
import 'helpers/recording_logger.dart';

class _DemoCoreConfig implements CoreConfig {
  const _DemoCoreConfig();

  @override
  bool get isDemoMode => true;

  @override
  String get clientId => 'carnama-test';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const <String>[];

  @override
  String get kitchenLanEndpoint => '';
}

class _BatchCountingFirestore extends FakeFirebaseFirestore {
  int batches = 0;

  @override
  WriteBatch batch() {
    batches++;
    return super.batch();
  }
}

class _FakeStorageEraser implements GdprStorageEraser {
  _FakeStorageEraser(this.trees);

  /// prefix → descendant object paths (mirrors recursive listAll).
  final Map<String, List<String>> trees;
  final List<String> deleted = <String>[];

  @override
  Future<List<String>> listAllUnder(String prefix) async =>
      trees[prefix] ?? const <String>[];

  @override
  Future<void> deleteObject(String objectPath) async {
    deleted.add(objectPath);
  }
}

/// CORE-COV Tier-1 COMPLIANCE suite: the GDPR erasure set shape (canonical
/// collection list, users/{uid} LAST, audit settings rows retained), the
/// chunked batch eraser (≤400/batch), the demo-mode two-phase deleteMyData
/// flow (durable marker FIRST — MONEY-3), and the production callable
/// contract with QUEUE-2 retry semantics.
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NetworkRetry.delay = (Duration duration) async {};
  });

  tearDown(() {
    CoreConfigHolder.set(const DefaultCoreConfig());
    NetworkRetry.delay = Future<void>.delayed;
  });
  group('collectUserDocs — canonical erasure set (GDPR Art.17)', () {
    test(
      'collects every user-scoped collection, keeps settings audit rows, users/{uid} LAST',
      () async {
        final fake = FakeFirebaseFirestore();
        await fake.collection('orders').add(<String, dynamic>{
          'customerId': 'u1',
        });
        await fake.collection('orders').add(<String, dynamic>{
          'customerId': 'u1',
        });
        await fake.collection('orders').add(<String, dynamic>{
          'assignedDriverId': 'u1',
        });
        await fake.collection('deliveries').add(<String, dynamic>{
          'driverId': 'u1',
        });
        await fake.collection('analyticsEvents').add(<String, dynamic>{
          'uid': 'u1',
        });
        await fake.collection('audit_log').add(<String, dynamic>{
          'documentId': 'u1',
          'collection': 'users',
        });
        await fake.collection('audit_log').add(<String, dynamic>{
          'documentId': 'u1',
          'collection': 'settings',
        });
        await fake.collection('reservations').add(<String, dynamic>{
          'userId': 'u1',
        });
        await fake.collection('reservation_locks').add(<String, dynamic>{
          'userId': 'u1',
        });
        await fake.collection('waitlist').add(<String, dynamic>{
          'userId': 'u1',
        });
        await fake.collection('promo_usage').add(<String, dynamic>{
          'userId': 'u1',
        });
        await fake
            .collection('notifications')
            .doc('u1')
            .collection('items')
            .add(<String, dynamic>{'read': false});
        await fake.collection('carts').doc('u1').set(<String, dynamic>{
          'total': 1,
        });
        await fake.collection('users').doc('u1').set(<String, dynamic>{
          'role': 'customer',
        });

        final service = GdprService(logger: RecordingLogger(), firestore: fake);
        final refs = await service.collectUserDocs('u1');
        final paths = refs.map((r) => r.path).toList();

        // Owned orders + one delivery row per DISTINCT order id (owned 2) + the
        // driver-assigned order's delivery row (legacy coverage) + the
        // driverId-keyed delivery row. The driver's order DOC itself is never
        // erased — it belongs to the customer; only the driver's own delivery
        // rows keyed by that order id are erased.
        expect(paths.where((p) => p.startsWith('orders/')), hasLength(2));
        final orderIds = paths
            .where((p) => p.startsWith('orders/'))
            .map((p) => p.split('/')[1])
            .toSet();
        for (final orderId in orderIds) {
          expect(paths, contains('deliveries/$orderId'));
        }
        expect(
          paths.where((p) => p.startsWith('deliveries/')),
          hasLength(4),
          reason:
              '2 owned-order delivery rows + the driver-assigned order\'s '
              'delivery row (legacy pre-driverId coverage) + the driverId-keyed '
              'delivery row; the customer\'s order doc is retained',
        );
        expect(
          paths.where((p) => p.startsWith('analyticsEvents/')),
          hasLength(1),
        );
        // audit_log: ONLY the role-change rows; settings rows are retained.
        expect(
          paths.where((p) => p.startsWith('audit_log/')),
          hasLength(1),
          reason:
              'settings-config audit rows are the immutable trail — retained',
        );
        expect(paths.any((p) => p.startsWith('reservations/')), isTrue);
        expect(paths.any((p) => p.startsWith('reservation_locks/')), isTrue);
        expect(paths.any((p) => p.startsWith('waitlist/')), isTrue);
        expect(paths.any((p) => p.startsWith('promo_usage/')), isTrue);
        expect(
          paths.any((p) => p.startsWith('notifications/u1/items/')),
          isTrue,
        );
        expect(paths, contains('notifications/u1'));
        expect(paths, contains('carts/u1'));
        expect(paths, contains('presence/u1'));
        expect(paths, contains('loyalty/u1'));
        expect(paths, contains('driverLocations/u1'));
        // The profile record must survive until every dependent doc is gone.
        expect(paths.last, 'users/u1');
      },
    );
  });
  group('eraseRefsChunked — the 500-write cap proof', () {
    test('450 refs → 2 batches (≤400 each) and every doc erased', () async {
      final fake = _BatchCountingFirestore();
      final refs = List<DocumentReference<Map<String, dynamic>>>.generate(
        450,
        (i) => fake.collection('temp').doc('d$i'),
      );
      for (final ref in refs) {
        await ref.set(<String, dynamic>{'x': 1});
      }

      final service = GdprService(logger: RecordingLogger(), firestore: fake);
      final erased = await service.eraseRefsChunked(refs);

      expect(erased, 450);
      expect(fake.batches, 2, reason: '450 refs must split into 400+50');
      expect((await fake.collection('temp').get()).docs, isEmpty);
    });

    test('400 refs fit in exactly ONE batch (chunk cap honored)', () async {
      final fake = _BatchCountingFirestore();
      final refs = List<DocumentReference<Map<String, dynamic>>>.generate(
        400,
        (i) => fake.collection('temp').doc('d$i'),
      );
      final service = GdprService(logger: RecordingLogger(), firestore: fake);

      expect(await service.eraseRefsChunked(refs), 400);
      expect(fake.batches, 1);
    });

    test(
      'erasure is idempotent for retries (missing docs are no-ops)',
      () async {
        final fake = FakeFirebaseFirestore();
        final service = GdprService(logger: RecordingLogger(), firestore: fake);
        final ref = fake.collection('temp').doc('gone');

        expect(
          await service.eraseRefsChunked(
            <DocumentReference<Map<String, dynamic>>>[ref],
          ),
          1,
        );
      },
    );
  });
  group('deleteMyData — DEMO two-phase flow (P4-05 / MONEY-3)', () {
    late MockFirebaseAuth auth;
    late MockFirebaseUser user;
    late FakeFirebaseFirestore fake;
    late _FakeStorageEraser eraser;
    late RecordingLogger logger;
    late GdprService service;

    setUp(() {
      auth = MockFirebaseAuth();
      user = MockFirebaseUser();
      fake = FakeFirebaseFirestore();
      eraser = _FakeStorageEraser(<String, List<String>>{
        'avatars/u1': <String>['avatars/u1/a.png'],
        'proof_of_delivery/o1': <String>['proof_of_delivery/o1/pod.jpg'],
      });
      logger = RecordingLogger();
      service = GdprService(
        logger: logger,
        firestore: fake,
        auth: auth,
        storageEraser: eraser,
      );
      CoreConfigHolder.set(const _DemoCoreConfig());
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
      when(() => user.delete()).thenAnswer((_) async {});
    });

    test(
      'marker FIRST → storage FIRST → docs → auth delete → completed',
      () async {
        await fake.collection('orders').doc('o1').set(<String, dynamic>{
          'customerId': 'u1',
        });
        await fake.collection('waitlist').add(<String, dynamic>{
          'userId': 'u1',
        });
        await fake.collection('users').doc('u1').set(<String, dynamic>{
          'role': 'customer',
        });

        final ok = await service.deleteMyData();

        expect(ok, isTrue);
        final marker = await fake
            .collection('deletion_requests')
            .doc('u1')
            .get();
        expect(marker.exists, isTrue);
        expect(marker.data()!['status'], 'completed');
        // Storage mirrors the server set: avatars + proof_of_delivery, deleted
        // BEFORE the order docs were erased (the POD prefixes resolved).
        expect(eraser.deleted, <String>[
          'avatars/u1/a.png',
          'proof_of_delivery/o1/pod.jpg',
        ]);
        expect((await fake.collection('orders').get()).docs, isEmpty);
        expect((await fake.collection('waitlist').get()).docs, isEmpty);
        expect((await fake.collection('users').get()).docs, isEmpty);
        verify(() => user.delete()).called(1);
      },
    );

    test(
      'auth delete failure leaves the marker in_progress and rethrows',
      () async {
        await fake.collection('users').doc('u1').set(<String, dynamic>{
          'role': 'customer',
        });
        when(
          () => user.delete(),
        ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        await expectLater(service.deleteMyData(), throwsA(isA<Exception>()));

        final marker = await fake
            .collection('deletion_requests')
            .doc('u1')
            .get();
        expect(marker.data()!['status'], 'in_progress');
        // The erasure DID happen — only the Auth delete is pending for the
        // server-side retrier.
        expect((await fake.collection('users').get()).docs, isEmpty);
        expect(logger.errors, contains('gdpr_auth_delete_failed'));
      },
    );
  });
  group('deleteMyData — PRODUCTION callable path', () {
    late MockFirebaseAuth auth;
    late MockFirebaseUser user;
    late FakeFirebaseFirestore fake;
    late MockFirebaseFunctions functions;
    late MockHttpsCallable callable;
    late RecordingLogger logger;
    late GdprService service;

    setUp(() {
      auth = MockFirebaseAuth();
      user = MockFirebaseUser();
      fake = FakeFirebaseFirestore();
      functions = MockFirebaseFunctions();
      callable = MockHttpsCallable();
      logger = RecordingLogger();
      when(
        () => functions.httpsCallable('deleteUserData'),
      ).thenReturn(callable);
      service = GdprService(
        functions: functions,
        logger: logger,
        firestore: fake,
        auth: auth,
      );
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');
    });

    test(
      'success:true contract — marker persisted FIRST, callable retried-safe',
      () async {
        var markerExistedDuringCall = false;
        final result = MockCallableResult();
        when(() => result.data).thenReturn(<String, dynamic>{'success': true});
        when(() => callable.call()).thenAnswer((_) async {
          final marker = await fake
              .collection('deletion_requests')
              .doc('u1')
              .get();
          markerExistedDuringCall = marker.exists;
          return result;
        });

        expect(await service.deleteMyData(), isTrue);
        expect(markerExistedDuringCall, isTrue);
        final marker = await fake
            .collection('deletion_requests')
            .doc('u1')
            .get();
        expect(marker.data()!['status'], 'in_progress');
      },
    );

    test(
      'success:false means the erasure did NOT complete (returns false)',
      () async {
        final result = MockCallableResult();
        when(() => result.data).thenReturn(<String, dynamic>{'success': false});
        when(() => callable.call()).thenAnswer((_) async => result);

        expect(await service.deleteMyData(), isFalse);
      },
    );

    test(
      'transient callable failure → 3 retries → marker stays in_progress',
      () async {
        var calls = 0;
        when(() => callable.call()).thenAnswer((_) async {
          calls++;
          throw TestFunctionsException('unavailable');
        });

        await expectLater(service.deleteMyData(), throwsA(isA<Exception>()));

        expect(
          calls,
          4,
          reason: 'initial + 3 retries (QUEUE-2 bounded ladder)',
        );
        final marker = await fake
            .collection('deletion_requests')
            .doc('u1')
            .get();
        expect(marker.data()!['status'], 'in_progress');
        expect(logger.errors, contains('gdpr_cloud_function_failed'));
      },
    );

    test(
      'no signed-in user is fail-closed false (never a silent success)',
      () async {
        when(() => auth.currentUser).thenReturn(null);
        expect(await service.deleteMyData(), isFalse);
      },
    );
  });

  group('gdprServiceProvider + ctor defaults (PERF-1)', () {
    test(
      'the DI provider resolves the service from firestore/logger providers',
      () {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            loggerProvider.overrideWithValue(RecordingLogger()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(gdprServiceProvider), isA<GdprService>());
      },
    );

    test('a bare constructor falls back to the canonical Firestore client', () {
      FirestoreClient.setMock(
        FirestoreClient.testInject(
          FakeFirebaseFirestore(),
          ErrorLoggerService(null),
        ),
      );
      // Must construct and be usable — the defaults resolve lazily-safe.
      expect(GdprService(), isA<GdprService>());
    });
  });

  group('demo deleteMyData — storage seams (PERF-1)', () {
    test('an ASSIGNED (driver) order gets its POD prefixes erased too '
        '(MONEY-3 mirror)', () async {
      final fake = FakeFirebaseFirestore();
      // A KNOWN id — the POD prefix is derived from the order document id.
      await fake.collection('orders').doc('ord-assigned').set(<String, dynamic>{
        'assignedDriverId': 'driver-9',
      });
      final eraser = _FakeStorageEraser(<String, List<String>>{
        'avatars/driver-9': <String>['avatars/driver-9/a.png'],
        'proof_of_delivery/ord-assigned': <String>[
          'proof_of_delivery/ord-assigned/pod.jpg',
        ],
      });
      final auth = MockFirebaseAuth();
      final user = MockFirebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('driver-9');
      // Phase 2 deletes the Auth account after the storage/doc erasure.
      when(() => user.delete()).thenAnswer((_) async {});

      CoreConfigHolder.set(const _DemoCoreConfig());
      final service = GdprService(
        firestore: fake,
        logger: RecordingLogger(),
        auth: auth,
        storageEraser: eraser,
      );

      await service.deleteMyData();

      expect(
        eraser.deleted,
        containsAll(<String>[
          'avatars/driver-9/a.png',
          'proof_of_delivery/ord-assigned/pod.jpg',
        ]),
        reason: 'an order the user was ASSIGNED must be in the POD erase set',
      );
    });

    test('a storage-erasure failure is logged and RETHROWN '
        '(the marker stays in_progress for the server retrier)', () async {
      final fake = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final user = MockFirebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u-fail');
      final logger = RecordingLogger();

      CoreConfigHolder.set(const _DemoCoreConfig());
      final service = GdprService(
        firestore: fake,
        logger: logger,
        auth: auth,
        storageEraser: _ThrowingStorageEraser(),
      );

      await expectLater(
        service.deleteMyData(),
        throwsA(isA<StateError>()),
        reason:
            'fail-closed — the deletion intent must survive for the retrier',
      );
      expect(logger.errors, contains('gdpr_batch_delete_failed'));
    });
  });
}

class _ThrowingStorageEraser implements GdprStorageEraser {
  @override
  Future<List<String>> listAllUnder(String prefix) async =>
      throw StateError('storage unreachable');

  @override
  Future<void> deleteObject(String objectPath) async {}
}
