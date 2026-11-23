import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/menu/data/menu_repository.dart';

void main() {
  group('B2-6: Defensive Modifier Option Parsing', () {
    test('MenuModifier.fromJson handles malformed option lists cleanly', () {
      final jsonWithMalformedOptions = {
        'id': 'mod_1',
        'name': 'Choice of Sauce',
        'isRequired': true,
        'allowMultiple': false,
        'options': [
          // Valid option
          {
            'id': 'opt_1',
            'name': 'Garlic Sauce',
            'upchargeCents': 50,
            'isDefault': false,
          },
          // Null option entry (malformed)
          null,
          // String option entry (malformed)
          'invalid_string_option',
          // Valid option
          {
            'id': 'opt_2',
            'name': 'Spicy Sauce',
            'upchargeCents': 100,
            'isDefault': true,
          },
        ],
      };

      final modifier = MenuModifier.fromJson(jsonWithMalformedOptions);

      expect(modifier.id, equals('mod_1'));
      expect(modifier.name, equals('Choice of Sauce'));
      // Malformed entries skipped, 2 valid options preserved
      expect(modifier.options.length, equals(2));
      expect(modifier.options[0].id, equals('opt_1'));
      expect(modifier.options[1].id, equals('opt_2'));
    });

    test(
      'MenuModifier.fromJson returns empty list when options field is not a List',
      () {
        final jsonWithInvalidType = {
          'id': 'mod_2',
          'name': 'Size',
          'options': 'not_a_list',
        };

        final modifier = MenuModifier.fromJson(jsonWithInvalidType);

        expect(modifier.options, isEmpty);
      },
    );
  });

  group('B2-3: MenuFetchException Handling', () {
    test('MenuFetchException stores error and displays clear toString', () {
      final originalError = Exception('Network Timeout');
      final exc = MenuFetchException(originalError);

      expect(exc.error, equals(originalError));
      expect(
        exc.toString(),
        contains('MenuFetchException: Exception: Network Timeout'),
      );
    });
  });
}
