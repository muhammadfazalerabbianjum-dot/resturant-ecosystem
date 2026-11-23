import 'package:core_ui/src/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-15 (p24) — the shared preference seam (L-P2: a broken store must degrade
/// to "nothing stored", never throw into the widget tree or the boot path).
///
/// The throwing case runs FIRST and on purpose: it needs the plugin's default
/// method-channel store, which `setMockInitialValues` replaces for the rest of
/// this file's isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a store that throws reads as "nothing stored" and writes silently',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async => throw PlatformException(code: 'store-unavailable'),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/shared_preferences'),
              null,
            ),
      );

      expect(await SettingsStore.readString('settings_locale'), isNull);
      await SettingsStore.writeString('settings_locale', 'ar');
    },
  );

  test('round-trips a value and removes it when null', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await SettingsStore.writeString('settings_locale', 'ar');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_locale'), 'ar');
    expect(await SettingsStore.readString('settings_locale'), 'ar');

    await SettingsStore.writeString('settings_locale', null);
    expect(prefs.containsKey('settings_locale'), isFalse);
    expect(await SettingsStore.readString('settings_locale'), isNull);
  });

  test('a value stored under the wrong type reads as absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings_locale': 42,
    });
    expect(await SettingsStore.readString('settings_locale'), isNull);
  });
}
