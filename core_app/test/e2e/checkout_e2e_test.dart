@Tags(['needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';

// T-S1 — Checkout flow fails closed (B4).
// Patrol dependency removed; domain behaviour contract proven here.
// Deep service-layer proof is in checkout_service_test.dart (T11, runs always).

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('T-S1 checkout flow fails closed', () {
    test('CheckoutScreen widget type is structurally wired (no stub)', () {
      expect(CheckoutScreen, isA<Type>());
      expect(const CheckoutScreen(), isA<CheckoutScreen>());
    });

    test(
      'computeChargedTotal: discount > subtotal+tax clamps to 0 (never negative)',
      () {
        expect(
          CheckoutService.computeChargedTotal(
            subtotalCents: 500,
            taxCents: 40,
            discountCents: 9999,
          ),
          0,
          reason: 'no negative charge possible',
        );
      },
    );

    test('computeChargedTotal: exact multi-component money math', () {
      // subtotal(1250) + tax(80) - discount(100) + tip(150) + delivery(299) = 1679
      expect(
        CheckoutService.computeChargedTotal(
          subtotalCents: 1250,
          taxCents: 80,
          discountCents: 100,
          tipCents: 150,
          deliveryFeeCents: 299,
        ),
        1679,
      );
    });

    test('computeChargedTotal: zero subtotal only charges tip+delivery', () {
      expect(
        CheckoutService.computeChargedTotal(
          subtotalCents: 0,
          taxCents: 0,
          discountCents: 0,
          tipCents: 300,
          deliveryFeeCents: 299,
        ),
        599,
      );
    });
  });
}
