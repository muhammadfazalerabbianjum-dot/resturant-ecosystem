import 'dart:async';

import 'package:core_ui/src/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stored key for the end-user appearance choice (UI-15 T-2). Values are
/// [ThemeMode.name] (`light` | `dark` | `system`); ABSENT keeps the L-P2
/// default ([ThemeMode.light]).
const String kThemeModePreferenceKey = 'settings_theme_mode';

/// Maps a stored appearance value to a [ThemeMode]. Anything absent, unknown
/// or mistyped keeps the L-P2 default — a corrupt store can never leave the
/// app in a mode the user cannot explain.
ThemeMode themeModeForStoredValue(String? stored) => switch (stored) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => ThemeMode.light,
};

/// UI-15 (p24) T-2 — the end-user APPEARANCE state, closing `F3-02`
/// (`ThemeMode.dark` was unreachable: `toggle()` had zero production callers).
///
/// [build] keeps returning [ThemeMode.light] (L-P2: with nothing stored the
/// app behaves exactly as before p24) and the stored value hydrates off the
/// boot path, applying at most one frame after the first paint (L-P5).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _userSelected = false;
  bool _disposed = false;

  @override
  ThemeMode build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_hydrate());
    return ThemeMode.light;
  }

  Future<void> _hydrate() async {
    // One microtask hop: the first frame must paint the L-P2 default, and
    // `state` must never be written while the tree that watches this provider
    // is still building. No timer — a pending `Future.delayed` would break
    // widget-test teardown invariants.
    await Future<void>.value();
    final stored = await SettingsStore.readString(kThemeModePreferenceKey);
    if (_disposed || _userSelected) return;
    final mode = themeModeForStoredValue(stored);
    if (mode != state) state = mode;
  }

  /// The SINGLE state transition: the appearance rows call this and the live
  /// `MaterialApp.themeMode` (`app_bootstrap.dart`) observes it.
  Future<void> setMode(ThemeMode mode) async {
    _userSelected = true;
    state = mode;
    await SettingsStore.writeString(kThemeModePreferenceKey, mode.name);
  }

  /// Re-pointed at [setMode] so the long-standing two-way toggle keeps working
  /// (`core_app/test/widget/dark_mode_test.dart` pins it) without a second
  /// transition or persistence path.
  void toggle() => unawaited(
    setMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
  );
}

/// Watched by the ONE `MaterialApp.router` (`app_bootstrap.dart`) as its
/// `themeMode:` argument (Law 6 dynamic observance).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
