import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'client_config.dart';
import 'screen_variants.dart';

/// Safe accessor for dotenv values that handles uninitialized state.
/// Returns [fallback] if dotenv has not been loaded yet.
String _env(String key, String fallback) {
  try {
    return dotenv.env[key] ?? fallback;
  } catch (_) {
    // dotenv not yet initialized - return fallback
    return fallback;
  }
}

/// Compile-time --dart-define query for [key] (p34 §0-3a).
///
/// A `String.fromEnvironment` query resolves ONLY from a literal name at
/// compile time — a runtime `key` argument silently yields '' for every value,
/// so a shared helper cannot take the key as a parameter. Each supported key
/// gets its own literal case; an unknown key returns '' (fail-closed, never a
/// fabricated default).
String _defineEnv(String key) => switch (key) {
  'FIREBASE_PROJECT_ID' => const String.fromEnvironment('FIREBASE_PROJECT_ID'),
  _ => '',
};

/// App-level configuration loader (Law 3: Single Source of Truth).
///
/// Phase 2.2 Batch 1: reads the client config file ([assetPath]) bundled as an
/// asset in the app (`assets/client_config.json`, see `core_app/pubspec.yaml`).
///
/// Layering (lowest → highest precedence):
///   1. In-code defaults (below) — safe production-like values.
///   2. dotenv (`.env`, loaded in `main()` before `loadConfig()`) — real
///      per-environment identity/backend values.
///   3. `assets/client_config.json` (Phase 2.1 schema) — per-client branding.
///
/// A JSON value only wins when it is present AND non-empty. Empty template
/// placeholders (e.g. `firebase.projectId: ""`) never clobber the real dotenv
/// value `FIREBASE_PROJECT_ID=resturants-8547d`.
///
/// Design note: this intentionally lives in the app layer, NOT in
/// `packages/core`. The `core` package is a pure-logic package with no
/// `flutter: assets:` section (Law 43 — Core must never depend on app-specific
/// configuration), and `rootBundle` is a Flutter services API whose assets are
/// declared/owned by the app package.
class AppConfig {
  AppConfig._();

  /// Asset path for the client config file. Flutter bundles this at build time.
  static const String assetPath = 'assets/client_config.json';

  // ── In-code defaults (layer 1) ────────────────────────────────────────────
  static const String _kDefaultAppName = 'Carnama';
  static const String _kDefaultBundleId = 'com.carnama.labs';
  static const String _kDefaultFcmDescription = 'Notifications for your orders';
  static const String _kDefaultCloudinaryPreset = 'carnama_unsigned';
  static const String _kDefaultCloudinaryCloudName = 'dcqf9qpsq';

  // ── Resolved values (layers 1+2+3) ────────────────────────────────────────
  static String _appName = _kDefaultAppName;
  static String _bundleId = _kDefaultBundleId;
  static String _storeAndroidUrl = '';
  static String _storeIosUrl = '';
  static String _fcmChannelDescription = _kDefaultFcmDescription;
  static String _cloudinaryUploadPreset = _kDefaultCloudinaryPreset;
  static String _cloudinaryCloudName = _kDefaultCloudinaryCloudName;
  static String _firebaseProjectId = '';
  static String _firebaseAndroidAppId = '';
  static String _firebaseIosAppId = '';
  static String _firebaseMessagingSenderId = '';
  static String _firebaseIosClientId = '';
  static String _kitchenLanEndpoint = '';

  // ── currency (p37 T-3: `currency` block = config seed default) ───────────
  static String _currencyCode = '';
  static String _currencySymbol = '';

  // ── branches (Phase 2.2: per-client default branch) ──────────────────────
  static String _defaultBranchId = '';

  // ── Theme (Phase 2.1 schema: `theme` section) ────────────────────────────
  static ThemeData _themeData = AppTheme.lightTheme;
  static ThemeData _darkThemeData = AppTheme.darkTheme;

  // ── TOKENS (b10): `theme.background.overlayAsset` ────────────────────────
  static String _scaffoldOverlayAsset = '';

  // Law 3: the confetti palette as NAMED constants. Each declaration line
  // carries `const` (the guard's documented exemption); list sites reference
  // the names, so no color literal is ever spelled at a use site.
  static const Color _kConfettiRed = Color(0xFFE63946);
  static const Color _kConfettiNavy = Color(0xFF1D3557);
  static const Color _kConfettiAmber = Color(0xFFF4A261);
  static const Color _kConfettiTeal = Color(0xFF2A9D8F);

  static List<Color> _confettiColors = const [
    _kConfettiRed,
    _kConfettiNavy,
    _kConfettiAmber,
    _kConfettiTeal,
  ];

  // ── Feature flags (Phase 2.1 schema: `features.flags`) ───────────────────
  static Map<String, bool> _featureFlags = const {};
  static bool _featureFlagDefault = false;

  // ── Navigation (Phase 2.1 schema: `navigation` + `screens`) ──────────────
  static String _navigationEntryPoint = '/splash';
  static List<String> _navigationTabs = const [];
  static List<String> _navigationHiddenRoutes = const [];
  static Map<String, String> _navigationRoutes = const {};
  static List<Map<String, dynamic>> _screens = const [];

  // ── UI-9 (p19): delivery-platform adapter rows (`deliveryPlatforms`) ──────
  // Raw rows as parsed. The W6.5 gate (`ClientConfig.fromMap` →
  // `DeliveryPlatforms.validatePlatforms`) ran BEFORE this block, so an
  // invalid row never reaches here; an absent section stays empty = every
  // adapter inert (L3).
  static List<Map<String, dynamic>> _deliveryPlatforms = const [];

  static bool _loaded = false;
  static bool _loadFailed = false;
  static String? _loadError;

  /// Typed REQUIRED-field schema violation from the last load (W6.5), or null
  /// when the config loaded and validated cleanly (or did not parse at all).
  static ConfigException? _schemaError;

  /// Whether [loadConfig] has completed (successfully or as a fallback).
  static bool get isLoaded => _loaded;

  /// Whether the asset load failed (app continues with defaults + dotenv).
  static bool get loadFailed => _loadFailed;

  /// Human-readable error from the last failed load, if any.
  static String? get loadError => _loadError;

  /// Typed REQUIRED-field schema violation from the last load (W6.5).
  ///
  /// Non-null means the config PARSED but violated the required schema — the
  /// boot must fail CLOSED on the `ConfigValidationErrorScreen` instead of
  /// silently continuing on defaults. Null when the load failed for a
  /// non-schema reason (missing/malformed asset): those keep the graceful
  /// defaults+dotenv boot and are surfaced via [loadFailed]/[loadError].
  static ConfigException? get schemaError => _schemaError;

  // ── Public getters (resolved layers) ──────────────────────────────────────
  static String get appName => _appName;
  static String get bundleId => _bundleId;
  static String get storeAndroidUrl => _storeAndroidUrl;
  static String get storeIosUrl => _storeIosUrl;
  static String get fcmChannelDescription => _fcmChannelDescription;
  static String get cloudinaryUploadPreset => _cloudinaryUploadPreset;
  static String get cloudinaryCloudName => _cloudinaryCloudName;
  static String get firebaseProjectId => _firebaseProjectId;
  static String get firebaseAndroidAppId => _firebaseAndroidAppId;
  static String get firebaseIosAppId => _firebaseIosAppId;
  static String get firebaseMessagingSenderId => _firebaseMessagingSenderId;
  static String get firebaseIosClientId => _firebaseIosClientId;

  /// Kitchen LAN endpoint from the `KITCHEN_LAN_ENDPOINT` dotenv value
  /// layered with `environment.kitchenLanEndpoint` (W6.4(3)). Empty means
  /// "not configured" — the adapter passes it through fail-closed instead of
  /// exposing a stale hard-coded address.
  static String get kitchenLanEndpoint => _kitchenLanEndpoint;

  /// Per-client default branch id from `branches.defaultBranchId` in the
  /// client config. Used only as a last-resort fallback when
  /// [currentBranchIdProvider] is null and no branch was resolvable from
  /// Firestore. Empty string = not configured (flows then fail closed).
  static String get defaultBranchId => _defaultBranchId;

  /// Seed currency code from `currency.code` in client_config.json (p37 T-3).
  /// Empty when absent — `resolveCurrencyCode` applies the final `USD`
  /// fallback. The owner-set Firestore doc (`settings/restaurantConfig
  /// .currency`) wins at runtime whenever it is set; this is only the
  /// seed/default layer that R3 found had zero readers.
  static String get currencyCode => _currencyCode;

  /// Display-symbol override from `currency.symbol` (p37 T-3). Empty = derive
  /// the symbol from the code via `currencySymbolFor`.
  static String get currencySymbol => _currencySymbol;

  /// ThemeData built from the `theme` section of the client config.
  /// Falls back to [AppTheme.lightTheme].
  static ThemeData get theme => _themeData;

  /// Dark ThemeData built from `theme.darkTheme` in the config.
  /// Falls back to [AppTheme.darkTheme].
  static ThemeData get darkTheme => _darkThemeData;

  /// TOKENS (b10): decorative scaffold overlay asset from
  /// `theme.background.overlayAsset` (e.g. a faded city map), for shells and
  /// screens rendering `ScaffoldBackground`. Empty = no overlay (default).
  static String get scaffoldOverlayAsset => _scaffoldOverlayAsset;

  /// Confetti celebration colors from theme.confettiOverlay.colors.
  /// Falls back to the neutral multi-brand palette.
  static List<Color> get confettiColors => List.unmodifiable(_confettiColors);

  /// Feature flags from `features.flags` (Phase 2.1 schema). DECORATIVE (D-P33-1).
  static Map<String, bool> get featureFlags => Map.unmodifiable(_featureFlags);

  /// Default for unknown feature flags (`features.unknownFlagDefault`). No callers.
  static bool get featureFlagDefault => _featureFlagDefault;

  /// Feature lookup with the configured per-client default. INERT (D-P33-1): no callers.
  static bool featureEnabled(String key) =>
      _featureFlags[key] ?? _featureFlagDefault;

  /// Initial route from `navigation.entryPoint` (Phase 2.1 schema).
  static String get navigationEntryPoint => _navigationEntryPoint;

  /// Bottom-nav tabs from `navigation.tabs` (Phase 2.1 schema).
  static List<String> get navigationTabs => List.unmodifiable(_navigationTabs);

  /// Routes hidden from the drawer from `navigation.hiddenRoutes`.
  static List<String> get navigationHiddenRoutes =>
      List.unmodifiable(_navigationHiddenRoutes);

  /// Named route map from `navigation.routes` (name → path).
  static Map<String, String> get navigationRoutes =>
      Map.unmodifiable(_navigationRoutes);

  /// Screen descriptors from `screens` (id, route; the dead `mandatory` key
  /// was pruned from the schema in W6.6).
  static List<Map<String, dynamic>> get screens => List.unmodifiable(_screens);

  /// Raw `deliveryPlatforms` rows (empty when the section is absent — the
  /// platform adapters stay inert, L3).
  static List<Map<String, dynamic>> get deliveryPlatforms =>
      List.unmodifiable(_deliveryPlatforms);

  /// The validated, ENABLED platform rows the adapters may use — the shared
  /// `DeliveryPlatforms.enabledPlatforms` selector (fail closed: ANY
  /// violation yields no rows at all; absent/disabled = inert).
  static List<DeliveryPlatformConfig> get enabledDeliveryPlatforms =>
      DeliveryPlatforms.enabledPlatforms(_deliveryPlatforms);

  // ── Loader ────────────────────────────────────────────────────────────────
  /// Reads `assets/client_config.json` and populates the resolved values.
  ///
  /// Precedence: in-code defaults < dotenv < JSON (non-empty only). If the
  /// asset is missing or malformed, the app continues with defaults + dotenv —
  /// the app must still work without the config file (Phase 2.2 fallback rule).
  ///
  /// Call ONCE from `main()` BEFORE `runApp()` (Phase 2.2 spec).
  static Future<void> loadConfig() async {
    if (_loaded) return;

    // Layer 2: dotenv (already loaded by main() before this call).
    _appName = _env('APP_NAME', _kDefaultAppName);
    _bundleId = _env('APP_BUNDLE_ID', _kDefaultBundleId);
    _storeAndroidUrl = _env('STORE_ANDROID_URL', '');
    _storeIosUrl = _env('STORE_IOS_URL', '');
    _fcmChannelDescription = _env(
      'FCM_CHANNEL_DESCRIPTION',
      _kDefaultFcmDescription,
    );
    _cloudinaryUploadPreset = _env(
      'CLOUDINARY_UPLOAD_PRESET',
      _kDefaultCloudinaryPreset,
    );
    _cloudinaryCloudName = _env(
      'CLOUDINARY_CLOUD_NAME',
      _kDefaultCloudinaryCloudName,
    );
    // p34 §0-3a: the --dart-define layer of the documented precedence
    // (`.env -> --dart-define -> config`). Previously only dotenv was read, so
    // a build that passed FIREBASE_PROJECT_ID as a dart-define (the e2e lane)
    // still resolved an empty projectId and withheld the Firebase chain.
    // A compile-time environment query needs a LITERAL name (a runtime `key`
    // silently yields ''), so each key gets its own const query via _defineEnv.
    _firebaseProjectId = _env(
      'FIREBASE_PROJECT_ID',
      _defineEnv('FIREBASE_PROJECT_ID'),
    );
    _kitchenLanEndpoint = _env('KITCHEN_LAN_ENDPOINT', '');

    try {
      final jsonString = await rootBundle.loadString(assetPath, cache: false);
      final Map<String, dynamic> json =
          jsonDecode(jsonString) as Map<String, dynamic>;

      // W6.5: strict REQUIRED-field schema validation. A config that parses
      // but violates the required schema throws [ConfigException] (captured
      // below as [schemaError]) so the boot can fail CLOSED on the
      // ConfigValidationErrorScreen. Optional/unknown fields are NOT
      // validated here — the defensive parsers below keep their graceful
      // degradation.
      ClientConfig.fromMap(json);

      // ── app ───────────────────────────────────────────────────────────
      final app = _asMap(json['app']);
      if (app != null) {
        // Layer 3: JSON only overrides when non-empty.
        _appName = _asString(app['name']).nonEmptyOr(_appName);
        _bundleId = _asString(app['bundleId']).nonEmptyOr(_bundleId);
        _storeAndroidUrl = _asString(
          app['storeAndroidUrl'],
        ).nonEmptyOr(_storeAndroidUrl);
        _storeIosUrl = _asString(app['storeIosUrl']).nonEmptyOr(_storeIosUrl);
        _fcmChannelDescription = _asString(
          app['fcmChannelDescription'],
        ).nonEmptyOr(_fcmChannelDescription);
      }

      // ── environment ───────────────────────────────────────────────────
      final environment = _asMap(json['environment']);
      if (environment != null) {
        _cloudinaryUploadPreset = _asString(
          environment['cloudinaryUploadPreset'],
        ).nonEmptyOr(_cloudinaryUploadPreset);
        _cloudinaryCloudName = _asString(
          environment['cloudinaryCloudName'],
        ).nonEmptyOr(_cloudinaryCloudName);
        // W6.4(1): `environment.firebaseProjectId` is consulted only when the
        // dotenv layer left the project id empty (dotenv = real ops value;
        // template JSONs may carry documented placeholders).
        if (_firebaseProjectId.isEmpty) {
          _firebaseProjectId = _asString(
            environment['firebaseProjectId'],
          ).nonEmptyOr('');
        }
        // W6.4(3): config-driven kitchen LAN endpoint (layered over dotenv).
        // Empty = not configured — never a silently-accepted stale address.
        _kitchenLanEndpoint = _asString(
          environment['kitchenLanEndpoint'],
        ).nonEmptyOr(_kitchenLanEndpoint);
      }

      // ── firebase (Phase 2.2: externalise app IDs / sender ID) ─────────
      final firebase = _asMap(json['firebase']);
      if (firebase != null) {
        _firebaseAndroidAppId = _asString(
          firebase['androidAppId'],
        ).nonEmptyOr(_firebaseAndroidAppId);
        _firebaseIosAppId = _asString(
          firebase['iosAppId'],
        ).nonEmptyOr(_firebaseIosAppId);
        _firebaseMessagingSenderId = _asString(
          firebase['messagingSenderId'],
        ).nonEmptyOr(_firebaseMessagingSenderId);
        _firebaseIosClientId = _asString(
          firebase['iosClientId'],
        ).nonEmptyOr(_firebaseIosClientId);
        // W6.4(1): legacy `firebase.projectId` dual-read — LAST priority
        // (dotenv > environment.firebaseProjectId > firebase.projectId).
        // Both JSON keys are now read, so a config that puts the project id
        // only in `firebase.projectId` (as both shipped configs historically
        // did) is no longer silently ignored.
        if (_firebaseProjectId.isEmpty) {
          _firebaseProjectId = _asString(firebase['projectId']).nonEmptyOr('');
        }
      }

      // ── branches (Phase 2.2: per-client default branch id) ──────────────
      final branches = _asMap(json['branches']);
      if (branches != null) {
        _defaultBranchId = _asString(
          branches['defaultBranchId'],
        ).nonEmptyOr(_defaultBranchId);
      }

      // ── currency (p37 T-3: the `currency` block seeds money display) ─────
      final currency = _asMap(json['currency']);
      if (currency != null) {
        _currencyCode = _asString(currency['code']).nonEmptyOr(_currencyCode);
        _currencySymbol = _asString(
          currency['symbol'],
        ).nonEmptyOr(_currencySymbol);
      }

      // ── theme ─────────────────────────────────────────────────────────
      final theme = _asMap(json['theme']);
      if (theme != null) {
        _themeData = AppTheme.buildTheme(theme);
        _darkThemeData = AppTheme.buildDarkTheme(theme);
        // TOKENS (b10): decorative scaffold overlay asset (theme-level value
        // rebuilds with the config, exactly like the ThemeData above).
        final backdrop = _asMap(theme['background']);
        _scaffoldOverlayAsset = _asString(
          backdrop?['overlayAsset'],
        ).nonEmptyOr('');
        final confetti = _asMap(theme['confettiOverlay']);
        if (confetti != null) {
          final rawColors = confetti['colors'];
          if (rawColors is List) {
            final parsed = <Color>[];
            for (final c in rawColors) {
              if (c is String) {
                final color = _colorFromHex(c);
                if (color != null) parsed.add(color);
              }
            }
            if (parsed.isNotEmpty) _confettiColors = parsed;
          }
        }
      }

      // ── features ──────────────────────────────────────────────────────
      final features = _asMap(json['features']);
      if (features != null) {
        final flags = _asMap(features['flags']);
        if (flags != null) {
          final result = <String, bool>{};
          flags.forEach((key, value) {
            if (value is bool) result[key] = value;
          });
          _featureFlags = result;
        }
        _featureFlagDefault =
            _asBool(features['unknownFlagDefault']) ?? _featureFlagDefault;
      }

      // ── navigation (Phase 2.2: per-client navigation structure) ───────
      final navigation = _asMap(json['navigation']);
      if (navigation != null) {
        _navigationEntryPoint = _asString(
          navigation['entryPoint'],
        ).nonEmptyOr(_navigationEntryPoint);
        final tabs = navigation['tabs'];
        if (tabs is List) {
          _navigationTabs = tabs.whereType<String>().toList();
        }
        final hidden = navigation['hiddenRoutes'];
        if (hidden is List) {
          _navigationHiddenRoutes = hidden.whereType<String>().toList();
        }
        final routes = _asMap(navigation['routes']);
        if (routes != null) {
          final result = <String, String>{};
          routes.forEach((key, value) {
            if (value is String) result[key] = value;
          });
          _navigationRoutes = result;
        }
      }

      // ── screens (Phase 2.2: per-client screen registry) ───────────────
      final screens = json['screens'];
      if (screens is List) {
        _screens = screens
            .whereType<Map<dynamic, dynamic>>()
            .map((s) => s.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }

      // ── UI-9 (p19): deliveryPlatforms — validated fail-closed above (an
      // invalid section throws [ConfigException] and never reaches here);
      // raw rows are kept for the adapter registry, the typed/enabled view
      // resolves through `enabledDeliveryPlatforms`.
      final deliveryPlatforms = json['deliveryPlatforms'];
      if (deliveryPlatforms is List) {
        _deliveryPlatforms = deliveryPlatforms
            .whereType<Map<dynamic, dynamic>>()
            .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }

      // ── PERF-5: per-screen variants (validated vocab, fail-closed) ────
      // The `variant` key is STRICTLY validated when present (the TOKENS
      // rule): an unknown variant name is a REQUIRED-field-style violation.
      // Throwing [ConfigException] HERE lands in the catch below, which
      // records it as the typed [_schemaError] so the boot fails CLOSED on
      // the ConfigValidationErrorScreen — never a silent wrong-layout boot.
      final variantViolations = ScreenVariants.validateScreens(screens);
      if (variantViolations.isNotEmpty) {
        throw ConfigException(
          List<ConfigViolation>.unmodifiable(variantViolations),
        );
      }

      _loaded = true;
      _loadFailed = false;
      _loadError = null;
      _schemaError = null;
    } catch (e) {
      // Fallback: defaults + dotenv stay in place so the app still boots.
      _loaded = true;
      _loadFailed = true;
      _loadError = e.toString();
      // W6.5: a REQUIRED-field schema violation is surfaced TYPED so the
      // boot can fail CLOSED on the ConfigValidationErrorScreen (see
      // main.dart) instead of silently booting on defaults.
      _schemaError = e is ConfigException ? e : null;
    }
  }

  /// Test seam: resets every resolved static to its in-code default so a test
  /// can call [loadConfig] repeatedly against different mocked assets. Never
  /// call from production code.
  @visibleForTesting
  static void resetForTest() {
    _appName = _kDefaultAppName;
    _bundleId = _kDefaultBundleId;
    _storeAndroidUrl = '';
    _storeIosUrl = '';
    _fcmChannelDescription = _kDefaultFcmDescription;
    _cloudinaryUploadPreset = _kDefaultCloudinaryPreset;
    _cloudinaryCloudName = _kDefaultCloudinaryCloudName;
    _firebaseProjectId = '';
    _firebaseAndroidAppId = '';
    _firebaseIosAppId = '';
    _firebaseMessagingSenderId = '';
    _firebaseIosClientId = '';
    _kitchenLanEndpoint = '';
    _defaultBranchId = '';
    _themeData = AppTheme.lightTheme;
    _darkThemeData = AppTheme.darkTheme;
    _scaffoldOverlayAsset = '';
    _confettiColors = const [
      _kConfettiRed,
      _kConfettiNavy,
      _kConfettiAmber,
      _kConfettiTeal,
    ];
    _featureFlags = const {};
    _featureFlagDefault = false;
    _navigationEntryPoint = '/splash';
    _navigationTabs = const [];
    _navigationHiddenRoutes = const [];
    _navigationRoutes = const {};
    _screens = const [];
    _deliveryPlatforms = const [];
    _loaded = false;
    _loadFailed = false;
    _loadError = null;
    _schemaError = null;
  }

  // ── Typed helpers (defensive; never throw on bad schema) ────────────────
  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String? _asString(dynamic value) => value is String ? value : null;

  static bool? _asBool(dynamic value) => value is bool ? value : null;

  /// Parses a hex color string (0xRRGGBB, 0xAARRGGBB, or bare RRGGBB).
  /// Returns null when unparseable so callers can fall back safely.
  static Color? _colorFromHex(String raw) {
    var hex = raw.trim().replaceFirst('0x', '');
    if (hex.isEmpty) return null;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

// ── PERF-5: the screen-variant registry providers ──────────────────────────
// Resolution lives in the pure `ScreenVariants` registry
// (`screen_variants.dart`); these providers surface it through Riverpod the
// same way the theme statics are surfaced (AppConfig is loaded ONCE in main()
// before runApp, so the table is synchronously ready). P9 W1 (T-5) note: the
// former `themeConfigProvider` was deleted as dead weight — the running app
// takes its theme from `AppConfig.theme` / `AppConfig.darkTheme`.

/// The resolved per-screen variant table (screenId → variant) from the
/// loaded client config. Empty when the config carries no variant keys (the
/// byte-for-byte default) or no config loaded at all.
final screenVariantsProvider = Provider<Map<String, String>>(
  (ref) => ScreenVariants.fromScreens(AppConfig.screens),
);

/// The resolved variant for [screenId]: the config's explicit variant when
/// the `screens[]` entry carries one, else the catalog default (today's
/// layout), else '' for screens with no variant support (never variant).
final screenVariantProvider = Provider.family<String, String>((ref, screenId) {
  return ScreenVariants.resolve(ref.watch(screenVariantsProvider), screenId);
});

/// Private extension: returns [fallback] if the string is null or empty.
extension _NonEmptyString on String? {
  String nonEmptyOr(String fallback) {
    final value = this;
    if (value == null || value.isEmpty) return fallback;
    return value;
  }
}
