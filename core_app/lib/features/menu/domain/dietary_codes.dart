/// P6-1 / D-052: the dietary vocabulary is fixed, append-only data — not free
/// text and not `tags`. This file is the ONE definition of the codes; the item
/// editor, the customer filter, model validation and the l10n keys all read it.
///
/// WHY a leaf module rather than `packages/core`: the menu item model must stay
/// importable by the thin shell (D-050, no Isar in that graph), and the core
/// barrel re-exports Isar. A leaf file with one dependency (`cloud_firestore`,
/// which is web-safe) keeps that boundary intact.
///
/// Full rationale and the regulator citations: `docs/DIETARY-VOCABULARY.md`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// What the item DECLARES it contains. Twelve Canadian allergen groups — with
/// crustaceans and molluscs split for filter value — plus `gluten`, which is a
/// five-grain declaration rather than an allergen (wheat is both).
const List<String> kAllergenCodes = <String>[
  'eggs',
  'milk',
  'mustard',
  'peanuts',
  'crustaceans',
  'molluscs',
  'fish',
  'sesame',
  'soybeans',
  'sulphites',
  'tree_nuts',
  'wheat_triticale',
  'gluten',
];

/// Who the item SUITS. A positive claim by the restaurant, never a
/// certification: `gluten_free` means "no gluten ingredients declared", and
/// cross-contamination belongs in `allergenNotes`.
const List<String> kDietaryCodes = <String>[
  'vegan',
  'vegetarian',
  'pescatarian',
  'gluten_free',
  'dairy_free',
  'nut_free',
];

/// The dietary codes exposed as inline filter chips. The remaining codes render
/// as badges only; a 390 px chip row cannot hold 19. Every [kAllergenCodes]
/// entry is reachable through the allergen sheet — filtering is the safety-shaped
/// affordance, so completeness matters there and only there.
const List<String> kDietaryFilterCodes = <String>[
  'vegan',
  'vegetarian',
  'gluten_free',
];

const List<String> _kHalalClaimFields = <String>[
  'halalCertified',
  'halalCertBody',
  'halalCertExpiresAt',
];

/// The claim fields the rules restrict to the owner (D-051). Exposed so a test
/// can assert the Dart list and `firestore.rules` name the same three keys.
List<String> get kHalalClaimFields => List.unmodifiable(_kHalalClaimFields);

/// Thrown when stored or submitted menu metadata carries a code outside
/// [kAllergenCodes] / [kDietaryCodes].
///
/// WHY a named error and not a silent filter: a dropped allergen code is a badge
/// that cannot be shown, and the absence of a badge reads as the absence of the
/// allergen. Failing loudly is the only safe posture for this data.
class DietaryCodeException implements Exception {
  const DietaryCodeException(this.field, this.code);

  final String field;
  final String code;

  @override
  String toString() =>
      'DietaryCodeException: unknown $field code "$code" '
      '(allowed: ${field == 'allergens' ? kAllergenCodes : kDietaryCodes})';
}

/// Validates a code list against its vocabulary. Throws [DietaryCodeException].
void validateDietaryCodes(String field, Iterable<String> codes) {
  final allowed = field == 'allergens' ? kAllergenCodes : kDietaryCodes;
  for (final code in codes) {
    if (!allowed.contains(code)) {
      throw DietaryCodeException(field, code);
    }
  }
}

/// True when the certification claim may be displayed: certified AND not
/// expired. Fail-closed — a claim with no expiry is not treated as expired
/// (the owner stated one), but a claim whose date has passed is.
bool isHalalClaimLive({required bool certified, DateTime? expiresAt}) {
  if (!certified) return false;
  if (expiresAt == null) return true;
  return expiresAt.isAfter(DateTime.now());
}

/// Normalises a Firestore `Timestamp`, an ISO-8601 string, or a `DateTime` into a
/// `DateTime`, and writes ISO-8601 back.
///
/// WHY not `packages/core`'s converter: that one lives in `auth/user_model.dart`
/// and is only reachable through the core barrel, which re-exports Isar — the
/// exact import this model must not have (D-050).
class CertExpiryConverter extends JsonConverter<DateTime?, Object?> {
  const CertExpiryConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    // Always UTC: `Timestamp.toDate()` returns a LOCAL DateTime for the same
    // instant, so without this the value would round-trip back to an
    // offset-bearing ISO string and two equal dates would serialize
    // differently depending on the device's timezone.
    if (json is DateTime) return json.toUtc();
    if (json is Timestamp) return json.toDate().toUtc();
    if (json is String) return DateTime.tryParse(json)?.toUtc();
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}
