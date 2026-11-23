// P6-1 (D-052): the customer filter's semantics, tested without a widget tree.
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/domain/dietary_filter.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

MenuItemModel item(
  String id, {
  List<String> dietary = const [],
  List<String> allergens = const [],
}) => MenuItemModel(
  id: id,
  priceCents: 1000,
  dietary: dietary,
  allergens: allergens,
);

void main() {
  final items = [
    item('vegan-plain', dietary: ['vegan']),
    item('vegan-sesame', dietary: ['vegan'], allergens: ['sesame']),
    item('veg-milk', dietary: ['vegetarian'], allergens: ['milk']),
    item('meat', allergens: ['gluten']),
  ];

  test('an empty filter is a no-op and returns the SAME list', () {
    expect(identical(filterByDietary(items), items), isTrue);
  });

  test('a dietary chip keeps only items carrying that claim', () {
    final result = filterByDietary(items, dietary: {'vegan'});
    expect(result.map((i) => i.id), ['vegan-plain', 'vegan-sesame']);
  });

  test('two dietary chips compose as AND, not OR', () {
    final both = [
      item('both', dietary: ['vegan', 'gluten_free']),
      item('vegan-only', dietary: ['vegan']),
    ];
    final result = filterByDietary(both, dietary: {'vegan', 'gluten_free'});
    expect(result.map((i) => i.id), ['both']);
  });

  test('an allergen exclusion removes every item declaring it', () {
    final result = filterByDietary(items, excludeAllergens: {'sesame'});
    expect(result.map((i) => i.id), ['vegan-plain', 'veg-milk', 'meat']);
  });

  test(
    'exclusion is exhaustive: an item declaring two excluded codes is gone',
    () {
      final multi = item('multi', allergens: ['milk', 'sesame', 'gluten']);
      expect(
        filterByDietary([multi], excludeAllergens: {'gluten'}).isEmpty,
        isTrue,
      );
    },
  );

  test('dietary and exclusion compose (AND)', () {
    final result = filterByDietary(
      items,
      dietary: {'vegan'},
      excludeAllergens: {'sesame'},
    );
    expect(result.map((i) => i.id), ['vegan-plain']);
  });

  test('the match count agrees with the filtered length', () {
    expect(
      dietaryFilterMatchCount(items, excludeAllergens: {'sesame'}),
      filterByDietary(items, excludeAllergens: {'sesame'}).length,
    );
  });

  test('an item with no declarations is only removed by a dietary filter', () {
    final bare = item('bare');
    expect(filterByDietary([bare], excludeAllergens: {'sesame'}), [bare]);
    expect(filterByDietary([bare], dietary: {'vegan'}), isEmpty);
  });
}
