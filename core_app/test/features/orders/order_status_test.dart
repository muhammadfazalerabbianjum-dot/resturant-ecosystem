import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';

void main() {
  test('OrderStatus parses remote status correctly from Firebase strings', () {
    expect(OrderStatus.fromString('pending'), OrderStatus.pending);
    expect(OrderStatus.fromString('cooking'), OrderStatus.cooking);
    expect(OrderStatus.fromString('ready'), OrderStatus.ready);
  });

  test('OrderStatus handles maliciously malformed JSON keys gracefully', () {
    expect(OrderStatus.fromString('alien_abduction'), OrderStatus.pending);
    expect(OrderStatus.fromString(''), OrderStatus.pending);
  });
}
