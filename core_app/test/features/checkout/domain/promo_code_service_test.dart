import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:core/core.dart';
import 'dart:io';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T> {}

void main() {
  // QUEUE-2: production now retries transient failures with REAL exponential
  // backoff (NetworkRetry). These fail-closed tests assert that errors still
  // RETHROW regardless of classification, so the delay is neutralized to keep
  // them fast and under the default per-test timeout. Retry semantics are
  // proven in test/core/network/retry_wrapping_test.dart.
  setUp(() {
    NetworkRetry.delay = (_) async {};
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('PromoCodeService (B1 — server-authoritative applyPromo)', () {
    late LoggerService logger;
    late MockFirebaseFunctions mockFunctions;
    late PromoCodeService service;

    setUp(() {
      logger = LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );
      mockFunctions = MockFirebaseFunctions();
      service = PromoCodeService(mockFunctions, logger);
    });

    test('empty code returns invalid without calling the server', () async {
      final result = await service.validate('', 1000);
      expect(result.isValid, false);
      expect(result.message, 'Enter a code');
      verifyNever(() => mockFunctions.httpsCallable(any()));
    });

    test(
      'whitespace code returns invalid without calling the server',
      () async {
        final result = await service.validate('   ', 1000);
        expect(result.isValid, false);
      },
    );

    test(
      'normalises the code to UPPERCASE and forwards cart subtotal',
      () async {
        final mockCallable = MockHttpsCallable();
        final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
        when(
          () => mockFunctions.httpsCallable('applyPromo'),
        ).thenReturn(mockCallable);
        when(() => mockCallable.call(any())).thenAnswer((invocation) async {
          final payload =
              invocation.positionalArguments.first as Map<String, dynamic>;
          expect(payload['code'], 'SAVE10'); // lower-case input normalised
          expect(payload['cartSubtotalCents'], 2000);
          expect(payload.containsKey('discountCents'), isFalse); // never sent
          return mockResult;
        });
        when(
          () => mockResult.data,
        ).thenReturn({'valid': true, 'code': 'SAVE10', 'discountCents': 200});

        final result = await service.validate('save10', 2000);

        expect(result.isValid, true);
        expect(result.discountCents, 200);
      },
    );

    test('server-computed fixed discount is returned', () async {
      final mockCallable = MockHttpsCallable();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
      when(
        () => mockFunctions.httpsCallable('applyPromo'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenAnswer((_) async => mockResult);
      when(
        () => mockResult.data,
      ).thenReturn({'valid': true, 'code': 'SAVE5', 'discountCents': 500});

      final result = await service.validate('SAVE5', 2000);
      expect(result.isValid, true);
      expect(result.discountCents, 500);
    });

    test('rejected promo surfaces the SERVER message (exhausted)', () async {
      final mockCallable = MockHttpsCallable();
      when(
        () => mockFunctions.httpsCallable('applyPromo'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Promo code has been fully redeemed',
        ),
      );

      final result = await service.validate('USEDUP', 1000);
      expect(result.isValid, false);
      expect(result.message, 'Promo code has been fully redeemed');
      expect(result.discountCents, 0);
    });

    test('rejected promo surfaces the SERVER message (already used)', () async {
      final mockCallable = MockHttpsCallable();
      when(
        () => mockFunctions.httpsCallable('applyPromo'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Promo code has already been used',
        ),
      );

      final result = await service.validate('ONCE', 1000);
      expect(result.isValid, false);
      expect(result.message, 'Promo code has already been used');
    });

    test('network failure fails gracefully with an error message', () async {
      final mockCallable = MockHttpsCallable();
      when(
        () => mockFunctions.httpsCallable('applyPromo'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(Exception('socket error'));

      final result = await service.validate('SAVE5', 1000);
      expect(result.isValid, false);
      expect(result.message, 'Error checking code');
    });
  });
}
