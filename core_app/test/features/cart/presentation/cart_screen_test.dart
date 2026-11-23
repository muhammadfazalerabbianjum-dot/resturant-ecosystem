import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  group('CartScreen Widget Tests', () {
    testWidgets('1. Shows cart title in app bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CartScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Your Cart'), findsOneWidget);
    });

    testWidgets('2. Shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CartScreen(),
          ),
        ),
      );

      // Initially loading state. UI-13 (p21 H2, F3-09): the loading
      // affordance is now the library placeholder (MenuTile footprints)
      // instead of a raw spinner — same assertion strength (a loading state
      // IS on screen), re-anchored to the adopted component.
      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('3. Renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CartScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
