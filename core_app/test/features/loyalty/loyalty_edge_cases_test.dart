import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';

/// COV-4 — loyalty EDGE-CASE points math, tier transitions and the
/// referral injection guard. Extends (never duplicates) the existing
/// loyalty_calculator_test.dart + wiring suite: here the boundaries are
/// pushed to platform int limits, the forged/negative document payloads,
/// and NON-default config thresholds.

void main() {
  group('LoyaltyCalculator — extreme-magnitude edge cases (COV-4)', () {
    test('INT32_MAX cents converts exactly (2147483647 → 21474836 points)', () {
      // 21474836.47 → floor = 21474836. Exact: well inside double precision.
      expect(LoyaltyCalculator.calculatePoints(2147483647), 21474836);
    });

    test('a 2^53-safe order magnitude converts exactly (no double drift)', () {
      // An exact multiple of 100 below 2^53 (double exactness limit) —
      // floor() stays lossless at this magnitude.
      expect(
        LoyaltyCalculator.calculatePoints(9007199254740900),
        90071992547409,
      );
    });

    test('PERF-1 T-5 (H-4): 2^53 cents converts exactly', () {
      // 9007199254740992 = 2^53, the double exactness limit. True integer
      // quotient: 90071992547409 r 92. `~/` is exact; no double round-trip.
      expect(
        LoyaltyCalculator.calculatePoints(9007199254740992),
        90071992547409,
      );
    });

    test('PERF-1 T-5 (H-4): 2^53 + 100 cents converts exactly', () {
      // 9007199254741092 = 2^53 + 100 (representable: even, within the
      // spacing-2 range). True integer quotient: 90071992547410 r 92.
      expect(
        LoyaltyCalculator.calculatePoints(9007199254741092),
        90071992547410,
      );
    });

    test('PERF-1 T-5 (H-4) discriminator: 2^53 + 7 cents stays integer-exact '
        'where the old double division drifted', () {
      // 9007199254740999 = 2^53 + 7, which is 99 mod 100. As a double it
      // rounds UP to 2^53 + 8 (ties-to-even), so the old
      // `(x / 100).floor()` computed floor(90071992547410.0) =
      // 90071992547410 — one point MORE than the true quotient
      // 90071992547409 r 99. `~/` is exact for every non-negative int;
      // this input is RED under the old code and GREEN under H-4.
      expect(
        LoyaltyCalculator.calculatePoints(9007199254740999),
        90071992547409,
      );
    });

    test('a one-cent negative attack yields 0 (clamped, not negative)', () {
      expect(LoyaltyCalculator.calculatePoints(-1), 0);
    });

    test('a large refund-style negative attack yields 0 (clamped)', () {
      expect(LoyaltyCalculator.calculatePoints(-2147483647), 0);
    });
  });

  group('LoyaltyModel.fromJson — document payload edge cases (COV-4)', () {
    test(
      'a missing totalPoints falls back to 0 (Bronze at default config)',
      () {
        final model = LoyaltyModel.fromJson({'uid': 'u9'});
        expect(model.totalPoints, 0);
        const config = RestaurantConfigModel();
        expect(
          model.tierFor(
            silverThreshold: config.redemptionThresholdPoints,
            goldThreshold: config.goldThresholdPoints,
          ),
          'Bronze',
        );
      },
    );

    test('a FORGED negative totalPoints document FAILS CLOSED to 0/Bronze '
        '(PERF-1 H-3: clamped at the model parse; the server CF writes '
        'positive only)', () {
      final model = LoyaltyModel.fromJson({'uid': 'u-atk', 'totalPoints': -50});
      expect(
        model.totalPoints,
        0,
        reason:
            'H-3: forged negatives are clamped at fromJson — they can '
            'never be rendered as "-50 points" nor reach tier math',
      );
      const config = RestaurantConfigModel();
      expect(
        model.tierFor(
          silverThreshold: config.redemptionThresholdPoints,
          goldThreshold: config.goldThresholdPoints,
        ),
        'Bronze',
        reason: 'negative points must never resolve to Silver/Gold',
      );
    });

    test('a LEGITIMATE positive totalPoints passes the clamp untouched', () {
      // The H-3 clamp must never dent real data: the CF delivered-hook only
      // writes positive totals, so positive values round-trip unchanged.
      final model = LoyaltyModel.fromJson({'uid': 'u-ok', 'totalPoints': 2100});
      expect(model.totalPoints, 2100);
    });

    test('redeemedRewardIds round-trips from the document payload', () {
      final model = LoyaltyModel.fromJson({
        'uid': 'u4',
        'totalPoints': 2100,
        'redeemedRewardIds': ['free_coffee', 'free_dessert'],
      });
      expect(model.redeemedRewardIds, ['free_coffee', 'free_dessert']);
    });
  });

  group('tier transitions with NON-default config thresholds (COV-4)', () {
    // Complements the existing default-threshold ladder: proves the
    // transition boundaries follow WHATEVER config is passed, not 500/2000.
    const silver = 300;
    const gold = 900;

    test('the full Bronze→Silver→Gold ladder honors the custom config', () {
      expect(
        const LoyaltyModel(
          totalPoints: 299,
        ).tierFor(silverThreshold: silver, goldThreshold: gold),
        'Bronze',
      );
      expect(
        const LoyaltyModel(
          totalPoints: 300,
        ).tierFor(silverThreshold: silver, goldThreshold: gold),
        'Silver',
      );
      // One below each boundary stays down; the boundary itself moves up.
      expect(
        const LoyaltyModel(
          totalPoints: 899,
        ).tierFor(silverThreshold: silver, goldThreshold: gold),
        'Silver',
      );
      expect(
        const LoyaltyModel(
          totalPoints: 900,
        ).tierFor(silverThreshold: silver, goldThreshold: gold),
        'Gold',
      );
      expect(
        const LoyaltyModel(
          totalPoints: 901,
        ).tierFor(silverThreshold: silver, goldThreshold: gold),
        'Gold',
      );
    });

    test('EQUAL thresholds resolve deterministically to Gold (gold wins)', () {
      expect(
        LoyaltyCalculator.currentTier(
          1000,
          silverThreshold: 1000,
          goldThreshold: 1000,
        ),
        'Gold',
        reason: 'gold is checked first — deterministic, never ambiguous',
      );
    });

    test('an INVERTED config (silver > gold) still resolves Gold first '
        '(documented gold-precedence determinism)', () {
      expect(
        LoyaltyCalculator.currentTier(
          150,
          silverThreshold: 3000,
          goldThreshold: 100,
        ),
        'Gold',
      );
    });

    test(
      'currentTier and LoyaltyModel.tierFor agree across a sample sweep',
      () {
        const config = RestaurantConfigModel();
        for (final points in const [0, 299, 500, 1999, 2000, 5000]) {
          final viaModel = LoyaltyModel(totalPoints: points).tierFor(
            silverThreshold: config.redemptionThresholdPoints,
            goldThreshold: config.goldThresholdPoints,
          );
          expect(
            LoyaltyCalculator.currentTier(
              points,
              silverThreshold: config.redemptionThresholdPoints,
              goldThreshold: config.goldThresholdPoints,
            ),
            viaModel,
            reason:
                'screen path (currentTier) and model path (tierFor) '
                'must never diverge at $points points',
          );
        }
      },
    );
  });

  // P9 W1 (T-5): the ReferralEngine group was deleted with the dead
  // `referral_engine.dart` itself (zero production importers — tests of dead
  // code are test-theater). The live loyalty math above is unchanged.
}
