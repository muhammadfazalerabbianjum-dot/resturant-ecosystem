import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';

void main() {
  group('CartValidatorService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CartValidatorService sut;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      sut = CartValidatorService(firestore: fakeFirestore);
    });

    test('returns Success when all items match live prices', () async {
      await fakeFirestore.collection('menus').doc('item1').set({
        'isAvailable': true,
        'priceCents': 1500,
      });

      final result = await sut.validate([
        {'id': 'item1', 'name': 'Burger', 'priceCents': 1500},
      ]);

      expect(result, isA<CartValidationSuccess>());
    });

    test('returns Failed when price has drifted', () async {
      await fakeFirestore.collection('menus').doc('item1').set({
        'isAvailable': true,
        'priceCents': 1800,
      });

      final result = await sut.validate([
        {'id': 'item1', 'name': 'Burger', 'priceCents': 1500},
      ]);

      expect(result, isA<CartValidationFailed>());
      final failed = result as CartValidationFailed;
      expect(failed.failures.isNotEmpty, isTrue);
      expect(failed.failures.first.reason, contains('price'));
    });

    test('returns Failed for ghost item (doc deleted)', () async {
      final result = await sut.validate([
        {'id': 'ghost_item', 'name': 'Deleted Dish', 'priceCents': 1000},
      ]);

      expect(result, isA<CartValidationFailed>());
      final failed = result as CartValidationFailed;
      expect(failed.failures.isNotEmpty, isTrue);
      expect(failed.failures.first.reason, contains('removed'));
    });

    test('returns Failed for unpublished item (isAvailable=false)', () async {
      await fakeFirestore.collection('menus').doc('item1').set({
        'isAvailable': false,
        'priceCents': 1500,
      });

      final result = await sut.validate([
        {'id': 'item1', 'name': 'Sold Out Dish', 'priceCents': 1500},
      ]);

      expect(result, isA<CartValidationFailed>());
      final failed = result as CartValidationFailed;
      expect(failed.failures.isNotEmpty, isTrue);
      expect(failed.failures.first.reason, contains('unavailable'));
    });

    test('handles empty cart gracefully without throwing', () async {
      final result = await sut.validate([]);
      expect(result, isA<CartValidationSuccess>());
    });
  });
}
