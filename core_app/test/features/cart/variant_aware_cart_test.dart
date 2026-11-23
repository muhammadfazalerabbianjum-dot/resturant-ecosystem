import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:core/core.dart';
import 'package:isar_community/isar.dart';
import 'dart:io';

import '../../helpers/app_localizations_test_helper.dart';

class _FakeIsarService extends IsarService {
  _FakeIsarService() : super.forTesting();

  @override
  Future<Isar> get db async => throw UnimplementedError();
}

class _InMemoryCartRepo extends CartRepository {
  CartModel current;
  _InMemoryCartRepo(this.current)
    : super(
        _FakeIsarService(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<CartModel> loadCart() async => current;

  @override
  Future<void> saveCart(CartModel cart) async {
    current = cart;
  }
}

void main() {
  group('B2-1 / T4: Variant-Aware Cart Mutations', () {
    const baseItem = MenuItemModel(
      id: 'burger_1',
      name: 'Gourmet Burger',
      priceCents: 1000,
    );

    const optionExtraCheese = ModifierOption(
      id: 'opt_cheese',
      name: 'Extra Cheese',
      upchargeCents: 150,
    );

    const optionBacon = ModifierOption(
      id: 'opt_bacon',
      name: 'Bacon',
      upchargeCents: 200,
    );

    test('sameCartVariant properly compares items with options', () {
      const itemA = CartItemModel(
        item: baseItem,
        selectedOptions: [optionExtraCheese],
      );
      const itemB = CartItemModel(
        item: baseItem,
        selectedOptions: [optionBacon],
      );
      const itemA2 = CartItemModel(
        item: baseItem,
        selectedOptions: [optionExtraCheese],
      );

      expect(sameCartVariant(itemA, itemB), isFalse);
      expect(sameCartVariant(itemA, itemA2), isTrue);
    });

    test(
      'CartNotifier handles multiple variants of the same item ID separately',
      () async {
        final repo = _InMemoryCartRepo(const CartModel(items: []));
        final notifier = CartNotifier(repo);

        // Explicitly await initial cart load
        await notifier.loadCart();

        // Add Variant A (Extra Cheese)
        await notifier.addItem(baseItem, selectedOptions: [optionExtraCheese]);
        // Add Variant B (Bacon)
        await notifier.addItem(baseItem, selectedOptions: [optionBacon]);

        var cart = notifier.state.value!;
        expect(cart.items.length, equals(2));
        expect(cart.items[0].selectedOptions.first.id, equals('opt_cheese'));
        expect(cart.items[1].selectedOptions.first.id, equals('opt_bacon'));

        // Remove Variant B only
        await notifier.removeItem(baseItem.id, selectedOptions: [optionBacon]);

        cart = notifier.state.value!;
        expect(cart.items.length, equals(1));
        expect(cart.items.first.selectedOptions.first.id, equals('opt_cheese'));
      },
    );

    testWidgets(
      'T4 UI: Dismissible renders unique keys for variants without collision',
      (tester) async {
        const cartWithVariants = CartModel(
          items: [
            CartItemModel(
              item: baseItem,
              quantity: 1,
              selectedOptions: [optionExtraCheese],
            ),
            CartItemModel(
              item: baseItem,
              quantity: 1,
              selectedOptions: [optionBacon],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartRepositoryProvider.overrideWith(
                (ref) => _InMemoryCartRepo(cartWithVariants),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: CartScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dismissibles = tester
            .widgetList<Dismissible>(find.byType(Dismissible))
            .toList();
        expect(dismissibles.length, equals(2));

        final key0 = (dismissibles[0].key as ValueKey<String>).value;
        final key1 = (dismissibles[1].key as ValueKey<String>).value;

        expect(key0, contains('burger_1'));
        expect(key1, contains('burger_1'));
        expect(key0, isNot(equals(key1)));
      },
    );
  });

  group('B2-1 / T1 & T13: Integer Money Math and Persistence', () {
    const item = MenuItemModel(
      id: 'pizza_1',
      name: 'Custom Pizza',
      priceCents: 1200,
    );

    const optionLarge = ModifierOption(
      id: 'opt_large',
      name: 'Large',
      upchargeCents: 400,
    );

    test(
      'T1: CartModel totalCents calculates exact integer cents with modifiers',
      () {
        const cartItem = CartItemModel(
          item: item,
          quantity: 3,
          selectedOptions: [optionLarge],
        );
        // (1200 + 400) * 3 = 4800 cents ($48.00)
        expect(cartItem.unitPriceCents, equals(1600));
        expect(cartItem.totalCents, equals(4800));

        const cart = CartModel(items: [cartItem]);
        expect(cart.totalCents, equals(4800));
      },
    );
  });
}
