// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps
//
// Phase 2.3 — UI Factory Generator.
//
// Produces a config-driven, fully-working Flutter client app in
// `apps/<app_name>`, wired to the `core` and `core_ui` packages.
//
// Usage:
//   dart run tool/whitelabel.dart --config path/to/client_config.json
//       [--template minimal|modern|classic]  (fill-missing radius preset; omit for config as authored)
//       [--dry-run]

import 'dart:convert';
import 'dart:io';

class ClientConfig {
  ClientConfig._(this.raw, this.path);

  final Map<String, dynamic> raw;
  final String path;

  static ClientConfig load(String configPath) {
    final file = File(configPath);
    if (!file.existsSync()) {
      throw ArgumentError('Config file not found: $configPath');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Config root must be a JSON object.');
    }
    return ClientConfig._(decoded, file.absolute.path);
  }

  Map<String, dynamic>? _section(String key) => raw[key] is Map<String, dynamic>
      ? raw[key] as Map<String, dynamic>
      : null;

  /// Reads a possibly nested string path (p36 T-5: walks EVERY segment —
  /// the old first/last-only version skipped middle hops, so 3-level paths
  /// like `['theme','background','color']` silently returned the fallback).
  String _string(List<String> path, {String fallback = ''}) {
    Object? current = _section(path.first);
    for (final key in path.skip(1)) {
      if (current is! Map<String, dynamic>) return fallback;
      current = current[key];
    }
    return current is String && current.isNotEmpty ? current : fallback;
  }

  String get appName => _string(['app', 'name'], fallback: 'Client App');
  String get navigationEntryPoint =>
      _string(['navigation', 'entryPoint'], fallback: '/splash');
  String get bundleId =>
      _string(['app', 'bundleId'], fallback: 'com.client.app');
  Map<String, dynamic>? get theme => _section('theme');
  Map<String, dynamic>? get navigation => _section('navigation');
  Map<String, dynamic>? get firebase => _section('firebase');
  Map<String, dynamic>? get features => _section('features');
  Map<String, dynamic>? get environment => _section('environment');
  String get firebaseProjectId => _string(['firebase', 'projectId']);

  // ── Firebase identity getters for the per-project firebase_options.dart
  // emission (ARCH-2) — the SAME values the W6.1 fail-closed gate and the
  // shell's `firebase_config_truth_test.dart` pin against the native
  // google-services files. Defaults to '' so a malformed config surfaces as
  // a build-time placeholder (the runtime gate still blocks the boot). ─────
  String get firebaseAndroidApiKey =>
      _string(['environment', 'firebaseAndroidApiKey']);
  String get firebaseIosApiKey => _string(['environment', 'firebaseIosApiKey']);
  String get firebaseAndroidAppId => _string(['firebase', 'androidAppId']);
  String get firebaseIosAppId => _string(['firebase', 'iosAppId']);
  String get firebaseMessagingSenderId =>
      _string(['firebase', 'messagingSenderId']);
  String get firebaseStorageBucket => _string(['firebase', 'storageBucket']);

  /// p36 T-3 (A3): the client's configured Stripe publishable key — consulted
  /// by [resolveStripePublishableKey]; placeholders never reach the build.
  String get stripePublishableKey =>
      _string(['environment', 'stripePublishableKey']);

  /// p36 T-4 (A4): the launcher-icon master, config-dir relative — copied to
  /// `tool/branding/app_icon.png` in the stamp (never into bundled assets).
  String get iconAsset => _string(['app', 'icon']);

  /// p36 T-4 (A4): theme colors for the emitted native splash
  /// (`theme.background.color` day, `theme.darkTheme.background` night).
  String get themeBackgroundColor => _string(['theme', 'background', 'color']);
  String get themeDarkBackgroundColor =>
      _string(['theme', 'darkTheme', 'background']);

  String get packageName {
    final cleaned = appName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '');
    return cleaned.isEmpty ? 'client_app' : cleaned;
  }

  String get organization {
    final parts = bundleId.split('.');
    return parts.length >= 2 ? '${parts[0]}.${parts[1]}' : 'com.client';
  }

  /// Placeholder fragments that must never ship as a real credential
  /// (case-insensitive). Mirrored at runtime by every generated shell's
  /// `lib/main.dart` fail-fast gate (W6.1).
  static final RegExp _placeholderPattern = RegExp(
    'REPLACE_ME|changeme|<your',
    caseSensitive: false,
  );

  /// PERF-5: the per-screen variant vocabulary. Mirrors the runtime
  /// `ScreenVariants.catalog` BY DESIGN (the tool must not import app lib
  /// code — the same rule as the schema-version constant); the two
  /// validators are pinned to the same fixtures by
  /// `core_app/test/tool/whitelabel_schema_identity_test.dart`.
  static const Map<String, Set<String>> screenVariantCatalog =
      <String, Set<String>>{
        'HomeScreen': <String>{'grid', 'showcase'},
      };

  /// UI-9 (p19): the `deliveryPlatforms` vocabulary. Mirrors
  /// `DeliveryPlatforms.catalog` / `credentialRefPattern` /
  /// `forbiddenCredentialPrefixes` in package:core BY DESIGN (the tool never
  /// imports app lib code — the same rule as the screen-variant catalog);
  /// `whitelabel_schema_identity_test.dart` pins this mirror to the runtime
  /// vocabulary and to the shared fixture.
  static const Set<String> deliveryPlatformIds = <String>{
    'uber_eats',
    'delivery_hero',
  };

  static const List<String> deliveryForbiddenCredentialPrefixes = <String>[
    'sk_live_',
    'sk_test_',
    'whsec_',
    'pk_live_',
    'AIza',
    'ya29.',
    '-----BEGIN',
  ];

  static final RegExp deliveryCredentialRefPattern = RegExp(
    r'^[A-Z][A-Z0-9_]{2,63}$',
  );

  /// Every top-level key the client_config schema recognizes (p37 T-4(b),
  /// scope A / D-P37-2). Mirrors the AppConfig parsers plus the generator's
  /// metadata and the two optional sections; `config_inverse_matrix_test.dart`
  /// pins this set against both shipped configs, and unknown roots now block
  /// generation instead of validating silently.
  static const Set<String> knownTopLevelKeys = <String>{
    '_meta',
    'app',
    'tenantId',
    'branches',
    'currency',
    'deliveryPlatforms',
    'environment',
    'firebase',
    'features',
    'navigation',
    'screens',
    'stripeAccountId',
    'theme',
  };

  /// UI-14 (p25) F-8 — the validity gate for a generated shell.
  ///
  /// Returns the list of ERRORS: the findings that must BLOCK generation
  /// (a missing section, an empty `app.bundleId`, a placeholder Firebase
  /// credential, a malformed design token, an unknown screen variant).
  ///
  /// A config can be perfectly valid yet still leave engine-read visual keys
  /// unset — that is a COMPLETENESS finding, not a validity one. Those are
  /// emitted through the optional [warnings] sink (see
  /// [completenessWarnings]); by L-P1 they can never add, move or reword an
  /// error string, never change the exit code, and never change an emitted
  /// byte.
  List<String> validate({
    bool allowUsdFallback = false,
    List<String>? warnings,
  }) {
    final errors = <String>[];
    if (_section('app') == null) {
      errors.add('Missing "app" section.');
    }
    if (_section('firebase') == null) {
      errors.add('Missing "firebase" section.');
    }
    if (_section('theme') == null) {
      errors.add('Missing "theme" section.');
    }
    if (_section('navigation') == null) {
      errors.add('Missing "navigation" section.');
    }
    if (_section('features') == null) {
      errors.add('Missing "features" section.');
    }
    // p37 T-4(b) (scope A / D-P37-2): fail-closed on UNKNOWN top-level keys.
    // A typo'd or historical root key used to validate silently while nothing
    // read it — exactly where a dead promise hides. Known roots mirror the
    // AppConfig parsers plus generator metadata and optional sections.
    for (final key in raw.keys) {
      if (!knownTopLevelKeys.contains(key)) {
        errors.add(
          'Unknown top-level key "$key" - not part of the client_config '
          'schema. Known top-level keys: ${knownTopLevelKeys.join(', ')}.',
        );
      }
    }
    if (appName.trim().isEmpty) {
      errors.add('"app.name" must not be empty.');
    }
    if (bundleId.trim().isEmpty) {
      errors.add('"app.bundleId" must not be empty.');
    }

    // p36 T-4 (A4): the launcher-icon master is a REQUIRED brand asset — a
    // stamp without it ships the stock Flutter launcher (S5). Fail-closed:
    // the file must sit next to the config, be a real PNG, and be >=512x512
    // (store + adaptive-icon headroom). Signature+IHDR read only; the raster
    // work is the branding tool's job, gated separately at run time.
    final iconRef = _string(['app', 'icon']).trim();
    if (iconRef.isEmpty) {
      errors.add(
        '"app.icon" is required (a PNG master >=512x512 next to the client '
        'config) - a stamp without it ships the stock Flutter launcher.',
      );
    } else {
      final normalizedPath = path.replaceAll('/', Platform.pathSeparator);
      final configDir = normalizedPath.substring(
        0,
        normalizedPath.lastIndexOf(Platform.pathSeparator),
      );
      final iconFile = File(
        '$configDir${Platform.pathSeparator}'
        '${iconRef.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!iconFile.existsSync()) {
        errors.add(
          '"app.icon" file not found: $iconRef (expected next to the config '
          'at $configDir).',
        );
      } else if (!iconRef.toLowerCase().endsWith('.png')) {
        errors.add('"app.icon" must be a .png file (got "$iconRef").');
      } else {
        final bytes = iconFile.readAsBytesSync();
        const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        final hasSignature =
            bytes.length >= 24 &&
            signature.asMap().entries.every((e) => bytes[e.key] == e.value);
        if (!hasSignature) {
          errors.add(
            '"app.icon" is not a valid PNG file (bad signature): $iconRef',
          );
        } else {
          int u32(int offset) =>
              (bytes[offset] << 24) |
              (bytes[offset + 1] << 16) |
              (bytes[offset + 2] << 8) |
              bytes[offset + 3];
          final width = u32(16);
          final height = u32(20);
          if (width < 512 || height < 512) {
            errors.add(
              '"app.icon" must be at least 512x512 (got ${width}x$height) - '
              'upscale the shipped master or supply the original brand file.',
            );
          }
        }
      }
    }

    // W6.1(a) — fail-closed Firebase credential gate. A shell generated with
    // an empty/placeholder Firebase API key would boot with NO auth,
    // Firestore or FCM. Errors name the exact JSON path so the operator can
    // fix the config directly.
    final environment = _section('environment');
    String envValue(String key) {
      final value = environment?[key];
      return value is String ? value : '';
    }

    void checkFirebaseKey(String jsonPath, String value) {
      if (value.trim().isEmpty) {
        errors.add('"$jsonPath" must not be empty.');
      } else if (_placeholderPattern.hasMatch(value)) {
        errors.add(
          '"$jsonPath" must be a real Firebase API key — '
          'placeholder values are rejected.',
        );
      }
    }

    checkFirebaseKey(
      'environment.firebaseAndroidApiKey',
      envValue('firebaseAndroidApiKey'),
    );
    checkFirebaseKey(
      'environment.firebaseIosApiKey',
      envValue('firebaseIosApiKey'),
    );

    final projectId = firebaseProjectId;
    if (projectId.trim().isEmpty) {
      errors.add('"firebase.projectId" must not be empty.');
    } else if (_placeholderPattern.hasMatch(projectId)) {
      errors.add(
        '"firebase.projectId" must be a real Firebase project id — '
        'placeholder values are rejected.',
      );
    }

    // W6.2 — flags format unification. Every parser accepts ONLY bool flag
    // values: an object-valued flag ({"enabled": true}) is silently dropped,
    // making flag gating inert. The map must be non-empty and all-bool.
    final flags = _section('features')?['flags'];
    if (flags is! Map || flags.isEmpty) {
      errors.add(
        '"features.flags" must be a non-empty map of "flagName": bool values.',
      );
    } else {
      final offending = flags.entries
          .where((entry) => entry.value is! bool)
          .map((entry) => '"${entry.key}"')
          .toList();
      if (offending.isNotEmpty) {
        errors.add(
          '"features.flags" values must be bool '
          '(offending keys: ${offending.join(', ')}).',
        );
      }
    }

    // TENANCY (P0-6) — mirrors the runtime `ClientConfig.fromMap` tenantId gate
    // BY DESIGN (the tool must not import app lib code). A config without a
    // well-formed tenant id is refused at VALIDATION, before any generation,
    // so a half-identified client can never be stamped into apps/.
    final rawTenantId = raw['tenantId'];
    final tenantId = rawTenantId is String ? rawTenantId : null;
    const tenantIdRule =
        'must be a kebab/snake id (lowercase letters, digits, '
        '"-" or "_"), e.g. "halal_boyz"';
    if (tenantId == null || tenantId.trim().isEmpty) {
      errors.add(
        '"tenantId" is required and must be a non-empty kebab/snake id '
        '(lowercase letters, digits, "-" or "_"), e.g. "halal_boyz".',
      );
    } else if (!RegExp(r'^[a-z0-9]+([_-][a-z0-9]+)*$').hasMatch(tenantId)) {
      errors.add('"tenantId" $tenantIdRule — got "$tenantId".');
    }

    // ADR-01 (P0-10) — the card-present payment surface, schema-only and
    // OPTIONAL (mirrors the runtime ClientConfig.fromMap gate BY DESIGN).
    // Nothing consumes these values; the generator merely accepts and
    // type-checks them so the config can carry them ahead of the feature.
    final rawStripeAccountId = raw['stripeAccountId'];
    if (rawStripeAccountId != null && rawStripeAccountId is! String) {
      errors.add(
        '"stripeAccountId" must be a string when present '
        '(empty string means unconfigured).',
      );
    }
    final branchSection = _section('branches');
    if (branchSection != null) {
      final flatLocation = branchSection['terminalLocationId'];
      if (flatLocation != null && flatLocation is! String) {
        errors.add(
          '"branches.terminalLocationId" must be a string when present.',
        );
      }
      branchSection.forEach((String key, Object? value) {
        if (value is! Map) return;
        final nested = value['terminalLocationId'];
        if (nested != null && nested is! String) {
          errors.add(
            '"branches.$key.terminalLocationId" must be a string when present.',
          );
        }
      });
    }

    // W6.4(4) — schema version pin. The config schema is versioned; this
    // generator speaks exactly ONE version and refuses anything else (a
    // newer-schema config must never silently generate an older app).
    final meta = _section('_meta');
    final schemaVersion = meta?['schemaVersion'];
    if (schemaVersion is! String ||
        schemaVersion != whitelabelSupportedSchemaVersion) {
      errors.add(
        '"_meta.schemaVersion" must be exactly '
        '"$whitelabelSupportedSchemaVersion" '
        '(got: ${schemaVersion ?? 'missing'}).',
      );
    }

    // W6.4(5) — currency is a REQUIRED section (the generated shell consumes
    // currency.code for money display). A missing section only passes with
    // the explicit --allow-usd-fallback owner opt-in, which keeps the
    // built-in USD fallback honest instead of silent.
    final currency = _section('currency');
    final currencyCode = currency?['code'];
    if (currencyCode is! String || currencyCode.trim().isEmpty) {
      if (!allowUsdFallback) {
        errors.add(
          '"currency.code" is required (ISO 4217, e.g. USD). Pass '
          '--allow-usd-fallback to accept the built-in USD fallback.',
        );
      }
    }

    // ── TOKENS (WHITE_LABEL_b10_tokens.md) ──────────────────────────────────
    // The optional design-token keys are validated STRICTLY WHEN PRESENT —
    // the same rule the runtime `ClientConfig.fromMap` enforces (WL-2: the
    // validator validates what `AppTheme.buildTheme` reads; a malformed
    // token must fail generation, never silently generate the default look).
    // The rules are mirrored BY DESIGN (the tool must not import app lib
    // code); `whitelabel_schema_identity_test.dart` pins both validators to
    // the same malformed-token fixtures.
    _validateDesignTokens(errors);

    // ── PERF-5: per-screen variant vocabulary ────────────────────────────
    // The variant key is part of the schema: an unknown variant name must
    // fail GENERATION, never silently generate a shell whose screens would
    // fail closed at boot (or worse, silently render the default layout).
    // Mirrors the runtime loadConfig gate (see the catalog above).
    _validateScreenVariants(errors);

    // ── UI-9 (p19): deliveryPlatforms vocabulary ────────────────────────────
    // STRICTLY WHEN PRESENT: an absent section generates an inert app; a
    // present-but-invalid row fails GENERATION at its exact JSON path — the
    // same paths the runtime gate (`ClientConfig.fromMap` →
    // `DeliveryPlatforms.validatePlatforms`) and the server selector name
    // (pinned to the shared fixture by the identity test).
    _validateDeliveryPlatforms(errors);

    if (warnings != null) {
      warnings.addAll(completenessWarnings());
    }
    return errors;
  }

  /// UI-14 (p25) F-8 — the COMPLETENESS channel.
  ///
  /// [validate] answers "is this config valid?"; this answers "does it set
  /// every visual key the theming engine actually reads?". Each finding names
  /// the exact JSON path plus what renders instead, so an operator sees the
  /// gap instead of shipping Material-default inputs/chips/backdrop (the B9
  /// defect class that reached production through F-8).
  ///
  /// The key set mirrors `AppTheme._themeFromConfig` /
  /// `AppTheme._brandColorsFor` (`packages/core_ui`) BY DESIGN — the tool must
  /// not import app lib code (the same rule as the screen-variant catalog);
  /// `client_config_engine_key_matrix_test.dart` pins this mirror to the
  /// engine's own read sites. Advisory only (L-P1): never an error, never a
  /// non-zero exit, never an emitted byte.
  List<String> completenessWarnings() {
    final theme = _section('theme');
    if (theme is! Map<String, dynamic>) return <String>[];

    final out = <String>[];

    /// Value at a `theme`-rooted dotted path. An absent key and an explicit
    /// JSON `null` both count as UNSET — exactly how the engine reads them
    /// (every token parser falls back on `null`/absent alike).
    Object? at(String path) {
      Object? cursor = theme;
      for (final key in path.split('.').skip(1)) {
        if (cursor is! Map) return null;
        cursor = cursor[key];
      }
      return cursor;
    }

    const materialDefault = 'Material default will render';

    // Singleton engine-read keys: JSON path -> what renders when unset.
    const singletons = <String, String>{
      'theme.shape.cardRadius': 'the 16dp card default will render',
      'theme.shape.ctaRadius': materialDefault,
      'theme.shape.smallRadius': materialDefault,
      'theme.components.chip.radius': materialDefault,
      'theme.background.color': 'the AppColors.background default will render',
      'theme.background.overlayAsset': 'no backdrop overlay will render',
      'theme.animationStyle': 'the full-motion default will render',
      'theme.typography.fontFamily': 'the SaaS type system will render',
      'theme.typography.headingFont': 'the SaaS heading font will render',
      'theme.typography.bodyFont': 'the SaaS body font will render',
      'theme.darkTheme.background': 'the built-in dark default will render',
      'theme.darkTheme.surface': 'the built-in dark default will render',
    };
    singletons.forEach((path, consequence) {
      if (at(path) == null) out.add('WARNING: $path unset — $consequence');
    });

    // Engine-read GROUPS. When EVERY leaf is unset the warning carries the
    // wildcard form (`WARNING: theme.components.input.* unset — ...`); a
    // partly-filled group reports only its unset leaves by exact path.
    const groups = <String, (List<String>, String)>{
      'theme.colors': (
        <String>[
          'primary',
          'secondary',
          'accent',
          'background',
          'surface',
          'textPrimary',
          'textSecondary',
          'error',
          'success',
          'warning',
          'soldOut',
          'textPrimary12',
        ],
        'the AppColors default palette will render',
      ),
      'theme.components.navigationBar': (
        <String>['background', 'activeColor'],
        materialDefault,
      ),
      'theme.components.input': (
        <String>['fillColor', 'borderColor', 'radius'],
        materialDefault,
      ),
    };
    groups.forEach((prefix, spec) {
      final (leaves, consequence) = spec;
      final unset = leaves
          .where((leaf) => at('$prefix.$leaf') == null)
          .toList();
      if (unset.isEmpty) return;
      if (unset.length == leaves.length) {
        out.add('WARNING: $prefix.* unset — $consequence');
        return;
      }
      for (final leaf in unset) {
        out.add('WARNING: $prefix.$leaf unset — $consequence');
      }
    });

    return out;
  }

  /// TOKENS (b10): optional design-token validation. Mirrors the runtime
  /// `ClientConfig.fromMap` (see `whitelabel_schema_identity_test.dart`).
  void _validateDesignTokens(List<String> errors) {
    Map<String, dynamic>? sectionAt(List<String> keys) {
      var cursor = _section(keys.first);
      for (var i = 1; i < keys.length; i++) {
        if (cursor == null) return null;
        final next = cursor[keys[i]];
        cursor = next is Map<String, dynamic> ? next : null;
      }
      return cursor;
    }

    void expectNonEmptyString(List<String> keys) {
      final value = sectionAt(keys.sublist(0, keys.length - 1))?[keys.last];
      if (value != null && (value is! String || value.trim().isEmpty)) {
        errors.add(
          '"${keys.join('.')}" must be a non-empty string when '
          'present.',
        );
      }
    }

    void expectHexColor(List<String> keys) {
      final value = sectionAt(keys.sublist(0, keys.length - 1))?[keys.last];
      if (value == null) return;
      var hex = value is String ? value.trim().replaceFirst('0x', '') : '';
      if (hex.length == 6) hex = 'FF$hex';
      if (value is! String ||
          hex.length != 8 ||
          int.tryParse(hex, radix: 16) == null) {
        errors.add(
          '"${keys.join('.')}" must be a parseable hex color '
          '(0xRRGGBB[AA]) when present (got: $value).',
        );
      }
    }

    void expectPositiveNumber(List<String> keys) {
      final value = sectionAt(keys.sublist(0, keys.length - 1))?[keys.last];
      if (value == null) return;
      if (value is! num || !(value > 0) || !(value.isFinite)) {
        errors.add(
          '"${keys.join('.')}" must be a positive finite number '
          'when present (got: $value).',
        );
      }
    }

    expectNonEmptyString(['theme', 'typography', 'headingFont']);
    expectNonEmptyString(['theme', 'typography', 'bodyFont']);
    expectPositiveNumber(['theme', 'shape', 'cardRadius']);
    expectPositiveNumber(['theme', 'shape', 'ctaRadius']);
    expectPositiveNumber(['theme', 'shape', 'smallRadius']);
    // p35 V3 mirror: the `theme.shape.style` closed-set check. The runtime
    // `AppShapePreset.fromStyle` gracefully degrades an unknown value to
    // today's default; the generator fails CLOSED here so a typo never ships.
    // Vocabulary pinned equal to core_ui `AppShapePreset.vocabulary` by
    // `whitelabel_schema_identity_test`.
    final shapeSection = _section('theme')?['shape'];
    final Object? shapeStyle = shapeSection is Map
        ? shapeSection['style']
        : null;
    if (shapeStyle != null) {
      const allowed = <String>{'sharp', 'soft', 'round', 'pill'};
      if (shapeStyle is! String || !allowed.contains(shapeStyle)) {
        errors.add(
          '"theme.shape.style" must be one of $allowed when present '
          '(got: $shapeStyle).',
        );
      }
    }
    // p35 scope B mirror: the `theme.depth` closed-set check. The runtime
    // `AppDepthPreset.fromStyle` gracefully degrades an unknown value to flat
    // (0); the generator fails CLOSED here so a typo never ships. Vocabulary
    // pinned equal to core_ui `AppDepthPreset.vocabulary` by
    // `whitelabel_schema_identity_test`.
    final Object? depthStyle = _section('theme')?['depth'];
    if (depthStyle != null) {
      const allowed = <String>{'flat', 'soft', 'elevated'};
      if (depthStyle is! String || !allowed.contains(depthStyle)) {
        errors.add(
          '"theme.depth" must be one of $allowed when present '
          '(got: $depthStyle).',
        );
      }
    }
    expectHexColor(['theme', 'components', 'navigationBar', 'background']);
    expectHexColor(['theme', 'components', 'navigationBar', 'activeColor']);
    expectHexColor(['theme', 'components', 'input', 'fillColor']);
    expectHexColor(['theme', 'components', 'input', 'borderColor']);
    expectPositiveNumber(['theme', 'components', 'input', 'radius']);
    expectPositiveNumber(['theme', 'components', 'chip', 'radius']);
    expectHexColor(['theme', 'background', 'color']);
    // Q3: engine-read state token — strict-when-present, mirroring the
    // runtime `ClientConfig.fromMap` (whitelabel_schema_identity_test pins
    // both validators to the same fixtures).
    expectHexColor(['theme', 'colors', 'soldOut']);
    expectNonEmptyString(['theme', 'background', 'overlayAsset']);
    final overlayAsset = sectionAt(['theme', 'background'])?['overlayAsset'];
    if (overlayAsset is String) {
      final trimmed = overlayAsset.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('/') ||
          trimmed.startsWith('\\') ||
          trimmed.contains('..') ||
          trimmed.contains('\\')) {
        errors.add(
          '"theme.background.overlayAsset" must be a relative asset '
          'path (no leading "/", no "..", no backslashes) when present.',
        );
      }
    }
    final animationStyle = _section('theme')?['animationStyle'];
    if (animationStyle != null) {
      const allowed = <String>{'full', 'subtle', 'none'};
      if (animationStyle is! String || !allowed.contains(animationStyle)) {
        errors.add(
          '"theme.animationStyle" must be one of $allowed when '
          'present (got: $animationStyle).',
        );
      }
    }

    // Q1 mirror of the runtime `theme.signature.style` closed-set check
    // (whitelabel_schema_identity_test pins both validators to the same
    // fixtures): strict-when-present, absent = stock UI (b10 byte contract).
    final signature = _section('theme')?['signature'];
    if (signature != null && signature is! Map) {
      errors.add(
        '"theme.signature.style" must be an object with a "style" string '
        'when present (got: $signature).',
      );
    } else if (signature is Map) {
      final Object? signatureStyle = signature['style'];
      const allowedSignatureStyles = <String>{'rule'};
      if (signatureStyle is! String || signatureStyle.trim().isEmpty) {
        errors.add(
          '"theme.signature.style" must be a non-empty string when '
          'theme.signature is present.',
        );
      } else if (!allowedSignatureStyles.contains(signatureStyle)) {
        errors.add(
          '"theme.signature.style" must be one of $allowedSignatureStyles '
          'when present (got: $signatureStyle).',
        );
      }
    }
  }

  /// PERF-5: per-screen variant vocabulary. STRICTLY WHEN PRESENT (the
  /// TOKENS rule): an absent `variant` key keeps the byte-for-byte default;
  /// a present-but-invalid key (non-string, unknown screen id, or a value
  /// outside the catalog) fails generation with the exact JSON path
  /// `screens[i].variant` — the same paths the runtime gate names, so the
  /// identity test pins both validators to the same fixtures.
  void _validateScreenVariants(List<String> errors) {
    final screens = raw['screens'];
    if (screens is! List) return;
    for (var i = 0; i < screens.length; i++) {
      final entry = screens[i];
      if (entry is! Map) continue;
      final variant = entry['variant'];
      if (variant == null) continue;
      final path = '"screens[$i].variant"';
      if (variant is! String || variant.trim().isEmpty) {
        errors.add('$path must be a non-empty string when present.');
        continue;
      }
      final id = entry['id'];
      final allowed = id is String ? screenVariantCatalog[id] : null;
      if (allowed == null) {
        errors.add(
          '$path: screen id "${id ?? 'missing'}" has no variant vocabulary '
          '— allowed ids: ${screenVariantCatalog.keys.toList()}.',
        );
        continue;
      }
      if (!allowed.contains(variant)) {
        errors.add(
          '$path must be one of $allowed for screen id "$id" '
          '(got: "$variant").',
        );
      }
    }
  }

  /// UI-9 (p19): the `deliveryPlatforms` section — STRICTLY WHEN PRESENT.
  /// Mirrors `DeliveryPlatforms.validatePlatforms` (package:core) BY DESIGN:
  /// same rules, same messages, same JSON paths — an unknown platform id, a
  /// duplicate row or a pasted secret VALUE fails generation at the exact
  /// path the operator must fix. Pinned to the shared fixture by
  /// `whitelabel_schema_identity_test.dart`.
  void _validateDeliveryPlatforms(List<String> errors) {
    final platforms = raw['deliveryPlatforms'];
    if (platforms == null) return;
    void add(String path, String message) => errors.add('"$path" $message');
    if (platforms is! List) {
      add(
        'deliveryPlatforms',
        'must be a list of platform rows when present '
            '({id, enabled, credentialRef, storeId})',
      );
      return;
    }
    final seen = <String>{};
    for (var i = 0; i < platforms.length; i++) {
      final entry = platforms[i];
      final base = 'deliveryPlatforms[$i]';
      if (entry is! Map) {
        add(base, 'must be an object');
        continue;
      }
      final id = entry['id'];
      if (id is! String || id.trim().isEmpty) {
        add('$base.id', 'must be a non-empty platform id');
        continue;
      }
      if (!deliveryPlatformIds.contains(id)) {
        add(
          '$base.id',
          'unknown platform id "$id" — allowed ids: '
              '${deliveryPlatformIds.toList()}',
        );
        continue;
      }
      if (!seen.add(id)) {
        add(
          '$base.id',
          'duplicate platform id "$id" — at most one row per platform',
        );
        continue;
      }
      final enabled = entry['enabled'];
      if (enabled != null && enabled is! bool) {
        add('$base.enabled', 'must be a boolean when present (got: $enabled)');
      }
      // Disabled or absent = INERT: nothing else about the row is read.
      if (enabled != true) continue;
      final storeId = entry['storeId'];
      if (storeId is! String || storeId.trim().isEmpty) {
        add(
          '$base.storeId',
          'storeId is required and must be a non-empty string when '
              'enabled is true',
        );
      }
      final credentialRef = entry['credentialRef'];
      if (credentialRef is! String || credentialRef.trim().isEmpty) {
        add(
          '$base.credentialRef',
          'credentialRef is required when enabled is true (the NAME of the '
              'secret holder, never the secret)',
        );
      } else if (_looksLikeSecretLiteral(credentialRef)) {
        add(
          '$base.credentialRef',
          'must be a secret REFERENCE (an environment variable name), never '
              'a secret literal',
        );
      } else if (!deliveryCredentialRefPattern.hasMatch(credentialRef.trim())) {
        add(
          '$base.credentialRef',
          'must match ${deliveryCredentialRefPattern.pattern} (an '
              'environment-style name)',
        );
      }
    }
  }

  /// True when [ref] looks like a pasted secret VALUE, not a reference name.
  bool _looksLikeSecretLiteral(Object? ref) {
    if (ref is! String) return false;
    final trimmed = ref.trim();
    for (final prefix in deliveryForbiddenCredentialPrefixes) {
      if (trimmed.startsWith(prefix)) return true;
    }
    return false;
  }
}

/// The only client_config schema version this generator speaks (W6.4(4)).
/// MUST stay equal to `ClientConfig.supportedSchemaVersion` in
/// `core_app/lib/app/config/client_config.dart` — enforced by
/// `core_app/test/tool/whitelabel_schema_identity_test.dart` (the tool does
/// not import app lib code, so the constant is mirrored here by design).
const String whitelabelSupportedSchemaVersion = '1.0.0';

/// W6.6: refuses to read a client config that still carries Carnama's live
/// identity (Cloudinary cloud/preset, stale LAN IP, the Carnama app id, and —
/// newly widened — Carnama's Firebase sender-id/project-id fragments).
/// Top-level so tests can exercise the guard directly.
void checkConfigForbiddenTokens(String configPath) =>
    _Generator._checkConfigForbiddenTokens(configPath);

/// Escapes [raw] for use inside a double-quoted XML attribute value.
String _xmlEscape(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// W6.6: aligns the generated app's platform identity with the config.
///
/// `flutter create` derives the Android `applicationId` from `--org` plus the
/// directory name — which drifts from `app.bundleId` (exactly the three-way
/// drift this batch caught in the checked-in halal_boyz shell). This step
/// rewrites: `android/app/build.gradle.kts` `applicationId` = bundleId;
/// `project.pbxproj` `PRODUCT_BUNDLE_IDENTIFIER` = bundleId (the
/// `*.RunnerTests` targets keep their derived suffix); `AndroidManifest.xml`
/// `android:label` = app.name; `Info.plist` `CFBundleDisplayName` = app.name.
///
/// Idempotent; any missing structure throws (fail-closed) — the generator
/// must never emit an app whose identity it cannot align.
void alignPlatformIdentity({
  required String appPath,
  required String bundleId,
  required String displayName,
}) {
  final sep = Platform.pathSeparator;

  final gradleFile = File(
    '$appPath${sep}android${sep}app${sep}build.gradle.kts',
  );
  if (!gradleFile.existsSync()) {
    throw StateError('alignPlatformIdentity: missing ${gradleFile.path}');
  }
  final gradleText = gradleFile.readAsStringSync();
  if (!RegExp(r'applicationId\s*=\s*"[^"]+"').hasMatch(gradleText)) {
    throw StateError(
      'alignPlatformIdentity: applicationId not found in ${gradleFile.path}',
    );
  }
  gradleFile.writeAsStringSync(
    gradleText.replaceFirst(
      RegExp(r'applicationId\s*=\s*"[^"]+"'),
      'applicationId = "$bundleId"',
    ),
  );

  final pbxFile = File(
    '$appPath${sep}ios${sep}Runner.xcodeproj${sep}project.pbxproj',
  );
  if (!pbxFile.existsSync()) {
    throw StateError('alignPlatformIdentity: missing ${pbxFile.path}');
  }
  final alignedLines = pbxFile.readAsLinesSync().map((line) {
    final match = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
    ).firstMatch(line);
    if (match == null) return line;
    final current = match.group(1)!.trim();
    final target = current.endsWith('.RunnerTests')
        ? '$bundleId.RunnerTests'
        : bundleId;
    return line.replaceFirst(current, target);
  }).toList();
  pbxFile.writeAsStringSync('${alignedLines.join('\n')}\n');

  final manifestFile = File(
    '$appPath${sep}android${sep}app${sep}src${sep}main${sep}AndroidManifest.xml',
  );
  if (!manifestFile.existsSync()) {
    throw StateError('alignPlatformIdentity: missing ${manifestFile.path}');
  }
  final manifestText = manifestFile.readAsStringSync();
  if (!RegExp(r'android:label="[^"]*"').hasMatch(manifestText)) {
    throw StateError(
      'alignPlatformIdentity: android:label not found in ${manifestFile.path}',
    );
  }
  manifestFile.writeAsStringSync(
    manifestText.replaceFirst(
      RegExp(r'android:label="[^"]*"'),
      'android:label="${_xmlEscape(displayName)}"',
    ),
  );

  final plistFile = File('$appPath${sep}ios${sep}Runner${sep}Info.plist');
  if (!plistFile.existsSync()) {
    throw StateError('alignPlatformIdentity: missing ${plistFile.path}');
  }
  final plistLines = plistFile.readAsLinesSync();
  final keyIndex = plistLines.indexWhere(
    (line) => line.trim() == '<key>CFBundleDisplayName</key>',
  );
  if (keyIndex == -1) {
    throw StateError(
      'alignPlatformIdentity: CFBundleDisplayName key not found '
      'in ${plistFile.path}',
    );
  }
  var valueIndex = -1;
  for (var i = keyIndex + 1; i < plistLines.length; i++) {
    final trimmed = plistLines[i].trim();
    if (trimmed.startsWith('<key>')) break;
    if (trimmed.startsWith('<string>')) {
      valueIndex = i;
      break;
    }
  }
  if (valueIndex == -1) {
    throw StateError(
      'alignPlatformIdentity: CFBundleDisplayName value not found '
      'in ${plistFile.path}',
    );
  }
  final valueLine = plistLines[valueIndex];
  final indent = valueLine.substring(0, valueLine.indexOf('<'));
  plistLines[valueIndex] = '$indent<string>${_xmlEscape(displayName)}</string>';
  plistFile.writeAsStringSync('${plistLines.join('\n')}\n');

  print(
    'Aligned platform identity: applicationId/pbxproj = $bundleId, '
    'labels = "$displayName".',
  );
}

/// Stock `flutter create` baseline fragments (pinned byte-exactly to the
/// AUD-2 emission receipt `tool_audit/aud2/c11_gradle_diff.txt`) and their
/// RELEASE-1-gated replacements (pinned byte-exactly to the shipped
/// `apps/halal_boyz/android/app/build.gradle.kts`). [alignReleaseSigningGate]
/// splices them in this order: jvmTarget, compileOptions, release block,
/// header prepend, tail append.
const String _releaseGateHeader = r'''import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ── RELEASE-1 / W11.1: release signing gate (hand-mirrored from the core
// template — the generator's `flutter create` owns this file's baseline, so a
// regeneration reverts these lines; re-apply per docs/RELEASE_RUNBOOK.md).
// Same contract as core: release builds MUST be signed from android/key.properties
// and fail CLOSED with a clear message when it is absent or incomplete. ──
val _releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
// Kotlin DSL sam-with-receiver: inside this lambda the receiver IS the
// TaskExecutionGraph (allTasks below resolves on it).
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.project == project &&
            (task.name == "bundleRelease" || task.name == "assembleRelease")
    }
    if (buildingRelease) {
        val missing = _releaseSigningKeys.filter { key ->
            keystoreProperties.getProperty(key).isNullOrBlank()
        }
        check(missing.isEmpty()) {
            "Release build requires a complete android/key.properties " +
                "(missing: $missing). Copy key.properties.template, fill in " +
                "your keystore values, and NEVER commit the file."
        }
    }
}

''';
const String _releaseGateFooter = r'''flutter {
    source = "../.."
}

// ── ANDROID-AAR-METADATA FIX (halal_boyz rebrand batch) ──────────────────────
// Mirrors the core_app template's PROVEN config (core_app/android/app/
// build.gradle.kts:53-57,102-104) that passes the SAME flutter-gradle-plugin +
// flutter_local_notifications 17.2.4 (packages/core pin) AAR build on this SDK.
// flutter_local_notifications' android/build.gradle sets
// `coreLibraryDesugaringEnabled true` (Java 1.8 target), so Gradle's
// checkDebugAarMetadata REQUIRES the consuming app (:app) to enable core-library
// desugaring too — the flutter-gradle-plugin does not propagate it
// (flutter/flutter#161964 resolved as app-side). Without this, `flutter build
// apk --debug` fails: "Dependency ':flutter_local_notifications' requires core
// library desugaring to be enabled for :app".
// Re-apply note (same as the RELEASE-1 signing mirror above): the generator's
// `flutter create` owns this file's baseline, so a regeneration reverts these
// lines; re-apply with the template on the next regen.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
''';
const String _releaseGateStockCompileOptions = r'''    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

''';
const String _releaseGateCompileOptions = r'''    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

''';
const String _releaseGateStockReleaseBlock = r'''    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

''';
const String _releaseGateReleaseBlock = r'''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // RELEASE-1 / W11.1: a release build is signed from
            // android/key.properties (the gate above fails closed when the
            // keystore is absent/incomplete) — never with the debug key.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

''';

/// F-AUD2-15 (FIX-B8 T-3): re-applies the RELEASE-1 signing gate and the
/// core-library desugaring block to `android/app/build.gradle.kts` immediately
/// after `flutter create` scaffolds it, byte-identically to the shipped shell.
///
/// The stock baseline signs RELEASE builds with the DEBUG key (the RELEASE-1
/// production stopper) and targets Java 17 without core-library desugaring,
/// while `flutter create` owns this file's baseline — so a regeneration
/// reverted the hand-mirrored gate (F-AUD2-15). The gate is generator-owned
/// now: applied on every fresh scaffold, a byte-identical no-op when already
/// present, and FAIL-CLOSED (StateError) when the stock baseline no longer
/// matches the pinned anchors or only part of the gate is present — the
/// generator must never emit a shell whose release-signing posture it cannot
/// assert (same fail-closed contract as [alignPlatformIdentity]).
void alignReleaseSigningGate({required String appPath}) {
  final sep = Platform.pathSeparator;
  final gradleFile = File(
    '$appPath${sep}android${sep}app${sep}build.gradle.kts',
  );
  if (!gradleFile.existsSync()) {
    throw StateError('alignReleaseSigningGate: missing ${gradleFile.path}');
  }
  final original = gradleFile.readAsStringSync();
  final usesCrlf = original.contains('\r\n');
  final text = original.replaceAll('\r\n', '\n');

  const gateMarkers = <String>[
    '_releaseSigningKeys',
    'signingConfigs.getByName("release")',
    'isCoreLibraryDesugaringEnabled = true',
    'coreLibraryDesugaring(',
  ];
  final markerCount = gateMarkers.where(text.contains).length;
  if (markerCount == gateMarkers.length) {
    // Already gated: leave the file byte-untouched (idempotent).
    return;
  }
  if (markerCount != 0) {
    throw StateError(
      'alignReleaseSigningGate: ${gradleFile.path} has a HALF-applied '
      'RELEASE-1 gate ($markerCount/${gateMarkers.length} markers) - '
      'refusing to continue (fail-closed).',
    );
  }

  String replaceExactlyOnce(
    String source,
    String anchor,
    String replacement,
    String what,
  ) {
    final index = source.indexOf(anchor);
    if (index == -1 || source.indexOf(anchor, index + 1) != -1) {
      throw StateError(
        'alignReleaseSigningGate: expected exactly one $what in '
        '${gradleFile.path} - the flutter create baseline drifted from the '
        'pinned shape; re-pin the RELEASE-1 template in '
        'core_app/tool/whitelabel.dart instead of shipping an ungated shell '
        '(fail-closed).',
      );
    }
    return source.replaceFirst(anchor, replacement);
  }

  var out = text;
  out = replaceExactlyOnce(
    out,
    'JavaVersion.VERSION_17.toString()',
    'JavaVersion.VERSION_1_8.toString()',
    'kotlinOptions jvmTarget (Java 17)',
  );
  out = replaceExactlyOnce(
    out,
    _releaseGateStockCompileOptions,
    _releaseGateCompileOptions,
    'compileOptions block',
  );
  out = replaceExactlyOnce(
    out,
    _releaseGateStockReleaseBlock,
    _releaseGateReleaseBlock,
    'release buildTypes/signingConfigs block',
  );
  if (!out.startsWith('plugins {')) {
    throw StateError(
      'alignReleaseSigningGate: ${gradleFile.path} does not start with the '
      'stock "plugins {" block - cannot prepend the RELEASE-1 gate '
      '(fail-closed).',
    );
  }
  out = _releaseGateHeader + out;
  const stockTail = 'flutter {\n    source = "../.."\n}\n';
  if (!out.endsWith(stockTail)) {
    throw StateError(
      'alignReleaseSigningGate: ${gradleFile.path} does not end with the '
      'stock flutter { source = "../.." } block - cannot append the '
      'desugaring dependency (fail-closed).',
    );
  }
  out = out.substring(0, out.length - stockTail.length) + _releaseGateFooter;
  gradleFile.writeAsStringSync(usesCrlf ? out.replaceAll('\n', '\r\n') : out);
  print(
    'Aligned RELEASE-1 signing gate + core-library desugaring in '
    'android/app/build.gradle.kts.',
  );
}

/// W7.3 (BACKEND-2, 06-P1-6): the fixed, least-privilege Android permission
/// set every generated shell must declare. Nothing else: background /
/// foreground-service location have NO consuming feature (P-1) and are
/// stripped on (re)generation.
const List<String> _shellAndroidPermissions = <String>[
  'android.permission.INTERNET',
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.POST_NOTIFICATIONS',
];

/// Permissions that must NEVER appear in a generated shell (P-1).
const List<String> _forbiddenShellPermissions = <String>[
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_LOCATION',
];

/// W7.3/W9.11: the iOS usage descriptions every generated shell needs.
/// `{name}` is filled with the client's app name. Tracking (ATT) copy is
/// deliberately absent — the app performs no ad-tracking and
/// `NSUserTrackingUsageDescription` is stripped wherever found (W9.11).
const Map<String, String> _shellIosUsageDescriptions = <String, String>{
  'NSLocationWhenInUseUsageDescription':
      '{name} uses your location to find the nearest branch and show the '
      'correct menu and delivery options.',
  'NSCameraUsageDescription':
      '{name} uses your camera to attach a photo to your order or profile.',
  'NSPhotoLibraryUsageDescription':
      '{name} may access your photo library to attach images to your order.',
};

/// Returns the key name when [line] is a plist `<key>...</key>` line.
String? _plistKeyName(String line) =>
    RegExp(r'^\s*<key>([^<]+)</key>\s*$').firstMatch(line)?.group(1);

/// W7.3 (BACKEND-2): aligns the generated app's platform privacy layer with
/// the least-privilege contract: AndroidManifest.xml is rewritten to EXACTLY
/// [_shellAndroidPermissions] (idempotent: every pre-existing
/// `<uses-permission>` line is stripped first), Info.plist gains the
/// [_shellIosUsageDescriptions] entries (values from the client's app name;
/// existing values replaced in place) and loses any
/// `NSUserTrackingUsageDescription` (W9.11), and the W9-corrected
/// `PrivacyInfo.xcprivacy` template is copied byte-identical into
/// `ios/Runner`. Fail-closed: any missing structure throws — the generator
/// must never emit a shell whose privacy layer it cannot assert.
void alignPlatformPrivacy({
  required String appPath,
  required String displayName,
  required String xcprivacyTemplatePath,
}) {
  final sep = Platform.pathSeparator;

  final manifestFile = File(
    '$appPath${sep}android${sep}app${sep}src${sep}main${sep}AndroidManifest.xml',
  );
  if (!manifestFile.existsSync()) {
    throw StateError('alignPlatformPrivacy: missing ${manifestFile.path}');
  }
  final strippedManifest = manifestFile.readAsStringSync().replaceAll(
    RegExp(r'[ \t]*<uses-permission[^>]*/>\r?\n'),
    '',
  );
  for (final forbidden in _forbiddenShellPermissions) {
    if (strippedManifest.contains(forbidden)) {
      throw StateError(
        'alignPlatformPrivacy: forbidden permission survived the strip: '
        '$forbidden',
      );
    }
  }
  final openMatch = RegExp(r'<manifest[^>]*>').firstMatch(strippedManifest);
  if (openMatch == null) {
    throw StateError(
      'alignPlatformPrivacy: <manifest> element not found in '
      '${manifestFile.path}',
    );
  }
  final manifestBuffer = StringBuffer(
    strippedManifest.substring(0, openMatch.end),
  )..write('\n');
  for (final permission in _shellAndroidPermissions) {
    manifestBuffer.write('    <uses-permission android:name="$permission"/>\n');
  }
  // Drop the leading newline(s) left behind by the stripped lines so the
  // rewritten manifest is byte-identical on every (re)generation.
  manifestBuffer.write(
    strippedManifest
        .substring(openMatch.end)
        .replaceFirst(RegExp(r'^(\r?\n)+'), ''),
  );
  manifestFile.writeAsStringSync(manifestBuffer.toString());

  // Belt-and-suspenders: the rewritten manifest must declare EXACTLY the
  // fixed safe set (proves the strip + insert round-trip, not just input).
  final writtenPermissions = RegExp('android:name="([^"]+)"')
      .allMatches(manifestFile.readAsStringSync())
      .map((m) => m.group(1)!)
      .where((name) => name.startsWith('android.permission.'))
      .toSet();
  final expectedPermissions = _shellAndroidPermissions.toSet();
  if (writtenPermissions.length != expectedPermissions.length ||
      !writtenPermissions.containsAll(expectedPermissions)) {
    throw StateError(
      'alignPlatformPrivacy: rewritten manifest permission set mismatch: '
      '$writtenPermissions',
    );
  }

  final plistFile = File('$appPath${sep}ios${sep}Runner${sep}Info.plist');
  if (!plistFile.existsSync()) {
    throw StateError('alignPlatformPrivacy: missing ${plistFile.path}');
  }
  var plistLines = plistFile.readAsLinesSync();
  // W9.11: a stale tracking usage description must never survive into a
  // generated shell (key + its <string> value are dropped together).
  final cleaned = <String>[];
  for (var i = 0; i < plistLines.length; i++) {
    if (_plistKeyName(plistLines[i]) == 'NSUserTrackingUsageDescription') {
      if (i + 1 < plistLines.length &&
          plistLines[i + 1].trim().startsWith('<string>')) {
        i++;
      }
      continue;
    }
    cleaned.add(plistLines[i]);
  }
  plistLines = cleaned;

  final dictIndex = plistLines.indexWhere((line) => line.trim() == '<dict>');
  if (dictIndex == -1 || dictIndex + 1 >= plistLines.length) {
    throw StateError(
      'alignPlatformPrivacy: outer <dict> not found in ${plistFile.path}',
    );
  }
  final firstChild = plistLines[dictIndex + 1];
  final lt = firstChild.indexOf('<');
  final indent = lt == -1 ? '\t' : firstChild.substring(0, lt);
  final pending = <String>[];
  for (final entry in _shellIosUsageDescriptions.entries) {
    final value = entry.value.replaceFirst('{name}', displayName);
    final existing = plistLines.indexWhere(
      (line) => line.trim() == '<key>${entry.key}</key>',
    );
    if (existing != -1) {
      var valueIndex = -1;
      for (var i = existing + 1; i < plistLines.length; i++) {
        final trimmed = plistLines[i].trim();
        if (trimmed.startsWith('<key>')) break;
        if (trimmed.startsWith('<string>')) {
          valueIndex = i;
          break;
        }
      }
      if (valueIndex == -1) {
        throw StateError(
          'alignPlatformPrivacy: no <string> value after ${entry.key} in '
          '${plistFile.path}',
        );
      }
      final line = plistLines[valueIndex];
      final valueIndent = line.substring(0, line.indexOf('<'));
      plistLines[valueIndex] =
          '$valueIndent<string>${_xmlEscape(value)}</string>';
      continue;
    }
    pending
      ..add('$indent<key>${entry.key}</key>')
      ..add('$indent<string>${_xmlEscape(value)}</string>');
  }
  if (pending.isNotEmpty) {
    plistLines.insertAll(dictIndex + 1, pending);
  }
  plistFile.writeAsStringSync('${plistLines.join('\n')}\n');

  final xcprivacySource = File(xcprivacyTemplatePath);
  if (!xcprivacySource.existsSync()) {
    throw StateError(
      'alignPlatformPrivacy: missing PrivacyInfo template at '
      '$xcprivacyTemplatePath',
    );
  }
  File(
    '$appPath${sep}ios${sep}Runner${sep}PrivacyInfo.xcprivacy',
  ).writeAsBytesSync(xcprivacySource.readAsBytesSync());

  print(
    'Aligned platform privacy: Android = fixed safe set '
    '(${_shellAndroidPermissions.length} permissions), iOS usage strings = '
    '${_shellIosUsageDescriptions.length}, PrivacyInfo.xcprivacy copied.',
  );
}

/// G1 (p31): the font files every generated app must ship — the ONE list
/// the pubspec template's `assets/fonts/*.ttf` entries and the byte copy
/// stay 1:1 with (pinned by test/tool/whitelabel_p31_assets_test.dart).
const List<String> kTemplateFontFiles = <String>[
  'PlayfairDisplay-Regular.ttf',
  'PlayfairDisplay-Bold.ttf',
  'Inter-Regular.ttf',
  'Inter-Bold.ttf',
];

/// G1 (p31): byte-copies [kTemplateFontFiles] from the canonical
/// `core_app/tool/templates/fonts/` source into `<appPath>/assets/fonts/`.
/// Fails loudly rather than emitting a pubspec that declares assets which
/// do not exist (the pre-p31 defect: a fresh client shipped 4 missing TTFs).
void copyTemplateFonts({required Directory repoRoot, required String appPath}) {
  final sep = Platform.pathSeparator;
  final source = Directory(
    '${repoRoot.path}${sep}core_app${sep}tool${sep}templates${sep}fonts',
  );
  if (!source.existsSync()) {
    throw StateError(
      'copyTemplateFonts: canonical font source missing at ${source.path}',
    );
  }
  final target = Directory('$appPath${sep}assets${sep}fonts')
    ..createSync(recursive: true);
  for (final name in kTemplateFontFiles) {
    final file = File('${source.path}$sep$name');
    if (!file.existsSync()) {
      throw StateError('copyTemplateFonts: missing $name in ${source.path}');
    }
    File('${target.path}$sep$name').writeAsBytesSync(file.readAsBytesSync());
  }
}

/// G2 (p31): `--template` presets — only engine-read radius keys
/// (`AppTheme._themeFromConfig` consumes every path below), seeded into the
/// generated app's config copy for keys the client did NOT specify. Config
/// stays the single source of truth: a preset can never overwrite an
/// owner-chosen value.
const Map<String, Map<String, dynamic>> _kTemplateThemePresets = {
  'minimal': {
    'shape': {'cardRadius': 8.0, 'ctaRadius': 8.0, 'smallRadius': 6.0},
    'components': {
      'input': {'radius': 6.0},
      'chip': {'radius': 8.0},
    },
  },
  'modern': {
    'shape': {'cardRadius': 20.0, 'ctaRadius': 100.0, 'smallRadius': 10.0},
    'components': {
      'input': {'radius': 12.0},
      'chip': {'radius': 100.0},
    },
  },
  'classic': {
    'shape': {'cardRadius': 4.0, 'ctaRadius': 4.0, 'smallRadius': 4.0},
    'components': {
      'input': {'radius': 4.0},
      'chip': {'radius': 4.0},
    },
  },
};

/// Fills ONLY absent keys of [config]'s `theme` from the named preset —
/// [config] wins everywhere it already speaks. Throws [ArgumentError] on an
/// unknown preset instead of silently no-opping.
void applyTemplateThemePreset(Map<String, dynamic> config, String template) {
  final preset = _kTemplateThemePresets[template];
  if (preset == null) {
    throw ArgumentError.value(
      template,
      'template',
      'unknown preset (expected one of ${_kTemplateThemePresets.keys.join(', ')})',
    );
  }
  final theme = config.putIfAbsent('theme', () => <String, dynamic>{});
  if (theme is Map<String, dynamic>) {
    _fillMissingThemeValues(theme, preset);
  }
}

/// Recursively seeds [preset] values into [target] only where the key is
/// absent — nested maps merge, scalars never overwrite.
void _fillMissingThemeValues(
  Map<String, dynamic> target,
  Map<String, dynamic> preset,
) {
  for (final entry in preset.entries) {
    final existing = target[entry.key];
    if (existing is Map<String, dynamic>) {
      final nested = entry.value;
      if (nested is Map<String, dynamic>) {
        _fillMissingThemeValues(existing, nested);
      }
      continue;
    }
    if (existing != null) continue;
    target[entry.key] = entry.value;
  }
}

void main(List<String> args) async {
  final configPath = _flagValue(args, '--config');
  // G2 (p31): the preset applies ONLY when the operator passes --template —
  // a default run keeps the generated config byte-identical to the source.
  final templateExplicit = args.contains('--template');
  final template =
      _flagValue(args, '--template', fallback: 'minimal') ?? 'minimal';
  final dryRun = args.contains('--dry-run');
  final regenerate = args.contains('--regenerate');
  final allowUsdFallback = args.contains('--allow-usd-fallback');
  // p36 T-3 (A3): explicit opt-out of the fail-closed flutterfire gate.
  final skipFirebase = wantsSkipFirebase(args);

  if (configPath == null) {
    _printUsage();
    exit(64);
  }

  const allowedTemplates = <String>{'minimal', 'modern', 'classic'};
  if (!allowedTemplates.contains(template)) {
    print(
      'ERROR: --template must be one of $allowedTemplates (got "$template").',
    );
    exit(64);
  }

  final clientConfig = ClientConfig.load(configPath);
  final validationErrors = clientConfig.validate(
    allowUsdFallback: allowUsdFallback,
  );
  if (validationErrors.isNotEmpty) {
    print('ERROR: Invalid client config:');
    for (final error in validationErrors) {
      print('  - $error');
    }
    exit(65);
  }

  // UI-14 (p25) F-8: completeness findings are WARNINGS, never errors (L-P1)
  // — they never change the exit code and never change an emitted byte.
  for (final warning in clientConfig.completenessWarnings()) {
    print(warning);
  }

  final repoRoot = _findRepoRoot();
  final appDirName = clientConfig.packageName;
  final appAbsolutePath =
      '${repoRoot.path}${Platform.pathSeparator}apps${Platform.pathSeparator}$appDirName';

  print('==========================================================');
  print(' UI FACTORY GENERATOR v2');
  print('==========================================================');
  print('Repo root     : ${repoRoot.path}');
  print('Config source : ${clientConfig.path}');
  print('App name      : ${clientConfig.appName}');
  print('Bundle id     : ${clientConfig.bundleId}');
  print('Org           : ${clientConfig.organization}');
  print(
    'Template      : '
    '${templateExplicit ? '$template (theme preset, fill-missing)' : '(none — config as authored)'}',
  );
  print('Output app    : $appAbsolutePath');
  print('Dry run       : $dryRun');
  print('USD fallback  : $allowUsdFallback');
  print('Skip firebase  : $skipFirebase');
  print('==========================================================');

  if (dryRun) {
    print('DRY RUN - files that WOULD be created:');
    print('  $appAbsolutePath/ (flutter create)');
    print('  $appAbsolutePath/pubspec.yaml (core + core_ui path deps)');
    print('  $appAbsolutePath/assets/client_config.json (copied config)');
    print(
      '  $appAbsolutePath/assets/fonts/*.ttf (4 canonical font files, '
      'byte-copied — G1)',
    );
    print(
      '  $appAbsolutePath/tool/branding/app_icon.png '
      '(launcher master from config app.icon — p36 A4)',
    );
    print(
      '  $appAbsolutePath/flutter_launcher_icons.yaml + '
      'flutter_native_splash.yaml (branding stamp configs — p36 A4)',
    );
    if (templateExplicit) {
      print(
        '  Theme preset: --template $template (fills ABSENT theme radius '
        'keys only — G2)',
      );
    }
    print('  $appAbsolutePath/lib/main.dart (THIN: shared initCarnamaApp)');
    print('  $appAbsolutePath/lib/app/app.dart (GeneratedApp wrapper)');
    print('  $appAbsolutePath/lib/firebase_options.dart (ARCH-2 per-project)');
    print('  $appAbsolutePath/lib/app/client_config_loader.dart (W6.3/W6.1)');
    print('  $appAbsolutePath/lib/app/core_config_adapter.dart');
    print('  $appAbsolutePath/lib/app/demo_config.dart (DEMO_MODE define)');
    print('  $appAbsolutePath/lib/app/config_error_screen.dart (blocking)');
    print(
      '  Identity contract: applicationId == pbxproj PRODUCT_BUNDLE_IDENTIFIER'
      ' == ${clientConfig.bundleId} (enforced post-generation)',
    );
    print(
      '  $appAbsolutePath/backend/firestore.rules (template copy, per-project)',
    );
    print('  $appAbsolutePath/backend/storage.rules (template copy)');
    print(
      '  $appAbsolutePath/backend/firestore.indexes.json '
      '(template copy incl. the W3.6 composite)',
    );
    print(
      '  $appAbsolutePath/backend/.firebaserc '
      '(projects.default = ${clientConfig.firebaseProjectId})',
    );
    print(
      '  $appAbsolutePath/backend/firebase.json '
      '(functions.source -> shared core_app/functions)',
    );
    print(
      '  $appAbsolutePath/backend/DEPLOY.md '
      '(copy-paste deploy commands + new-project flutterfire line — p37 T-5)',
    );
    print(
      '  $appAbsolutePath/android/.../AndroidManifest.xml '
      '(fixed safe set: INTERNET, FINE/COARSE location, POST_NOTIFICATIONS)',
    );
    print(
      '  $appAbsolutePath/ios/Runner/Info.plist '
      '(location/camera/photo usage strings from app.name)',
    );
    print(
      '  $appAbsolutePath/ios/Runner/PrivacyInfo.xcprivacy '
      '(W9-corrected template copy)',
    );
    print('  $appAbsolutePath/test/helpers/router_test_harness.dart');
    print('  $appAbsolutePath/test/widget_test.dart');
    print('  $appAbsolutePath/test/constitution_guard_test.dart');
    print('  $appAbsolutePath/test/checkout_honesty_test.dart');
    print('  $appAbsolutePath/test/price_cents_guard_test.dart');
    print('  $appAbsolutePath/test/firebase_gate_test.dart');
    print('  $appAbsolutePath/test/demo_mode_wiring_test.dart');
    print('  $appAbsolutePath/test/route_walker_test.dart');
    print('  $appAbsolutePath/test/firebase_config_truth_test.dart');
    print('  $appAbsolutePath/test/platform_privacy_test.dart');
    print(
      '  $appAbsolutePath/test/stripe_android_gate_test.dart '
      '(p36 A5: FragmentActivity + Material theme pin)',
    );
    print('  $appAbsolutePath/integration_test/app_launch_test.dart');
    print(
      '  POST-GATES: branding tools (exit 75) + flutter test (exit 72) + '
      'flutter build apk --debug (exit 73) + flutterfire fail-closed '
      '(exit 74; --skip-firebase opt-out)',
    );
    print('DRY RUN - no files were modified.');
    return;
  }

  final generator = _Generator(
    repoRoot: repoRoot,
    clientConfig: clientConfig,
    template: templateExplicit ? template : null,
    appDirName: appDirName,
    regenerate: regenerate,
    skipFirebase: skipFirebase,
  );
  _Generator._checkConfigForbiddenTokens(clientConfig.path);
  await generator.run();
}

/// p36 T-1 (A1/S1, spec `WHITE_LABEL_p36_generator_grade.md`): gate the two
/// `flutter create` Android files flutter_stripe rejects, using the proven
/// [alignReleaseSigningGate] contract (pinned anchors, idempotent no-op,
/// anything-else = StateError fail-closed):
///
/// - `MainActivity.kt`: stock `FlutterActivity` -> `FlutterFragmentActivity`
///   (stock baseline = `git show d76bcdd2^`, gated bytes = shipped
///   `apps/halal_boyz/.../MainActivity.kt`, proven on device by
///   `stripe_android_gate_test` + the p34 boot session).
/// - every `res/values*/styles.xml`: the two plain `@android:style/*` parents
///   -> the shipped Material pins (`values*` ->
///   `Theme.MaterialComponents.Light.NoActionBar`, `values-night*` ->
///   `Theme.MaterialComponents.NoActionBar`) — a half-applied, mis-pinned or
///   unrecognized shape refuses to continue instead of shipping a shell whose
///   payment-sheet posture the generator cannot assert.
void alignStripeAndroidGate({required String appPath}) {
  final sep = Platform.pathSeparator;
  final mainDir = '$appPath${sep}android${sep}app${sep}src${sep}main';

  // ── MainActivity.kt: exactly one, stock or already-gated ──────────────────
  final kotlinRoot = Directory('$mainDir${sep}kotlin');
  if (!kotlinRoot.existsSync()) {
    throw StateError('alignStripeAndroidGate: missing ${kotlinRoot.path}');
  }
  final activities = kotlinRoot
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.kt'))
      .toList();
  if (activities.length != 1) {
    throw StateError(
      'alignStripeAndroidGate: expected exactly one MainActivity.kt under '
      '${kotlinRoot.path}, found ${activities.length} (fail-closed)',
    );
  }
  const gatedImport =
      'import io.flutter.embedding.android.FlutterFragmentActivity';
  const gatedClass = 'class MainActivity : FlutterFragmentActivity()';
  const stockImport = 'import io.flutter.embedding.android.FlutterActivity';
  const stockClass = 'class MainActivity : FlutterActivity()';
  final activityFile = activities.single;
  final activityText = activityFile.readAsStringSync();
  final gatedCount =
      (activityText.contains(gatedImport) ? 1 : 0) +
      (activityText.contains(gatedClass) ? 1 : 0);
  final stockCount =
      (activityText.contains(stockImport) ? 1 : 0) +
      (activityText.contains(stockClass) ? 1 : 0);
  if (gatedCount == 2 && stockCount == 0) {
    // Already gated: byte-untouched.
  } else if (gatedCount == 0 && stockCount == 2) {
    activityFile.writeAsStringSync(
      activityText
          .replaceFirst(stockImport, gatedImport)
          .replaceFirst(stockClass, gatedClass),
    );
  } else {
    throw StateError(
      'alignStripeAndroidGate: ${activityFile.path} is neither the stock '
      'flutter create baseline nor the gated shape '
      '(gated=$gatedCount stock=$stockCount); re-pin the template instead of '
      'shipping an ungated shell (fail-closed)',
    );
  }

  // ── styles.xml: every values*/ dir, exactly 2 stock -> 2 pinned ───────────
  const stockLight = '@android:style/Theme.Light.NoTitleBar';
  const stockBlack = '@android:style/Theme.Black.NoTitleBar';
  const pinLight = '@style/Theme.MaterialComponents.Light.NoActionBar';
  const pinDark = '@style/Theme.MaterialComponents.NoActionBar';
  final resDir = Directory('$mainDir${sep}res');
  if (!resDir.existsSync()) {
    throw StateError('alignStripeAndroidGate: missing ${resDir.path}');
  }
  final styleFiles = resDir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.split(sep).last.startsWith('values'))
      .map((d) => File('${d.path}${sep}styles.xml'))
      .where((f) => f.existsSync())
      .toList();
  if (styleFiles.isEmpty) {
    throw StateError(
      'alignStripeAndroidGate: no res/values*/styles.xml found under '
      '${resDir.path} (fail-closed)',
    );
  }
  int count(String haystack, String needle) =>
      haystack.split(needle).length - 1;
  for (final file in styleFiles) {
    final dirName = file.parent.path.split(sep).last;
    final pin = dirName.contains('night') ? pinDark : pinLight;
    final otherPin = pin == pinDark ? pinLight : pinDark;
    final text = file.readAsStringSync();
    final stock = count(text, stockLight) + count(text, stockBlack);
    final pinned = count(text, pin);
    final misplaced = count(text, otherPin);
    if (stock == 2 && pinned == 0 && misplaced == 0) {
      file.writeAsStringSync(
        text.replaceAll(stockLight, pin).replaceAll(stockBlack, pin),
      );
    } else if (stock == 0 && pinned == 2 && misplaced == 0) {
      // Already gated: byte-untouched.
    } else {
      throw StateError(
        'alignStripeAndroidGate: ${file.path} is neither the stock flutter '
        'create baseline nor the gated shape (stock=$stock pinned=$pinned '
        'misplaced=$misplaced); re-pin the template instead of shipping an '
        'ungated shell (fail-closed)',
      );
    }
  }
}

/// p36 T-6 (S7, discovered live by Attestation L — spec
/// `WHITE_LABEL_p36_generator_grade.md`): the stock `flutter create` root
/// `android/build.gradle.kts` has no AGP-8 namespace shim, so
/// `isar_flutter_libs 3.1.0+1` (pulled by the labs path dep) dies at
/// configuration with "Namespace not specified" under the pinned AGP 8.11.1.
/// Shipped shells carried the reflection hook by hand (ARCH-1 LEDGER,
/// `apps/halal_boyz/android/build.gradle.kts`) — the generator now emits it
/// under the proven [alignStripeAndroidGate] contract:
///
/// - stock `allprojects` anchor without the shim -> shim inserted after it,
/// - shim present (already shipped) -> byte-identical no-op,
/// - anything else -> StateError fail-closed.
void alignAndroidNamespaceShim({required String appPath}) {
  final sep = Platform.pathSeparator;
  final gradle = File('$appPath${sep}android${sep}build.gradle.kts');
  if (!gradle.existsSync()) {
    throw StateError('alignAndroidNamespaceShim: missing ${gradle.path}');
  }
  final raw = gradle.readAsStringSync();
  // `flutter create` on Windows emits CRLF; match on normalized LF and write
  // back in the file's own EOL style (byte-preserving for shipped shapes).
  final crlf = raw.contains('\r\n');
  final text = raw.replaceAll('\r\n', '\n');
  const marker = 'setNamespace.invoke(androidExt';
  if (text.contains(marker)) {
    // Already shimmed (shipped shape): byte-untouched.
    return;
  }
  const stockAnchor =
      'allprojects {\n'
      '    repositories {\n'
      '        google()\n'
      '        mavenCentral()\n'
      '    }\n'
      '}';
  final anchorAt = text.indexOf(stockAnchor);
  if (anchorAt < 0) {
    throw StateError(
      'alignAndroidNamespaceShim: ${gradle.path} is neither the stock '
      'flutter create baseline (allprojects anchor) nor the shimmed shape; '
      're-pin the template instead of shipping a shell that cannot build '
      'isar_flutter_libs (fail-closed)',
    );
  }
  const shim = '''
// AGP 8 namespace shim (p36 T-6, generator-owned since p36):
// `isar_flutter_libs 3.1.0+1` predates AGP 8's mandatory `namespace` and
// fails configuration under the pinned AGP 8.11.1 ("Namespace not
// specified"). This reflection hook injects the namespace from each
// subproject's manifest `package` attr when AGP never received one — the
// standard pre-AGP-8-plugin shim.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val methods = androidExt.javaClass.methods
        val getNamespace = methods.firstOrNull { it.name == "getNamespace" } ?: return@afterEvaluate
        if (getNamespace.invoke(androidExt) != null) return@afterEvaluate
        val setNamespace = methods.firstOrNull { it.name == "setNamespace" } ?: return@afterEvaluate
        val manifest = projectDir.resolve("src/main/AndroidManifest.xml")
        if (!manifest.exists()) return@afterEvaluate
        val pkg = Regex("package\\\\s*=\\\\s*\\"([^\\"]+)\\"")
            .find(manifest.readText())?.groupValues?.get(1) ?: return@afterEvaluate
        setNamespace.invoke(androidExt, pkg)
    }
}
''';
  final insertAt = anchorAt + stockAnchor.length;
  final out =
      '${text.substring(0, insertAt)}\n\n$shim${text.substring(insertAt)}';
  gradle.writeAsStringSync(crlf ? out.replaceAll('\n', '\r\n') : out);
}

/// p36 T-3 (A3/S2, spec `WHITE_LABEL_p36_generator_grade.md`): resolve the
/// debug-build Stripe publishable key fail-closed — platform env
/// `STRIPE_PUBLISHABLE_KEY` wins (the `run_integration_tests.ps1`
/// `pk_test_FAKE` precedent), then a real `pk_*` config value; placeholders
/// and empties throw instead of producing the p34 root-cause-2 boot that
/// dies in the fail-closed ConfigErrorScreen.
String resolveStripePublishableKey({
  required String configValue,
  Map<String, String> platformEnvironment = const {},
}) {
  final fromEnv = platformEnvironment['STRIPE_PUBLISHABLE_KEY'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (configValue.isNotEmpty &&
      configValue.startsWith('pk_') &&
      !configValue.contains('REPLACE_ME')) {
    return configValue;
  }
  throw StateError(
    'resolveStripePublishableKey: no usable Stripe publishable key - set the '
    'STRIPE_PUBLISHABLE_KEY environment variable or a real pk_* value at '
    'client_config environment.stripePublishableKey (fail-closed)',
  );
}

/// p36 T-3 (A3): the ONLY opt-out of the fail-closed flutterfire gate —
/// a failed `flutterfire configure` must exit 74, never warn-and-continue.
bool wantsSkipFirebase(List<String> args) => args.contains('--skip-firebase');

/// p36 T-4 (A4): emitted `flutter_launcher_icons.yaml` — the launcher master
/// sits at `tool/branding/` (outside the bundled assets tree); android + ios
/// both regenerate from it. The root key is mandatory: the tool reads
/// `yaml['flutter_launcher_icons']` (NoConfigFoundException without it).
String launcherIconsYaml({required String iconPath}) =>
    '''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "$iconPath"
  min_sdk_android: 21
''';

/// Converts the config's Dart-hex color (`0xRRGGBB` / `0xAARRGGBB`) to the
/// `#RRGGBB` form flutter_native_splash requires.
String _splashHex(String dartHex) {
  var value = dartHex.trim();
  if (value.startsWith('0x') || value.startsWith('0X')) {
    value = value.substring(2);
  }
  if (value.length == 8) {
    value = value.substring(2); // drop the leading alpha byte
  }
  return '#${value.toUpperCase()}';
}

/// p36 T-4 (A4): emitted `flutter_native_splash.yaml` — day color from
/// `theme.background.color`, night from `theme.darkTheme.background` with a
/// documented day-color fallback when the dark theme is unset (a
/// completeness warning, never an error — L-P1).
String nativeSplashYaml({
  required String dayDartHex,
  required String? nightDartHex,
}) {
  final day = _splashHex(dayDartHex);
  final night = nightDartHex == null || nightDartHex.trim().isEmpty
      ? day
      : _splashHex(nightDartHex);
  return '''
flutter_native_splash:
  color: "$day"
  color_dark: "$night"
  android: true
  ios: true
''';
}

/// p36 T-4 (A4): the two dev-only branding tools the emitted pubspec carries
/// — `flutter_launcher_icons` mirrors the `core_app` template's existing
/// dev-dependency; `flutter_native_splash` is pinned to **2.4.7** (meta
/// `^1.16.0`, verified against pub.dev) because 2.4.8 needs `meta ^1.18.0`
/// while this Flutter SDK's flutter_test pins meta 1.17.0 (the phase-1
/// attestation receipt captured that solver conflict live). Zero runtime
/// cost — generation-time tools only (§0 rule 3 bans RUNTIME deps).
const String generatorToolDevDependencies = '''
  flutter_launcher_icons: ^0.14.4
  flutter_native_splash: ^2.4.7
''';

/// W6.6 post-generation identity check: the Android `applicationId` and every
/// Runner-level iOS `PRODUCT_BUNDLE_IDENTIFIER` must equal `bundleId`, and
/// the `*.RunnerTests` targets must be exactly `<bundleId>.RunnerTests`.
/// Returns the list of violations (empty = pass). Reads real files so tests
/// can run it against fixtures AND the checked-in generated shell.
List<String> generatedIdentityErrors(String appPath, String bundleId) {
  final errors = <String>[];
  final sep = Platform.pathSeparator;

  final gradleFile = File(
    '$appPath${sep}android${sep}app${sep}build.gradle.kts',
  );
  if (!gradleFile.existsSync()) {
    errors.add('missing android/app/build.gradle.kts under $appPath');
  } else {
    final match = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradleFile.readAsStringSync());
    final applicationId = match?.group(1);
    if (applicationId == null) {
      errors.add('android/app/build.gradle.kts: applicationId not found');
    } else if (applicationId != bundleId) {
      errors.add(
        'android applicationId "$applicationId" != app.bundleId "$bundleId"',
      );
    }
  }

  final pbxFile = File(
    '$appPath${sep}ios${sep}Runner.xcodeproj${sep}project.pbxproj',
  );
  if (!pbxFile.existsSync()) {
    errors.add('missing ios/Runner.xcodeproj/project.pbxproj under $appPath');
  } else {
    final matches = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
    ).allMatches(pbxFile.readAsStringSync());
    if (matches.isEmpty) {
      errors.add('project.pbxproj: no PRODUCT_BUNDLE_IDENTIFIER found');
    }
    for (final match in matches) {
      final id = match.group(1)!.trim();
      if (id.endsWith('.RunnerTests')) {
        if (id != '$bundleId.RunnerTests') {
          errors.add('pbxproj RunnerTests id "$id" != "$bundleId.RunnerTests"');
        }
      } else if (id != bundleId) {
        errors.add(
          'pbxproj PRODUCT_BUNDLE_IDENTIFIER "$id" != app.bundleId "$bundleId"',
        );
      }
    }
  }
  return errors;
}

/// W7.1 (09-P0-FB-1) — writes the per-client backend bundle into
/// `<appPath>/backend/`: byte-identical template copies of `firestore.rules`,
/// `storage.rules` and `firestore.indexes.json` (single-sourced from
/// `core_app/` so the shipped bundle can never drift from the template tree,
/// including the W3.6 `orders(status, createdAt)` composite), plus
/// `.firebaserc` (`projects.default = <projectId>`) and `firebase.json` whose
/// `functions.source` points at the SHARED `core_app/functions` directory
/// (the deploy NEVER carries a per-brand function copy — every client deploys
/// the exact code the money/rules waves ship).
///
/// Returns the absolute paths of the files written so callers/tests can
/// assert the whole bundle.
List<String> writeBackendBundle({
  required String appPath,
  required Directory repoRoot,
  required String projectId,
}) {
  if (projectId.trim().isEmpty) {
    throw ArgumentError('firebase.projectId must be non-empty (W6.1 gate).');
  }
  final sep = Platform.pathSeparator;
  final backendDir = Directory('$appPath${sep}backend');
  backendDir.createSync(recursive: true);
  final files = <String>[];
  final templateDir = '${repoRoot.path}${sep}core_app';

  for (final name in const <String>[
    'firestore.rules',
    'storage.rules',
    'firestore.indexes.json',
  ]) {
    final source = File('$templateDir${sep}$name');
    if (!source.existsSync()) {
      throw StateError(
        'Backend template file missing: ${source.path} — a backend bundle '
        'requires a complete core_app template tree.',
      );
    }
    final target = File('${backendDir.path}${sep}$name');
    target.writeAsStringSync(source.readAsStringSync());
    files.add(target.path);
  }

  const encoder = JsonEncoder.withIndent('  ');
  final firebaserc = File('${backendDir.path}${sep}.firebaserc');
  firebaserc.writeAsStringSync(
    '${encoder.convert(<String, dynamic>{
      'projects': <String, dynamic>{'default': projectId},
    })}\n',
  );
  files.add(firebaserc.path);

  // The bundle carries no function source; `functions.source` resolves to the
  // shared monorepo implementation relative to the backend dir
  // (`apps/<dir>/backend/../../core_app/functions`).
  final firebaseJson = File('${backendDir.path}${sep}firebase.json');
  firebaseJson.writeAsStringSync(
    '${encoder.convert(<String, dynamic>{
      'functions': <String, dynamic>{
        'source': '../../core_app/functions',
        'predeploy': <String>['npm --prefix "\$RESOURCE_DIR" run build'],
      },
      'firestore': <String, dynamic>{'rules': 'firestore.rules', 'indexes': 'firestore.indexes.json'},
      'storage': <String, dynamic>{'rules': 'storage.rules'},
    })}\n',
  );
  files.add(firebaseJson.path);

  // p37 T-5 (R5): the runbook ships WITH the artifacts — exact commands
  // against the exact file set just written, plus the new-project flutterfire
  // line the old print-only flow never documented (vs --skip-firebase).
  final deployMd = File('${backendDir.path}${sep}DEPLOY.md');
  deployMd.writeAsStringSync('''
# Deploy the backend — `$projectId`

Generated by `tool/whitelabel.dart` (p37 T-5). Run every command from THIS
directory (`backend/`), where `firebase.json` and `.firebaserc` live.

## One-time setup

    firebase login

## Deploy rules, indexes, storage rules and functions

    firebase deploy --project $projectId

`firebase.json` routes `firestore.rules`, `firestore.indexes.json`,
`storage.rules` and the SHARED `core_app/functions` source (predeploy runs
the build); `.firebaserc` pins the default project. Split the deploy with
`--only firestore:rules,firestore:indexes` when functions should not ride.

## New Firebase project?

    firebase login
    dart pub global activate flutterfire
    flutterfire configure --project=$projectId

Run `flutterfire configure` from the STAMPED APP ROOT — it rewrites
`lib/firebase_options.dart`. A stamp done with `--skip-firebase` deferred
exactly this step; complete it before first boot on a fresh project.
''');
  files.add(deployMd.path);

  print(
    'Wrote per-client backend bundle to ${backendDir.path} '
    '(project: $projectId):',
  );
  print(
    '  - firestore.rules / storage.rules / firestore.indexes.json '
    '(template copies)',
  );
  print('  - .firebaserc (projects.default = $projectId)');
  print('  - firebase.json (functions.source -> shared core_app/functions)');
  print('  - DEPLOY.md (copy-paste: firebase deploy --project $projectId)');
  return files;
}

/// p34 gen_proof / p36 A6 (S3-close): emit the native Firebase service files
/// from the config bundle.
///
/// The `--skip-firebase` lane never runs `flutterfire configure`, so the
/// generator itself must carry `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist` — otherwise the emitted
/// `firebase_config_truth_test.dart` (which reads both unconditionally) crashes
/// on a fresh stamp. Every value here is sourced from the SAME config the
/// emitted `lib/firebase_options.dart` uses (ARCH-2), so the three files mirror
/// each other by construction — exactly what the truth guard asserts. When a
/// real `flutterfire configure` later runs it overwrites these with the CLI's
/// equivalent per-project output (same identity).
void emitServiceFilesFromConfig({
  required String appPath,
  required Map<String, dynamic> config,
}) {
  String read(List<String> path) {
    dynamic node = config;
    for (final key in path) {
      if (node is Map && node[key] != null) {
        node = node[key];
      } else {
        return '';
      }
    }
    return node is String ? node : '';
  }

  final sep = Platform.pathSeparator;
  final bundleId = read(['app', 'bundleId']);
  final projectId = read(['firebase', 'projectId']);
  final androidAppId = read(['firebase', 'androidAppId']);
  final iosAppId = read(['firebase', 'iosAppId']);
  final messagingSenderId = read(['firebase', 'messagingSenderId']);
  final storageBucket = read(['firebase', 'storageBucket']);
  final iosClientId = read(['firebase', 'iosClientId']);
  final androidApiKey = read(['environment', 'firebaseAndroidApiKey']);
  final iosApiKey = read(['environment', 'firebaseIosApiKey']);

  // ── android/app/google-services.json ─────────────────────────────────────
  final googleServices = File(
    '$appPath${sep}android${sep}app${sep}google-services.json',
  );
  if (!googleServices.parent.existsSync()) {
    googleServices.parent.createSync(recursive: true);
  }
  googleServices.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'project_info': <String, dynamic>{'project_number': messagingSenderId, 'project_id': projectId, 'storage_bucket': storageBucket},
      'client': <Map<String, dynamic>>[
        <String, dynamic>{
          'client_info': <String, dynamic>{
            'mobilesdk_app_id': androidAppId,
            'android_client_info': <String, dynamic>{'package_name': bundleId},
          },
          'oauth_client': <dynamic>[],
          'api_key': <Map<String, dynamic>>[
            <String, dynamic>{'current_key': androidApiKey},
          ],
          'services': <String, dynamic>{
            'appinvite_service': <String, dynamic>{'other_platform_oauth_client': <dynamic>[]},
          },
        },
      ],
      'configuration_version': '1',
    })}\n',
  );
  print('Wrote native google-services.json -> ${googleServices.path}');

  // ── ios/Runner/GoogleService-Info.plist ──────────────────────────────────
  final plist = File(
    '$appPath${sep}ios${sep}Runner${sep}GoogleService-Info.plist',
  );
  if (Directory('$appPath${sep}ios').existsSync()) {
    if (!plist.parent.existsSync()) {
      plist.parent.createSync(recursive: true);
    }
    plist.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>$iosApiKey</string>
	<key>GCM_SENDER_ID</key>
	<string>$messagingSenderId</string>
	<key>PROJECT_ID</key>
	<string>$projectId</string>
	<key>STORAGE_BUCKET</key>
	<string>$storageBucket</string>
	<key>GOOGLE_APP_ID</key>
	<string>$iosAppId</string>
	<key>CLIENT_ID</key>
	<string>$iosClientId</string>
	<key>BUNDLE_ID</key>
	<string>$bundleId</string>
</dict>
</plist>
''');
    print('Wrote native GoogleService-Info.plist -> ${plist.path}');
  }
}

String? _flagValue(List<String> args, String flag, {String? fallback}) {
  final index = args.indexOf(flag);
  return (index == -1 || index + 1 >= args.length) ? fallback : args[index + 1];
}

/// Resolves a CLI command for [Process.run].
///
/// On Windows, `flutter`/`melos` are `.bat` shims that cannot be launched via
/// CreateProcess directly, so we route through `cmd /c`.
(String, List<String>) _resolvedCommand(String executable, List<String> args) {
  if (Platform.isWindows) {
    return ('cmd', ['/c', executable, ...args]);
  }
  return (executable, args);
}

void _printUsage() {
  print('Usage: dart run tool/whitelabel.dart --config <path> [options]');
  print('');
  print('Options:');
  print('  --config <path>     (required) Path to client_config.json');
  print('  --template <name>   (optional) minimal | modern | classic');
  print('                                 (default: minimal)');
  print('  --dry-run           Preview the generated app without writing.');
  print(
    '  --allow-usd-fallback\n'
    '                      Accept a missing "currency" section and fall back\n'
    '                      to USD (W6.4(5) owner opt-in; default: refuse).',
  );
}

Directory _findRepoRoot() {
  Directory? dir = File.fromUri(Platform.script).parent;
  while (dir != null) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    final core = Directory(
      '${dir.path}${Platform.pathSeparator}packages${Platform.pathSeparator}core',
    );
    if (pubspec.existsSync() && core.existsSync()) return dir;
    dir = dir.parent == dir ? null : dir.parent;
  }
  throw StateError(
    'Could not locate monorepo root (a directory containing pubspec.yaml and packages/core).',
  );
}

class _Generator {
  _Generator({
    required this.repoRoot,
    required this.clientConfig,
    required this.template,
    required this.appDirName,
    required this.regenerate,
    required this.skipFirebase,
  });

  final Directory repoRoot;
  final ClientConfig clientConfig;

  /// G2 (p31): null when `--template` was NOT passed — the generator then
  /// emits the source config byte-identical (no preset seeding).
  final String? template;
  final String appDirName;
  final bool regenerate;

  /// p36 T-3 (A3): false = a failed `flutterfire configure` exits 74 instead
  /// of the historical warn-and-continue fail-open (S3 fix); true = the
  /// operator explicitly attests from the config bundle (`--skip-firebase`).
  final bool skipFirebase;

  /// Identity tokens that must never be compiled into (or configured for) a
  /// white-label shell. Built from fragments so this generator source itself
  /// never contains the literal tokens (banned repo-wide by the grep gates).
  static const List<String> _forbiddenIdentity = <String>[
    'carnama_${'unsigned'}',
    '${'dcqf9'}qpsq',
    '${'192.168.1.'}100',
    '${'com.carnama.'}app',
    // W6.6: Carnama's live Firebase identity fragments. The sender-id
    // fragment also covers the app-id and iOS-client-id strings derived from
    // it ('1:<sender>:android:...' and '<sender>-...apps.googleusercontent...'),
    // so a copied Carnama `firebase` section can no longer pass the guard.
    '${'69700'}7956550',
    '${'resturants-'}8547d',
  ];

  /// Refuses to read a client config that still carries Carnama's live
  /// identity (Cloudinary cloud/preset, stale LAN IP, or the Carnama app id).
  /// A shell must FAIL FAST rather than silently target Carnama's live cloud.
  static void _checkConfigForbiddenTokens(String configPath) {
    final text = File(configPath).readAsStringSync();
    final hits = <String>[
      for (final token in _forbiddenIdentity)
        if (text.contains(token)) token,
    ];
    if (hits.isNotEmpty) {
      throw StateError(
        'Refusing to generate: client_config.json still contains forbidden '
        'identity values (${hits.join(', ')}). Per-client cloud credentials '
        'and the bundle id must be supplied by the restaurant owner.',
      );
    }
  }

  static final String _sep = Platform.pathSeparator;

  String get appPath => '${repoRoot.path}$_sep${'apps'}$_sep$appDirName';

  Directory get appDir => Directory(appPath);

  Future<void> run() async {
    if (appDir.existsSync() && !regenerate) {
      print('ERROR: Target app directory already exists: $appPath');
      print(
        '       Pass --regenerate to refresh an existing app from the '
        'fixed templates (the generator stays the only source of truth).',
      );
      exit(66);
    }
    if (appDir.existsSync()) {
      print('Regenerating existing app in place (--regenerate): $appPath');
    } else {
      await _createFlutterProject();
      _stripBoilerplateTODOs();
    }
    await _copyClientConfig();
    // p36 T-4 (A4): stage the launcher master at tool/branding/ before any
    // emission reads it (the emitted flutter_launcher_icons.yaml points here).
    _copyBrandingAssets();
    // G1 (p31): the pubspec template DECLARES four font assets — the bytes
    // must land with them or every fresh client ships missing-font text.
    copyTemplateFonts(repoRoot: repoRoot, appPath: appPath);
    _writeProjectFiles();
    // W6.6: platform identity must match the config BEFORE anything else
    // consumes the generated tree (idempotent on --regenerate).
    alignPlatformIdentity(
      appPath: appPath,
      bundleId: clientConfig.bundleId,
      displayName: clientConfig.appName,
    );
    // F-AUD2-15 / FIX-B8 T-3: `flutter create` owns this file's baseline, so
    // the RELEASE-1 signing gate + desugaring are re-applied here - a
    // regeneration can no longer revert them (idempotent, fail-closed).
    alignReleaseSigningGate(appPath: appPath);
    // p36 T-1 (A1): gate MainActivity + launch/normal themes for
    // flutter_stripe (FlutterFragmentActivity + MaterialComponents) — the
    // fail-closed fresh-stamp fix proven on device in the p34 boot session.
    alignStripeAndroidGate(appPath: appPath);
    // p36 T-6 (S7, found live by Attestation L): emit the AGP-8 namespace
    // shim into the root android/build.gradle.kts so isar_flutter_libs can
    // configure — without it every fresh stamp fails `flutter build`.
    alignAndroidNamespaceShim(appPath: appPath);
    // W7.3 (BACKEND-2): the platform privacy layer — fixed Android safe set,
    // iOS usage strings from app.name, and the W9-corrected privacy manifest
    // copy — must exist before the generated app is ever built. Idempotent
    // on --regenerate.
    alignPlatformPrivacy(
      appPath: appPath,
      displayName: clientConfig.appName,
      xcprivacyTemplatePath:
          '${repoRoot.path}${Platform.pathSeparator}core_app'
          '${Platform.pathSeparator}ios${Platform.pathSeparator}Runner'
          '${Platform.pathSeparator}PrivacyInfo.xcprivacy',
    );
    final identityErrors = generatedIdentityErrors(
      appPath,
      clientConfig.bundleId,
    );
    if (identityErrors.isNotEmpty) {
      print('ERROR: generated platform identity does not match app.bundleId:');
      for (final error in identityErrors) {
        print('  - $error');
      }
      exit(71);
    }
    print(
      'Identity check passed: applicationId == pbxproj == '
      '${clientConfig.bundleId}',
    );
    _writeBackendBundle();
    // p36 T-5 (S7): these guards used to be `!appDir.existsSync()` — dead
    // code, because flutter create already made the directory, so a fresh
    // stamp NEVER joined the workspace and `flutter pub get` failed with
    // `resolution: workspace` + no workspace root (phase-1 receipt
    // tool_uilib/p36/receipts/fresh_stamp_phase1.txt). Registration is
    // idempotent (skips an already-listed entry); melos runs only when
    // membership actually changed.
    final workspaceChanged = _registerWorkspacePackage();
    await _maybeRunFlutterFire();
    await _runPubGet();
    if (workspaceChanged) {
      await _runMelosBootstrap();
    }
    // p36 T-4 (A4): brand the stamp (icons + native splash) BEFORE the
    // analyze/test/build gates so a branding failure is caught in-generation.
    await _runBrandingTools();
    // p36 T-8 (S8, found live by Attestation L): flutter_native_splash's
    // `[Android] Updating styles...` step rewrites values-v31/styles.xml
    // AFTER alignStripeAndroidGate ran, re-introducing stock
    // `@android:style/*` parents — on API-31+ devices the rebuilt stamp
    // then dies in flutter_stripe ("Your theme isn't set to use
    // Theme.AppCompat or Theme.MaterialComponents") and boots the
    // fail-closed ConfigErrorScreen (receipts: fresh_stamp_phase1f.txt +
    // attest_stripe_theme_red.txt). Re-run the idempotent aligner so the
    // gate is the LAST writer of every styles.xml.
    alignStripeAndroidGate(appPath: appPath);
    final success = await _runAnalyze();
    if (!success) {
      print(
        'ANALYZE FAILED - generated app did not pass '
        'flutter analyze --fatal-infos. Stopping.',
      );
      exit(70);
    }
    // p36 A3 (S2 fix): analyze alone never proved the stamp works — the
    // emitted guard battery must run, and the debug APK must build with a
    // resolved Stripe publishable key, before the generator claims COMPLETE.
    await _runEmittedTests();
    await _buildDebugApk();
    print('UI FACTORY GENERATOR COMPLETE - app ready at $appPath');
  }

  Future<void> _createFlutterProject() async {
    print('Creating Flutter project (flutter create)...');
    final command = _resolvedCommand('flutter', [
      'create',
      '--org',
      clientConfig.organization,
      'apps/$appDirName',
    ]);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: repoRoot.path,
    );
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw StateError(
        'flutter create failed with exit code ${result.exitCode}',
      );
    }
    print('Project scaffolded.');
  }

  /// Removes the stock `// TODO:` comments that `flutter create` leaves in
  /// `android/app/build.gradle.kts` so the generated app contains no
  /// placeholder TODOs (verifier check 9).
  void _stripBoilerplateTODOs() {
    final gradleFile = File(
      '${appPath}$_sep${'android'}$_sep${'app'}$_sep${'build.gradle.kts'}',
    );
    if (!gradleFile.existsSync()) return;
    final lines = gradleFile
        .readAsLinesSync()
        .where((line) => !line.trim().startsWith('// TODO:'))
        .toList();
    gradleFile.writeAsStringSync('${lines.join('\n')}\n');
    print('Stripped Flutter boilerplate TODO comments from build.gradle.kts.');
  }

  Future<void> _copyClientConfig() async {
    final assetsDir = Directory('${appPath}$_sep${'assets'}');
    assetsDir.createSync(recursive: true);
    final configFile = File(
      '${appPath}$_sep${'assets'}${_sep}client_config.json',
    );
    configFile.writeAsStringSync(File(clientConfig.path).readAsStringSync());
    // G2 (p31): an explicit --template seeds only ABSENT theme keys into the
    // app's copy (fill-missing) — the source config is never rewritten and
    // an owner-chosen value can never be overwritten by a preset.
    final templateName = template;
    if (templateName != null) {
      final configJson =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      applyTemplateThemePreset(configJson, templateName);
      configFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(configJson)}\n',
      );
      print(
        'Seeded theme preset "$templateName" (fill-missing only) into the '
        'app config copy.',
      );
    }
    print(
      'Copied client_config.json to ${appPath}${_sep}assets${_sep}client_config.json',
    );
  }

  /// W7.1 (09-P0-FB-1) — emits the per-client backend bundle so a brand-new
  /// Firebase project can be provisioned exactly as the white-label contract
  /// expects (rules, indexes, storage rules, project default and the deploy
  /// `firebase.json`). Runs after the identity check; idempotent on
  /// `--regenerate`.
  void _writeBackendBundle() {
    writeBackendBundle(
      appPath: appPath,
      repoRoot: repoRoot,
      projectId: clientConfig.firebaseProjectId,
    );
  }

  void _writeProjectFiles() {
    print('Writing project files...');
    void write(String relative, String content) {
      final file = File('${appPath}$_sep$relative');
      file.parent.createSync(recursive: true);
      // The file templates are r''' strings whose content starts with a
      // newline right after the opening quotes. Strip that leading newline
      // so a regenerated file is byte-identical to the checked-in mirror
      // (which starts directly with its first line).
      final normalized = content.startsWith('\n')
          ? content.substring(1)
          : content;
      file.writeAsStringSync(normalized);
    }

    write('pubspec.yaml', _pubspecTemplate());
    write('${'lib'}$_sep${'main.dart'}', _mainTemplate());
    write('${'lib'}$_sep${'app'}${_sep}app.dart', _appTemplate());
    // ARCH-2: the per-project firebase_options.dart (values from THIS
    // client_config.json — the same identity the W6.1 gate and the shell's
    // firebase_config_truth_test pin against the native google-services
    // files; a later `flutterfire configure` run may overwrite it with the
    // CLI's equivalent per-project file).
    write(
      '${'lib'}$_sep${'firebase_options.dart'}',
      _firebaseOptionsTemplate(),
    );
    // W6.3/W6.1: the shell's config loader + fail-closed key gate lives in
    // its own file so lib/main.dart stays a THIN wrapper over the shared
    // initCarnamaApp (ARCH-2 spec acceptance contract 3).
    write(
      '${'lib'}$_sep${'app'}${_sep}client_config_loader.dart',
      _clientConfigLoaderTemplate(),
    );
    write(
      '${'lib'}$_sep${'app'}${_sep}core_config_adapter.dart',
      _coreConfigAdapterTemplate(),
    );
    // DEMO_MODE mirror — single-sourced byte-identical from core_app so the
    // shell's kDemoMode can never drift from the template app's.
    write(
      '${'lib'}$_sep${'app'}${_sep}demo_config.dart',
      _demoConfigTemplate(),
    );
    write(
      '${'lib'}$_sep${'app'}${_sep}config_error_screen.dart',
      _configErrorScreenTemplate(),
    );
    // p36 T-4 (A4): stamp configs — launcher icons + native splash driven
    // from the client theme (the same dev-only tools the core_app template
    // already ships); run by _runBrandingTools before the analyze gate.
    write(
      'flutter_launcher_icons.yaml',
      launcherIconsYaml(iconPath: 'tool/branding/app_icon.png'),
    );
    write(
      'flutter_native_splash.yaml',
      nativeSplashYaml(
        dayDartHex: clientConfig.themeBackgroundColor,
        nightDartHex: clientConfig.themeDarkBackgroundColor,
      ),
    );
    write(
      '${'test'}${_sep}helpers${_sep}router_test_harness.dart',
      _routerTestHarnessTemplate(),
    );
    write('${'test'}${_sep}widget_test.dart', _widgetTestTemplate());
    write(
      '${'test'}${_sep}constitution_guard_test.dart',
      _constitutionGuardTestTemplate(),
    );
    write(
      '${'test'}${_sep}checkout_honesty_test.dart',
      _checkoutHonestyTestTemplate(),
    );
    write(
      '${'test'}${_sep}price_cents_guard_test.dart',
      _priceCentsGuardTestTemplate(),
    );
    write(
      '${'test'}${_sep}firebase_gate_test.dart',
      _firebaseGateTestTemplate(),
    );
    write(
      '${'test'}${_sep}platform_privacy_test.dart',
      _platformPrivacyTestTemplate(),
    );
    // p36 A5: every fresh stamp carries the stripe Android gate — the S1
    // regression can never re-enter a generated shell silently.
    write(
      '${'test'}${_sep}stripe_android_gate_test.dart',
      _stripeAndroidGateTestTemplate(),
    );
    write(
      '${'test'}${_sep}demo_mode_wiring_test.dart',
      _demoModeWiringTestTemplate(),
    );
    write('${'test'}${_sep}route_walker_test.dart', _routeWalkerTestTemplate());
    write(
      '${'test'}${_sep}firebase_config_truth_test.dart',
      _firebaseConfigTruthTestTemplate(),
    );
    write(
      '${'integration_test'}${_sep}app_launch_test.dart',
      _appLaunchTestTemplate(),
    );
    print('Wrote pubspec.yaml, main.dart (thin), app/app.dart (thin wrapper),');
    print(
      'firebase_options.dart (per-project), app/client_config_loader.dart,',
    );
    print(
      'core_config_adapter.dart, demo_config.dart, config_error_screen.dart,',
    );
    print('and the generated test set (router harness, widget, firebase gate,');
    print('guards, privacy, wiring, truth, app-launch).');
  }

  /// p36 T-5 (S7): returns true when a NEW workspace entry was inserted
  /// (melos must then sync); false when already listed / not registrable.
  bool _registerWorkspacePackage() {
    final rootPubspec = File('${repoRoot.path}$_sep${'pubspec.yaml'}');
    if (!rootPubspec.existsSync()) {
      print('WARNING: Root pubspec.yaml not found; cannot register workspace.');
      return false;
    }
    final content = rootPubspec.readAsStringSync();
    const marker = '- core_app';
    final entry = '- apps/$appDirName';
    if (content.contains(entry)) return false;
    if (content.contains(marker)) {
      rootPubspec.writeAsStringSync(
        content.replaceFirst(marker, '$marker\n  $entry'),
      );
      print('Registered apps/$appDirName in root pubspec workspace.');
      return true;
    } else {
      print('WARNING: Root pubspec.yaml has no "- core_app" marker.');
      return false;
    }
  }

  Future<void> _maybeRunFlutterFire() async {
    if (skipFirebase) {
      print(
        'SKIP (--skip-firebase): flutterfire configure not run; emitting the '
        'config-bundle google-services files (p36 A6).',
      );
      emitServiceFilesFromConfig(appPath: appPath, config: clientConfig.raw);
      return;
    }
    final projectId = clientConfig.firebaseProjectId;
    if (projectId.isEmpty) {
      print(
        'No firebase.projectId in config - skipping flutterfire configure.',
      );
      return;
    }
    print('firebase.projectId present - running flutterfire configure...');
    try {
      final command = _resolvedCommand('flutterfire', [
        'configure',
        '--project=$projectId',
        '--yes',
      ]);
      final result = await Process.run(
        command.$1,
        command.$2,
        workingDirectory: appPath,
      );
      print(result.stdout);
      if (result.exitCode != 0) {
        print(result.stderr);
        print(
          'ERROR: flutterfire configure failed (exit ${result.exitCode}) - a '
          'stamp without google-services files can never boot. Fix the '
          'Firebase project/login, or attest from the config bundle with '
          '--skip-firebase (p36 A3 fail-closed, exit 74).',
        );
        exit(74);
      }
    } catch (error) {
      print(
        'ERROR: flutterfire not available ($error) - a stamp without '
        'google-services files can never boot. Install flutterfire, or attest '
        'from the config bundle with --skip-firebase (p36 A3, exit 74).',
      );
      exit(74);
    }
    await _ensureAppleServiceFiles();
  }

  /// p36 T-6 (D2): flutterfire_cli gates EVERY Apple service-file write
  /// behind `Platform.isMacOS` (`config.dart`: `appleValidation` plus the
  /// ios/macos `FirebaseJsonWrites` blocks), so a Windows/Linux host gets
  /// `google-services.json` + `firebase_options.dart` but never
  /// `ios/Runner/GoogleService-Info.plist` — and the emitted
  /// `firebase_config_truth_test.dart` hard-crashes loading it (phase-1
  /// receipt `tool_uilib/p36/receipts/fresh_stamp_phase1c.txt`).
  /// `flutterfire reconfigure` IS the cross-platform writer
  /// (`reconfigure.dart:_updateServiceFile` has no platform gate) but only
  /// acts when `firebase.json` carries a `flutter.platforms.ios` fileOutput
  /// entry — so patch that entry from the dart configurations, run
  /// reconfigure, then verify the plist exists fail-closed.
  Future<void> _ensureAppleServiceFiles() async {
    if (!Directory('${appPath}${_sep}ios').existsSync()) {
      return; // stamp carries no iOS platform - nothing to configure
    }
    final plist = File(
      '${appPath}${_sep}ios${_sep}Runner${_sep}GoogleService-Info.plist',
    );
    if (plist.existsSync()) {
      return; // a macOS host already got it from `flutterfire configure`
    }
    final firebaseJson = File('${appPath}${_sep}firebase.json');
    if (firebaseJson.existsSync()) {
      final map =
          jsonDecode(firebaseJson.readAsStringSync()) as Map<String, dynamic>;
      final flutterMap = map['flutter'] as Map?;
      final platforms = flutterMap?['platforms'] as Map?;
      final dartConfig =
          (platforms?['dart'] as Map?)?['lib/firebase_options.dart'] as Map?;
      final configurations = dartConfig?['configurations'] as Map?;
      final iosAppId = configurations?['ios'];
      final projectId = dartConfig?['projectId'];
      if (iosAppId is String &&
          iosAppId.isNotEmpty &&
          projectId is String &&
          projectId.isNotEmpty) {
        final iosPlatform = Map<String, dynamic>.from(
          (platforms!['ios'] as Map?) ?? const <String, dynamic>{},
        );
        final defaultEntry = Map<String, dynamic>.from(
          (iosPlatform['default'] as Map?) ?? const <String, dynamic>{},
        );
        if (defaultEntry['fileOutput'] == null) {
          defaultEntry['projectId'] = projectId;
          defaultEntry['appId'] = iosAppId;
          defaultEntry['fileOutput'] = 'ios/Runner/GoogleService-Info.plist';
          iosPlatform['default'] = defaultEntry;
          platforms['ios'] = iosPlatform;
          firebaseJson.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(map),
          );
          print(
            'iOS service-file entry patched into firebase.json - running '
            'flutterfire reconfigure (the cross-platform Apple writer)...',
          );
          // One bounded retry: the phase-1e receipt captured a single
          // transient `firebase --version` failure in this exact chain
          // (the identical command succeeded on direct invocation).
          // The retry never masks anything - the plist existence check
          // below is the actual gate.
          var reconfigured = false;
          for (var attempt = 1; attempt <= 2 && !reconfigured; attempt++) {
            try {
              final command = _resolvedCommand('flutterfire', ['reconfigure']);
              final result = await Process.run(
                command.$1,
                command.$2,
                workingDirectory: appPath,
              );
              print(result.stdout);
              if (result.exitCode == 0) {
                reconfigured = true;
                break;
              }
              print(result.stderr);
              print(
                'flutterfire reconfigure attempt $attempt failed '
                '(exit ${result.exitCode})...',
              );
            } catch (error) {
              print('flutterfire reconfigure attempt $attempt threw: $error');
            }
          }
          if (!reconfigured) {
            print(
              'ERROR: flutterfire reconfigure failed after 2 attempts - the '
              'iOS GoogleService-Info.plist would be missing (p36 T-6 '
              'fail-closed, exit 74).',
            );
            exit(74);
          }
        }
      }
    }
    if (!plist.existsSync()) {
      print(
        'ERROR: ios/Runner/GoogleService-Info.plist is still missing - the '
        'emitted firebase_config_truth_test.dart can never pass and the app '
        'cannot boot on iOS (p36 T-6 fail-closed, exit 74). Fix: run '
        '`flutterfire configure` on a macOS host, or provide the plist '
        'before generation.',
      );
      exit(74);
    }
  }

  Future<void> _runPubGet() async {
    print('Running flutter pub get in the generated app...');
    final command = _resolvedCommand('flutter', ['pub', 'get']);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: appPath,
    );
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw StateError(
        'flutter pub get failed with exit code ${result.exitCode}',
      );
    }
  }

  Future<void> _runMelosBootstrap() async {
    print('Running melos bootstrap...');
    final command = _resolvedCommand('dart', ['run', 'melos', 'bootstrap']);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: repoRoot.path,
    );
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw StateError(
        'melos bootstrap failed with exit code ${result.exitCode}',
      );
    }
  }

  Future<bool> _runAnalyze() async {
    print('Running dart format on the generated app...');
    final fmtCommand = _resolvedCommand('dart', ['format', appPath]);
    final fmtResult = await Process.run(
      fmtCommand.$1,
      fmtCommand.$2,
      workingDirectory: repoRoot.path,
    );
    if (fmtResult.exitCode != 0) {
      print(fmtResult.stderr);
      print('WARN: dart format exited ${fmtResult.exitCode} (continuing).');
    }
    print('Running flutter analyze --fatal-infos on the generated app...');
    final command = _resolvedCommand('flutter', ['analyze', '--fatal-infos']);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: appPath,
    );
    print(result.stdout);
    if (result.exitCode != 0) print(result.stderr);
    return result.exitCode == 0;
  }

  // ── File templates ───────────────────────────────────────────────

  /// p36 A3 gate 1 (exit 72): execute the guard battery the generator itself
  /// emits — a stamp whose own guards are red never reports COMPLETE.
  Future<void> _runEmittedTests() async {
    print('Running the emitted guard battery (flutter test)...');
    final command = _resolvedCommand('flutter', ['test']);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: appPath,
    );
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      print(
        'EMITTED TESTS FAILED (exit ${result.exitCode}) - a stamp whose own '
        'guards are red never ships (p36 A3, exit 72).',
      );
      exit(72);
    }
  }

  /// p36 A3 gate 2 (exit 73): prove the shell builds for Android with a
  /// resolved Stripe publishable key (p34 root-cause-2 can no longer hide
  /// behind an analyze-only completion signal).
  Future<void> _buildDebugApk() async {
    final stripeKey = resolveStripePublishableKey(
      configValue: clientConfig.stripePublishableKey,
      platformEnvironment: Platform.environment,
    );
    print('Building the debug APK (p36 A3 gate, stripe define resolved)...');
    final command = _resolvedCommand('flutter', [
      'build',
      'apk',
      '--debug',
      '--dart-define=STRIPE_PUBLISHABLE_KEY=$stripeKey',
    ]);
    final result = await Process.run(
      command.$1,
      command.$2,
      workingDirectory: appPath,
    );
    print(result.stdout);
    if (result.exitCode != 0) {
      print(result.stderr);
      print(
        'DEBUG APK BUILD FAILED (exit ${result.exitCode}) - the generator '
        'never completes on an unbuildable shell (p36 A3, exit 73).',
      );
      exit(73);
    }
  }

  /// p36 T-4 (A4): the launcher master lands at `tool/branding/` — outside
  /// the bundled assets tree, so the stamp ships the brand with zero APK
  /// asset cost. Fail-closed when the validated config's master can't copy.
  void _copyBrandingAssets() {
    final iconRef = clientConfig.iconAsset.trim();
    final normalized = iconRef.replaceAll('/', Platform.pathSeparator);
    final configPath = clientConfig.path.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    final configDir = configPath.substring(
      0,
      configPath.lastIndexOf(Platform.pathSeparator),
    );
    final source = File('$configDir${Platform.pathSeparator}$normalized');
    if (!source.existsSync()) {
      print(
        'ERROR: app.icon master missing at ${source.path} '
        '(p36 A4 fail-closed, exit 75).',
      );
      exit(75);
    }
    final target = File(
      '${appPath}${Platform.pathSeparator}tool'
      '${Platform.pathSeparator}branding${Platform.pathSeparator}'
      '${'app_icon.png'}',
    );
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(source.readAsBytesSync());
    print('Branding master copied -> ${target.path}');
  }

  /// p36 T-4 (A4, exit 75): regenerate launcher icons + native splash from
  /// the emitted stamp configs — a stamp that can't run its own branding
  /// tools never reports COMPLETE.
  Future<void> _runBrandingTools() async {
    for (final args in <List<String>>[
      ['flutter_launcher_icons'],
      ['flutter_native_splash:create'],
    ]) {
      print('Running dart run ${args.first} (p36 A4)...');
      final resolved = _resolvedCommand('dart', ['run', ...args]);
      final result = await Process.run(
        resolved.$1,
        resolved.$2,
        workingDirectory: appPath,
      );
      print(result.stdout);
      if (result.exitCode != 0) {
        print(result.stderr);
        print(
          'BRANDING TOOL ${args.first} FAILED (exit ${result.exitCode}) - '
          'branded icons and splash are a shipping requirement '
          '(p36 A4 fail-closed, exit 75).',
        );
        exit(75);
      }
    }
  }

  String _pubspecTemplate() =>
      '''
name: $appDirName
description: "Config-driven client app generated by the Carnama UI Factory."
publish_to: 'none'
resolution: workspace

version: 1.0.0+1

environment:
  sdk: ^3.8.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  core:
    path: ../../packages/core
  core_ui:
    path: ../../packages/core_ui

  # ARCH-1/ARCH-2: the shell imports the REAL screens/router/config and the
  # SHARED init (initCarnamaApp in app_bootstrap.dart) from the labs package
  # (core_app) — there are no local placeholder features/ or l10n/.
  labs:
    path: ../../core_app

  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  firebase_core: ^4.7.0
  firebase_auth: ^6.4.0
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  # Test-only seam for the GDPR consent chain (kGdprAnalyticsConsentKey):
  # the REAL home screen fires GdprConsentDialog.showIfNeeded on first land;
  # widget tests mock the prefs store (shared_preferences is already a
  # transitive runtime dependency of `labs` — declared here for the direct
  # test import).
  shared_preferences: any
${generatorToolDevDependencies}

flutter:
  uses-material-design: true
  assets:
    - assets/client_config.json
  fonts:
    - family: PlayfairDisplay
      fonts:
        - asset: assets/fonts/PlayfairDisplay-Regular.ttf
          weight: 400
        - asset: assets/fonts/PlayfairDisplay-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
''';

  // ── ARCH-2 template methods (the THIN shell) ───────────────────────────

  /// ARCH-2 (spec acceptance contract 3): the shell's main is a THIN WRAPPER
  /// over the SHARED init (`package:labs` `initCarnamaApp`) — the entire
  /// 16-step chain lives in `core_app/lib/app_bootstrap.dart`, so there is
  /// exactly ONE init sequence in the fleet. The shell supplies only its
  /// client inputs: its own per-project `firebase_options.dart`, the loaded
  /// `assets/client_config.json` (W6.3), the W6.1 fail-closed Firebase key
  /// gate (client-specific blocking screen) and the B7-2 identity fast-fail.
  String _mainTemplate() => r'''
import 'package:core/core.dart' show CoreConfigHolder;
import 'package:flutter/material.dart';
import 'package:labs/app_bootstrap.dart'
    show CarnamaBootstrap, initCarnamaApp;

import 'app/app.dart';
import 'app/client_config_loader.dart';
import 'app/config_error_screen.dart';
import 'app/core_config_adapter.dart';
import 'firebase_options.dart';

/// The generated shell's entry point (white-label fleet ARCH-2).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // W6.3: read assets/client_config.json without ever throwing.
  final loaded = await loadClientConfig();
  if (loaded.error != null) {
    debugPrint('client_config.json could not be loaded: ${loaded.error}');
  }

  // W6.1 fail-closed: without a REAL Firebase API key the shell renders a
  // blocking error screen and NEVER initializes Firebase (no auth,
  // Firestore, FCM). The old silent offline boot is gone.
  if (!firebaseKeyConfigured(loaded.config)) {
    debugPrint(
      'FATAL: Firebase API key missing or placeholder '
      '(environment.firebaseAndroidApiKey / environment.firebaseIosApiKey). '
      'Boot blocked - contact the operator.',
    );
    runApp(const ConfigErrorScreen());
    return;
  }

  // B7-2 identity fast-fail: a white-label shell without its OWN
  // app.bundleId must never boot (assert in debug, throw in release).
  final coreConfig = ClientCoreConfig(loaded.config);
  CoreConfigHolder.set(coreConfig);
  CoreConfigHolder.instance.clientId;

  // The SHARED 16-step init chain (package:labs app_bootstrap.dart) with
  // the shell's own inputs. The blocking-screen builder switches the boot
  // to the shell's FAIL-CLOSED policy: a missing key or a Firebase init
  // failure renders the screen — never a silent auth-less shell.
  await initCarnamaApp(
    bootstrap: CarnamaBootstrap(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      coreConfig: coreConfig,
      appBuilder: () => GeneratedApp(config: loaded.config),
      firebaseErrorScreenBuilder: ConfigErrorScreen.new,
    ),
  );
}
''';

  /// ARCH-2 (spec acceptance contract 4): the shell's `app/app.dart` is a THIN
  /// router-delegate over the REAL app widget — every screen, the 27-screen
  /// config-driven router, the config palette, and the full en+ar l10n come
  /// from `package:labs` (ARCH-1 barrel). The [config] parameter is retained
  /// because the shell's boot contract funnels the loaded
  /// `assets/client_config.json` through here and the generated tests pin the
  /// boot path against this widget.
  String _appTemplate() => r'''
import 'package:flutter/material.dart';
import 'package:labs/labs.dart';

/// The generated shell's app root — a THIN WRAPPER (white-label fleet
/// ARCH-1/ARCH-2).
///
/// The shell's own responsibility is `main.dart`: client config load +
/// fail-fast gates (W6.1/W6.3) + its per-project Firebase options. Every
/// SCREEN, the 27-screen config-driven router, the config palette, and the
/// full en+ar l10n come from the REAL app in `package:labs` (core_app).
/// The real app reads the SAME bundled config through the `AppConfig`
/// statics hydrated inside the shared `initCarnamaApp` (STEP 07), so the
/// client palette/typography/navigation registry flow into the real
/// screens.
class GeneratedApp extends StatelessWidget {
  const GeneratedApp({super.key, required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    return const CoreApp();
  }
}
''';

  /// The per-app `CoreConfig` adapter — updated by ARCH-2 to mirror the
  /// checked-in shell (the DEMO mirror: `isDemoMode` follows the build-time
  /// `kDemoMode` define, never the old hardcoded `false`).
  String _coreConfigAdapterTemplate() => r'''
import 'package:core/core.dart';

import 'demo_config.dart';

/// Per-app adapter between the client_config.json and the shared core config
/// interface. This is generated by the whitelabel generator — the ONLY source
/// of truth. Hand-edits drift and are overwritten on regeneration.
///
/// DEMO mirror (OPS-CONFIG-1 ADDENDUM-D): [isDemoMode] used to hardcode
/// `false`, which left every demo branch in packages/core dead in this shell.
/// It now mirrors `kDemoMode` (`app/demo_config.dart`), so the free-plan demo
/// (`--dart-define=DEMO_MODE=true`) routes callables to the local Dart mocks
/// exactly like core_app. ARCH-2: the shell's boot no longer references
/// `main.dart`'s guard — the shared `initCarnamaApp` (STEP 01) runs the
/// same `_assertSafeBuildConfig` for every app.
class ClientCoreConfig implements CoreConfig {
  const ClientCoreConfig(this.config);

  final Map<String, dynamic> config;

  String _environmentValue(String key, String fallback) {
    final environment = config['environment'];
    if (environment is Map<String, dynamic>) {
      final value = environment[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _appValue(String key, String fallback) {
    final app = config['app'];
    if (app is Map<String, dynamic>) {
      final value = app[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  // OFFLINE_FALLBACK: shell money display is config-driven. The currency code
  // comes from `config.currency.code` (ISO 4217, e.g. USD); the display symbol
  // is resolved by core_ui's money formatter — never hardcoded in shell code.
  String get currencyCode {
    final currency = config['currency'];
    if (currency is Map<String, dynamic>) {
      final value = currency['code'];
      if (value is String && value.isNotEmpty) return value;
    }
    return 'USD';
  }

  @override
  // DEMO mirror: was `=> false` (dead demo branches in the shell); now follows
  // the build-time DEMO_MODE define so packages/core's local Dart mocks engage
  // on the free plan (no Cloud Functions deployed). Release+demo is rejected
  // at startup (app_bootstrap.dart `_assertSafeBuildConfig`).
  bool get isDemoMode => kDemoMode;

  // P0-6: the tenant this generated shell belongs to. Same fail-fast shape as
  // `clientId`: a shell that cannot name its tenant must not boot pretending to
  // be one, but nothing reads this value yet (no behaviour change in P0).
  String get tenantId {
    final value = config['tenantId'];
    assert(value is String && value.isNotEmpty, 'tenantId missing');
    if (value is! String || value.isEmpty) {
      throw StateError(
        'tenantId missing — set tenantId in client_config.json',
      );
    }
    return value;
  }

  // OFFLINE_FALLBACK/B7-2: a white-label shell MUST carry its OWN bundle id in
  // `app.bundleId`. If the id is missing the shell fails FAST (assert in debug,
  // pristine StateError in release) — it can never silently inherit Carnama's
  // identity.
  @override
  String get clientId {
    final value = _appValue('bundleId', '');
    assert(value.isNotEmpty, 'client bundleId missing');
    if (value.isEmpty) {
      throw StateError(
        'client bundleId missing — set app.bundleId in client_config.json',
      );
    }
    return value;
  }

  // OFFLINE_FALLBACK: Cloudinary credentials default to EMPTY so a white-label
  // shell that misses config composition never silently uploads into the
  // reference app's live Cloudinary account. The app layer MUST inject the
  // real per-client credentials via the client_config.json `environment` block.
  @override
  String get cloudinaryUploadPreset =>
      _environmentValue('cloudinaryUploadPreset', '');

  @override
  String get cloudinaryCloudName =>
      _environmentValue('cloudinaryCloudName', '');

  @override
  List<String> get ownerEmails => const [];

  // OFFLINE_FALLBACK: kitchen LAN endpoint is per-restaurant business data.
  // The owner must supply their own terminal IP via the client_config.json
  // `environment` block (or Firestore `settings/restaurantConfig`). The empty
  // default means "not configured" — never a silently-accepted real endpoint.
  @override
  String get kitchenLanEndpoint => _environmentValue('kitchenLanEndpoint', '');
}
''';

  /// ARCH-2 (spec acceptance contract 4): the shell gets ITS OWN per-project
  /// `firebase_options.dart`, emitted from THIS client_config.json — the same
  /// identity values the W6.1 fail-closed gate and the shell's
  /// firebase_config_truth_test pin against the native google-services files.
  /// (A later `flutterfire configure` run may overwrite it with the CLI's
  /// equivalent per-project file; both carry the same project identity.)
  String _firebaseOptionsTemplate() =>
      '''
// GENERATED FILE — white-label fleet ARCH-2. Per-project Firebase options
// for this shell, emitted by the core_app tool/whitelabel.dart from the
// client's own client_config.json. Re-run the generator to refresh;
// hand-edits are overwritten on regeneration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for this shell's Firebase project
/// (${clientConfig.firebaseProjectId}).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '${clientConfig.firebaseAndroidApiKey}',
    appId: '${clientConfig.firebaseAndroidAppId}',
    messagingSenderId: '${clientConfig.firebaseMessagingSenderId}',
    projectId: '${clientConfig.firebaseProjectId}',
    storageBucket: '${clientConfig.firebaseStorageBucket}',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '${clientConfig.firebaseIosApiKey}',
    appId: '${clientConfig.firebaseIosAppId}',
    messagingSenderId: '${clientConfig.firebaseMessagingSenderId}',
    projectId: '${clientConfig.firebaseProjectId}',
    storageBucket: '${clientConfig.firebaseStorageBucket}',
  );
}
''';

  /// ARCH-2: the shell's W6.3 config loader + W6.1 key gate — extracted from
  /// the old monolithic main.dart into its own file so lib/main.dart stays a
  /// thin wrapper over the shared initCarnamaApp.
  String _clientConfigLoaderTemplate() => r'''
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

const String _clientConfigAsset = 'assets/client_config.json';

/// Documented placeholder fragments (mirrors the generator's validate()
/// gate, W6.1). A shell must never boot Firebase with a placeholder
/// credential, so the same vocabulary is rejected at runtime.
final RegExp _placeholderKeyPattern = RegExp(
  'REPLACE_ME|changeme|<your',
  caseSensitive: false,
);

/// The result of loading `assets/client_config.json`.
///
/// [config] is the decoded JSON object, or the empty map (the shell's
/// in-code defaults layer — every downstream consumer carries its own safe
/// fallbacks) when the asset is missing or malformed. [error] is the
/// recorded load error, or null on success (W6.3).
typedef LoadedClientConfig = ({Map<String, dynamic> config, Object? error});

/// Reads `assets/client_config.json` WITHOUT ever throwing (W6.3: core's
/// try/catch fallback pattern). A missing/malformed asset degrades to the
/// defaults layer with the error recorded, so the boot path can fail CLOSED
/// with an honest error screen instead of crashing.
Future<LoadedClientConfig> loadClientConfig({
  Future<String> Function(String assetKey)? readAsset,
}) async {
  try {
    final reader = readAsset ?? rootBundle.loadString;
    final raw = await reader(_clientConfigAsset);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return (config: decoded, error: null);
    }
    return (
      config: const <String, dynamic>{},
      error: StateError(
        'client_config.json: root must be a JSON object, '
        'got ${decoded.runtimeType}',
      ),
    );
  } catch (error) {
    return (config: const <String, dynamic>{}, error: error);
  }
}

/// True when the platform's Firebase API key is present and is not a
/// documented placeholder (W6.1 shell fail-fast gate) — evaluated against
/// the RAW config map (the resolved FirebaseOptions are merged by the
/// shared bootstrap, which delegates this same vocabulary check).
bool firebaseKeyConfigured(Map<String, dynamic> config) {
  final environment = config['environment'];
  if (environment is! Map<String, dynamic>) {
    return false;
  }
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final key =
      environment[isAndroid ? 'firebaseAndroidApiKey' : 'firebaseIosApiKey'];
  return key is String &&
      key.trim().isNotEmpty &&
      !_placeholderKeyPattern.hasMatch(key);
}
''';

  /// ARCH-2: `demo_config.dart` is single-sourced byte-identical from the
  /// template app (the DEMO_MODE dart-define contract can never drift).
  String _demoConfigTemplate() => File(
    '${repoRoot.path}$_sep${'core_app'}$_sep${'lib'}$_sep${'app'}'
    '$_sep${'config'}$_sep${'demo_config.dart'}',
  ).readAsStringSync();

  /// The shell's blocking W6.1 screen — ARCH-1/ARCH-2: the message key comes
  /// from the SHARED l10n in `package:labs` (the shell ARB set is gone).
  String _configErrorScreenTemplate() => r'''
import 'package:flutter/material.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Blocking boot screen shown when the shell cannot boot safely:
/// - the Firebase API key is missing or a documented placeholder (W6.1), or
/// - Firebase.initializeApp failed (fail-closed), or
/// - assets/client_config.json could not be loaded (W6.3).
///
/// The shell NEVER silently boots into an auth/Firestore/FCM-less UI; the
/// operator must supply the real per-client configuration.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.firebaseConfigMissing,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
''';

  /// BACKEND-2 (W7.3/T-2/T-5): platform privacy file assertions — the fixed
  /// Android safe set, the iOS usage descriptions, and the Apple privacy
  /// manifest (kept byte-identical with the checked-in shell's formatted file).
  String _platformPrivacyTestTemplate() => r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BACKEND-2 (W7.3, 06-P1-6): the generated shell's platform privacy layer.
/// FILE assertions — the shell must declare exactly the least-privilege
/// Android permission set, the iOS usage descriptions, and the Apple privacy
/// manifest. A release build without INTERNET cannot reach Firebase/Stripe;
/// background-location/foreground-service permissions have no consuming
/// feature and must never come back (P-1).
void main() {
  group('AndroidManifest.xml (fixed safe set, W7.3)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('exists', () {
      expect(
        manifest.existsSync(),
        isTrue,
        reason: 'android/app/src/main/AndroidManifest.xml must exist',
      );
    });

    test('declares the least-privilege permission set', () {
      final text = manifest.readAsStringSync();
      expect(
        text.contains('android.permission.INTERNET'),
        isTrue,
        reason:
            'the shell must reach Firebase/Stripe (release builds die '
            'without INTERNET)',
      );
      expect(
        text.contains('android.permission.ACCESS_FINE_LOCATION'),
        isTrue,
        reason: 'checkout delivery address detection needs fine location',
      );
      expect(
        text.contains('android.permission.ACCESS_COARSE_LOCATION'),
        isTrue,
      );
      expect(
        text.contains('android.permission.POST_NOTIFICATIONS'),
        isTrue,
        reason:
            'Android 13+ requires POST_NOTIFICATIONS to display FCM '
            'order/delivery notifications',
      );
    });

    test('never declares the forbidden permissions (P-1)', () {
      final text = manifest.readAsStringSync();
      expect(
        text.contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
        isFalse,
      );
      expect(text.contains('android.permission.FOREGROUND_SERVICE'), isFalse);
      expect(
        text.contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
        isFalse,
      );
    });
  });

  group('iOS privacy layer (W7.3/W9.11)', () {
    test('Info.plist carries the usage descriptions', () {
      final plist = File('ios/Runner/Info.plist');
      expect(
        plist.existsSync(),
        isTrue,
        reason: 'ios/Runner/Info.plist must exist',
      );
      final text = plist.readAsStringSync();
      expect(
        text.contains('NSLocationWhenInUseUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first location access without the string',
      );
      expect(
        text.contains('NSCameraUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first camera access without the string',
      );
      expect(
        text.contains('NSPhotoLibraryUsageDescription'),
        isTrue,
        reason: 'iOS aborts on first photo-library access without the string',
      );
      expect(
        text.contains('NSUserTrackingUsageDescription'),
        isFalse,
        reason: 'the app performs no ad-tracking (W9.11 removal)',
      );
    });

    test('PrivacyInfo.xcprivacy exists and is the W9-corrected manifest', () {
      final xcprivacy = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(
        xcprivacy.existsSync(),
        isTrue,
        reason: 'ios/Runner/PrivacyInfo.xcprivacy must exist',
      );
      final text = xcprivacy.readAsStringSync();
      expect(
        text.contains('NSPrivacyCollectedDataTypePurchaseHistory'),
        isTrue,
        reason: 'order history must be declared (W9.11)',
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypeOtherUsageData'),
        isTrue,
        reason: 'funnel analytics events must be declared (W9.11)',
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
        isTrue,
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypePurposeAnalytics'),
        isTrue,
      );
      expect(
        text.contains('NSPrivacyCollectedDataTypeEmailAddress'),
        isTrue,
        reason: 'account authentication collects email (W9.11 linked=true)',
      );
      expect(text.contains('NSPrivacyCollectedDataTypeName'), isTrue);
    });
  });
}
''';

  /// T-B9-1 identity guard — updated by ARCH-1/ARCH-2 to assert the shell
  /// carries no local identity (the checks below match the checked-in
  /// formatted file).
  String _constitutionGuardTestTemplate() => r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo-level guard (T-B9-1) that proves every generated adapter is free of
/// Carnama's live identity and uses empty, fail-fast defaults.
void main() {
  const carnamaPreset =
      'carnama_'
      'unsigned';
  const carnamaCloud =
      'dc'
      'qf9qpsq';
  const staleLan =
      '192.168.1.'
      '100';
  const carnamaAppId =
      'com.ca'
      'rnama.app';

  test('generated app never embeds the Carnama identity', () {
    final files = <String>['lib/app/core_config_adapter.dart', 'lib/main.dart'];
    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');
      final text = file.readAsStringSync();
      expect(
        text.contains(carnamaPreset),
        isFalse,
        reason: '$path must not embed the Carnama upload preset',
      );
      expect(
        text.contains(carnamaCloud),
        isFalse,
        reason: '$path must not embed the Carnama cloud name',
      );
      expect(
        text.contains(staleLan),
        isFalse,
        reason: '$path must not embed the stale LAN IP',
      );
      expect(
        text.contains(carnamaAppId),
        isFalse,
        reason: '$path must not fall back to the Carnama app id',
      );
    }
  });

  test('adapter defaults are empty, marked, and fail fast', () {
    final text = File('lib/app/core_config_adapter.dart').readAsStringSync();
    expect(
      text.contains('OFFLINE_FALLBACK'),
      isTrue,
      reason:
          'empty defaults must be documented with an OFFLINE_FALLBACK marker',
    );
    expect(
      text.contains('client bundleId missing'),
      isTrue,
      reason: 'a missing bundle id must fail fast, never silently fall back',
    );
  });
}
''';

  /// T-B9-2 checkout honesty — carried forward into the ARCH-1/ARCH-2
  /// architecture: the shell ships NO payment code of its own and its config
  /// carries only the documented placeholder payment key.
  String _checkoutHonestyTestTemplate() => r'''
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show CheckoutScreen;

/// T-B9-2 carried forward into the ARCH-1 architecture — the shell's
/// checkout is HONEST.
///
/// Pre-ARCH-1 the shell carried its own placeholder checkout with a
/// `merchantConfigured` honesty gate (disabled Place Order, no fake success).
/// ARCH-1 deletes every local screen: the checkout is now the REAL
/// `package:labs` `CheckoutScreen`, whose payment path is fail-closed by
/// construction — the money never fakes success:
///   * `CheckoutService.processStripePayment` returns null on a failed or
///     unconfigured charge and the order is never confirmed as paid
///     (behavioral proof: `core_app/test/features/checkout/` —
///     `chaos_checkout_test.dart`, `checkout_service_test.dart`,
///     `checkout_auth_guard_test.dart` — the shell cannot and must not
///     duplicate the payment service's cross-territory test suite);
///   * `DEMO_MODE` (simulated Stripe) is a build-time define, forbidden in
///     release by the shared `_assertSafeBuildConfig` (pinned by
///     `demo_mode_wiring_test.dart`).
/// What the SHELL must prove (and does below) is the inverse: it ships NO
/// payment code of its own, and its config carries ONLY the documented
/// placeholder payment key — so there is no fake credential and no fake
/// success to ship.
void main() {
  group('T-B9-2 (ARCH-1): shell checkout honesty', () {
    test('the REAL CheckoutScreen (labs) is the shell checkout — '
        'const-constructible, no local copy anywhere in shell lib', () {
      expect(const CheckoutScreen(), isA<CheckoutScreen>());

      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        final text = file.readAsStringSync();
        expect(
          text.contains('class CheckoutScreen'),
          isFalse,
          reason:
              '${file.path} must not declare a local checkout — '
              'the real one comes from package:labs',
        );
        expect(
          text.contains('processStripePayment'),
          isFalse,
          reason: '${file.path} must not contain shell-side payment logic',
        );
        expect(
          text.contains('merchantConfigured'),
          isFalse,
          reason:
              '${file.path} must not resurrect the deleted placeholder '
              'honesty param — the REAL checkout owns the money gate',
        );
      }
    });

    test('the shell config carries ONLY the documented REPLACE_ME payment '
        'placeholder — never a fake working key, never a live key', () {
      final config =
          jsonDecode(File('assets/client_config.json').readAsStringSync())
              as Map<String, dynamic>;
      final environment = config['environment'] as Map<String, dynamic>;
      final key = environment['stripePublishableKey'] as String;
      expect(
        key.contains('REPLACE_ME'),
        isTrue,
        reason:
            'the payment key must stay the documented placeholder until a '
            'real merchant account exists — honesty over fake green',
      );

      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(
          text.contains('pk_live') || text.contains('pk_test'),
          isFalse,
          reason:
              '${file.path} must never embed a Stripe publishable key '
              '(keys live in build defines / the ops config, never code)',
        );
      }
    });
  });
}
''';

  /// T-B9-3 money guard — carried forward into the ARCH-1/ARCH-2 architecture
  /// (the REAL formatter asserted against the shell's own fixtures).
  String _priceCentsGuardTestTemplate() => r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show formatCurrencyCents;

/// T-B9-3 carried forward into the ARCH-1 architecture — shell money is
/// canonical integer `priceCents` rendered through the canonical formatter;
/// floating-point money and resurrected `data['price']` reads must never
/// appear in shell code.
///
/// Pre-ARCH-1 the widget half of this guard pumped the shell's own
/// placeholder `MenuScreen` (6 hardcoded dishes). ARCH-1 deletes it: the
/// REAL `MenuScreen` streams the REAL Firestore menu and renders every
/// price through the SAME canonical formatter asserted below
/// (`formatCurrencyCents` — the single customer-facing money formatter,
/// W9.3). The money itself is proven integer-cents by the labs suite
/// (`core_app/test/features/menu/*`, `cart/*`,
/// `core_app/test/app/config/currency_format_test.dart`).
void main() {
  group('T-B9-3 (ARCH-1): the REAL money formatter (integer cents)', () {
    test('renders integer cents through the configured currency code', () {
      // The pre-ARCH-1 shell placeholder's own fixtures, now asserted
      // against the REAL production formatter from package:labs.
      expect(formatCurrencyCents(999, currencyCode: 'AED'), 'AED 9.99');
      expect(formatCurrencyCents(849, currencyCode: 'AED'), 'AED 8.49');
    });

    test(
      'groups thousands, handles negatives and the unknown-code fallback',
      () {
        expect(formatCurrencyCents(1250, currencyCode: 'USD'), r'$12.50');
        expect(
          formatCurrencyCents(1234567, currencyCode: 'USD'),
          r'$12,345.67',
        );
        // CLDR target (AUD1-02 + D-1): negative amounts render minus before symbol
        expect(formatCurrencyCents(-500, currencyCode: 'USD'), r'-$5.00');
        expect(formatCurrencyCents(0, currencyCode: 'USD'), r'$0.00');
        // CLDR target (AUD1-02 + D-1): unknown codes fail closed to CODE-prefix
        expect(formatCurrencyCents(100, currencyCode: 'XYZ'), 'XYZ 1.00');
      },
    );
  });

  test('no floating-point money or resurrected price field in shell code', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.contains('l10n') &&
              !f.path.endsWith('.freezed.dart'),
        )
        .toList();
    for (final file in files) {
      final text = file.readAsStringSync();
      expect(
        text.contains('price.toStringAsFixed'),
        isFalse,
        reason: '${file.path} must not format a double price',
      );
      expect(
        text.contains(
          "'"
          'US'
          'D '
          "'",
        ),
        isFalse,
        reason: '${file.path} must not hardcode a currency literal',
      );
      expect(
        text.contains('double total'),
        isFalse,
        reason: '${file.path} must not store money in a double',
      );
      expect(
        text.contains('double price'),
        isFalse,
        reason: '${file.path} must not store price in a double',
      );
      expect(
        text.contains('double amount'),
        isFalse,
        reason: '${file.path} must not store amount in a double',
      );
      expect(
        text.contains("data['price']"),
        isFalse,
        reason:
            '${file.path} must not resurrect the deprecated double `price` '
            'field — money is integer `priceCents` (Law 3)',
      );
    }
  });
}
''';

  /// W6.1 firebase gate — REWRITTEN by ARCH-2: the gate lives in the SHARED
  /// init (package:labs initCarnamaApp STEP 13); these tests drive the REAL
  /// production function (no mirror) with the shell's own blocking screen.
  String _firebaseGateTestTemplate() =>
      r'''
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app_bootstrap.dart' as shared
    show CarnamaBootstrap, firebaseKeyConfigured, initCarnamaApp;
import 'package:labs/labs.dart' show AppConfig;

import 'package:''' +
      appDirName +
      r'''/app/app.dart';
import 'package:''' +
      appDirName +
      r'''/app/client_config_loader.dart';
import 'package:''' +
      appDirName +
      r'''/app/config_error_screen.dart';
import 'package:''' +
      appDirName +
      r'''/app/core_config_adapter.dart';

/// W6.1: the shell boots FAIL-CLOSED. The Firebase key gate and the
/// Firebase-init failure path live in the SHARED 16-step init
/// (`package:labs` `initCarnamaApp`, STEP 13); the shell's thin `main.dart`
/// supplies its per-project options + the blocking `ConfigErrorScreen`
/// builder. W6.3: a missing/malformed client_config.json degrades to
/// defaults + a recorded error and must never crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FirebaseOptions options({String apiKey = 'AIzaSyA-real-android-key'}) =>
      FirebaseOptions(
        apiKey: apiKey,
        appId: 'present-app-id',
        messagingSenderId: '1234567890',
        projectId: 'client-project',
      );

  Map<String, dynamic> configWithKey(String key) => <String, dynamic>{
    'app': <String, dynamic>{
      'name': 'Client App',
      'bundleId': 'labs.client.app',
    },
    'currency': <String, dynamic>{'code': 'USD', 'symbol': ''},
    'environment': <String, dynamic>{
      'firebaseAndroidApiKey': key,
      'firebaseIosApiKey': key,
    },
    'firebase': <String, dynamic>{'projectId': 'client-project'},
    'navigation': <String, dynamic>{
      'entryPoint': '/',
      'routes': <String, dynamic>{
        'home': '/',
        'menu': '/menu',
        'cart': '/cart',
        'checkout': '/checkout',
      },
    },
    'theme': <String, dynamic>{
      'injection': 'local-config-file',
      'colors': <String, dynamic>{'primary': '0xFF2E7D32'},
    },
  };

  group('firebaseKeyConfigured — the SHARED resolved-options gate (W6.1)', () {
    test('rejects an empty resolved api key', () {
      expect(shared.firebaseKeyConfigured(options(apiKey: '')), isFalse);
    });

    test('rejects documented placeholders (case-insensitive)', () {
      expect(
        shared.firebaseKeyConfigured(options(apiKey: 'REPLACE_ME_API_KEY')),
        isFalse,
      );
      expect(
        shared.firebaseKeyConfigured(options(apiKey: 'please changeme now')),
        isFalse,
      );
      expect(
        shared.firebaseKeyConfigured(options(apiKey: '<your-api-key>')),
        isFalse,
      );
    });

    test('accepts a real key', () {
      expect(shared.firebaseKeyConfigured(options()), isTrue);
    });
  });

  group('loader firebaseKeyConfigured — the client_config.json gate (W6.1)',
      () {
    test('rejects an empty key', () {
      expect(firebaseKeyConfigured(configWithKey('')), isFalse);
    });

    test('rejects documented placeholders (case-insensitive)', () {
      expect(
        firebaseKeyConfigured(configWithKey('REPLACE_ME_API_KEY')),
        isFalse,
      );
      expect(
        firebaseKeyConfigured(configWithKey('please changeme now')),
        isFalse,
      );
      expect(firebaseKeyConfigured(configWithKey('<your-api-key>')), isFalse);
    });

    test('accepts a real key', () {
      expect(firebaseKeyConfigured(configWithKey('AIzaSyA-real-key')), isTrue);
    });

    test('rejects a config without an environment section', () {
      expect(firebaseKeyConfigured(<String, dynamic>{}), isFalse);
    });
  });

testWidgets(
    'empty firebase key blocks the SHARED init on ConfigErrorScreen and '
    'never initializes Firebase',
    (tester) async {
      AppConfig.resetForTest();
      final originalOnError = PlatformDispatcher.instance.onError;
      final originalErrorWidget = ErrorWidget.builder;
      try {
        // The REAL production boot function — with a placeholder-resolved
        // key the shell policy (blocking screen builder) must stop the boot
        // at STEP 13, BEFORE Firebase.initializeApp.
        //
        // tester.runAsync: the boot body performs REAL async I/O (asset
        // reads, logger file writes) that can never complete under the
        // test binding's fake async. runAsync escapes to the real event
        // loop — exactly like production — while keeping the resulting
        // widget tree inspectable afterwards.
        await tester.runAsync(
          () => shared.initCarnamaApp(
            bootstrap: shared.CarnamaBootstrap(
              firebaseOptions: options(apiKey: ''),
              coreConfig: const ClientCoreConfig(<String, dynamic>{
                'app': <String, dynamic>{'bundleId': 'labs.client.app'},
              }),
              appBuilder: () =>
                  const GeneratedApp(config: <String, dynamic>{}),
              firebaseErrorScreenBuilder: ConfigErrorScreen.new,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(ConfigErrorScreen), findsOneWidget);
        expect(find.byType(GeneratedApp), findsNothing);
        expect(
          Firebase.apps,
          isEmpty,
          reason: 'the blocked boot path must skip Firebase.initializeApp',
        );
      } finally {
        // flutter_test verifies at the end of the test body that the
        // error-widget builder is unset, so restore inline (addTearDown
        // runs too late for that verification).
        ErrorWidget.builder = originalErrorWidget;
        PlatformDispatcher.instance.onError = originalOnError;
        AppConfig.resetForTest();
      }
    },
  );

  group('loadClientConfig (W6.3 resilience)', () {
    test(
      'malformed JSON degrades to defaults + recorded error, no crash',
      () async {
        final loaded = await loadClientConfig(
          readAsset: (assetKey) async => '{ not valid json',
        );
        expect(loaded.config, isEmpty);
        expect(loaded.error, isA<FormatException>());
      },
    );

    test(
      'missing asset degrades to defaults + recorded error, no crash',
      () async {
        final loaded = await loadClientConfig(
          readAsset: (assetKey) =>
              throw StateError('asset not found: $assetKey'),
        );
        expect(loaded.config, isEmpty);
        expect(loaded.error, isA<StateError>());
      },
    );

    test('valid JSON parses through unchanged', () async {
      final loaded = await loadClientConfig(
        readAsset: (assetKey) async => '{"app": {"name": "Client App"}}',
      );
      expect(loaded.error, isNull);
      expect(loaded.config['app'], isA<Map<dynamic, dynamic>>());
    });
  });
}
''';

  /// ARCH-1 T-3 route-walker gate: the shell's REAL router must register
  /// exactly the config's whitelisted screens plus the ONE sanctioned DLQ ops
  /// route. Client identity (app name + navigation entry point) is pinned
  /// through interpolated constants emitted from the client config.
  String _routeWalkerTestTemplate() =>
      r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart'
    show AppConfig, RouteNames, appRouterProvider, screenIdToRouteName;

import 'helpers/router_test_harness.dart';
'''
      // ignore: prefer_adjacent_string_concatenation
      +
      "const kClientAppName = '${clientConfig.appName}';\n\n"
          "const kClientEntryPoint = '${clientConfig.navigationEntryPoint}';\n" +
      r'''
/// ARCH-1 T-3: the route-walker gate (the ROUTER-3 pattern, ported into the
/// shell). The shell's REAL router — built through the production
/// `appRouterProvider` from the shell's OWN bundled `assets/client_config.json`
/// — must register EVERY whitelisted `screens[].id` under its `RouteNames`
/// name with the exact config path, plus the ONE sanctioned internal DLQ ops
/// route (QUEUE-1, W5.1(d)).
///
/// SPEC-DRIFT NOTE (recorded in the ARCH-1 addendum): the spec says "all 42
/// routes registered". The live tree registers 28 NAMED routes in config
/// mode (26 whitelisted screens + DLQ); 42 was a stale count. The INTENDED
/// contract — the exact whitelisted route table, no more, no less — is
/// asserted here against the code as it actually is (exact map equality is
/// strictly stronger than a count).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 T-3: the shell config-mode route table', () {
    setUp(() async {
      await loadRealConfigMode();
    });

    test('registers exactly the whitelisted screens plus the DLQ ops route '
        '(never the error fallback)', () {
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.screens, isNotEmpty);

      final container = ProviderContainer(overrides: routerAuthOverrides());
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final registered = routerNamedRoutes(router);

      final expected = <String, String>{};
      for (final screen in AppConfig.screens) {
        final id = screen['id'] as String;
        final route = screen['route'] as String;
        final name = screenIdToRouteName[id];
        expect(
          name,
          isNotNull,
          reason:
              'screen id "$id" has no RouteNames mapping — a config '
              'route without one crashes every goNamed call site (00-P0-1)',
        );
        expected[name!] = route;
      }
      // QUEUE-1 (W5.1(d)): the DLQ ops route is the ONE sanctioned
      // internal route registered in config mode.
      expected[RouteNames.deadLetterQueue] = '/dead-letters';

      expect(
        registered,
        expected,
        reason:
            'config mode must register exactly the whitelisted screens '
            'plus the DLQ internal ops route — nothing may leak in or out',
      );
      expect(registered.length, 27);
    });

    test('the shell entry point comes from the shell config (not the labs '
        'default "/splash")', () {
      // The client's navigation.entryPoint is interpolated from the client's
      // own config (kClientEntryPoint); the labs in-code default is
      // '/splash' — proving the SHELL's asset hydrated AppConfig, not the
      // template defaults.
      expect(AppConfig.navigationEntryPoint, kClientEntryPoint);
      expect(AppConfig.appName, kClientAppName);
    });
  });
}
''';

  /// DEMO_MODE wiring guard — ARCH-2 updated: the safe-build guard + emulator
  /// hooks live in the SHARED init (`package:labs` `app_bootstrap.dart`), and
  /// the shell's own per-project `firebase_options.dart` must exist.
  String _demoModeWiringTestTemplate() =>
      r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:''' +
      appDirName +
      r'''/app/core_config_adapter.dart';
import 'package:''' +
      // ignore: prefer_interpolation_to_compose_strings
      appDirName +
      // ignore: prefer_interpolation_to_compose_strings
      r'''/app/demo_config.dart' show kDemoMode;

/// OPS-CONFIG-1 ADDENDUM-D wiring guard.
///
/// The free-plan demo (no Cloud Functions deployed — Firebase Spark plan)
/// rides on two build-time defines:
///   * `--dart-define=DEMO_MODE=true` — the local Dart mocks in packages/core
///     route on `CoreConfigHolder.instance.isDemoMode` (orders written
///     directly to Firestore, Stripe simulated, GDPR client-side).
///   * `--dart-define=USE_EMULATORS=true` — Firestore+Auth wired to the local
///     Firebase Emulator Suite for the fully-local loop (DEMO_PHASE0_LOG.md).
///
/// ARCH-2 moved the entire init into the SHARED `initCarnamaApp`
/// (`package:labs` `app_bootstrap.dart`) — the emulator wiring, the
/// safe-build release guard, and the platform-aware hosts live there now,
/// so this guard asserts the SHARED source plus the shell's per-project
/// `firebase_options.dart`.
void main() {
  final packageRoot = Directory.current.path;
  final labsSource = File(
    '$packageRoot/../../core_app/lib/app_bootstrap.dart',
  ).readAsStringSync();

  test('kDemoMode defaults to false (production) without the define', () {
    expect(kDemoMode, isFalse);
  });

  test('adapter mirrors kDemoMode instead of the old hardcoded false', () {
    const config = ClientCoreConfig(<String, dynamic>{
      'app': <String, dynamic>{
        'bundleId': '''
          // ignore: prefer_interpolation_to_compose_strings
          "'" +
      // ignore: prefer_interpolation_to_compose_strings
      clientConfig.bundleId +
      // ignore: prefer_interpolation_to_compose_strings
      "'" +
      r''',
      },
    });
    expect(config.isDemoMode, kDemoMode);
  });

  test(
    'boot wiring contract: safe-build guard + emulator hooks in the SHARED '
    'init (app_bootstrap.dart)',
    () {
      expect(
        labsSource.contains('_assertSafeBuildConfig'),
        isTrue,
        reason: 'release+DEMO_MODE boot rejection missing from the shared init',
      );
      expect(
        labsSource.contains('usePlatformAuthEmulator'),
        isTrue,
        reason: 'Auth emulator wiring missing from the shared init',
      );
      expect(
        labsSource.contains('useFirestoreEmulator'),
        isTrue,
        reason: 'Firestore emulator wiring missing from the shared init',
      );
      expect(
        labsSource.contains("bool.fromEnvironment('USE_EMULATORS')"),
        isTrue,
        reason: 'USE_EMULATORS gate missing from the shared init',
      );
      expect(
        labsSource.contains('10.0.2.2'),
        isTrue,
        reason: 'platform-aware Android emulator host missing',
      );
      expect(
        labsSource.contains("String.fromEnvironment('EMULATOR_HOST')"),
        isTrue,
        reason: 'physical-device override (EMULATOR_HOST) missing',
      );
    },
  );

  test('the shell main is a THIN wrapper that calls the shared init', () {
    final mainSource = File('$packageRoot/lib/main.dart').readAsStringSync();
    expect(mainSource.contains('initCarnamaApp'), isTrue,
        reason: 'the shell boot must route through the shared initCarnamaApp');
    expect(mainSource.contains('Firebase.initializeApp('), isFalse,
        reason: 'no duplicate init path may live in the shell main');
  });

  test('the shell carries its OWN per-project firebase_options.dart', () {
    final optionsSource = File(
      '$packageRoot/lib/firebase_options.dart',
    ).readAsStringSync();
    expect(
      optionsSource.contains('class DefaultFirebaseOptions'),
      isTrue,
      reason: 'the shell needs its own DefaultFirebaseOptions (ARCH-2)',
    );
    expect(
      optionsSource.contains('TargetPlatform.android'),
      isTrue,
      reason: 'the emitted options must cover android',
    );
    expect(
      optionsSource.contains('TargetPlatform.iOS'),
      isTrue,
      reason: 'the emitted options must cover ios',
    );
  });

  test('demo_config.dart keeps the DEMO_MODE dart-define contract', () {
    final source = File(
      '$packageRoot/lib/app/demo_config.dart',
    ).readAsStringSync();
    expect(
      source.contains("bool.fromEnvironment('DEMO_MODE', defaultValue: false)"),
      isTrue,
      reason: 'kDemoMode must stay a build-time define defaulting to false',
    );
  });
}
''';

  /// OPS-CONFIG-1 truth guard — ARCH-2 extends it with the per-project
  /// firebase_options.dart mirror (the generated options must agree with the
  /// config exactly as the native google-services files do).
  String _firebaseConfigTruthTestTemplate() => r'''
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OPS-CONFIG-1 truth guard (P0-WL-1 ops half, recorded in FIX_VERIFICATION.md).
///
/// The shell initializes Firebase with ITS OWN per-project
/// `lib/firebase_options.dart` (emitted from `assets/client_config.json` by
/// ARCH-2), so the tracked native platform files —
/// `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
/// — must be mirrored by BOTH the config and the emitted options. If either
/// stops mirroring the native truth, the mismatch is invisible until the boot
/// fails closed (W6.1) or the app talks to the wrong Firebase project.
void main() {
  final packageRoot = Directory.current.path;

  Map<String, dynamic> readJson(String relativePath) =>
      jsonDecode(File('$packageRoot/$relativePath').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, String> readPlistStrings(String relativePath) {
    final raw = File('$packageRoot/$relativePath').readAsStringSync();
    final pattern = RegExp(r'<key>([A-Z_]+)</key>\s*<string>([^<]+)</string>');
    return <String, String>{
      for (final match in pattern.allMatches(raw))
        match.group(1)!: match.group(2)!,
    };
  }

  /// Pulls the `key: 'value'` pairs out of one FirebaseOptions group in the
  /// emitted lib/firebase_options.dart so the statics can be compared with
  /// the native truth. The file has TWO groups (android, ios) that repeat
  /// the same identifiers (apiKey, appId, ...) — parse a SINGLE group or the
  /// ios values would silently shadow the android ones.
  Map<String, String> readFirebaseOptionsGroup(String groupSignature) {
    final raw = File(
      '$packageRoot/lib/firebase_options.dart',
    ).readAsStringSync();
    final start = raw.indexOf(groupSignature);
    if (start < 0) {
      return <String, String>{};
    }
    final end = raw.indexOf(');', start);
    final block = raw.substring(start, end);
    final pattern = RegExp(r"(\w+): '([^']*)'");
    return <String, String>{
      for (final match in pattern.allMatches(block))
        match.group(1)!: match.group(2)!,
    };
  }

  final config = readJson('assets/client_config.json');
  final googleServices = readJson('android/app/google-services.json');
  final plist = readPlistStrings('ios/Runner/GoogleService-Info.plist');
  final androidOptions = readFirebaseOptionsGroup(
    'static const FirebaseOptions android =',
  );
  final iosOptions = readFirebaseOptionsGroup(
    'static const FirebaseOptions ios =',
  );

  final environment = config['environment'] as Map<String, dynamic>;
  final firebase = config['firebase'] as Map<String, dynamic>;
  final app = config['app'] as Map<String, dynamic>;
  final bundleId = app['bundleId'] as String;

  final projectInfo = googleServices['project_info'] as Map<String, dynamic>;
  final androidClient = (googleServices['client'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere(
        (client) =>
            ((client['client_info']
                    as Map<String, dynamic>)['android_client_info']
                as Map<String, dynamic>)['package_name'] ==
            bundleId,
      );
  final androidClientInfo =
      androidClient['client_info'] as Map<String, dynamic>;

  test('firebase.projectId mirrors both native platform files', () {
    final expected = projectInfo['project_id'] as String;
    expect(
      firebase['projectId'] as String,
      expected,
      reason: 'client_config.json must mirror google-services.json project_id',
    );
    expect(
      plist['PROJECT_ID'],
      expected,
      reason:
          'GoogleService-Info.plist and google-services.json must be the '
          'same Firebase project',
    );
  });

  test('messagingSenderId mirrors the project number and GCM_SENDER_ID', () {
    final expected = projectInfo['project_number'] as String;
    expect(firebase['messagingSenderId'] as String, expected);
    expect(plist['GCM_SENDER_ID'], expected);
  });

  test('storageBucket mirrors both native platform files', () {
    final expected = projectInfo['storage_bucket'] as String;
    expect(firebase['storageBucket'] as String, expected);
    expect(plist['STORAGE_BUCKET'], expected);
  });

  test('androidAppId mirrors the google-services mobilesdk_app_id', () {
    expect(
      firebase['androidAppId'] as String,
      androidClientInfo['mobilesdk_app_id'] as String,
    );
  });

  test('iosAppId mirrors the plist GOOGLE_APP_ID', () {
    expect(firebase['iosAppId'] as String, plist['GOOGLE_APP_ID']);
  });

  test('firebaseAndroidApiKey mirrors the google-services current_key', () {
    expect(
      environment['firebaseAndroidApiKey'] as String,
      (androidClient['api_key'] as List).first['current_key'] as String,
    );
  });

  test('firebaseIosApiKey mirrors the plist API_KEY', () {
    // The iOS key is a DIFFERENT Firebase key from the Android one (the
    // project issues one key per platform). Mirroring the Android key into
    // the iOS slot looks "real", passes the W6.1 placeholder gate, and then
    // fails iOS identity — exactly the trap this guard exists for.
    expect(environment['firebaseIosApiKey'] as String, plist['API_KEY']);
  });

  test('iosClientId mirrors the plist CLIENT_ID', () {
    expect(firebase['iosClientId'] as String, plist['CLIENT_ID']);
  });

  test('bundle identity matches both platform registrations', () {
    expect(bundleId, plist['BUNDLE_ID']);
    expect(
      (androidClientInfo['android_client_info']
              as Map<String, dynamic>)['package_name']
          as String,
      bundleId,
    );
  });

group('ARCH-2: the emitted firebase_options.dart mirrors the native truth',
      () {
    test('android options carry the google-services identity', () {
      expect(
        androidOptions['apiKey'],
        environment['firebaseAndroidApiKey'] as String,
        reason: 'the emitted android apiKey must be the config/android key',
      );
      expect(
        androidOptions['appId'],
        firebase['androidAppId'] as String,
        reason: 'the emitted android appId must be the mobilesdk_app_id',
      );
      expect(
        androidOptions['messagingSenderId'],
        firebase['messagingSenderId'] as String,
      );
      expect(androidOptions['projectId'], firebase['projectId'] as String);
      expect(
        androidOptions['storageBucket'],
        firebase['storageBucket'] as String,
      );
    });

    test('ios options carry the GoogleService-Info.plist identity', () {
      expect(
        iosOptions['apiKey'],
        environment['firebaseIosApiKey'] as String,
        reason:
            'the emitted ios apiKey must be the config/ios key — '
            'never the android key',
      );
      expect(iosOptions['appId'], firebase['iosAppId'] as String);
    });
  });

  test('zero foreign-project identity tokens anywhere in the config', () {
    final raw = File(
      '$packageRoot/assets/client_config.json',
    ).readAsStringSync();
    for (final token in const <String>[
      '000000000000', // Carnama project number
      'resturants-8547d', // Carnama Firebase project id
      'com.carnama.app', // Carnama application id
    ]) {
      expect(
        raw.contains(token),
        isFalse,
        reason: 'Carnama token "$token" leaked into the shell config',
      );
    }
  });
}
''';

  /// The headless integration test — ARCH-1/ARCH-2 form (boots the shell's
  /// thin wrapper over the REAL labs app; fixed pumps, never pumpAndSettle).
  String _appLaunchTestTemplate() =>
      r'''
import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show AppConfig, HomeScreen;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:''' +
      appDirName +
      r'''/app/app.dart';
import '../test/helpers/router_test_harness.dart';

/// Headless integration test that proves the REAL app can launch through the
/// shell: `GeneratedApp` is a THIN WRAPPER over `CoreApp` (package:labs) —
/// the shell boots with its own bundled config hydrated into the labs
/// statics, and the REAL config-driven router renders the REAL `HomeScreen`
/// wearing the client palette (ARCH-1 T-1/T-2, on-device form).
///
/// It does NOT couple to placeholder content — the placeholder screens were
/// deleted by ARCH-1. Fixed pumps, not `pumpAndSettle` (the real splash/
/// animations never settle).
void main() {
  testWidgets('the shell launches the REAL labs app on the shell config', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // The REAL shell asset (assets/client_config.json) — not a synthetic
    // fixture: the wrapper delegates to the labs statics hydrated from it.
    await loadRealConfigMode();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kGdprAnalyticsConsentKey: true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        child: const GeneratedApp(config: <String, dynamic>{}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The REAL HomeScreen from package:labs is on the entry route ('/') and
    // the shell identity hydrated from the shell's own config asset — the
    // client's own app name is interpolated from the client config.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(AppConfig.loadFailed, isFalse);
    expect(AppConfig.schemaError, isNull);
    expect(AppConfig.bundleId, isNotEmpty);
    expect(
      AppConfig.appName,
      ''' +
      // ignore: prefer_interpolation_to_compose_strings
      "'" +
      clientConfig.appName +
      "'" +
      r''',
    );
  });
}
''';

  /// The shared ARCH-1 router-test harness — ported into the generated shell
  /// verbatim (the shell's REAL router is built from its OWN bundled config
  /// through the production appRouterProvider from package:labs).
  String _routerTestHarnessTemplate() => r'''
/// Shared plumbing for the ARCH-1 shell router tests — a port of
/// `core_app/test/helpers/router_test_harness.dart` (the ROUTER-3 pattern)
/// into the generated shell: the shell's REAL router is built from the
/// shell's OWN bundled `assets/client_config.json` through the production
/// `appRouterProvider` from `package:labs`. These helpers only provide the
/// provider overrides every router build needs and a structural walker over
/// the actual go_router route tree.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/labs.dart';

/// Puts [AppConfig] into config mode from the SHELL's bundled asset: resets
/// every static and loads `assets/client_config.json` (the client template —
/// the whitelisted screens on today's schema).
Future<void> loadRealConfigMode() async {
  AppConfig.resetForTest();
  await AppConfig.loadConfig();
}

/// Returns the overrides every router build needs (same contract as the
/// core_app harness):
/// - `authStateProvider`/`currentUserProvider` so the router's redirect can
///   resolve without Firebase. Pass [authUser] and [user] to simulate a
///   signed-in role.
/// - `loggerProvider` bound to the service's designed test seam
///   (`LoggerService(testDirectory:)`) so building the router never touches
///   the unmocked `path_provider` platform channel.
List<Override> routerAuthOverrides({User? authUser, UserModel? user}) {
  return [
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    currentUserProvider.overrideWith((ref) async => user),
    loggerProvider.overrideWithValue(
      LoggerService(testDirectory: Directory.systemTemp),
    ),
  ];
}

/// The overrides the home feed tab needs so the REAL HomeScreen renders
/// against controlled data in a widget test (no Firebase/Isar): an empty
/// merged menu, no pending sync / DLQ entries, no restaurant-config stream,
/// and a fail-safe HomeService double that returns no promotions.
///
/// These are test doubles over the production provider seams — the screens
/// themselves are the real `package:labs` production widgets.
class _FakeHomeService implements HomeService {
  @override
  Future<List<HomePromotion>> getPromotions() async => const <HomePromotion>[];

  @override
  Future<List<HomeBranch>> getBranches() async => const <HomeBranch>[];

  @override
  List<MenuItemModel> searchMenuItems(List<MenuItemModel> items, String query) {
    if (query.isEmpty) return items;
    final q = query.trim().toLowerCase();
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  List<MenuItemModel> filterByCategory(
    List<MenuItemModel> items,
    String category,
  ) {
    if (category.isEmpty) return items;
    final c = category.trim().toLowerCase();
    return items
        .where(
          (i) =>
              i.category.toLowerCase() == c ||
              i.tags.any((t) => t.toLowerCase() == c),
        )
        .toList();
  }

  @override
  List<MenuItemModel> filterByMaxPrice(
    List<MenuItemModel> items,
    int maxPriceCents,
  ) {
    return items.where((i) => i.priceCents <= maxPriceCents).toList();
  }

  @override
  List<MenuItemModel> filterAvailable(List<MenuItemModel> items) {
    return items.where((i) => i.isAvailable).toList();
  }
}

List<Override> homeFeedOverrides() {
  return [
    homeServiceProvider.overrideWithValue(_FakeHomeService()),
    mergedMenuProvider.overrideWith(
      (ref) => Stream<List<MenuItemModel>>.value(const <MenuItemModel>[]),
    ),
    restaurantConfigProvider.overrideWith(
      (ref) => const Stream<RestaurantConfigModel>.empty(),
    ),
    pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
  ];
}

/// Pumps the production `appRouterProvider` inside a `MaterialApp.router`
/// themed with the SHELL's config palette ([AppConfig.theme]) and the labs
/// localization delegates. Uses FIXED pumps (never `pumpAndSettle`): the
/// splash screen animates indefinitely, which would never settle.
Future<GoRouter> pumpRouterApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            routerConfig: router,
            theme: AppConfig.theme,
            darkTheme: AppConfig.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

/// Flattens a go_router route tree into `{routeName: fullPath}`.
///
/// go_router stores nested `GoRoute`s with RELATIVE paths (e.g. `menu` under
/// `/admin`), so the full path is recomposed from the parent prefix. This
/// walker works for both `GoRoute` and `ShellRoute` nesting.
Map<String, String> collectNamedRoutes(
  List<RouteBase> routes, [
  String parentPath = '',
]) {
  final out = <String, String>{};
  void walk(List<RouteBase> rs, String prefix) {
    for (final r in rs) {
      if (r is GoRoute) {
        final full = _joinPaths(prefix, r.path);
        final name = r.name;
        if (name != null && name.isNotEmpty) out[name] = full;
        walk(r.routes, full);
      } else if (r is ShellRoute) {
        walk(r.routes, prefix);
      }
    }
  }

  walk(routes, parentPath);
  return out;
}

/// The named routes a built [GoRouter] actually registered.
Map<String, String> routerNamedRoutes(GoRouter router) =>
    collectNamedRoutes(router.configuration.routes);

String _joinPaths(String prefix, String path) {
  if (path.startsWith('/')) return path;
  if (prefix.isEmpty) return '/$path';
  if (prefix.endsWith('/')) return '$prefix$path';
  return '$prefix/$path';
}
''';

  /// The ARCH-1 shell widget test — proves the shell resolves the REAL screens
  /// through the production router (no local placeholder remains).
  /// p36 A5: the stripe Android gate every fresh stamp emits — mirrors
  /// `apps/halal_boyz/test/stripe_android_gate_test.dart` with a recursive
  /// MainActivity lookup (the package path is client-specific).
  String _stripeAndroidGateTestTemplate() => r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// flutter_stripe's Android SDK hard requirements (its README), each of
/// which has bitten the fail-closed white-label boot on device (p34):
/// 1. the host Activity must extend FlutterFragmentActivity — a plain
///    FlutterActivity makes `Stripe.instance.applySettings()` throw;
/// 2. that Activity's theme must derive from Theme.AppCompat or
///    Theme.MaterialComponents — plain `@android:style/` parents throw.
/// Emitted by whitelabel.dart (p36 A5) and produced by its own
/// alignStripeAndroidGate — a stamp can never regress these silently.
void main() {
  final kotlinRoot = Directory('android/app/src/main/kotlin');
  final activityFile = kotlinRoot
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere(
        (f) => f.path.endsWith('MainActivity.kt'),
        orElse: () => throw StateError('MainActivity.kt not found'),
      );
  final activitySource = activityFile.readAsStringSync();

  final lightStyles = File(
    'android/app/src/main/res/values/styles.xml',
  ).readAsStringSync();

  final nightStyles = File(
    'android/app/src/main/res/values-night/styles.xml',
  ).readAsStringSync();

  final appCompatParent = RegExp(
    r'parent="[^"]*(?:Theme\.MaterialComponents|Theme\.AppCompat)[^"]*"',
  );

  test('MainActivity extends FlutterFragmentActivity so flutter_stripe can '
      'initialize', () {
    expect(activitySource, contains('FlutterFragmentActivity'));
    expect(activitySource, isNot(contains(': FlutterActivity()')));
  });

  test('LaunchTheme and NormalTheme derive from AppCompat or '
      'MaterialComponents so flutter_stripe accepts the activity theme', () {
    expect(
      appCompatParent.allMatches(lightStyles).length,
      greaterThanOrEqualTo(2),
      reason: 'values/styles.xml: LaunchTheme + NormalTheme parents',
    );
    expect(
      appCompatParent.allMatches(nightStyles).length,
      greaterThanOrEqualTo(2),
      reason: 'values-night/styles.xml: LaunchTheme + NormalTheme parents',
    );
  });
}
''';

  String _widgetTestTemplate() => r'''
import 'dart:io';

import 'package:core/core.dart' show kGdprAnalyticsConsentKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show AppConfig, HomeScreen, RouteNames;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/router_test_harness.dart';

// ARCH-1 T-1/T-2: the shell's app root (`GeneratedApp` in `app/app.dart`) is
// now a THIN WRAPPER over the REAL app widget (`CoreApp` from
// `package:labs`). These tests prove the shell's REAL route table — built
// from the shell's OWN bundled `assets/client_config.json` through the
// production `appRouterProvider` — renders the REAL `HomeScreen` from
// `package:labs`, wearing the client config palette.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 T-1: the shell resolves the REAL screens', () {
    testWidgets(
      'the shell router builds HomeScreen from package:labs (not a local '
      'placeholder)',
      (tester) async {
        await loadRealConfigMode();
        // The real HomeScreen fires the GDPR consent chain on first land;
        // mock the prefs store so the ask resolves against the canonical key.
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });

        final router = await pumpRouterApp(
          tester,
          overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        );

        // The REAL production screen type — imported from package:labs via
        // the barrel (this file has NO local HomeScreen to import).
        expect(find.byType(HomeScreen), findsOneWidget);

        // The entry route is the config-driven home route at '/'.
        final registered = routerNamedRoutes(router);
        expect(registered[RouteNames.home], '/');
        // (The GeneratedApp -> CoreApp wrapper mounting itself is proven by
        // the headless integration test: integration_test/app_launch_test.)
      },
    );

    test(
      'no placeholder screen class remains in shell lib (ARCH-1 deletion)',
      () {
        final files = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(files, isNotEmpty);
        for (final file in files) {
          final text = file.readAsStringSync();
          for (final marker in <String>[
            'class HomeScreen',
            'class MenuScreen',
            'class CartScreen',
            'class CheckoutScreen',
          ]) {
            expect(
              text.contains(marker),
              isFalse,
              reason:
                  '${file.path} must not declare a local screen '
                  '"$marker" — screens come from package:labs',
            );
          }
        }
      },
    );
  });

  group('ARCH-1 T-2: the client config flows through the real app', () {
    test(
      'AppConfig resolves the shell identity/palette/screens registry',
      () async {
        await loadRealConfigMode();

        expect(AppConfig.loadFailed, isFalse);
        expect(AppConfig.schemaError, isNull);
        expect(AppConfig.bundleId, isNotEmpty);
        expect(AppConfig.appName, isNotEmpty);
        expect(AppConfig.screens, isNotEmpty);
      },
    );

    testWidgets(
      'the config palette renders on the REAL MaterialApp (CoreApp wiring)',
      (tester) async {
        await loadRealConfigMode();
        SharedPreferences.setMockInitialValues(<String, Object>{
          kGdprAnalyticsConsentKey: true,
        });

        await pumpRouterApp(
          tester,
          overrides: [...routerAuthOverrides(), ...homeFeedOverrides()],
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp).first,
        );
        // The config palette must be the MaterialApp theme that the real
        // screens render with (not the labs in-code default).
        expect(
          materialApp.theme?.colorScheme.primary,
          AppConfig.theme.colorScheme.primary,
          reason: 'the hydrated config palette must BE the MaterialApp theme',
        );
      },
    );
  });
}
''';
}
