// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_modifier_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ModifierOption _$ModifierOptionFromJson(Map<String, dynamic> json) {
  return _ModifierOption.fromJson(json);
}

/// @nodoc
mixin _$ModifierOption {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get upchargeCents => throw _privateConstructorUsedError;
  bool get isDefault => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ModifierOptionCopyWith<ModifierOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModifierOptionCopyWith<$Res> {
  factory $ModifierOptionCopyWith(
    ModifierOption value,
    $Res Function(ModifierOption) then,
  ) = _$ModifierOptionCopyWithImpl<$Res, ModifierOption>;
  @useResult
  $Res call({String id, String name, int upchargeCents, bool isDefault});
}

/// @nodoc
class _$ModifierOptionCopyWithImpl<$Res, $Val extends ModifierOption>
    implements $ModifierOptionCopyWith<$Res> {
  _$ModifierOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? upchargeCents = null,
    Object? isDefault = null,
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
            upchargeCents: null == upchargeCents
                ? _value.upchargeCents
                : upchargeCents // ignore: cast_nullable_to_non_nullable
                      as int,
            isDefault: null == isDefault
                ? _value.isDefault
                : isDefault // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModifierOptionImplCopyWith<$Res>
    implements $ModifierOptionCopyWith<$Res> {
  factory _$$ModifierOptionImplCopyWith(
    _$ModifierOptionImpl value,
    $Res Function(_$ModifierOptionImpl) then,
  ) = __$$ModifierOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, int upchargeCents, bool isDefault});
}

/// @nodoc
class __$$ModifierOptionImplCopyWithImpl<$Res>
    extends _$ModifierOptionCopyWithImpl<$Res, _$ModifierOptionImpl>
    implements _$$ModifierOptionImplCopyWith<$Res> {
  __$$ModifierOptionImplCopyWithImpl(
    _$ModifierOptionImpl _value,
    $Res Function(_$ModifierOptionImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? upchargeCents = null,
    Object? isDefault = null,
  }) {
    return _then(
      _$ModifierOptionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        upchargeCents: null == upchargeCents
            ? _value.upchargeCents
            : upchargeCents // ignore: cast_nullable_to_non_nullable
                  as int,
        isDefault: null == isDefault
            ? _value.isDefault
            : isDefault // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModifierOptionImpl implements _ModifierOption {
  const _$ModifierOptionImpl({
    this.id = '',
    this.name = '',
    this.upchargeCents = 0,
    this.isDefault = false,
  });

  factory _$ModifierOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModifierOptionImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final int upchargeCents;
  @override
  @JsonKey()
  final bool isDefault;

  @override
  String toString() {
    return 'ModifierOption(id: $id, name: $name, upchargeCents: $upchargeCents, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModifierOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.upchargeCents, upchargeCents) ||
                other.upchargeCents == upchargeCents) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, upchargeCents, isDefault);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ModifierOptionImplCopyWith<_$ModifierOptionImpl> get copyWith =>
      __$$ModifierOptionImplCopyWithImpl<_$ModifierOptionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ModifierOptionImplToJson(this);
  }
}

abstract class _ModifierOption implements ModifierOption {
  const factory _ModifierOption({
    final String id,
    final String name,
    final int upchargeCents,
    final bool isDefault,
  }) = _$ModifierOptionImpl;

  factory _ModifierOption.fromJson(Map<String, dynamic> json) =
      _$ModifierOptionImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  int get upchargeCents;
  @override
  bool get isDefault;
  @override
  @JsonKey(ignore: true)
  _$$ModifierOptionImplCopyWith<_$ModifierOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MenuModifier _$MenuModifierFromJson(Map<String, dynamic> json) {
  return _MenuModifier.fromJson(json);
}

/// @nodoc
mixin _$MenuModifier {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  bool get isRequired => throw _privateConstructorUsedError;
  bool get allowMultiple => throw _privateConstructorUsedError;
  @ModifierOptionsConverter()
  List<ModifierOption> get options => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MenuModifierCopyWith<MenuModifier> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MenuModifierCopyWith<$Res> {
  factory $MenuModifierCopyWith(
    MenuModifier value,
    $Res Function(MenuModifier) then,
  ) = _$MenuModifierCopyWithImpl<$Res, MenuModifier>;
  @useResult
  $Res call({
    String id,
    String name,
    bool isRequired,
    bool allowMultiple,
    @ModifierOptionsConverter() List<ModifierOption> options,
  });
}

/// @nodoc
class _$MenuModifierCopyWithImpl<$Res, $Val extends MenuModifier>
    implements $MenuModifierCopyWith<$Res> {
  _$MenuModifierCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isRequired = null,
    Object? allowMultiple = null,
    Object? options = null,
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
            isRequired: null == isRequired
                ? _value.isRequired
                : isRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowMultiple: null == allowMultiple
                ? _value.allowMultiple
                : allowMultiple // ignore: cast_nullable_to_non_nullable
                      as bool,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as List<ModifierOption>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MenuModifierImplCopyWith<$Res>
    implements $MenuModifierCopyWith<$Res> {
  factory _$$MenuModifierImplCopyWith(
    _$MenuModifierImpl value,
    $Res Function(_$MenuModifierImpl) then,
  ) = __$$MenuModifierImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    bool isRequired,
    bool allowMultiple,
    @ModifierOptionsConverter() List<ModifierOption> options,
  });
}

/// @nodoc
class __$$MenuModifierImplCopyWithImpl<$Res>
    extends _$MenuModifierCopyWithImpl<$Res, _$MenuModifierImpl>
    implements _$$MenuModifierImplCopyWith<$Res> {
  __$$MenuModifierImplCopyWithImpl(
    _$MenuModifierImpl _value,
    $Res Function(_$MenuModifierImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isRequired = null,
    Object? allowMultiple = null,
    Object? options = null,
  }) {
    return _then(
      _$MenuModifierImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        isRequired: null == isRequired
            ? _value.isRequired
            : isRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowMultiple: null == allowMultiple
            ? _value.allowMultiple
            : allowMultiple // ignore: cast_nullable_to_non_nullable
                  as bool,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as List<ModifierOption>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MenuModifierImpl implements _MenuModifier {
  const _$MenuModifierImpl({
    this.id = '',
    this.name = '',
    this.isRequired = false,
    this.allowMultiple = false,
    @ModifierOptionsConverter() final List<ModifierOption> options = const [],
  }) : _options = options;

  factory _$MenuModifierImpl.fromJson(Map<String, dynamic> json) =>
      _$$MenuModifierImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final bool isRequired;
  @override
  @JsonKey()
  final bool allowMultiple;
  final List<ModifierOption> _options;
  @override
  @JsonKey()
  @ModifierOptionsConverter()
  List<ModifierOption> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'MenuModifier(id: $id, name: $name, isRequired: $isRequired, allowMultiple: $allowMultiple, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MenuModifierImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.isRequired, isRequired) ||
                other.isRequired == isRequired) &&
            (identical(other.allowMultiple, allowMultiple) ||
                other.allowMultiple == allowMultiple) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    isRequired,
    allowMultiple,
    const DeepCollectionEquality().hash(_options),
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MenuModifierImplCopyWith<_$MenuModifierImpl> get copyWith =>
      __$$MenuModifierImplCopyWithImpl<_$MenuModifierImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MenuModifierImplToJson(this);
  }
}

abstract class _MenuModifier implements MenuModifier {
  const factory _MenuModifier({
    final String id,
    final String name,
    final bool isRequired,
    final bool allowMultiple,
    @ModifierOptionsConverter() final List<ModifierOption> options,
  }) = _$MenuModifierImpl;

  factory _MenuModifier.fromJson(Map<String, dynamic> json) =
      _$MenuModifierImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  bool get isRequired;
  @override
  bool get allowMultiple;
  @override
  @ModifierOptionsConverter()
  List<ModifierOption> get options;
  @override
  @JsonKey(ignore: true)
  _$$MenuModifierImplCopyWith<_$MenuModifierImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
