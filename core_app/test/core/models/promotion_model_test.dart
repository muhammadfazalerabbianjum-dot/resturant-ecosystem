import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

void main() {
  group('PromotionModel Tests (Law 2 Compliance)', () {
    test('JSON Serialization maps correctly for valid promotion', () {
      final json = {
        'id': 'promo123',
        'imageUrl': 'https://carnama.com/banner.png',
        'actionUrl': '/menu?promo=true',
        'isActive': true,
        'priority': 0,
        'createdAt': '2026-05-19T00:00:00.000Z',
      };

      final promotion = PromotionModel.fromJson(json);

      expect(promotion.id, 'promo123');
      expect(promotion.imageUrl, 'https://carnama.com/banner.png');
      expect(promotion.actionUrl, '/menu?promo=true');
      expect(promotion.isActive, isTrue);
      expect(promotion.priority, 0);
    });

    test('JSON Serialization defaults work when optional fields missing', () {
      final json = {
        'id': 'promo456',
        'imageUrl': 'https://carnama.com/banner2.png',
      };

      final promotion = PromotionModel.fromJson(json);

      expect(promotion.id, 'promo456');
      expect(promotion.isActive, isTrue); // Should default to true
      expect(promotion.priority, 99); // Should default to low priority
      expect(promotion.actionUrl, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = PromotionModel(
        id: 'promo-rt',
        imageUrl: 'https://example.com/img.png',
        title: 'Test Promo',
        subtitle: 'Test subtitle',
        actionUrl: '/test',
        isActive: true,
        priority: 5,
        createdAt: DateTime(2026, 7, 1),
      );

      final json = original.toJson();
      final restored = PromotionModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.actionUrl, original.actionUrl);
      expect(restored.isActive, original.isActive);
      expect(restored.priority, original.priority);
    });

    test('constructor defaults are correct', () {
      const promo = PromotionModel(id: 'promo-defaults');
      expect(promo.imageUrl, '');
      expect(promo.isActive, true);
      expect(promo.priority, 99);
      expect(promo.title, isNull);
      expect(promo.subtitle, isNull);
      expect(promo.actionUrl, isNull);
      expect(promo.createdAt, isNull);
    });

    test('copyWith creates modified copy', () {
      const original = PromotionModel(id: 'promo-copy', isActive: true);
      final modified = original.copyWith(isActive: false, priority: 1);
      expect(original.isActive, true);
      expect(modified.isActive, false);
      expect(modified.priority, 1);
      expect(modified.id, 'promo-copy');
    });

    test('equality holds for identical models', () {
      const a = PromotionModel(id: 'promo-eq', isActive: true, priority: 5);
      const b = PromotionModel(id: 'promo-eq', isActive: true, priority: 5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality detects different id', () {
      const a = PromotionModel(id: 'promo-a');
      const b = PromotionModel(id: 'promo-b');
      expect(a, isNot(equals(b)));
    });
  });
}
