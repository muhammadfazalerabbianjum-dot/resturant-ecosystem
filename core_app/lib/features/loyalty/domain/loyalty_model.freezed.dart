// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'loyalty_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LoyaltyModel _$LoyaltyModelFromJson(Map<String, dynamic> json) {
  return _LoyaltyModel.fromJson(json);
}

/// @nodoc
mixin _$LoyaltyModel {
  int get totalPoints => throw _privateConstructorUsedError;
  String get uid => throw _privateConstructorUsedError;
  List<String> get redeemedRewardIds => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LoyaltyModelCopyWith<LoyaltyModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LoyaltyModelCopyWith<$Res> {
  factory $LoyaltyModelCopyWith(
    LoyaltyModel value,
    $Res Function(LoyaltyModel) then,
  ) = _$LoyaltyModelCopyWithImpl<$Res, LoyaltyModel>;
  @useResult
  $Res call({int totalPoints, String uid, List<String> redeemedRewardIds});
}

/// @nodoc
class _$LoyaltyModelCopyWithImpl<$Res, $Val extends LoyaltyModel>
    implements $LoyaltyModelCopyWith<$Res> {
  _$LoyaltyModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalPoints = null,
    Object? uid = null,
    Object? redeemedRewardIds = null,
  }) {
    return _then(
      _value.copyWith(
            totalPoints: null == totalPoints
                ? _value.totalPoints
                : totalPoints // ignore: cast_nullable_to_non_nullable
                      as int,
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            redeemedRewardIds: null == redeemedRewardIds
                ? _value.redeemedRewardIds
                : redeemedRewardIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LoyaltyModelImplCopyWith<$Res>
    implements $LoyaltyModelCopyWith<$Res> {
  factory _$$LoyaltyModelImplCopyWith(
    _$LoyaltyModelImpl value,
    $Res Function(_$LoyaltyModelImpl) then,
  ) = __$$LoyaltyModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int totalPoints, String uid, List<String> redeemedRewardIds});
}

/// @nodoc
class __$$LoyaltyModelImplCopyWithImpl<$Res>
    extends _$LoyaltyModelCopyWithImpl<$Res, _$LoyaltyModelImpl>
    implements _$$LoyaltyModelImplCopyWith<$Res> {
  __$$LoyaltyModelImplCopyWithImpl(
    _$LoyaltyModelImpl _value,
    $Res Function(_$LoyaltyModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalPoints = null,
    Object? uid = null,
    Object? redeemedRewardIds = null,
  }) {
    return _then(
      _$LoyaltyModelImpl(
        totalPoints: null == totalPoints
            ? _value.totalPoints
            : totalPoints // ignore: cast_nullable_to_non_nullable
                  as int,
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        redeemedRewardIds: null == redeemedRewardIds
            ? _value._redeemedRewardIds
            : redeemedRewardIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LoyaltyModelImpl extends _LoyaltyModel {
  const _$LoyaltyModelImpl({
    this.totalPoints = 0,
    this.uid = '',
    final List<String> redeemedRewardIds = const [],
  }) : _redeemedRewardIds = redeemedRewardIds,
       super._();

  factory _$LoyaltyModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$LoyaltyModelImplFromJson(json);

  @override
  @JsonKey()
  final int totalPoints;
  @override
  @JsonKey()
  final String uid;
  final List<String> _redeemedRewardIds;
  @override
  @JsonKey()
  List<String> get redeemedRewardIds {
    if (_redeemedRewardIds is EqualUnmodifiableListView)
      return _redeemedRewardIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_redeemedRewardIds);
  }

  @override
  String toString() {
    return 'LoyaltyModel(totalPoints: $totalPoints, uid: $uid, redeemedRewardIds: $redeemedRewardIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoyaltyModelImpl &&
            (identical(other.totalPoints, totalPoints) ||
                other.totalPoints == totalPoints) &&
            (identical(other.uid, uid) || other.uid == uid) &&
            const DeepCollectionEquality().equals(
              other._redeemedRewardIds,
              _redeemedRewardIds,
            ));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalPoints,
    uid,
    const DeepCollectionEquality().hash(_redeemedRewardIds),
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LoyaltyModelImplCopyWith<_$LoyaltyModelImpl> get copyWith =>
      __$$LoyaltyModelImplCopyWithImpl<_$LoyaltyModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LoyaltyModelImplToJson(this);
  }
}

abstract class _LoyaltyModel extends LoyaltyModel {
  const factory _LoyaltyModel({
    final int totalPoints,
    final String uid,
    final List<String> redeemedRewardIds,
  }) = _$LoyaltyModelImpl;
  const _LoyaltyModel._() : super._();

  factory _LoyaltyModel.fromJson(Map<String, dynamic> json) =
      _$LoyaltyModelImpl.fromJson;

  @override
  int get totalPoints;
  @override
  String get uid;
  @override
  List<String> get redeemedRewardIds;
  @override
  @JsonKey(ignore: true)
  _$$LoyaltyModelImplCopyWith<_$LoyaltyModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
