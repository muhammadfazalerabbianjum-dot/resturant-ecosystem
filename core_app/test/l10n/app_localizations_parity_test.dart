import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// UI-8 (p18) T-2 — the ICU plural-category parser + numeric-key rules from
// the six-form completeness test (single source of truth; importing the
// helpers never runs that suite's main()).
import '../l10n_plural_completeness_test.dart' as plural_rules;

/// B6-4 — ARB parity regression gate.
///
/// Flutter's `gen-l10n` falls back to the template locale whenever a key is
/// absent from a non-template ARB file. That means a missing Arabic translation
/// silently renders English in the localized app — the exact potato2 Part 3.5
/// defect. This test turns that drift into a CI-visible failure: EVERY key in
/// `app_en.arb` MUST exist in `app_ar.arb`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() async {
    en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
  });

  Set<String> nonMetaKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// A message is NUMERIC when it carries an ICU plural or declares at least
  /// one int/num placeholder. Literal-digit copy ("Min 6 characters") is not
  /// an integer operand and is out of scope (see the report's audit table).
  bool isNumericMessage(Map<String, dynamic> arb, String key) {
    final value = arb[key];
    final hasPlural =
        value is String && plural_rules.pluralCategoriesOf(value) != null;
    return hasPlural || plural_rules.declaresNumericPlaceholder(arb, key);
  }

  test('every numeric en message has an ar counterpart with the SAME '
      'plural categories (fail-closed on future additions)', () {
    final problems = <String>[];
    final numericEnKeys = nonMetaKeys(
      en,
    ).where((k) => isNumericMessage(en, k)).toSet();
    for (final key in numericEnKeys) {
      if (!ar.containsKey(key)) {
        problems.add('$key: numeric en message has no ar counterpart');
        continue;
      }
      final enValue = en[key];
      final arValue = ar[key];
      final enCats = enValue is String
          ? plural_rules.pluralCategoriesOf(enValue) ?? <String>{}
          : <String>{};
      final arCats = arValue is String
          ? plural_rules.pluralCategoriesOf(arValue) ?? <String>{}
          : <String>{};
      if (enCats.isNotEmpty || arCats.isNotEmpty) {
        // NOTE: Set/Map `==` is IDENTITY in Dart — compare contents explicitly.
        if (enCats.length != arCats.length || !enCats.containsAll(arCats)) {
          problems.add(
            '$key: plural categories differ — '
            'en=${enCats.toList()..sort()} ar=${arCats.toList()..sort()}',
          );
        }
      }
      final enTypes = plural_rules.placeholderTypesOf(en, key);
      final arTypes = plural_rules.placeholderTypesOf(ar, key);
      final sameTypes =
          enTypes.length == arTypes.length &&
          enTypes.entries.every((e) => arTypes[e.key] == e.value);
      if (enTypes.isNotEmpty && !sameTypes) {
        problems.add(
          '$key: numeric placeholder declarations differ — '
          'en=$enTypes ar=$arTypes',
        );
      }
    }
    expect(
      problems,
      isEmpty,
      reason: 'Numeric en/ar parity failures: ${problems.join(' | ')}',
    );
  });

  test('no ar-only plural messages (structure drift both ways)', () {
    final arOnly = nonMetaKeys(ar).where((k) {
      final value = ar[k];
      final arHasPlural =
          value is String && plural_rules.pluralCategoriesOf(value) != null;
      if (!arHasPlural) return false;
      final enValue = en[k];
      final enHasPlural =
          enValue is String && plural_rules.pluralCategoriesOf(enValue) != null;
      return !enHasPlural;
    }).toList()..sort();
    expect(
      arOnly,
      isEmpty,
      reason: 'ar plurals with no en plural counterpart: ${arOnly.join(', ')}',
    );
  });

  test(
    'every app_en.arb key is present in app_ar.arb (no silent English fallback)',
    () {
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();

      final missing = enKeys.difference(arKeys).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'Missing Arabic translations (would render English): '
            '${missing.join(', ')}',
      );
    },
  );

  test('Arabic provides non-empty values — no placeholder-only stubs', () {
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
    final empties = <String>[];
    for (final k in enKeys) {
      if (ar[k] is String && (ar[k] as String).trim().isEmpty) {
        empties.add(k);
      }
    }
    expect(
      empties,
      isEmpty,
      reason: 'Empty Arabic values: ${empties.join(', ')}',
    );
  });

  test('C-3 (p18 A2.4): the orphan enterReferralCode key is removed', () {
    // Zero consumers repo-wide (verified by the carriage): the key must be
    // gone from BOTH ARBs — presence here is the RED state.
    expect(
      en.containsKey('enterReferralCode'),
      isFalse,
      reason: 'enterReferralCode has zero consumers — remove from app_en.arb',
    );
    expect(
      ar.containsKey('enterReferralCode'),
      isFalse,
      reason: 'enterReferralCode has zero consumers — remove from app_ar.arb',
    );
  });
}
