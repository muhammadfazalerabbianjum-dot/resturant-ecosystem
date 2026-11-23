// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BranchModelImpl _$$BranchModelImplFromJson(Map<String, dynamic> json) =>
    _$BranchModelImpl(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      deliveryRadiusMiles:
          (json['deliveryRadiusMiles'] as num?)?.toDouble() ?? 5.0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 50,
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$BranchModelImplToJson(_$BranchModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'deliveryRadiusMiles': instance.deliveryRadiusMiles,
      'capacity': instance.capacity,
      'isDefault': instance.isDefault,
      'isActive': instance.isActive,
    };
