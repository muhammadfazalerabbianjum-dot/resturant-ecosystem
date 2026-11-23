import 'dart:math' as math;

import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/brand_button.dart';
import 'package:core_ui/src/ui/brand_chip.dart';
import 'package:core_ui/src/ui/segment_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P37 T-1 — WCAG 2.x AA contrast proofs (WHITE_LABEL_p37_nine_push.md §3).
///
/// R1: the filled-brand foreground is a FIXED white
/// (`brand_button.dart:77`, `brand_chip.dart:37`, `segment_selector.dart:77`);
/// safe only while every client primary happens to be dark. White-label means
/// any client may ship a light primary — planted here with the palette's own
/// warning amber (`#FFC107`, 1.63:1 with white) as a legal client primary.

double _luminance(Color color) {
  double channel(int value) {
    final c = value / 255.0;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.red) +
      0.7152 * channel(color.green) +
      0.0722 * channel(color.blue);
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// A legal white-label primary that is LIGHT — the witness hue.
const Color _lightPrimary = Color(0xFFFFC107);

BrandColors _lightBrand() => const BrandColors(
  primary: _lightPrimary,
  secondary: Color(0xFF1D3557),
  accent: Color(0xFFF4A261),
  success: Color(0xFF2E7D32),
  warning: Color(0xFFFFC107),
  error: Color(0xFFE53935),
  soldOut: Color(0xFF616161),
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF1E1E1E),
  textSecondary: Color(0xFF757575),
  textPrimary12: Color(0x1F1E1E1E),
);

void main() {
  group(
    'P37 T-1 planted light primary — fg must clear AA 4.5:1 (RED witness)',
    () {
      testWidgets('BrandButton label clears AA on a light client primary', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              primaryColor: _lightPrimary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: _lightPrimary,
                primary: _lightPrimary,
              ),
            ),
            home: Scaffold(
              body: BrandButton(text: 'Place order', onPressed: () {}),
            ),
          ),
        );

        final label = tester.widget<Text>(find.text('Place order'));
        final fg = label.style!.color!;
        expect(
          _contrastRatio(fg, _lightPrimary),
          greaterThanOrEqualTo(4.5),
          reason:
              'BrandButton paints $fg on $_lightPrimary — white-label primaries '
              'are client-supplied and may be light',
        );
      });

      testWidgets('BrandChip selected label clears AA on a light primary', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[_lightBrand()],
            ),
            home: Scaffold(body: BrandChip(label: 'Spicy', selected: true)),
          ),
        );

        final fg = tester.widget<Text>(find.text('Spicy')).style!.color!;
        expect(
          _contrastRatio(fg, _lightPrimary),
          greaterThanOrEqualTo(4.5),
          reason: 'selected chip paints $fg on the injected light primary',
        );
      });

      testWidgets(
        'SegmentSelector selected segment clears AA on light primary',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                extensions: <ThemeExtension<dynamic>>[_lightBrand()],
              ),
              home: Scaffold(
                body: SegmentSelector<int>(
                  segments: const [
                    SegmentOption(value: 1, label: 'Delivery'),
                    SegmentOption(value: 2, label: 'Pickup'),
                  ],
                  selectedValue: 1,
                  onChanged: (_) {},
                ),
              ),
            ),
          );

          final fg = tester.widget<Text>(find.text('Delivery')).style!.color!;
          expect(
            _contrastRatio(fg, _lightPrimary),
            greaterThanOrEqualTo(4.5),
            reason: 'selected segment paints $fg on the injected light primary',
          );
        },
      );
    },
  );

  group('P37 T-1 shipped palettes stay AA and visually unchanged', () {
    testWidgets(
      'BrandButton on the shipped primary keeps white (golden-safe)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrandButton(text: 'Place order', onPressed: () {}),
            ),
          ),
        );

        final fg = tester.widget<Text>(find.text('Place order')).style!.color!;
        // Shipped core primary #C84F00: dark → white is AA (4.59:1) and is what
        // every baseline golden captured — the fix must not move it.
        expect(
          _contrastRatio(fg, const Color(0xFFC84F00)),
          greaterThanOrEqualTo(4.5),
        );
        expect(fg, const Color(0xFFFFFFFF));
      },
    );
  });

  group('P37 T-1 AppColors.onColorFor helper contract', () {
    test('every shipped theme.colors hue resolves an AA foreground', () {
      const shipped = <String, Color>{
        'core primary': Color(0xFFC84F00),
        'halal primary': Color(0xFF900000),
        'core secondary': Color(0xFF1D3557),
        'halal secondary/accent': Color(0xFFFFA500),
        'core accent': Color(0xFFF4A261),
        'core/halal background': Color(0xFFFFFFFF),
        'disabled fill (textSecondary)': Color(0xFF757575),
      };
      shipped.forEach((name, bg) {
        expect(
          AppColors.contrastRatio(AppColors.onColorFor(bg), bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name must clear AA with its resolved foreground',
        );
      });
    });

    test('onColorFor clears AA for EVERY hue (16-step RGB sweep)', () {
      var worst = 21.0;
      Color? worstBg;
      for (var r = 0; r <= 255; r += 15) {
        for (var g = 0; g <= 255; g += 15) {
          for (var b = 0; b <= 255; b += 15) {
            final bg = Color.fromARGB(255, r, g, b);
            final ratio = AppColors.contrastRatio(AppColors.onColorFor(bg), bg);
            if (ratio < worst) {
              worst = ratio;
              worstBg = bg;
            }
          }
        }
      }
      expect(
        worst,
        greaterThanOrEqualTo(4.5),
        reason: 'worst-case background $worstBg at $worst:1',
      );
    });
  });
}
