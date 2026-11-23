// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      id: json['id'] as String,
      customerId: json['customerId'] as String? ?? '',
      status: json['status'] == null
          ? OrderStatus.pending
          : const OrderStatusConverter().fromJson(json['status']),
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      taxCents: (json['taxCents'] as num?)?.toInt() ?? 0,
      discountCents: (json['discountCents'] as num?)?.toInt() ?? 0,
      tipCents: (json['tipCents'] as num?)?.toInt() ?? 0,
      deliveryFeeCents: (json['deliveryFeeCents'] as num?)?.toInt() ?? 0,
      orderNumber: json['orderNumber'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      branchId: json['branchId'] as String?,
      assignedDriverId: json['assignedDriverId'] as String?,
      customerLat: (json['customerLat'] as num?)?.toDouble(),
      customerLng: (json['customerLng'] as num?)?.toDouble(),
      orderSource: const OrderSourceConverter().fromJson(json['orderSource']),
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerId': instance.customerId,
      'status': const OrderStatusConverter().toJson(instance.status),
      'totalCents': instance.totalCents,
      'taxCents': instance.taxCents,
      'discountCents': instance.discountCents,
      'tipCents': instance.tipCents,
      'deliveryFeeCents': instance.deliveryFeeCents,
      'orderNumber': instance.orderNumber,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'items': instance.items,
      'branchId': instance.branchId,
      'assignedDriverId': instance.assignedDriverId,
      'customerLat': instance.customerLat,
      'customerLng': instance.customerLng,
      'orderSource': const OrderSourceConverter().toJson(instance.orderSource),
    };
