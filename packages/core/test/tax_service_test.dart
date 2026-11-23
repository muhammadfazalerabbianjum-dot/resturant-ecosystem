import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

import 'helpers/mock_firebase.dart';
import 'helpers/recording_logger.dart';

class _TestCoreConfig implements CoreConfig {
  const _TestCoreConfig();

  @override
  bool get isDemoMode => false;

  @override
  String get clientId => 'wl-client';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const <String>[];

  @override
  String get kitchenLanEndpoint => '';
}

/// CORE-COV Tier-2 TAX suite: the server-authority contract — the ONLY
/// source of truth for tax is the calculateTax callable; results are typed,
/// the white-label clientId is injected from CoreConfig, and every failure
/// FAILS CLOSED by rethrowing (never a silent $0 tax).
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    NetworkRetry.delay = (Duration duration) async {};
  });

  tearDown(() {
    CoreConfigHolder.set(const DefaultCoreConfig());
    NetworkRetry.delay = Future<void>.delayed;
  });

  group('TaxService.calculate', () {
    late MockFirebaseFunctions functions;

    setUp(() {
      functions = MockFirebaseFunctions();
    });

    TaxService service() =>
        TaxService(functions: functions, logger: RecordingLogger());

    MockHttpsCallable callable() {
      final mock = MockHttpsCallable();
      when(() => functions.httpsCallable('calculateTax')).thenReturn(mock);
      return mock;
    }

    MockCallableResult result(Map<String, dynamic> data) {
      final mock = MockCallableResult();
      when(() => mock.data).thenReturn(data);
      return mock;
    }

    test('maps the server payload into a typed TaxResult', () async {
      final mock = callable();
      CoreConfigHolder.set(const _TestCoreConfig());
      when(() => mock.call(captureAny<dynamic>())).thenAnswer(
        (_) async => result(<String, dynamic>{
          'taxCents': 900,
          'rate': 0.09,
          'stateCode': 'CA',
        }),
      );

      final tax = await service().calculate(
        stateCode: 'CA',
        subtotalCents: 10000,
      );

      expect(tax.taxCents, 900);
      expect(tax.rate, 0.09);
      expect(tax.stateCode, 'CA');
      expect(tax.rateLabel, '9.00%');
      final payload =
          verify(() => mock.call(captureAny<dynamic>())).captured.single
              as Map<dynamic, dynamic>;
      expect(payload['stateCode'], 'CA');
      expect(payload['subtotalCents'], 10000);
      expect(payload['clientId'], 'wl-client');
    });

    test('subtotal is integer cents — never a client-computed tax', () async {
      final mock = callable();
      when(() => mock.call(captureAny<dynamic>())).thenAnswer(
        (_) async => result(<String, dynamic>{
          'taxCents': 0,
          'rate': 0.0,
          'stateCode': 'TX',
        }),
      );

      final tax = await service().calculate(
        stateCode: 'TX',
        subtotalCents: 1,
        clientId: 'explicit',
      );

      expect(tax.taxCents, 0);
      final payload =
          verify(() => mock.call(captureAny<dynamic>())).captured.single
              as Map<dynamic, dynamic>;
      expect(payload['clientId'], 'explicit');
    });

    test(
      'callable failure FAILS CLOSED (rethrows — caller aborts checkout)',
      () async {
        final mock = callable();
        when(
          () => mock.call(any<dynamic>()),
        ).thenAnswer((_) async => throw TestFunctionsException('internal'));

        await expectLater(
          service().calculate(stateCode: 'CA', subtotalCents: 10000),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      },
    );

    test(
      'transient failures are retried before the fail-closed rethrow',
      () async {
        final mock = callable();
        var calls = 0;
        when(() => mock.call(any<dynamic>())).thenAnswer((_) async {
          calls++;
          if (calls < 3) throw TestFunctionsException('unavailable');
          return result(<String, dynamic>{
            'taxCents': 900,
            'rate': 0.09,
            'stateCode': 'CA',
          });
        });

        final tax = await service().calculate(
          stateCode: 'CA',
          subtotalCents: 10000,
        );
        expect(tax.taxCents, 900);
        expect(
          calls,
          3,
          reason: 'QUEUE-2: bounded classified retry on a pure read',
        );
      },
    );
  });
}
