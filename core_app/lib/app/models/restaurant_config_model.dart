import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant_config_model.freezed.dart';

/// Firestore serialisation for [RestaurantConfigModel].
/// Kept as an extension so freezed can generate the Impl class cleanly.
extension RestaurantConfigModelX on RestaurantConfigModel {
  Map<String, dynamic> toFirestore() => {
    'restaurantName': restaurantName,
    'tagline': tagline,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'address': address,
    'currency': currency,
    'defaultLanguage': defaultLanguage,
    'logoUrl': logoUrl,
    'heroImageUrl': heroImageUrl,
    'primaryColorHex': primaryColorHex,
    'secondaryColorHex': secondaryColorHex,
    'appStoreName': appStoreName,
    'appDescription': appDescription,
    'termsUrl': termsUrl,
    'privacyUrl': privacyUrl,
    'socialLinks': socialLinks,
    'loyaltyProgramName': loyaltyProgramName,
    'pointsPerDollar': pointsPerDollar,
    'redemptionThresholdPoints': redemptionThresholdPoints,
    'goldThresholdPoints': goldThresholdPoints,
    'redemptionValueCents': redemptionValueCents,
    'signupBonusPoints': signupBonusPoints,
    'notificationTone': notificationTone,
    'notificationOptIn': notificationOptIn,
    'minimumOrderCents': minimumOrderCents,
    'tipEnabled': tipEnabled,
    'serviceChargePercent': serviceChargePercent,
    'estimatedPrepTimeMinutes': estimatedPrepTimeMinutes,
    'deliveryFeeType': deliveryFeeType,
    'deliveryFeeCents': deliveryFeeCents,
    'freeDeliveryThresholdCents': freeDeliveryThresholdCents,
    'operatingHours': operatingHours,
  };
}

/// Firestore path: settings/restaurantConfig
/// Stores all identity + operational data collected during client onboarding.
@freezed
abstract class RestaurantConfigModel with _$RestaurantConfigModel {
  const factory RestaurantConfigModel({
    @Default('') String restaurantName,
    @Default('') String tagline,
    @Default('') String contactEmail,
    @Default('') String contactPhone,
    @Default('') String address,
    @Default('USD') String currency,
    @Default('en') String defaultLanguage,
    String? logoUrl,
    String? heroImageUrl,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? appStoreName,
    String? appDescription,
    String? termsUrl,
    String? privacyUrl,
    @Default({}) Map<String, String> socialLinks,
    @Default('Rewards') String loyaltyProgramName,
    @Default(10) int pointsPerDollar,
    @Default(500) int redemptionThresholdPoints,
    @Default(2000) int goldThresholdPoints,
    @Default(500) int redemptionValueCents,
    @Default(0) int signupBonusPoints,
    @Default('casual') String notificationTone,
    @Default('after_first_order') String notificationOptIn,
    @Default(0) int minimumOrderCents,
    @Default(true) bool tipEnabled,
    @Default(0) int serviceChargePercent,
    @Default(20) int estimatedPrepTimeMinutes,
    @Default('flat') String deliveryFeeType,
    @Default(299) int deliveryFeeCents,
    @Default(3000) int freeDeliveryThresholdCents,
    @Default({}) Map<String, dynamic> operatingHours,
  }) = _RestaurantConfigModel;

  factory RestaurantConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RestaurantConfigModel(
      restaurantName: data['restaurantName'] as String? ?? '',
      tagline: data['tagline'] as String? ?? '',
      contactEmail: data['contactEmail'] as String? ?? '',
      contactPhone: data['contactPhone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      currency: data['currency'] as String? ?? 'USD',
      defaultLanguage: data['defaultLanguage'] as String? ?? 'en',
      logoUrl: data['logoUrl'] as String?,
      heroImageUrl: data['heroImageUrl'] as String?,
      primaryColorHex: data['primaryColorHex'] as String?,
      secondaryColorHex: data['secondaryColorHex'] as String?,
      appStoreName: data['appStoreName'] as String?,
      appDescription: data['appDescription'] as String?,
      termsUrl: data['termsUrl'] as String?,
      privacyUrl: data['privacyUrl'] as String?,
      socialLinks: Map<String, String>.from(data['socialLinks'] as Map? ?? {}),
      loyaltyProgramName: data['loyaltyProgramName'] as String? ?? 'Rewards',
      pointsPerDollar: data['pointsPerDollar'] as int? ?? 10,
      redemptionThresholdPoints:
          data['redemptionThresholdPoints'] as int? ?? 500,
      redemptionValueCents: data['redemptionValueCents'] as int? ?? 500,
      signupBonusPoints: data['signupBonusPoints'] as int? ?? 0,
      notificationTone: data['notificationTone'] as String? ?? 'casual',
      notificationOptIn:
          data['notificationOptIn'] as String? ?? 'after_first_order',
      minimumOrderCents: data['minimumOrderCents'] as int? ?? 0,
      tipEnabled: data['tipEnabled'] as bool? ?? true,
      serviceChargePercent: data['serviceChargePercent'] as int? ?? 0,
      estimatedPrepTimeMinutes: data['estimatedPrepTimeMinutes'] as int? ?? 20,
      deliveryFeeType: data['deliveryFeeType'] as String? ?? 'flat',
      deliveryFeeCents: data['deliveryFeeCents'] as int? ?? 299,
      freeDeliveryThresholdCents:
          data['freeDeliveryThresholdCents'] as int? ?? 3000,
      operatingHours: Map<String, dynamic>.from(
        data['operatingHours'] as Map? ?? {},
      ),
    );
  }
}
