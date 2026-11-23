import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:core_ui/src/theme/app_colors.dart';
import 'package:core_ui/src/theme/app_signature_tokens.dart';
import 'package:core_ui/src/theme/app_tokens.dart';
import 'package:core_ui/src/theme/brand_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Psychological Color Palette — ALL colors delegated to AppColors
  // (Law 3: Single Source of Truth — no hardcoded values here).
  static Color get primaryColor => AppColors.primary;
  static Color get secondaryColor =>
      AppColors.secondary; // Instills reliability
  static Color get backgroundColor => AppColors.background; // Clean canvas
  static Color get surfaceColor => AppColors.surface; // Clean container
  static Color get accentColor => AppColors.accent; // Warmth, friendliness
  static Color get successColor => AppColors.success; // Confidence
  static Color get errorColor => AppColors.error; // Immediate attention

  static bool get _isTest {
    if (kIsWeb) return false;
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  static TextTheme _buildSaaSTextTheme(TextTheme base) {
    if (_isTest) {
      // In tests, avoid hitting font network requests which cause timeouts.
      return base.copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'System',
          letterSpacing: -1.0,
          height: 1.1,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: 'System',
          letterSpacing: -0.5,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: base.bodyLarge?.copyWith(fontFamily: 'System', height: 1.5),
        bodyMedium: base.bodyMedium?.copyWith(
          fontFamily: 'System',
          height: 1.5,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontFamily: 'System',
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Tier-1 SaaS geometric typography
    return GoogleFonts.outfitTextTheme(base).copyWith(
      displayLarge: GoogleFonts.outfit(
        textStyle: base.displayLarge,
        letterSpacing: -1.0,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: base.headlineMedium,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.outfit(textStyle: base.bodyLarge, height: 1.5),
      bodyMedium: GoogleFonts.outfit(textStyle: base.bodyMedium, height: 1.5),
      labelLarge: GoogleFonts.montserrat(
        textStyle: base.labelLarge,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w700,
      ), // Buttons
    );
  }

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = primaryColor;
    final background = isDark ? const Color(0xFF121212) : backgroundColor;
    final surface = isDark ? const Color(0xFF1E1E1E) : surfaceColor;

    final baseTheme = ThemeData(brightness: brightness);

    final brand = _brandColorsFor(
      const {},
      primary: primary,
      secondary: secondaryColor,
      error: errorColor,
      background: background,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [brand],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondaryColor,
        surface: surface,
        error: errorColor,
      ),
      scaffoldBackgroundColor: background,
      textTheme: _buildSaaSTextTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        scrolledUnderElevation: 0,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Phase 2.2 Batch 1: config-driven theming ────────────────────────────
  // Builds ThemeData from the `theme` section of the client config
  // (Phase 2.1 schema) instead of hardcoded AppColors. Any missing/empty
  // value falls back to the AppColors single source of truth (Law 3).

  /// Parses a config color string that is either `0xRRGGBB` / `0xAARRGGBB`
  /// or a bare `RRGGBB` hex. Returns [fallback] if unparseable.
  static Color _colorFromConfig(Object? value, Color fallback) {
    final raw = value;
    if (raw is! String) return fallback;
    var hex = raw.trim().replaceFirst('0x', '');
    if (hex.isEmpty) return fallback;
    // Support 6-digit RGB by prefixing opaque alpha.
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  /// Reads `theme.typography` (Phase 2.1 schema) and returns a font family,
  /// preferring the app-level fontFamily override.
  static String? _fontFamilyFrom(Map<String, dynamic> theme) {
    final typography = theme['typography'];
    if (typography is Map) {
      final font = typography['fontFamily'];
      if (font is String && font.isNotEmpty) return font;
    }
    final topLevel = theme['fontFamily'];
    if (topLevel is String && topLevel.isNotEmpty) return topLevel;
    return null;
  }

  // ── RELEASE-1 / W11.3: typography guard (08-P2-2) ───────────────────────
  // A non-`System` fontFamily must be a REGISTERED bundled font (declared
  // under `flutter.fonts` in pubspec.yaml, which the tooling bakes into the
  // built app's `FontManifest.json`). An unregistered family previously
  // degraded to a SILENT fallback; now it records an explicit
  // [fontLoadError] entry and falls back to the built-in type system, so a
  // typo in client_config.json can never silently re-type the whole app.
  static const String systemFontFamily = 'System';

  /// Explicit loadError entry for the typography guard (mirrors
  /// `AppConfig.loadError` semantics): non-null means the last
  /// `buildTheme`/`buildDarkTheme` saw an unregistered fontFamily and fell
  /// back. Cleared on the next build that resolves cleanly.
  static String? fontLoadError;

  /// TOKENS (b10) — the HEADING font family resolved by the last
  /// `buildTheme`/`buildDarkTheme` (after the registered-font guard), or null
  /// when no heading font resolves (default SaaS type system in use).
  /// `theme.typography.headingFont` → fallback `theme.typography.fontFamily`.
  static String? headingFontFamily;

  /// TOKENS (b10) — the BODY font family resolved by the last
  /// `buildTheme`/`buildDarkTheme`, or null. `theme.typography.bodyFont` →
  /// fallback `theme.typography.fontFamily`.
  static String? bodyFontFamily;

  /// Reads one of `theme.typography.{headingFont,bodyFont}` with fallback to
  /// the pre-existing top-level `theme.fontFamily` (TOKENS b10).
  static String? _fontOptionFrom(Map<String, dynamic> theme, String key) {
    final typography = theme['typography'];
    if (typography is Map) {
      final font = typography[key];
      if (font is String && font.isNotEmpty) return font;
    }
    return null;
  }

  static Set<String> _bundledFontFamilies = <String>{};
  static bool _fontManifestLoaded = false;
  static bool _fontManifestFailed = false;

  /// Bundled font families parsed from the built app's `FontManifest.json`
  /// (the build artifact of the pubspec `flutter.fonts` section). Never
  /// includes `System`, which is always available by default.
  static Set<String> get bundledFontFamilies =>
      Set<String>.unmodifiable(_bundledFontFamilies);

  /// Asset key of the app font manifest emitted by the Flutter tooling.
  static const String fontManifestAsset = 'FontManifest.json';

  /// Reads the built app's `FontManifest.json` and records every registered
  /// family in [bundledFontFamilies]. Called once at app boot
  /// (`core_app/lib/app_bootstrap.dart:512`; the generated shell is a W3 handoff). Never
  /// throws: on any failure the registry stays empty and the typography
  /// guard fails CLOSED (unregistered -> loadError + fallback).
  static Future<void> loadBundledFontFamilies({
    Future<String> Function(String assetKey)? readAsset,
  }) async {
    try {
      final loader = readAsset ?? rootBundle.loadString;
      final decoded = jsonDecode(await loader(fontManifestAsset));
      if (decoded is! List) {
        throw const FormatException('FontManifest root must be a JSON list');
      }
      final families = <String>{
        for (final entry in decoded)
          if (entry is Map && entry['family'] is String)
            entry['family'] as String,
      };
      _bundledFontFamilies = families;
      _fontManifestLoaded = true;
      _fontManifestFailed = false;
    } catch (_) {
      _bundledFontFamilies = <String>{};
      _fontManifestLoaded = false;
      _fontManifestFailed = true;
    }
  }

  /// Resolves a configured [family] to the family that may be applied to the
  /// text theme, or null when the built-in type system should be used.
  ///
  /// * `null`/empty/`System` -> built-in typography, no error.
  /// * A registered bundled family -> returned unchanged, no error.
  /// * An unregistered family -> explicit [fontLoadError] entry (never
  ///   silent) and built-in fallback.
  static String? resolveFontFamily(String? family) {
    if (family == null || family.isEmpty || family == systemFontFamily) {
      fontLoadError = null;
      return null;
    }
    if (_bundledFontFamilies.contains(family)) {
      fontLoadError = null;
      return family;
    }
    final manifestState = _fontManifestLoaded
        ? 'registered families: '
              '${_bundledFontFamilies.map((f) => '"$f"').join(', ')}'
        : (_fontManifestFailed
              ? 'the FontManifest.json could not be read'
              : 'the FontManifest.json has not been loaded yet');
    fontLoadError =
        'AppTheme: fontFamily "$family" is not a registered bundled font '
        '($manifestState). Register the font under `flutter.fonts` in '
        'pubspec.yaml — or set typography.fontFamily to "System". Falling '
        'back to the built-in type system.';
    debugPrint(fontLoadError!);
    return null;
  }

  static TextTheme _textThemeFor(
    String? headingFamily,
    String? bodyFamily,
    TextTheme base,
  ) {
    final resolvedHeading = resolveFontFamily(headingFamily);
    // The split resolves BOTH families independently; each call to
    // `resolveFontFamily` overwrites the shared `fontLoadError`, so capture
    // each result and re-join — a bad HEADING must not be masked by a clean
    // BODY (and vice versa). A null family resolves to built-in + clears the
    // error, keeping the "a later clean build clears a previous loadError"
    // contract for single-family/default builds.
    final headingError = fontLoadError;
    final resolvedBody = resolveFontFamily(bodyFamily);
    final bodyError = fontLoadError;
    if (headingError != null && bodyError != null) {
      fontLoadError = '$headingError $bodyError';
    } else {
      fontLoadError = headingError ?? bodyError;
    }
    final textTheme = _buildSaaSTextTheme(base);
    // TOKENS (b10): the typography split resolved by this build, exposed for
    // diagnostics/tests — the resolution (and its guard) runs even where the
    // offline-safe test environment suppresses the application itself.
    headingFontFamily = resolvedHeading;
    bodyFontFamily = resolvedBody;
    // In tests the real bundled families are never loaded, so no family is
    // applied (keeps the suite offline-safe) — the GUARD itself is fully
    // active either way.
    if (_isTest) return textTheme;
    return applyResolvedFamilies(
      textTheme,
      headingFamily: resolvedHeading,
      bodyFamily: resolvedBody,
    );
  }

  /// The ONE typography→family slot table (TOKENS b10): display/headline/title
  /// carry the HEADING family; body/label carry the BODY family.
  ///
  /// Public so the halal_boyz visual-capture harness can render captures with
  /// the app's real bundled fonts (loaded via `FontLoader`) through the exact
  /// production mapping — no second copy of this slot table may exist anywhere
  /// (Law 3: single source of truth).
  static TextTheme applyResolvedFamilies(
    TextTheme base, {
    required String? headingFamily,
    required String? bodyFamily,
  }) {
    TextStyle? withFamily(TextStyle? style, String? family) =>
        (style == null || family == null)
        ? style
        : style.copyWith(fontFamily: family);
    return base.copyWith(
      // Display/headline/title carry the HEADING font.
      displayLarge: withFamily(base.displayLarge, headingFamily),
      displayMedium: withFamily(base.displayMedium, headingFamily),
      displaySmall: withFamily(base.displaySmall, headingFamily),
      headlineLarge: withFamily(base.headlineLarge, headingFamily),
      headlineMedium: withFamily(base.headlineMedium, headingFamily),
      headlineSmall: withFamily(base.headlineSmall, headingFamily),
      titleLarge: withFamily(base.titleLarge, headingFamily),
      titleMedium: withFamily(base.titleMedium, headingFamily),
      titleSmall: withFamily(base.titleSmall, headingFamily),
      // Body/label carry the BODY font.
      bodyLarge: withFamily(base.bodyLarge, bodyFamily),
      bodyMedium: withFamily(base.bodyMedium, bodyFamily),
      bodySmall: withFamily(base.bodySmall, bodyFamily),
      labelLarge: withFamily(base.labelLarge, bodyFamily),
      labelMedium: withFamily(base.labelMedium, bodyFamily),
      labelSmall: withFamily(base.labelSmall, bodyFamily),
    );
  }

  /// Test seam: replaces the parsed registry so tests can exercise both guard
  /// branches deterministically (the test asset bundle has no FontManifest).
  @visibleForTesting
  static void setBundledFontFamiliesForTest(Set<String> families) {
    _bundledFontFamilies = Set<String>.of(families);
    _fontManifestLoaded = true;
    _fontManifestFailed = false;
  }

  /// Test seam: restores the pristine (unloaded) guard state.
  @visibleForTesting
  static void resetFontGuardForTest() {
    _bundledFontFamilies = <String>{};
    _fontManifestLoaded = false;
    _fontManifestFailed = false;
    fontLoadError = null;
  }

  /// Reads `theme.colors` (Phase 2.1 schema) with per-key fallback to
  /// [AppColors].
  static Color _primaryFrom(Map<String, dynamic> theme) =>
      _colorFromConfig(_cfgColor(theme, 'primary'), AppColors.primary);

  /// Builds the [BrandColors] extension carried by the returned ThemeData.
  ///
  /// COLOR-1 (W10.2): built from the SAME config keys the surrounding
  /// ThemeData is built from — `theme.colors.*` for the brand hues and light
  /// neutrals, `theme.darkTheme.*` for the dark neutrals — with per-key
  /// fallback to [AppColors] (Law 3). `primary`/`secondary`/`error`/
  /// `background`/`surface` are the ALREADY-RESOLVED values used in the
  /// ColorScheme/scaffold, so the extension and the ThemeData can never
  /// disagree (single parse, single source of truth).
  static BrandColors _brandColorsFor(
    Map<String, dynamic> theme, {
    required Color primary,
    required Color secondary,
    required Color error,
    required Color background,
    required Color surface,
  }) {
    return BrandColors(
      primary: primary,
      secondary: secondary,
      accent: _colorFromConfig(_cfgColor(theme, 'accent'), AppColors.accent),
      success: _colorFromConfig(_cfgColor(theme, 'success'), AppColors.success),
      warning: _colorFromConfig(_cfgColor(theme, 'warning'), AppColors.warning),
      error: error,
      background: background,
      surface: surface,
      textPrimary: _colorFromConfig(
        _cfgColor(theme, 'textPrimary'),
        AppColors.textPrimary,
      ),
      textSecondary: _colorFromConfig(
        _cfgColor(theme, 'textSecondary'),
        AppColors.textSecondary,
      ),
      textPrimary12: _colorFromConfig(
        _cfgColor(theme, 'textPrimary12'),
        AppColors.textPrimary12,
      ),
      soldOut: _colorFromConfig(_cfgColor(theme, 'soldOut'), AppColors.soldOut),
    );
  }

  static Object? _cfgColor(Map<String, dynamic> theme, String key) {
    final colors = theme['colors'];
    if (colors is! Map) return null;
    return colors[key];
  }

  /// Builds a light [ThemeData] from a `theme` section of the client config.
  ///
  /// If any color is missing/empty, that color falls back to [AppColors]
  /// (Law 3 — single source of truth). This is additive and non-breaking:
  /// callers that pass an empty map get exactly the previous [lightTheme].
  static ThemeData buildTheme(Map<String, dynamic> theme) =>
      _themeFromConfig(Brightness.light, theme);

  /// Builds a dark [ThemeData] from a `theme` section of the client config.
  ///
  /// Honors `theme.darkTheme.background` / `theme.darkTheme.surface` when
  /// present for per-client dark mode.
  static ThemeData buildDarkTheme(Map<String, dynamic> theme) =>
      _themeFromConfig(Brightness.dark, theme);

  static ThemeData _themeFromConfig(
    Brightness brightness,
    Map<String, dynamic> theme,
  ) {
    final isDark = brightness == Brightness.dark;

    final primary = _primaryFrom(theme);

    final dark = theme['darkTheme'];
    Color background;
    Color surface;
    if (dark is Map<String, dynamic>) {
      background = isDark
          ? _colorFromConfig(dark['background'], const Color(0xFF121212))
          : _colorFromConfig(
              _cfgColor(theme, 'background'),
              AppColors.background,
            );
      surface = isDark
          ? _colorFromConfig(dark['surface'], const Color(0xFF1E1E1E))
          : _colorFromConfig(_cfgColor(theme, 'surface'), AppColors.surface);
    } else {
      background = isDark
          ? const Color(0xFF121212)
          : _colorFromConfig(
              _cfgColor(theme, 'background'),
              AppColors.background,
            );
      surface = isDark
          ? const Color(0xFF1E1E1E)
          : _colorFromConfig(_cfgColor(theme, 'surface'), AppColors.surface);
    }

    final secondary = _colorFromConfig(
      _cfgColor(theme, 'secondary'),
      AppColors.secondary,
    );
    final error = _colorFromConfig(_cfgColor(theme, 'error'), AppColors.error);
    final fontFamily = _fontFamilyFrom(theme);
    // TOKENS (b10): typography split — heading/body fonts fall back to the
    // pre-existing single `fontFamily` key, which falls back to the SaaS
    // default (backward-compatible: omitting both keeps today's behavior).
    final headingFamily = _fontOptionFrom(theme, 'headingFont') ?? fontFamily;
    final bodyFamily = _fontOptionFrom(theme, 'bodyFont') ?? fontFamily;

    // ── TOKENS (b10): shape / components / background / animation ──────────
    final shape = _sectionAt(theme, 'shape');
    // TOKENS (p35 V3): the one-key shape preset. Resolves null for an
    // absent/unknown style, so an explicit per-key token (or the pre-token
    // default) still wins — byte-for-byte today when no `style` is set.
    final shapePreset = AppShapePreset.fromStyle(shape?['style']);
    final cardRadius =
        _positiveDoubleFrom(shape, 'cardRadius') ?? shapePreset?.card ?? 16;
    final ctaRadius =
        _positiveDoubleFrom(shape, 'ctaRadius') ?? shapePreset?.cta;
    final smallRadius =
        _positiveDoubleFrom(shape, 'smallRadius') ?? shapePreset?.small;

    final components = _sectionAt(theme, 'components');
    final navBar = _sectionAt(components, 'navigationBar');
    final navBackground = _colorOptFrom(navBar?['background']);
    final navActive = _colorOptFrom(navBar?['activeColor']);

    final input = _sectionAt(components, 'input');
    final inputFill = _colorOptFrom(input?['fillColor']);
    final inputBorder = _colorOptFrom(input?['borderColor']);
    final inputRadius = _positiveDoubleFrom(input, 'radius');
    final chip = _sectionAt(components, 'chip');
    final chipRadius = _positiveDoubleFrom(chip, 'radius');

    final backdropSection = _sectionAt(theme, 'background');
    final backdropColor = _colorOptFrom(backdropSection?['color']);
    final backdropOverlay = _nonEmptyStringFrom(
      backdropSection?['overlayAsset'],
    );
    final animationStyle = _motionStyleFrom(theme['animationStyle']);

    // ── Q1 (signature identity): optional per-client motif ────────────────
    // Absent => null => the AppSignatureTokens extension is never attached
    // and every consumer renders its stock tree (the b10 byte contract).
    // Present => closed-set style, validated at BOTH config gates; an
    // unknown value degrades to "no motif" rather than mispainting.
    final signature = _sectionAt(theme, 'signature');
    final signatureStyle = switch (_nonEmptyStringFrom(signature?['style'])) {
      'rule' => AppSignatureStyle.rule,
      _ => null,
    };

    // ── p35 scope B: one-key depth preset (theme.depth) ──────────────────
    // D-P35-2: non-flat default depth — absent `theme.depth` now resolves to
    // `soft` (elevation 3, M3 Level2) instead of `flat` (0). An explicit
    // `theme.depth` value still overrides; unknown degrades to 0 (fail-safe).
    final rawDepth = theme['depth'];
    final depthElevation = rawDepth == null
        ? 3.0 // absent → non-flat default (soft, M3 Level2)
        : (AppDepthPreset.fromStyle(rawDepth)?.elevation ?? 0.0);
    // present but unknown/invalid → 0 (flat fail-safe, never a wrong look)

    // ── D-P35-2 B-2/B-3: dark surfaces ramp + AA foreground ────────────────
    // Only attached for dark theme; light theme never carries this extension.
    // `theme.darkTheme.surfaces` is a map of surface colors for depth levels;
    // `theme.darkTheme.foreground` is the AA-safe dark foreground.
    // Defaults match today's dark theme byte-for-byte (no config = no change).
    final darkSurfaces = (isDark && dark is Map<String, dynamic>)
        ? AppDarkSurfaces(
            surface: _colorFromConfig(
              (dark['surfaces'] is Map<String, dynamic>)
                  ? dark['surfaces']['surface']
                  : null,
              const Color(0xFF1E1E1E),
            ),
            surfaceSoft: _colorFromConfig(
              (dark['surfaces'] is Map<String, dynamic>)
                  ? dark['surfaces']['soft']
                  : null,
              const Color(0xFF2A2A2A),
            ),
            surfaceElevated: _colorFromConfig(
              (dark['surfaces'] is Map<String, dynamic>)
                  ? dark['surfaces']['elevated']
                  : null,
              const Color(0xFF3A3A3A),
            ),
            foreground: _colorFromConfig(
              dark['foreground'],
              const Color(0xFFFFFFFF),
            ),
          )
        : const AppDarkSurfaces();

    final baseTheme = ThemeData(brightness: brightness);

    final brand = _brandColorsFor(
      theme,
      primary: primary,
      secondary: secondary,
      error: error,
      background: background,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [
        brand,
        const AppSpacing(),
        AppShapeTokens(
          cardRadius: cardRadius,
          ctaRadius: ctaRadius,
          smallRadius: smallRadius,
        ),
        AppDepthTokens(elevation: depthElevation),
        AppMotionTokens.forStyle(animationStyle),
        AppBackdropTokens(overlayAsset: backdropOverlay),
        if (isDark) darkSurfaces,
        if (signatureStyle != null) AppSignatureTokens(style: signatureStyle),
      ],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: backdropColor ?? background,
      textTheme: _textThemeFor(headingFamily, bodyFamily, baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: backdropColor ?? background,
        scrolledUnderElevation: 0,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      // TOKENS (b10): component themes attach ONLY when the corresponding
      // token key is present — an absent key keeps the Material 3 default
      // (today's behavior; acceptance contract 3).
      filledButtonTheme: ctaRadius == null
          ? null
          : FilledButtonThemeData(
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ctaRadius),
                  ),
                ),
              ),
            ),
      outlinedButtonTheme: ctaRadius == null
          ? null
          : OutlinedButtonThemeData(
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ctaRadius),
                  ),
                ),
              ),
            ),
      iconButtonTheme: ctaRadius == null
          ? null
          : IconButtonThemeData(
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ctaRadius),
                  ),
                ),
              ),
            ),
      textButtonTheme: smallRadius == null
          ? null
          : TextButtonThemeData(
              style: ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(smallRadius),
                  ),
                ),
              ),
            ),
      navigationBarTheme: (navBackground == null && navActive == null)
          ? null
          : NavigationBarThemeData(
              backgroundColor: navBackground,
              iconTheme: navActive == null
                  ? null
                  : WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? IconThemeData(color: navActive)
                          : null,
                    ),
            ),
      inputDecorationTheme: inputFill == null && inputBorder == null
          ? null
          : InputDecorationTheme(
              filled: inputFill != null,
              fillColor: inputFill,
              // Borders attach only when a border token (color or radius) is
              // configured; the 4.0 fallback radius = the Material 3 default.
              enabledBorder: inputBorder == null && inputRadius == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(inputRadius ?? 4),
                      borderSide: inputBorder == null
                          ? const BorderSide()
                          : BorderSide(color: inputBorder),
                    ),
              focusedBorder: inputBorder == null && inputRadius == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(inputRadius ?? 4),
                      borderSide: inputBorder == null
                          ? const BorderSide()
                          : BorderSide(color: inputBorder, width: 2),
                    ),
            ),
      chipTheme: chipRadius == null
          ? null
          : ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(chipRadius),
              ),
            ),
    );
  }

  // ── TOKENS (b10): defensive token parsers ────────────────────────────────
  // Same convention as every other config reader in this engine: a malformed
  // OPTIONAL value falls back to the default here, while the format
  // enforcement lives in `ClientConfig.fromMap` / the generator's `validate()`
  // (WL-2: a malformed token fails fast at the schema gate, never silently at
  // runtime).

  /// Reads a nested config section (e.g. `theme.shape`), null when absent.
  static Map<String, dynamic>? _sectionAt(
    Map<String, dynamic>? parent,
    String key,
  ) {
    final value = parent?[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Reads a positive finite number token; null when absent/malformed.
  static double? _positiveDoubleFrom(
    Map<String, dynamic>? section,
    String key,
  ) {
    final value = section?[key];
    if (value is num && value > 0 && value.isFinite) return value.toDouble();
    return null;
  }

  /// Reads an optional hex color token; null when absent/unparseable.
  static Color? _colorOptFrom(Object? value) {
    if (value is! String) return null;
    var hex = value.trim().replaceFirst('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Reads a non-empty string token; null when absent/empty.
  static String? _nonEmptyStringFrom(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Parses `theme.animationStyle` (`full`|`subtle`|`none`); anything else
  /// (including absent) keeps the `full` default — today's shared baseline.
  static AppMotionStyle _motionStyleFrom(Object? value) => switch (value) {
    'subtle' => AppMotionStyle.subtle,
    'none' => AppMotionStyle.none,
    _ => AppMotionStyle.full,
  };
}
