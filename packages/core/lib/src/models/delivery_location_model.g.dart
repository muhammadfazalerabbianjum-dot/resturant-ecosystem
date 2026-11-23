// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeliveryLocationModelImpl _$$DeliveryLocationModelImplFromJson(
  Map<String, dynamic> json,
) => _$DeliveryLocationModelImpl(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  address: json['address'] as String? ?? '',
);

Map<String, dynamic> _$$DeliveryLocationModelImplToJson(
  _$DeliveryLocationModelImpl instance,
) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'address': instance.address,
};
