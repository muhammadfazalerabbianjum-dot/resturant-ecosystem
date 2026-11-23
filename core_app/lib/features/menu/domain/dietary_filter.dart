import 'menu_item_model.dart';

/// P6-1 (D-052) — the customer-side dietary filter, kept pure so it can be
/// tested without a widget tree and reasoned about without a screen.
///
/// SEMANTICS: the two sets compose as AND. `dietary` must all be present (a
/// diner asking for vegan + gluten-free is asking for both), and NO item whose
/// `allergens` intersects `excludeAllergens` survives (an exclusion that only
/// half-applies is worse than none). Empty sets are no-ops, so the unfiltered
/// path is exactly the input list.
List<MenuItemModel> filterByDietary(
  List<MenuItemModel> items, {
  Set<String> dietary = const <String>{},
  Set<String> excludeAllergens = const <String>{},
}) {
  if (dietary.isEmpty && excludeAllergens.isEmpty) return items;
  return items.where((item) {
    if (!dietary.every(item.dietary.contains)) return false;
    for (final allergen in item.allergens) {
      if (excludeAllergens.contains(allergen)) return false;
    }
    return true;
  }).toList();
}

/// How many items a filter would remove — used by the sheet to say what the
/// selection does before the diner commits to it.
int dietaryFilterMatchCount(
  List<MenuItemModel> items, {
  Set<String> dietary = const <String>{},
  Set<String> excludeAllergens = const <String>{},
}) => filterByDietary(
  items,
  dietary: dietary,
  excludeAllergens: excludeAllergens,
).length;
