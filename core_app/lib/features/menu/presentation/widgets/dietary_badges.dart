import 'package:flutter/material.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../../domain/dietary_codes.dart';

/// Localised name for a declaration code. The vocabulary is closed
/// ([kAllergenCodes]), so the fallback only fires on data the write boundary
/// rejects; it renders the raw code rather than nothing, because a missing
/// allergen badge is indistinguishable from a missing allergen.
String allergenLabelOf(AppLocalizations loc, String code) => switch (code) {
  'eggs' => loc.allergenNameEggs,
  'milk' => loc.allergenNameMilk,
  'mustard' => loc.allergenNameMustard,
  'peanuts' => loc.allergenNamePeanuts,
  'crustaceans' => loc.allergenNameCrustaceans,
  'molluscs' => loc.allergenNameMolluscs,
  'fish' => loc.allergenNameFish,
  'sesame' => loc.allergenNameSesame,
  'soybeans' => loc.allergenNameSoybeans,
  'sulphites' => loc.allergenNameSulphites,
  'tree_nuts' => loc.allergenNameTreeNuts,
  'wheat_triticale' => loc.allergenNameWheatTriticale,
  'gluten' => loc.allergenNameGluten,
  _ => code,
};

/// Localised name for a suitability code (`vegan` reuses the long-standing
/// ARB key; the rest were added with P6-1).
String dietaryLabelOf(AppLocalizations loc, String code) => switch (code) {
  'vegan' => loc.vegan,
  'vegetarian' => loc.dietaryVegetarian,
  'pescatarian' => loc.dietaryPescatarian,
  'gluten_free' => loc.dietaryGlutenFree,
  'dairy_free' => loc.dietaryDairyFree,
  'nut_free' => loc.dietaryNutFree,
  _ => code,
};

/// The chips that carry P6-1's trust layer: what the dish SUITS, and what it
/// CONTAINS. The halal badge renders only when the claim is live (certified and
/// not expired) — an expired certification is not a claim (D-051).
class DietaryBadges extends StatelessWidget {
  const DietaryBadges({
    super.key,
    required this.allergens,
    required this.dietary,
    this.halalCertified = false,
    this.halalCertExpiresAt,
    this.notes = '',
    this.showNotes = false,
  });

  final List<String> allergens;
  final List<String> dietary;
  final bool halalCertified;
  final DateTime? halalCertExpiresAt;
  final String notes;

  /// The detail screen shows the cross-contamination note inline; list rows do
  /// not (it is prose, not a chip).
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final halalLive = isHalalClaimLive(
      certified: halalCertified,
      expiresAt: halalCertExpiresAt,
    );
    final hasNotes = showNotes && notes.trim().isNotEmpty;
    if (dietary.isEmpty && allergens.isEmpty && !halalLive && !hasNotes) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (halalLive)
              _Badge(
                label: loc.halalCertified,
                icon: Icons.verified_outlined,
                background: Theme.of(context).colorScheme.tertiaryContainer,
                foreground: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            for (final code in dietary)
              _Badge(
                label: dietaryLabelOf(loc, code),
                icon: Icons.eco_outlined,
                background: Theme.of(context).colorScheme.secondaryContainer,
                foreground: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            for (final code in allergens)
              _Badge(
                // "Contains sesame" reads as a statement about THIS dish, where
                // a bare "sesame" chip reads as a seasoning list.
                label: loc.containsAllergen(allergenLabelOf(loc, code)),
                icon: Icons.warning_amber_outlined,
                background: Theme.of(context).colorScheme.errorContainer,
                foreground: Theme.of(context).colorScheme.onErrorContainer,
              ),
          ],
        ),
        if (hasNotes)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              notes.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
