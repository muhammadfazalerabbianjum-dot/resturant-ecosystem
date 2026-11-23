/// UI-10 (p20) Phase B — before/after golden pair for the ORDER TRACKER.
///
/// The baseline in `goldens/p20_order_tracker.png` is re-captured deliberately
/// once per phase (red = pre-wiring look, green = adoption look); both captures
/// are copied into `tool_uilib/p20/visual_review/` for the owner's appeal
/// verdict (L12.6). The order is a fixed `preparing` order with a fixed
/// currency so the pair is deterministic.
///
/// L16 SANCTUARY: this harness only renders the screen — the tracker's state
/// machine, timers and listeners are untouched, and the frozen steps-widget
/// golden lives in `test/golden/order_tracker_golden_test.dart`.
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/orders/data/order_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  testWidgets('P20 order tracker golden — adoption pair', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MockOrderRepository();
    when(() => repo.streamOrder('ORD-2001')).thenAnswer(
      (_) => Stream.value(
        OrderModel(
          id: 'ORD-2001',
          customerId: 'user-1',
          status: OrderStatus.preparing,
          totalCents: 4590,
          createdAt: DateTime(2026, 9, 27),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repo),
          restaurantConfigProvider.overrideWith(
            (ref) => Stream<RestaurantConfigModel>.value(
              const RestaurantConfigModel(currency: 'USD'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OrderTrackerScreen(orderId: 'ORD-2001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p20_order_tracker.png'),
    );
  });
}
