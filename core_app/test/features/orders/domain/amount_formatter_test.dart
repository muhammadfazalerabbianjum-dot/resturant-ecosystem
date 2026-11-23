import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';

/// PERF-2 S1 — W9.3 (05-P1-L10N-MONEY): the formatter takes the CLIENT'S
/// currency code explicitly; the silent USD default was retired, so an
/// AED/SAR white-label client can never silently render USD prices.
void main() {
  group('formatAmount — explicit-currency money rendering', () {
    test('USD renders the dollar symbol with exact minor units', () {
      expect(formatAmount(150, 'USD'), '\$1.50');
      expect(formatAmount(0, 'USD'), '\$0.00');
    });

    test('a non-USD client currency renders its own symbol — never USD', () {
      final String aed = formatAmount(150, 'AED');
      expect(aed, contains('1.50'));
      expect(
        aed,
        isNot(contains('\$')),
        reason: 'W9.3: a configured AED client must never see a dollar sign',
      );
    });

    test(
      'an unknown currency code degrades to a code-symbol rendering — never USD, never a throw',
      () {
        // intl's simpleCurrency does NOT throw for unknown names (it renders
        // the name itself as the symbol); the formatter's catch-branch is a
        // defensive fallback. The W9.3 invariant still holds: junk input
        // NEVER renders a USD dollar sign.
        final String weird = formatAmount(150, 'zz-not-a-currency');
        expect(weird, contains('1.50'));
        expect(weird, isNot(contains('\$')));
      },
    );
  });
}
