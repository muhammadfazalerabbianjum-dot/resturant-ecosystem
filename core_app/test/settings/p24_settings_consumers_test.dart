import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mock_firebase.dart';

/// UI-15 (p24) T-1 — **L-P1 CONSUMER proof**.
///
/// L-P1: "a preference the user cannot reach is a defect; a preference that
/// lies is worse". The mirror image of `F3-01` is a stored key nothing READS,
/// so every test here mounts the REAL `CoreApp` (the one widget both clients
/// render — `core_app` and, through its thin wrapper, `apps/halal_boyz`),
/// seeds ONLY the stored preference through the real `shared_preferences`
/// mock store, and reads the production consumer back out of the live widget
/// tree: `MaterialApp.locale` → `Localizations.localeOf` → `Directionality`
/// (the `locale:` argument of the single `MaterialApp.router` in
/// `core_app/lib/app_bootstrap.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mounts the production app with [prefs] as the device's stored state and
  /// lets the (non-blocking, L-P5) hydration settle: the first painted frame
  /// is the L-P2 default, the stored value applies on a later frame.
  Future<void> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
    setupFirebaseAuthMocks();
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(const ProviderScope(child: CoreApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The splash surface schedules a 1s floor timer and a 10s auth timeout;
  /// rolling the fake clock past them keeps the framework's "no timers
  /// pending at teardown" invariant satisfied even when an assertion above
  /// failed (so a red test reports ITS reason, not a teardown artifact).
  Future<void> check(WidgetTester tester, void Function() body) async {
    try {
      body();
    } finally {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 11));
    }
  }

  /// The live production `MaterialApp.router` — the consumer under test.
  MaterialApp runningApp(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp).first);

  group('p24 T-1 — the stored language reaches MaterialApp.locale (F3-01)', () {
    test('the test drives the production wire key', () {
      expect(kAppLocalePreferenceKey, 'settings_locale');
    });

    testWidgets('a stored ar choice flips the RUNNING app to ar + RTL', (
      tester,
    ) async {
      await pumpApp(tester, <String, Object>{kAppLocalePreferenceKey: 'ar'});
      await check(tester, () {
        expect(
          runningApp(tester).locale,
          const Locale('ar'),
          reason: 'the stored language must reach the app-level `locale:` arg',
        );
        final context = tester.element(find.byType(Scaffold).first);
        expect(Localizations.localeOf(context).languageCode, 'ar');
        expect(
          AppLocalizations.of(context).profile,
          'الملف الشخصي',
          reason: 'the ar resources are live in the running app',
        );
        // The app's OWN direction derivation from the ar locale. NOTE: the
        // DEBUG-only bug-reporter overlay
        // (`core_ui/src/error_logger/bug_reporter_overlay.dart:28`) wraps all
        // app content in an explicit `TextDirection.ltr` in debug/profile
        // builds, so the VISIBLE tree is LTR in this host; that wrapper is
        // dropped in release (`B6-2`). Recorded as finding F-p24-1 in the
        // report, with `receipts/diag_dir.txt` as evidence, and outside p24's
        // territory. The visible-tree tap→RTL flip is asserted in
        // `p24_settings_rows_test.dart`, whose harness mirrors the production
        // `locale:` line without that dev-only wrapper.
        expect(
          Directionality.of(tester.element(find.byType(BugReporterOverlay))),
          TextDirection.rtl,
        );
      });
    });

    testWidgets('with nothing stored the app follows the device (L-P2)', (
      tester,
    ) async {
      await pumpApp(tester, <String, Object>{});
      await check(tester, () {
        expect(
          runningApp(tester).locale,
          isNull,
          reason: 'no stored choice => no `locale:` override (today exactly)',
        );
      });
    });

    testWidgets('an unsupported stored language falls back to the device', (
      tester,
    ) async {
      await pumpApp(tester, <String, Object>{kAppLocalePreferenceKey: 'fr'});
      await check(tester, () {
        expect(
          runningApp(tester).locale,
          isNull,
          reason: 'a language outside supportedLocales must never be applied',
        );
      });
    });
  });

  group('p24 T-2 — the stored appearance reaches MaterialApp.themeMode', () {
    test('the test drives the production wire key', () {
      expect(kThemeModePreferenceKey, 'settings_theme_mode');
    });

    testWidgets('a stored dark choice reaches the RUNNING app', (tester) async {
      await pumpApp(tester, <String, Object>{kThemeModePreferenceKey: 'dark'});
      await check(tester, () {
        expect(
          runningApp(tester).themeMode,
          ThemeMode.dark,
          reason:
              'F3-02: ThemeMode.dark must be reachable in a release build — '
              'the stored choice is the only thing that differs here',
        );
      });
    });

    testWidgets('with nothing stored the mode is light (L-P2)', (tester) async {
      await pumpApp(tester, <String, Object>{});
      await check(tester, () {
        expect(runningApp(tester).themeMode, ThemeMode.light);
      });
    });
  });
}
