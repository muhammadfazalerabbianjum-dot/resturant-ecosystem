// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BranchModel _$BranchModelFromJson(Map<String, dynamic> json) {
  return _BranchModel.fromJson(json);
}

/// @nodoc
mixin _$BranchModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get address =>
      throw _privateConstructorUsedError; // WHY: GeoPoint stored as lat/lng doubles — GeoPoint is not JSON serializable
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  double get deliveryRadiusMiles => throw _privateConstructorUsedError;
  int get capacity =>
      throw _privateConstructorUsedError; // Added for reservation table capacity
  bool get isDefault => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BranchModelCopyWith<BranchModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BranchModelCopyWith<$Res> {
  factory $BranchModelCopyWith(
    BranchModel value,
    $Res Function(BranchModel) then,
  ) = _$BranchModelCopyWithImpl<$Res, BranchModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String address,
    double latitude,
    double longitude,
    double deliveryRadiusMiles,
    int capacity,
    bool isDefault,
    bool isActive,
  });
}

/// @nodoc
class _$BranchModelCopyWithImpl<$Res, $Val extends BranchModel>
    implements $BranchModelCopyWith<$Res> {
  _$BranchModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? deliveryRadiusMiles = null,
    Object? capacity = null,
    Object? isDefault = null,
    Object? isActive = null,
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
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            deliveryRadiusMiles: null == deliveryRadiusMiles
                ? _value.deliveryRadiusMiles
                : deliveryRadiusMiles // ignore: cast_nullable_to_non_nullable
                      as double,
            capacity: null == capacity
                ? _value.capacity
                : capacity // ignore: cast_nullable_to_non_nullable
                      as int,
            isDefault: null == isDefault
                ? _value.isDefault
                : isDefault // ignore: cast_nullable_to_non_nullable
                      as bool,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BranchModelImplCopyWith<$Res>
    implements $BranchModelCopyWith<$Res> {
  factory _$$BranchModelImplCopyWith(
    _$BranchModelImpl value,
    $Res Function(_$BranchModelImpl) then,
  ) = __$$BranchModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String address,
    double latitude,
    double longitude,
    double deliveryRadiusMiles,
    int capacity,
    bool isDefault,
    bool isActive,
  });
}

/// @nodoc
class __$$BranchModelImplCopyWithImpl<$Res>
    extends _$BranchModelCopyWithImpl<$Res, _$BranchModelImpl>
    implements _$$BranchModelImplCopyWith<$Res> {
  __$$BranchModelImplCopyWithImpl(
    _$BranchModelImpl _value,
    $Res Function(_$BranchModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? deliveryRadiusMiles = null,
    Object? capacity = null,
    Object? isDefault = null,
    Object? isActive = null,
  }) {
    return _then(
      _$BranchModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        deliveryRadiusMiles: null == deliveryRadiusMiles
            ? _value.deliveryRadiusMiles
            : deliveryRadiusMiles // ignore: cast_nullable_to_non_nullable
                  as double,
        capacity: null == capacity
            ? _value.capacity
            : capacity // ignore: cast_nullable_to_non_nullable
                  as int,
        isDefault: null == isDefault
            ? _value.isDefault
            : isDefault // ignore: cast_nullable_to_non_nullable
                  as bool,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BranchModelImpl extends _BranchModel {
  const _$BranchModelImpl({
    required this.id,
    this.name = '',
    this.address = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.deliveryRadiusMiles = 5.0,
    this.capacity = 50,
    this.isDefault = false,
    this.isActive = true,
  }) : super._();

  factory _$BranchModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BranchModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String address;
  // WHY: GeoPoint stored as lat/lng doubles — GeoPoint is not JSON serializable
  @override
  @JsonKey()
  final double latitude;
  @override
  @JsonKey()
  final double longitude;
  @override
  @JsonKey()
  final double deliveryRadiusMiles;
  @override
  @JsonKey()
  final int capacity;
  // Added for reservation table capacity
  @override
  @JsonKey()
  final bool isDefault;
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'BranchModel(id: $id, name: $name, address: $address, latitude: $latitude, longitude: $longitude, deliveryRadiusMiles: $deliveryRadiusMiles, capacity: $capacity, isDefault: $isDefault, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BranchModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.deliveryRadiusMiles, deliveryRadiusMiles) ||
                other.deliveryRadiusMiles == deliveryRadiusMiles) &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    address,
    latitude,
    longitude,
    deliveryRadiusMiles,
    capacity,
    isDefault,
    isActive,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BranchModelImplCopyWith<_$BranchModelImpl> get copyWith =>
      __$$BranchModelImplCopyWithImpl<_$BranchModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BranchModelImplToJson(this);
  }
}

abstract class _BranchModel extends BranchModel {
  const factory _BranchModel({
    required final String id,
    final String name,
    final String address,
    final double latitude,
    final double longitude,
    final double deliveryRadiusMiles,
    final int capacity,
    final bool isDefault,
    final bool isActive,
  }) = _$BranchModelImpl;
  const _BranchModel._() : super._();

  factory _BranchModel.fromJson(Map<String, dynamic> json) =
      _$BranchModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get address;
  @override // WHY: GeoPoint stored as lat/lng doubles — GeoPoint is not JSON serializable
  double get latitude;
  @override
  double get longitude;
  @override
  double get deliveryRadiusMiles;
  @override
  int get capacity;
  @override // Added for reservation table capacity
  bool get isDefault;
  @override
  bool get isActive;
  @override
  @JsonKey(ignore: true)
  _$$BranchModelImplCopyWith<_$BranchModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
