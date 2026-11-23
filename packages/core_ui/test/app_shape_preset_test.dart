// p35 THEME-V2 (V3) — the one-key `theme.shape.style` preset.
//
// Red→green (Law 2): `AppShapePreset` does not exist yet, so this fails to
// compile first; it is implemented in `app_tokens.dart` + merged by
// `AppTheme.buildTheme`. Covers the three `theme.shape` tokens
// (card/cta/small — cards + all buttons, the dominant surfaces); input/chip
// radii stay as their own explicit `theme.components.*.radius` knobs.
//
// SAFETY CONTRACT (the whole point of V3):
//   - absent `theme.shape.style` => today byte-for-byte (16 / null / null).
//   - unknown style => graceful degrade to today (never a crash, never wrong).
//   - an EXPLICIT per-key token (`theme.shape.cardRadius`) overrides the preset.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  AppShapeTokens shapeOf(ThemeData t) => t.extension<AppShapeTokens>()!;

  group('absent style = today byte-for-byte', () {
    test('no shape section keeps the pre-token defaults', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 16);
      expect(shape.ctaRadius, isNull);
      expect(shape.smallRadius, isNull);
      // Button themes stay unattached (ctaRadius/smallRadius null).
      expect(theme.filledButtonTheme.style, isNull);
      expect(theme.textButtonTheme.style, isNull);
    });
  });

  group('style preset sets the three shape tokens', () {
    test('round => card 24, cta 20, small 12 (buttons attach)', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'round'},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 24);
      expect(shape.ctaRadius, 20);
      expect(shape.smallRadius, 12);
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
    });

    test('pill => stadium radii (999)', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'pill'},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 28);
      expect(shape.ctaRadius, 999);
      expect(shape.smallRadius, 999);
    });

    test('sharp => crisp small radii', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'sharp'},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 4);
      expect(shape.ctaRadius, 4);
      expect(shape.smallRadius, 4);
    });

    test('soft => the warm baseline (16/12/8)', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'soft'},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 16);
      expect(shape.ctaRadius, 12);
      expect(shape.smallRadius, 8);
    });
  });

  group('explicit token overrides the preset', () {
    test('style=round + explicit cardRadius=10 => card wins as 10', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'round', 'cardRadius': 10},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 10); // explicit overrides preset
      expect(shape.ctaRadius, 20); // still from preset
      expect(shape.smallRadius, 12); // still from preset
    });
  });

  group('unknown style degrades to today (fail-safe, not fail-crash)', () {
    test('an unknown style keeps the pre-token defaults', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'shape': <String, dynamic>{'style': 'blobby'},
      });
      final shape = shapeOf(theme);
      expect(shape.cardRadius, 16);
      expect(shape.ctaRadius, isNull);
      expect(shape.smallRadius, isNull);
    });
  });

  group('AppShapePreset vocabulary', () {
    test('exposes exactly the curated set', () {
      expect(AppShapePreset.vocabulary, <String>{
        'sharp',
        'soft',
        'round',
        'pill',
      });
    });

    test('fromStyle maps known values, null for unknown/absent', () {
      expect(AppShapePreset.fromStyle('round'), isNotNull);
      expect(AppShapePreset.fromStyle('blobby'), isNull);
      expect(AppShapePreset.fromStyle(null), isNull);
    });
  });
}
