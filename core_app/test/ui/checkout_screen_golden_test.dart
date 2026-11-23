// UI-13 (p21) — phase A golden pair (checkout + tip), L12.6 deliberate-first
// protocol (the p16/p20 house standard):
//
// 1. BEFORE baselines are captured with `--update-goldens` on the
//    PRE-WIRING screen (tracked edits stashed; this test file is untracked
//    so it stays) and archived into
//    `tool_uilib/p21/visual_review/p21_checkout_{light,dark}_before.png`
//    with their SHA-256 recorded in p21_report.md.
// 2. With the wiring restored, the plain run must FAIL against those
//    before-baselines (hash-proven genuine pairs — no forced greens).
// 3. The declared re-capture then writes the AFTER pair committed alongside
//    this test (`goldens/p21_checkout_*.png`).
//
// `pumpAndSettle` drains the entrance motion so the goldens never freeze an
// entrance frame (p16 phase-C mechanical timing rule).
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/src/theme/app_theme.dart';
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

import '../helpers/app_localizations_test_helper.dart';
import '../helpers/platform_mocks.dart';
import '../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

/// Cart repository that returns a seeded cart without touching disk (p16
/// golden pattern) — the golden exercises the POPULATED surface (sections,
/// tip selector, totals tray), not the empty/loading branches.
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

Widget _buildApp({required CartRepository repo, required ThemeMode mode}) {
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
      currentUserIdProvider.overrideWithValue('golden-uid'),
      locationsProvider.overrideWith((ref) async => const []),
      loggerProvider.overrideWithValue(FakeLogger()),
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      syncQueueProvider.overrideWithValue(RecordingSyncQueue()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
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

Future<void> _drain(WidgetTester tester) async {
  // pumpAndSettle only — the house pattern (p16/p20 golden suites); the
  // platform mocks keep the pending-sync logger off the unmocked
  // path_provider channel (see p16_cart_golden_test.dart).
  await tester.pumpAndSettle();
}

void main() {
  // L12.6 goldens run inside binding.runAsync (real async); platform_mocks
  // is the documented setup for path_provider + shared_preferences.
  setUpAll(() async {
    await setupPlatformMocks();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets(
    'P21 checkout golden — populated + tip selector (default light)',
    (tester) async {
      final repo = _CapturingCartRepo(
        const CartModel(
          items: [
            CartItemModel(item: _burger, quantity: 2),
            CartItemModel(item: _fries, quantity: 1),
          ],
        ),
      );
      await tester.pumpWidget(_buildApp(repo: repo, mode: ThemeMode.light));
      await _drain(tester);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(CheckoutScreen),
        matchesGoldenFile('goldens/p21_checkout_light.png'),
      );
    },
  );

  testWidgets('P21 checkout golden — populated + tip selector (dark)', (
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
    await tester.pumpWidget(_buildApp(repo: repo, mode: ThemeMode.dark));
    await _drain(tester);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(CheckoutScreen),
      matchesGoldenFile('goldens/p21_checkout_dark.png'),
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
