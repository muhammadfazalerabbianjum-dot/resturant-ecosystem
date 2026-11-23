// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
      stripeCustomerId: json['stripeCustomerId'] as String?,
      pushToken: json['pushToken'] as String?,
      tier: json['tier'] as String? ?? 'starter',
      role: json['role'] == null
          ? UserRole.customer
          : const UserRoleConverter().fromJson(json['role']),
      branchId: json['branchId'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      assignedOrderIds:
          (json['assignedOrderIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: const DateTimeConverter().fromJson(json['createdAt']),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'name': instance.name,
      'displayName': instance.displayName,
      'username': instance.username,
      'phone': instance.phone,
      'phoneNumber': instance.phoneNumber,
      'loyaltyPoints': instance.loyaltyPoints,
      'stripeCustomerId': instance.stripeCustomerId,
      'pushToken': instance.pushToken,
      'tier': instance.tier,
      'role': const UserRoleConverter().toJson(instance.role),
      'branchId': instance.branchId,
      'isOnline': instance.isOnline,
      'assignedOrderIds': instance.assignedOrderIds,
      'createdAt': const DateTimeConverter().toJson(instance.createdAt),
    };
