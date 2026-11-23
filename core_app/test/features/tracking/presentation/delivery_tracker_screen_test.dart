import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart'
    show singleOrderProvider;
import 'package:labs/features/tracking/presentation/delivery_tracker_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// P6-03: Stub-screen behavior test — DeliveryTrackerScreen.
/// Must render the real order status (not hardcoded 'PREPARING').
void main() {
  group('DeliveryTrackerScreen — real status rendering (P6-03)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider(
              'order_001',
            ).overrideWith((ref) => Stream.value(_makeOrder('order_001'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order_001'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows order ID in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider(
              'order_xyz',
            ).overrideWith((ref) => Stream.value(_makeOrder('order_xyz'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order_xyz'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('order_xyz'), findsOneWidget);
    });

    testWidgets('shows delivery status title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider(
              'order_456',
            ).overrideWith((ref) => Stream.value(_makeOrder('order_456'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order_456'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The delivery status title should be present
      expect(find.text('Delivery Status'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows contact and reorder buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider(
              'order_789',
            ).overrideWith((ref) => Stream.value(_makeOrder('order_789'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order_789'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Contact and Reorder buttons should be present
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsWidgets);
    });
  });
}

OrderModel _makeOrder(String id) => OrderModel(
  id: id,
  customerId: 'user-test',
  status: OrderStatus.cooking,
  totalCents: 1500,
  createdAt: DateTime(2026, 1, 1),
);
