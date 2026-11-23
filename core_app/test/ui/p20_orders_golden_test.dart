/// UI-10 (p20) Phase A — before/after golden pair for the ORDERS HISTORY
/// screen.
///
/// The baseline in `goldens/p20_order_history.png` is re-captured deliberately
/// once per phase (red = pre-wiring look, green = adoption look); both
/// captures are copied into `tool_uilib/p20/visual_review/` for the owner's
/// appeal verdict (L12.6). The seed spans all three status groups and a fixed
/// currency so the pair is deterministic.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  testWidgets('P20 order history golden — adoption pair', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final created = DateTime(2026, 9, 27);
    final orders = <OrderModel>[
      OrderModel(
        id: 'ORD-1001',
        status: OrderStatus.preparing,
        totalCents: 4590,
        createdAt: created,
      ),
      OrderModel(
        id: 'ORD-1002',
        status: OrderStatus.pickedUp,
        totalCents: 1275,
        createdAt: created,
      ),
      OrderModel(
        id: 'ORD-1003',
        status: OrderStatus.delivered,
        totalCents: 8899,
        createdAt: created,
      ),
      OrderModel(
        id: 'ORD-1004',
        status: OrderStatus.cancelled,
        totalCents: 2200,
        createdAt: created,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userOrdersProvider.overrideWith((ref) => Stream.value(orders)),
          restaurantConfigProvider.overrideWith(
            (ref) => Stream<RestaurantConfigModel>.value(
              const RestaurantConfigModel(currency: 'USD'),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/orders',
            routes: [
              GoRoute(
                path: '/orders',
                name: 'orders',
                builder: (_, __) => const OrderHistoryScreen(),
              ),
              // The row tap target exists so the router never throws; the
              // golden itself stays on the history screen.
              GoRoute(
                path: '/tracker/:orderId',
                name: 'orderTracker',
                builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_order_history.png'),
    );
  });
}
