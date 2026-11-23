import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../cart/domain/cart_model.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  cooking, // legacy alias
  ready,
  pickedUp,
  delivered,
  cancelled;

  /// WHY: Firestore may store 'picked_up' or 'pickedUp' — normalise both.
  static OrderStatus fromString(String status) {
    final normalized = status.toLowerCase().replaceAll('_', '');
    return OrderStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => OrderStatus.pending,
    );
  }

  /// W8.3 (03-P1-TRANSITION): the order state machine, encoded ONCE on the
  /// enum. Every client status writer (KitchenService.updateOrderStatus,
  /// DeliveryService.markDelivered) MUST gate writes through this predicate —
  /// Firestore rules (W4.1) remain the server-side guard.
  ///
  /// Valid transitions:
  ///   pending   -> confirmed | preparing | cancelled
  ///   confirmed -> preparing | ready     | cancelled
  ///   preparing -> ready     | cancelled
  ///   cooking   -> ready     | cancelled  (legacy alias of preparing,
  ///                                       see this enum's `cooking` member)
  ///   ready     -> pickedUp  | cancelled
  ///   pickedUp  -> delivered
  ///   delivered / cancelled -> terminal (no outgoing transitions)
  bool canTransitionTo(OrderStatus next) {
    switch (this) {
      case OrderStatus.pending:
        return next == OrderStatus.confirmed ||
            next == OrderStatus.preparing ||
            next == OrderStatus.cancelled;
      case OrderStatus.confirmed:
        return next == OrderStatus.preparing ||
            next == OrderStatus.ready ||
            next == OrderStatus.cancelled;
      case OrderStatus.preparing:
      case OrderStatus.cooking: // legacy alias — same outgoing edges
        return next == OrderStatus.ready || next == OrderStatus.cancelled;
      case OrderStatus.ready:
        return next == OrderStatus.pickedUp || next == OrderStatus.cancelled;
      case OrderStatus.pickedUp:
        return next == OrderStatus.delivered;
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return false;
    }
  }
}

OrderStatus _statusFromJson(dynamic value) {
  if (value is String) return OrderStatus.fromString(value);
  return OrderStatus.pending;
}

String _statusToJson(OrderStatus status) => status.name;

/// json_serializable converter for [OrderStatus]: unknown status strings fall
/// back to [OrderStatus.pending] via the existing normalisers.
///
/// B3 P2 (finding 2.7): a `@JsonConverter` (rather than `@JsonKey`) lets the
/// freezed factory annotate the constructor parameter without the
/// `invalid_annotation_target` false positive (json_annotation 4.9.0 restricts
/// `JsonKey` to fields/getters only).
class OrderStatusConverter extends JsonConverter<OrderStatus, Object?> {
  const OrderStatusConverter();

  @override
  OrderStatus fromJson(Object? json) => _statusFromJson(json);

  @override
  Object? toJson(OrderStatus object) => _statusToJson(object);
}

/// L18 (UI-12 p22, Section 2 Amendment A1): reader for the `orderSource`
/// field p19's ingestion persists on the order document
/// (`platform_ingestion.ts` -> `buildOrderSource`, vocabulary
/// `OrderSource` in `package:core`), which the model never carried.
///
/// WHY a converter instead of a plain `String?` field: json_serializable would
/// generate `json['orderSource'] as String?` and THROW on a malformed payload
/// (an int, a map) — the register requires malformed input to fail closed to
/// `null`, never to crash a kitchen screen. The `platform:` vocabulary check
/// belongs to the badge (`OrderSource.isPlatformOrder`), not to this reader.
/// Same sanctioned pattern as [OrderStatusConverter] (`@JsonKey` on a freezed
/// parameter raises `invalid_annotation_target`).
class OrderSourceConverter extends JsonConverter<String?, Object?> {
  const OrderSourceConverter();

  /// Any non-empty string is kept verbatim; anything else is null.
  @override
  String? fromJson(Object? json) =>
      json is String && json.isNotEmpty ? json : null;

  @override
  Object? toJson(String? object) => object;
}

@freezed
abstract class OrderModel with _$OrderModel {
  const OrderModel._();

  const factory OrderModel({
    required String id,
    @Default('') String customerId,
    @Default(OrderStatus.pending)
    // B3 P2: `@OrderStatusConverter()` delegates to `_statusFromJson`/
    // `_statusToJson` for a graceful `pending` fallback. A `@JsonConverter`
    // (rather than `@JsonKey`) lets the freezed factory annotate this
    // parameter without the `invalid_annotation_target` false positive.
    @OrderStatusConverter()
    OrderStatus status,
    @Default(0) int totalCents,
    @Default(0) int taxCents,
    @Default(0) int discountCents,
    @Default(0) int tipCents,
    @Default(0) int deliveryFeeCents,
    @Default('') String orderNumber,
    required DateTime createdAt,
    DateTime? updatedAt,
    @Default([]) List<CartItemModel> items,
    String? branchId,
    String? assignedDriverId,
    // WHY: customerLocation stored as lat/lng — GeoPoint is not JSON serializable
    double? customerLat,
    double? customerLng,
    // L18 (Amendment A1): p19 ingests platform orders with
    // `orderSource: platform:<id>`; present on the document, absent on
    // locally-created orders. Read-only surface for the staff source badge —
    // receipted by test/features/orders/domain/p22_order_source_seam_test.dart.
    @OrderSourceConverter() String? orderSource,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  /// WHY: Firestore returns Timestamps and GeoPoints, which are not plain JSON.
  /// fromDoc normalises these into types json_serializable can handle.
  /// Returns null if the document is missing or empty to prevent GXa cast crashes.
  static OrderModel? tryFromDoc(DocumentSnapshot doc) {
    final rawData = doc.data();
    if (rawData == null) {
      return null; // Guard: prevents 'Null is not a subtype' crash
    }
    final data = Map<String, dynamic>.from(rawData as Map<dynamic, dynamic>);
    data['id'] = doc.id;

    // Normalise Timestamps to ISO-8601 strings
    // timestampToDateTime returns DateTime.now() for malformed/missing data per spec
    final createdAt = timestampToDateTime(
      (data['createdAt'] ?? DateTime.now()) as Object,
    );
    data['createdAt'] = createdAt.toIso8601String();
    if (data['updatedAt'] != null) {
      data['updatedAt'] = timestampToDateTime(
        data['updatedAt'] as Object,
      ).toIso8601String();
    }

    // Normalise GeoPoint to lat/lng doubles
    final gp = data['customerLocation'];
    if (gp is GeoPoint) {
      data['customerLat'] = gp.latitude;
      data['customerLng'] = gp.longitude;
    }
    data.remove('customerLocation');

    // Support legacy 'userId' field
    data['customerId'] ??= data['userId'] ?? '';

    // Normalise status string
    final statusStr = data['status'] as String? ?? 'pending';
    data['status'] = OrderStatus.fromString(statusStr).name;

    return OrderModel.fromJson(data);
  }

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    return tryFromDoc(doc) ??
        OrderModel(
          id: doc.id,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
        );
  }

  GeoPoint? get customerLocation => (customerLat != null && customerLng != null)
      ? GeoPoint(customerLat!, customerLng!)
      : null;
}
