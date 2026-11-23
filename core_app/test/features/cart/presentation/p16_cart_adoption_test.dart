// P16 (UI-6) — adoption wave 1, phase D (cart).
//
// RED-first contract: written BEFORE the phase-D wiring. D1/D2 must FAIL on
// the pre-wiring screen (library components not yet composed in); the two
// provider-flow cases and D3 pass at baseline BY DESIGN — they are the
// behavior-preservation proof (L14) and D3's EmptyStateWidget branch was
// already adopted pre-wave (asserted so it cannot regress).
//
// Money law (L13): D2 forwards the total VERBATIM in cents to the display-only
// PriceTag and asserts the rendered string is byte-identical to the pre-wiring
// call `formatCurrencyCents(totalCents, currencyCode: null)`.
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/currency_format.dart';
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

Widget _buildApp(CartRepository repo) {
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
  group('P16 D — cart adoption', () {
    testWidgets(
      'D1: line rows compose PriceTag per line + QuantityStepper per line',
      (tester) async {
        // The semantics tree only exists while a handle is active — required
        // for bySemanticsLabel (house pattern, p15 T-5: enable + dispose at
        // the end of the body — flutter_test verifies disposal before its own
        // addTearDown callbacks run).
        final semanticsHandle = tester.ensureSemantics();

        final repo = _CapturingCartRepo(
          const CartModel(
            items: [
              CartItemModel(item: _burger, quantity: 1),
              CartItemModel(item: _fries, quantity: 1),
            ],
          ),
        );
        await tester.pumpWidget(_buildApp(repo));
        await tester.pumpAndSettle();

        // One stepper per line, showing the line's quantity.
        final steppers = tester
            .widgetList<QuantityStepper>(find.byType(QuantityStepper))
            .toList();
        expect(steppers, hasLength(2), reason: 'one QuantityStepper per line');
        expect(steppers[0].value, 1);

        // PriceTag per line (unit price, verbatim cents) — L13: the string is
        // the same moneyCents rule set the old Text used.
        expect(
          find.widgetWithText(PriceTag, r'$10.00'),
          findsOneWidget,
          reason: 'line 1 unit price renders through PriceTag',
        );
        expect(
          find.widgetWithText(PriceTag, r'$5.00'),
          findsOneWidget,
          reason: 'line 2 unit price renders through PriceTag',
        );

        // The composed row label (L14) survives: name + qty + unit price.
        // Unanchored: the node label merges with the ListTile's inner texts,
        // so the composed string is a substring of the merged label.
        expect(
          find.bySemanticsLabel(RegExp(r'Burger, 1 x \$10\.00')),
          findsOneWidget,
        );
        semanticsHandle.dispose();
      },
    );

    testWidgets(
      'D1-flow: stepper writes through the real provider (preserved)',
      (tester) async {
        final repo = _CapturingCartRepo(
          const CartModel(items: [CartItemModel(item: _burger, quantity: 1)]),
        );
        await tester.pumpWidget(_buildApp(repo));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pumpAndSettle();
        expect(
          repo.items.single.quantity,
          2,
          reason: '+1 via addItem, unchanged',
        );

        await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
        await tester.pumpAndSettle();
        expect(
          repo.items.single.quantity,
          1,
          reason: 'unit decrement 2 -> 1 via removeItem, unchanged',
        );

        await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
        await tester.pumpAndSettle();
        expect(repo.items, isEmpty, reason: 'unit decrement clears at qty 1');
        expect(find.text('Your cart is empty'), findsOneWidget);
      },
    );

    testWidgets(
      'D2: total PriceTag receives cents verbatim; money string byte-identical',
      (tester) async {
        final repo = _CapturingCartRepo(
          const CartModel(
            items: [
              CartItemModel(item: _burger, quantity: 1),
              CartItemModel(item: _fries, quantity: 1),
            ],
          ),
        );
        await tester.pumpWidget(_buildApp(repo));
        await tester.pumpAndSettle();

        final totalTag = tester.widget<PriceTag>(
          find.widgetWithText(PriceTag, r'$15.00'),
        );
        expect(totalTag.cents, 1500, reason: 'display-only: cents verbatim');
        expect(totalTag.large, isTrue, reason: 'prominent totals variant');
        expect(
          find.text(formatCurrencyCents(1500, currencyCode: null)),
          findsOneWidget,
          reason: 'byte-identical to the pre-wiring total string',
        );
      },
    );

    testWidgets('D3: empty cart keeps the EmptyStateWidget branch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(_CapturingCartRepo(const CartModel(items: []))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Proceed to Checkout'), findsNothing);
    });
  });
}
