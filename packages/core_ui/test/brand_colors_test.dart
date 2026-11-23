import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

/// COLOR-1 T-2 fixture: a client palette PROVABLY distinct from [AppColors] —
/// every hex differs from every `AppColors` constant, so any leakage of the
/// constant palette into a widget reading [BrandColors] fails these asserts.
const Map<String, Color> kFixtureColors = {
  'primary': Color(0xFF112233),
  'secondary': Color(0xFF223344),
  'accent': Color(0xFF334455),
  'success': Color(0xFF445566),
  'warning': Color(0xFF556677),
  'error': Color(0xFF667788),
  'soldOut': Color(0xFF886677),
  'background': Color(0xFF778899),
  'surface': Color(0xFF8899AA),
  'textPrimary': Color(0xFF99AABB),
  'textSecondary': Color(0xFFAABBCC),
  'textPrimary12': Color(0x1F99AABB),
};

/// The same fixture in the Phase 2.1 `theme` config section shape.
const Map<String, dynamic> kFixtureTheme = {
  'colors': {
    'primary': '0xFF112233',
    'secondary': '0xFF223344',
    'accent': '0xFF334455',
    'success': '0xFF445566',
    'warning': '0xFF556677',
    'error': '0xFF667788',
    'soldOut': '0xFF886677',
    'background': '0xFF778899',
    'surface': '0xFF8899AA',
    'textPrimary': '0xFF99AABB',
    'textSecondary': '0xFFAABBCC',
    'textPrimary12': '0x1F99AABB',
  },
  'darkTheme': {'background': '0xFF101010', 'surface': '0xFF202020'},
};

void main() {
  group('BrandColors — config-driven ThemeExtension (COLOR-1 / W10.2)', () {
    test('AppTheme.buildTheme carries the full fixture palette (light)', () {
      final brand = AppTheme.buildTheme(kFixtureTheme).extension<BrandColors>();
      expect(brand, isNotNull);
      for (final entry in kFixtureColors.entries) {
        expect(
          _field(brand!, entry.key),
          entry.value,
          reason: 'extension.${entry.key} must equal the config fixture hex',
        );
      }
    });

    test(
      'AppTheme.buildDarkTheme: brand hues from colors, neutrals from darkTheme',
      () {
        final brand = AppTheme.buildDarkTheme(
          kFixtureTheme,
        ).extension<BrandColors>();
        expect(brand, isNotNull);
        // Dark neutrals come from the `darkTheme` keys (same keys the
        // ThemeData scaffold/surface use).
        expect(brand!.background, const Color(0xFF101010));
        expect(brand.surface, const Color(0xFF202020));
        // Brand hues are brightness-invariant (same config keys, light+dark).
        expect(brand.primary, kFixtureColors['primary']);
        expect(brand.success, kFixtureColors['success']);
        expect(brand.textPrimary, kFixtureColors['textPrimary']);
      },
    );

    test('partial config falls back per key to AppColors (non-breaking)', () {
      final brand = AppTheme.buildTheme(const {
        'colors': {'primary': '0xFF112233'},
      }).extension<BrandColors>();
      expect(brand!.primary, const Color(0xFF112233));
      expect(brand.accent, AppColors.accent);
      expect(brand.success, AppColors.success);
      expect(brand.textSecondary, AppColors.textSecondary);
    });

    test('empty config resolves to the AppColors constants', () {
      final brand = AppTheme.buildTheme(const {}).extension<BrandColors>();
      expect(brand, const BrandColors.fallback());
      // The static legacy themes go through the same path.
      expect(
        AppTheme.lightTheme.extension<BrandColors>(),
        const BrandColors.fallback(),
      );
      final dark = AppTheme.darkTheme.extension<BrandColors>();
      expect(dark!.background, const Color(0xFF121212));
      expect(dark.surface, const Color(0xFF1E1E1E));
      expect(dark.primary, AppColors.primary);
    });

    testWidgets(
      'widget probe renders the FIXTURE palette — zero AppColors leakage',
      (tester) async {
        late BrandColors probed;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(kFixtureTheme),
            home: Builder(
              builder: (context) {
                probed = BrandColors.of(context);
                return ColoredBox(
                  key: const Key('probe'),
                  color: probed.background,
                  child: Text(
                    'probe',
                    style: TextStyle(color: probed.textSecondary),
                  ),
                );
              },
            ),
          ),
        );

        expect(probed, isNot(const BrandColors.fallback()));
        for (final entry in kFixtureColors.entries) {
          expect(
            _field(probed, entry.key),
            entry.value,
            reason:
                'widget probe must resolve the config fixture color '
                '${entry.key}, never the AppColors constant',
          );
        }
        // Explicit zero-leakage proof on the brand-defining slots.
        expect(probed.primary, isNot(AppColors.primary));
        expect(probed.background, isNot(AppColors.background));
        expect(probed.textSecondary, isNot(AppColors.textSecondary));
      },
    );

    testWidgets(
      'foreign ThemeData (no extension) resolves the AppColors fallback — '
      'legacy byte-identity, no crash',
      (tester) async {
        late BrandColors probed;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                probed = BrandColors.of(context);
                return ColoredBox(
                  color: probed.background,
                  child: const SizedBox.shrink(),
                );
              },
            ),
          ),
        );
        expect(probed, const BrandColors.fallback());
        expect(probed.primary, AppColors.primary);
        expect(probed.background, AppColors.background);
      },
    );

    test('ThemeExtension contract: copyWith/lerp/==/hashCode', () {
      const a = BrandColors.fallback();
      final b = AppTheme.buildTheme(kFixtureTheme).extension<BrandColors>()!;

      expect(a, a.copyWith());
      expect(
        a.copyWith(primary: const Color(0xFF010203)).primary,
        const Color(0xFF010203),
      );
      expect(a == b, isFalse);
      expect(a.hashCode, a.copyWith().hashCode);

      expect(a.lerp(null, 0.5), a);
      expect(a.lerp(b, 1.0), b);
      expect(a.lerp(b, 0.5).primary, Color.lerp(a.primary, b.primary, 0.5));
    });
  });
}

/// Reads a [BrandColors] field by the fixture's key name.
Color _field(BrandColors brand, String key) => switch (key) {
  'primary' => brand.primary,
  'secondary' => brand.secondary,
  'accent' => brand.accent,
  'success' => brand.success,
  'warning' => brand.warning,
  'error' => brand.error,
  'soldOut' => brand.soldOut,
  'background' => brand.background,
  'surface' => brand.surface,
  'textPrimary' => brand.textPrimary,
  'textSecondary' => brand.textSecondary,
  'textPrimary12' => brand.textPrimary12,
  _ => throw ArgumentError('unknown BrandColors field: $key'),
};
