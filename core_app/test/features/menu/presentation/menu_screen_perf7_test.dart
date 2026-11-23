// PERF-7 — menu screen: search filter, category chip, add-to-cart from a
// row, and the sold-out no-add guarantee. mergedMenuProvider is overridden
// directly (the stream provider replaces both Firestore streams), and the
// cart provider is warmed like the dish-detail suite (autoDispose notifier
// cold-starts on a bare read).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import '../../../helpers/app_localizations_test_helper.dart';

class _CapturingCartRepo extends CartRepository {
  _CapturingCartRepo()
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel _last = const CartModel(items: []);

  List<CartItemModel> get items => _last.items;

  @override
  Future<CartModel> loadCart() async => _last;

  @override
  Future<void> saveCart(CartModel cart) async => _last = cart;
}

const tBurger = MenuItemModel(
  id: 'b1',
  name: 'Burger',
  description: 'Beef burger',
  priceCents: 1000,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 5,
);
const tPizza = MenuItemModel(
  id: 'p1',
  name: 'Pizza',
  description: 'Cheese pizza',
  priceCents: 1200,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 5,
);
const tSoldOut = MenuItemModel(
  id: 's1',
  name: 'Sushi',
  description: 'Unavailable today',
  priceCents: 2000,
  category: 'mains',
  isAvailable: false,
  quantityRemaining: 0,
);

Widget buildApp({
  required List<MenuItemModel> items,
  // Public base type (mirrors cart_screen_perf7_test.dart): a private type in a
  // public signature trips `library_private_types_in_public_api`, which is
  // fatal under `flutter analyze --fatal-infos`.
  CartRepository? cartRepo,
  String? initialCategory,
}) {
  return ProviderScope(
    overrides: [
      mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      if (cartRepo != null)
        cartRepositoryProvider.overrideWith((ref) => cartRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: MenuScreen(initialCategory: initialCategory),
    ),
  );
}

void main() {
  testWidgets('all available items render by default', (tester) async {
    await tester.pumpWidget(buildApp(items: const [tBurger, tPizza, tSoldOut]));
    await tester.pumpAndSettle();

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Sushi'), findsOneWidget);
  });

  testWidgets('search narrows the list to matching items', (tester) async {
    await tester.pumpWidget(buildApp(items: const [tBurger, tPizza, tSoldOut]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pumpAndSettle();

    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Burger'), findsNothing);
  });

  testWidgets('the row add control writes through the cart provider', (
    tester,
  ) async {
    final repo = _CapturingCartRepo();
    await tester.pumpWidget(
      buildApp(items: const [tBurger, tSoldOut], cartRepo: repo),
    );
    await tester.pumpAndSettle();

    // Warm the autoDispose cart notifier: the row add uses ref.read, which
    // early-returns on a cold state (cart_provider.dart:72).
    final container = ProviderScope.containerOf(
      tester.element(find.text('Burger')),
    );
    container.listen<AsyncValue<CartModel>>(cartProvider, (_, __) {});
    await container.read(cartProvider.notifier).loadCart();

    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pumpAndSettle();

    expect(
      repo.items.single.item.id,
      'b1',
      reason: 'the menu-row add must write through to the repository',
    );
    // The sold-out row renders remove_shopping_cart instead — no second add.
    expect(find.byIcon(Icons.remove_shopping_cart), findsOneWidget);
  });
}
