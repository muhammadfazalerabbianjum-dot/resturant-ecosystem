import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

// Spec: MenuItemModel contract:
// - Required: id, name, priceCents, category, isAvailable
// - Optional: imageUrl (nullable)
// - isAvailable defaults to true
// Tests verify model structure — repository requires complex dependencies (Isar, Firebase)

void main() {
  group('MenuItemModel — Spec Contract', () {
    test('Model has all required fields per spec', () {
      const item = MenuItemModel(
        id: 'test',
        name: 'Test Burger',
        priceCents: 999,
        category: 'mains',
        isAvailable: true,
      );
      expect(item.id, equals('test'));
      expect(item.name, equals('Test Burger'));
      expect(item.priceCents, equals(999));
      expect(item.category, equals('mains'));
      expect(item.isAvailable, equals(true));
    });

    test('imageUrl is nullable per spec', () {
      const item = MenuItemModel(
        id: 'minimal',
        name: 'Minimal',
        priceCents: 0,
        category: 'other',
      );
      expect(item.imageUrl, isNull);
    });

    test('isAvailable defaults to true per spec', () {
      const item = MenuItemModel(
        id: 'default_test',
        name: 'Test',
        priceCents: 100,
        category: 'mains',
      );
      expect(item.isAvailable, equals(true));
    });

    test('Model round-trips through JSON per spec', () {
      const original = MenuItemModel(
        id: 'roundtrip',
        name: 'Pizza',
        priceCents: 1499,
        category: 'mains',
        isAvailable: true,
        imageUrl: 'http://example.com/pizza.jpg',
      );

      final json = original.toJson();
      final restored = MenuItemModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.priceCents, equals(original.priceCents));
      expect(restored.category, equals(original.category));
      expect(restored.isAvailable, equals(original.isAvailable));
      expect(restored.imageUrl, equals(original.imageUrl));
    });
  });
}
