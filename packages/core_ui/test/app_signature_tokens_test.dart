// p31 coverage-floor red→green: `lib/src/theme/app_signature_tokens.dart`
// is a NEW file (Q1 signature identity, p30), so the b7 fleet rule demands
// 100 % line coverage — the widget tests only exercised the present path.
// This pins the token contract itself: constructor, copyWith, the discrete
// lerp (both sides of the t < 0.5 swap plus the null-other hold), equality,
// hashCode and toString.
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  group('AppSignatureTokens contract', () {
    const a = AppSignatureTokens(style: AppSignatureStyle.rule);
    const b = AppSignatureTokens(style: AppSignatureStyle.rule);

    test('constructor exposes the style it was built with', () {
      expect(a.style, AppSignatureStyle.rule);
      expect(b.style, AppSignatureStyle.rule);
    });

    test('copyWith keeps the style when no override is given', () {
      final same = a.copyWith();
      expect(same.style, AppSignatureStyle.rule);
      expect(same, a);

      final explicit = a.copyWith(style: AppSignatureStyle.rule);
      expect(explicit.style, AppSignatureStyle.rule);
      expect(explicit, a);
    });

    test('lerp holds this below 0.5, swaps to other at/above 0.5', () {
      expect(identical(a.lerp(b, 0.0), a), isTrue);
      expect(identical(a.lerp(b, 0.49), a), isTrue);
      expect(identical(a.lerp(b, 0.5), b), isTrue);
      expect(identical(a.lerp(b, 1.0), b), isTrue);
    });

    test('lerp with a null other holds the current tokens', () {
      expect(identical(a.lerp(null, 1.0), a), isTrue);
    });

    test('equality: same style equal, foreign operand not equal', () {
      expect(a, b);
      expect(a == const Object(), isFalse);
      expect(b == const Object(), isFalse);
    });

    test('hashCode follows the style', () {
      expect(a.hashCode, AppSignatureStyle.rule.hashCode);
      expect(a.hashCode, b.hashCode);
    });

    test('toString names the type and style', () {
      expect(a.toString(), 'AppSignatureTokens(style: AppSignatureStyle.rule)');
    });
  });

  test('AppSignatureStyle closed set is exactly {rule}', () {
    expect(AppSignatureStyle.values, [AppSignatureStyle.rule]);
  });
}
