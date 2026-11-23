import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:core/core.dart';

class MockCartRepository implements CartRepository {
  @override
  Future<CartModel> loadCart() async {
    return const CartModel(items: []);
  }

  @override
  Future<void> saveCart(CartModel cart) async {}
}

void main() {
  group('Empty State UI Enforcement', () {
    testWidgets('OrderHistoryScreen shows EmptyStateWidget when no orders', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userOrdersProvider.overrideWith(
              (ref) => Stream.value(<OrderModel>[]),
            ),
            cartRepositoryProvider.overrideWith((ref) => MockCartRepository()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: OrderHistoryScreen()),
          ),
        ),
      );

      // Settle all microtasks/streams
      await tester.pumpAndSettle();

      // Verify empty state is strictly shown
      expect(
        find.byType(EmptyStateWidget),
        findsOneWidget,
        reason: 'Must show empty state widget',
      );
    });

    testWidgets('CartScreen shows EmptyStateWidget when no items', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartRepositoryProvider.overrideWith((ref) => MockCartRepository()),
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CartScreen()),
          ),
        ),
      );

      // Settle all timers
      await tester.pumpAndSettle();

      // Assert EmptyStateWidget strictly
      expect(
        find.byType(EmptyStateWidget),
        findsOneWidget,
        reason: 'Must show empty state widget',
      );
    });
  });
}
