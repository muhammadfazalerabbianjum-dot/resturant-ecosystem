// UI-8 (p18) T-1 — fail-closed six-form CLDR `ar` plural completeness.
//
// Rule 0.9 (WHITE_LABEL_p18_arabic1 §0): every numeric ARB message must be
// plural-COMPLETE for `ar` — all six CLDR categories (zero/one/two/few/many/
// other) — and an incomplete message is a test failure, never a fallback
// guess. L1: every message with a numeric (int/num) placeholder adopts the
// six-way ICU form in BOTH locales; where a locale's grammar does not vary
// by category the branches may carry identical copy, but all six are
// declared so the structure is fail-closed.
//
// Fail-closed on future additions (T-2 lineage): any NEW key declaring an
// int/num placeholder that is not audited into one of the two tables below
// fails this test — a future numeric message cannot ship without a ruling.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations_ar.dart';
import 'package:labs/l10n/app_localizations_en.dart';

/// Messages the audit (tool_uilib/p18/p18_report.md, numeric-message audit
/// table) ruled SIX-FORM in BOTH locales. Adding a key here is a deliberate,
/// reviewable audit act.
const Set<String> kSixFormPluralKeys = {
  'itemsCount',
  'pendingSyncCount',
  'cartItemsCount',
  'cartItemLimitReached',
  'cartLineLimitReached',
};

/// Numeric keys the audit ruled NO ICU plural, with the per-key reason
/// (L1: "audit decides per message").
const Map<String, String> kNoPluralRequiredKeys = {
  'trackerStepOfTotal':
      'ordinal "Step {step} of {total}" label — a position in a sequence, '
      'not a counted noun; the Arabic equivalent does not inflect by count.',
  'onboardingPage':
      'ordinal "Page {page} of {total}" label (p18 C-1) — a position in a '
      'sequence, not a counted noun; the Arabic equivalent does not inflect '
      'by count.',
  'onboardingPageDot':
      'ordinal "Page {page}" dot label (p18 C-1) — a position marker, not a '
      'counted noun; the Arabic digits form does not inflect by count.',
};

/// The six CLDR `ar` plural categories (CLDR Language Plural Rules, ar row).
const Set<String> kCldrArCategories = {
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
};

/// Canonicalises an ICU plural category token: `=0` -> `zero`, `=1` -> `one`,
/// `=2` -> `two`; named categories pass through; any other exact match
/// (e.g. `=7`) is returned as-is so it fails the six-set comparison.
String canonicalPluralCategory(String token) {
  switch (token) {
    case '=0':
      return 'zero';
    case '=1':
      return 'one';
    case '=2':
      return 'two';
    default:
      return token;
  }
}

/// Extracts the declared plural categories of an ICU message, canonicalised
/// to CLDR names. Returns null when the message carries no ICU plural.
///
/// Parser: after the `, plural,` selector, categories are the top-level
/// `token{` pairs; nested `{placeholder}` args inside branches are skipped by
/// tracking brace depth, so branch copy cannot fake a category.
Set<String>? pluralCategoriesOf(String message) {
  const selector = ', plural,';
  final idx = message.indexOf(selector);
  if (idx < 0) return null;
  final categories = <String>{};
  var depth = 0;
  final token = StringBuffer();
  for (var i = idx + selector.length; i < message.length; i++) {
    final ch = message[i];
    if (depth == 0) {
      if (ch == '}') break; // closes the outer {arg, plural, ...} placeholder
      if (ch == '{') {
        if (token.isNotEmpty) {
          categories.add(canonicalPluralCategory(token.toString()));
          token.clear();
        }
        depth = 1;
      } else if (ch == ' ' || ch == '\t' || ch == '\n') {
        token.clear();
      } else {
        token.write(ch);
      }
    } else {
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
      }
    }
  }
  if (token.isNotEmpty) {
    categories.add(canonicalPluralCategory(token.toString()));
  }
  return categories;
}

/// Placeholder name -> declared type from an ARB entry's `@key` metadata.
Map<String, String> placeholderTypesOf(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is! Map<String, dynamic>) return const {};
  final placeholders = meta['placeholders'];
  if (placeholders is! Map<String, dynamic>) return const {};
  final out = <String, String>{};
  placeholders.forEach((name, decl) {
    if (decl is Map<String, dynamic>) {
      out[name] = (decl['type'] ?? 'String').toString();
    }
  });
  return out;
}

/// True when the entry declares at least one numeric (int/num) placeholder.
bool declaresNumericPlaceholder(Map<String, dynamic> arb, String key) =>
    placeholderTypesOf(arb, key).values.any((t) => t == 'int' || t == 'num');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() {
    en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
  });

  Set<String> keys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('ar: every ICU plural declares ALL six CLDR categories', () {
    final offenders = <String>[];
    for (final key in keys(ar)) {
      final value = ar[key];
      if (value is! String) continue;
      final cats = pluralCategoriesOf(value);
      if (cats == null) continue;
      final missing = kCldrArCategories.difference(cats);
      if (missing.isNotEmpty) {
        offenders.add('$key missing ${missing.toList()..sort()} (has $cats)');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Incomplete ar plurals (rule 0.9, never a fallback guess): '
          '${offenders.join(' | ')}',
    );
  });

  test('six-form keys declare all six categories in BOTH locales', () {
    final offenders = <String>[];
    for (final key in kSixFormPluralKeys) {
      for (final entry in {'en': en, 'ar': ar}.entries) {
        final value = entry.value[key];
        if (value is! String) {
          offenders.add('$key missing from ${entry.key}');
          continue;
        }
        final cats = pluralCategoriesOf(value);
        if (cats == null) {
          offenders.add('$key (${entry.key}) has no ICU plural');
          continue;
        }
        final missing = kCldrArCategories.difference(cats);
        if (missing.isNotEmpty) {
          offenders.add(
            '$key (${entry.key}) missing ${missing.toList()..sort()}',
          );
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join(' | '));
  });

  test('every ICU plural key (en or ar) is an audited six-form key', () {
    final unlisted = <String>[];
    for (final entry in {'en': en, 'ar': ar}.entries) {
      for (final key in keys(entry.value)) {
        final value = entry.value[key];
        if (value is! String) continue;
        if (pluralCategoriesOf(value) == null) continue;
        if (!kSixFormPluralKeys.contains(key)) {
          unlisted.add('${entry.key}:$key');
        }
      }
    }
    expect(
      unlisted,
      isEmpty,
      reason:
          'Unaudited plural messages (add to kSixFormPluralKeys with a '
          'grammar ruling): ${unlisted.join(', ')}',
    );
  });

  test('fail-closed: every int/num placeholder key is audited '
      '(six-form or documented no-plural)', () {
    final audited = {...kSixFormPluralKeys, ...kNoPluralRequiredKeys.keys};
    final unaudited = <String>[];
    for (final entry in {'en': en, 'ar': ar}.entries) {
      for (final key in keys(entry.value)) {
        if (!declaresNumericPlaceholder(entry.value, key)) continue;
        if (!audited.contains(key)) {
          unaudited.add('${entry.key}:$key');
        }
      }
    }
    expect(
      unaudited,
      isEmpty,
      reason:
          'Numeric messages with no plural ruling (L1 audit gate): '
          '${unaudited.join(', ')}',
    );
  });

  test('no-plural keys are declared, numeric, and carry no ICU plural', () {
    final offenders = <String>[];
    for (final key in kNoPluralRequiredKeys.keys) {
      if (!declaresNumericPlaceholder(en, key) ||
          !declaresNumericPlaceholder(ar, key)) {
        offenders.add('$key lost its numeric placeholder declaration');
      }
      for (final entry in {'en': en, 'ar': ar}.entries) {
        final value = entry.value[key];
        if (value is! String) {
          offenders.add('$key missing from ${entry.key}');
          continue;
        }
        if (pluralCategoriesOf(value) != null) {
          offenders.add(
            '$key (${entry.key}) now carries a plural — move it to '
            'kSixFormPluralKeys with a grammar ruling',
          );
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join(' | '));
  });

  test('CLDR ar six-form render — 0/1/2/3/11/25 samples (rule L1)', () {
    final arL = AppLocalizationsAr();
    expect(arL.itemsCount(0), 'لا عناصر');
    expect(arL.itemsCount(1), 'عنصر واحد');
    expect(arL.itemsCount(2), 'عنصران');
    expect(arL.itemsCount(3), '3 عناصر');
    expect(arL.itemsCount(11), '11 عنصرًا');
    expect(arL.itemsCount(25), '25 عنصرًا');
    expect(arL.pendingSyncCount(0), 'لا طلبات في انتظار المزامنة');
    expect(arL.pendingSyncCount(3), '3 طلبات في انتظار المزامنة');
    expect(arL.pendingSyncCount(11), '11 طلبًا في انتظار المزامنة');
    expect(arL.pendingSyncCount(100), '100 طلب في انتظار المزامنة');
    expect(arL.cartItemsCount(3), 'السلة، 3 عناصر');
    expect(
      arL.cartLineLimitReached(3),
      'سلتك ممتلئة — يُسمح بـ 3 عناصر مختلفة كحد أقصى.',
    );
    expect(arL.cartItemLimitReached(11), 'يمكنك إضافة حتى 11 من هذا الطبق.');
  });

  test('en renders the SAME copy as pre-change for every audited branch', () {
    final enL = AppLocalizationsEn();
    expect(enL.itemsCount(0), 'No items');
    expect(enL.itemsCount(1), '1 item');
    expect(enL.itemsCount(3), '3 items');
    expect(enL.pendingSyncCount(0), '0 orders pending sync');
    expect(enL.pendingSyncCount(1), '1 order pending sync');
    expect(enL.pendingSyncCount(2), '2 orders pending sync');
    expect(enL.cartItemsCount(0), 'Cart, empty');
    expect(enL.cartItemsCount(3), 'Cart, 3 items');
    expect(enL.cartItemLimitReached(10), 'You can add up to 10 of this item.');
    expect(
      enL.cartLineLimitReached(10),
      'Your cart is full — up to 10 different items.',
    );
  });
}
