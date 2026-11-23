import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/menu_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

import '../../../helpers/app_localizations_test_helper.dart';

/// In-memory cart repository so the cart provider is FUNCTIONAL in widget
/// tests (the default repository hits the real Isar/paths and errors, which
/// makes `addItem` a no-op). Same double pattern as the runtime-audit tests.
class _InMemoryCartRepo extends CartRepository {
  _InMemoryCartRepo()
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<CartModel> loadCart() async => const CartModel(items: []);

  @override
  Future<void> saveCart(CartModel cart) async {}
}

/// Wraps the screen in a localized MaterialApp so the (l10n-driven) B2
/// strings resolve; still renders in English so behaviour assertions match.
Widget _buildApp({
  required String menuItemId,
  required List<MenuItemModel> items,
}) {
  return ProviderScope(
    overrides: [menuItemsProvider.overrideWith((ref) async => items)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: DishDetailScreen(menuItemId: menuItemId),
    ),
  );
}

void main() {
  group('DishDetailScreen Widget Tests', () {
    const tMockMenuItem = MenuItemModel(
      id: 'item_123',
      name: 'Test Dish',
      description: 'A test dish description',
      priceCents: 1000,
      isAvailable: true,
      quantityRemaining: 10,
      modifiers: [],
    );

    testWidgets('1. Renders dish detail screen with item name in title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tMockMenuItem]),
      );
      await tester.pumpAndSettle();

      // Item name should appear in headline
      expect(find.text('Test Dish'), findsWidgets);
      // Price should appear
      expect(find.text('\$10.00'), findsOneWidget);
    });

    testWidgets('2. Shows Add to Cart button (l10n en: "Add to Cart")', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tMockMenuItem]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    });

    testWidgets('3. Add to Cart button is tappable', (tester) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tMockMenuItem]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Add to Cart'), findsOneWidget);
    });

    testWidgets('4. Shows AppBar with item name', (tester) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'item_123', items: const [tMockMenuItem]),
      );
      await tester.pumpAndSettle();

      // AppBar title should be the item's name
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('5. Shows item not found for unknown item', (tester) async {
      await tester.pumpWidget(
        _buildApp(menuItemId: 'unknown_id', items: const [tMockMenuItem]),
      );
      await tester.pumpAndSettle();

      // Item not found — localized en value
      expect(find.text('Item not found'), findsOneWidget);
    });

    testWidgets(
      '6. W8.9 T-5: 11th add surfaces the TYPED limit as its localized copy',
      (tester) async {
        // Functional cart repository so addItem actually mutates state (the
        // default Isar-backed repo errors in widget tests → addItem no-ops).
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              menuItemsProvider.overrideWith(
                (ref) async => const [tMockMenuItem],
              ),
              cartRepositoryProvider.overrideWith((ref) => _InMemoryCartRepo()),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              home: DishDetailScreen(menuItemId: 'item_123'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final add = find.text('Add to Cart');
        // Adds 1..10 fill the per-item quantity cap (kMaxQuantityPerItem = 10,
        // cart_provider.dart) — no error copy may appear while under the cap.
        // Prefill via the REAL CartNotifier (tapping 10x is unreliable: each
        // success raises a bottom SnackBar that overlays the button).
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DishDetailScreen)),
        );
        // cartProvider is StateNotifierProvider.autoDispose: without an
        // ACTIVE listener it disposes at frame end, and every read re-creates
        // a fresh AsyncLoading instance (addItem no-ops on null state).
        // Holding one listener pins the SINGLE notifier for the whole test.
        final sub = container.listen<AsyncValue<CartModel>>(
          cartProvider,
          (prev, next) {},
        );
        addTearDown(sub.close);
        final notifier = container.read(cartProvider.notifier);
        // Let the async loadCart resolve before prefilling.
        await tester.pumpAndSettle();
        for (var i = 0; i < 10; i++) {
          await notifier.addItem(tMockMenuItem);
        }
        await tester.pumpAndSettle();
        expect(find.text('You can add up to 10 of this item.'), findsNothing);

        // Add #11 throws the TYPED CartItemQuantityLimitException, which the
        // screen maps to its OWN localized copy (W8.9 04-P2-5) — not the
        // generic addToCartFailed string, and never a raw exception.
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.text('You can add up to 10 of this item.'), findsOneWidget);
        expect(
          find.text('Could not add to cart. Please try again.'),
          findsNothing,
        );
      },
    );
  });
}
