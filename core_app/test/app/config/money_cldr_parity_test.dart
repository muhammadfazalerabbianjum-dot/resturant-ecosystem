@Tags(['gate_fast'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';

/// FIX-B3 / AUD1-02 — T-2: the AUD-1 14-row CLDR conformance matrix.
///
/// Every row is asserted against ALL THREE public formatters, in this fixed
/// order: `[moneyCents, formatCurrencyCents, formatAmount]`. The `target` is
/// the unified, CLDR-conformant output (owner decision D-1: negatives render
/// `-$1.50`, minus BEFORE the symbol; JPY/KRW render with zero decimals;
/// unknown codes render a `CODE ` prefix; codes are case-normalized).
///
/// Pre-fix contract (receipt `tool_fix/b3/red_matrix.txt`): exactly the
/// AUD-1 divergent rows fail — `-150/USD`, `1250/CAD`, `1250/AUD`,
/// `1250/JPY`, `1250/AED`, `1250/SAR`, `1250/XYZ`, `1250/usd` = **8 red
/// rows**; the remaining 6 (zero/positive USD incl. grouping, EUR, GBP,
/// null) already agree. Post-fix: 14/14.
class _MatrixRow {
  const _MatrixRow(this.label, this.cents, this.code, this.target);

  final String label;
  final int cents;
  final String? code;

  /// The CLDR-conformant output every formatter must produce.
  final String target;

  /// What `formatAmount` receives: its parameter is non-nullable (W9.3
  /// retired the silent USD default), so the `null`-code row passes the
  /// app-side equivalent — the explicit configured code.
  String get amountCode => code ?? 'USD';
}

const List<_MatrixRow> _kMatrix = <_MatrixRow>[
  _MatrixRow('0 / USD', 0, 'USD', r'$0.00'),
  _MatrixRow('1250 / USD', 1250, 'USD', r'$12.50'),
  _MatrixRow('123456789 / USD', 123456789, 'USD', r'$1,234,567.89'),
  _MatrixRow('-150 / USD', -150, 'USD', r'-$1.50'),
  _MatrixRow('1250 / CAD', 1250, 'CAD', r'CA$12.50'),
  _MatrixRow('1250 / AUD', 1250, 'AUD', r'A$12.50'),
  _MatrixRow('1250 / EUR', 1250, 'EUR', '€12.50'),
  _MatrixRow('1250 / GBP', 1250, 'GBP', '£12.50'),
  _MatrixRow('1250 / JPY', 1250, 'JPY', '¥13'),
  _MatrixRow('1250 / AED', 1250, 'AED', 'AED 12.50'),
  _MatrixRow('1250 / SAR', 1250, 'SAR', 'SAR 12.50'),
  _MatrixRow('1250 / XYZ', 1250, 'XYZ', 'XYZ 12.50'),
  _MatrixRow('1250 / usd', 1250, 'usd', r'$12.50'),
  _MatrixRow('1250 / null', 1250, null, r'$12.50'),
];

/// UI-8 (p18) T-3 — the same 14 inputs rendered per CLDR `ar` currency
/// patterns (intl's `ar` NumberSymbols:
/// `CURRENCY_PATTERN: '\u200F#,##0.00\u00A0¤;\u200F-#,##0.00\u00A0¤'`
/// = RTL mark before the amount, NBSP before the symbol, minus BEFORE the
/// amount when negative; `ZERO_DIGIT: '0'` = Latin digits for the plain
/// `ar` tag). Symbols come from the ONE map (`moneySymbolFor`), fraction
/// digits from CLDR minorDigits via the currency name. Ground-truth receipt:
/// `tool_uilib/p18/receipts/t3_cldr_probe.txt`.
const List<_MatrixRow> _kArMatrix = <_MatrixRow>[
  _MatrixRow('ar: 0 / USD', 0, 'USD', '\u200F0.00\u00A0\$'),
  _MatrixRow('ar: 1250 / USD', 1250, 'USD', '\u200F12.50\u00A0\$'),
  _MatrixRow(
    'ar: 123456789 / USD',
    123456789,
    'USD',
    '\u200F1,234,567.89\u00A0\$',
  ),
  _MatrixRow('ar: -150 / USD', -150, 'USD', '\u200F-1.50\u00A0\$'),
  _MatrixRow('ar: 1250 / CAD', 1250, 'CAD', '\u200F12.50\u00A0CA\$'),
  _MatrixRow('ar: 1250 / AUD', 1250, 'AUD', '\u200F12.50\u00A0A\$'),
  _MatrixRow('ar: 1250 / EUR', 1250, 'EUR', '\u200F12.50\u00A0€'),
  _MatrixRow('ar: 1250 / GBP', 1250, 'GBP', '\u200F12.50\u00A0£'),
  _MatrixRow('ar: 1250 / JPY', 1250, 'JPY', '\u200F13\u00A0¥'),
  _MatrixRow('ar: 1250 / AED', 1250, 'AED', '\u200F12.50\u00A0AED'),
  _MatrixRow('ar: 1250 / SAR', 1250, 'SAR', '\u200F12.50\u00A0SAR'),
  _MatrixRow('ar: 1250 / XYZ', 1250, 'XYZ', '\u200F12.50\u00A0XYZ'),
  _MatrixRow('ar: 1250 / usd', 1250, 'usd', '\u200F12.50\u00A0\$'),
  _MatrixRow('ar: 1250 / null', 1250, null, '\u200F12.50\u00A0\$'),
];

void main() {
  group('T-2 CLDR conformance matrix — 14 rows × 3 formatters', () {
    for (final row in _kMatrix) {
      test('row "${row.label}" renders ${row.target} everywhere', () {
        final actual = <String>[
          moneyCents(row.cents, currencyCode: row.code),
          formatCurrencyCents(row.cents, currencyCode: row.code),
          formatAmount(row.cents, row.amountCode),
        ];
        expect(
          actual,
          everyElement(row.target),
          reason:
              'AUD1-02 row "${row.label}" — actual list order: '
              '[moneyCents, formatCurrencyCents, formatAmount]',
        );
      });
    }

    test('matrix size guard — exactly the 14 AUD-1 rows', () {
      expect(_kMatrix, hasLength(14));
    });
  });

  // ---------------------------------------------------------------------------
  // UI-8 (p18) T-3 — locale-aware currency (L2 money-display parity).
  //
  // Contract: `en` stays BYTE-IDENTICAL to today's renderer for every
  // supported code (explicit `locale: 'en'` so this suite never depends on
  // the host locale); `ar` renders per CLDR `ar` currency patterns (see
  // `_kArMatrix` for the pattern decode); any non-`ar` locale falls back to
  // the current renderer unchanged; the default (no `locale:`) reads the
  // AMBIENT platform locale, which equals the app locale because the app's
  // MaterialApp sets no explicit `locale:` (it follows the device).
  group('T-3 locale-aware currency (L2 en parity + CLDR ar)', () {
    for (final row in _kMatrix) {
      test('en byte-identical — "${row.label}"', () {
        final viaLocale = formatCurrencyCents(
          row.cents,
          currencyCode: row.code,
          locale: 'en',
        );
        expect(viaLocale, row.target, reason: 'L2: en stays byte-identical');
        expect(
          viaLocale,
          moneyCents(row.cents, currencyCode: row.code),
          reason: 'L2: en path agrees with the single renderer',
        );
      });
    }

    test('ar table-driven CLDR rows — 14 rows', () {
      for (final row in _kArMatrix) {
        expect(
          formatCurrencyCents(row.cents, currencyCode: row.code, locale: 'ar'),
          row.target,
          reason: 'T-3 ar row "${row.label}"',
        );
      }
      expect(_kArMatrix, hasLength(14));
    });

    test(
      'locale variants: ar-SA matches ar; non-ar falls back byte-identical',
      () {
        expect(
          formatCurrencyCents(1250, currencyCode: 'SAR', locale: 'ar-SA'),
          formatCurrencyCents(1250, currencyCode: 'SAR', locale: 'ar'),
          reason: 'device tags like ar-SA resolve to the same ar rendering',
        );
        expect(
          formatCurrencyCents(1250, currencyCode: 'SAR', locale: 'fr'),
          moneyCents(1250, currencyCode: 'SAR'),
          reason: 'unsupported locales fail closed to today\'s renderer',
        );
      },
    );

    test('int.min fails closed to the T-5 placeholder in BOTH locales', () {
      const minCents = -9223372036854775807 - 1;
      expect(
        formatCurrencyCents(minCents, currencyCode: 'USD', locale: 'en'),
        kMoneyRenderPlaceholder,
      );
      expect(
        formatCurrencyCents(minCents, currencyCode: 'USD', locale: 'ar'),
        kMoneyRenderPlaceholder,
        reason: 'ar path must never fabricate digits for the overflowing int',
      );
    });

    testWidgets(
      'ambient locale (Intl seam) drives the default (no-locale) render',
      (tester) async {
        Intl.defaultLocale = 'ar';
        addTearDown(() => Intl.defaultLocale = null);
        expect(
          formatCurrencyCents(1250, currencyCode: 'SAR'),
          '\u200F12.50\u00A0SAR',
          reason: 'ambient ar device renders the CLDR ar form',
        );
        Intl.defaultLocale = 'en';
        expect(
          formatCurrencyCents(1250, currencyCode: 'SAR'),
          'SAR 12.50',
          reason: 'ambient en device stays byte-identical',
        );
      },
    );

    testWidgets(
      'a widget pumping money under an ar ambient locale renders the ar form',
      (tester) async {
        Intl.defaultLocale = 'ar';
        addTearDown(() => Intl.defaultLocale = null);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(formatCurrencyCents(1250, currencyCode: 'SAR')),
          ),
        );
        expect(find.text('\u200F12.50\u00A0SAR'), findsOneWidget);
      },
    );
  });
}
