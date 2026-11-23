import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:labs/features/orders/data/order_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

OrderModel _makeOrder(String id) => OrderModel(
  id: id,
  customerId: 'user-1',
  status: OrderStatus.preparing,
  totalCents: 2500,
  createdAt: DateTime(2026, 7, 24, 18, 0),
);

Widget _buildScreen(String orderId, OrderRepository repo) {
  return ProviderScope(
    overrides: [orderRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OrderTrackerScreen(orderId: orderId),
    ),
  );
}

void main() {
  group('OrderTrackerScreen Widget Tests', () {
    testWidgets('1. Renders order tracker screen with title', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_001'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_001')));

      await tester.pumpWidget(_buildScreen('order_001', repo));
      await tester.pump();
      await tester.pump();

      // "Delivery Status" appears in AppBar and body
      expect(find.text('Delivery Status'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Shows order ID in app bar', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_xyz'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_xyz')));

      await tester.pumpWidget(_buildScreen('order_xyz', repo));
      await tester.pump();
      await tester.pump();

      // AppBar title should contain order ID
      expect(find.textContaining('order_xyz'), findsOneWidget);
    });

    testWidgets('3. Shows Preparing status text', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_456'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_456')));

      await tester.pumpWidget(_buildScreen('order_456', repo));
      await tester.pump();
      await tester.pump();

      // UI-13 (p21 B): the steps widget renders the composed UX-2 label
      // through the frozen OrderTimeline ("Step 3 of 8: Preparing"); the bare
      // status name as a standalone Text node is gone with the ListTile rows.
      expect(find.text('Step 3 of 8: Preparing'), findsOneWidget);
    });

    testWidgets('4. AppBar and body widgets are present', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_789'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_789')));

      await tester.pumpWidget(_buildScreen('order_789', repo));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('5. Screen layout uses centered column layout', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_layout'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_layout')));

      await tester.pumpWidget(_buildScreen('order_layout', repo));
      await tester.pump();
      await tester.pump();

      // Should have a Column and Center widget
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('6. Different order IDs render without error', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('order_999'),
      ).thenAnswer((_) => Stream.value(_makeOrder('order_999')));

      await tester.pumpWidget(_buildScreen('order_999', repo));
      await tester.pump();
      await tester.pump();

      // UI-13 (p21 B): composed UX-2 step label via the frozen OrderTimeline
      // (same deliberate change as test 3 above).
      expect(find.text('Step 3 of 8: Preparing'), findsOneWidget);
      expect(find.textContaining('order_999'), findsOneWidget);
    });
  });
}
