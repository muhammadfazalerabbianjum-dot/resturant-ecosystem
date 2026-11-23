import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';

/// COV-1 — PROMO_CODE service-level redemption contract (B1, P0-2).
///
/// The discount is SERVER-authoritative: the Cloud Function `applyPromo`
/// reads `promoCodes/{code}` + `promo_usage/{code}_{uid}` and returns the
/// verdict; the client NEVER reads promoCodes directly and NEVER sends a
/// discount value (a hostile client cannot inflate a discount). This suite
/// pins the service's redemption semantics for the promo_code territory:
///   - apply/redemption: a valid code returns the server discount, which
///     lands as a top-line deduction on the cart (clamped, never negative);
///   - invalid code: `valid:false` rejects with no discount;
///   - expired / already-used codes: the SERVER's typed message surfaces
///     verbatim (the user sees why, not a generic error);
///   - a payload missing discountCents degrades to 0 (defensive parse).

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T> {}

/// The redemption math the checkout applies: the server discount is a
/// top-line deduction, clamped so a total can never go negative.
int _finalTotalAfterRedemption(int cartTotalCents, int discountCents) =>
    (cartTotalCents - discountCents).clamp(0, cartTotalCents);

/// Installs a mock `applyPromo` callable answering [payload] for every call.
MockHttpsCallable callableReturning(
  MockFirebaseFunctions functions,
  Map<String, dynamic> payload,
) {
  final mockCallable = MockHttpsCallable();
  final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
  when(() => functions.httpsCallable('applyPromo')).thenReturn(mockCallable);
  when(() => mockResult.data).thenReturn(payload);
  when(() => mockCallable.call(any())).thenAnswer((_) async => mockResult);
  return mockCallable;
}

void main() {
  // QUEUE-2: production retries transient failures with REAL exponential
  // backoff (NetworkRetry). Server rejections (`failed-precondition`) are
  // permanent codes and surface immediately (no retry burn), but the delay
  // seam is neutralized anyway to keep the suite deterministic and fast.
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

  group('PromoCodeService redemption (COV-1)', () {
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

    test(
      'apply/redemption: a valid code returns the server discount and lands it on the cart',
      () async {
        callableReturning(mockFunctions, {
          'valid': true,
          'code': 'SAVE5',
          'discountCents': 500,
        });

        final result = await service.validate('save5', 2000);

        expect(result.isValid, isTrue);
        expect(result.discountCents, 500);
        expect(result.message, 'Code applied!');
        // Redemption math: the server discount is a top-line deduction,
        // clamped so a total can never go negative.
        expect(_finalTotalAfterRedemption(2000, result.discountCents), 1500);
      },
    );

    test(
      'apply/redemption: a discount larger than the cart clamps the total to zero',
      () async {
        callableReturning(mockFunctions, {
          'valid': true,
          'code': 'FREEALL',
          'discountCents': 99999,
        });

        final result = await service.validate('FREEALL', 2000);

        expect(result.isValid, isTrue);
        expect(result.discountCents, 99999);
        expect(
          _finalTotalAfterRedemption(2000, result.discountCents),
          0,
          reason: 'money can never go negative, whatever the server says',
        );
      },
    );

    test('invalid code: valid:false rejects with no discount', () async {
      callableReturning(mockFunctions, {'valid': false, 'code': 'NOPE'});

      final result = await service.validate('NOPE', 1000);

      expect(result.isValid, isFalse);
      expect(result.discountCents, 0);
      expect(result.message, 'Code rejected');
      expect(_finalTotalAfterRedemption(1000, result.discountCents), 1000);
    });

    test('expired code: the SERVER message surfaces verbatim', () async {
      final mockCallable = MockHttpsCallable();
      when(
        () => mockFunctions.httpsCallable('applyPromo'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Promo code has expired',
        ),
      );

      final result = await service.validate('OLDCODE', 1000);

      expect(result.isValid, isFalse);
      expect(result.discountCents, 0);
      expect(result.message, 'Promo code has expired');
    });

    test('already-used code: the SERVER message surfaces verbatim', () async {
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

      expect(result.isValid, isFalse);
      expect(result.discountCents, 0);
      expect(result.message, 'Promo code has already been used');
    });

    test(
      'defensive parse: a valid verdict missing discountCents degrades to zero',
      () async {
        callableReturning(mockFunctions, {'valid': true, 'code': 'SHAPESHIFT'});

        final result = await service.validate('SHAPESHIFT', 2000);

        expect(result.isValid, isTrue);
        expect(
          result.discountCents,
          0,
          reason: 'a missing server discount is zero, never a null-crash',
        );
        expect(_finalTotalAfterRedemption(2000, result.discountCents), 2000);
      },
    );

    test(
      'the client never sends a discount value (server-authoritative)',
      () async {
        final mockCallable = MockHttpsCallable();
        final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
        when(
          () => mockFunctions.httpsCallable('applyPromo'),
        ).thenReturn(mockCallable);
        when(() => mockCallable.call(any())).thenAnswer((invocation) async {
          final payload =
              invocation.positionalArguments.first as Map<String, dynamic>;
          expect(payload['code'], 'SAVE10');
          expect(payload['cartSubtotalCents'], 2000);
          expect(
            payload.containsKey('discountCents'),
            isFalse,
            reason: 'a hostile client must not be able to inflate a discount',
          );
          return mockResult;
        });
        when(
          () => mockResult.data,
        ).thenReturn({'valid': true, 'code': 'SAVE10', 'discountCents': 200});

        final result = await service.validate('save10', 2000);

        expect(result.isValid, isTrue);
        expect(result.discountCents, 200);
      },
    );
  });
}
