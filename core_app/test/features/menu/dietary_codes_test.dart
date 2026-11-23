// P6-1 (D-051/D-052) — the dietary vocabulary is a contract, so it is pinned
// rather than described. Every assertion here is against the published doc
// (`docs/DIETARY-VOCABULARY.md`) and the regulator list behind it, not against
// whatever the code happens to return.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart' as admin;
import 'package:labs/features/menu/domain/dietary_codes.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

void main() {
  group('vocabulary is pinned (adding a code must be a deliberate diff)', () {
    test('the 13 declaration codes are exactly these', () {
      expect(kAllergenCodes, <String>[
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
      ]);
    });

    test('the 6 dietary codes are exactly these', () {
      expect(kDietaryCodes, <String>[
        'vegan',
        'vegetarian',
        'pescatarian',
        'gluten_free',
        'dairy_free',
        'nut_free',
      ]);
    });

    test('wheat is an allergen and gluten is a declaration: both exist', () {
      // The error the research corrected: collapsing these told a coeliac
      // nothing about barley.
      expect(kAllergenCodes, contains('wheat_triticale'));
      expect(kAllergenCodes, contains('gluten'));
      expect(kAllergenCodes, isNot(contains('cereals_gluten')));
    });

    test('EU-only codes are absent (celery, lupin are not Canadian)', () {
      expect(kAllergenCodes, isNot(contains('celery')));
      expect(kAllergenCodes, isNot(contains('lupin')));
    });

    test('every filter chip is a real dietary code', () {
      expect(kDietaryFilterCodes, isNotEmpty);
      for (final code in kDietaryFilterCodes) {
        expect(kDietaryCodes, contains(code));
      }
    });

    test('codes are lowercase snake_case ASCII (they are stored keys)', () {
      final all = [...kAllergenCodes, ...kDietaryCodes];
      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final code in all) {
        expect(pattern.hasMatch(code), isTrue, reason: 'bad code: $code');
      }
      expect(all.toSet().length, all.length, reason: 'duplicate code');
    });
  });

  group('validation fails loudly and names the offender', () {
    test('known codes pass', () {
      expect(
        () => validateDietaryCodes('allergens', ['sesame', 'gluten']),
        returnsNormally,
      );
      expect(() => validateDietaryCodes('dietary', ['vegan']), returnsNormally);
    });

    test('an unknown code throws with field and code in the message', () {
      expect(
        () => validateDietaryCodes('allergens', ['sesame', 'halal_v2']),
        throwsA(
          isA<DietaryCodeException>()
              .having((e) => e.field, 'field', 'allergens')
              .having((e) => e.code, 'code', 'halal_v2')
              .having((e) => e.toString(), 'message', contains('halal_v2')),
        ),
      );
    });

    test('a code from the other axis is rejected', () {
      // `vegan` is dietary, not a declaration: cross-axis use would make the
      // filter hide items for the wrong reason.
      expect(
        () => validateDietaryCodes('allergens', ['vegan']),
        throwsA(isA<DietaryCodeException>()),
      );
    });
  });

  group('an expired certification is not a claim', () {
    test('certified + future = live', () {
      expect(
        isHalalClaimLive(
          certified: true,
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
        isTrue,
      );
    });

    test('certified + past = NOT live (fail closed)', () {
      expect(
        isHalalClaimLive(
          certified: true,
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('not certified = not live, whatever the dates say', () {
      expect(
        isHalalClaimLive(
          certified: false,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });

    test('no expiry = live while certified (the owner stated no end date)', () {
      expect(isHalalClaimLive(certified: true), isTrue);
    });
  });

  group('model round-trip (customer projection)', () {
    test('new fields parse and serialize', () {
      final model = MenuItemModel.fromJson({
        'id': 'i1',
        'priceCents': 1200,
        'allergens': ['sesame', 'gluten'],
        'dietary': ['vegan'],
        'allergenNotes': 'shared fryer',
        'halalCertified': true,
        'halalCertBody': 'body-1',
        'halalCertExpiresAt': '2027-01-01T00:00:00.000Z',
      });
      expect(model.allergens, ['sesame', 'gluten']);
      expect(model.dietary, ['vegan']);
      expect(model.allergenNotes, 'shared fryer');
      expect(model.halalCertified, isTrue);
      expect(model.halalCertExpiresAt, DateTime.utc(2027, 1, 1));

      final json = model.toJson();
      expect(json['allergens'], ['sesame', 'gluten']);
      expect(json['halalCertExpiresAt'], '2027-01-01T00:00:00.000Z');
    });

    test('a Firestore Timestamp is normalised on the way in', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 6, 1));
      final model = MenuItemModel.fromJson({
        'id': 'i2',
        'priceCents': 100,
        'halalCertified': true,
        'halalCertExpiresAt': ts,
      });
      expect(model.halalCertExpiresAt, DateTime.utc(2026, 6, 1));
    });

    test('a legacy document with none of the fields still parses', () {
      // The exact pre-card shape: nothing added, nothing required.
      final model = MenuItemModel.fromJson({
        'id': 'legacy',
        'name': 'Burger',
        'priceCents': 1000,
        'branchId': 'branch-1',
        'tags': ['Halal'],
      });
      expect(model.allergens, isEmpty);
      expect(model.dietary, isEmpty);
      expect(model.allergenNotes, '');
      expect(model.halalCertified, isFalse);
      expect(model.halalCertExpiresAt, isNull);
      expect(model.priceCents, 1000);
    });
  });

  group('model round-trip (admin projection)', () {
    test('new fields parse and serialize', () {
      final model = admin.MenuItemModel.fromJson({
        'id': 'a1',
        'priceCents': 900,
        'allergens': ['milk'],
        'dietary': ['vegetarian'],
        'halalCertified': true,
        'halalCertExpiresAt': '2027-03-01T00:00:00.000Z',
      });
      expect(model.allergens, ['milk']);
      expect(model.dietary, ['vegetarian']);
      expect(model.halalCertified, isTrue);
      expect(model.toJson()['halalCertExpiresAt'], '2027-03-01T00:00:00.000Z');
    });

    test('a branch override INHERITS facts but NOT the certification claim', () {
      const global = admin.MenuItemModel(
        id: 'g1',
        priceCents: 1000,
        allergens: ['sesame'],
        dietary: ['vegan'],
        allergenNotes: 'shared fryer',
        halalCertified: true,
        halalCertBody: 'body-1',
      );
      const override = admin.MenuItemModel(id: 'g1', priceCents: 1100);

      final merged = global.mergeWith(override);
      expect(merged.allergens, ['sesame'], reason: 'facts inherit');
      expect(merged.dietary, ['vegan']);
      expect(merged.allergenNotes, 'shared fryer');
      // The claim does NOT inherit: the branch's kitchen is not certified just
      // because the global item is.
      expect(merged.halalCertified, isFalse);
      expect(merged.halalCertBody, '');
    });
  });

  group('Dart and rules cannot drift on the claim fields', () {
    test('every kHalalClaimFields key appears in firestore.rules', () {
      final rules = File('firestore.rules').readAsStringSync();
      for (final key in kHalalClaimFields) {
        expect(
          rules.contains("'$key'"),
          isTrue,
          reason:
              '$key is restricted by D-051 but absent from firestore.rules - '
              'the Dart model would offer a field the rules do not guard',
        );
      }
    });
  });
}
