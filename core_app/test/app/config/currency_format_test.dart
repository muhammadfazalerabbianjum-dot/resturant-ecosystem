import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/currency_format.dart';

/// W9.3 (05-P1-L10N-MONEY) T-4 — canonical money formatter contract:
/// thousands grouping + configured currency symbol, `$` fallback for
/// unset codes, CLDR negative form (D-1: minus BEFORE the symbol).
///
/// FIX-B3 / AUD1-02: the unknown-code fallback is now a fail-closed
/// `CODE ` prefix (single symbol map in `package:core_ui`) and negatives
/// render `-$1.50` — the two assertions that pinned the retired divergent
/// behavior were updated here; the authoritative CLDR matrix lives in
/// `money_cldr_parity_test.dart`.
void main() {
  group('currencySymbolFor', () {
    test('maps known ISO codes to display symbols', () {
      expect(currencySymbolFor('USD'), r'$');
      expect(currencySymbolFor('EUR'), '€');
      expect(currencySymbolFor('GBP'), '£');
      expect(currencySymbolFor('AED'), 'AED ');
      expect(currencySymbolFor('SAR'), 'SAR ');
      expect(currencySymbolFor('CAD'), r'CA$');
      expect(currencySymbolFor('AUD'), r'A$');
      expect(currencySymbolFor('JPY'), r'¥');
    });

    test('falls back to \$ for empty/null and a CODE prefix for unknown', () {
      expect(currencySymbolFor(null), r'$');
      expect(currencySymbolFor(''), r'$');
      expect(currencySymbolFor('XYZ'), 'XYZ ');
    });
  });

  group('formatCurrencyCents (T-4: grouping + config currency)', () {
    test(
      'T-4: formatCurrencyCents(1234567) -> grouped string with config currency',
      () {
        expect(
          formatCurrencyCents(1234567, currencyCode: 'AED'),
          'AED 12,345.67',
        );
        expect(formatCurrencyCents(1234567), r'$12,345.67');
      },
    );

    test('groups every third digit', () {
      expect(
        formatCurrencyCents(123456789, currencyCode: 'USD'),
        r'$1,234,567.89',
      );
      expect(formatCurrencyCents(1000, currencyCode: 'USD'), r'$10.00');
      expect(formatCurrencyCents(999, currencyCode: 'USD'), r'$9.99');
    });

    test('renders small values with exactly 2 decimals', () {
      expect(formatCurrencyCents(1250, currencyCode: 'USD'), r'$12.50');
      expect(formatCurrencyCents(5, currencyCode: 'USD'), r'$0.05');
      expect(formatCurrencyCents(100, currencyCode: 'USD'), r'$1.00');
    });

    test('renders zero as 0.00 with the configured symbol', () {
      expect(formatCurrencyCents(0, currencyCode: 'SAR'), 'SAR 0.00');
    });

    test(
      'renders negative values (discount lines) with the CLDR sign (D-1)',
      () {
        expect(
          formatCurrencyCents(-1234567, currencyCode: 'USD'),
          r'-$12,345.67',
        );
        expect(formatCurrencyCents(-50, currencyCode: 'EUR'), '-€0.50');
      },
    );
  });
}
