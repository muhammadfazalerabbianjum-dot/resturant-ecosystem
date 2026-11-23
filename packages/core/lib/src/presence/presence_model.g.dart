// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PresenceModelImpl _$$PresenceModelImplFromJson(Map<String, dynamic> json) =>
    _$PresenceModelImpl(
      userId: json['userId'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      branchId: json['branchId'] as String? ?? '',
      role: json['role'] == null
          ? UserRole.customer
          : const UserRoleConverter().fromJson(json['role']),
    );

Map<String, dynamic> _$$PresenceModelImplToJson(_$PresenceModelImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'branchId': instance.branchId,
      'role': const UserRoleConverter().toJson(instance.role),
    };
