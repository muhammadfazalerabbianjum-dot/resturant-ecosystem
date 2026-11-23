// FIX-B12 (REC-B2-1) - the client maps the server's idempotency CONFLICT to a
// distinct, non-retryable, user-visible failure - never "order placed".
//
// Server contract (`functions/src/index.ts` idempotency block, wired in this
// batch): same key + same content -> `{orderId, idempotent: true}` (B2's
// legitimate retry shape, byte-identical); same key + DIFFERENT content ->
// `HttpsError('already-exists', details: {code: 'IDEMPOTENCY_CONFLICT',
// reason})` + a `logSecurityAlert` - the foreign orderId is never returned.
//
// Client contract under test (`checkout_service.dart`):
//  * T-1 same key + same content still resolves to the same orderId with
//    `idempotent: true` (regression pin - B2 retry path untouched);
//  * T-2 THE DEFECT ROW (client side): the marker error maps to
//    IdempotencyConflictException - THROWN, never a success map;
//  * T-3 the conflict is non-retryable: `already-exists` is permanent in
//    `NetworkRetry` (B5), so it surfaces after exactly ONE call;
//  * T-4 the mapping is precise: an `already-exists` WITHOUT the
//    `IDEMPOTENCY_CONFLICT` marker is rethrown unchanged;
//  * T-5 control: transient failures still burn the bounded backoff - the
//    mapping never disables retry for genuine transport errors;
//  * T-6 the conflict failure is user-visible and never reads as success.
//
// Receipt for the catch blocks cited by R-3: `checkout_service.dart` catches
// at :247 / :308 / :353 (fetchBranch, calculateFinalTotal, calculateTax) and
// the `createOrder` catch itself only LOG + RETHROW today - none of them maps
// `already-exists` to anything, so the conflict surfaced as a generic failure
// (fail-closed, but not truthful). This file pins the distinct mapping.
//
// MONEY SANCTUARY (law 0.4): a NEW test file only; no existing test changes.
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:mocktail/mocktail.dart';
import '../../../support/tenant_claim_fakes.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

const String kUid = 'user-1';

/// The server's conflict error exactly as `createOrder` throws it.
FirebaseFunctionsException conflictException({
  String reason = 'customer_mismatch',
}) => FirebaseFunctionsException(
  code: 'already-exists',
  message: 'Idempotency key was already used by a different order attempt',
  details: {'code': 'IDEMPOTENCY_CONFLICT', 'reason': reason},
);

/// Scripted `createOrder` callable: counts calls and answers via [behavior].
class ScriptedCreateOrderServer {
  ScriptedCreateOrderServer(FirebaseFunctions functions, this.behavior) {
    when(() => functions.httpsCallable('createOrder')).thenReturn(_callable);
    when(() => _callable.call(any())).thenAnswer((inv) async {
      calls++;
      return behavior();
    });
  }

  final MockHttpsCallable _callable = MockHttpsCallable();
  final Future<HttpsCallableResult<Map<String, dynamic>>> Function() behavior;
  int calls = 0;
}

HttpsCallableResult<Map<String, dynamic>> resultOf(Map<String, dynamic> data) {
  final result = MockCallableResult<Map<String, dynamic>>();
  when(() => result.data).thenReturn(data);
  return result;
}

CheckoutService createService(FirebaseFunctions functions) {
  final logger = LoggerService(
    testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
  );
  return CheckoutService(
    firestore: FakeFirebaseFirestore(),
    functions: functions,
    promoService: PromoCodeService(functions, logger),
    logger: logger,
    tenantClaim: const FixedTenantClaim(),
  );
}

OrderModel orderFor(String id) => OrderModel(
  id: id,
  customerId: kUid,
  totalCents: 1620,
  createdAt: DateTime.now(),
  items: const [],
);

Future<Map<String, dynamic>> submitOrder(
  CheckoutService service, {
  String paymentIntentId = 'pi_1',
  String idempotencyKey = 'key_same_attempt',
}) => service.createOrder(
  paymentIntentId: paymentIntentId,
  order: orderFor('ORD-A'),
  userId: kUid,
  idempotencyKey: idempotencyKey,
);

/// Runs [submitOrder] and captures whatever it throws (null = returned).
Future<Object?> caughtSubmit(CheckoutService service) async {
  try {
    return await submitOrder(service);
  } catch (e) {
    return e;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  // Production retries transient failures with real exponential backoff; these
  // rows are about CLASSIFICATION and call counts, never wall-clock - the same
  // seam checkout_order_scoped_idempotency_test.dart uses.
  setUp(() {
    NetworkRetry.delay = (_) async {};
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  group('FIX-B12 (REC-B2-1) - idempotency conflict client mapping', () {
    test('T-1 same key + same content still returns the same orderId with '
        'idempotent: true (B2 retry path regression pin)', () async {
      final functions = MockFirebaseFunctions();
      final server = ScriptedCreateOrderServer(functions, () async {
        return resultOf({'orderId': 'ORD-A', 'idempotent': true});
      });
      final service = createService(functions);

      final result = await submitOrder(service);

      expect(result, {'orderId': 'ORD-A', 'idempotent': true});
      expect(result['idempotent'], true);
      expect(server.calls, 1);
    });

    test(
      'T-2 THE DEFECT (client): conflict maps to IdempotencyConflictException '
      '- never a success map',
      () async {
        final functions = MockFirebaseFunctions();
        final server = ScriptedCreateOrderServer(functions, () async {
          return throw conflictException(reason: 'customer_mismatch');
        });
        final service = createService(functions);

        await expectLater(
          submitOrder(service),
          throwsA(
            isA<IdempotencyConflictException>().having(
              (e) => e.reason,
              'reason',
              'customer_mismatch',
            ),
          ),
        );
        expect(server.calls, 1);
      },
    );

    test('T-3 conflict is NON-RETRYABLE (B5: already-exists is permanent) - '
        'exactly one call, no backoff burn', () async {
      final functions = MockFirebaseFunctions();
      final server = ScriptedCreateOrderServer(functions, () async {
        return throw conflictException(reason: 'payment_intent_mismatch');
      });
      final service = createService(functions);

      expect(NetworkRetry.isRetryable(conflictException()), isFalse);

      await expectLater(
        submitOrder(service),
        throwsA(isA<IdempotencyConflictException>()),
      );
      expect(server.calls, 1, reason: 'already-exists must not be retried');
    });

    test(
      'T-4 mapping precision: already-exists WITHOUT the IDEMPOTENCY_CONFLICT '
      'marker rethrows unchanged (no false conflict)',
      () async {
        final functions = MockFirebaseFunctions();
        ScriptedCreateOrderServer(functions, () async {
          return throw FirebaseFunctionsException(
            code: 'already-exists',
            message: 'Email already registered.',
          );
        });
        final service = createService(functions);

        final caught = await caughtSubmit(service);
        expect(caught, isA<FirebaseFunctionsException>());
        expect(caught, isNot(isA<IdempotencyConflictException>()));
      },
    );

    test('T-5 control: transient failures still burn the bounded backoff '
        '(4 calls) and surface - retry is NOT disabled', () async {
      final functions = MockFirebaseFunctions();
      final server = ScriptedCreateOrderServer(functions, () async {
        return throw Exception('connection closed before the response');
      });
      final service = createService(functions);

      final caught = await caughtSubmit(service);
      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<FirebaseFunctionsException>()));
      expect(server.calls, 4, reason: 'maxRetries 3 => 4 attempts (B5 ladder)');
    });

    test(
      'T-6 the conflict failure is user-visible and never reads as success',
      () async {
        final functions = MockFirebaseFunctions();
        ScriptedCreateOrderServer(functions, () async {
          return throw conflictException(reason: 'amount_mismatch');
        });
        final service = createService(functions);

        final caught = await caughtSubmit(service);
        expect(caught, isA<IdempotencyConflictException>());
        final conflict = caught! as IdempotencyConflictException;
        expect(conflict.reason, 'amount_mismatch');
        expect(conflict.message, isNotEmpty);
        expect(
          conflict.message,
          contains('No duplicate order was placed'),
          reason: 'the screen must never present this as an order success',
        );
        expect(conflict.toString(), contains('amount_mismatch'));
      },
    );
  });
}
