import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:core_ui/src/ui/shapes.dart';
import 'package:flutter/material.dart';

/// Badge tone — four semantic pairs with four DISTINCT (bg, fg) resolutions
/// (UI-1, T-4). Neutral = quiet chrome; the rest map to the brand palette's
/// semantic slots (Law 3 chain: `BrandColors` → `AppColors` fallback).
enum BadgeTone { neutral, positive, warning, negative }

/// Small stadium pill for status labels (counters, states, deltas).
///
/// DRIFT (spec amendment, UI-1): originally specced as `Badge`, but Flutter's
/// material library already exports a Material 3 `Badge` — the collision
/// would break every file importing both `core_ui.dart` and
/// `package:flutter/material.dart` (caught red→green during UI-1). Renamed to
/// [BrandBadge]; the `Brand*` prefix now also disambiguates from SDK widgets.
///
/// All visible text is caller-supplied (L3). Single line, ellipsized — a
/// badge never grows into a paragraph.
class BrandBadge extends StatelessWidget {
  /// The badge label.
  final String label;

  /// The semantic tone (default [BadgeTone.neutral]).
  final BadgeTone tone;

  const BrandBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  /// The documented (background, foreground) pair for [tone].
  static ({Color background, Color foreground}) colorsFor(
    BadgeTone tone,
    BrandColors brand,
  ) => switch (tone) {
    BadgeTone.neutral => (
      background: brand.textPrimary12,
      foreground: brand.textPrimary,
    ),
    // White-on-brand for the AA-passed semantic hues (W9.1 palette).
    BadgeTone.positive => (
      background: brand.success,
      foreground: AppColors.background,
    ),
    // Amber warns best with dark text (contrast on #FFC107).
    BadgeTone.warning => (
      background: brand.warning,
      foreground: brand.textPrimary,
    ),
    BadgeTone.negative => (
      background: brand.error,
      foreground: AppColors.background,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(tone, BrandColors.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BrandShapes.borderPill,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
        ),
      ),
    );
  }
}
