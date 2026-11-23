/// Strict REQUIRED-field schema validation for `client_config.json` (W6.5).
///
/// Pure Dart on purpose: the same file is used by the template app
/// (`package:labs`) AND emitted verbatim into every generated shell by
/// `tool/whitelabel.dart` (`lib/app/client_config.dart`), so the validator
/// must never depend on Flutter services, dotenv, or an app package.
///
/// Contract (master W6.5 / audit 07-P1-3):
/// - REQUIRED fields fail CLOSED: a config that parses but misses or mistypes
///   them throws [ConfigException] naming the exact JSON path. The boot then
///   blocks on `ConfigValidationErrorScreen` — never a silent default boot.
/// - Optional/unknown fields are NOT validated here; they keep the graceful
///   degradation of `AppConfig`'s defensive parsers.
/// - Unknown `navigation.routes` keys are rejected: the route vocabulary is
///   part of the schema ("the generator validates what consumers read").
library;

import 'package:core/core.dart';

/// One REQUIRED-field violation at an exact JSON path.
class ConfigViolation {
  const ConfigViolation(this.path, this.message);

  /// Dot path into client_config.json, e.g. `app.bundleId`.
  final String path;

  /// Human-readable violation description for the operator.
  final String message;
}

/// Typed failure of the REQUIRED-field config schema (W6.5).
class ConfigException implements Exception {
  ConfigException(this.violations)
    : assert(
        violations.isNotEmpty,
        'a ConfigException must carry at least one violation',
      ),
      jsonPath = violations.first.path;

  /// Every violation found, each with its exact JSON path.
  final List<ConfigViolation> violations;

  /// JSON path of the first violation (e.g. `app.bundleId`).
  final String jsonPath;

  @override
  String toString() =>
      'ConfigException: '
      '${violations.map((v) => '"${v.path}" ${v.message}').join('; ')}';
}

class ClientConfig {
  const ClientConfig._();

  /// The only client_config schema version this codebase speaks (W6.4(4)).
  /// The generator's `validate()` pins the SAME constant; the two are kept in
  /// sync by `core_app/test/tool/whitelabel_schema_identity_test.dart`.
  static const String supportedSchemaVersion = '1.0.0';

  /// The only legal `theme.injection` mode — the config's enum "mode" field
  /// for W6.5. Line-drift decision (index §2.4, recorded in the WL-2
  /// addendum): no key literally named `mode` exists in any config or parser;
  /// `theme.injection` is the enum-typed field both real configs carry.
  static const String requiredInjectionMode = 'local-config-file';

  /// The route-name vocabulary `navigation.routes` may use. Unknown keys are
  /// rejected (W6.5). Mirrors the route names the apps actually resolve (the
  /// core router's screen-id map and the generated shell's `routeFor` call
  /// sites), so a config key that no router can ever look up fails closed.
  static const Set<String> knownRouteKeys = <String>{
    'splash',
    'onboarding',
    'login',
    'signup',
    'home',
    'menu',
    'dishDetail',
    'cart',
    'checkout',
    'orderTracker',
    'orders',
    'reservations',
    'locations',
    'waitlist',
    'loyalty',
    'profile',
    'errorLogs',
    'admin',
    'adminMenu',
    'roleRouter',
    'ownerDashboard',
    'managerDashboard',
    'kitchenDashboard',
    'deliveryDashboard',
    'privacy',
    'terms',
    'deleteAccount',
    'logs',
    'adminGateway',
  };

  /// The `theme.shape.style` form-preset vocabulary (p35 V3 / W6.5 parity).
  /// Mirrors core_ui `AppShapePreset.vocabulary` and the generator's
  /// `validate()`; pinned three-way by `whitelabel_schema_identity_test`.
  static const Set<String> knownShapeStyles = <String>{
    'sharp',
    'soft',
    'round',
    'pill',
  };

  /// The `theme.depth` preset vocabulary (p35 scope B / W6.5 parity).
  /// Mirrors core_ui `AppDepthPreset.vocabulary` and the generator's
  /// `validate()`; pinned three-way by `whitelabel_schema_identity_test`.
  static const Set<String> knownDepthStyles = <String>{
    'flat',
    'soft',
    'elevated',
  };

  /// The `tenantId` shape (P0-6): a lowercase kebab/snake id such as
  /// `halal_boyz` or `halal-boyz`. Pinned here so the runtime gate and the
  /// generator's `validate()` reject the same strings.
  static final RegExp tenantIdPattern = RegExp(r'^[a-z0-9]+([_-][a-z0-9]+)*$');

  /// Validates the REQUIRED subset of [config]. Throws a [ConfigException]
  /// listing every violation with its exact JSON path; returns silently when
  /// the config satisfies the schema.
  static void fromMap(Map<String, dynamic> config) {
    final violations = <ConfigViolation>[];

    Map<String, dynamic>? sectionIn(Map<String, dynamic>? parent, String key) {
      final value = parent?[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    }

    String? stringAt(Map<String, dynamic>? parent, String key) {
      final value = parent?[key];
      return value is String ? value : null;
    }

    // _meta.schemaVersion (W6.4(4)/W6.5): pin the schema so a config written
    // for a NEWER schema can never silently boot an OLDER app.
    final schemaVersion = stringAt(sectionIn(config, '_meta'), 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      violations.add(
        ConfigViolation(
          '_meta.schemaVersion',
          'must be exactly "$supportedSchemaVersion" '
              '(got: ${schemaVersion ?? 'missing'})',
        ),
      );
    }

    // app.name / app.bundleId — the installed identity (the B7-2 fast-fail
    // reads the same bundle id at runtime).
    final app = sectionIn(config, 'app');
    final appName = stringAt(app, 'name');
    if (appName == null || appName.trim().isEmpty) {
      violations.add(
        const ConfigViolation(
          'app.name',
          'is required and must be a non-empty string',
        ),
      );
    }
    final bundleId = stringAt(app, 'bundleId');
    if (bundleId == null || bundleId.trim().isEmpty) {
      violations.add(
        const ConfigViolation(
          'app.bundleId',
          'is required and must be a non-empty string',
        ),
      );
    }

    // TENANCY (P0-6): every config states which tenant it belongs to. Required
    // and shape-checked NOW so later rules/claims work can rely on it; nothing
    // consumes it yet, which is deliberate — this card changes no behaviour.
    final rawTenantId = config['tenantId'];
    final tenantId = rawTenantId is String ? rawTenantId : null;
    if (tenantId == null || tenantId.trim().isEmpty) {
      violations.add(
        const ConfigViolation(
          'tenantId',
          'is required and must be a non-empty kebab/snake id '
              '(lowercase letters, digits, "-" or "_"), e.g. "halal_boyz"',
        ),
      );
    } else if (!tenantIdPattern.hasMatch(tenantId)) {
      violations.add(
        ConfigViolation(
          'tenantId',
          'must be a kebab/snake id (lowercase letters, digits, "-" or "_") '
              'such as "halal_boyz" — got "$tenantId"',
        ),
      );
    }

    // ADR-01 (P0-10): the card-present payment surface now exists in the schema
    // and is read by NOTHING yet. Both fields are OPTIONAL on purpose — unlike
    // tenantId — so an unconfigured tenant or branch still boots; an empty
    // string means "not configured". Only the TYPE is enforced here.
    final rawStripeAccountId = config['stripeAccountId'];
    if (rawStripeAccountId != null && rawStripeAccountId is! String) {
      violations.add(
        const ConfigViolation(
          'stripeAccountId',
          'must be a string when present (empty string means unconfigured)',
        ),
      );
    }
    final branches = sectionIn(config, 'branches');
    if (branches != null) {
      // Two accepted placements, both schema-only: `branches.terminalLocationId`
      // (the flat shape this section already uses for defaultBranchId) and
      // `branches.<branchId>.terminalLocationId` (per-branch, for the multi-site
      // case the expansion needs). See D-013.
      final flatLocation = branches['terminalLocationId'];
      if (flatLocation != null && flatLocation is! String) {
        violations.add(
          const ConfigViolation(
            'branches.terminalLocationId',
            'must be a string when present',
          ),
        );
      }
      branches.forEach((String key, Object? value) {
        if (value is! Map) return;
        final nested = value['terminalLocationId'];
        if (nested != null && nested is! String) {
          violations.add(
            ConfigViolation(
              'branches.$key.terminalLocationId',
              'must be a string when present',
            ),
          );
        }
      });
    }

    // theme.injection — the required enum "mode" (see [requiredInjectionMode]).
    final theme = sectionIn(config, 'theme');
    final injection = stringAt(theme, 'injection');
    if (injection == null || injection.isEmpty) {
      violations.add(
        const ConfigViolation(
          'theme.injection',
          'is required (enum: "$requiredInjectionMode")',
        ),
      );
    } else if (injection != requiredInjectionMode) {
      violations.add(
        ConfigViolation(
          'theme.injection',
          'must be "$requiredInjectionMode" (got: "$injection")',
        ),
      );
    }

    // theme.colors.primary — REQUIRED and must parse as a hex color.
    // Line-drift decision (index §2.4, recorded in the WL-2 addendum): the
    // master W6.5 text names `theme.colors.primaryHex`, but the key every
    // parser and both real configs actually use is `theme.colors.primary` —
    // the INTENDED contract (a required, parseable primary color) is
    // implemented against the real key.
    final colors = sectionIn(theme, 'colors');
    final primary = stringAt(colors, 'primary');
    if (primary == null || primary.trim().isEmpty) {
      violations.add(
        const ConfigViolation(
          'theme.colors.primary',
          'is required and must be a non-empty hex string',
        ),
      );
    } else if (!isValidHexColor(primary)) {
      violations.add(
        ConfigViolation(
          'theme.colors.primary',
          'must be a parseable hex color (0xRRGGBB[AA]) (got: "$primary")',
        ),
      );
    }

    // navigation.entryPoint — the boot route.
    final navigation = sectionIn(config, 'navigation');
    final entryPoint = stringAt(navigation, 'entryPoint');
    if (entryPoint == null || entryPoint.isEmpty) {
      violations.add(
        const ConfigViolation(
          'navigation.entryPoint',
          'is required and must be a non-empty string',
        ),
      );
    } else if (!entryPoint.startsWith('/')) {
      violations.add(
        ConfigViolation(
          'navigation.entryPoint',
          'must be a route path starting with "/" (got: "$entryPoint")',
        ),
      );
    }

    // navigation.routes — optional (shells fall back per key) but STRICTLY
    // validated when present: unknown keys and malformed paths reject.
    final routes = sectionIn(navigation, 'routes');
    if (routes != null) {
      routes.forEach((key, value) {
        final path = 'navigation.routes.$key';
        if (!knownRouteKeys.contains(key)) {
          violations.add(
            ConfigViolation(
              path,
              'unknown route key — allowed keys: $knownRouteKeys',
            ),
          );
          return;
        }
        if (value is! String || value.isEmpty || !value.startsWith('/')) {
          violations.add(
            ConfigViolation(
              path,
              'must be a non-empty route path starting with "/" (got: $value)',
            ),
          );
        }
      });
    }

    // ── TOKENS (WHITE_LABEL_b10_tokens.md) ──────────────────────────────────
    // The optional design-token keys are validated STRICTLY WHEN PRESENT
    // (WL-2: the validator validates what `AppTheme.buildTheme` reads — a
    // malformed token must fail CLOSED on the ConfigValidationErrorScreen,
    // never silently fall back to the default look). An absent/null key keeps
    // the default (= pre-token behavior).
    // ── UI-9 (p19): deliveryPlatforms — ABSENT = inert; PRESENT = fail-closed
    // through the ONE shared validator (`DeliveryPlatforms` in package:core —
    // the same rules the generator mirror and the server selector run), each
    // violation re-reported at its exact JSON path so the boot blocks on the
    // ConfigValidationErrorScreen with the path the operator must fix (L3).
    for (final violation in DeliveryPlatforms.validatePlatforms(
      config['deliveryPlatforms'],
    )) {
      violations.add(ConfigViolation(violation.path, violation.message));
    }

    _validateThemeTokens(theme, sectionIn, violations);

    if (violations.isNotEmpty) {
      throw ConfigException(List<ConfigViolation>.unmodifiable(violations));
    }
  }

  /// Validates the optional design-token keys under `theme` (b10).
  static void _validateThemeTokens(
    Map<String, dynamic>? theme,
    Map<String, dynamic>? Function(Map<String, dynamic>? parent, String key)
    sectionIn,
    List<ConfigViolation> violations,
  ) {
    // Present-but-invalid → violation; absent/null → default. Every check
    // names the exact JSON path (W6.5 discipline).
    void expectNonEmptyString(
      Map<String, dynamic>? section,
      String path,
      String key,
    ) {
      final value = section?[key];
      if (value == null) return;
      if (value is! String || value.trim().isEmpty) {
        violations.add(
          ConfigViolation(path, 'must be a non-empty string when present'),
        );
      }
    }

    void expectHexColor(
      Map<String, dynamic>? section,
      String path,
      String key,
    ) {
      final value = section?[key];
      if (value == null) return;
      if (value is! String || !isValidHexColor(value)) {
        violations.add(
          ConfigViolation(
            path,
            'must be a parseable hex color (0xRRGGBB[AA]) when present '
            '(got: $value)',
          ),
        );
      }
    }

    void expectPositiveNumber(
      Map<String, dynamic>? section,
      String path,
      String key,
    ) {
      final value = section?[key];
      if (value == null) return;
      if (value is! num || !(value > 0) || !(value.isFinite)) {
        violations.add(
          ConfigViolation(
            path,
            'must be a positive finite number when present (got: $value)',
          ),
        );
      }
    }

    // typography.headingFont / bodyFont — the per-client heading/body font
    // split (registered bundled families are enforced at runtime by the
    // AppTheme typography guard, W11.3).
    final typography = sectionIn(theme, 'typography');
    expectNonEmptyString(
      typography,
      'theme.typography.headingFont',
      'headingFont',
    );
    expectNonEmptyString(typography, 'theme.typography.bodyFont', 'bodyFont');

    // Q3 (semantic state palette): colors.soldOut is engine-read (it feeds
    // the BrandColors extension), so a malformed value fails CLOSED at its
    // exact path WHEN PRESENT — absent keeps the AppColors default (the b10
    // strict-when-present rule the other optional visual tokens follow).
    expectHexColor(
      sectionIn(theme, 'colors'),
      'theme.colors.soldOut',
      'soldOut',
    );

    // Q1 (signature identity): theme.signature.style is CLOSED-SET and
    // strict-when-present — absent = no motif (the b10 byte contract),
    // present must name a style the engine knows (mirrored in
    // `tool/whitelabel.dart`, pinned by whitelabel_schema_identity_test).
    final signature = theme?['signature'];
    if (signature != null && signature is! Map) {
      violations.add(
        ConfigViolation(
          'theme.signature.style',
          'must be an object with a "style" string when present '
              '(got: $signature)',
        ),
      );
    } else if (signature is Map) {
      final Object? signatureStyle = signature['style'];
      const allowedSignatureStyles = <String>{'rule'};
      if (signatureStyle is! String || signatureStyle.trim().isEmpty) {
        violations.add(
          const ConfigViolation(
            'theme.signature.style',
            'must be a non-empty string when theme.signature is present',
          ),
        );
      } else if (!allowedSignatureStyles.contains(signatureStyle)) {
        violations.add(
          ConfigViolation(
            'theme.signature.style',
            'must be one of $allowedSignatureStyles when present '
                '(got: $signatureStyle)',
          ),
        );
      }
    }

    // shape.{cardRadius,ctaRadius,smallRadius} — positive pixel radii.
    final shape = sectionIn(theme, 'shape');
    expectPositiveNumber(shape, 'theme.shape.cardRadius', 'cardRadius');
    expectPositiveNumber(shape, 'theme.shape.ctaRadius', 'ctaRadius');
    expectPositiveNumber(shape, 'theme.shape.smallRadius', 'smallRadius');

    // p35 V3: theme.shape.style is CLOSED-SET and strict-when-present (the
    // b10 rule) — the generator failed closed at stamp time and the runtime
    // now fails closed at boot too (W6.5 parity), so a typo never degrades a
    // shipped look. Absent keeps the byte-for-byte baseline; the engine's
    // graceful degrade still covers direct raw-map theme builds.
    final Object? shapeStyle = shape?['style'];
    if (shapeStyle != null &&
        (shapeStyle is! String || !knownShapeStyles.contains(shapeStyle))) {
      violations.add(
        ConfigViolation(
          'theme.shape.style',
          'must be one of $knownShapeStyles when present '
              '(got: $shapeStyle)',
        ),
      );
    }

    // components.navigationBar.{background,activeColor}.
    final components = sectionIn(theme, 'components');
    final navBar = sectionIn(components, 'navigationBar');
    expectHexColor(
      navBar,
      'theme.components.navigationBar.background',
      'background',
    );
    expectHexColor(
      navBar,
      'theme.components.navigationBar.activeColor',
      'activeColor',
    );

    // components.input.{fillColor,borderColor,radius}.
    final input = sectionIn(components, 'input');
    expectHexColor(input, 'theme.components.input.fillColor', 'fillColor');
    expectHexColor(input, 'theme.components.input.borderColor', 'borderColor');
    expectPositiveNumber(input, 'theme.components.input.radius', 'radius');

    // components.chip.radius.
    final chip = sectionIn(components, 'chip');
    expectPositiveNumber(chip, 'theme.components.chip.radius', 'radius');

    // background.{color,overlayAsset} — decorative scaffold layer.
    final background = sectionIn(theme, 'background');
    expectHexColor(background, 'theme.background.color', 'color');
    final overlayAssetValue = background?['overlayAsset'];
    if (overlayAssetValue != null) {
      final trimmed = overlayAssetValue is String
          ? overlayAssetValue.trim()
          : '';
      if (overlayAssetValue is! String ||
          trimmed.isEmpty ||
          trimmed.startsWith('/') ||
          trimmed.startsWith(r'\') ||
          trimmed.contains('..') ||
          trimmed.contains(r'\')) {
        violations.add(
          const ConfigViolation(
            'theme.background.overlayAsset',
            'must be a relative asset path (no leading "/", no "..", no '
                'backslashes) when present',
          ),
        );
      }
    }

    // animationStyle — enum: full | subtle | none.
    final animationStyle = theme?['animationStyle'];
    if (animationStyle != null) {
      const allowed = <String>{'full', 'subtle', 'none'};
      if (animationStyle is! String || !allowed.contains(animationStyle)) {
        violations.add(
          ConfigViolation(
            'theme.animationStyle',
            'must be one of $allowed when present (got: $animationStyle)',
          ),
        );
      }
    }

    // p35 scope B: theme.depth is CLOSED-SET and strict-when-present — the
    // same W6.5 parity contract as shape.style (generator + runtime both
    // fail closed; absent = flat = today).
    final Object? depthStyle = theme?['depth'];
    if (depthStyle != null &&
        (depthStyle is! String || !knownDepthStyles.contains(depthStyle))) {
      violations.add(
        ConfigViolation(
          'theme.depth',
          'must be one of $knownDepthStyles when present (got: $depthStyle)',
        ),
      );
    }

    // D-P35-2 B-2: theme.darkTheme.surfaces — optional surface ramp map for
    // dark mode. Each value must be a valid hex color when present.
    final darkTheme = theme?['darkTheme'];
    if (darkTheme != null && darkTheme is! Map<String, dynamic>) {
      violations.add(
        ConfigViolation(
          'theme.darkTheme',
          'must be a map when present (got: $darkTheme)',
        ),
      );
    } else if (darkTheme is Map<String, dynamic>) {
      final surfaces = darkTheme['surfaces'];
      if (surfaces != null && surfaces is! Map<String, dynamic>) {
        violations.add(
          ConfigViolation(
            'theme.darkTheme.surfaces',
            'must be a map of surface-level hex colors when present '
                '(got: $surfaces)',
          ),
        );
      } else if (surfaces is Map<String, dynamic>) {
        surfaces.forEach((key, value) {
          if (value is! String || !isValidHexColor(value)) {
            violations.add(
              ConfigViolation(
                'theme.darkTheme.surfaces.$key',
                'must be a valid hex color (0xRRGGBB / 0xAARRGGBB / RRGGBB) '
                    'when present (got: $value)',
              ),
            );
          }
        });
      }

      // B-3: theme.darkTheme.foreground — optional hex color for dark AA guard.
      final foreground = darkTheme['foreground'];
      if (foreground != null &&
          (foreground is! String || !isValidHexColor(foreground))) {
        violations.add(
          ConfigViolation(
            'theme.darkTheme.foreground',
            'must be a valid hex color when present (got: $foreground)',
          ),
        );
      }
    }
  }

  /// Whether [raw] parses as a config hex color (0xRRGGBB, 0xAARRGGBB, or a
  /// bare RRGGBB) — the same vocabulary `AppTheme` consumes.
  static bool isValidHexColor(String raw) {
    var hex = raw.trim().replaceFirst('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return false;
    return int.tryParse(hex, radix: 16) != null;
  }
}
