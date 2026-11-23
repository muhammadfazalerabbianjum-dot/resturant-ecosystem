import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:core/core.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('FraudScreeningService', () {
    late FraudScreeningService service;

    setUp(() {
      service = FraudScreeningService();
    });

    test(
      'screenPayment FAILS CLOSED when no user is signed in (Law 8/12)',
      () async {
        // In demo mode, it uses local Firestore count.
        // FAIL-CLOSED: no authenticated user => reject the payment.
        final result = await service.screenPayment();
        expect(result, false);
      },
    );

    test('FraudScreeningService can be instantiated', () {
      expect(service, isNotNull);
    });

    test('FraudScreeningService can be instantiated with custom functions', () {
      final customService = FraudScreeningService(functions: null);
      expect(customService, isNotNull);
    });

    test('screenPayment does not throw when called multiple times', () async {
      for (int i = 0; i < 3; i++) {
        final result = await service.screenPayment();
        expect(result, isA<bool>());
      }
    });

    test('screenPayment returns a boolean', () async {
      final result = await service.screenPayment();
      expect(result, isA<bool>());
    });

    test(
      'FraudScreeningService constructor accepts null functions parameter',
      () {
        final svc = FraudScreeningService(functions: null);
        expect(svc, isNotNull);
      },
    );
  });
}
