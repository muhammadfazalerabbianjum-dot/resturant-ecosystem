// p35 scope B (B-1) — the one-key `theme.depth` preset (AppDepthTokens).
//
// Red→green (Law 2): `AppDepthTokens` / `AppDepthPreset` do not exist yet, so
// this fails to compile first; they are implemented in `app_tokens.dart` and
// attached by `AppTheme.buildTheme` / `buildDarkTheme`.
//
// SAFETY CONTRACT (mirrors the scope-A shape preset):
//   - absent `theme.depth` => elevation 0 (today byte-for-byte; the 5 flat
//     card/tile surfaces stay flat).
//   - unknown style => degrade to 0 (never a crash, never a wrong look).
//   - `soft` / `elevated` => a positive Material elevation, opt-in per client.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  AppDepthTokens depthOf(ThemeData t) => t.extension<AppDepthTokens>()!;

  group('absent depth = today (elevation 3, non-flat default per D-P35-2)', () {
    test('no depth key attaches a soft (3) token', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      expect(depthOf(theme).elevation, 3);
    });
  });

  group('depth preset sets a positive elevation (opt-in)', () {
    test('soft => 3 (M3 elevation Level2)', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'depth': 'soft',
      });
      expect(depthOf(theme).elevation, 3);
    });

    test('elevated => 6', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'depth': 'elevated',
      });
      expect(depthOf(theme).elevation, 6);
    });

    test('flat => 0', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'depth': 'flat',
      });
      expect(depthOf(theme).elevation, 0);
    });
  });

  group('unknown depth degrades to flat (fail-safe)', () {
    test('unknown style keeps elevation 0', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{
        'depth': 'chunky',
      });
      expect(depthOf(theme).elevation, 0);
    });
  });

  group('dark path also carries the token', () {
    test('buildDarkTheme absent => 3 (non-flat default)', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{});
      expect(depthOf(theme).elevation, 3);
    });

    test('buildDarkTheme soft => 3', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{
        'depth': 'soft',
      });
      expect(depthOf(theme).elevation, 3);
    });
  });

  group('AppDepthPreset vocabulary', () {
    test('exposes exactly the curated set', () {
      expect(AppDepthPreset.vocabulary, <String>{'flat', 'soft', 'elevated'});
    });

    test('fromStyle maps known, null for unknown/absent', () {
      expect(AppDepthPreset.fromStyle('elevated'), isNotNull);
      expect(AppDepthPreset.fromStyle('chunky'), isNull);
      expect(AppDepthPreset.fromStyle(null), isNull);
    });
  });

  group('a real component applies the configured depth', () {
    testWidgets('BrandCard reads theme.depth=soft => Material elevation 3', (
      tester,
    ) async {
      final theme = AppTheme.buildTheme(<String, dynamic>{'depth': 'soft'});
      await tester.pumpWidget(
        Theme(
          data: theme,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: BrandCard(child: Text('card')),
          ),
        ),
      );
      expect(find.text('card'), findsOneWidget);
      final material = tester.widget<Material>(find.byType(Material));
      expect(material.elevation, 3);
    });

    testWidgets('BrandCard default (no depth) => Material elevation 3', (
      tester,
    ) async {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      await tester.pumpWidget(
        Theme(
          data: theme,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: BrandCard(child: Text('card')),
          ),
        ),
      );
      expect(find.text('card'), findsOneWidget);
      final material = tester.widget<Material>(find.byType(Material));
      expect(material.elevation, 3);
    });
  });

  group('D-P35-2 B-2: dark surfaces ramp (theme.darkTheme.surfaces)', () {
    test('absent surfaces => dark defaults (byte-for-byte today)', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{});
      final surfaces = theme.extension<AppDarkSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.surface, const Color(0xFF1E1E1E));
      expect(surfaces.surfaceSoft, const Color(0xFF2A2A2A));
      expect(surfaces.surfaceElevated, const Color(0xFF3A3A3A));
      expect(surfaces.foreground, const Color(0xFFFFFFFF));
    });

    test('configured surfaces override dark defaults', () {
      final theme = AppTheme.buildDarkTheme(<String, dynamic>{
        'darkTheme': <String, dynamic>{
          'surfaces': <String, dynamic>{
            'surface': '0xFF0A0A0A',
            'soft': '0xFF1A1A1A',
            'elevated': '0xFF2A2A2A',
          },
        },
      });
      final surfaces = theme.extension<AppDarkSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.surface, const Color(0xFF0A0A0A));
      expect(surfaces.surfaceSoft, const Color(0xFF1A1A1A));
      expect(surfaces.surfaceElevated, const Color(0xFF2A2A2A));
    });

    test('light theme does not attach AppDarkSurfaces', () {
      final theme = AppTheme.buildTheme(const <String, dynamic>{});
      expect(theme.extension<AppDarkSurfaces>(), isNull);
    });
  });

  group('D-P35-2 B-3: dark AA foreground', () {
    test('absent foreground => white default (AA-safe on #121212)', () {
      final theme = AppTheme.buildDarkTheme(const <String, dynamic>{});
      final surfaces = theme.extension<AppDarkSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.foreground, const Color(0xFFFFFFFF));
    });

    test('configured foreground overrides default', () {
      final theme = AppTheme.buildDarkTheme(<String, dynamic>{
        'darkTheme': <String, dynamic>{'foreground': '0xFFEEEEEE'},
      });
      final surfaces = theme.extension<AppDarkSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.foreground, const Color(0xFFEEEEEE));
    });
  });
}
