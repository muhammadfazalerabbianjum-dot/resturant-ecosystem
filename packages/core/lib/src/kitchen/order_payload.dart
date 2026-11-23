/// Minimal data contract required by [KitchenOfflineService] for offline
/// order synchronisation.
///
/// Core must never depend on feature models. This interface captures only the
/// JSON round-trip the service needs. Feature models are bridged to this
/// contract via an adapter supplied by the feature layer.
abstract class OrderPayload {
  Map<String, dynamic> toJson();
}

/// Builds an [OrderPayload] from its serialized JSON form.
///
/// Dart does not support abstract factory constructors, so the "fromJson"
/// half of the contract is expressed as a parser function. The concrete
/// feature layer supplies the implementation (e.g.
/// `OrderPayloadAdapter.fromJson`), keeping core feature-agnostic.
typedef OrderPayloadParser = OrderPayload Function(Map<String, dynamic> json);
