@Tags(['gate_fast'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';

/// FIX-B3 / AUD1-02 — T-3: positive-amount byte identity.
///
/// Every assertion below is byte-identical to what the app rendered BEFORE
/// FIX-B3 (verified in the RED receipt `tool_fix/b3/red_byte_identity.txt`,
/// where this whole group is green — it is a guard, not a migration). After
/// the unification it must still be green: a positive known-code amount that
/// moves here is a defect, not a migration.
///
/// Scope note (documented in `tool_fix/b3/b3_report.md`): rows AUD-1 marked
/// DIVERGE are excluded by design — their positive bytes change because they
/// were WRONG (CAD/AUD symbol, JPY decimals, AED/SAR labels via
/// `formatAmount`). The shipped client config (halal_boyz, `currency: USD`)
/// renders exclusively through the rows covered here.
void main() {
  group(
    'T-3 positive-amount byte identity (the AGREE rows stay byte-identical)',
    () {
      test(
        'zero and positive USD render the exact pre-fix bytes everywhere',
        () {
          expect(moneyCents(0, currencyCode: 'USD'), r'$0.00');
          expect(formatCurrencyCents(0, currencyCode: 'USD'), r'$0.00');
          expect(formatAmount(0, 'USD'), r'$0.00');

          expect(moneyCents(1250, currencyCode: 'USD'), r'$12.50');
          expect(formatCurrencyCents(1250, currencyCode: 'USD'), r'$12.50');
          expect(formatAmount(1250, 'USD'), r'$12.50');
        },
      );

      test(
        'positive USD keeps thousands grouping byte-identical everywhere',
        () {
          expect(moneyCents(123456789, currencyCode: 'USD'), r'$1,234,567.89');
          expect(
            formatCurrencyCents(123456789, currencyCode: 'USD'),
            r'$1,234,567.89',
          );
          expect(formatAmount(123456789, 'USD'), r'$1,234,567.89');
        },
      );

      test(
        'positive EUR and GBP render the exact pre-fix bytes everywhere',
        () {
          expect(moneyCents(1250, currencyCode: 'EUR'), '€12.50');
          expect(formatCurrencyCents(1250, currencyCode: 'EUR'), '€12.50');
          expect(formatAmount(1250, 'EUR'), '€12.50');

          expect(moneyCents(1250, currencyCode: 'GBP'), '£12.50');
          expect(formatCurrencyCents(1250, currencyCode: 'GBP'), '£12.50');
          expect(formatAmount(1250, 'GBP'), '£12.50');
        },
      );

      test(
        'null/empty code keeps the pre-fix \$ fallback everywhere it exists',
        () {
          expect(moneyCents(1250), r'$12.50');
          expect(formatCurrencyCents(1250), r'$12.50');
          expect(moneyCents(1250, currencyCode: ''), r'$12.50');
          expect(formatCurrencyCents(1250, currencyCode: ''), r'$12.50');
        },
      );

      test('moneyCents known-code positives never move (source of truth)', () {
        expect(moneyCents(1250, currencyCode: 'CAD'), r'CA$12.50');
        expect(moneyCents(1250, currencyCode: 'AUD'), r'A$12.50');
        expect(moneyCents(1250, currencyCode: 'AED'), 'AED 12.50');
        expect(moneyCents(1250, currencyCode: 'SAR'), 'SAR 12.50');
        expect(moneyCents(5, currencyCode: 'USD'), r'$0.05');
        expect(
          moneyCents(1250, currencyCode: 'USD', currencySymbol: r'US$'),
          r'US$12.50',
        );
      });

      test('formatCurrencyCents AED/SAR positives never move', () {
        expect(
          formatCurrencyCents(1234567, currencyCode: 'AED'),
          'AED 12,345.67',
        );
        expect(formatCurrencyCents(0, currencyCode: 'SAR'), 'SAR 0.00');
        expect(formatCurrencyCents(999, currencyCode: 'USD'), r'$9.99');
        expect(formatCurrencyCents(1000, currencyCode: 'USD'), r'$10.00');
      });

      test(
        'shipped client config (halal_boyz = USD) positives are untouched',
        () {
          // The shipped client_config.json carries currency.code = "USD"; every
          // positive amount that screen renders must be byte-identical to today.
          expect(
            formatCurrencyCents(1234567, currencyCode: 'USD'),
            r'$12,345.67',
          );
          expect(formatAmount(150, 'USD'), r'$1.50');
          expect(moneyCents(123456, currencyCode: 'USD'), r'$1,234.56');
        },
      );
    },
  );
}
