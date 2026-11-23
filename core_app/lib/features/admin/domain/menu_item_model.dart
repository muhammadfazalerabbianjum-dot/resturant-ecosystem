import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../menu/domain/dietary_codes.dart';

part 'menu_item_model.freezed.dart';
part 'menu_item_model.g.dart';

@freezed
abstract class MenuItemModel with _$MenuItemModel {
  const MenuItemModel._();

  const factory MenuItemModel({
    required String id,
    String? branchId, // null = global item visible to all branches
    @Default('') String name,
    @Default(0) int priceCents,
    @Default('') String description,
    @Default('') String imageUrl,
    @Default('') String category,
    @Default([]) List<Map<String, dynamic>> modifiers,
    @Default(true) bool isAvailable,
    @Default([]) List<String> tags,
    int? quantityRemaining,

    // ── P6-1 (D-051/D-052): one vocabulary, defined once in
    // `menu/domain/dietary_codes.dart`. The claim fields are owner-only in
    // `firestore.rules`.
    @Default([]) List<String> allergens,
    @Default([]) List<String> dietary,
    @Default('') String allergenNotes,
    @Default(false) bool halalCertified,
    @Default('') String halalCertBody,
    @CertExpiryConverter() DateTime? halalCertExpiresAt,
  }) = _MenuItemModel;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemModelFromJson(json);

  factory MenuItemModel.fromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<dynamic, dynamic>);
    data['id'] = doc.id;
    return MenuItemModel.fromJson(data);
  }

  bool get isGlobal => branchId == null;

  /// WHY: Applies a branch-level override on top of a global item.
  /// Branch-specific name/price/image take precedence; falls back to global.
  MenuItemModel mergeWith(MenuItemModel override) => copyWith(
    id: override.id,
    branchId: override.branchId,
    name: override.name,
    priceCents: override.priceCents,
    description: override.description,
    imageUrl: override.imageUrl.isNotEmpty ? override.imageUrl : imageUrl,
    category: override.category.isNotEmpty ? override.category : category,
    modifiers: override.modifiers.isNotEmpty ? override.modifiers : modifiers,
    isAvailable: override.isAvailable,
    tags: override.tags.isNotEmpty ? override.tags : tags,
    quantityRemaining: override.quantityRemaining ?? quantityRemaining,
    // Facts follow the `tags` rule: a non-empty branch override wins, an empty
    // one inherits the global declaration.
    allergens: override.allergens.isNotEmpty ? override.allergens : allergens,
    dietary: override.dietary.isNotEmpty ? override.dietary : dietary,
    allergenNotes: override.allergenNotes.isNotEmpty
        ? override.allergenNotes
        : allergenNotes,
    // The CERTIFICATION CLAIM is deliberately NOT inherited. A branch that
    // overrides an item has its own kitchen; showing the global claim there
    // would assert a certification about premises nobody certified. Fail
    // closed: the badge comes from the override or it does not render.
    halalCertified: override.halalCertified,
    halalCertBody: override.halalCertBody,
    halalCertExpiresAt: override.halalCertExpiresAt,
  );
}
