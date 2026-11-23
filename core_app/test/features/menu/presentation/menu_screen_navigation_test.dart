import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/dish_detail_screen.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

/// ROUTER-2 W2.4 / T-1: tapping a menu item navigates to DishDetailScreen.
///
/// Uses a real go_router with the `/dish/:id` route (the production route
/// already exists) so the menu card's `context.pushNamed(RouteNames.dishDetail,
/// pathParameters: {'id': item.id})` resolves end-to-end.
MenuItemModel _menuItem({required String id, required String name}) {
  return MenuItemModel(
    id: id,
    name: name,
    description: 'Description for $name',
    priceCents: 999,
    imageUrl: null,
    category: 'General',
    tags: const [],
    isAvailable: true,
  );
}

void main() {
  testWidgets('tapping a menu card opens DishDetailScreen with the item id', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const MenuScreen(),
        ),
        GoRoute(
          path: '/dish/:id',
          name: 'dishDetail',
          builder: (_, state) =>
              DishDetailScreen(menuItemId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mergedMenuProvider.overrideWith(
            (ref) => Stream.value([_menuItem(id: '1', name: 'Burger')]),
          ),
          restaurantConfigProvider.overrideWith(
            (ref) => Stream<RestaurantConfigModel>.value(
              const RestaurantConfigModel(currency: 'USD'),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Burger'));
    await tester.pumpAndSettle();

    expect(find.byType(DishDetailScreen), findsOneWidget);
    // The tapped item's id landed in the path parameter.
    final detail = tester.widget<DishDetailScreen>(
      find.byType(DishDetailScreen),
    );
    expect(detail.menuItemId, '1');
    // The detail screen renders the actual item data.
    expect(
      find.descendant(
        of: find.byType(DishDetailScreen),
        matching: find.text('Burger'),
      ),
      findsWidgets,
    );
  });
}
