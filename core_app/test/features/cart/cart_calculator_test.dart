import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

void main() {
  test(
    'Cart calculates total correctly from multiple items and quantities',
    () {
      const item1 = MenuItemModel(
        id: '1',
        name: 'Burger',
        priceCents: 500,
        category: 'Menu',
      );
      const item2 = MenuItemModel(
        id: '2',
        name: 'Fries',
        priceCents: 200,
        category: 'Menu',
      );

      const cart = CartModel(
        items: [
          CartItemModel(item: item1, quantity: 2), // $10.00
          CartItemModel(item: item2, quantity: 1), // $2.00
        ],
      );

      expect(cart.totalCents, 1200); // Expect $12.00
    },
  );

  test('Cart total is 0 when empty', () {
    const cart = CartModel();
    expect(cart.totalCents, 0);
  });
}
