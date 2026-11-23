import 'dart:async';

import 'package:core_ui/src/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stored key for the end-user language choice (UI-15 T-1): a language CODE
/// such as `ar`. ABSENT means "follow the device" (L-P2).
const String kAppLocalePreferenceKey = 'settings_locale';

/// The language codes this build ships — the settings-side mirror of
/// `AppLocalizations.supportedLocales`. `core_app`'s
/// `locale_validity_parity_test.dart` pins the two sets EQUAL (fail-closed),
/// so a stored language can only ever be applied when the app ships it.
const Set<String> kSupportedSettingsLanguageCodes = <String>{'en', 'ar'};

/// Maps a stored language code to a [Locale]; `null` (follow the device) for
/// an absent, empty or no-longer-shipped value (L-P2 fail-safe).
Locale? localeForStoredLanguageCode(String? storedCode) {
  if (storedCode == null || storedCode.isEmpty) return null;
  return kSupportedSettingsLanguageCodes.contains(storedCode)
      ? Locale(storedCode)
      : null;
}

/// UI-15 (p24) T-1 — the end-user LANGUAGE choice, closing `F3-01` (locale
/// switching was code-supported with zero UI controls).
///
/// `null` = follow the device locale: exactly the pre-p24 behaviour and the
/// first frame of every launch (L-P2/L-P5 — the stored value hydrates
/// asynchronously and applies at most one frame later; nothing blocks boot).
class AppLocaleController extends Notifier<Locale?> {
  bool _userSelected = false;
  bool _disposed = false;

  @override
  Locale? build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_hydrate());
    return null;
  }

  Future<void> _hydrate() async {
    // One microtask hop: the first frame must paint the L-P2 default before
    // the stored value applies (L-P5), and `state` must never be written while
    // the tree that watches this provider is still building. No timer — a
    // pending `Future.delayed` would break widget-test teardown invariants.
    await Future<void>.value();
    final stored = await SettingsStore.readString(kAppLocalePreferenceKey);
    if (_disposed || _userSelected) return;
    final resolved = localeForStoredLanguageCode(stored);
    if (resolved != state) state = resolved;
  }

  /// Applies the choice to the running app and persists it; `null` = follow
  /// the device again (the key is REMOVED, never stored as a sentinel).
  Future<void> setLocale(Locale? locale) async {
    _userSelected = true;
    state = locale;
    await SettingsStore.writeString(
      kAppLocalePreferenceKey,
      locale?.languageCode,
    );
  }
}

/// Watched by the ONE `MaterialApp.router` (`app_bootstrap.dart`) as its
/// `locale:` argument — the consumer this state exists for.
final appLocaleProvider = NotifierProvider<AppLocaleController, Locale?>(
  AppLocaleController.new,
);
