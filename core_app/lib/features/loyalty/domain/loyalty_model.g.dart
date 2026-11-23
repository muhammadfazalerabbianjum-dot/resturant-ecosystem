// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loyalty_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LoyaltyModelImpl _$$LoyaltyModelImplFromJson(Map<String, dynamic> json) =>
    _$LoyaltyModelImpl(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      uid: json['uid'] as String? ?? '',
      redeemedRewardIds:
          (json['redeemedRewardIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$LoyaltyModelImplToJson(_$LoyaltyModelImpl instance) =>
    <String, dynamic>{
      'totalPoints': instance.totalPoints,
      'uid': instance.uid,
      'redeemedRewardIds': instance.redeemedRewardIds,
    };
