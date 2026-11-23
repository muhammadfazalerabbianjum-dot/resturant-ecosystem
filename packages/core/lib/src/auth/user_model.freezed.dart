// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  int get loyaltyPoints => throw _privateConstructorUsedError;
  String? get stripeCustomerId => throw _privateConstructorUsedError;
  String? get pushToken => throw _privateConstructorUsedError;
  String get tier => throw _privateConstructorUsedError;
  @UserRoleConverter()
  UserRole get role => throw _privateConstructorUsedError;
  String? get branchId => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  List<String> get assignedOrderIds => throw _privateConstructorUsedError;
  @DateTimeConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call({
    String id,
    String? email,
    String? name,
    String? displayName,
    String? username,
    String? phone,
    String? phoneNumber,
    int loyaltyPoints,
    String? stripeCustomerId,
    String? pushToken,
    String tier,
    @UserRoleConverter() UserRole role,
    String? branchId,
    bool isOnline,
    List<String> assignedOrderIds,
    @DateTimeConverter() DateTime? createdAt,
  });
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? name = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? phone = freezed,
    Object? phoneNumber = freezed,
    Object? loyaltyPoints = null,
    Object? stripeCustomerId = freezed,
    Object? pushToken = freezed,
    Object? tier = null,
    Object? role = null,
    Object? branchId = freezed,
    Object? isOnline = null,
    Object? assignedOrderIds = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            phoneNumber: freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            loyaltyPoints: null == loyaltyPoints
                ? _value.loyaltyPoints
                : loyaltyPoints // ignore: cast_nullable_to_non_nullable
                      as int,
            stripeCustomerId: freezed == stripeCustomerId
                ? _value.stripeCustomerId
                : stripeCustomerId // ignore: cast_nullable_to_non_nullable
                      as String?,
            pushToken: freezed == pushToken
                ? _value.pushToken
                : pushToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            isOnline: null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            assignedOrderIds: null == assignedOrderIds
                ? _value.assignedOrderIds
                : assignedOrderIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
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
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
    _$UserModelImpl value,
    $Res Function(_$UserModelImpl) then,
  ) = __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? email,
    String? name,
    String? displayName,
    String? username,
    String? phone,
    String? phoneNumber,
    int loyaltyPoints,
    String? stripeCustomerId,
    String? pushToken,
    String tier,
    @UserRoleConverter() UserRole role,
    String? branchId,
    bool isOnline,
    List<String> assignedOrderIds,
    @DateTimeConverter() DateTime? createdAt,
  });
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
    _$UserModelImpl _value,
    $Res Function(_$UserModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? name = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? phone = freezed,
    Object? phoneNumber = freezed,
    Object? loyaltyPoints = null,
    Object? stripeCustomerId = freezed,
    Object? pushToken = freezed,
    Object? tier = null,
    Object? role = null,
    Object? branchId = freezed,
    Object? isOnline = null,
    Object? assignedOrderIds = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$UserModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        phoneNumber: freezed == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        loyaltyPoints: null == loyaltyPoints
            ? _value.loyaltyPoints
            : loyaltyPoints // ignore: cast_nullable_to_non_nullable
                  as int,
        stripeCustomerId: freezed == stripeCustomerId
            ? _value.stripeCustomerId
            : stripeCustomerId // ignore: cast_nullable_to_non_nullable
                  as String?,
        pushToken: freezed == pushToken
            ? _value.pushToken
            : pushToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        isOnline: null == isOnline
            ? _value.isOnline
            : isOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        assignedOrderIds: null == assignedOrderIds
            ? _value._assignedOrderIds
            : assignedOrderIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
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
class _$UserModelImpl extends _UserModel {
  const _$UserModelImpl({
    required this.id,
    this.email,
    this.name,
    this.displayName,
    this.username,
    this.phone,
    this.phoneNumber,
    this.loyaltyPoints = 0,
    this.stripeCustomerId,
    this.pushToken,
    this.tier = 'starter',
    @UserRoleConverter() this.role = UserRole.customer,
    this.branchId,
    this.isOnline = false,
    final List<String> assignedOrderIds = const [],
    @DateTimeConverter() this.createdAt,
  }) : _assignedOrderIds = assignedOrderIds,
       super._();

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String? email;
  @override
  final String? name;
  @override
  final String? displayName;
  @override
  final String? username;
  @override
  final String? phone;
  @override
  final String? phoneNumber;
  @override
  @JsonKey()
  final int loyaltyPoints;
  @override
  final String? stripeCustomerId;
  @override
  final String? pushToken;
  @override
  @JsonKey()
  final String tier;
  @override
  @JsonKey()
  @UserRoleConverter()
  final UserRole role;
  @override
  final String? branchId;
  @override
  @JsonKey()
  final bool isOnline;
  final List<String> _assignedOrderIds;
  @override
  @JsonKey()
  List<String> get assignedOrderIds {
    if (_assignedOrderIds is EqualUnmodifiableListView)
      return _assignedOrderIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assignedOrderIds);
  }

  @override
  @DateTimeConverter()
  final DateTime? createdAt;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, displayName: $displayName, username: $username, phone: $phone, phoneNumber: $phoneNumber, loyaltyPoints: $loyaltyPoints, stripeCustomerId: $stripeCustomerId, pushToken: $pushToken, tier: $tier, role: $role, branchId: $branchId, isOnline: $isOnline, assignedOrderIds: $assignedOrderIds, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.loyaltyPoints, loyaltyPoints) ||
                other.loyaltyPoints == loyaltyPoints) &&
            (identical(other.stripeCustomerId, stripeCustomerId) ||
                other.stripeCustomerId == stripeCustomerId) &&
            (identical(other.pushToken, pushToken) ||
                other.pushToken == pushToken) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            const DeepCollectionEquality().equals(
              other._assignedOrderIds,
              _assignedOrderIds,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    name,
    displayName,
    username,
    phone,
    phoneNumber,
    loyaltyPoints,
    stripeCustomerId,
    pushToken,
    tier,
    role,
    branchId,
    isOnline,
    const DeepCollectionEquality().hash(_assignedOrderIds),
    createdAt,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(this);
  }
}

abstract class _UserModel extends UserModel {
  const factory _UserModel({
    required final String id,
    final String? email,
    final String? name,
    final String? displayName,
    final String? username,
    final String? phone,
    final String? phoneNumber,
    final int loyaltyPoints,
    final String? stripeCustomerId,
    final String? pushToken,
    final String tier,
    @UserRoleConverter() final UserRole role,
    final String? branchId,
    final bool isOnline,
    final List<String> assignedOrderIds,
    @DateTimeConverter() final DateTime? createdAt,
  }) = _$UserModelImpl;
  const _UserModel._() : super._();

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  String? get email;
  @override
  String? get name;
  @override
  String? get displayName;
  @override
  String? get username;
  @override
  String? get phone;
  @override
  String? get phoneNumber;
  @override
  int get loyaltyPoints;
  @override
  String? get stripeCustomerId;
  @override
  String? get pushToken;
  @override
  String get tier;
  @override
  @UserRoleConverter()
  UserRole get role;
  @override
  String? get branchId;
  @override
  bool get isOnline;
  @override
  List<String> get assignedOrderIds;
  @override
  @DateTimeConverter()
  DateTime? get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
