@Tags(['gate_fast'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';

/// FIX-B3 / AUD1-02 (T-1) — zero-decimal rule beyond the AUD-1 matrix rows:
/// KRW (CLDR `minorDigits=0`) must render whole units through ALL THREE
/// formatters once they share one implementation.
///
/// KRW is deliberately NOT one of the 14 AUD-1 rows (the parity log
/// `tool_audit/aud1/receipts/c3_parity_run.log` sampled no KRW row), so it
/// runs as its own red→green rule test: pre-fix receipt
/// `tool_fix/b3/red_krw_rule.txt` (moneyCents `KRW 12.50`,
/// formatCurrencyCents `$12.50` — two different wrong answers).
void main() {
  test('KRW renders whole units through ALL three formatters', () {
    final actual = <String>[
      moneyCents(1250, currencyCode: 'KRW'),
      formatCurrencyCents(1250, currencyCode: 'KRW'),
      formatAmount(1250, 'KRW'),
    ];
    expect(
      actual,
      everyElement('₩13'),
      reason:
          'CLDR KRW minorDigits=0 — order: '
          '[moneyCents, formatCurrencyCents, formatAmount]',
    );
  });
}
