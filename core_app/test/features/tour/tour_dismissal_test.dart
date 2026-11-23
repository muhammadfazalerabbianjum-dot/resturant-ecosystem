import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/tour/domain/tour_manager.dart';
import 'package:labs/features/tour/presentation/tour_overlay.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hosts the tour on a real pushed route so dismissal (Skip / Finish) is
/// observed through the production route-pop path instead of a stub.
class _TourLauncher extends ConsumerWidget {
  const _TourLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const Text('HOME_SCREEN'),
            ElevatedButton(
              onPressed: () {
                unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TourOverlay()),
                  ),
                );
              },
              child: const Text('Open tour'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createSubject() {
    return const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _TourLauncher(),
      ),
    );
  }

  Future<void> openTour(WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('Open tour'));
    await tester.pumpAndSettle();
    expect(find.byType(TourOverlay), findsOneWidget);
  }

  group('TourOverlay dismissal + re-show rules (COV-2)', () {
    testWidgets('Skip pops the overlay and persists NOTHING to shared prefs', (
      tester,
    ) async {
      await openTour(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(TourOverlay), findsNothing);
      expect(find.text('HOME_SCREEN'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('tour_completed'),
        isNull,
        reason:
            'dismissal must not write a hidden tour flag (owner-deferred wiring)',
      );
      expect(prefs.getBool('onboarding_completed'), isNull);
    });

    testWidgets(
      'Finish on the last step pops the overlay back to the launcher',
      (tester) async {
        await openTour(tester);

        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(find.text('Finish'), findsOneWidget);

        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();

        expect(find.byType(TourOverlay), findsNothing);
        expect(find.text('HOME_SCREEN'), findsOneWidget);
      },
    );

    testWidgets('Previous returns to the earlier step (round-trip 2 -> 1)', (
      tester,
    ) async {
      await openTour(tester);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Tour Step 2 of 3'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pump();

      expect(find.text('Tour Step 1 of 3'), findsOneWidget);
      expect(
        find.text('Browse the menu and explore our delicious offerings.'),
        findsOneWidget,
      );
    });

    test(
      'TourManager re-show rules: first run shows, returning users stay suppressed',
      () {
        final manager = TourManager(isFirstRun: true);
        expect(manager.shouldShowTour, isTrue);
        expect(
          manager.tourStepKeys,
          hasLength(3),
          reason:
              'the overlay counter renders Tour Step N of 3 off this shared set',
        );
        expect(manager.tourStepKeys, ['tourStep1', 'tourStep2', 'tourStep3']);
        expect(TourManager(isFirstRun: false).shouldShowTour, isFalse);
      },
    );
  });
}
