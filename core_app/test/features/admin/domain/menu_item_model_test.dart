import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';

void main() {
  group('MenuItemModel', () {
    test('constructor assigns id correctly', () {
      const item = MenuItemModel(id: 'item1', name: 'Pizza', priceCents: 1299);
      expect(item.id, 'item1');
      expect(item.name, 'Pizza');
      expect(item.priceCents, 1299);
    });

    test('default values are correct', () {
      const item = MenuItemModel(id: 'test');
      expect(item.name, '');
      expect(item.priceCents, 0);
      expect(item.description, '');
      expect(item.imageUrl, '');
      expect(item.isAvailable, true);
      expect(item.modifiers, []);
      expect(item.tags, []);
    });

    test('isGlobal returns true when branchId is null', () {
      const item = MenuItemModel(id: 'global1');
      expect(item.isGlobal, true);
    });

    test('isGlobal returns false when branchId is set', () {
      const item = MenuItemModel(id: 'branch1', branchId: 'branch_42');
      expect(item.isGlobal, false);
    });

    test('fromJson parses JSON correctly', () {
      final json = {
        'id': 'item1',
        'name': 'Burger',
        'priceCents': 899,
        'description': 'Tasty burger',
        'imageUrl': 'https://example.com/burger.jpg',
        'isAvailable': true,
        'tags': ['popular', 'beef'],
      };
      final item = MenuItemModel.fromJson(json);
      expect(item.id, 'item1');
      expect(item.name, 'Burger');
      expect(item.priceCents, 899);
      expect(item.isAvailable, true);
      expect(item.tags, ['popular', 'beef']);
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 'item2', 'name': 'Minimal'};
      final item = MenuItemModel.fromJson(json);
      expect(item.id, 'item2');
      expect(item.name, 'Minimal');
      expect(item.priceCents, 0);
      expect(item.description, '');
      expect(item.isAvailable, true);
    });

    test('mergeWith applies override fields', () {
      const global = MenuItemModel(
        id: 'item1',
        name: 'Basic Pizza',
        priceCents: 1000,
        imageUrl: 'global.jpg',
      );
      const override = MenuItemModel(
        id: 'item1',
        branchId: 'branch_1',
        name: 'Branch Pizza',
        priceCents: 1200,
      );
      final merged = global.mergeWith(override);
      expect(merged.id, 'item1');
      expect(merged.branchId, 'branch_1');
      expect(merged.name, 'Branch Pizza');
      expect(merged.priceCents, 1200);
      // imageUrl falls back to global since override is empty
      expect(merged.imageUrl, 'global.jpg');
    });

    test(
      'mergeWith keeps global imageUrl when override has empty imageUrl',
      () {
        const global = MenuItemModel(
          id: 'item1',
          name: 'Global Item',
          priceCents: 500,
          imageUrl: 'global.jpg',
        );
        const override = MenuItemModel(
          id: 'item1',
          branchId: 'branch_2',
          name: 'Branch Item',
        );
        final merged = global.mergeWith(override);
        expect(merged.imageUrl, 'global.jpg');
        expect(merged.id, 'item1');
        expect(merged.branchId, 'branch_2');
      },
    );

    test('toJson round-trips correctly', () {
      const item = MenuItemModel(
        id: 'roundtrip1',
        name: 'Test Item',
        priceCents: 1500,
        description: 'A test',
        isAvailable: false,
      );
      final json = item.toJson();
      final restored = MenuItemModel.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.priceCents, item.priceCents);
      expect(restored.isAvailable, item.isAvailable);
    });
  });
}
