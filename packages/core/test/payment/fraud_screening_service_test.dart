import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:core/src/payment/fraud_screening_service.dart';

/// PERF-1 (T-6) — FraudScreeningService production path: the `allowed`
/// contract plus the FAIL-CLOSED guarantees (Law 8/12 — a security control
/// must reject, never silently allow, on ANY error).

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult {}

/// The [FirebaseFunctionsException] constructor is @protected — subclassing
/// is the documented way to fabricate the typed exception (same pattern as
/// the shared `TestFunctionsException` helper).
class _TestFunctionsException extends FirebaseFunctionsException {
  _TestFunctionsException(String code) : super(code: code, message: 'test');
}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable('screenPaymentFraud'),
    ).thenReturn(callable);
  });

  Future<bool> screenWith(Object? data) {
    when(() => callable.call()).thenAnswer((_) async {
      final result = _MockResult();
      when(() => result.data).thenReturn(data);
      return result;
    });
    return FraudScreeningService(functions: functions).screenPayment();
  }

  test("the function's allowed=true verdict ALLOWS the payment", () async {
    expect(await screenWith(<String, dynamic>{'allowed': true}), isTrue);
  });

  test("the function's allowed=false verdict REJECTS the payment", () async {
    expect(await screenWith(<String, dynamic>{'allowed': false}), isFalse);
  });

  test('a permission-denied function error FAILS CLOSED (reject)', () async {
    when(
      () => callable.call(),
    ).thenThrow(_TestFunctionsException('permission-denied'));
    expect(
      await FraudScreeningService(functions: functions).screenPayment(),
      isFalse,
      reason: 'a security control must never fail open on a function error',
    );
  });

  test('an arbitrary backend error FAILS CLOSED (reject)', () async {
    when(() => callable.call()).thenThrow(StateError('backend down'));
    expect(
      await FraudScreeningService(functions: functions).screenPayment(),
      isFalse,
    );
  });

  test('a non-bool allowed payload is treated as NOT allowed', () async {
    expect(
      await screenWith(<String, dynamic>{'allowed': 'yes'}),
      isFalse,
      reason: "the contract is strictly `allowed == true`",
    );
  });
}
