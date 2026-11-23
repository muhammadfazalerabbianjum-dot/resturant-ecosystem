// UI-6 (p16) Phase A — menu adoption (MenuTile + PriceTag + StaggeredEntrance
// + EmptyStateWidget). Written RED before the wiring (p16 §3 phase A);
// the A2 money-parity table is the mandatory L13 guard.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';

import '../../../helpers/app_localizations_test_helper.dart';

const String _kRawCloudinaryUrl =
    'https://res.cloudinary.com/carnama/image/upload/v1721000000/menu/burger.jpg';

MenuItemModel _item({
  required String id,
  required String name,
  int priceCents = 999,
  String? imageUrl,
  bool isAvailable = true,
  List<String> tags = const [],
}) => MenuItemModel(
  id: id,
  name: name,
  description: 'Description for $name',
  priceCents: priceCents,
  imageUrl: imageUrl,
  category: 'General',
  tags: tags,
  isAvailable: isAvailable,
);

/// Localized harness; [currency] drives the config provider the production
/// row reads (W9.3 config-driven currency).
Widget _harness({
  required List<MenuItemModel> items,
  String? currency,
  CartRepository? cartRepo,
  FakeFirebaseFirestore? firestore,
}) => ProviderScope(
  // Riverpod applies `overrides` when the ProviderContainer is created, so
  // re-keying the scope per currency gives every iteration a FRESH
  // container — without this the A2 loop would silently reuse the first
  // iteration's container and every code would render the $ fallback
  // (the table would then only prove the fallback, not L13 parity).
  key: ValueKey<String>('p16-${currency ?? 'fallback'}'),
  overrides: [
    mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
    // null code => the provider never emits, so the row's
    // `valueOrNull?.currency` resolves to null (the documented $ fallback).
    restaurantConfigProvider.overrideWith(
      (ref) => currency == null
          ? const Stream<RestaurantConfigModel>.empty()
          : Stream<RestaurantConfigModel>.value(
              RestaurantConfigModel(currency: currency),
            ),
    ),
    if (firestore != null) firestoreProvider.overrideWithValue(firestore),
    if (cartRepo != null)
      cartRepositoryProvider.overrideWith((ref) => cartRepo),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizationsTestHelper.delegates,
    supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    home: MenuScreen(),
  ),
);

/// In-memory cart repository (same double as menu_screen_perf7_test) so the
/// row add writes through instead of erroring on the real Isar path.
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

void main() {
  group('P16 A — menu adoption', () {
    testWidgets('A2: menu prices render through PriceTag, byte-identical to '
        'formatCurrencyCents across the supported code set (L13 parity)', (
      tester,
    ) async {
      // The L13 edge set: positive known codes, thousands grouping, a
      // negative (CLDR sign), a lower-case code, an unknown code
      // (fail-closed CODE prefix) and the null-code $ fallback.
      const codes = <String?>[
        null,
        'USD',
        'CAD',
        'AUD',
        'EUR',
        'GBP',
        'JPY',
        'KRW',
        'AED',
        'SAR',
        'usd',
        'XYZ',
      ];
      const centsSet = [1250, 1234567, -150];

      for (final code in codes) {
        final items = [
          for (var i = 0; i < centsSet.length; i++)
            _item(id: 'p$i', name: 'Parity $i', priceCents: centsSet[i]),
        ];
        await tester.pumpWidget(_harness(items: items, currency: code));
        await tester.pumpAndSettle();

        // RED signal: the menu must adopt the library PriceTag.
        expect(
          find.byType(PriceTag),
          findsNWidgets(centsSet.length),
          reason: 'every menu row price must render via PriceTag (code=$code)',
        );

        final rendered = tester
            .widgetList<PriceTag>(find.byType(PriceTag))
            .map((t) => t.cents)
            .toList();
        expect(rendered, centsSet, reason: 'cents forwarded verbatim ($code)');

        // Byte parity: each rendered string equals the canonical formatter.
        for (var i = 0; i < centsSet.length; i++) {
          final expected = formatCurrencyCents(centsSet[i], currencyCode: code);
          expect(
            find.text(expected),
            findsOneWidget,
            reason:
                'PriceTag($code, ${centsSet[i]}) must render exactly '
                '"$expected"',
          );
        }
      }
    });

    testWidgets('A1: rows are MenuTiles carrying Hero + cloudinaryThumb', (
      tester,
    ) async {
      // Explicit pumps (home-suite pattern): pumpAndSettle never settles
      // while the transport-blocked thumbnail's skeleton shimmer is visible.
      await tester.pumpWidget(
        _harness(
          items: [
            _item(id: 'b1', name: 'Burger', imageUrl: _kRawCloudinaryUrl),
            _item(id: 'p1', name: 'Pizza'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(MenuTile), findsNWidgets(2));

      // L14: Hero tag on the dish image + STATE-3 CDN thumbnail (w_100).
      expect(find.byType(Hero), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CachedNetworkImage &&
              w.imageUrl == cloudinaryThumb(_kRawCloudinaryUrl, width: 100),
        ),
        findsOneWidget,
      );

      // Drain flutter_cache_manager's 10 s cleanup Timer.
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('A1: the composed menu-row Semantics label is preserved', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _harness(
            items: [_item(id: 'b1', name: 'Burger', priceCents: 999)],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          // The composed label leads the node; ListTile's own texts merge in
          // behind it with '\n' separators (asserted as an anchored prefix).
          find.bySemanticsLabel(
            RegExp(r'^Burger, \$9\.99\. Tap to add to cart'),
          ),
          findsOneWidget,
          reason: 'the composed label (name, price, hint) must survive wiring',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('A1: sold-out gating keeps the disabled add affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          items: [_item(id: 's1', name: 'Sushi', isAvailable: false)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_shopping_cart), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
    });

    testWidgets('A1: row add keeps the snackbar feedback', (tester) async {
      final repo = _CapturingCartRepo();
      await tester.pumpWidget(
        _harness(
          items: [_item(id: 'b1', name: 'Burger')],
          cartRepo: repo,
          firestore: FakeFirebaseFirestore(),
        ),
      );
      await tester.pumpAndSettle();

      // Warm the autoDispose cart notifier (cold read early-returns).
      final container = ProviderScope.containerOf(
        tester.element(find.text('Burger')),
      );
      container.listen<AsyncValue<CartModel>>(cartProvider, (_, __) {});
      await container.read(cartProvider.notifier).loadCart();

      await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
      await tester.pumpAndSettle();

      expect(repo.items.single.item.id, 'b1');
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('A3: the menu body enters through StaggeredEntrance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          items: [_item(id: 'b1', name: 'Burger')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StaggeredEntrance), findsOneWidget);
    });

    testWidgets('A4: an empty category renders EmptyStateWidget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          items: [
            _item(id: 'v1', name: 'Vegan Salad', tags: const ['vegan']),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.textContaining('No items match'), findsOneWidget);
    });
  });
}
