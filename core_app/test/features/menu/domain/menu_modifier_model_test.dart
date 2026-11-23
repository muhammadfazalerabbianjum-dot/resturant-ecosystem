import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';

void main() {
  group('ModifierOption', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'opt1',
        'name': 'Extra Cheese',
        'upchargeCents': 150,
        'isDefault': true,
      };
      final option = ModifierOption.fromJson(json);
      expect(option.id, 'opt1');
      expect(option.name, 'Extra Cheese');
      expect(option.upchargeCents, 150);
      expect(option.isDefault, true);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};
      final option = ModifierOption.fromJson(json);
      expect(option.id, '');
      expect(option.name, '');
      expect(option.upchargeCents, 0);
      expect(option.isDefault, false);
    });

    test('toJson produces correct map', () {
      const option = ModifierOption(
        id: 'opt2',
        name: 'No Onions',
        upchargeCents: 0,
        isDefault: false,
      );
      final json = option.toJson();
      expect(json['id'], 'opt2');
      expect(json['name'], 'No Onions');
      expect(json['upchargeCents'], 0);
      expect(json['isDefault'], false);
    });

    test('roundtrip preserves all fields', () {
      const original = ModifierOption(
        id: 'opt3',
        name: 'Add Bacon',
        upchargeCents: 200,
        isDefault: true,
      );
      final json = original.toJson();
      final decoded = ModifierOption.fromJson(json);
      expect(decoded, original);
    });

    test('equality works correctly', () {
      const a = ModifierOption(
        id: 'x',
        name: 'A',
        upchargeCents: 100,
        isDefault: true,
      );
      const b = ModifierOption(
        id: 'x',
        name: 'A',
        upchargeCents: 100,
        isDefault: true,
      );
      const c = ModifierOption(
        id: 'y',
        name: 'A',
        upchargeCents: 100,
        isDefault: true,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('MenuModifier', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'mod1',
        'name': 'Cheese Options',
        'isRequired': true,
        'allowMultiple': false,
        'options': [
          {
            'id': 'o1',
            'name': 'Cheddar',
            'upchargeCents': 100,
            'isDefault': false,
          },
          {
            'id': 'o2',
            'name': 'Swiss',
            'upchargeCents': 150,
            'isDefault': true,
          },
        ],
      };
      final modifier = MenuModifier.fromJson(json);
      expect(modifier.id, 'mod1');
      expect(modifier.name, 'Cheese Options');
      expect(modifier.isRequired, true);
      expect(modifier.allowMultiple, false);
      expect(modifier.options.length, 2);
      expect(modifier.options[0].name, 'Cheddar');
      expect(modifier.options[1].name, 'Swiss');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};
      final modifier = MenuModifier.fromJson(json);
      expect(modifier.id, '');
      expect(modifier.name, '');
      expect(modifier.isRequired, false);
      expect(modifier.allowMultiple, false);
      expect(modifier.options, isEmpty);
    });

    test('toJson produces correct map', () {
      const modifier = MenuModifier(
        id: 'mod2',
        name: 'Size',
        isRequired: true,
        allowMultiple: false,
        options: [
          ModifierOption(
            id: 's1',
            name: 'Small',
            upchargeCents: 0,
            isDefault: true,
          ),
          ModifierOption(
            id: 's2',
            name: 'Large',
            upchargeCents: 200,
            isDefault: false,
          ),
        ],
      );
      final json = modifier.toJson();
      expect(json['id'], 'mod2');
      expect(json['name'], 'Size');
      expect(json['isRequired'], true);
      expect(json['allowMultiple'], false);
      expect((json['options'] as List).length, 2);
    });

    test('roundtrip preserves all fields', () {
      const original = MenuModifier(
        id: 'mod3',
        name: 'Toppings',
        isRequired: false,
        allowMultiple: true,
        options: [
          ModifierOption(
            id: 't1',
            name: 'Pepperoni',
            upchargeCents: 100,
            isDefault: false,
          ),
          ModifierOption(
            id: 't2',
            name: 'Mushrooms',
            upchargeCents: 75,
            isDefault: false,
          ),
        ],
      );
      final json = original.toJson();
      final decoded = MenuModifier.fromJson(json);
      expect(decoded.id, original.id);
      expect(decoded.name, original.name);
      expect(decoded.isRequired, original.isRequired);
      expect(decoded.allowMultiple, original.allowMultiple);
      expect(decoded.options.length, original.options.length);
    });

    test('equality works correctly', () {
      const a = MenuModifier(
        id: 'x',
        name: 'A',
        isRequired: true,
        allowMultiple: false,
      );
      const b = MenuModifier(
        id: 'x',
        name: 'A',
        isRequired: true,
        allowMultiple: false,
      );
      const c = MenuModifier(
        id: 'y',
        name: 'A',
        isRequired: true,
        allowMultiple: false,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
