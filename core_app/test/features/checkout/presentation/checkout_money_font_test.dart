// P2-2 (p31) — money NEVER renders in the heading font.
//
// RED-first contract: the checkout total used to compose `moneyCents(...)`
// with `textTheme.displaySmall` — the config HEADING family (PlayfairDisplay
// in every shipped client) — and Playfair's raised, undersized `$` painted a
// stray currency glyph floating over `$20.98` (visual-pack capture,
// 2026-10-03 07:41). The fix re-uses the shared display-only `PriceTag`
// (body family by construction — the same widget the cart total already
// uses, whose correct rendering is the live control).
//
// Assertion shape: every currency-bearing Text on checkout keeps a family
// other than the heading family, and the grand total IS a PriceTag with
// cents forwarded verbatim (L13 display-only).
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/features/locations/data/location_repository.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/platform_mocks.dart';
import '../../../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

/// The heading family the client config actually resolves (halal_boyz:
/// `theme.typography.headingFont = PlayfairDisplay`). Injected on
/// `displaySmall` so the RED build reproduces the shipped defect without
/// needing the TTF on disk — the style carries the family string regardless.
const String _kHeadingFamily = 'PlayfairDisplay';

class _CapturingCartRepo extends CartRepository {
  _CapturingCartRepo(this._initial)
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

Widget _buildApp(CartRepository repo) {
  final base = AppTheme.lightTheme;
  // P2-2: heading/body split — displaySmall = heading family, everything
  // else stays default, exactly the config-driven theme shape.
  final theme = base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: _kHeadingFamily,
      ),
    ),
  );
  return ProviderScope(
    overrides: [
      cartRepositoryProvider.overrideWithValue(repo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      restaurantConfigProvider.overrideWith(
        (ref) => Stream.value(
          const RestaurantConfigModel(
            currency: 'USD',
            deliveryFeeCents: 300,
            tipEnabled: true,
          ),
        ),
      ),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      currentUserIdProvider.overrideWithValue('p31-uid'),
      locationsProvider.overrideWith((ref) async => const []),
      loggerProvider.overrideWithValue(FakeLogger()),
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      syncQueueProvider.overrideWithValue(RecordingSyncQueue()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      theme: theme,
      routerConfig: GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(
            path: '/checkout',
            name: RouteNames.checkout,
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/',
            name: RouteNames.menu,
            builder: (context, state) =>
                const Scaffold(body: Text('Menu Home')),
          ),
          GoRoute(
            path: '/order',
            name: RouteNames.orderTracker,
            builder: (context, state) =>
                const Scaffold(body: Text('Order Tracker')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await setupPlatformMocks();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('no currency-bearing Text renders in the heading font (P2-2)', (
    tester,
  ) async {
    final repo = _CapturingCartRepo(
      const CartModel(
        items: [
          CartItemModel(item: _burger, quantity: 2),
          CartItemModel(item: _fries, quantity: 1),
        ],
      ),
    );
    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final moneyTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').contains(r'$'))
        .toList();
    expect(
      moneyTexts,
      isNotEmpty,
      reason: 'checkout must render currency on the populated surface',
    );
    final offenders = moneyTexts
        .where((t) => t.style?.fontFamily == _kHeadingFamily)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'P2-2: money in the heading font paints Playfair\'s raised \$ as '
          'a stray floating glyph; offenders: '
          '${offenders.map((t) => t.data).toList()}',
    );
  });

  testWidgets(
    'the grand total renders through the shared PriceTag with verbatim cents',
    (tester) async {
      final repo = _CapturingCartRepo(
        const CartModel(
          items: [
            CartItemModel(item: _burger, quantity: 2),
            CartItemModel(item: _fries, quantity: 1),
          ],
        ),
      );
      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // subtotal 2500 + delivery 300 + tip 0 → preview total 2800.
      final totalTag = tester.widget<PriceTag>(
        find.widgetWithText(PriceTag, r'$28.00'),
      );
      expect(totalTag.cents, 2800, reason: 'display-only: cents verbatim');
      expect(totalTag.large, isTrue, reason: 'prominent totals variant');
    },
  );
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
