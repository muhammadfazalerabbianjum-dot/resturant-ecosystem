// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promotion_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PromotionModelImpl _$$PromotionModelImplFromJson(Map<String, dynamic> json) =>
    _$PromotionModelImpl(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      actionUrl: json['actionUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 99,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$PromotionModelImplToJson(
  _$PromotionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'imageUrl': instance.imageUrl,
  'title': instance.title,
  'subtitle': instance.subtitle,
  'actionUrl': instance.actionUrl,
  'isActive': instance.isActive,
  'priority': instance.priority,
  'createdAt': instance.createdAt?.toIso8601String(),
};
