// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'promotion_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PromotionModel _$PromotionModelFromJson(Map<String, dynamic> json) {
  return _PromotionModel.fromJson(json);
}

/// @nodoc
mixin _$PromotionModel {
  String get id => throw _privateConstructorUsedError;
  String get imageUrl => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get subtitle => throw _privateConstructorUsedError;
  String? get actionUrl => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PromotionModelCopyWith<PromotionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromotionModelCopyWith<$Res> {
  factory $PromotionModelCopyWith(
    PromotionModel value,
    $Res Function(PromotionModel) then,
  ) = _$PromotionModelCopyWithImpl<$Res, PromotionModel>;
  @useResult
  $Res call({
    String id,
    String imageUrl,
    String? title,
    String? subtitle,
    String? actionUrl,
    bool isActive,
    int priority,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$PromotionModelCopyWithImpl<$Res, $Val extends PromotionModel>
    implements $PromotionModelCopyWith<$Res> {
  _$PromotionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? title = freezed,
    Object? subtitle = freezed,
    Object? actionUrl = freezed,
    Object? isActive = null,
    Object? priority = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: null == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            subtitle: freezed == subtitle
                ? _value.subtitle
                : subtitle // ignore: cast_nullable_to_non_nullable
                      as String?,
            actionUrl: freezed == actionUrl
                ? _value.actionUrl
                : actionUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromotionModelImplCopyWith<$Res>
    implements $PromotionModelCopyWith<$Res> {
  factory _$$PromotionModelImplCopyWith(
    _$PromotionModelImpl value,
    $Res Function(_$PromotionModelImpl) then,
  ) = __$$PromotionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String imageUrl,
    String? title,
    String? subtitle,
    String? actionUrl,
    bool isActive,
    int priority,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$PromotionModelImplCopyWithImpl<$Res>
    extends _$PromotionModelCopyWithImpl<$Res, _$PromotionModelImpl>
    implements _$$PromotionModelImplCopyWith<$Res> {
  __$$PromotionModelImplCopyWithImpl(
    _$PromotionModelImpl _value,
    $Res Function(_$PromotionModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? title = freezed,
    Object? subtitle = freezed,
    Object? actionUrl = freezed,
    Object? isActive = null,
    Object? priority = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$PromotionModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: null == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        subtitle: freezed == subtitle
            ? _value.subtitle
            : subtitle // ignore: cast_nullable_to_non_nullable
                  as String?,
        actionUrl: freezed == actionUrl
            ? _value.actionUrl
            : actionUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PromotionModelImpl extends _PromotionModel {
  const _$PromotionModelImpl({
    required this.id,
    this.imageUrl = '',
    this.title,
    this.subtitle,
    this.actionUrl,
    this.isActive = true,
    this.priority = 99,
    this.createdAt,
  }) : super._();

  factory _$PromotionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PromotionModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String imageUrl;
  @override
  final String? title;
  @override
  final String? subtitle;
  @override
  final String? actionUrl;
  @override
  @JsonKey()
  final bool isActive;
  @override
  @JsonKey()
  final int priority;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'PromotionModel(id: $id, imageUrl: $imageUrl, title: $title, subtitle: $subtitle, actionUrl: $actionUrl, isActive: $isActive, priority: $priority, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromotionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.actionUrl, actionUrl) ||
                other.actionUrl == actionUrl) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    imageUrl,
    title,
    subtitle,
    actionUrl,
    isActive,
    priority,
    createdAt,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PromotionModelImplCopyWith<_$PromotionModelImpl> get copyWith =>
      __$$PromotionModelImplCopyWithImpl<_$PromotionModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PromotionModelImplToJson(this);
  }
}

abstract class _PromotionModel extends PromotionModel {
  const factory _PromotionModel({
    required final String id,
    final String imageUrl,
    final String? title,
    final String? subtitle,
    final String? actionUrl,
    final bool isActive,
    final int priority,
    final DateTime? createdAt,
  }) = _$PromotionModelImpl;
  const _PromotionModel._() : super._();

  factory _PromotionModel.fromJson(Map<String, dynamic> json) =
      _$PromotionModelImpl.fromJson;

  @override
  String get id;
  @override
  String get imageUrl;
  @override
  String? get title;
  @override
  String? get subtitle;
  @override
  String? get actionUrl;
  @override
  bool get isActive;
  @override
  int get priority;
  @override
  DateTime? get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$PromotionModelImplCopyWith<_$PromotionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
