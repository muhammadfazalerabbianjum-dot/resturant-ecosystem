import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      userOrdersProvider.overrideWith((ref) => Stream.value(<OrderModel>[])),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OrderHistoryScreen(),
    ),
  );
}

void main() {
  group('OrderHistoryScreen Widget Tests', () {
    testWidgets('1. Shows order history title in app bar', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Order History'), findsOneWidget);
    });

    testWidgets('2. Shows empty state when no orders', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Empty state should be shown
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('Order Now'), findsAtLeastNWidgets(1));
    });

    testWidgets('3. Shows empty state text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('No orders yet.'), findsOneWidget);
    });

    testWidgets('4. Renders without crashing', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('5. Has elevated button for empty state CTA', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
