// BATCH QUEUE-2 — T-4 companion: `screenPaymentFraud` stays UNWRAPPED
// (fail-closed, no blind retry) per batch contract 3.
//
// The spec gate is a code read ("no NetworkRetry on the fraud call"); this
// file additionally proves the BEHAVIOR: a transient CF blip must NOT be
// retried (fraud screening is a security control — retrying it on the client
// would multiply risk decisions during an incident), and every failure mode
// still fails CLOSED (returns false), never throws.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

/// Callable that throws [steps] in order, then repeats the last one, while
/// counting attempts — the mirror image of a success script.
class ThrowingCallable extends Mock implements HttpsCallable {
  final List<Object> steps;
  int attempts = 0;
  ThrowingCallable(this.steps);

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([Object? payload]) {
    attempts++;
    final index = attempts - 1 < steps.length ? attempts - 1 : steps.length - 1;
    throw steps[index];
  }
}

class OkCallable extends Mock implements HttpsCallable {
  int attempts = 0;
  final Map<String, dynamic> response;
  OkCallable(this.response);

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([Object? payload]) {
    attempts++;
    return Future.value(_FakeResult<T>(response as T));
  }
}

class _FakeResult<T> implements HttpsCallableResult<T> {
  @override
  final T data;
  _FakeResult(this.data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed; // production default restored
  });

  group(
    'T-4 — screenPaymentFraud is NOT retried (fail-closed, contract 3)',
    () {
      test(
        'transient unavailability: exactly ONE attempt, then reject',
        () async {
          final callable = ThrowingCallable([
            FirebaseFunctionsException(code: 'unavailable', message: 'blip'),
          ]);
          final functions = MockFirebaseFunctions();
          when(
            () => functions.httpsCallable('screenPaymentFraud'),
          ).thenReturn(callable);

          final result = await FraudScreeningService(
            functions: functions,
          ).screenPayment();

          expect(
            result,
            isFalse,
            reason: 'a security control must fail closed, never flap open',
          );
          expect(
            callable.attempts,
            1,
            reason: 'NO retry — the fraud call is deliberately unwrapped',
          );
        },
      );

      test('permission-denied: exactly ONE attempt, then reject', () async {
        final callable = ThrowingCallable([
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'rules',
          ),
        ]);
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('screenPaymentFraud'),
        ).thenReturn(callable);

        final result = await FraudScreeningService(
          functions: functions,
        ).screenPayment();

        expect(result, isFalse);
        expect(callable.attempts, 1);
      });

      test('any error type is caught — screenPayment never throws', () async {
        final callable = ThrowingCallable([Exception('socket exploded')]);
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('screenPaymentFraud'),
        ).thenReturn(callable);

        final result = await FraudScreeningService(
          functions: functions,
        ).screenPayment();

        expect(result, isFalse);
        expect(callable.attempts, 1);
      });

      test('success path: allowed==true passes through untouched', () async {
        final callable = OkCallable({'allowed': true});
        final functions = MockFirebaseFunctions();
        when(
          () => functions.httpsCallable('screenPaymentFraud'),
        ).thenReturn(callable);

        final result = await FraudScreeningService(
          functions: functions,
        ).screenPayment();

        expect(result, isTrue);
        expect(callable.attempts, 1);
      });
    },
  );
}
