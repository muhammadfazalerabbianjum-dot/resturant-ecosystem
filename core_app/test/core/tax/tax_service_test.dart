import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

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

  group('TaxService - Cloud Function Mode', () {
    test('returns tax from Cloud Function on success', () async {
      final mockFunctions = MockFirebaseFunctions();
      final mockCallable = MockHttpsCallable();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();

      when(
        () => mockFunctions.httpsCallable('calculateTax'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenAnswer((_) async => mockResult);
      when(
        () => mockResult.data,
      ).thenReturn({'taxCents': 72, 'rate': 0.0725, 'stateCode': 'CA'});

      final service = TaxService(functions: mockFunctions);
      final result = await service.calculate(
        stateCode: 'CA',
        subtotalCents: 1000, // $10.00
      );

      expect(result.taxCents, 72);
      expect(result.rate, 0.0725);
      expect(result.stateCode, 'CA');
    });

    test('throws when Cloud Function is unavailable (fail-closed)', () async {
      final mockFunctions = MockFirebaseFunctions();
      final mockCallable = MockHttpsCallable();

      when(
        () => mockFunctions.httpsCallable('calculateTax'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Cloud Function not deployed',
        ),
      );

      final service = TaxService(functions: mockFunctions);

      await expectLater(
        () => service.calculate(stateCode: 'CA', subtotalCents: 1000),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test('throws for any state when Cloud Function is unavailable', () async {
      final mockFunctions = MockFirebaseFunctions();
      final mockCallable = MockHttpsCallable();

      when(
        () => mockFunctions.httpsCallable('calculateTax'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Cloud Function not deployed',
        ),
      );

      final service = TaxService(functions: mockFunctions);

      await expectLater(
        () => service.calculate(stateCode: 'NY', subtotalCents: 1550),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });

    test(
      'throws for unknown state when Cloud Function is unavailable',
      () async {
        final mockFunctions = MockFirebaseFunctions();
        final mockCallable = MockHttpsCallable();

        when(
          () => mockFunctions.httpsCallable('calculateTax'),
        ).thenReturn(mockCallable);
        when(() => mockCallable.call(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'unavailable',
            message: 'Cloud Function not deployed',
          ),
        );

        final service = TaxService(functions: mockFunctions);

        await expectLater(
          () => service.calculate(stateCode: 'WY', subtotalCents: 1000),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      },
    );

    test('zero subtotal returns zero tax from Cloud Function', () async {
      final mockFunctions = MockFirebaseFunctions();
      final mockCallable = MockHttpsCallable();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();

      when(
        () => mockFunctions.httpsCallable('calculateTax'),
      ).thenReturn(mockCallable);
      when(() => mockCallable.call(any())).thenAnswer((_) async => mockResult);
      when(
        () => mockResult.data,
      ).thenReturn({'taxCents': 0, 'rate': 0.0, 'stateCode': 'CA'});

      final service = TaxService(functions: mockFunctions);
      final result = await service.calculate(stateCode: 'CA', subtotalCents: 0);

      expect(result.taxCents, 0);
      expect(result.rate, 0.0);
    });

    test('rateLabel returns formatted percentage for 0%', () async {
      const result = TaxResult(taxCents: 0, rate: 0.0, stateCode: 'CA');
      expect(result.rateLabel, '0.00%');
    });

    test(
      'case insensitive state code is passed through to Cloud Function',
      () async {
        final mockFunctions = MockFirebaseFunctions();
        final mockCallable = MockHttpsCallable();
        final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();

        when(
          () => mockFunctions.httpsCallable('calculateTax'),
        ).thenReturn(mockCallable);
        when(
          () => mockCallable.call(any()),
        ).thenAnswer((_) async => mockResult);
        when(
          () => mockResult.data,
        ).thenReturn({'taxCents': 72, 'rate': 0.0725, 'stateCode': 'CA'});

        final service = TaxService(functions: mockFunctions);
        final lower = await service.calculate(
          stateCode: 'ca',
          subtotalCents: 1000,
        );
        final upper = await service.calculate(
          stateCode: 'CA',
          subtotalCents: 1000,
        );

        expect(lower.taxCents, upper.taxCents);
        expect(lower.rate, closeTo(upper.rate, 0.0001));
      },
    );
  });
}
