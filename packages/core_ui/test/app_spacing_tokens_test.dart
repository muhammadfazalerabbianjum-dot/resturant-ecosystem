// p35 THEME-V2 (V2) — the AppSpacing rhythm-scale token.
//
// Red→green (Law 2): `AppSpacing` does not exist yet, so this fails to compile
// first; it is implemented in `app_tokens.dart` + attached by `AppTheme`
// builders. V2 is a CONSTANT scale (not per-client config in this scope) — the
// single spacing rhythm every new component references, replacing ad-hoc inline
// `12/2/6/16` literals. Mirrors the AppSignatureTokens contract test shape.
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  group('AppSpacing contract', () {
    const a = AppSpacing();

    test('exposes the fixed scale steps', () {
      expect(a.xs, 4);
      expect(a.sm, 8);
      expect(a.md, 12);
      expect(a.lg, 16);
      expect(a.xl, 24);
      expect(a.xxl, 32);
    });

    test('copyWith overrides one step, keeps the rest', () {
      final changed = a.copyWith(md: 14);
      expect(changed.md, 14);
      expect(changed.lg, a.lg);
      expect(changed.xs, a.xs);
    });

    test('copyWith with no override equals the original', () {
      expect(a.copyWith(), a);
    });

    test('lerp interpolates each step toward other by t', () {
      const other = AppSpacing(xs: 0, sm: 0, md: 0, lg: 0, xl: 0, xxl: 0);
      final mid = a.lerp(other, 0.5);
      expect(mid.xs, 2); // (4 + 0) * 0.5
      expect(mid.xxl, 16); // (32 + 0) * 0.5
    });

    test('lerp with null other holds the current tokens', () {
      expect(identical(a.lerp(null, 1.0), a), isTrue);
    });

    test('equality + hashCode: same steps equal, foreign not equal', () {
      const b = AppSpacing();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const AppSpacing(md: 13), isFalse);
      expect(a == const Object(), isFalse);
    });
  });

  group('AppSpacing reads from the built theme', () {
    test('buildTheme attaches the scale (default, no config needed)', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      final spacing = theme.extension<AppSpacing>();
      expect(spacing, isNotNull);
      expect(spacing!.xs, 4);
      expect(spacing.xxl, 32);
    });

    test('buildDarkTheme attaches the same scale', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{});
      final spacing = theme.extension<AppSpacing>();
      expect(spacing, isNotNull);
      expect(spacing!.md, 12);
    });
  });
}
