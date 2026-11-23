import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UI-15 (p24) — the settings ROWS in the profile settings block.
///
/// The harness mirrors the ONE production line that consumes the language
/// state (`locale: ref.watch(appLocaleProvider)` on the app's single
/// `MaterialApp.router`), so a tap here is observed exactly the way the running
/// app observes it: the tree flips to RTL and every label switches to Arabic.
/// The production wiring itself is pinned against the REAL `CoreApp` in
/// `p24_settings_consumers_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languageArabicRow = ValueKey<String>('settings-language-ar');
  const languageEnglishRow = ValueKey<String>('settings-language-en');
  const languageSystemRow = ValueKey<String>('settings-language-system');
  const themeLightRow = ValueKey<String>('settings-theme-light');
  const themeDarkRow = ValueKey<String>('settings-theme-dark');
  const themeSystemRow = ValueKey<String>('settings-theme-system');
  const notificationRow = ValueKey<String>('settings-notification-echo');

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          locale: ref.watch(appLocaleProvider),
          themeMode: ref.watch(themeModeProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> tapRow(WidgetTester tester, ValueKey<String> key) async {
    final row = find.byKey(key);
    expect(row, findsOneWidget, reason: 'the row must be reachable');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  TextDirection directionOf(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(Scaffold).first));

  MaterialApp runningApp(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp).first);

  group('p24 T-1 — the language rows write a choice something reads', () {
    testWidgets('tapping العربية flips the tree to Arabic + RTL and persists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(directionOf(tester), TextDirection.ltr);

      await tapRow(tester, languageArabicRow);

      expect(directionOf(tester), TextDirection.rtl);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(context).languageCode, 'ar');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAppLocalePreferenceKey), 'ar');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping English returns the tree to LTR', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'ar',
      });
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(directionOf(tester), TextDirection.rtl);

      await tapRow(tester, languageEnglishRow);

      expect(directionOf(tester), TextDirection.ltr);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAppLocalePreferenceKey), 'en');
    });

    testWidgets('the follow-device row clears the stored choice (L-P2)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'ar',
      });
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tapRow(tester, languageSystemRow);

      expect(directionOf(tester), TextDirection.ltr);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kAppLocalePreferenceKey), isFalse);
    });

    testWidgets('the active language carries the selected marker', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'ar',
      });
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      Finder markIn(ValueKey<String> key) => find.descendant(
        of: find.byKey(key),
        matching: find.byIcon(Icons.check),
      );

      expect(markIn(languageArabicRow), findsOneWidget);
      expect(markIn(languageEnglishRow), findsNothing);
      expect(markIn(languageSystemRow), findsNothing);
    });

    testWidgets('under ar every settings row renders its Arabic label', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'ar',
      });
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final loc = AppLocalizations.of(
        tester.element(find.byType(ProfileScreen)),
      );
      expect(find.byType(SettingTile), findsAtLeastNWidgets(6));
      expect(
        find.text(loc.settingsTitle),
        findsOneWidget,
        reason: 'the settings block header is localised, not literal',
      );
      expect(find.text(loc.settingsLanguage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'p24 T-2 — the appearance rows drive the live MaterialApp.themeMode',
    () {
      testWidgets('tapping Dark switches the app and persists the choice', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();
        expect(runningApp(tester).themeMode, ThemeMode.light);

        await tapRow(tester, themeDarkRow);

        expect(runningApp(tester).themeMode, ThemeMode.dark);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kThemeModePreferenceKey), 'dark');
      });

      testWidgets('tapping System follows the device brightness', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kThemeModePreferenceKey: 'dark',
        });
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();
        expect(runningApp(tester).themeMode, ThemeMode.dark);

        await tapRow(tester, themeSystemRow);

        expect(runningApp(tester).themeMode, ThemeMode.system);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kThemeModePreferenceKey), 'system');
      });

      testWidgets('tapping Light returns to the pre-p24 default', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kThemeModePreferenceKey: 'system',
        });
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();

        await tapRow(tester, themeLightRow);

        expect(runningApp(tester).themeMode, ThemeMode.light);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kThemeModePreferenceKey), 'light');
      });
    },
  );

  group('p24 T-3 — the notification row writes the value the gate reads', () {
    testWidgets('toggling the row OFF reaches the ONE service consumer', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tapRow(tester, notificationRow);

      expect(
        await PushNotificationService.foregroundEchoEnabled(),
        isFalse,
        reason:
            'the write must land on the stored value the foreground-echo gate '
            'reads (packages/core push_notification_service.dart)',
      );
    });

    testWidgets('the switch renders the stored OFF state', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PushNotificationService.foregroundEchoPreferenceKey: false,
      });
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });
}
