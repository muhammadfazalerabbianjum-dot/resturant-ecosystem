// UI-6 (p16) Phase B — dish detail adoption (PriceTag large + QuantityStepper
// + InfoBanner). Written RED before the wiring (p16 §3 phase B); the B1b
// money-parity table is the mandatory L13 guard for this surface.
//
// NOTE ON B3: p16 B3 reads "informational/allergen notices -> InfoBanner".
// The allergen disclaimer banner was REMOVED by owner decision O-1
// (DECISIONS_LOG.md) and is PINNED deleted by
// core_app/test/app/deleted_sources_pin_test.dart, so it is NOT reintroducible
// by an adoption wave. The surviving notice on this surface is the sold-out
// state; that is what adopts InfoBanner here (tone mapping explicit). Recorded
// as DRIFT + a report entry, never silently dropped.
import 'dart:io';

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
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';

import '../../../helpers/app_localizations_test_helper.dart';

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

MenuItemModel _item({
  int priceCents = 1000,
  int? quantityRemaining = 10,
  bool isAvailable = true,
}) => MenuItemModel(
  id: 'item_123',
  name: 'Test Dish',
  description: 'A test dish description',
  priceCents: priceCents,
  isAvailable: isAvailable,
  quantityRemaining: quantityRemaining,
  modifiers: const [tModifier],
);

/// In-memory cart repository (same double as the W8.9 / PERF-6a-1 dish-detail
/// suites) — the default Isar-backed repo errors in widget tests, which makes
/// `addItem` a silent no-op and would make the quantity assertions vacuous.
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

/// Localized harness; [currency] drives the config provider the screen reads.
///
/// [keySeed] must distinguish any two pumps whose OVERRIDES differ. Riverpod
/// applies `overrides` when the ProviderContainer is created, so without a
/// fresh container the previous override's stream keeps feeding the screen —
/// the B1b table would then assert the first iteration's price on every
/// iteration (proving nothing about L13 parity).
Widget _harness({
  required List<MenuItemModel> items,
  String menuItemId = 'item_123',
  String? currency,
  CartRepository? cartRepo,
  String? keySeed,
  bool warmConfigOnly = false,
}) => ProviderScope(
  key: ValueKey<String>('p16B-${currency ?? 'fallback'}-${keySeed ?? ''}'),
  overrides: [
    // The detail screen resolves through menuItemByIdProvider, which reads the
    // merged branch stream FIRST (Law 4) — so that is the deterministic seam.
    mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
    // null code => the provider never emits, so the screen's
    // `valueOrNull?.currency` resolves to null (the documented $ fallback).
    restaurantConfigProvider.overrideWith(
      (ref) => currency == null
          ? const Stream<RestaurantConfigModel>.empty()
          : Stream<RestaurantConfigModel>.value(
              RestaurantConfigModel(currency: currency),
            ),
    ),
    firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    if (cartRepo != null)
      cartRepositoryProvider.overrideWith((ref) => cartRepo),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizationsTestHelper.delegates,
    supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    home: warmConfigOnly
        ? const _ConfigWarmup()
        : DishDetailScreen(menuItemId: menuItemId),
  ),
);

/// Reads [restaurantConfigProvider] so it actually SUBSCRIBES during the
/// warm-up frame. A StreamProvider is lazy — it never touches its stream until
/// something reads it — so merely pumping the scope would leave the provider
/// uninitialised and the screen's (pre-existing, `ref.read`-based) currency
/// lookup would still see null on its first build.
class _ConfigWarmup extends ConsumerWidget {
  const _ConfigWarmup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(restaurantConfigProvider);
    return const SizedBox.shrink();
  }
}

/// Pins the single cart notifier for the whole test and resolves its async
/// state, so `addItem` actually mutates instead of early-returning on null.
Future<ProviderContainer> _warmCart(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DishDetailScreen)),
  );
  final sub = container.listen<AsyncValue<CartModel>>(cartProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(cartProvider.notifier).loadCart();
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('P16 B — dish detail adoption', () {
    testWidgets(
      'B1: the price renders through PriceTag(large: true) and carries the '
      'modifier-inclusive total in cents verbatim',
      (tester) async {
        await tester.pumpWidget(_harness(items: [_item()]));
        await tester.pumpAndSettle();

        // RED signal: the detail price must adopt the library PriceTag.
        expect(find.byType(PriceTag), findsOneWidget);

        final tag = tester.widget<PriceTag>(find.byType(PriceTag));
        expect(tag.cents, 1000, reason: 'base price with no modifier selected');
        expect(
          tag.large,
          isTrue,
          reason: 'B1: detail surfaces use the 22sp prominent variant',
        );

        // The upcharge stays DISPLAY-ONLY (never recomputed) and must still be
        // reflected in the total the tag shows.
        await tester.tap(find.text('Large  +\$1.50'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PriceTag>(find.byType(PriceTag)).cents,
          1150,
          reason: '1000 base + 150 upcharge, forwarded in cents verbatim',
        );
      },
    );

    testWidgets(
      'B1b: the rendered price is byte-identical to formatCurrencyCents across '
      'the supported code set (L13 money-display parity)',
      (tester) async {
        // The L13 edge set: the null-code $ fallback, positive known codes,
        // thousands grouping, a negative (CLDR sign), a lower-case code and an
        // unknown code (fail-closed CODE prefix).
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
          for (final cents in centsSet) {
            final items = [_item(priceCents: cents)];
            // A NEW container per (code, cents) — see `keySeed`.
            final seed = '$code-$cents';

            // The screen resolves the currency with `ref.read` (pre-existing
            // behaviour, preserved by L14), so a config stream that is still
            // pending at first build renders the `$` fallback. Production never
            // sees that: the app resolves the config during boot, long before
            // the user pushes this route. Mirror that order by warming the SAME
            // container (= same key) before mounting the screen, so the table
            // asserts byte parity under the real condition, not the fallback.
            await tester.pumpWidget(
              _harness(
                items: items,
                currency: code,
                keySeed: seed,
                warmConfigOnly: true,
              ),
            );
            await tester.pumpAndSettle();

            await tester.pumpWidget(
              _harness(items: items, currency: code, keySeed: seed),
            );
            await tester.pumpAndSettle();

            expect(
              find.byType(PriceTag),
              findsOneWidget,
              reason: 'the detail price must render via PriceTag (code=$code)',
            );
            expect(
              tester.widget<PriceTag>(find.byType(PriceTag)).cents,
              cents,
              reason: 'cents are forwarded verbatim ($code)',
            );

            final expected = formatCurrencyCents(cents, currencyCode: code);
            expect(
              find.text(expected),
              findsOneWidget,
              reason:
                  'PriceTag($code, $cents) must render exactly "$expected" — '
                  'formatCurrencyCents delegates to moneyCents, so the '
                  'supported set stays byte-identical',
            );

            // Self-guard: the warm-up must actually have resolved the
            // configured code. Where a code formats differently from the `$`
            // fallback, that fallback must be ABSENT — otherwise this table
            // could silently degrade into asserting only the fallback on every
            // row and prove nothing about L13 parity.
            final fallback = formatCurrencyCents(cents, currencyCode: null);
            if (expected != fallback) {
              expect(
                find.text(fallback),
                findsNothing,
                reason:
                    'the resolved code ($code) must win over the `\$` fallback',
              );
            }
          }
        }
      },
    );

    testWidgets('B2: a QuantityStepper owns the quantity, floored at 1', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(items: [_item()]));
      await tester.pumpAndSettle();

      expect(find.byType(QuantityStepper), findsOneWidget);
      final stepper = tester.widget<QuantityStepper>(
        find.byType(QuantityStepper),
      );
      expect(stepper.value, 1, reason: 'the picker starts at one portion');
      expect(stepper.minValue, 1, reason: 'adding zero is not an order');

      // The floor is a DISABLED control, not a clamped no-op: the owned state
      // cannot drift below the bound through the UI.
      final decrement = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      expect(decrement.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(
        tester.widget<QuantityStepper>(find.byType(QuantityStepper)).value,
        2,
        reason: 'stepping up updates the owned value',
      );
    });

    testWidgets('B2: the upper bound honours the remaining stock', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(items: [_item(quantityRemaining: 3)]));
      await tester.pumpAndSettle();

      expect(
        tester.widget<QuantityStepper>(find.byType(QuantityStepper)).maxValue,
        3,
        reason: 'never offer more portions than the kitchen has left',
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(
        tester.widget<QuantityStepper>(find.byType(QuantityStepper)).value,
        3,
      );

      final increment = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      expect(
        increment.onPressed,
        isNull,
        reason: 'the stock bound cannot be crossed through the UI',
      );
    });

    testWidgets(
      'B2: Add to Cart adds exactly the chosen quantity through the SAME '
      'provider path (haptic + snackbar preserved)',
      (tester) async {
        final repo = _CapturingCartRepo();
        await tester.pumpWidget(_harness(items: [_item()], cartRepo: repo));
        await tester.pumpAndSettle();
        await _warmCart(tester);

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Add to Cart'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to Cart'));
        await tester.pumpAndSettle();

        expect(repo.items, hasLength(1), reason: 'one line, not N lines');
        expect(
          repo.items.single.quantity,
          3,
          reason: 'the stepper value is the added quantity',
        );
        expect(
          repo.items.single.selectedOptions,
          isEmpty,
          reason: 'no modifier was selected in this test',
        );
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'B3: the sold-out notice renders through InfoBanner(soldOut) with the '
      'caller-supplied localized copy',
      (tester) async {
        await tester.pumpWidget(_harness(items: [_item(isAvailable: false)]));
        await tester.pumpAndSettle();

        expect(find.byType(InfoBanner), findsOneWidget);
        final banner = tester.widget<InfoBanner>(find.byType(InfoBanner));
        expect(
          banner.tone,
          InfoTone.soldOut,
          reason:
              'Q3: sold-out is its OWN semantic state — still a blocking, '
              'non-dismissible notice, but no longer dressed as a system error '
              '(p16 B3 chose error only because no soldOut tone existed)',
        );
        expect(
          banner.onDismiss,
          isNull,
          reason: 'the notice is not dismissible — it states a fact',
        );
        expect(
          find.byIcon(InfoBanner.iconFor(InfoTone.soldOut)),
          findsOneWidget,
          reason: 'the banner renders its tone icon',
        );
        // L14: the string stays caller-supplied from AppLocalizations.
        expect(find.text('Test Dish is sold out'), findsOneWidget);
        expect(
          find.byType(Chip),
          findsNothing,
          reason: 'the hand-rolled sold-out Chip is replaced by the banner',
        );
      },
    );
  });
}
