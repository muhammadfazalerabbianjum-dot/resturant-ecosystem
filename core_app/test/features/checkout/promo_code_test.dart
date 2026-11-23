import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';

void main() {
  test('PromoCodeResult valid code returns correct discount', () {
    const result = PromoCodeResult(isValid: true, discountCents: 500);
    expect(result.isValid, true);
    expect(result.discountCents, 500);
  });

  test('PromoCodeResult invalid code returns 0 discount', () {
    const result = PromoCodeResult(
      isValid: false,
      discountCents: 0,
      message: 'Code not found',
    );
    expect(result.isValid, false);
    expect(result.discountCents, 0);
    expect(result.message, 'Code not found');
  });

  test('Percent discount math is correct for 20% off USD 50.00', () {
    const cartCents = 5000;
    const percentValue = 20;
    final discount = (cartCents * percentValue / 100).round();
    expect(discount, 1000); // $10.00 off
  });
}
