// P16 (UI-6) — phase D golden pair (cart).
//
// Deliberate-first protocol (L12.6): BEFORE baselines are captured with
// --update-goldens on the PRE-WIRING screen and archived into
// tool_uilib/p16/visual_review/p16_cart_*_before.png; after wiring the plain
// run must FAIL against those baselines (hash-proven genuine pairs) before the
// declared re-capture. Settle drains mirror the phase-C mechanical timing rule
// so goldens never freeze an entrance frame.
import 'dart:io';

import 'package:core/core.dart';
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

import '../helpers/app_localizations_test_helper.dart';
import '../helpers/platform_mocks.dart';

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

Future<void> _drain(WidgetTester tester) async {
  // pumpAndSettle only — the house pattern (perf7/variant/adopt suites).
  // NOTE: extra FIXED pumps were tried here first (phase-C style) but they
  // advance pendingSyncCountProvider's periodic timer, whose queue-scan .info
  // write lands on a bare LoggerService() -> unmocked path_provider channel ->
  // MissingPluginException. Pre-existing test-environment constraint, not
  // introduced by this wave; pumpAndSettle drains every frame-driven entrance.
  await tester.pumpAndSettle();
}

void main() {
  // L12.6 goldens run inside binding.runAsync (real async), which lets the
  // pending-sync queue's bare LoggerService().info write reach the UNMOCKED
  // path_provider channel -> MissingPluginException. platform_mocks is the
  // documented setup for exactly this (path_provider + shared_preferences).
  setUpAll(setupPlatformMocks);

  testWidgets('P16 cart golden — seeded rows + total (default light)', (
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
    await _drain(tester);

    await expectLater(
      find.byType(CartScreen),
      matchesGoldenFile('goldens/p16_cart_seeded.png'),
    );
  });

  testWidgets('P16 cart golden — empty state (default light)', (tester) async {
    await tester.pumpWidget(
      _buildApp(_CapturingCartRepo(const CartModel(items: []))),
    );
    await _drain(tester);

    await expectLater(
      find.byType(CartScreen),
      matchesGoldenFile('goldens/p16_cart_empty.png'),
    );
  });
}
