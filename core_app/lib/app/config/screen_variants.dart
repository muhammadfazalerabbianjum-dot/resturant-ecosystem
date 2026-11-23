/// PERF-5 (WHITE_LABEL_p05_perf5.md): the config-driven screen-variant
/// registry — the TOKENS house pattern (validated config vocabulary →
/// resolver → per-key behavior with byte-for-byte default) extended from
/// skin (colors/shape/motion/backdrop) to STRUCTURE: per-screen layout
/// variants chosen by config.
///
/// Pure Dart on purpose: the vocabulary and the validator are consumed by
/// `AppConfig.loadConfig`'s W6.5 schema gate (a violation becomes a typed
/// [ConfigException] so the boot blocks on the ConfigValidationErrorScreen),
/// and the SAME vocabulary is mirrored BY DESIGN in the generator's
/// `validate()` (`core_app/tool/whitelabel.dart` — the tool never imports
/// app lib code, exactly like the schema-version and token constants). The
/// two validators are pinned to the same fixtures by
/// `core_app/test/tool/whitelabel_schema_identity_test.dart`.
library;

import 'client_config.dart';

/// The validated variant vocabulary and the resolver for `screens[].variant`.
class ScreenVariants {
  const ScreenVariants._();

  /// The screen id the pilot variant wires (T-3) — the home feed.
  static const String homeScreenId = 'HomeScreen';

  /// The home feed's DEFAULT layout — what a config with no `variant` key
  /// renders. Byte-for-byte today's grid (acceptance 2).
  static const String homeGridVariant = 'grid';

  /// The ONE pilot variant (mechanism, not 28 screens): a distinct
  /// full-width showcase layout for the home feed.
  static const String homeShowcaseVariant = 'showcase';

  /// The validated variant vocabulary per screen id. A config may carry a
  /// `variant` key on a `screens[]` entry ONLY for a screen id listed here,
  /// ONLY with a value listed here. Anything else fails CLOSED (W6.5).
  static const Map<String, Set<String>> catalog = <String, Set<String>>{
    homeScreenId: <String>{homeGridVariant, homeShowcaseVariant},
  };

  /// The variant each variant-capable screen renders when its config entry
  /// carries NO `variant` key (= today's behavior, byte-for-byte).
  static const Map<String, String> defaults = <String, String>{
    homeScreenId: homeGridVariant,
  };

  /// Validates every `variant` key the config's `screens[]` registry carries.
  ///
  /// STRICTLY WHEN PRESENT (the TOKENS rule): an absent/null key keeps the
  /// default; a present-but-invalid key is a violation at the exact JSON
  /// path `screens[i].variant`. Returns every violation (empty = valid);
  /// the caller turns non-empty into a [ConfigException] so the W6.5 gate
  /// blocks the boot — the same fail-closed path as the REQUIRED fields.
  static List<ConfigViolation> validateScreens(dynamic screens) {
    final violations = <ConfigViolation>[];
    if (screens is! List) return violations;
    for (var i = 0; i < screens.length; i++) {
      final entry = screens[i];
      if (entry is! Map) continue;
      final variant = entry['variant'];
      if (variant == null) continue;
      final path = 'screens[$i].variant';
      if (variant is! String || variant.trim().isEmpty) {
        violations.add(
          ConfigViolation(
            path,
            'must be a non-empty string when present (got: $variant)',
          ),
        );
        continue;
      }
      final id = entry['id'];
      final allowed = id is String ? catalog[id] : null;
      if (allowed == null) {
        violations.add(
          ConfigViolation(
            path,
            'screen id "${id ?? 'missing'}" has no variant vocabulary — '
            'allowed ids: ${catalog.keys.toList()}',
          ),
        );
        continue;
      }
      if (!allowed.contains(variant)) {
        violations.add(
          ConfigViolation(
            path,
            'must be one of $allowed for screen id "$id" '
            '(got: "$variant")',
          ),
        );
      }
    }
    return violations;
  }

  /// The resolved variant table from the parsed `screens` registry: screenId
  /// → variant for every entry that EXPLICITLY carries one. Entries without
  /// a variant key (and every screen id outside the catalog) never appear —
  /// they resolve through [resolve]'s default fallback.
  static Map<String, String> fromScreens(List<Map<String, dynamic>> screens) {
    final resolved = <String, String>{};
    for (final screen in screens) {
      final id = screen['id'];
      final variant = screen['variant'];
      if (id is String && variant is String && variant.isNotEmpty) {
        resolved[id] = variant;
      }
    }
    return resolved;
  }

  /// Resolves the variant for [screenId]: the config's explicit variant,
  /// else the catalog default (byte-for-byte today's layout), else '' for
  /// screens with no variant support at all (callers treat '' as "default").
  static String resolve(Map<String, String> configured, String screenId) =>
      configured[screenId] ?? defaults[screenId] ?? '';
}
