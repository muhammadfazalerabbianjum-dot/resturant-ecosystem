// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MenuItemModelImpl _$$MenuItemModelImplFromJson(
  Map<String, dynamic> json,
) => _$MenuItemModelImpl(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'Unknown',
  description: json['description'] as String? ?? '',
  priceCents: (json['priceCents'] as num).toInt(),
  imageUrl: json['imageUrl'] as String?,
  category: json['category'] as String? ?? 'General',
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  isAvailable: json['isAvailable'] as bool? ?? true,
  quantityRemaining: (json['quantityRemaining'] as num?)?.toInt(),
  modifiers:
      (json['modifiers'] as List<dynamic>?)
          ?.map((e) => MenuModifier.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
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
      'name': instance.name,
      'description': instance.description,
      'priceCents': instance.priceCents,
      'imageUrl': instance.imageUrl,
      'category': instance.category,
      'tags': instance.tags,
      'isAvailable': instance.isAvailable,
      'quantityRemaining': instance.quantityRemaining,
      'modifiers': instance.modifiers,
      'allergens': instance.allergens,
      'dietary': instance.dietary,
      'allergenNotes': instance.allergenNotes,
      'halalCertified': instance.halalCertified,
      'halalCertBody': instance.halalCertBody,
      'halalCertExpiresAt': const CertExpiryConverter().toJson(
        instance.halalCertExpiresAt,
      ),
    };
