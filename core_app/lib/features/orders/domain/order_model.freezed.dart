// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
  String get id => throw _privateConstructorUsedError;
  String get customerId => throw _privateConstructorUsedError;
  @OrderStatusConverter()
  OrderStatus get status => throw _privateConstructorUsedError;
  int get totalCents => throw _privateConstructorUsedError;
  int get taxCents => throw _privateConstructorUsedError;
  int get discountCents => throw _privateConstructorUsedError;
  int get tipCents => throw _privateConstructorUsedError;
  int get deliveryFeeCents => throw _privateConstructorUsedError;
  String get orderNumber => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  List<CartItemModel> get items => throw _privateConstructorUsedError;
  String? get branchId => throw _privateConstructorUsedError;
  String? get assignedDriverId =>
      throw _privateConstructorUsedError; // WHY: customerLocation stored as lat/lng — GeoPoint is not JSON serializable
  double? get customerLat => throw _privateConstructorUsedError;
  double? get customerLng =>
      throw _privateConstructorUsedError; // L18 (Amendment A1): p19 ingests platform orders with
  // `orderSource: platform:<id>`; present on the document, absent on
  // locally-created orders. Read-only surface for the staff source badge —
  // receipted by test/features/orders/domain/p22_order_source_seam_test.dart.
  @OrderSourceConverter()
  String? get orderSource => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
    OrderModel value,
    $Res Function(OrderModel) then,
  ) = _$OrderModelCopyWithImpl<$Res, OrderModel>;
  @useResult
  $Res call({
    String id,
    String customerId,
    @OrderStatusConverter() OrderStatus status,
    int totalCents,
    int taxCents,
    int discountCents,
    int tipCents,
    int deliveryFeeCents,
    String orderNumber,
    DateTime createdAt,
    DateTime? updatedAt,
    List<CartItemModel> items,
    String? branchId,
    String? assignedDriverId,
    double? customerLat,
    double? customerLng,
    @OrderSourceConverter() String? orderSource,
  });
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? customerId = null,
    Object? status = null,
    Object? totalCents = null,
    Object? taxCents = null,
    Object? discountCents = null,
    Object? tipCents = null,
    Object? deliveryFeeCents = null,
    Object? orderNumber = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? items = null,
    Object? branchId = freezed,
    Object? assignedDriverId = freezed,
    Object? customerLat = freezed,
    Object? customerLng = freezed,
    Object? orderSource = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            customerId: null == customerId
                ? _value.customerId
                : customerId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OrderStatus,
            totalCents: null == totalCents
                ? _value.totalCents
                : totalCents // ignore: cast_nullable_to_non_nullable
                      as int,
            taxCents: null == taxCents
                ? _value.taxCents
                : taxCents // ignore: cast_nullable_to_non_nullable
                      as int,
            discountCents: null == discountCents
                ? _value.discountCents
                : discountCents // ignore: cast_nullable_to_non_nullable
                      as int,
            tipCents: null == tipCents
                ? _value.tipCents
                : tipCents // ignore: cast_nullable_to_non_nullable
                      as int,
            deliveryFeeCents: null == deliveryFeeCents
                ? _value.deliveryFeeCents
                : deliveryFeeCents // ignore: cast_nullable_to_non_nullable
                      as int,
            orderNumber: null == orderNumber
                ? _value.orderNumber
                : orderNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<CartItemModel>,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            assignedDriverId: freezed == assignedDriverId
                ? _value.assignedDriverId
                : assignedDriverId // ignore: cast_nullable_to_non_nullable
                      as String?,
            customerLat: freezed == customerLat
                ? _value.customerLat
                : customerLat // ignore: cast_nullable_to_non_nullable
                      as double?,
            customerLng: freezed == customerLng
                ? _value.customerLng
                : customerLng // ignore: cast_nullable_to_non_nullable
                      as double?,
            orderSource: freezed == orderSource
                ? _value.orderSource
                : orderSource // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
    _$OrderModelImpl value,
    $Res Function(_$OrderModelImpl) then,
  ) = __$$OrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String customerId,
    @OrderStatusConverter() OrderStatus status,
    int totalCents,
    int taxCents,
    int discountCents,
    int tipCents,
    int deliveryFeeCents,
    String orderNumber,
    DateTime createdAt,
    DateTime? updatedAt,
    List<CartItemModel> items,
    String? branchId,
    String? assignedDriverId,
    double? customerLat,
    double? customerLng,
    @OrderSourceConverter() String? orderSource,
  });
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
    _$OrderModelImpl _value,
    $Res Function(_$OrderModelImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? customerId = null,
    Object? status = null,
    Object? totalCents = null,
    Object? taxCents = null,
    Object? discountCents = null,
    Object? tipCents = null,
    Object? deliveryFeeCents = null,
    Object? orderNumber = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? items = null,
    Object? branchId = freezed,
    Object? assignedDriverId = freezed,
    Object? customerLat = freezed,
    Object? customerLng = freezed,
    Object? orderSource = freezed,
  }) {
    return _then(
      _$OrderModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        customerId: null == customerId
            ? _value.customerId
            : customerId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OrderStatus,
        totalCents: null == totalCents
            ? _value.totalCents
            : totalCents // ignore: cast_nullable_to_non_nullable
                  as int,
        taxCents: null == taxCents
            ? _value.taxCents
            : taxCents // ignore: cast_nullable_to_non_nullable
                  as int,
        discountCents: null == discountCents
            ? _value.discountCents
            : discountCents // ignore: cast_nullable_to_non_nullable
                  as int,
        tipCents: null == tipCents
            ? _value.tipCents
            : tipCents // ignore: cast_nullable_to_non_nullable
                  as int,
        deliveryFeeCents: null == deliveryFeeCents
            ? _value.deliveryFeeCents
            : deliveryFeeCents // ignore: cast_nullable_to_non_nullable
                  as int,
        orderNumber: null == orderNumber
            ? _value.orderNumber
            : orderNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<CartItemModel>,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        assignedDriverId: freezed == assignedDriverId
            ? _value.assignedDriverId
            : assignedDriverId // ignore: cast_nullable_to_non_nullable
                  as String?,
        customerLat: freezed == customerLat
            ? _value.customerLat
            : customerLat // ignore: cast_nullable_to_non_nullable
                  as double?,
        customerLng: freezed == customerLng
            ? _value.customerLng
            : customerLng // ignore: cast_nullable_to_non_nullable
                  as double?,
        orderSource: freezed == orderSource
            ? _value.orderSource
            : orderSource // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl extends _OrderModel {
  const _$OrderModelImpl({
    required this.id,
    this.customerId = '',
    @OrderStatusConverter() this.status = OrderStatus.pending,
    this.totalCents = 0,
    this.taxCents = 0,
    this.discountCents = 0,
    this.tipCents = 0,
    this.deliveryFeeCents = 0,
    this.orderNumber = '',
    required this.createdAt,
    this.updatedAt,
    final List<CartItemModel> items = const [],
    this.branchId,
    this.assignedDriverId,
    this.customerLat,
    this.customerLng,
    @OrderSourceConverter() this.orderSource,
  }) : _items = items,
       super._();

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String customerId;
  @override
  @JsonKey()
  @OrderStatusConverter()
  final OrderStatus status;
  @override
  @JsonKey()
  final int totalCents;
  @override
  @JsonKey()
  final int taxCents;
  @override
  @JsonKey()
  final int discountCents;
  @override
  @JsonKey()
  final int tipCents;
  @override
  @JsonKey()
  final int deliveryFeeCents;
  @override
  @JsonKey()
  final String orderNumber;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;
  final List<CartItemModel> _items;
  @override
  @JsonKey()
  List<CartItemModel> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? branchId;
  @override
  final String? assignedDriverId;
  // WHY: customerLocation stored as lat/lng — GeoPoint is not JSON serializable
  @override
  final double? customerLat;
  @override
  final double? customerLng;
  // L18 (Amendment A1): p19 ingests platform orders with
  // `orderSource: platform:<id>`; present on the document, absent on
  // locally-created orders. Read-only surface for the staff source badge —
  // receipted by test/features/orders/domain/p22_order_source_seam_test.dart.
  @override
  @OrderSourceConverter()
  final String? orderSource;

  @override
  String toString() {
    return 'OrderModel(id: $id, customerId: $customerId, status: $status, totalCents: $totalCents, taxCents: $taxCents, discountCents: $discountCents, tipCents: $tipCents, deliveryFeeCents: $deliveryFeeCents, orderNumber: $orderNumber, createdAt: $createdAt, updatedAt: $updatedAt, items: $items, branchId: $branchId, assignedDriverId: $assignedDriverId, customerLat: $customerLat, customerLng: $customerLng, orderSource: $orderSource)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.customerId, customerId) ||
                other.customerId == customerId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalCents, totalCents) ||
                other.totalCents == totalCents) &&
            (identical(other.taxCents, taxCents) ||
                other.taxCents == taxCents) &&
            (identical(other.discountCents, discountCents) ||
                other.discountCents == discountCents) &&
            (identical(other.tipCents, tipCents) ||
                other.tipCents == tipCents) &&
            (identical(other.deliveryFeeCents, deliveryFeeCents) ||
                other.deliveryFeeCents == deliveryFeeCents) &&
            (identical(other.orderNumber, orderNumber) ||
                other.orderNumber == orderNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.assignedDriverId, assignedDriverId) ||
                other.assignedDriverId == assignedDriverId) &&
            (identical(other.customerLat, customerLat) ||
                other.customerLat == customerLat) &&
            (identical(other.customerLng, customerLng) ||
                other.customerLng == customerLng) &&
            (identical(other.orderSource, orderSource) ||
                other.orderSource == orderSource));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    customerId,
    status,
    totalCents,
    taxCents,
    discountCents,
    tipCents,
    deliveryFeeCents,
    orderNumber,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_items),
    branchId,
    assignedDriverId,
    customerLat,
    customerLng,
    orderSource,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(this);
  }
}

abstract class _OrderModel extends OrderModel {
  const factory _OrderModel({
    required final String id,
    final String customerId,
    @OrderStatusConverter() final OrderStatus status,
    final int totalCents,
    final int taxCents,
    final int discountCents,
    final int tipCents,
    final int deliveryFeeCents,
    final String orderNumber,
    required final DateTime createdAt,
    final DateTime? updatedAt,
    final List<CartItemModel> items,
    final String? branchId,
    final String? assignedDriverId,
    final double? customerLat,
    final double? customerLng,
    @OrderSourceConverter() final String? orderSource,
  }) = _$OrderModelImpl;
  const _OrderModel._() : super._();

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

  @override
  String get id;
  @override
  String get customerId;
  @override
  @OrderStatusConverter()
  OrderStatus get status;
  @override
  int get totalCents;
  @override
  int get taxCents;
  @override
  int get discountCents;
  @override
  int get tipCents;
  @override
  int get deliveryFeeCents;
  @override
  String get orderNumber;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  List<CartItemModel> get items;
  @override
  String? get branchId;
  @override
  String? get assignedDriverId;
  @override // WHY: customerLocation stored as lat/lng — GeoPoint is not JSON serializable
  double? get customerLat;
  @override
  double? get customerLng;
  @override // L18 (Amendment A1): p19 ingests platform orders with
  // `orderSource: platform:<id>`; present on the document, absent on
  // locally-created orders. Read-only surface for the staff source badge —
  // receipted by test/features/orders/domain/p22_order_source_seam_test.dart.
  @OrderSourceConverter()
  String? get orderSource;
  @override
  @JsonKey(ignore: true)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
