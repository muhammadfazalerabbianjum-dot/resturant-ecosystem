import 'package:freezed_annotation/freezed_annotation.dart';

part 'loyalty_model.freezed.dart';
part 'loyalty_model.g.dart';

class LoyaltyCalculator {
  static const int centsPerPoint = 100;

  static int calculatePoints(int totalCentsSpent) {
    if (totalCentsSpent <= 0) return 0;
    // PERF-1 H-4: integer division `~/` is EXACT for all non-negative 64-bit
    // ints. `(x / 100).floor()` round-trips through double and loses cents
    // beyond ~2^53 (double precision limit). Negative inputs are guarded
    // above, where `~/` truncation would differ from floor anyway.
    return totalCentsSpent ~/ centsPerPoint;
  }

  /// Computes the loyalty tier from total points using CONFIG-DRIVEN
  /// thresholds. There are intentionally NO defaults here — the caller
  /// (screen / drawer) resolves both values from `settings/restaurantConfig`
  /// (see [RestaurantConfigModel.redemptionThresholdPoints] for the silver
  /// tier and [RestaurantConfigModel.goldThresholdPoints] for gold). This
  /// keeps the tier business rule free of hardcoded magic numbers (B4-6).
  static String currentTier(
    int totalPoints, {
    required int silverThreshold,
    required int goldThreshold,
  }) {
    if (totalPoints >= goldThreshold) return 'Gold';
    if (totalPoints >= silverThreshold) return 'Silver';
    return 'Bronze';
  }
}

@freezed
abstract class LoyaltyModel with _$LoyaltyModel {
  const LoyaltyModel._();

  const factory LoyaltyModel({
    @Default(0) int totalPoints,
    @Default('') String uid,
    @Default([]) List<String> redeemedRewardIds,
  }) = _LoyaltyModel;

  /// PERF-1 H-3: fail-closed at the parse boundary. The Cloud Functions
  /// delivered-hook only ever writes positive `totalPoints`, so a negative
  /// value in a loyalty document is FORGED data — it is clamped to 0 here
  /// (Bronze) instead of rendering "-50 points". Clamping at the single
  /// model factory protects every consumer (screen, drawer, dashboards).
  factory LoyaltyModel.fromJson(Map<String, dynamic> json) {
    final model = _$LoyaltyModelFromJson(json);
    return model.copyWith(
      totalPoints: model.totalPoints < 0 ? 0 : model.totalPoints,
    );
  }

  /// Tier derived from [totalPoints] using CONFIG-DRIVEN thresholds.
  ///
  /// WHY: tier logic stays a pure function of points + thresholds — no
  /// extra Firestore read, no hardcoded 500/2000 (B4-6). Callers pass the
  /// real values from `settings/restaurantConfig`.
  String tierFor({required int silverThreshold, required int goldThreshold}) =>
      LoyaltyCalculator.currentTier(
        totalPoints,
        silverThreshold: silverThreshold,
        goldThreshold: goldThreshold,
      );
}
