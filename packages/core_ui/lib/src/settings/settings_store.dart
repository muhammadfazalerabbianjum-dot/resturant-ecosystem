import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// UI-15 (p24) — the settings surface's ONLY persistence seam.
///
/// L-P4: `shared_preferences` is already declared in this package, so the
/// preference I/O lives here and is reused by every p24 preference — never
/// re-implemented per screen (the repo's `SharedPreferences.getInstance()`
/// precedent, wrapped in the failure handling L-P2 demands).
///
/// Fail-safe by construction: a missing key, a value stored under the wrong
/// type, or a store that throws (plugin unavailable, corrupt store) all
/// resolve to `null` = "nothing stored", and the caller keeps its L-P2
/// default. Nothing here may throw into the widget tree or the boot sequence.
class SettingsStore {
  /// Reads [key] as a `String`; `null` when absent, mistyped or unreadable.
  static Future<String?> readString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (error) {
      developer.log('SettingsStore read failed ($key): $error');
      return null;
    }
  }

  /// Persists [value] under [key]; a `null` value REMOVES the key, so the
  /// stored state is "follow the default" rather than a stale explicit choice.
  static Future<void> writeString(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (error) {
      developer.log('SettingsStore write failed ($key): $error');
    }
  }
}
