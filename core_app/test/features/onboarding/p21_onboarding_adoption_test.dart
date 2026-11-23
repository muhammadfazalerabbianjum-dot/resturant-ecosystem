// UI-13 (p21 C2) — OnboardingShell adoption + the Amendment A1 page-label
// ruling (W-5).
//
// RED before the wiring: the hand-rolled Column is not an OnboardingShell and
// renders no page announcement at all. Amendment A1's temporary
// `trackerStepOfTotal` reuse was superseded by UI-8 (p18) Amendment A2.2:
// both callers' builders now come from the dedicated localized
// `onboardingPage` / `onboardingPageDot` keys (en + ar parity) — never the
// English `kOnboardingPageAnnouncement` / `kOnboardingPageDotLabel` fallbacks.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/onboarding/presentation/onboarding_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('P21 C2 — OnboardingShell adoption (W-5)', () {
    testWidgets('the first-run screen renders through the frozen shell', (
      tester,
    ) async {
      await _pumpOnboarding(tester, locale: const Locale('en'));

      expect(find.byType(OnboardingShell), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      // Single-page flow: the shell only shows Skip off the last page.
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets(
      'en: page announcement + dot label come from onboardingPage, never '
      'the English fallbacks',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpOnboarding(tester, locale: const Locale('en'));

        // Both wired builders resolve to the dedicated p18 keys:
        // onboardingPage(1, 1) = 'Page 1 of 1', onboardingPageDot(1) = 'Page 1'.
        expect(find.bySemanticsLabel('Page 1 of 1'), findsWidgets);
        expect(find.bySemanticsLabel('Page 1'), findsWidgets);
        // The announcement fallback string is byte-identical to the localized
        // wording by design, so builder-source proof lives in the ar case;
        // the dot fallback still must never render on the hot path.
        expect(find.bySemanticsLabel(kOnboardingPageDotLabel(1)), findsNothing);

        handle.dispose();
      },
    );

    testWidgets('ar: announcement is the Arabic onboardingPage', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpOnboarding(tester, locale: const Locale('ar'));

      // app_ar.arb: 'الصفحة {page} من {total}' -> 'الصفحة 1 من 1'; the
      // localized Arabic label differing from the English fallback string IS
      // the builder-source proof (A2.2).
      expect(find.bySemanticsLabel('الصفحة 1 من 1'), findsWidgets);
      expect(find.bySemanticsLabel('صفحة 1'), findsWidgets);
      expect(
        find.bySemanticsLabel(kOnboardingPageAnnouncement(1, 1)),
        findsNothing,
        reason: 'no English announcement on the Arabic surface',
      );
      expect(
        find.bySemanticsLabel(kOnboardingPageDotLabel(1)),
        findsNothing,
        reason: 'no English dot label on the Arabic surface',
      );
      // The shell's done control exists regardless of locale copy.
      expect(find.byType(BrandButton), findsOneWidget);

      handle.dispose();
    });
  });

  group('C-1 (p18 A2.2) — dedicated onboardingPage keys', () {
    testWidgets('en: the live-region label equals onboardingPage(1, 1)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpOnboarding(tester, locale: const Locale('en'));

      expect(find.bySemanticsLabel(loc.onboardingPage(1, 1)), findsWidgets);
      expect(
        find.bySemanticsLabel(loc.trackerStepOfTotal(1, 1)),
        findsNothing,
        reason: 'the trackerStepOfTotal reuse is deleted (A2.2 step 2)',
      );
      handle.dispose();
    });

    testWidgets('ar: the live-region label equals onboardingPage(1, 1)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final loc = await AppLocalizations.delegate.load(const Locale('ar'));
      await _pumpOnboarding(tester, locale: const Locale('ar'));

      expect(find.bySemanticsLabel(loc.onboardingPage(1, 1)), findsWidgets);
      expect(find.bySemanticsLabel(loc.onboardingPageDot(1)), findsWidgets);
      expect(
        find.bySemanticsLabel(loc.trackerStepOfTotal(1, 1)),
        findsNothing,
        reason: 'the trackerStepOfTotal reuse is deleted (A2.2 step 2)',
      );
      handle.dispose();
    });
  });
}
