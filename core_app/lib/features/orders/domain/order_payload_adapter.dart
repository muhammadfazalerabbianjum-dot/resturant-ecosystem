import 'package:core/core.dart';
import 'order_model.dart';

/// Bridges [OrderModel] (feature layer) to [OrderPayload] (core contract).
///
/// The core `KitchenOfflineService` only needs a JSON round-trip; this adapter
/// supplies it without core ever importing a feature model.
class OrderPayloadAdapter implements OrderPayload {
  const OrderPayloadAdapter(this._order);

  final OrderModel _order;

  /// Parses a raw JSON payload into an [OrderModel], wrapped as an
  /// [OrderPayload]. Drop-in parser for `KitchenOfflineService`.
  factory OrderPayloadAdapter.fromJson(Map<String, dynamic> json) =>
      OrderPayloadAdapter(OrderModel.fromJson(json));

  OrderModel get order => _order;

  @override
  Map<String, dynamic> toJson() => _order.toJson();
}
