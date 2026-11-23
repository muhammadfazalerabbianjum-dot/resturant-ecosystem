// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reservation_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReservationModel _$ReservationModelFromJson(Map<String, dynamic> json) {
  return _ReservationModel.fromJson(json);
}

/// @nodoc
mixin _$ReservationModel {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;
  String get customerName => throw _privateConstructorUsedError;
  String get customerPhone => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  int get partySize => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReservationModelCopyWith<ReservationModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReservationModelCopyWith<$Res> {
  factory $ReservationModelCopyWith(
    ReservationModel value,
    $Res Function(ReservationModel) then,
  ) = _$ReservationModelCopyWithImpl<$Res, ReservationModel>;
  @useResult
  $Res call({
    String id,
    String userId,
    String branchId,
    String customerName,
    String customerPhone,
    DateTime startTime,
    int partySize,
    String? notes,
  });
}

/// @nodoc
class _$ReservationModelCopyWithImpl<$Res, $Val extends ReservationModel>
    implements $ReservationModelCopyWith<$Res> {
  _$ReservationModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? branchId = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? startTime = null,
    Object? partySize = null,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            branchId: null == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String,
            customerName: null == customerName
                ? _value.customerName
                : customerName // ignore: cast_nullable_to_non_nullable
                      as String,
            customerPhone: null == customerPhone
                ? _value.customerPhone
                : customerPhone // ignore: cast_nullable_to_non_nullable
                      as String,
            startTime: null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            partySize: null == partySize
                ? _value.partySize
                : partySize // ignore: cast_nullable_to_non_nullable
                      as int,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReservationModelImplCopyWith<$Res>
    implements $ReservationModelCopyWith<$Res> {
  factory _$$ReservationModelImplCopyWith(
    _$ReservationModelImpl value,
    $Res Function(_$ReservationModelImpl) then,
  ) = __$$ReservationModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String branchId,
    String customerName,
    String customerPhone,
    DateTime startTime,
    int partySize,
    String? notes,
  });
}

/// @nodoc
class __$$ReservationModelImplCopyWithImpl<$Res>
    extends _$ReservationModelCopyWithImpl<$Res, _$ReservationModelImpl>
    implements _$$ReservationModelImplCopyWith<$Res> {
  __$$ReservationModelImplCopyWithImpl(
    _$ReservationModelImpl _value,
    $Res Function(_$ReservationModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? branchId = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? startTime = null,
    Object? partySize = null,
    Object? notes = freezed,
  }) {
    return _then(
      _$ReservationModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        branchId: null == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String,
        customerName: null == customerName
            ? _value.customerName
            : customerName // ignore: cast_nullable_to_non_nullable
                  as String,
        customerPhone: null == customerPhone
            ? _value.customerPhone
            : customerPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        startTime: null == startTime
            ? _value.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        partySize: null == partySize
            ? _value.partySize
            : partySize // ignore: cast_nullable_to_non_nullable
                  as int,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReservationModelImpl extends _ReservationModel {
  const _$ReservationModelImpl({
    required this.id,
    this.userId = '',
    this.branchId = '',
    this.customerName = 'Guest',
    this.customerPhone = '—',
    required this.startTime,
    this.partySize = 1,
    this.notes,
  }) : super._();

  factory _$ReservationModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReservationModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String userId;
  @override
  @JsonKey()
  final String branchId;
  @override
  @JsonKey()
  final String customerName;
  @override
  @JsonKey()
  final String customerPhone;
  @override
  final DateTime startTime;
  @override
  @JsonKey()
  final int partySize;
  @override
  final String? notes;

  @override
  String toString() {
    return 'ReservationModel(id: $id, userId: $userId, branchId: $branchId, customerName: $customerName, customerPhone: $customerPhone, startTime: $startTime, partySize: $partySize, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReservationModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.customerName, customerName) ||
                other.customerName == customerName) &&
            (identical(other.customerPhone, customerPhone) ||
                other.customerPhone == customerPhone) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.partySize, partySize) ||
                other.partySize == partySize) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    branchId,
    customerName,
    customerPhone,
    startTime,
    partySize,
    notes,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReservationModelImplCopyWith<_$ReservationModelImpl> get copyWith =>
      __$$ReservationModelImplCopyWithImpl<_$ReservationModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ReservationModelImplToJson(this);
  }
}

abstract class _ReservationModel extends ReservationModel {
  const factory _ReservationModel({
    required final String id,
    final String userId,
    final String branchId,
    final String customerName,
    final String customerPhone,
    required final DateTime startTime,
    final int partySize,
    final String? notes,
  }) = _$ReservationModelImpl;
  const _ReservationModel._() : super._();

  factory _ReservationModel.fromJson(Map<String, dynamic> json) =
      _$ReservationModelImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get branchId;
  @override
  String get customerName;
  @override
  String get customerPhone;
  @override
  DateTime get startTime;
  @override
  int get partySize;
  @override
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$ReservationModelImplCopyWith<_$ReservationModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
