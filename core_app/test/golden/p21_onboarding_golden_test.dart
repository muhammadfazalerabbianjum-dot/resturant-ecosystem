// UI-13 (p21) phase C golden pair — first-run onboarding, en + ar (§3-C L12.6).
//
// Deliberate-first protocol: BEFORE baselines are captured with
// `--update-goldens` while the PRE-WIRING (hand-rolled Column) screen is in
// place and archived to tool_uilib/p21/visual_review/
// p21_onboarding_{en,ar}_before.png with SHA-256 recorded in p21_report.md;
// after the OnboardingShell adoption the plain run must FAIL against those
// baselines before the declared re-capture writes the committed AFTER pair.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/onboarding/presentation/onboarding_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

Future<void> _capture(
  WidgetTester tester, {
  required String locale,
  required String golden,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(find.byType(OnboardingScreen), matchesGoldenFile(golden));
}

void main() {
  testWidgets('P21 first-run onboarding golden — en', (tester) async {
    await _capture(
      tester,
      locale: 'en',
      golden: 'snapshots/p21_onboarding_en.png',
    );
  });

  testWidgets('P21 first-run onboarding golden — ar (RTL parity)', (
    tester,
  ) async {
    await _capture(
      tester,
      locale: 'ar',
      golden: 'snapshots/p21_onboarding_ar.png',
    );
  });
}
