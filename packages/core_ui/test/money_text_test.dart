import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  group('moneyCents - multi-app currency formatter (B3-1)', () {
    test('formats USD dollars and cents with two decimal digits', () {
      expect(moneyCents(0, currencyCode: 'USD'), r'$0.00');
      expect(moneyCents(50, currencyCode: 'USD'), r'$0.50');
      expect(moneyCents(1250, currencyCode: 'USD'), r'$12.50');
      expect(moneyCents(123456, currencyCode: 'USD'), r'$1,234.56');
    });

    test('uses AED/SAR prefix symbols (no hardcoded dollar)', () {
      expect(moneyCents(1250, currencyCode: 'AED'), 'AED 12.50');
      expect(moneyCents(1250, currencyCode: 'SAR'), 'SAR 12.50');
    });

    test('prefers an explicit currency symbol from the config', () {
      expect(
        moneyCents(1250, currencyCode: 'USD', currencySymbol: r'US$'),
        'US\$12.50',
      );
    });

    test('falls back to code-prefix for unknown currencies', () {
      expect(moneyCents(1250, currencyCode: 'XYZ'), 'XYZ 12.50');
    });

    test('negative cents render a leading minus sign with exact minor', () {
      expect(moneyCents(-123, currencyCode: 'USD'), r'-$1.23');
    });
  });
}
