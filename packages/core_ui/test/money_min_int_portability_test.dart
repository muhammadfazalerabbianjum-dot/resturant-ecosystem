// P2-1a — the min-int guard is a PREDICATE, not a literal.
//
// The literal `-9223372036854775807 - 1` is exact on the VM and not
// representable under dart2js, where the equality was false for every real
// value and therefore silently disabled the T-5 fail-closed render
// (`checkpoints/P2-00.md`). `isMinInt` must be true for exactly one VM value
// and false for everything else — including every value JS can hold.
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The same sentinel, computed at runtime inside the test binary (this file
  // runs on the VM, so the expression is exact).
  final minInt = -9223372036854775807 - 1;

  group('isMinInt', () {
    test('is true for minInt64 and only minInt64', () {
      expect(isMinInt(minInt), isTrue);
      expect(isMinInt(minInt + 1), isFalse);
      expect(isMinInt(minInt + 2), isFalse);
    });

    test('is false for zero and small magnitudes', () {
      for (final v in [0, 1, -1, 2, -2, 99, -99]) {
        expect(isMinInt(v), isFalse, reason: 'value $v');
      }
    });

    test('is false for the ints a JS build can actually hold', () {
      // Every integer a double represents exactly is well inside the 53-bit
      // range, so a web build never trips the guard — and never misfires either.
      const safe = 9007199254740991; // 2^53 - 1
      expect(isMinInt(safe), isFalse);
      expect(isMinInt(-safe), isFalse);
    });
  });

  group('the renderer still fails closed on minInt64', () {
    test('moneyCents renders the placeholder, not fabricated digits', () {
      expect(moneyCents(minInt), kMoneyRenderPlaceholder);
    });

    test('the neighbours of minInt64 render as numbers', () {
      expect(moneyCents(minInt + 1), startsWith('-'));
      expect(moneyCents(minInt + 1), isNot(kMoneyRenderPlaceholder));
    });
  });
}
