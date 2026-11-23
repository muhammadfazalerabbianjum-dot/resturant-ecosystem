import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';

// Spec: LoyaltyCalculator.calculatePoints contract:
// - 100 cents = 1 point (centsPerPoint = 100)
// - Formula: floor(totalCents / 100), minimum 0
// - Negative input returns 0 (no negative points)
// - Zero input returns 0
// Tests assert against hard-coded spec values — no mirroring.
//
// Tier thresholds are CONFIG-DRIVEN (B4-6): the model's declared defaults on
// RestaurantConfigModel are the single source of truth for the fallback, and
// the independent `goldThresholdPoints` field is tested separately.

void main() {
  group('LoyaltyCalculator — Spec Contract', () {
    test('100 cents yields exactly 1 point', () {
      // Spec: 100 / 100 = 1.0 → floor() = 1
      expect(LoyaltyCalculator.calculatePoints(100), equals(1));
    });

    test('450 cents yields 4 points (floor division)', () {
      // Spec: 450 / 100 = 4.5 → floor() = 4
      expect(LoyaltyCalculator.calculatePoints(450), equals(4));
    });

    test('9999 cents yields 99 points', () {
      // Spec: 9999 / 100 = 99.99 → floor() = 99
      expect(LoyaltyCalculator.calculatePoints(9999), equals(99));
    });

    test('10000 cents yields exactly 100 points', () {
      // Spec: 10000 / 100 = 100.0 → floor() = 100
      expect(LoyaltyCalculator.calculatePoints(10000), equals(100));
    });

    test('Zero spend yields 0 points', () {
      // Spec: 0 / 100 = 0 → floor() = 0
      expect(LoyaltyCalculator.calculatePoints(0), equals(0));
    });

    test('Negative spend yields 0 points (no negative points)', () {
      // Spec: negative input returns 0
      expect(LoyaltyCalculator.calculatePoints(-500), equals(0));
      expect(LoyaltyCalculator.calculatePoints(-1), equals(0));
      expect(LoyaltyCalculator.calculatePoints(-10000), equals(0));
    });

    test('Single cent yields 0 points (floor division)', () {
      // Spec: 1 / 100 = 0.01 → floor() = 0
      expect(LoyaltyCalculator.calculatePoints(1), equals(0));
    });

    test('99 cents yields 0 points (below 1 point threshold)', () {
      // Spec: 99 / 100 = 0.99 → floor() = 0
      expect(LoyaltyCalculator.calculatePoints(99), equals(0));
    });

    test('Large purchase 100000 cents yields 1000 points', () {
      // Spec: 100000 / 100 = 1000.0 → floor() = 1000
      expect(LoyaltyCalculator.calculatePoints(100000), equals(1000));
    });

    test('Tier thresholds default to the config model values (B4-6)', () {
      // B4-6: silver/gold come from RestaurantConfigModel — the fallback path
      // uses the model's declared defaults (500 / 2000), never literals here.
      const config = RestaurantConfigModel();
      const bronze = LoyaltyModel(totalPoints: 499);
      expect(
        bronze.tierFor(
          silverThreshold: config.redemptionThresholdPoints,
          goldThreshold: config.goldThresholdPoints,
        ),
        equals('Bronze'),
      );

      const silver = LoyaltyModel(totalPoints: 500);
      expect(
        silver.tierFor(
          silverThreshold: config.redemptionThresholdPoints,
          goldThreshold: config.goldThresholdPoints,
        ),
        equals('Silver'),
      );

      const gold = LoyaltyModel(totalPoints: 2000);
      expect(
        gold.tierFor(
          silverThreshold: config.redemptionThresholdPoints,
          goldThreshold: config.goldThresholdPoints,
        ),
        equals('Gold'),
      );

      const highGold = LoyaltyModel(totalPoints: 9999);
      expect(
        highGold.tierFor(
          silverThreshold: config.redemptionThresholdPoints,
          goldThreshold: config.goldThresholdPoints,
        ),
        equals('Gold'),
      );
    });

    test(
      'gold threshold is an INDEPENDENT config value, not silver * 4 (B4-6)',
      () {
        const silver = LoyaltyModel(totalPoints: 600);
        expect(
          silver.tierFor(silverThreshold: 500, goldThreshold: 2500),
          equals('Silver'),
        );
        // 2400 >= 2500? No — still Silver. Independent gold config respected.
        const highSilver = LoyaltyModel(totalPoints: 2400);
        expect(
          highSilver.tierFor(silverThreshold: 500, goldThreshold: 2500),
          equals('Silver'),
        );
        const gold = LoyaltyModel(totalPoints: 2500);
        expect(
          gold.tierFor(silverThreshold: 500, goldThreshold: 2500),
          equals('Gold'),
        );
      },
    );
  });
}
