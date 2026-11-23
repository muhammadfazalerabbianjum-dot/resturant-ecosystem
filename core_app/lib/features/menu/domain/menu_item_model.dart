import 'package:freezed_annotation/freezed_annotation.dart';
import 'dietary_codes.dart';
import 'menu_modifier_model.dart';

part 'menu_item_model.freezed.dart';
part 'menu_item_model.g.dart';

@freezed
class MenuItemModel with _$MenuItemModel {
  const factory MenuItemModel({
    required String id,
    @Default('Unknown') String name,
    @Default('') String description,
    required int priceCents,
    String? imageUrl,
    @Default('General') String category,
    @Default([]) List<String> tags,
    @Default(true) bool isAvailable,
    int? quantityRemaining,
    @Default([]) List<MenuModifier> modifiers,

    // ── P6-1 (D-051/D-052): dietary declarations and the owner-only halal
    // claim. Codes only — see dietary_codes.dart for the fixed vocabulary.
    @Default([]) List<String> allergens,
    @Default([]) List<String> dietary,
    @Default('') String allergenNotes,
    @Default(false) bool halalCertified,
    @Default('') String halalCertBody,
    @CertExpiryConverter() DateTime? halalCertExpiresAt,
  }) = _MenuItemModel;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemModelFromJson(json);
}
