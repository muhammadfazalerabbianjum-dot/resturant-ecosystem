import 'dart:developer' as developer;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_modifier_model.freezed.dart';
part 'menu_modifier_model.g.dart';

const String _kMalformedModifierOption =
    'MenuModifier: skipped malformed modifier option';

/// Defensive [JsonConverter] for a `List<ModifierOption>`.
///
/// B2-6: a malformed entry (null, non-map, or a map whose typed fields cannot
/// be decoded) must NEVER crash menu loading — it is skipped and logged so the
/// bad data is visible in telemetry instead of taking the whole dish down.
///
/// Using a dedicated `JsonConverter` class (annotated directly on the field,
/// the same pattern as `user_model.dart`'s `DateTimeConverter`) lets
/// json_serializable honour the custom (de)serialization WITHOUT a freezed
/// annotation-target suppression on the constructor parameter.
class ModifierOptionsConverter
    extends JsonConverter<List<ModifierOption>, Object?> {
  const ModifierOptionsConverter();

  @override
  List<ModifierOption> fromJson(Object? json) {
    if (json is! List) return const [];
    final options = <ModifierOption>[];
    for (final item in json) {
      final Map<String, dynamic>? map = item is Map<String, dynamic>
          ? item
          : item is Map
          ? Map<String, dynamic>.from(item)
          : null;
      if (map == null) {
        developer.log('$_kMalformedModifierOption: $item');
        continue;
      }
      try {
        options.add(ModifierOption.fromJson(map));
      } catch (e, st) {
        developer.log(
          '$_kMalformedModifierOption: $map',
          error: e,
          stackTrace: st,
        );
      }
    }
    return options;
  }

  @override
  Object? toJson(List<ModifierOption> object) =>
      object.map((e) => e.toJson()).toList();
}

@freezed
abstract class ModifierOption with _$ModifierOption {
  const factory ModifierOption({
    @Default('') String id,
    @Default('') String name,
    @Default(0) int upchargeCents,
    @Default(false) bool isDefault,
  }) = _ModifierOption;

  factory ModifierOption.fromJson(Map<String, dynamic> json) =>
      _$ModifierOptionFromJson(json);
}

@freezed
abstract class MenuModifier with _$MenuModifier {
  const factory MenuModifier({
    @Default('') String id,
    @Default('') String name,
    @Default(false) bool isRequired,
    @Default(false) bool allowMultiple,
    @Default([]) @ModifierOptionsConverter() List<ModifierOption> options,
  }) = _MenuModifier;

  factory MenuModifier.fromJson(Map<String, dynamic> json) =>
      _$MenuModifierFromJson(json);
}
