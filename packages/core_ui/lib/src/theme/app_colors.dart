import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppColors {
  /// Primary brand color.
  ///
  /// W9.1 (05-P1-A11Y-CONTRAST) Option A: darkened from `#FF6B00` (2.86:1
  /// with white — AA fail) to `#C84F00` (4.59:1 with white — AA pass). Kept
  /// byte-synced with the `theme.colors` block in
  /// `core_app/assets/client_config.json` only — since the sanctioned
  /// Halal Boyz rebrand (operator decision 2026-09-11, COV-2) the shell
  /// carries its own palette in `apps/halal_boyz/assets/client_config.json`,
  /// as asserted by `core_app/test/ui/accessibility_guidelines_test.dart`.
  static const Color primary = Color(0xFFC84F00);

  /// Secondary brand color (reliability/depth)
  static const Color secondary = Color(0xFF1D3557);

  /// Accent color (warmth, friendliness)
  static const Color accent = Color(0xFFF4A261);

  /// Base background color (also used for white overlays)
  static const Color background = Color(0xFFFFFFFF);

  /// Surface color (clean containers/cards)
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text color
  static const Color textPrimary = Color(0xFF1E1E1E);

  /// Secondary/muted text color (replaces Colors.grey).
  ///
  /// W9.1: darkened from `#9E9E9E` (2.68:1 on white — AA fail) to `#757575`
  /// (4.61:1 on white — AA pass).
  static const Color textSecondary = Color(0xFF757575);

  /// Error state color (replaces Colors.red)
  static const Color error = Color(0xFFE53935);

  /// Success state color (replaces Colors.green).
  ///
  /// W9.1: darkened from `#4CAF50` (2.78:1 on white — AA fail) to `#2E7D32`
  /// (5.13:1 on white — AA pass). Note: the master wave's `#388E3C` example
  /// computes to only 4.12:1 on white, below the 4.5:1 requirement, so the
  /// next Material step (Green 800) is used instead.
  static const Color success = Color(0xFF2E7D32);

  /// Warning state color (replaces Colors.amber)
  static const Color warning = Color(0xFFFFC107);

  /// Sold-out / unavailable state color (Q3 semantic state palette).
  ///
  /// 0xFF616161 (graphite): 6.2:1 on white — AA as text AND as a non-text
  /// icon/tint — deliberately distinct from [error] (an unavailable dish is
  /// an availability state, not a system failure) and from [textSecondary]
  /// (muted copy). Config key: `theme.colors.soldOut`.
  static const Color soldOut = Color(0xFF616161);

  /// Transparent color (replaces Colors.transparent)
  static const Color transparent = Color(0x00000000);

  /// Background with 54% opacity (replaces Colors.white54)
  static const Color background54 = Color(0x8AFFFFFF);

  /// Background with 70% opacity (replaces Colors.white70)
  static const Color background70 = Color(0xB3FFFFFF);

  static const Color textPrimary12 = Color(0x1F1E1E1E);
  static const Color textPrimary45 = Color(0x731E1E1E);
  static const Color textPrimary54 = Color(0x8A1E1E1E);

  /// WCAG 2.x relative luminance of [color] (P37 T-1, 05-P1-A11Y-CONTRAST).
  static double relativeLuminance(Color color) {
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

  /// WCAG 2.x contrast ratio between [a] and [b]: 1.0 (identical) .. 21.0.
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The AA-safe foreground (pure white or pure black) for content painted on
  /// [background].
  ///
  /// WHY (P37 T-1): filled brand widgets used a FIXED white — safe only while
  /// every client primary happens to be dark. White-label clients supply any
  /// `theme.colors.primary`, so the foreground must be derived from the fill.
  /// Picking whichever of white/black scores higher guarantees >= 4.586:1 for
  /// EVERY possible background (their crossover), clearing WCAG AA (4.5:1)
  /// unconditionally. Dark brand hues resolve to white — byte-identical to the
  /// shipped golden baselines; light hues flip to black.
  static Color onColorFor(Color background) {
    final white = contrastRatio(const Color(0xFFFFFFFF), background);
    final black = contrastRatio(const Color(0xFF000000), background);
    return white >= black ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  }
}
