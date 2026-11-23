import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// FIX-B3 / AUD1-02 (T-1) — the source-of-truth rules, asserted directly on
/// `moneyCents` inside its own package:
///
/// 1. CLDR zero-decimal currencies (JPY, KRW) render whole units only.
/// 2. Currency codes are case-normalized (`usd` → USD's `$`, not a literal
///    `usd ` prefix).
/// 3. Negatives keep the CLDR form (minus BEFORE the symbol, D-1 `-$1.50`).
/// 4. Malformed cents (`int.min`) fails closed to the placeholder `—`.
/// 5. Unknown codes keep the fail-closed `CODE ` prefix.
///
/// Pre-fix receipt: `tool_fix/b3/red_cldr_core_ui.txt`.
void main() {
  group('T-1 CLDR zero-decimal currencies (JPY, KRW)', () {
    test('JPY renders whole units, round half away from zero', () {
      expect(moneyCents(1250, currencyCode: 'JPY'), '¥13');
      expect(moneyCents(0, currencyCode: 'JPY'), '¥0');
      expect(moneyCents(149, currencyCode: 'JPY'), '¥1');
      expect(moneyCents(150, currencyCode: 'JPY'), '¥2');
      expect(moneyCents(999, currencyCode: 'JPY'), '¥10');
      expect(moneyCents(123456789, currencyCode: 'JPY'), '¥1,234,568');
    });

    test('JPY negatives keep the CLDR minus-before-symbol form', () {
      expect(moneyCents(-150, currencyCode: 'JPY'), '-¥2');
      expect(moneyCents(-1250, currencyCode: 'JPY'), '-¥13');
    });

    test('KRW renders whole units (CLDR minorDigits=0)', () {
      expect(moneyCents(1250, currencyCode: 'KRW'), '₩13');
      expect(moneyCents(0, currencyCode: 'KRW'), '₩0');
      expect(moneyCents(-150, currencyCode: 'KRW'), '-₩2');
    });

    test('zero-decimal rule still honors an explicit config symbol', () {
      expect(
        moneyCents(1250, currencyCode: 'JPY', currencySymbol: r'JP¥'),
        'JP¥13',
      );
    });
  });

  group('T-1 case-normalized codes', () {
    test('lowercase codes resolve to their known symbol', () {
      expect(moneyCents(1250, currencyCode: 'usd'), r'$12.50');
      expect(moneyCents(1250, currencyCode: 'eur'), '€12.50');
      expect(moneyCents(1250, currencyCode: 'cad'), r'CA$12.50');
    });

    test(
      'lowercase unknown codes still fail closed to an upper CODE prefix',
      () {
        expect(moneyCents(1250, currencyCode: 'xyz'), 'XYZ 12.50');
        expect(moneyCents(150, currencyCode: ' zz '), 'ZZ 1.50');
      },
    );
  });

  group('T-1 CLDR negative form (D-1) stays byte-stable', () {
    test('minus renders before the symbol', () {
      expect(moneyCents(-150, currencyCode: 'USD'), r'-$1.50');
      expect(moneyCents(-50, currencyCode: 'EUR'), '-€0.50');
      expect(moneyCents(-1234567, currencyCode: 'USD'), r'-$12,345.67');
      expect(moneyCents(-1250, currencyCode: 'AED'), '-AED 12.50');
      expect(moneyCents(-1250, currencyCode: 'XYZ'), '-XYZ 12.50');
    });
  });

  group('T-5 fail-closed placeholder at the source', () {
    test('int.min yields the placeholder — never fabricated digits', () {
      const int minInt = -9223372036854775807 - 1;
      expect(moneyCents(minInt, currencyCode: 'USD'), '—');
      expect(moneyCents(minInt, currencyCode: 'JPY'), '—');
      expect(moneyCents(minInt), '—');
    });
  });
}
