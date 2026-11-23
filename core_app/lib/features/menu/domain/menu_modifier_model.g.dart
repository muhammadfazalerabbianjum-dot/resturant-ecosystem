// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_modifier_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ModifierOptionImpl _$$ModifierOptionImplFromJson(Map<String, dynamic> json) =>
    _$ModifierOptionImpl(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      upchargeCents: (json['upchargeCents'] as num?)?.toInt() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$$ModifierOptionImplToJson(
  _$ModifierOptionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'upchargeCents': instance.upchargeCents,
  'isDefault': instance.isDefault,
};

_$MenuModifierImpl _$$MenuModifierImplFromJson(Map<String, dynamic> json) =>
    _$MenuModifierImpl(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isRequired: json['isRequired'] as bool? ?? false,
      allowMultiple: json['allowMultiple'] as bool? ?? false,
      options: json['options'] == null
          ? const []
          : const ModifierOptionsConverter().fromJson(json['options']),
    );

Map<String, dynamic> _$$MenuModifierImplToJson(_$MenuModifierImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isRequired': instance.isRequired,
      'allowMultiple': instance.allowMultiple,
      'options': const ModifierOptionsConverter().toJson(instance.options),
    };
