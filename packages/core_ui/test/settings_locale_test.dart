import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-15 (p24) T-1 — the LANGUAGE preference state (L-P1/L-P2/L-P5).
///
/// The value here is the input to the ONE production consumer (`locale:` on
/// the app's single `MaterialApp.router`), which
/// `core_app/test/settings/p24_settings_consumers_test.dart` asserts against
/// the real running app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A container whose (non-blocking) hydration has already landed.
  Future<ProviderContainer> hydrated() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appLocaleProvider);
    await pumpEventQueue();
    return container;
  }

  test(
    'first frame follows the device, then the stored language applies',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'ar',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appLocaleProvider),
        isNull,
        reason: 'L-P5: the first frame is the L-P2 default, never a lie',
      );

      await pumpEventQueue();
      expect(container.read(appLocaleProvider), const Locale('ar'));
    },
  );

  test(
    'an unsupported stored language falls back to the device (L-P2)',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kAppLocalePreferenceKey: 'fr',
      });
      expect((await hydrated()).read(appLocaleProvider), isNull);
    },
  );

  test('an empty stored value falls back to the device (L-P2)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppLocalePreferenceKey: '',
    });
    expect((await hydrated()).read(appLocaleProvider), isNull);
  });

  test(
    'a stored language survives container re-creation (restart proof)',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final first = await hydrated();
      await first
          .read(appLocaleProvider.notifier)
          .setLocale(const Locale('ar'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAppLocalePreferenceKey), 'ar');

      final second = await hydrated();
      expect(
        second.read(appLocaleProvider),
        const Locale('ar'),
        reason: 'the choice is re-read on the next launch (L-P1: it survives)',
      );
    },
  );

  test('setLocale(null) removes the key so the device applies again', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppLocalePreferenceKey: 'ar',
    });
    final container = await hydrated();
    expect(container.read(appLocaleProvider), const Locale('ar'));

    await container.read(appLocaleProvider.notifier).setLocale(null);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(kAppLocalePreferenceKey),
      isFalse,
      reason: 'null means "follow the device", not a stored sentinel',
    );
    expect((await hydrated()).read(appLocaleProvider), isNull);
  });

  test('a slower hydration never clobbers an explicit choice', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppLocalePreferenceKey: 'ar',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appLocaleProvider.notifier)
        .setLocale(const Locale('en'));
    await pumpEventQueue();

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test('localeForStoredLanguageCode maps only shipped languages', () {
    expect(localeForStoredLanguageCode(null), isNull);
    expect(localeForStoredLanguageCode(''), isNull);
    expect(localeForStoredLanguageCode('fr'), isNull);
    expect(localeForStoredLanguageCode('ar'), const Locale('ar'));
    expect(localeForStoredLanguageCode('en'), const Locale('en'));
  });
}
