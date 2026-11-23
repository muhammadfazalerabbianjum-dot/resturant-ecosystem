import 'package:flutter/material.dart';

/// TOKENS (WHITE_LABEL_b10_tokens.md) — the per-client design-token surface.
///
/// Every token class here is a [ThemeExtension] built by
/// `AppTheme.buildTheme`/`AppTheme.buildDarkTheme` from the SAME `theme`
/// section of the client config the surrounding [ThemeData] is built from
/// (the COLOR-1/`BrandColors` pattern: single parse, single source of truth).
/// Config vocabulary (validated fail-closed by `ClientConfig.fromMap` /
/// the generator's `validate()` — WL-2: the validator validates what the
/// theme engine reads):
///
/// - `theme.shape.{cardRadius,ctaRadius,smallRadius}`   → [AppShapeTokens]
/// - `theme.animationStyle` (`full`|`subtle`|`none`)    → [AppMotionTokens]
/// - `theme.background.{color,overlayAsset}`            → [AppBackdropTokens]
///
/// DEFAULTS = today's behavior (acceptance contract 3): a config that sets
/// none of these keys gets byte-for-byte the pre-token ThemeData surfaces
/// (card radius 16, Material 3 component defaults, 300 ms / `Curves.easeOut`
/// page motion — the shared baseline `FadeSlideTransitionPage` already uses).
/// Component themes (`NavigationBarThemeData`, `InputDecorationTheme`,
/// `ChipThemeData`, button themes) are only attached to [ThemeData] when the
/// corresponding token key is present — an absent key means "Material 3
/// default", exactly as before this batch.

/// Shape tokens (`theme.shape.*`).
@immutable
class AppShapeTokens extends ThemeExtension<AppShapeTokens> {
  /// Card corner radius (`theme.shape.cardRadius`). Defaults to 16 — the
  /// hardcoded `CardThemeData` radius used before tokens existed.
  final double cardRadius;

  /// CTA button corner radius (`theme.shape.ctaRadius`). `null` = Material 3
  /// default (today). A large value (e.g. 100) renders the stadium/pill CTA
  /// look demanded by client UI specs.
  final double? ctaRadius;

  /// Compact-button corner radius (`theme.shape.smallRadius`). `null` =
  /// Material 3 default (today).
  final double? smallRadius;

  const AppShapeTokens({
    this.cardRadius = 16,
    this.ctaRadius,
    this.smallRadius,
  });

  @override
  AppShapeTokens copyWith({
    double? cardRadius,
    double? ctaRadius,
    double? smallRadius,
  }) => AppShapeTokens(
    cardRadius: cardRadius ?? this.cardRadius,
    ctaRadius: ctaRadius ?? this.ctaRadius,
    smallRadius: smallRadius ?? this.smallRadius,
  );

  @override
  AppShapeTokens lerp(AppShapeTokens? other, double t) {
    if (other == null) return this;
    return AppShapeTokens(
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      ctaRadius: _lerpNullableDouble(ctaRadius, other.ctaRadius, t),
      smallRadius: _lerpNullableDouble(smallRadius, other.smallRadius, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppShapeTokens &&
      other.cardRadius == cardRadius &&
      other.ctaRadius == ctaRadius &&
      other.smallRadius == smallRadius;

  @override
  int get hashCode => Object.hash(cardRadius, ctaRadius, smallRadius);
}

/// Spacing rhythm-scale token (p35 THEME-V2 V2).
///
/// The single spacing scale every new component references, replacing ad-hoc
/// inline literals (`12`/`2`/`6`/`16`). A CONSTANT scale in this scope (not
/// per-client config): attached to the theme by [AppTheme] so widgets read
/// `AppSpacing.of(context)` for padding/gaps. Legacy components keep their
/// inline values until the golden-gated migration (p35-B.1).
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  /// 4 — hairline gaps (icon↔label, tight stacks).
  final double xs;

  /// 8 — small gaps (chips, compact rows).
  final double sm;

  /// 12 — default inner padding (menu tiles, list rows).
  final double md;

  /// 16 — standard padding (cards, screens).
  final double lg;

  /// 24 — section separation.
  final double xl;

  /// 32 — large structural spacing.
  final double xxl;

  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  /// Resolves the ambient spacing scale from [context]'s [ThemeData]; falls back
  /// to the constant default when the extension is absent (e.g. a bare
  /// `MaterialApp()` in a widget test) — never throws.
  static AppSpacing of(BuildContext context) =>
      Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) => AppSpacing(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
  );

  @override
  AppSpacing lerp(AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      xs: _lerpDouble(xs, other.xs, t),
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      xl: _lerpDouble(xl, other.xl, t),
      xxl: _lerpDouble(xxl, other.xxl, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSpacing &&
      other.xs == xs &&
      other.sm == sm &&
      other.md == md &&
      other.lg == lg &&
      other.xl == xl &&
      other.xxl == xxl;

  @override
  int get hashCode => Object.hash(xs, sm, md, lg, xl, xxl);
}

/// One-key shape preset (p35 THEME-V2 V3) — `theme.shape.style`.
///
/// A curated form-language that sets the three `theme.shape` radii (card/cta/
/// small — cards + all buttons) together. An EXPLICIT per-key token
/// (`theme.shape.cardRadius` …) always overrides the preset; an absent/unknown
/// style resolves to `null` here so the theme keeps today's byte-for-byte
/// defaults (graceful degrade — never a crash, never a wrong look). The
/// generator's `validate()` fails CLOSED on an unknown style so a typo never
/// ships. Input/chip radii are separate `theme.components.*` knobs (not in the
/// preset) to keep each config section's semantics clean.
@immutable
class AppShapePreset {
  /// Card corner radius for this preset.
  final double card;

  /// CTA button corner radius for this preset.
  final double cta;

  /// Compact/text button corner radius for this preset.
  final double small;

  const AppShapePreset({
    required this.card,
    required this.cta,
    required this.small,
  });

  /// The closed set of allowed `theme.shape.style` values. Mirrored by the
  /// generator's `validate()` and pinned equal by the schema-identity test.
  static const Set<String> vocabulary = <String>{
    'sharp',
    'soft',
    'round',
    'pill',
  };

  /// Resolves a preset from a raw `theme.shape.style` value; `null` for an
  /// absent or unknown value (caller keeps the pre-token default).
  static AppShapePreset? fromStyle(Object? style) => switch (style) {
    'sharp' => const AppShapePreset(card: 4, cta: 4, small: 4),
    'soft' => const AppShapePreset(card: 16, cta: 12, small: 8),
    'round' => const AppShapePreset(card: 24, cta: 20, small: 12),
    'pill' => const AppShapePreset(card: 28, cta: 999, small: 999),
    _ => null,
  };
}

/// One-key depth preset (p35 scope B) — `theme.depth`.
///
/// A per-client hierarchy level for the flat card/tile surfaces. `flat` = today
/// (elevation 0, the shipped default), `soft` / `elevated` opt into Material
/// depth. An absent or unknown style resolves to `null` here so the theme keeps
/// today's byte-for-byte flat surfaces (graceful degrade — never a crash, never
/// a wrong look). The generator's `validate()` fails CLOSED on an unknown value
/// so a typo never ships. Input/chip radii and shape stay their own knobs.
@immutable
class AppDepthPreset {
  /// Material elevation for this depth level (0 = flat = today).
  final double elevation;

  const AppDepthPreset({required this.elevation});

  /// The closed set of allowed `theme.depth` values. Mirrored by the
  /// generator's `validate()` and pinned equal by the schema-identity test.
  static const Set<String> vocabulary = <String>{'flat', 'soft', 'elevated'};

  /// Resolves a preset from a raw `theme.depth` value; `null` for an absent or
  /// unknown value (caller keeps the flat default).
  // M3-exact ladder: flat=Level0 (0), soft=Level2 (3), elevated=Level3 (6) —
  // the three rungs snap to the AOSP ElevationTokens values so every client's
  // depth hierarchy matches Material 3 out of the box.
  static AppDepthPreset? fromStyle(Object? style) => switch (style) {
    'flat' => const AppDepthPreset(elevation: 0),
    'soft' => const AppDepthPreset(elevation: 3),
    'elevated' => const AppDepthPreset(elevation: 6),
    _ => null,
  };
}

/// The resolved depth [ThemeExtension] (p35 scope B). Default `flat` (0) keeps
/// every card/tile surface exactly as shipped; a configured `soft` / `elevated`
/// lifts them. Components read `Theme.of(context).extension<AppDepthTokens>()`
/// with a `?? 0` fallback, so the stock (no-config) theme — which never attaches
/// this extension — still renders flat, byte-for-byte.
@immutable
class AppDepthTokens extends ThemeExtension<AppDepthTokens> {
  const AppDepthTokens({this.elevation = 0});

  /// Material elevation applied to the flat surfaces (0 = today).
  final double elevation;

  static const AppDepthTokens flat = AppDepthTokens(elevation: 0);

  @override
  AppDepthTokens copyWith({double? elevation}) =>
      AppDepthTokens(elevation: elevation ?? this.elevation);

  @override
  AppDepthTokens lerp(covariant AppDepthTokens? other, double t) {
    if (other == null) return this;
    return AppDepthTokens(
      elevation: _lerpDouble(elevation, other.elevation, t),
    );
  }
}

/// Dark-mode surface ramp + AA foreground (p35 scope B, D-P35-2 B-2/B-3).
///
/// Read from `theme.darkTheme.{surfaces,foreground}` in
/// `AppTheme._themeFromConfig`. Defaults match today's dark theme
/// (`#121212` background / `#1E1E1E` surface) byte-for-byte so no config
/// means zero visual change. A configured surface ramp lets a client author
/// multi-level dark depth (flat / soft / elevated) matched to
/// [AppDepthTokens.elevation].
///
/// - `theme.darkTheme.surfaces.surface`   → elevation 0 (flat) surface color
/// - `theme.darkTheme.surfaces.soft`      → elevation 3 (soft) surface color
/// - `theme.darkTheme.surfaces.elevated`  → elevation 6 (elevated) surface color
/// - `theme.darkTheme.foreground`         → dark-mode AA-safe foreground color
@immutable
class AppDarkSurfaces extends ThemeExtension<AppDarkSurfaces> {
  /// Base surface (elevation 0 / flat depth).
  final Color surface;

  /// Surface for soft depth (elevation 3).
  final Color surfaceSoft;

  /// Surface for elevated depth (elevation 6).
  final Color surfaceElevated;

  /// Foreground color for dark mode (B-3: AA guard against arbitrary client hues).
  final Color foreground;

  const AppDarkSurfaces({
    this.surface = const Color(0xFF1E1E1E),
    this.surfaceSoft = const Color(0xFF2A2A2A),
    this.surfaceElevated = const Color(0xFF3A3A3A),
    this.foreground = const Color(0xFFFFFFFF),
  });

  @override
  AppDarkSurfaces copyWith({
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceElevated,
    Color? foreground,
  }) => AppDarkSurfaces(
    surface: surface ?? this.surface,
    surfaceSoft: surfaceSoft ?? this.surfaceSoft,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    foreground: foreground ?? this.foreground,
  );

  @override
  AppDarkSurfaces lerp(covariant AppDarkSurfaces? other, double t) {
    if (other == null) return this;
    return AppDarkSurfaces(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppDarkSurfaces &&
      other.surface == surface &&
      other.surfaceSoft == surfaceSoft &&
      other.surfaceElevated == surfaceElevated &&
      other.foreground == foreground;

  @override
  int get hashCode =>
      Object.hash(surface, surfaceSoft, surfaceElevated, foreground);
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

double? _lerpNullableDouble(double? a, double? b, double t) =>
    (a == null || b == null) ? (t < 0.5 ? a : b) : _lerpDouble(a, b, t);

Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: _lerpDouble(
    a.inMicroseconds.toDouble(),
    b.inMicroseconds.toDouble(),
    t,
  ).round(),
);

/// Motion intensity (`theme.animationStyle`).
enum AppMotionStyle { full, subtle, none }

/// Motion tokens (`theme.animationStyle` → shared durations/curves).
@immutable
class AppMotionTokens extends ThemeExtension<AppMotionTokens> {
  /// The configured intensity.
  final AppMotionStyle style;

  /// Fast feedback (e.g. hover/press ticks).
  final Duration fast;

  /// Standard UI motion (page transitions). The `full` value equals the
  /// shared baseline `FadeSlideTransitionPage` already uses (300 ms).
  final Duration standard;

  /// Slow, cinematic motion (celebrations, large reveals).
  final Duration slow;

  /// The shared easing curve.
  final Curve curve;

  const AppMotionTokens({
    this.style = AppMotionStyle.full,
    this.fast = const Duration(milliseconds: 200),
    this.standard = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.curve = Curves.easeOut,
  });

  /// The preset for [style]: `full` = today's shared baseline,
  /// `subtle` = shorter/gentler, `none` = instant (zero durations).
  factory AppMotionTokens.forStyle(AppMotionStyle style) => switch (style) {
    AppMotionStyle.full => const AppMotionTokens(),
    AppMotionStyle.subtle => const AppMotionTokens(
      style: AppMotionStyle.subtle,
      fast: Duration(milliseconds: 120),
      standard: Duration(milliseconds: 200),
      slow: Duration(milliseconds: 300),
    ),
    AppMotionStyle.none => const AppMotionTokens(
      style: AppMotionStyle.none,
      fast: Duration.zero,
      standard: Duration.zero,
      slow: Duration.zero,
      curve: Curves.linear,
    ),
  };

  @override
  AppMotionTokens copyWith({
    AppMotionStyle? style,
    Duration? fast,
    Duration? standard,
    Duration? slow,
    Curve? curve,
  }) => AppMotionTokens(
    style: style ?? this.style,
    fast: fast ?? this.fast,
    standard: standard ?? this.standard,
    slow: slow ?? this.slow,
    curve: curve ?? this.curve,
  );

  @override
  AppMotionTokens lerp(AppMotionTokens? other, double t) {
    if (other == null) return this;
    return AppMotionTokens(
      style: t < 0.5 ? style : other.style,
      fast: _lerpDuration(fast, other.fast, t),
      standard: _lerpDuration(standard, other.standard, t),
      slow: _lerpDuration(slow, other.slow, t),
      curve: t < 0.5 ? curve : other.curve,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppMotionTokens &&
      other.style == style &&
      other.fast == fast &&
      other.standard == standard &&
      other.slow == slow &&
      other.curve == curve;

  @override
  int get hashCode => Object.hash(style, fast, standard, slow, curve);
}

/// Backdrop tokens (`theme.background.{color,overlayAsset}`).
///
/// `background.color` is consumed directly as the scaffold background by
/// `AppTheme.buildTheme`; the decorative [overlayAsset] (e.g. a faded city
/// map) is carried here and rendered by [ScaffoldBackground].
@immutable
class AppBackdropTokens extends ThemeExtension<AppBackdropTokens> {
  /// Decorative overlay asset path (`theme.background.overlayAsset`), e.g.
  /// `assets/images/city_map.png`. `null` = no overlay (today). The ASSET
  /// itself is operator-supplied art — this batch builds the mechanism.
  final String? overlayAsset;

  const AppBackdropTokens({this.overlayAsset});

  @override
  AppBackdropTokens copyWith({String? overlayAsset}) =>
      AppBackdropTokens(overlayAsset: overlayAsset ?? this.overlayAsset);

  @override
  AppBackdropTokens lerp(AppBackdropTokens? other, double t) {
    if (other == null) return this;
    return AppBackdropTokens(
      overlayAsset: t < 0.5 ? overlayAsset : other.overlayAsset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppBackdropTokens && other.overlayAsset == overlayAsset;

  @override
  int get hashCode => overlayAsset.hashCode;
}

/// Renders the client's decorative scaffold background (the faded city-map
/// overlay demanded by client UI specs) beneath [child].
///
/// Reads [AppBackdropTokens] from the ambient [Theme] unless [overlayAsset]
/// is passed explicitly. With no overlay configured this degrades to a plain
/// scaffold-colored box — zero visual change (acceptance contract 3). The
/// overlay image is decorative: a missing/corrupt asset degrades to no
/// overlay via [errorBuilder] (cosmetic layer, never the content).
class ScaffoldBackground extends StatelessWidget {
  const ScaffoldBackground({super.key, this.overlayAsset, this.child});

  /// Explicit overlay asset override; defaults to the theme's
  /// [AppBackdropTokens.overlayAsset].
  final String? overlayAsset;

  /// The screen content rendered above the decorative layer.
  final Widget? child;

  /// Fixed decorative intensity — the mechanism token, not artwork tuning.
  static const double overlayOpacity = 0.08;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backdrop =
        theme.extension<AppBackdropTokens>() ?? const AppBackdropTokens();
    final asset = overlayAsset ?? backdrop.overlayAsset;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: asset == null
          ? (child ?? const SizedBox.shrink())
          : Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: overlayOpacity,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                if (child != null) child!,
              ],
            ),
    );
  }
}
