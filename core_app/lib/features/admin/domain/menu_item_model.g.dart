// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MenuItemModelImpl _$$MenuItemModelImplFromJson(
  Map<String, dynamic> json,
) => _$MenuItemModelImpl(
  id: json['id'] as String,
  branchId: json['branchId'] as String?,
  name: json['name'] as String? ?? '',
  priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
  description: json['description'] as String? ?? '',
  imageUrl: json['imageUrl'] as String? ?? '',
  category: json['category'] as String? ?? '',
  modifiers:
      (json['modifiers'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  isAvailable: json['isAvailable'] as bool? ?? true,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  quantityRemaining: (json['quantityRemaining'] as num?)?.toInt(),
  allergens:
      (json['allergens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  dietary:
      (json['dietary'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  allergenNotes: json['allergenNotes'] as String? ?? '',
  halalCertified: json['halalCertified'] as bool? ?? false,
  halalCertBody: json['halalCertBody'] as String? ?? '',
  halalCertExpiresAt: const CertExpiryConverter().fromJson(
    json['halalCertExpiresAt'],
  ),
);

Map<String, dynamic> _$$MenuItemModelImplToJson(_$MenuItemModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'branchId': instance.branchId,
      'name': instance.name,
      'priceCents': instance.priceCents,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'category': instance.category,
      'modifiers': instance.modifiers,
      'isAvailable': instance.isAvailable,
      'tags': instance.tags,
      'quantityRemaining': instance.quantityRemaining,
      'allergens': instance.allergens,
      'dietary': instance.dietary,
      'allergenNotes': instance.allergenNotes,
      'halalCertified': instance.halalCertified,
      'halalCertBody': instance.halalCertBody,
      'halalCertExpiresAt': const CertExpiryConverter().toJson(
        instance.halalCertExpiresAt,
      ),
    };
