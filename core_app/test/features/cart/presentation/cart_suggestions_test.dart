// P2-3 (p31) — in-cart cross-sell fills the dead zone.
//
// RED-first contract: the cart's mid-section rendered ~50% empty space
// between the last line item and the totals tray (visual-pack capture,
// 2026-10-03). The fix appends a "You may also like" section INSIDE the
// cart list: suggestions come from the same merged menu stream, exclude
// carted/sold-out items, cap at four, and are display-plus-tap only —
// nothing is added to the cart before the customer taps add.
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/platform_mocks.dart';

class _RecordingCartRepo extends CartRepository {
  _RecordingCartRepo(this._initial)
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel _initial;

  @override
  Future<CartModel> loadCart() async => _initial;

  @override
  Future<void> saveCart(CartModel cart) async => _initial = cart;
}

const _burger = MenuItemModel(
  id: 'i1',
  name: 'Burger',
  priceCents: 1000,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 10,
);
const _fries = MenuItemModel(
  id: 'i2',
  name: 'Fries',
  priceCents: 500,
  category: 'sides',
  isAvailable: true,
  quantityRemaining: 10,
);
const _shake = MenuItemModel(
  id: 'i3',
  name: 'Shake',
  priceCents: 700,
  category: 'drinks',
  isAvailable: true,
  quantityRemaining: 10,
);
const _special = MenuItemModel(
  id: 'i4',
  name: 'Chef Special',
  priceCents: 1900,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 10,
  modifiers: [MenuModifier(id: 'spice', name: 'Spice level')],
);

Future<void> _seedMenu(
  FakeFirebaseFirestore firestore,
  MenuItemModel item,
) async {
  await firestore.collection('menus').doc(item.id).set({
    'name': item.name,
    'category': item.category,
    'priceCents': item.priceCents,
    'isAvailable': item.isAvailable,
    'branchId': null,
    // P2-3: modifiers must round-trip — the quick-add gate reads them.
    'modifiers': [for (final m in item.modifiers) m.toJson()],
  });
}

/// The RUNNING TOTAL (the p16 D2 `large` PriceTag) — line rows carry their
/// own small PriceTags with the unit price, so text alone can't isolate it.
Finder _largeTotal(WidgetTester tester, int cents) =>
    find.byWidgetPredicate((w) => w is PriceTag && w.large && w.cents == cents);

Widget _buildApp({
  required CartRepository repo,
  required FakeFirebaseFirestore firestore,
}) {
  return ProviderScope(
    overrides: [
      cartRepositoryProvider.overrideWith((ref) => repo),
      firestoreProvider.overrideWithValue(firestore),
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
            name: 'menu',
            builder: (context, state) =>
                const Scaffold(body: Text('Menu Home')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await setupPlatformMocks();
  });

  group('cartSuggestionsFor (pure)', () {
    test(
      'keeps menu order, drops carted/sold-out/zero-stock, caps at four',
      () {
        const burger = MenuItemModel(
          id: 'i1',
          name: 'Burger',
          priceCents: 1000,
        );
        const menu = <MenuItemModel>[
          burger,
          MenuItemModel(
            id: 'i2',
            name: 'Fries',
            priceCents: 500,
            isAvailable: true,
            quantityRemaining: 3,
          ),
          MenuItemModel(
            id: 'i3',
            name: 'Shake',
            priceCents: 700,
            isAvailable: true,
            quantityRemaining: 3,
          ),
          MenuItemModel(
            id: 'i4',
            name: 'Sold Out',
            priceCents: 300,
            isAvailable: false,
          ),
          MenuItemModel(
            id: 'i5',
            name: 'No Stock',
            priceCents: 300,
            quantityRemaining: 0,
          ),
          MenuItemModel(
            id: 'i6',
            name: 'Soup',
            priceCents: 600,
            isAvailable: true,
            quantityRemaining: 3,
          ),
          MenuItemModel(
            id: 'i7',
            name: 'Curry',
            priceCents: 900,
            isAvailable: true,
            quantityRemaining: 3,
          ),
          MenuItemModel(
            id: 'i8',
            name: 'Wrap',
            priceCents: 800,
            isAvailable: true,
            quantityRemaining: 3,
          ),
        ];
        const cart = CartModel(
          items: [CartItemModel(item: burger, quantity: 1)],
        );

        final out = cartSuggestionsFor(menu: menu, cart: cart);

        expect(
          out.map((i) => i.id).toList(),
          ['i2', 'i3', 'i6', 'i7'],
          reason:
              'carted i1 dropped, sold-out i4 and zero-stock i5 dropped, '
              'menu order kept, i8 capped by the four-item limit',
        );
      },
    );
  });

  group('CartScreen suggestions (P2-3)', () {
    testWidgets('renders You may also like with non-carted items only', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedMenu(firestore, _burger);
      await _seedMenu(firestore, _fries);
      await _seedMenu(firestore, _shake);
      final repo = _RecordingCartRepo(
        const CartModel(items: [CartItemModel(item: _burger, quantity: 1)]),
      );

      await tester.pumpWidget(_buildApp(repo: repo, firestore: firestore));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('You may also like'), findsOneWidget);
      expect(find.text('Fries'), findsOneWidget);
      expect(find.text('Shake'), findsOneWidget);
      // The carted Burger renders as the cart line, never as a suggestion.
      expect(find.text('Burger'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tapping add puts the suggestion in the cart', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedMenu(firestore, _burger);
      await _seedMenu(firestore, _fries);
      final repo = _RecordingCartRepo(
        const CartModel(items: [CartItemModel(item: _burger, quantity: 1)]),
      );

      await tester.pumpWidget(_buildApp(repo: repo, firestore: firestore));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Before the tap: the LARGE total is the carted Burger only —
      // nothing enters the cart implicitly.
      expect(_largeTotal(tester, 1000), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // After ONE explicit tap: Fries joined the cart.
      expect(_largeTotal(tester, 1500), findsOneWidget);
      expect(find.text('Fries'), findsOneWidget);

      // Let the add-to-cart SnackBar's dismissal timer expire.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('modifier dishes render without quick-add', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedMenu(firestore, _burger);
      await _seedMenu(firestore, _special);
      final repo = _RecordingCartRepo(
        const CartModel(items: [CartItemModel(item: _burger, quantity: 1)]),
      );

      await tester.pumpWidget(_buildApp(repo: repo, firestore: firestore));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Chef Special'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an empty menu renders no suggestions section', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final repo = _RecordingCartRepo(
        const CartModel(items: [CartItemModel(item: _burger, quantity: 1)]),
      );

      await tester.pumpWidget(_buildApp(repo: repo, firestore: firestore));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('You may also like'), findsNothing);
      expect(find.byType(PriceTag), findsWidgets);

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
