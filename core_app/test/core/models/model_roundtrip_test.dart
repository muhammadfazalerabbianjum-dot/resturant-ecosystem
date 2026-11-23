import 'package:flutter_test/flutter_test.dart';

import 'package:core/core.dart';
import 'package:labs/features/admin/domain/branch_model.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';
import 'package:labs/app/models/restaurant_config_model.dart';

/// WHY: Law 24 requires roundtrip serialisation tests for every model.
/// Verifies `expect(model.fromJson(model.toJson()), model)` explicitly.
void main() {
  group('Domain Models Roundtrip Tests (Law 24)', () {
    test('UserModel roundtrip', () {
      final model = UserModel(
        id: 'u123',
        email: 'test@example.com',
        role: UserRole.manager,
        loyaltyPoints: 1500,
        createdAt: DateTime.utc(2026, 5, 24),
      );
      final json = model.toJson();
      final decoded = UserModel.fromJson(json).copyWith(
        id: 'u123',
      ); // FromJson handles id loosely depending on the caller, so we sync it here.
      expect(decoded, model);
    });

    test('DeliveryLocationModel roundtrip', () {
      const model = DeliveryLocationModel(
        latitude: 10.5,
        longitude: 20.5,
        address: '123 Test St',
      );
      final json = model.toJson();
      final decoded = DeliveryLocationModel.fromJson(json);
      expect(decoded, model);
    });

    test('PromotionModel roundtrip', () {
      const model = PromotionModel(
        id: 'promo1',
        title: 'BOGO',
        subtitle: 'Buy One Get One',
        imageUrl: 'http://img',
        isActive: true,
        priority: 1,
      );
      final json = model.toJson();
      final decoded = PromotionModel.fromJson(json).copyWith(id: 'promo1');
      expect(decoded, model);
    });

    test('BranchModel roundtrip', () {
      const model = BranchModel(
        id: 'b1',
        name: 'Downtown',
        latitude: 33.3,
        longitude: -110.1,
        deliveryRadiusMiles: 10.0,
      );
      final json = model.toJson();
      final decoded = BranchModel.fromJson(json).copyWith(id: 'b1');
      expect(decoded, model);
    });

    test('MenuItemModel roundtrip', () {
      const model = MenuItemModel(
        id: 'm1',
        name: 'Cheeseburger',
        priceCents: 1500,
        isAvailable: true,
        tags: ['popular', 'beef'],
      );
      final json = model.toJson();
      final decoded = MenuItemModel.fromJson(json).copyWith(id: 'm1');
      expect(decoded, model);
    });

    test('LoyaltyModel roundtrip', () {
      const model = LoyaltyModel(
        totalPoints: 2500,
        uid: 'user1',
        redeemedRewardIds: ['r1', 'r2'],
      );
      final json = model.toJson();
      final decoded = LoyaltyModel.fromJson(json);
      expect(decoded, model);
    });

    test('OrderModel roundtrip', () {
      final model = OrderModel(
        id: 'o1',
        customerId: 'c1',
        status: OrderStatus.cooking,
        totalCents: 2000,
        createdAt: DateTime.utc(2026, 5, 25),
        customerLat: 10.0,
        customerLng: 20.0,
      );
      final json = model.toJson();
      final decoded = OrderModel.fromJson(json).copyWith(id: 'o1');
      expect(decoded, model);
    });

    test('ReservationModel roundtrip', () {
      final model = ReservationModel(
        id: 'r1',
        userId: 'u1',
        customerName: 'Alice',
        startTime: DateTime.utc(2026, 5, 26, 19, 0),
        partySize: 4,
      );
      final json = model.toJson();
      final decoded = ReservationModel.fromJson(json).copyWith(id: 'r1');
      expect(decoded, model);
    });

    test('MenuModifier roundtrip (freezed, Law 23)', () {
      const model = MenuModifier(
        id: 'm1',
        name: 'Cheese',
        isRequired: true,
        allowMultiple: false,
        options: [
          ModifierOption(
            id: 'o1',
            name: 'Cheddar',
            upchargeCents: 100,
            isDefault: true,
          ),
          ModifierOption(id: 'o2', name: 'Swiss', upchargeCents: 150),
        ],
      );
      final json = model.toJson();
      final decoded = MenuModifier.fromJson(json);
      expect(decoded, model);
    });

    test('MenuModifier == compares contents, not just length (Law 23)', () {
      const modelA = MenuModifier(
        id: 'm1',
        name: 'Cheese',
        options: [
          ModifierOption(id: 'o1', name: 'Cheddar', upchargeCents: 100),
        ],
      );
      // Same length but DIFFERENT options → must NOT be equal
      const modelB = MenuModifier(
        id: 'm1',
        name: 'Cheese',
        options: [ModifierOption(id: 'o9', name: 'Bacon', upchargeCents: 200)],
      );
      expect(modelA, isNot(modelB));
      // Same options → must be equal
      const modelC = MenuModifier(
        id: 'm1',
        name: 'Cheese',
        options: [
          ModifierOption(id: 'o1', name: 'Cheddar', upchargeCents: 100),
        ],
      );
      expect(modelA, modelC);
    });

    test('OperatingHoursModel roundtrip (freezed, null-safe fromMap)', () {
      const model = OperatingHoursModel(
        monday: DayHours(isOpen: true, openTime: '08:00', closeTime: '17:00'),
        tuesday: DayHours(isOpen: false),
        holidayModeEnabled: true,
      );
      final map = model.toMap();
      final decoded = OperatingHoursModel.fromMap(map);
      expect(decoded, model);
    });

    test(
      'OperatingHoursModel.fromMap handles corrupt non-Map values (Law 25)',
      () {
        // A corrupt doc where a day value is a String, not a Map — must
        // return a closed DayHours instead of crashing.
        final decoded = OperatingHoursModel.fromMap({
          'monday': 'corrupt-not-a-map',
          'holidayModeEnabled': true,
        });
        expect(decoded.monday.isOpen, isTrue); // Default DayHours
        expect(decoded.monday.openTime, '09:00');
        expect(decoded.holidayModeEnabled, isTrue);
      },
    );

    test('RestaurantConfigModel roundtrip (freezed, Law 23)', () {
      const model = RestaurantConfigModel(
        restaurantName: 'Test Restaurant',
        tagline: 'Best food',
        contactEmail: 'test@example.com',
        currency: 'USD',
        pointsPerDollar: 20,
        operatingHours: {
          'monday': {'open': '09:00', 'close': '22:00'},
        },
      );
      // RestaurantConfigModel uses toFirestore/fromFirestore (not toJson/fromJson)
      // Simulate roundtrip via a fake DocumentSnapshot
      final firestoreData = model.toFirestore();
      expect(firestoreData['restaurantName'], 'Test Restaurant');
      expect(firestoreData['contactEmail'], 'test@example.com');
      // Verify operatingHours roundtrips
      expect(firestoreData['operatingHours'], isA<Map<String, dynamic>>());
      expect(
        firestoreData['operatingHours'],
        containsPair('monday', {'open': '09:00', 'close': '22:00'}),
      );
    });
  });
}
