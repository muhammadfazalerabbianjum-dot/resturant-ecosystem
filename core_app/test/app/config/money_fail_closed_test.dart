@Tags(['gate_fast'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';

/// FIX-B3 / AUD1-02 — T-5: fail-closed display.
///
/// Never NaN, never infinity, never an empty string, never a fabricated
/// number. The one malformed-cents case a two's-complement `int` can carry —
/// `int.min`, where `.abs()` overflows — must yield the explicit placeholder
/// `—` (see `money_text.dart`), not the pre-fix garbage
/// `$--92,233,720,368,547,758.92`.
///
/// Pre-fix receipt: `tool_fix/b3/red_fail_closed.txt`.
void main() {
  const int minInt = -9223372036854775807 - 1;
  const int maxInt = 9223372036854775807;
  const placeholder = '—';

  group(
    'T-5 malformed cents yields the explicit placeholder (never fabricated)',
    () {
      test('int.min renders as the placeholder in all three formatters', () {
        final actual = <String>[
          moneyCents(minInt, currencyCode: 'USD'),
          formatCurrencyCents(minInt, currencyCode: 'USD'),
          formatAmount(minInt, 'USD'),
        ];
        expect(
          actual,
          everyElement(placeholder),
          reason:
              'int.min.abs() overflows — fail-closed placeholder required. '
              'Order: [moneyCents, formatCurrencyCents, formatAmount]',
        );
      });

      test('int.min placeholder also holds for unknown and empty codes', () {
        expect(moneyCents(minInt, currencyCode: 'XYZ'), placeholder);
        expect(moneyCents(minInt, currencyCode: ''), placeholder);
        expect(formatCurrencyCents(minInt, currencyCode: 'JPY'), placeholder);
        expect(formatAmount(minInt, 'ZZZ'), placeholder);
      });
    },
  );

  group('T-5 render output is never NaN / infinity / empty', () {
    final battery = <String, int>{
      'zero': 0,
      'negative': -1,
      'maxInt': maxInt,
      'minInt': minInt,
      'junk-code-minInt': minInt,
    };

    test('moneyCents never emits NaN/infinity/empty', () {
      for (final entry in battery.entries) {
        final out = moneyCents(entry.value, currencyCode: 'USD');
        expect(out, isNotEmpty, reason: '${entry.key} rendered empty');
        expect(out, isNot(contains('NaN')), reason: entry.key);
        expect(out, isNot(contains('Infinity')), reason: entry.key);
      }
    });

    test('formatCurrencyCents never emits NaN/infinity/empty', () {
      for (final entry in battery.entries) {
        final out = formatCurrencyCents(entry.value, currencyCode: 'USD');
        expect(out, isNotEmpty, reason: '${entry.key} rendered empty');
        expect(out, isNot(contains('NaN')), reason: entry.key);
        expect(out, isNot(contains('Infinity')), reason: entry.key);
      }
    });

    test('formatAmount never emits NaN/infinity/empty', () {
      for (final entry in battery.entries) {
        final out = formatAmount(entry.value, 'USD');
        expect(out, isNotEmpty, reason: '${entry.key} rendered empty');
        expect(out, isNot(contains('NaN')), reason: entry.key);
        expect(out, isNot(contains('Infinity')), reason: entry.key);
      }
    });

    test('extremes render faithful digits, not placeholders', () {
      expect(
        formatCurrencyCents(maxInt, currencyCode: 'USD'),
        r'$92,233,720,368,547,758.07',
      );
      expect(formatAmount(maxInt, 'USD'), r'$92,233,720,368,547,758.07');
      expect(formatCurrencyCents(-1, currencyCode: 'USD'), r'-$0.01');
    });
  });

  group('T-5 malformed currency code degrades to an explicit placeholder', () {
    test('empty code falls back to the documented \$ placeholder', () {
      expect(formatAmount(150, ''), r'$1.50');
      expect(formatAmount(1250, ''), r'$12.50');
    });

    test('unknown/junk codes render a CODE prefix — never a fabricated \$', () {
      expect(formatAmount(150, 'XYZ'), 'XYZ 1.50');
      expect(formatAmount(1250, 'usd'), r'$12.50');
      expect(formatAmount(150, ' zz '), 'ZZ 1.50');
      expect(formatAmount(150, 'zz-not-a-currency'), 'ZZ-NOT-A-CURRENCY 1.50');
    });
  });
}
