import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/tour/presentation/tour_overlay.dart';
import 'package:labs/l10n/app_localizations.dart';

/// P6-03: Stub-screen behavior test for TourOverlay (P1-10 fix).
/// Asserts the overlay renders real localized tour step text instead of
/// raw 'tourStep1/2/3' key strings or the old waitlist stub string.
void main() {
  group('TourOverlay - real tour step text (P6-03)', () {
    testWidgets('renders first localised step, not raw key', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TourOverlay(),
          ),
        ),
      );

      expect(find.text('tourStep1'), findsNothing);
      expect(
        find.text('Browse the menu and explore our delicious offerings.'),
        findsOneWidget,
      );
      expect(find.text('Table full? Join the virtual line.'), findsNothing);
    });

    testWidgets('shows step counter, Skip, and Next controls', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TourOverlay(),
          ),
        ),
      );

      expect(find.text('Tour Step 1 of 3'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('advances to second localised step on Next', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TourOverlay(),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Tour Step 2 of 3'), findsOneWidget);
      expect(
        find.text('Add items to your cart and customize them to your taste.'),
        findsOneWidget,
      );
      expect(find.text('Previous'), findsOneWidget);
    });

    testWidgets('shows Finish on the last step', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TourOverlay(),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Tour Step 3 of 3'), findsOneWidget);
      expect(
        find.text('Checkout securely and track your order in real time.'),
        findsOneWidget,
      );
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });
  });
}
