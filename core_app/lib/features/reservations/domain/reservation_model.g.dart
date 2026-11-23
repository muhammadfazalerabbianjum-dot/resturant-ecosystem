// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReservationModelImpl _$$ReservationModelImplFromJson(
  Map<String, dynamic> json,
) => _$ReservationModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String? ?? '',
  branchId: json['branchId'] as String? ?? '',
  customerName: json['customerName'] as String? ?? 'Guest',
  customerPhone: json['customerPhone'] as String? ?? '—',
  startTime: DateTime.parse(json['startTime'] as String),
  partySize: (json['partySize'] as num?)?.toInt() ?? 1,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$$ReservationModelImplToJson(
  _$ReservationModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'branchId': instance.branchId,
  'customerName': instance.customerName,
  'customerPhone': instance.customerPhone,
  'startTime': instance.startTime.toIso8601String(),
  'partySize': instance.partySize,
  'notes': instance.notes,
};
