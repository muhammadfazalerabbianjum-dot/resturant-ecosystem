// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_location_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DeliveryLocationModel _$DeliveryLocationModelFromJson(
  Map<String, dynamic> json,
) {
  return _DeliveryLocationModel.fromJson(json);
}

/// @nodoc
mixin _$DeliveryLocationModel {
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $DeliveryLocationModelCopyWith<DeliveryLocationModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeliveryLocationModelCopyWith<$Res> {
  factory $DeliveryLocationModelCopyWith(
    DeliveryLocationModel value,
    $Res Function(DeliveryLocationModel) then,
  ) = _$DeliveryLocationModelCopyWithImpl<$Res, DeliveryLocationModel>;
  @useResult
  $Res call({double latitude, double longitude, String address});
}

/// @nodoc
class _$DeliveryLocationModelCopyWithImpl<
  $Res,
  $Val extends DeliveryLocationModel
>
    implements $DeliveryLocationModelCopyWith<$Res> {
  _$DeliveryLocationModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
  }) {
    return _then(
      _value.copyWith(
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeliveryLocationModelImplCopyWith<$Res>
    implements $DeliveryLocationModelCopyWith<$Res> {
  factory _$$DeliveryLocationModelImplCopyWith(
    _$DeliveryLocationModelImpl value,
    $Res Function(_$DeliveryLocationModelImpl) then,
  ) = __$$DeliveryLocationModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double latitude, double longitude, String address});
}

/// @nodoc
class __$$DeliveryLocationModelImplCopyWithImpl<$Res>
    extends
        _$DeliveryLocationModelCopyWithImpl<$Res, _$DeliveryLocationModelImpl>
    implements _$$DeliveryLocationModelImplCopyWith<$Res> {
  __$$DeliveryLocationModelImplCopyWithImpl(
    _$DeliveryLocationModelImpl _value,
    $Res Function(_$DeliveryLocationModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
  }) {
    return _then(
      _$DeliveryLocationModelImpl(
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeliveryLocationModelImpl extends _DeliveryLocationModel {
  const _$DeliveryLocationModelImpl({
    required this.latitude,
    required this.longitude,
    this.address = '',
  }) : super._();

  factory _$DeliveryLocationModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeliveryLocationModelImplFromJson(json);

  @override
  final double latitude;
  @override
  final double longitude;
  @override
  @JsonKey()
  final String address;

  @override
  String toString() {
    return 'DeliveryLocationModel(latitude: $latitude, longitude: $longitude, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeliveryLocationModelImpl &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.address, address) || other.address == address));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, latitude, longitude, address);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DeliveryLocationModelImplCopyWith<_$DeliveryLocationModelImpl>
  get copyWith =>
      __$$DeliveryLocationModelImplCopyWithImpl<_$DeliveryLocationModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DeliveryLocationModelImplToJson(this);
  }
}

abstract class _DeliveryLocationModel extends DeliveryLocationModel {
  const factory _DeliveryLocationModel({
    required final double latitude,
    required final double longitude,
    final String address,
  }) = _$DeliveryLocationModelImpl;
  const _DeliveryLocationModel._() : super._();

  factory _DeliveryLocationModel.fromJson(Map<String, dynamic> json) =
      _$DeliveryLocationModelImpl.fromJson;

  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String get address;
  @override
  @JsonKey(ignore: true)
  _$$DeliveryLocationModelImplCopyWith<_$DeliveryLocationModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
