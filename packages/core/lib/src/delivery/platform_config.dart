/// UI-9 (p19) L3: the `deliveryPlatforms` config vocabulary — fail-closed
/// validation, a typed row, and the "disabled/absent = inert" rule.
///
/// Pure Dart on purpose (no Flutter, no I/O): the SAME validator is consumed by
/// the app's W6.5 schema gate (`core_app/lib/app/config/client_config.dart`),
/// by the `AppConfig` parser and by the adapter registry, and the identical
/// vocabulary is MIRRORED by the generator (`core_app/tool/whitelabel.dart`
/// `validate()`, which never imports app lib code) and by the server-side
/// selector (`core_app/functions/src/platform_ingestion.ts`, which must not
/// trust a client-shaped config either). All are pinned to the ONE shared
/// fixture `core_app/functions/test/fixtures/platform/
/// delivery_platforms_config.json`.
///
/// Platform facts (fetched, `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` Track 3):
/// Uber Eats (`orders.notification` webhook + Menu API, written approval),
/// DeliveryHero POS program (PGP credentials, HTTPS plugin, Catalog Import API;
/// covers Talabat + HungerStation behind ONE agreement).
library;

/// One `deliveryPlatforms[]` violation at its exact JSON path.
class DeliveryPlatformViolation {
  const DeliveryPlatformViolation(this.path, this.message);

  /// Dot/bracket path into client_config.json, e.g.
  /// `deliveryPlatforms[0].credentialRef`.
  final String path;

  /// Human-readable violation description for the operator.
  final String message;

  @override
  String toString() => '"$path" $message';
}

/// One validated `deliveryPlatforms[]` row (the typed view the adapters read).
class DeliveryPlatformConfig {
  const DeliveryPlatformConfig({
    required this.id,
    required this.enabled,
    required this.storeId,
    required this.credentialRef,
  });

  /// One of [DeliveryPlatforms.catalog].
  final String id;

  /// Whether the adapter may activate. Absent key = false (inert).
  final bool enabled;

  /// The platform-side store identifier (`storeId` on Uber, the store/branch id
  /// on the DeliveryHero plugin).
  final String storeId;

  /// The NAME of the secret holder (an environment variable name resolved
  /// server-side) — never the secret value (L4).
  final String credentialRef;

  /// Parses one row defensively; returns null when it is not a valid, known
  /// platform row (validation has already reported the reason).
  static DeliveryPlatformConfig? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final storeId = raw['storeId'];
    final credentialRef = raw['credentialRef'];
    if (id is! String || !DeliveryPlatforms.catalog.contains(id)) return null;
    if (storeId is! String || credentialRef is! String) return null;
    return DeliveryPlatformConfig(
      id: id,
      enabled: raw['enabled'] == true,
      storeId: storeId,
      credentialRef: credentialRef,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'enabled': enabled,
    'credentialRef': credentialRef,
    'storeId': storeId,
  };

  @override
  String toString() =>
      'DeliveryPlatformConfig(id: $id, enabled: $enabled, storeId: $storeId)';
}

/// The validated platform vocabulary + the fail-closed section validator.
class DeliveryPlatforms {
  /// Uber Eats — the documented id used in the config and in the namespaced
  /// idempotency key (`uber_eats:ORDER123`).
  static const String uberEatsId = 'uber_eats';

  /// DeliveryHero POS program (Talabat / HungerStation / foodpanda behind one
  /// integration).
  static const String deliveryHeroId = 'delivery_hero';

  /// The ONLY platform ids a config may name. An unknown id is a violation
  /// (fail closed): a typo must never silently disable a platform.
  static const Set<String> catalog = <String>{uberEatsId, deliveryHeroId};

  /// A credentialRef is an environment-variable NAME (server-side secret
  /// holder), e.g. `UBER_EATS_WEBHOOK_SECRET`.
  static final RegExp credentialRefPattern = RegExp(r'^[A-Z][A-Z0-9_]{2,63}$');

  /// Prefixes that mean "a secret value was pasted, not a reference" (L4).
  static const List<String> forbiddenCredentialPrefixes = <String>[
    'sk_live_',
    'sk_test_',
    'whsec_',
    'pk_live_',
    'AIza',
    'ya29.',
    '-----BEGIN',
  ];

  /// True when [ref] looks like a real secret value rather than a ref name.
  static bool looksLikeSecretLiteral(Object? ref) {
    if (ref is! String) return false;
    final trimmed = ref.trim();
    for (final prefix in forbiddenCredentialPrefixes) {
      if (trimmed.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Validates the whole `deliveryPlatforms` section.
  ///
  /// STRICTLY WHEN PRESENT (the TOKENS/screen_variants rule): an absent/null
  /// section is VALID and leaves every adapter inert; a present-but-invalid row
  /// is a violation at its exact JSON path. Returns every violation (empty =
  /// valid); the runtime gate turns non-empty into a `ConfigException` so the
  /// boot blocks on the ConfigValidationErrorScreen.
  static List<DeliveryPlatformViolation> validatePlatforms(Object? raw) {
    final violations = <DeliveryPlatformViolation>[];
    if (raw == null) return violations;
    if (raw is! List) {
      violations.add(
        const DeliveryPlatformViolation(
          'deliveryPlatforms',
          'must be a list of platform rows when present '
              '({id, enabled, credentialRef, storeId})',
        ),
      );
      return violations;
    }
    final seen = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      final base = 'deliveryPlatforms[$i]';
      if (entry is! Map) {
        violations.add(DeliveryPlatformViolation(base, 'must be an object'));
        continue;
      }
      final id = entry['id'];
      if (id is! String || id.trim().isEmpty) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.id',
            'must be a non-empty platform id',
          ),
        );
        continue;
      }
      if (!catalog.contains(id)) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.id',
            'unknown platform id "$id" — allowed ids: ${catalog.toList()}',
          ),
        );
        continue;
      }
      if (!seen.add(id)) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.id',
            'duplicate platform id "$id" — at most one row per platform',
          ),
        );
        continue;
      }
      final enabled = entry['enabled'];
      if (enabled != null && enabled is! bool) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.enabled',
            'must be a boolean when present (got: $enabled)',
          ),
        );
      }
      // Disabled or absent = INERT: nothing else about the row is read, so
      // nothing else is required (the adapters never activate).
      if (enabled != true) continue;
      final storeId = entry['storeId'];
      if (storeId is! String || storeId.trim().isEmpty) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.storeId',
            'storeId is required and must be a non-empty string when '
                'enabled is true',
          ),
        );
      }
      final credentialRef = entry['credentialRef'];
      if (credentialRef is! String || credentialRef.trim().isEmpty) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.credentialRef',
            'credentialRef is required when enabled is true (the NAME of the '
                'secret holder, never the secret)',
          ),
        );
      } else if (looksLikeSecretLiteral(credentialRef)) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.credentialRef',
            'must be a secret REFERENCE (an environment variable name), never '
                'a secret literal',
          ),
        );
      } else if (!credentialRefPattern.hasMatch(credentialRef.trim())) {
        violations.add(
          DeliveryPlatformViolation(
            '$base.credentialRef',
            'must match ${credentialRefPattern.pattern} (an environment-style '
                'name)',
          ),
        );
      }
    }
    return violations;
  }

  /// The typed, ENABLED platform rows the adapters may use. A section with ANY
  /// violation yields no rows at all (fail closed — an ambiguous config never
  /// half-activates), and an absent/disabled section yields none (inert).
  static List<DeliveryPlatformConfig> enabledPlatforms(Object? raw) {
    if (raw is! List) return const <DeliveryPlatformConfig>[];
    if (validatePlatforms(raw).isNotEmpty) {
      return const <DeliveryPlatformConfig>[];
    }
    final enabled = <DeliveryPlatformConfig>[];
    for (final entry in raw) {
      final config = DeliveryPlatformConfig.fromMap(entry);
      if (config != null && config.enabled) enabled.add(config);
    }
    return enabled;
  }

  /// True when the section activates nothing (absent, empty or all-disabled).
  static bool isInert(Object? raw) => enabledPlatforms(raw).isEmpty;
}
