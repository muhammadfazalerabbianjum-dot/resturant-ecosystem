import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:core_ui/core_ui.dart';

/// P9 W1 (T-5): the dead `appThemeProvider` declaration is deleted (zero
/// production consumers — the running app takes its theme from
/// `AppConfig.theme`/`AppConfig.darkTheme`, PERF-8 W4-4). The LIVE
/// [themeModeProvider] (app_bootstrap.dart watches it for Law 6 dynamic
/// observance) keeps real behavior pins here.
void main() {
  group('ThemeModeNotifier — live theme mode state (P9 W1)', () {
    test('defaults to light', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('toggle switches light → dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle round-trips dark → light', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeModeProvider.notifier).toggle();
      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('p24 T-2 — appearance persistence + setMode (F3-02)', () {
    test(
      'first frame is light, then a stored mode applies (L-P2/L-P5)',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kThemeModePreferenceKey: 'dark',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(themeModeProvider),
          ThemeMode.light,
          reason: 'L-P2: the first frame is the pre-p24 default',
        );
        await pumpEventQueue();
        expect(container.read(themeModeProvider), ThemeMode.dark);
      },
    );

    test(
      'setMode applies live and survives a fresh container (restart)',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(themeModeProvider.notifier)
            .setMode(ThemeMode.dark);

        expect(container.read(themeModeProvider), ThemeMode.dark);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kThemeModePreferenceKey), 'dark');

        final fresh = ProviderContainer();
        addTearDown(fresh.dispose);
        fresh.read(themeModeProvider);
        await pumpEventQueue();
        expect(fresh.read(themeModeProvider), ThemeMode.dark);
      },
    );

    test('a stored system mode is honoured', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kThemeModePreferenceKey: 'system',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider);
      await pumpEventQueue();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('an unknown stored value keeps light (L-P2)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kThemeModePreferenceKey: 'sepia',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider);
      await pumpEventQueue();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test(
      'toggle delegates to setMode (one transition + one write path)',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(themeModeProvider.notifier).toggle();
        expect(container.read(themeModeProvider), ThemeMode.dark);
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kThemeModePreferenceKey), 'dark');
      },
    );

    test('themeModeForStoredValue maps only known values', () {
      expect(themeModeForStoredValue(null), ThemeMode.light);
      expect(themeModeForStoredValue(''), ThemeMode.light);
      expect(themeModeForStoredValue('sepia'), ThemeMode.light);
      expect(themeModeForStoredValue('light'), ThemeMode.light);
      expect(themeModeForStoredValue('dark'), ThemeMode.dark);
      expect(themeModeForStoredValue('system'), ThemeMode.system);
    });
  });
}
