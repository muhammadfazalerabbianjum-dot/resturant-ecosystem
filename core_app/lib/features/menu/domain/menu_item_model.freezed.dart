// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MenuItemModel _$MenuItemModelFromJson(Map<String, dynamic> json) {
  return _MenuItemModel.fromJson(json);
}

/// @nodoc
mixin _$MenuItemModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get priceCents => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;
  int? get quantityRemaining => throw _privateConstructorUsedError;
  List<MenuModifier> get modifiers =>
      throw _privateConstructorUsedError; // ── P6-1 (D-051/D-052): dietary declarations and the owner-only halal
  // claim. Codes only — see dietary_codes.dart for the fixed vocabulary.
  List<String> get allergens => throw _privateConstructorUsedError;
  List<String> get dietary => throw _privateConstructorUsedError;
  String get allergenNotes => throw _privateConstructorUsedError;
  bool get halalCertified => throw _privateConstructorUsedError;
  String get halalCertBody => throw _privateConstructorUsedError;
  @CertExpiryConverter()
  DateTime? get halalCertExpiresAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MenuItemModelCopyWith<MenuItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MenuItemModelCopyWith<$Res> {
  factory $MenuItemModelCopyWith(
    MenuItemModel value,
    $Res Function(MenuItemModel) then,
  ) = _$MenuItemModelCopyWithImpl<$Res, MenuItemModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    int priceCents,
    String? imageUrl,
    String category,
    List<String> tags,
    bool isAvailable,
    int? quantityRemaining,
    List<MenuModifier> modifiers,
    List<String> allergens,
    List<String> dietary,
    String allergenNotes,
    bool halalCertified,
    String halalCertBody,
    @CertExpiryConverter() DateTime? halalCertExpiresAt,
  });
}

/// @nodoc
class _$MenuItemModelCopyWithImpl<$Res, $Val extends MenuItemModel>
    implements $MenuItemModelCopyWith<$Res> {
  _$MenuItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? priceCents = null,
    Object? imageUrl = freezed,
    Object? category = null,
    Object? tags = null,
    Object? isAvailable = null,
    Object? quantityRemaining = freezed,
    Object? modifiers = null,
    Object? allergens = null,
    Object? dietary = null,
    Object? allergenNotes = null,
    Object? halalCertified = null,
    Object? halalCertBody = null,
    Object? halalCertExpiresAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            priceCents: null == priceCents
                ? _value.priceCents
                : priceCents // ignore: cast_nullable_to_non_nullable
                      as int,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isAvailable: null == isAvailable
                ? _value.isAvailable
                : isAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            quantityRemaining: freezed == quantityRemaining
                ? _value.quantityRemaining
                : quantityRemaining // ignore: cast_nullable_to_non_nullable
                      as int?,
            modifiers: null == modifiers
                ? _value.modifiers
                : modifiers // ignore: cast_nullable_to_non_nullable
                      as List<MenuModifier>,
            allergens: null == allergens
                ? _value.allergens
                : allergens // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            dietary: null == dietary
                ? _value.dietary
                : dietary // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            allergenNotes: null == allergenNotes
                ? _value.allergenNotes
                : allergenNotes // ignore: cast_nullable_to_non_nullable
                      as String,
            halalCertified: null == halalCertified
                ? _value.halalCertified
                : halalCertified // ignore: cast_nullable_to_non_nullable
                      as bool,
            halalCertBody: null == halalCertBody
                ? _value.halalCertBody
                : halalCertBody // ignore: cast_nullable_to_non_nullable
                      as String,
            halalCertExpiresAt: freezed == halalCertExpiresAt
                ? _value.halalCertExpiresAt
                : halalCertExpiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MenuItemModelImplCopyWith<$Res>
    implements $MenuItemModelCopyWith<$Res> {
  factory _$$MenuItemModelImplCopyWith(
    _$MenuItemModelImpl value,
    $Res Function(_$MenuItemModelImpl) then,
  ) = __$$MenuItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    int priceCents,
    String? imageUrl,
    String category,
    List<String> tags,
    bool isAvailable,
    int? quantityRemaining,
    List<MenuModifier> modifiers,
    List<String> allergens,
    List<String> dietary,
    String allergenNotes,
    bool halalCertified,
    String halalCertBody,
    @CertExpiryConverter() DateTime? halalCertExpiresAt,
  });
}

/// @nodoc
class __$$MenuItemModelImplCopyWithImpl<$Res>
    extends _$MenuItemModelCopyWithImpl<$Res, _$MenuItemModelImpl>
    implements _$$MenuItemModelImplCopyWith<$Res> {
  __$$MenuItemModelImplCopyWithImpl(
    _$MenuItemModelImpl _value,
    $Res Function(_$MenuItemModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? priceCents = null,
    Object? imageUrl = freezed,
    Object? category = null,
    Object? tags = null,
    Object? isAvailable = null,
    Object? quantityRemaining = freezed,
    Object? modifiers = null,
    Object? allergens = null,
    Object? dietary = null,
    Object? allergenNotes = null,
    Object? halalCertified = null,
    Object? halalCertBody = null,
    Object? halalCertExpiresAt = freezed,
  }) {
    return _then(
      _$MenuItemModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        priceCents: null == priceCents
            ? _value.priceCents
            : priceCents // ignore: cast_nullable_to_non_nullable
                  as int,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isAvailable: null == isAvailable
            ? _value.isAvailable
            : isAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        quantityRemaining: freezed == quantityRemaining
            ? _value.quantityRemaining
            : quantityRemaining // ignore: cast_nullable_to_non_nullable
                  as int?,
        modifiers: null == modifiers
            ? _value._modifiers
            : modifiers // ignore: cast_nullable_to_non_nullable
                  as List<MenuModifier>,
        allergens: null == allergens
            ? _value._allergens
            : allergens // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        dietary: null == dietary
            ? _value._dietary
            : dietary // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        allergenNotes: null == allergenNotes
            ? _value.allergenNotes
            : allergenNotes // ignore: cast_nullable_to_non_nullable
                  as String,
        halalCertified: null == halalCertified
            ? _value.halalCertified
            : halalCertified // ignore: cast_nullable_to_non_nullable
                  as bool,
        halalCertBody: null == halalCertBody
            ? _value.halalCertBody
            : halalCertBody // ignore: cast_nullable_to_non_nullable
                  as String,
        halalCertExpiresAt: freezed == halalCertExpiresAt
            ? _value.halalCertExpiresAt
            : halalCertExpiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MenuItemModelImpl implements _MenuItemModel {
  const _$MenuItemModelImpl({
    required this.id,
    this.name = 'Unknown',
    this.description = '',
    required this.priceCents,
    this.imageUrl,
    this.category = 'General',
    final List<String> tags = const [],
    this.isAvailable = true,
    this.quantityRemaining,
    final List<MenuModifier> modifiers = const [],
    final List<String> allergens = const [],
    final List<String> dietary = const [],
    this.allergenNotes = '',
    this.halalCertified = false,
    this.halalCertBody = '',
    @CertExpiryConverter() this.halalCertExpiresAt,
  }) : _tags = tags,
       _modifiers = modifiers,
       _allergens = allergens,
       _dietary = dietary;

  factory _$MenuItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MenuItemModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String description;
  @override
  final int priceCents;
  @override
  final String? imageUrl;
  @override
  @JsonKey()
  final String category;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final bool isAvailable;
  @override
  final int? quantityRemaining;
  final List<MenuModifier> _modifiers;
  @override
  @JsonKey()
  List<MenuModifier> get modifiers {
    if (_modifiers is EqualUnmodifiableListView) return _modifiers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_modifiers);
  }

  // ── P6-1 (D-051/D-052): dietary declarations and the owner-only halal
  // claim. Codes only — see dietary_codes.dart for the fixed vocabulary.
  final List<String> _allergens;
  // ── P6-1 (D-051/D-052): dietary declarations and the owner-only halal
  // claim. Codes only — see dietary_codes.dart for the fixed vocabulary.
  @override
  @JsonKey()
  List<String> get allergens {
    if (_allergens is EqualUnmodifiableListView) return _allergens;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergens);
  }

  final List<String> _dietary;
  @override
  @JsonKey()
  List<String> get dietary {
    if (_dietary is EqualUnmodifiableListView) return _dietary;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dietary);
  }

  @override
  @JsonKey()
  final String allergenNotes;
  @override
  @JsonKey()
  final bool halalCertified;
  @override
  @JsonKey()
  final String halalCertBody;
  @override
  @CertExpiryConverter()
  final DateTime? halalCertExpiresAt;

  @override
  String toString() {
    return 'MenuItemModel(id: $id, name: $name, description: $description, priceCents: $priceCents, imageUrl: $imageUrl, category: $category, tags: $tags, isAvailable: $isAvailable, quantityRemaining: $quantityRemaining, modifiers: $modifiers, allergens: $allergens, dietary: $dietary, allergenNotes: $allergenNotes, halalCertified: $halalCertified, halalCertBody: $halalCertBody, halalCertExpiresAt: $halalCertExpiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MenuItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.priceCents, priceCents) ||
                other.priceCents == priceCents) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.quantityRemaining, quantityRemaining) ||
                other.quantityRemaining == quantityRemaining) &&
            const DeepCollectionEquality().equals(
              other._modifiers,
              _modifiers,
            ) &&
            const DeepCollectionEquality().equals(
              other._allergens,
              _allergens,
            ) &&
            const DeepCollectionEquality().equals(other._dietary, _dietary) &&
            (identical(other.allergenNotes, allergenNotes) ||
                other.allergenNotes == allergenNotes) &&
            (identical(other.halalCertified, halalCertified) ||
                other.halalCertified == halalCertified) &&
            (identical(other.halalCertBody, halalCertBody) ||
                other.halalCertBody == halalCertBody) &&
            (identical(other.halalCertExpiresAt, halalCertExpiresAt) ||
                other.halalCertExpiresAt == halalCertExpiresAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    description,
    priceCents,
    imageUrl,
    category,
    const DeepCollectionEquality().hash(_tags),
    isAvailable,
    quantityRemaining,
    const DeepCollectionEquality().hash(_modifiers),
    const DeepCollectionEquality().hash(_allergens),
    const DeepCollectionEquality().hash(_dietary),
    allergenNotes,
    halalCertified,
    halalCertBody,
    halalCertExpiresAt,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MenuItemModelImplCopyWith<_$MenuItemModelImpl> get copyWith =>
      __$$MenuItemModelImplCopyWithImpl<_$MenuItemModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MenuItemModelImplToJson(this);
  }
}

abstract class _MenuItemModel implements MenuItemModel {
  const factory _MenuItemModel({
    required final String id,
    final String name,
    final String description,
    required final int priceCents,
    final String? imageUrl,
    final String category,
    final List<String> tags,
    final bool isAvailable,
    final int? quantityRemaining,
    final List<MenuModifier> modifiers,
    final List<String> allergens,
    final List<String> dietary,
    final String allergenNotes,
    final bool halalCertified,
    final String halalCertBody,
    @CertExpiryConverter() final DateTime? halalCertExpiresAt,
  }) = _$MenuItemModelImpl;

  factory _MenuItemModel.fromJson(Map<String, dynamic> json) =
      _$MenuItemModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  int get priceCents;
  @override
  String? get imageUrl;
  @override
  String get category;
  @override
  List<String> get tags;
  @override
  bool get isAvailable;
  @override
  int? get quantityRemaining;
  @override
  List<MenuModifier> get modifiers;
  @override // ── P6-1 (D-051/D-052): dietary declarations and the owner-only halal
  // claim. Codes only — see dietary_codes.dart for the fixed vocabulary.
  List<String> get allergens;
  @override
  List<String> get dietary;
  @override
  String get allergenNotes;
  @override
  bool get halalCertified;
  @override
  String get halalCertBody;
  @override
  @CertExpiryConverter()
  DateTime? get halalCertExpiresAt;
  @override
  @JsonKey(ignore: true)
  _$$MenuItemModelImplCopyWith<_$MenuItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
