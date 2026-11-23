// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'presence_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PresenceModel _$PresenceModelFromJson(Map<String, dynamic> json) {
  return _PresenceModel.fromJson(json);
}

/// @nodoc
mixin _$PresenceModel {
  String get userId => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  DateTime? get lastSeen => throw _privateConstructorUsedError;
  String get branchId =>
      throw _privateConstructorUsedError; // B3 P2: `@UserRoleConverter()` (imported from user_model.dart) gives a
  // graceful customer fallback for unknown/missing role strings — no
  // annotation-target suppression needed.
  @UserRoleConverter()
  UserRole get role => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PresenceModelCopyWith<PresenceModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PresenceModelCopyWith<$Res> {
  factory $PresenceModelCopyWith(
    PresenceModel value,
    $Res Function(PresenceModel) then,
  ) = _$PresenceModelCopyWithImpl<$Res, PresenceModel>;
  @useResult
  $Res call({
    String userId,
    bool isOnline,
    DateTime? lastSeen,
    String branchId,
    @UserRoleConverter() UserRole role,
  });
}

/// @nodoc
class _$PresenceModelCopyWithImpl<$Res, $Val extends PresenceModel>
    implements $PresenceModelCopyWith<$Res> {
  _$PresenceModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? branchId = null,
    Object? role = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            isOnline: null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastSeen: freezed == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            branchId: null == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PresenceModelImplCopyWith<$Res>
    implements $PresenceModelCopyWith<$Res> {
  factory _$$PresenceModelImplCopyWith(
    _$PresenceModelImpl value,
    $Res Function(_$PresenceModelImpl) then,
  ) = __$$PresenceModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    bool isOnline,
    DateTime? lastSeen,
    String branchId,
    @UserRoleConverter() UserRole role,
  });
}

/// @nodoc
class __$$PresenceModelImplCopyWithImpl<$Res>
    extends _$PresenceModelCopyWithImpl<$Res, _$PresenceModelImpl>
    implements _$$PresenceModelImplCopyWith<$Res> {
  __$$PresenceModelImplCopyWithImpl(
    _$PresenceModelImpl _value,
    $Res Function(_$PresenceModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? branchId = null,
    Object? role = null,
  }) {
    return _then(
      _$PresenceModelImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        isOnline: null == isOnline
            ? _value.isOnline
            : isOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastSeen: freezed == lastSeen
            ? _value.lastSeen
            : lastSeen // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        branchId: null == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PresenceModelImpl implements _PresenceModel {
  const _$PresenceModelImpl({
    required this.userId,
    this.isOnline = false,
    this.lastSeen,
    this.branchId = '',
    @UserRoleConverter() this.role = UserRole.customer,
  });

  factory _$PresenceModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PresenceModelImplFromJson(json);

  @override
  final String userId;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final DateTime? lastSeen;
  @override
  @JsonKey()
  final String branchId;
  // B3 P2: `@UserRoleConverter()` (imported from user_model.dart) gives a
  // graceful customer fallback for unknown/missing role strings — no
  // annotation-target suppression needed.
  @override
  @JsonKey()
  @UserRoleConverter()
  final UserRole role;

  @override
  String toString() {
    return 'PresenceModel(userId: $userId, isOnline: $isOnline, lastSeen: $lastSeen, branchId: $branchId, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PresenceModelImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.role, role) || other.role == role));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, isOnline, lastSeen, branchId, role);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PresenceModelImplCopyWith<_$PresenceModelImpl> get copyWith =>
      __$$PresenceModelImplCopyWithImpl<_$PresenceModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PresenceModelImplToJson(this);
  }
}

abstract class _PresenceModel implements PresenceModel {
  const factory _PresenceModel({
    required final String userId,
    final bool isOnline,
    final DateTime? lastSeen,
    final String branchId,
    @UserRoleConverter() final UserRole role,
  }) = _$PresenceModelImpl;

  factory _PresenceModel.fromJson(Map<String, dynamic> json) =
      _$PresenceModelImpl.fromJson;

  @override
  String get userId;
  @override
  bool get isOnline;
  @override
  DateTime? get lastSeen;
  @override
  String get branchId;
  @override // B3 P2: `@UserRoleConverter()` (imported from user_model.dart) gives a
  // graceful customer fallback for unknown/missing role strings — no
  // annotation-target suppression needed.
  @UserRoleConverter()
  UserRole get role;
  @override
  @JsonKey(ignore: true)
  _$$PresenceModelImplCopyWith<_$PresenceModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
