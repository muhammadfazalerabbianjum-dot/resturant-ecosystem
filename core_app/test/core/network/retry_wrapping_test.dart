// BATCH QUEUE-2 — behavioral proofs that the wrapped callables and one-shot
// reads actually RETRY transient failures, SKIP permanent ones, and keep
// every fail-closed contract intact.
//
// T-3: createOrder / createPaymentIntent replay the SAME idempotencyKey on
// retry (Law 9 — no double charge, no duplicate order).
// The NetworkRetry.delay seam is neutralized so no wall-clock backoff burns
// CI time; the production default is separately proven in
// network_retry_test.dart.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/data/menu_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/tenant_claim_fakes.dart';

class MockLoggerService extends Mock implements LoggerService {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// CollectionReference transitively implements the sealed `Query`; the
// suppression covers that supertype obligation (mocktail test double only).
// ignore: subtype_of_sealed_class
class MockCollectionRef extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// cloud_firestore seals Query/DocumentReference/DocumentSnapshot; mocktail
// still needs the `implements` seam to script transient failures — the
// suppression is scoped to these test doubles only. (QuerySnapshot is NOT
// sealed, and `isar` also exports a `Query`, so no mock implements that name.)
// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockIsarService extends Mock implements IsarService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

/// Alias so Firestore `unavailable`/`permission-denied` reads read clearly.
typedef FirestoreFirebaseException = FirebaseException;

MockLoggerService _makeLogger() {
  final logger = MockLoggerService();
  when(() => logger.error(any(), any())).thenAnswer((_) async {});
  when(
    () => logger.error(any(), any(), stack: any(named: 'stack')),
  ).thenAnswer((_) async {});
  when(() => logger.info(any(), any())).thenAnswer((_) async {});
  return logger;
}

/// Scripted HttpsCallable: each [call] pops the next scripted step — an
/// [Exception] to THROW, or an [HttpsCallableResult] to return. The LAST
/// step repeats once the script is exhausted.
class ScriptedCallable extends Mock implements HttpsCallable {
  final List<Object> steps;
  int attempts = 0;
  final capturedPayloads = <Map<String, dynamic>>[];
  ScriptedCallable(this.steps);

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([Object? payload]) {
    attempts++;
    if (payload != null) {
      capturedPayloads.add(payload as Map<String, dynamic>);
    }
    final index = attempts - 1 < steps.length ? attempts - 1 : steps.length - 1;
    final step = steps[index];
    if (step is Exception) {
      throw step;
    }
    return Future.value(step as HttpsCallableResult<T>);
  }
}

FirebaseFunctionsException _ffe(String code, [String message = 'x']) =>
    FirebaseFunctionsException(code: code, message: message);

FirestoreFirebaseException _fs(String code, [String message = 'x']) =>
    FirestoreFirebaseException(
      plugin: 'cloud_firestore',
      code: code,
      message: message,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureIsarCoreForTests();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    NetworkRetry.delay = (_) async {}; // no wall-clock backoff in these tests
  });

  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed; // restore PRODUCTION default
  });

  group(
    'T-3 — createOrder: transient retry replays the SAME idempotencyKey',
    () {
      test(
        'unavailable x1 then success: 2 attempts, identical key, order returned',
        () async {
          final logger = _makeLogger();
          final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
          when(() => mockResult.data).thenReturn({'orderId': 'ord-123'});
          final callable = ScriptedCallable([
            _ffe('unavailable', 'transport blip'),
            mockResult,
          ]);
          final functions = MockFirebaseFunctions();
          when(
            () => functions.httpsCallable('createOrder'),
          ).thenReturn(callable);

          final svc = CheckoutService(
            firestore: FakeFirebaseFirestore(),
            functions: functions,
            promoService: PromoCodeService(functions, logger),
            logger: logger,
            tenantClaim: const FixedTenantClaim(),
          );

          final result = await svc.createOrder(
            paymentIntentId: 'pi_123',
            order: OrderModel(
              id: 'ord-123',
              customerId: 'uid-1',
              status: OrderStatus.pending,
              totalCents: 1500,
              createdAt: DateTime.now(),
            ),
            userId: 'uid-1',
            idempotencyKey: 'uid-1_ord-123_1',
          );

          expect(result['orderId'], 'ord-123');
          expect(
            callable.attempts,
            2,
            reason: 'one transient failure must be retried exactly once here',
          );
          expect(callable.capturedPayloads.length, 2);
          for (final payload in callable.capturedPayloads) {
            expect(
              payload['idempotencyKey'],
              'uid-1_ord-123_1',
              reason:
                  'EVERY attempt must replay the SAME idempotencyKey — the '
                  'server deduplicates on it, so a committed-but-unacked first '
                  'attempt can never produce a second charge or a duplicate '
                  'order',
            );
          }
        },
      );

      test(
        'transport TimeoutException is also retried (raw errors are transient)',
        () async {
          final logger = _makeLogger();
          final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
          when(() => mockResult.data).thenReturn({'orderId': 'ord-9'});
          final callable = ScriptedCallable([
            TimeoutException('socket stall'),
            mockResult,
          ]);
          final functions = MockFirebaseFunctions();
          when(
            () => functions.httpsCallable('createOrder'),
          ).thenReturn(callable);

          final svc = CheckoutService(
            firestore: FakeFirebaseFirestore(),
            functions: functions,
            promoService: PromoCodeService(functions, logger),
            logger: logger,
            tenantClaim: const FixedTenantClaim(),
          );

          final result = await svc.createOrder(
            paymentIntentId: 'pi_9',
            order: OrderModel(
              id: 'ord-9',
              customerId: 'uid-1',
              status: OrderStatus.pending,
              totalCents: 900,
              createdAt: DateTime.now(),
            ),
            userId: 'uid-1',
            idempotencyKey: 'uid-1_ord-9_1',
          );

          expect(result['orderId'], 'ord-9');
          expect(callable.attempts, 2);
        },
      );

      test(
        'createPaymentIntent: transient retry keeps the SAME Stripe key',
        () async {
          final logger = _makeLogger();
          final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
          when(() => mockResult.data).thenReturn({
            'clientSecret': 'cs_test_secret',
            'paymentIntentId': 'pi_1',
            'amountCents': 2000,
            'taxCents': 0,
            'discountCents': 0,
          });
          final callable = ScriptedCallable([
            _ffe('unavailable', 'blip'),
            mockResult,
          ]);
          final functions = MockFirebaseFunctions();
          when(
            () => functions.httpsCallable('createPaymentIntent'),
          ).thenReturn(callable);

          final svc = CheckoutService(
            firestore: FakeFirebaseFirestore(),
            functions: functions,
            promoService: PromoCodeService(functions, logger),
            logger: logger,
            tenantClaim: const FixedTenantClaim(),
          );

          Object? caught;
          try {
            await svc.processStripePayment(
              finalTotal: 2000,
              cart: const CartModel(),
              idempotencyKey: 'sess_abc',
            );
          } catch (e) {
            caught = e; // the payment sheet itself is unavailable in tests
          }

          expect(
            callable.attempts,
            2,
            reason: 'the wrapped createPaymentIntent call must be retried once',
          );
          for (final payload in callable.capturedPayloads) {
            expect(
              payload['idempotencyKey'],
              'sess_abc',
              reason:
                  'Stripe idempotency key is replayed — no duplicate charge',
            );
          }
          expect(
            caught,
            isNot(isA<FirebaseFunctionsException>()),
            reason:
                'the callable SUCCEEDED on attempt 2 — any throw afterwards '
                'comes from Stripe presentation (unavailable in tests)',
          );
        },
      );
    },
  );

  group('callables — applyPromo / calculateTax classification', () {
    test(
      'applyPromo: failed-precondition surfaces the server message with NO retry',
      () async {
        final logger = _makeLogger();
        final callable = ScriptedCallable([
          _ffe('failed-precondition', 'Promo code has been fully redeemed'),
        ]);
        final functions = MockFirebaseFunctions();
        when(() => functions.httpsCallable('applyPromo')).thenReturn(callable);

        final result = await PromoCodeService(
          functions,
          logger,
        ).validate('USEDUP', 1000);

        expect(result.isValid, isFalse);
        expect(result.message, 'Promo code has been fully redeemed');
        expect(
          callable.attempts,
          1,
          reason: 'permanent code — retrying a fully-redeemed promo is waste',
        );
      },
    );

    test('applyPromo: transient unavailability retried to success', () async {
      final logger = _makeLogger();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
      when(
        () => mockResult.data,
      ).thenReturn({'valid': true, 'discountCents': 500});
      final callable = ScriptedCallable([
        _ffe('unavailable'),
        _ffe('unavailable'),
        mockResult,
      ]);
      final functions = MockFirebaseFunctions();
      when(() => functions.httpsCallable('applyPromo')).thenReturn(callable);

      final result = await PromoCodeService(
        functions,
        logger,
      ).validate('SAVE5', 2000);

      expect(result.isValid, isTrue);
      expect(result.discountCents, 500);
      expect(callable.attempts, 3);
    });

    test('TaxService.calculate: transient x2 retried, result parsed', () async {
      final logger = _makeLogger();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
      when(
        () => mockResult.data,
      ).thenReturn({'taxCents': 725, 'rate': 0.0725, 'stateCode': 'CA'});
      final callable = ScriptedCallable([
        _ffe('unavailable'),
        _ffe('internal'),
        mockResult,
      ]);
      final functions = MockFirebaseFunctions();
      when(() => functions.httpsCallable('calculateTax')).thenReturn(callable);

      final result = await TaxService(
        functions: functions,
        logger: logger,
      ).calculate(stateCode: 'CA', subtotalCents: 10000);

      expect(result.taxCents, 725);
      expect(result.rateLabel, '7.25%');
      expect(callable.attempts, 3);
    });

    test(
      'TaxService.calculate: permission-denied fails closed after ONE attempt',
      () async {
        final logger = _makeLogger();
        final callable = ScriptedCallable([_ffe('permission-denied')]);
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('calculateTax'),
        ).thenReturn(callable);

        await expectLater(
          TaxService(
            functions: functions,
            logger: logger,
          ).calculate(stateCode: 'CA', subtotalCents: 10000),
          throwsA(isA<FirebaseFunctionsException>()),
        );
        expect(callable.attempts, 1, reason: 'never retry an authz rejection');
      },
    );
  });

  group('P-2 one-shot reads — fetchBranch / panic / auth / menu', () {
    test(
      'fetchBranch: transient unavailability retried, snapshot returned',
      () async {
        final logger = _makeLogger();
        final snapshot = MockDocumentSnapshot();
        when(() => snapshot.exists).thenReturn(true);
        final docRef = MockDocumentReference();
        var attempts = 0;
        when(() => docRef.get()).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw _fs('unavailable');
          return snapshot;
        });
        final collection = MockCollectionRef();
        when(() => collection.doc('branch-1')).thenReturn(docRef);
        final fs = MockFirebaseFirestore();
        when(() => fs.collection('branches')).thenReturn(collection);

        final svc = CheckoutService(
          firestore: fs,
          functions: MockFirebaseFunctions(),
          promoService: PromoCodeService(MockFirebaseFunctions(), logger),
          logger: logger,
          tenantClaim: const FixedTenantClaim(),
        );

        final result = await svc.fetchBranch('branch-1');
        expect(result.exists, isTrue);
        expect(attempts, 2);
      },
    );

    test('fetchBranch: permission-denied rethrows after ONE attempt', () async {
      final logger = _makeLogger();
      final docRef = MockDocumentReference();
      var attempts = 0;
      when(() => docRef.get()).thenAnswer((_) async {
        attempts++;
        throw _fs('permission-denied');
      });
      final collection = MockCollectionRef();
      when(() => collection.doc('branch-1')).thenReturn(docRef);
      final fs = MockFirebaseFirestore();
      when(() => fs.collection('branches')).thenReturn(collection);

      final svc = CheckoutService(
        firestore: fs,
        functions: MockFirebaseFunctions(),
        promoService: PromoCodeService(MockFirebaseFunctions(), logger),
        logger: logger,
        tenantClaim: const FixedTenantClaim(),
      );

      await expectLater(
        svc.fetchBranch('branch-1'),
        throwsA(isA<FirebaseException>()),
      );
      expect(attempts, 1);
    });

    test(
      'PanicSwitchService.isOrdersAccepting: transient blip retried; gate honored',
      () async {
        final snapshot = MockDocumentSnapshot();
        when(() => snapshot.data()).thenReturn({'ordersAccepting': false});
        final docRef = MockDocumentReference();
        var attempts = 0;
        when(() => docRef.get()).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw _fs('unavailable');
          return snapshot;
        });
        // D-038: panic_switch_service reads
        // collection('settings').doc('<tenant>_restaurantConfig'), so the stub
        // follows that hop rather than the retired unprefixed path.
        final fs = MockFirebaseFirestore();
        final settings = MockCollectionReference();
        when(() => fs.collection('settings')).thenReturn(settings);
        when(
          () => settings.doc('tenant_a_restaurantConfig'),
        ).thenReturn(docRef);

        final gate = await PanicSwitchService(
          firestore: fs,
          tenantClaim: const FixedTenantClaim(),
        ).isOrdersAccepting();

        expect(
          gate,
          isFalse,
          reason: 'the paused gate must be honored, not defaulted to true',
        );
        expect(attempts, 2);
      },
    );

    test(
      'FirebaseAuthRepository.getUserData: transient blip retried; profile mapped',
      () async {
        final snapshot = MockDocumentSnapshot();
        when(() => snapshot.exists).thenReturn(true);
        when(() => snapshot.id).thenReturn('uid_1');
        when(() => snapshot.data()).thenReturn({
          'id': 'uid_1',
          'email': 'test@example.com',
          'name': 'Test User',
        });
        final docRef = MockDocumentReference();
        var attempts = 0;
        when(() => docRef.get()).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw _fs('unavailable');
          return snapshot;
        });
        final collection = MockCollectionRef();
        when(() => collection.doc('uid_1')).thenReturn(docRef);
        final fs = MockFirebaseFirestore();
        when(() => fs.collection('users')).thenReturn(collection);

        final repo = FirebaseAuthRepository(
          MockFirebaseAuth(),
          fs,
          _makeLogger(),
          cache: const NoOpLocalCache(),
        );

        final user = await repo.getUserData('uid_1');
        expect(user, isNotNull);
        expect(user!.name, 'Test User');
        expect(attempts, 2);
      },
    );

    test(
      'getUserData: permission-denied maps to the friendly error after ONE attempt',
      () async {
        final docRef = MockDocumentReference();
        var attempts = 0;
        when(() => docRef.get()).thenAnswer((_) async {
          attempts++;
          throw _fs('permission-denied');
        });
        final collection = MockCollectionRef();
        when(() => collection.doc('uid_1')).thenReturn(docRef);
        final fs = MockFirebaseFirestore();
        when(() => fs.collection('users')).thenReturn(collection);

        final repo = FirebaseAuthRepository(
          MockFirebaseAuth(),
          fs,
          _makeLogger(),
          cache: const NoOpLocalCache(),
        );

        await expectLater(repo.getUserData('uid_1'), throwsA(isA<Exception>()));
        expect(attempts, 1);
      },
    );

    test(
      'MenuRepository sync read: transient unavailability retried; cache path intact',
      () async {
        final logger = _makeLogger();
        final dir = Directory.systemTemp.createTempSync('retry_menu_test_');
        final isar = await Isar.open([
          IsarMenuItemSchema,
          IsarCartSchema,
          IsarPendingOperationSchema,
          IsarDeadLetterSchema,
        ], directory: dir.path);
        addTearDown(() async {
          await isar.close();
          Directory(dir.path).deleteSync(recursive: true);
        });

        final snapshot = MockQuerySnapshot();
        when(() => snapshot.docs).thenReturn([]);
        final query = MockCollectionRef();
        var attempts = 0;
        when(() => query.get()).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw _fs('unavailable');
          return snapshot;
        });
        when(() => query.limit(any())).thenReturn(query);
        final fs = MockFirebaseFirestore();
        when(() => fs.collection('menus')).thenReturn(query);

        final isarSvc = MockIsarService();
        when(() => isarSvc.db).thenAnswer((_) async => isar);

        final repo = MenuRepository(fs, isarSvc, logger);
        final items = await repo.getMenuItems();

        expect(
          items,
          isEmpty,
          reason: 'empty menu stays empty — cache path intact',
        );
        expect(
          attempts,
          2,
          reason: 'the wrapped Firestore read (menu sync) must retry',
        );
      },
    );

    test('MenuRepository: permanent sync failure with NO cache fails loud '
        '(a Firestore outage must not masquerade as an empty menu)', () async {
      final logger = _makeLogger();
      final dir = Directory.systemTemp.createTempSync('retry_menu_loud_');
      final isar = await Isar.open([
        IsarMenuItemSchema,
        IsarCartSchema,
        IsarPendingOperationSchema,
        IsarDeadLetterSchema,
      ], directory: dir.path);
      addTearDown(() async {
        await isar.close();
        Directory(dir.path).deleteSync(recursive: true);
      });

      var attempts = 0;
      final query = MockCollectionRef();
      when(() => query.get()).thenAnswer((_) async {
        attempts++;
        throw _fs('permission-denied', 'stale rules');
      });
      when(() => query.limit(any())).thenReturn(query);
      final fs = MockFirebaseFirestore();
      when(() => fs.collection('menus')).thenReturn(query);

      final isarSvc = MockIsarService();
      when(() => isarSvc.db).thenAnswer((_) async => isar);

      final repo = MenuRepository(fs, isarSvc, logger);

      await expectLater(
        repo.getMenuItems(),
        throwsA(isA<MenuFetchException>()),
        reason:
            'empty cache + failed sync must surface the failure so the UI '
            'renders its error state, never "Menu is empty"',
      );
      expect(
        attempts,
        1,
        reason:
            'permission-denied is permanent — NetworkRetry must not back it off',
      );
    });

    test(
      'MenuRepository: permanent sync failure with a stale cache still serves the cache',
      () async {
        final logger = _makeLogger();
        final dir = Directory.systemTemp.createTempSync('retry_menu_stale_');
        final isar = await Isar.open([
          IsarMenuItemSchema,
          IsarCartSchema,
          IsarPendingOperationSchema,
          IsarDeadLetterSchema,
        ], directory: dir.path);
        addTearDown(() async {
          await isar.close();
          Directory(dir.path).deleteSync(recursive: true);
        });

        // TTL-stale cache entry (>= 1h old) so getMenuItems takes the sync path.
        await isar.writeTxn(() async {
          await isar.isarMenuItems.put(
            IsarMenuItem()
              ..firestoreId = 'cached_1'
              ..name = 'Cached Burger'
              ..price = 1250
              ..category = 'mains'
              ..isAvailable = true
              ..lastUpdated = DateTime.now().subtract(const Duration(hours: 2))
              ..cachedAt = DateTime.now().subtract(const Duration(hours: 2)),
          );
        });

        final query = MockCollectionRef();
        when(() => query.get()).thenAnswer(
          (_) async => throw _fs('permission-denied', 'stale rules'),
        );
        when(() => query.limit(any())).thenReturn(query);
        final fs = MockFirebaseFirestore();
        when(() => fs.collection('menus')).thenReturn(query);

        final isarSvc = MockIsarService();
        when(() => isarSvc.db).thenAnswer((_) async => isar);

        final repo = MenuRepository(fs, isarSvc, logger);
        final items = await repo.getMenuItems();

        expect(
          items,
          hasLength(1),
          reason: 'offline-first: a failed refresh serves the stale cache',
        );
        expect(items.single.name, equals('Cached Burger'));
      },
    );
  });

  group('gdpr_service deleteUserData — wrapped with marker-first intact', () {
    test(
      'transient CF failure retried; durable marker written before the call',
      () async {
        final db = FakeFirebaseFirestore();
        const uid = 'gdpr-user';
        final auth = MockFirebaseAuth();
        final user = MockUser();
        when(() => user.uid).thenReturn(uid);
        when(() => auth.currentUser).thenReturn(user);

        final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
        when(() => mockResult.data).thenReturn({'success': true});
        final callable = ScriptedCallable([
          _ffe('unavailable', 'CF cold start'),
          mockResult,
        ]);
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('deleteUserData'),
        ).thenReturn(callable);

        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: _makeLogger(),
          functions: functions,
        );

        final ok = await service.deleteMyData();

        expect(ok, isTrue);
        expect(
          callable.attempts,
          2,
          reason: 'a cold-start internal/unavailable blip must be retried',
        );
        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(
          marker.exists,
          isTrue,
          reason:
              'the durable intent marker must be written BEFORE the callable',
        );
      },
    );

    test(
      'permission-denied CF: ONE attempt; marker stays in_progress (retrier picks up)',
      () async {
        final db = FakeFirebaseFirestore();
        const uid = 'gdpr-user-2';
        final auth = MockFirebaseAuth();
        final user = MockUser();
        when(() => user.uid).thenReturn(uid);
        when(() => auth.currentUser).thenReturn(user);

        final callable = ScriptedCallable([_ffe('permission-denied')]);
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('deleteUserData'),
        ).thenReturn(callable);

        final service = GdprService(
          firestore: db,
          auth: auth,
          logger: _makeLogger(),
          functions: functions,
        );

        await expectLater(service.deleteMyData(), throwsA(anything));

        expect(
          callable.attempts,
          1,
          reason: 'authz rejections never heal — no retry burn',
        );
        final marker = await db.collection('deletion_requests').doc(uid).get();
        expect(
          marker.data()?['status'],
          'in_progress',
          reason: 'a server-side retrier completes the erasure later',
        );
      },
    );
  });
}
