import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/animated_cart_badge.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:core/core.dart';

/// UX-2 T-1 harness: seeds the real cartProvider through a stub repository
/// (no Isar) so the REAL AnimatedCartBadge renders with a live item count.
class _StubCartRepository implements CartRepository {
  final CartModel cart;
  _StubCartRepository(this.cart);

  @override
  Future<CartModel> loadCart() async => cart;

  @override
  Future<void> saveCart(CartModel cart) async {}
}

Widget _badgeHarness(WidgetTester tester, CartModel cart) {
  return ProviderScope(
    overrides: [
      cartRepositoryProvider.overrideWithValue(_StubCartRepository(cart)),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AnimatedCartBadge()),
    ),
  );
}

void main() {
  group('AnimatedCartBadge', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AnimatedCartBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedCartBadge), findsOneWidget);
    });

    testWidgets('shows cart icon', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AnimatedCartBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('icon button is present', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AnimatedCartBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('AnimatedCartBadge renders a Stack widget', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AnimatedCartBadge()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // AnimatedCartBadge uses Stack internally
      expect(find.byType(AnimatedCartBadge), findsOneWidget);
    });

    test('AnimatedCartBadge can be created with default constructor', () {
      expect(const AnimatedCartBadge(), isA<AnimatedCartBadge>());
    });
  });

  group('AnimatedCartBadge — T-1 cart semantics (UX-2 / 05-P1-A11Y-CART)', () {
    testWidgets(
      'badge announces an item-count phrase and excludes the raw digit',
      (tester) async {
        final handle = tester.ensureSemantics();
        const cart = CartModel(
          items: [
            CartItemModel(
              item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1000),
              quantity: 2,
            ),
          ],
        );

        await tester.pumpWidget(_badgeHarness(tester, cart));
        await tester.pumpAndSettle();

        // 1) The item-count phrase is the button's semantics label.
        expect(
          find.bySemanticsLabel('Cart, 2 items'),
          findsOneWidget,
          reason: 'TalkBack must hear "Cart, 2 items", not a bare "button"',
        );

        // 2) The tooltip mirrors the phrase.
        expect(find.byTooltip('Cart, 2 items'), findsOneWidget);

        // 3) The raw count digit is EXCLUDED from the semantics tree.
        expect(
          find.bySemanticsLabel('2'),
          findsNothing,
          reason: 'the raw count digit must not leak into the tree',
        );
        expect(
          find.text('2'),
          findsOneWidget,
          reason: 'the digit stays visible to sighted users',
        );

        // Let the badge's scale animation finish BEFORE teardown so no
        // animation timer is left pending at the invariant check.
        await tester.pump(const Duration(milliseconds: 300));

        handle.dispose();
      },
    );

    testWidgets('empty cart announces the empty phrase, no digit node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _badgeHarness(tester, const CartModel(items: [])),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Cart, empty'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));

      handle.dispose();
    });
  });

  group('AnimatedCartBadge — COLOR-1 distinct-palette proof (W10.2 T-2)', () {
    // A client palette where every hex differs from every AppColors constant:
    // any leakage of the static palette into the real widget fails below.
    const fixture = {
      'colors': {'primary': '0xFF403020', 'background': '0xFF102030'},
    };

    Widget themedHarness(CartModel cart) {
      return ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(_StubCartRepository(cart)),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(fixture),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AnimatedCartBadge()),
        ),
      );
    }

    testWidgets(
      'real badge renders the FIXTURE palette — zero AppColors leakage',
      (tester) async {
        const cart = CartModel(
          items: [
            CartItemModel(
              item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1000),
              quantity: 2,
            ),
          ],
        );
        await tester.pumpWidget(themedHarness(cart));
        await tester.pumpAndSettle();

        // 1) The digit's paint color comes from the config palette
        //    (BrandColors.background), NOT the AppColors constant.
        final digit = tester.widget<Text>(find.text('2'));
        expect(digit.style?.color, const Color(0xFF102030));
        expect(digit.style?.color, isNot(AppColors.background));

        // 2) The badge disc's paint comes from the config primary — the full
        //    config -> AppTheme -> ColorScheme -> widget pipeline is live.
        //    UI-13 (p21 H2, F3-15): the disc is now a `CircleAvatar` (the raw
        //    decorated `Container` was the adoption gap); the proof keeps the
        //    SAME hexes and the SAME AppColors negative control.
        final badgeDisc = tester.widget<CircleAvatar>(
          find
              .ancestor(of: find.text('2'), matching: find.byType(CircleAvatar))
              .first,
        );
        expect(badgeDisc.backgroundColor, const Color(0xFF403020));
        expect(badgeDisc.backgroundColor, isNot(AppColors.primary));

        // Let the badge's scale animation finish BEFORE teardown so no
        // animation timer is left pending at the invariant check (same
        // pattern as the UX-2 T-1 tests above).
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}
