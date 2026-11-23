import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';

void main() {
  group('Loyalty & Rewards Engine Wiring - F1', () {
    test(
      'LoyaltyModel tier is config-driven (B4-6): default thresholds 500/2000',
      () {
        const fallback = RestaurantConfigModel();
        const bronze = LoyaltyModel(totalPoints: 100);
        expect(
          bronze.tierFor(
            silverThreshold: fallback.redemptionThresholdPoints,
            goldThreshold: fallback.goldThresholdPoints,
          ),
          'Bronze',
        );

        const upperBronze = LoyaltyModel(totalPoints: 499);
        expect(
          upperBronze.tierFor(
            silverThreshold: fallback.redemptionThresholdPoints,
            goldThreshold: fallback.goldThresholdPoints,
          ),
          'Bronze',
        );

        const silver = LoyaltyModel(totalPoints: 500);
        expect(
          silver.tierFor(
            silverThreshold: fallback.redemptionThresholdPoints,
            goldThreshold: fallback.goldThresholdPoints,
          ),
          'Silver',
        );

        const upperSilver = LoyaltyModel(totalPoints: 1999);
        expect(
          upperSilver.tierFor(
            silverThreshold: fallback.redemptionThresholdPoints,
            goldThreshold: fallback.goldThresholdPoints,
          ),
          'Silver',
        );

        const gold = LoyaltyModel(totalPoints: 2000);
        expect(
          gold.tierFor(
            silverThreshold: fallback.redemptionThresholdPoints,
            goldThreshold: fallback.goldThresholdPoints,
          ),
          'Gold',
        );
      },
    );

    test('LoyaltyModel tier honors INDEPENDENT config thresholds (B4-6)', () {
      // B4-6: gold is an independent config field — never `silver * 4`.
      const silver = LoyaltyModel(totalPoints: 600);
      expect(
        silver.tierFor(silverThreshold: 500, goldThreshold: 2500),
        'Silver',
      );
      const gold = LoyaltyModel(totalPoints: 2500);
      expect(gold.tierFor(silverThreshold: 500, goldThreshold: 2500), 'Gold');
    });

    test('Points calculation maps \$1 (100 cents) to 1 point', () {
      expect(LoyaltyCalculator.calculatePoints(100), 1);
      expect(LoyaltyCalculator.calculatePoints(450), 4);
      expect(LoyaltyCalculator.calculatePoints(99), 0);
    });

    test('Negative and zero spend yields 0 points', () {
      expect(LoyaltyCalculator.calculatePoints(0), 0);
      expect(LoyaltyCalculator.calculatePoints(-100), 0);
    });
  });
}
