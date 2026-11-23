// PERF-7 — cart screen: empty state, item rows, quantity steppers, remove,
// checkout navigation. Uses the capturing in-memory cart repository (the
// default Isar-backed repo errors in widget tests) — same double as the
// dish-detail suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import '../../../helpers/app_localizations_test_helper.dart';

class _CapturingCartRepo extends CartRepository {
  _CapturingCartRepo(this._initial)
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel _initial;

  List<CartItemModel> get items => _initial.items;

  @override
  Future<CartModel> loadCart() async => _initial;

  @override
  Future<void> saveCart(CartModel cart) async => _initial = cart;
}

const tBurger = MenuItemModel(
  id: 'i1',
  name: 'Burger',
  priceCents: 1000,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 10,
);
const tFries = MenuItemModel(
  id: 'i2',
  name: 'Fries',
  priceCents: 500,
  category: 'sides',
  isAvailable: true,
  quantityRemaining: 10,
);

Widget buildApp(CartRepository repo) {
  return ProviderScope(
    overrides: [
      cartRepositoryProvider.overrideWith((ref) => repo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/cart',
        routes: [
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/checkout',
            name: 'checkout',
            builder: (context, state) => const Scaffold(body: Text('Checkout')),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Menu Home')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('an empty cart shows the empty copy and no checkout', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_CapturingCartRepo(const CartModel(items: []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsNothing);
  });

  testWidgets('seeded items render with prices and the running total', (
    tester,
  ) async {
    final repo = _CapturingCartRepo(
      const CartModel(
        items: [
          CartItemModel(item: tBurger, quantity: 1),
          CartItemModel(item: tFries, quantity: 1),
        ],
      ),
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Fries'), findsOneWidget);
    // 1000 + 500 = 1500 cents → $15.00 with the default USD fallback.
    expect(find.text('\$15.00'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsOneWidget);
  });

  testWidgets('the stepper increments through the real provider', (
    tester,
  ) async {
    final repo = _CapturingCartRepo(
      const CartModel(items: [CartItemModel(item: tBurger, quantity: 1)]),
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(
      repo.items.single.quantity,
      2,
      reason: 'the stepper must write through cartProvider → repository',
    );
  });

  testWidgets('decreasing the last unit empties the cart', (tester) async {
    final repo = _CapturingCartRepo(
      const CartModel(items: [CartItemModel(item: tBurger, quantity: 1)]),
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    expect(
      repo.items,
      isEmpty,
      reason: 'removing the last unit must clear the persisted cart',
    );
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('proceed-to-checkout navigates to the checkout route', (
    tester,
  ) async {
    final repo = _CapturingCartRepo(
      const CartModel(items: [CartItemModel(item: tBurger, quantity: 1)]),
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Proceed to Checkout'));
    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
  });
}
