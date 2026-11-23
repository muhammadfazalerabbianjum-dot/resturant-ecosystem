import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/menu_provider.dart';

import '../../../helpers/app_localizations_test_helper.dart';

// PERF-6a-1 — behavioral coverage for the modifier single-select, upcharge
// display, and sold-out paths of DishDetailScreen that the original suite
// did not reach (the file sat at 49% line coverage). Same doubles as the
// W8.9 suite: the default Isar-backed cart repository errors in widget
// tests, so a CAPTURING in-memory repo makes the cart provider FUNCTIONAL
// and records every saveCart for assertion.

class _CapturingCartRepo extends CartRepository {
  _CapturingCartRepo()
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel? lastSaved;

  @override
  Future<CartModel> loadCart() async => lastSaved ?? const CartModel(items: []);

  @override
  Future<void> saveCart(CartModel cart) async => lastSaved = cart;
}

const tSmallOption = ModifierOption(id: 'opt_small', name: 'Small');
const tLargeOption = ModifierOption(
  id: 'opt_large',
  name: 'Large',
  upchargeCents: 150,
);
const tModifier = MenuModifier(
  id: 'mod_size',
  name: 'Size',
  options: [tSmallOption, tLargeOption],
);
const tItem = MenuItemModel(
  id: 'item_123',
  name: 'Test Dish',
  description: 'A test dish description',
  priceCents: 1000,
  isAvailable: true,
  quantityRemaining: 10,
  modifiers: [tModifier],
);

Widget _buildApp({
  required String menuItemId,
  required List<MenuItemModel> items,
  _CapturingCartRepo? cartRepo,
}) {
  return ProviderScope(
    overrides: [
      menuItemsProvider.overrideWith((ref) async => items),
      if (cartRepo != null)
        cartRepositoryProvider.overrideWith((ref) => cartRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: DishDetailScreen(menuItemId: menuItemId),
    ),
  );
}

void main() {
  group('DishDetailScreen modifiers & availability (PERF-6a-1)', () {
    testWidgets('upcharge renders on the option label', (tester) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tItem]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Large  +\$1.50'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
    });

    testWidgets('selecting another option in the group REPLACES the selection '
        '(Law 25 — modifiers preserved, single-select per group)', (
      tester,
    ) async {
      final repo = _CapturingCartRepo();
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tItem], cartRepo: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large  +\$1.50'));
      await tester.pumpAndSettle();

      // The modifier group pushes the button below the fold in the test
      // viewport — bring it into view or the tap lands off-screen.
      await tester.ensureVisible(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      // Warm the async cart state: addItem early-returns while
      // `state.value == null` (cart_provider.dart:72). cartProvider is an
      // AutoDisposeStateNotifierProvider — holding a listener keeps the
      // notifier alive, and CartNotifier.loadCart() resolves the state.
      // The subscription itself is the point; it is intentionally not kept.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      container.listen<AsyncValue<CartModel>>(cartProvider, (_, __) {});
      await container.read(cartProvider.notifier).loadCart();
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      final items = repo.lastSaved?.items ?? const [];
      expect(items, hasLength(1));
      expect(
        items.single.selectedOptions.single.id,
        'opt_large',
        reason:
            'the second tap in the same group must REPLACE the first — '
            'a duplicated modifier would double-charge the upcharge',
      );
    });

    testWidgets('unavailable item disables Add to Cart', (tester) async {
      const unavailable = MenuItemModel(
        id: 'item_123',
        name: 'Test Dish',
        description: 'A test dish description',
        priceCents: 1000,
        isAvailable: false,
        quantityRemaining: 10,
        modifiers: [tModifier],
      );
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [unavailable]),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add to Cart'),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'an unavailable dish must never be addable',
      );
    });

    testWidgets('quantityRemaining 0 disables Add to Cart (sold out)', (
      tester,
    ) async {
      const soldOut = MenuItemModel(
        id: 'item_123',
        name: 'Test Dish',
        description: 'A test dish description',
        priceCents: 1000,
        isAvailable: true,
        quantityRemaining: 0,
        modifiers: [tModifier],
      );
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [soldOut]),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add to Cart'),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'zero remaining quantity is the sold-out path',
      );
    });
  });
}
