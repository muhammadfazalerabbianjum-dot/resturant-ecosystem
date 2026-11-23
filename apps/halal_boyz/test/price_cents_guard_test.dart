import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show formatCurrencyCents;

/// T-B9-3 carried forward into the ARCH-1 architecture — shell money is
/// canonical integer `priceCents` rendered through the canonical formatter;
/// floating-point money and resurrected `data['price']` reads must never
/// appear in shell code.
///
/// Pre-ARCH-1 the widget half of this guard pumped the shell's own
/// placeholder `MenuScreen` (6 hardcoded dishes). ARCH-1 deletes it: the
/// REAL `MenuScreen` streams the REAL Firestore menu and renders every
/// price through the SAME canonical formatter asserted below
/// (`formatCurrencyCents` — the single customer-facing money formatter,
/// W9.3). The money itself is proven integer-cents by the labs suite
/// (`core_app/test/features/menu/*`, `cart/*`,
/// `core_app/test/app/config/currency_format_test.dart`).
void main() {
  group('T-B9-3 (ARCH-1): the REAL money formatter (integer cents)', () {
    test('renders integer cents through the configured currency code', () {
      // The pre-ARCH-1 shell placeholder's own fixtures, now asserted
      // against the REAL production formatter from package:labs.
      expect(formatCurrencyCents(999, currencyCode: 'AED'), 'AED 9.99');
      expect(formatCurrencyCents(849, currencyCode: 'AED'), 'AED 8.49');
    });

    test('groups thousands, handles negatives and the unknown-code fallback', () {
      expect(formatCurrencyCents(1250, currencyCode: 'USD'), r'$12.50');
      expect(formatCurrencyCents(1234567, currencyCode: 'USD'), r'$12,345.67');
      // CLDR target (AUD1-02 + D-1): negative amounts render minus before symbol
      expect(formatCurrencyCents(-500, currencyCode: 'USD'), r'-$5.00');
      expect(formatCurrencyCents(0, currencyCode: 'USD'), r'$0.00');
      // CLDR target (AUD1-02 + D-1): unknown codes fail closed to CODE-prefix
      expect(formatCurrencyCents(100, currencyCode: 'XYZ'), 'XYZ 1.00');
    });
  });

  test('no floating-point money or resurrected price field in shell code', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.contains('l10n') &&
              !f.path.endsWith('.freezed.dart'),
        )
        .toList();
    for (final file in files) {
      final text = file.readAsStringSync();
      expect(
        text.contains('price.toStringAsFixed'),
        isFalse,
        reason: '${file.path} must not format a double price',
      );
      expect(
        text.contains(
          "'"
          'US'
          'D '
          "'",
        ),
        isFalse,
        reason: '${file.path} must not hardcode a currency literal',
      );
      expect(
        text.contains('double total'),
        isFalse,
        reason: '${file.path} must not store money in a double',
      );
      expect(
        text.contains('double price'),
        isFalse,
        reason: '${file.path} must not store price in a double',
      );
      expect(
        text.contains('double amount'),
        isFalse,
        reason: '${file.path} must not store amount in a double',
      );
      expect(
        text.contains("data['price']"),
        isFalse,
        reason:
            '${file.path} must not resurrect the deprecated double `price` '
            'field — money is integer `priceCents` (Law 3)',
      );
    }
  });
}
