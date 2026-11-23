import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// P6-01: Money-path test — NumToIntConverter rounds half away from zero
/// (Dart num.round(); the former label was wrong — corrected per AUD1-16).
/// Law 3: fractional cents must round, never truncate.
/// 1999.99 → 2000 (rounds to nearest cent), not 1999 (truncation).
void main() {
  group('NumToIntConverter — half-away-from-zero rounding (Law 3)', () {
    const converter = NumToIntConverter();

    test('1999.99 rounds to 2000 (not 1999 truncation)', () {
      expect(converter.fromJson(1999.99), 2000);
    });

    test('1999.49 rounds to 1999', () {
      expect(converter.fromJson(1999.49), 1999);
    });

    test('1999.5 rounds to 2000', () {
      expect(converter.fromJson(1999.5), 2000);
    });

    test('integer input stays exact', () {
      expect(converter.fromJson(1999), 1999);
      expect(converter.fromJson(0), 0);
      expect(converter.fromJson(100), 100);
    });

    test('null/string input parsed correctly', () {
      // Null/string fallback: tryParse returns null → 0
      // The converter returns 0 for unparseable non-num values
      expect(converter.fromJson('1999.99'), 2000);
      expect(converter.fromJson('0'), 0);
    });

    test('small fractional cents round correctly', () {
      expect(converter.fromJson(0.001), 0);
      expect(converter.fromJson(0.499), 0);
      expect(converter.fromJson(0.5), 1);
      expect(converter.fromJson(0.999), 1);
    });

    test('toJson returns exact integer', () {
      expect(converter.toJson(1999), 1999);
      expect(converter.toJson(0), 0);
    });
  });
}
