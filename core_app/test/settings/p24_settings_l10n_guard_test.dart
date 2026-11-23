import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UI-15 (p24) T-4 — the ARB pair + generated l10n for every string T-1..T-3
/// adds (L-P7: one source of truth for user-visible text).
///
/// Fail-closed in both directions:
///  * each p24 key must exist in BOTH ARBs with real Arabic (`ar` values that
///    carry no Arabic codepoint are an English copy wearing an Arabic label);
///  * each key must have a GENERATED getter in both localizations classes, so
///    the ARB edit can never be committed without a `flutter gen-l10n` run;
///  * the new rows must source their visible text from `loc.` (a literal
///    string in the profile screen is the drift this guard exists to catch).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every message the p24 settings surface adds (contract §3 T-1..T-3).
  const p24Keys = <String>[
    'settingsTitle',
    'settingsLanguage',
    'settingsAppearance',
    'settingsLanguageEnglish',
    'settingsLanguageArabic',
    'settingsFollowSystem',
    'settingsThemeLight',
    'settingsThemeDark',
    'settingsThemeSystem',
    'settingsNotifications',
    'settingsNotificationsSubtitle',
    'settingsSelected',
  ];

  Map<String, dynamic> arb(String file) =>
      jsonDecode(File('lib/l10n/$file').readAsStringSync())
          as Map<String, dynamic>;

  final arabic = RegExp(r'[\u0600-\u06FF]');

  test('every p24 key is present in app_en.arb and app_ar.arb', () {
    final en = arb('app_en.arb');
    final ar = arb('app_ar.arb');
    final missing = <String>[];
    for (final key in p24Keys) {
      if (en[key] is! String || (en[key] as String).trim().isEmpty) {
        missing.add('en:$key');
      }
      if (ar[key] is! String || (ar[key] as String).trim().isEmpty) {
        missing.add('ar:$key');
      }
    }
    expect(missing, isEmpty, reason: 'missing ARB messages: $missing');
  });

  test('every p24 ar value is real Arabic, not an English copy', () {
    final ar = arb('app_ar.arb');
    final copies = <String>[];
    for (final key in p24Keys) {
      final value = ar[key];
      if (value is String && !arabic.hasMatch(value)) {
        copies.add('$key="$value"');
      }
    }
    expect(copies, isEmpty, reason: 'ar values without Arabic script: $copies');
  });

  test('every p24 key has a GENERATED getter in both locales', () {
    final generated = <String, String>{
      'en': File('lib/l10n/app_localizations_en.dart').readAsStringSync(),
      'ar': File('lib/l10n/app_localizations_ar.dart').readAsStringSync(),
    };
    final missing = <String>[];
    generated.forEach((locale, source) {
      for (final key in p24Keys) {
        if (!source.contains('get $key')) missing.add('$locale:$key');
      }
    });
    expect(
      missing,
      isEmpty,
      reason:
          'flutter gen-l10n was not re-run after the ARB edit '
          '(missing getters: $missing)',
    );
  });

  test('the new rows read their text from loc (no literal labels)', () {
    final screen = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();
    const fromLoc = <String>[
      'loc.settingsTitle',
      'loc.settingsLanguage',
      'loc.settingsAppearance',
      'loc.settingsLanguageEnglish',
      'loc.settingsLanguageArabic',
      'loc.settingsFollowSystem',
      'loc.settingsThemeLight',
      'loc.settingsThemeDark',
      'loc.settingsThemeSystem',
      'loc.settingsNotifications',
      'loc.settingsNotificationsSubtitle',
      'loc.settingsSelected',
    ];
    final missing = fromLoc
        .where((reference) => !screen.contains(reference))
        .toList();
    expect(
      missing,
      isEmpty,
      reason: 'literals instead of ARB lookups: $missing',
    );
  });
}
