import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

import 'helpers/mock_firebase.dart';

/// A demo-mode [CoreConfig] (mirrors the app's kDemoMode injection).
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

/// CORE-COV Tier-1 PAYMENT suite: the fraud-screening client contract
/// (fail-closed on every error path — Law 8/12) and the NFC terminal's
/// documented no-SDK contract (never a fake charge).
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('FraudScreeningService — production callable path', () {
    late MockFirebaseFunctions functions;
    late MockHttpsCallable callable;
    late FraudScreeningService service;

    setUp(() {
      functions = MockFirebaseFunctions();
      callable = MockHttpsCallable();
      when(
        () => functions.httpsCallable('screenPaymentFraud'),
      ).thenReturn(callable);
      service = FraudScreeningService(functions: functions);
    });

    MockCallableResult result(Map<String, dynamic> data) {
      final mock = MockCallableResult();
      when(() => mock.data).thenReturn(data);
      return mock;
    }

    test('allowed:true lets the payment proceed', () async {
      when(
        () => callable.call(),
      ).thenAnswer((_) async => result(<String, dynamic>{'allowed': true}));
      expect(await service.screenPayment(), isTrue);
    });

    test('allowed:false blocks the payment', () async {
      when(
        () => callable.call(),
      ).thenAnswer((_) async => result(<String, dynamic>{'allowed': false}));
      expect(await service.screenPayment(), isFalse);
    });

    test('a non-bool allowed value blocks (strict true contract)', () async {
      when(
        () => callable.call(),
      ).thenAnswer((_) async => result(<String, dynamic>{'allowed': 'true'}));
      expect(await service.screenPayment(), isFalse);
    });

    test('permission-denied is fail-closed', () async {
      when(
        () => callable.call(),
      ).thenThrow(TestFunctionsException('permission-denied'));
      expect(await service.screenPayment(), isFalse);
    });

    test('any other error is fail-closed (never silently allows)', () async {
      when(() => callable.call()).thenThrow(StateError('boom'));
      expect(await service.screenPayment(), isFalse);
    });
  });

  group('FraudScreeningService — demo mode (Firestore count)', () {
    tearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));

    test('no Firebase runtime fails CLOSED (never a silent allow)', () async {
      CoreConfigHolder.set(const _DemoCoreConfig());
      // The demo path reads FirebaseAuth.instance/FirebaseFirestore.instance;
      // in this test binary neither Firebase app exists, so the control MUST
      // reject rather than throw or allow. The mocked functions instance
      // satisfies construction without touching FirebaseFunctions.instance.
      final service = FraudScreeningService(functions: MockFirebaseFunctions());
      expect(await service.screenPayment(), isFalse);
    });
  });

  group('NfcTerminalService — documented no-SDK contract', () {
    test('collectPayment never claims a charge', () async {
      final result = await NfcTerminalService.instance.collectPayment(
        paymentIntentClientSecret: 'secret',
        amountCents: 1999,
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.chargeId, isNull);
    });

    test(
      'discoverReader returns null (no reader — not a fake success)',
      () async {
        expect(await NfcTerminalService.instance.discoverReader(), isNull);
      },
    );

    test('initialize is idempotent and never throws', () async {
      await NfcTerminalService.instance.initialize(
        fetchConnectionToken: () async => 'token',
      );
      await NfcTerminalService.instance.initialize(
        fetchConnectionToken: () async => 'token',
      );
    });
  });
}
