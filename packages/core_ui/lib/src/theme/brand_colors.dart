import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Per-client brand palette as a [ThemeExtension] (COLOR-1 / W10.2, fixing
/// 08-P0-WL-3).
///
/// [AppColors] is a compile-time constant palette: reading it directly from
/// `core_app/lib` bypasses the per-client `theme.colors` config section, so
/// the first client with a non-default palette would render a mixed-brand UI.
/// This extension is built by `AppTheme.buildTheme`/`AppTheme.buildDarkTheme`
/// from the SAME `theme.colors.*` / `theme.darkTheme.*` config keys the
/// [ThemeData] itself is built from (single parse, single source of truth),
/// so widgets reading [BrandColors.of] always render the configured client
/// palette — for light AND dark brightness.
///
/// Direct `AppColors.*` use outside `packages/core_ui/lib` is banned and
/// enforced by `core_app/test/ui/app_colors_theme_ban_test.dart` (COLOR-1
/// T-1/T-3; `custom_lint` is not a dependency, so the enforceable repo-test
/// mechanism from master W10.1 is used).
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  /// Primary brand color (`theme.colors.primary`).
  final Color primary;

  /// Secondary brand color (`theme.colors.secondary`).
  final Color secondary;

  /// Accent color (`theme.colors.accent`).
  final Color accent;

  /// Success state color (`theme.colors.success`).
  final Color success;

  /// Warning state color (`theme.colors.warning`).
  final Color warning;

  /// Error state color (`theme.colors.error`).
  final Color error;

  /// Sold-out / unavailable state color (`theme.colors.soldOut`).
  final Color soldOut;

  /// Base background color (`theme.colors.background`; dark brightness reads
  /// `theme.darkTheme.background`).
  final Color background;

  /// Surface/container color (`theme.colors.surface`; dark brightness reads
  /// `theme.darkTheme.surface`).
  final Color surface;

  /// Primary text color (`theme.colors.textPrimary`).
  final Color textPrimary;

  /// Secondary/muted text color (`theme.colors.textSecondary`).
  final Color textSecondary;

  /// Primary text color at 12% opacity (`theme.colors.textPrimary12`).
  final Color textPrimary12;

  const BrandColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.soldOut,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPrimary12,
  });

  /// The [AppColors] constant palette verbatim.
  ///
  /// Used in two byte-identical-to-legacy situations: (a) [AppTheme] builds
  /// this for its static light/dark themes (whose non-neutral hues already
  /// delegate to [AppColors]), and (b) [BrandColors.of] falls back to it when
  /// the ambient [ThemeData] was NOT produced by [AppTheme] (e.g. a bare
  /// `MaterialApp()` in a widget test). Case (b) preserves exactly the
  /// pre-COLOR-1 rendering — the palette constants were theme-agnostic
  /// before — without silently crashing screens that render under a foreign
  /// theme. Production themes always carry the extension (both builders in
  /// `app_theme.dart` attach it), so the config palette always wins there.
  const BrandColors.fallback()
    : primary = AppColors.primary,
      secondary = AppColors.secondary,
      accent = AppColors.accent,
      success = AppColors.success,
      warning = AppColors.warning,
      error = AppColors.error,
      soldOut = AppColors.soldOut,
      background = AppColors.background,
      surface = AppColors.surface,
      textPrimary = AppColors.textPrimary,
      textSecondary = AppColors.textSecondary,
      textPrimary12 = AppColors.textPrimary12;

  /// Resolves the ambient brand palette from [context]'s [ThemeData].
  ///
  /// See [BrandColors.fallback] for why a missing extension resolves to the
  /// [AppColors] constants instead of throwing.
  static BrandColors of(BuildContext context) =>
      Theme.of(context).extension<BrandColors>() ??
      const BrandColors.fallback();

  @override
  BrandColors copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? soldOut,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textPrimary12,
  }) {
    return BrandColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      soldOut: soldOut ?? this.soldOut,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textPrimary12: textPrimary12 ?? this.textPrimary12,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      soldOut: Color.lerp(soldOut, other.soldOut, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textPrimary12: Color.lerp(textPrimary12, other.textPrimary12, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrandColors &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.accent == accent &&
        other.success == success &&
        other.warning == warning &&
        other.error == error &&
        other.soldOut == soldOut &&
        other.background == background &&
        other.surface == surface &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textPrimary12 == textPrimary12;
  }

  @override
  int get hashCode => Object.hash(
    primary,
    secondary,
    accent,
    success,
    warning,
    error,
    soldOut,
    background,
    surface,
    textPrimary,
    textSecondary,
    textPrimary12,
  );

  @override
  String toString() =>
      'BrandColors('
      'primary: $primary, secondary: $secondary, accent: $accent, '
      'success: $success, warning: $warning, error: $error, '
      'soldOut: $soldOut, '
      'background: $background, surface: $surface, '
      'textPrimary: $textPrimary, textSecondary: $textSecondary, '
      'textPrimary12: $textPrimary12)';
}
