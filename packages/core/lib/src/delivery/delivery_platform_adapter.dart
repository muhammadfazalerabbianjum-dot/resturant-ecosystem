/// UI-9 (p19) L1: the `DeliveryPlatformAdapter` contract — the white-label DNA.
///
/// We ship ADAPTERS; a client's validated config picks theirs (L3). Every
/// platform is an implementation of this interface, and a disabled/absent
/// config row means no adapter is ever constructed: the layer is inert.
///
/// The contract mirrors what the server-side functions need:
///   * `syncAvailability` — T-3: dish availability changes → the platform's
///     catalog API (Uber Menu API / DeliveryHero Catalog Import).
///   * `mapInboundOrder` — T-2 step (3): the platform's webhook/order payload →
///     an [IngestedOrderDraft] (our menu ids, claimed prices).
///   * `acknowledge` / `reject` — T-2 step (5): the platform protocol's
///     accept/deny callback.
///
/// Verification is NOT part of this interface: webhook signature verification is
/// a server-side concern of each platform's own transport
/// (see `platform_ingestion.ts`) — the adapter never sees an unverified payload.
library;

import 'ingested_order.dart';
import 'platform_config.dart';

/// One dish availability change destined for a platform catalog.
class DishAvailabilityUpdate {
  const DishAvailabilityUpdate({
    required this.menuItemId,
    required this.branchId,
    required this.isAvailable,
  });

  /// OUR `menus/{id}` document id (the id we publish to the platform catalog).
  final String menuItemId;

  /// The branch the item belongs to (the platform store is mapped per client).
  final String branchId;

  /// The new availability of the dish.
  final bool isAvailable;
}

/// A platform payload that cannot be turned into a draft (fail closed: the
/// caller routes the order to the platform's deny/fulfillment-issue flow or the
/// dead-letter queue; it is never guessed).
class IngestedOrderMappingError implements Exception {
  const IngestedOrderMappingError(this.reason, this.detail);

  /// Machine-readable reason (`malformed_payload`, `unknown_event`, …).
  final String reason;

  /// Operator-facing detail (never a raw payload dump).
  final String detail;

  @override
  String toString() => 'IngestedOrderMappingError($reason): $detail';
}

/// Thrown when an adapter is requested for a platform the config did not
/// activate (never a silent no-op: an inert platform is an explicit error at
/// the call site).
class AdapterNotConfiguredError implements Exception {
  const AdapterNotConfiguredError(this.platformId);

  final String platformId;

  @override
  String toString() =>
      'AdapterNotConfiguredError: no enabled adapter for platform '
      '"$platformId"';
}

/// The platform-agnostic adapter contract (L1).
abstract class DeliveryPlatformAdapter {
  /// The platform id — one of [DeliveryPlatforms.catalog].
  String get id;

  /// Pushes dish availability changes to the platform's catalog API.
  Future<void> syncAvailability(List<DishAvailabilityUpdate> updates);

  /// Maps one inbound (already VERIFIED) platform payload to a draft. Throws
  /// [IngestedOrderMappingError] when the payload cannot be mapped safely.
  IngestedOrderDraft mapInboundOrder(
    Map<String, dynamic> payload, {
    required String storeId,
  });

  /// The platform protocol's accept callback.
  Future<void> acknowledge(String platformOrderId);

  /// The platform protocol's deny callback (out-of-stock, price mismatch).
  Future<void> reject(String platformOrderId, {required String reason});
}

/// Builds the adapter for one validated config row.
typedef DeliveryPlatformAdapterFactory =
    DeliveryPlatformAdapter Function(DeliveryPlatformConfig config);

/// The config-gated adapter registry: only ENABLED, known platforms with a
/// registered factory ever produce an adapter.
class DeliveryPlatformRegistry {
  DeliveryPlatformRegistry._(this._configs, this._adapters);

  /// The validated ENABLED rows (may name a platform that ships no adapter
  /// implementation yet — that platform simply stays inert).
  final List<DeliveryPlatformConfig> _configs;
  final Map<String, DeliveryPlatformAdapter> _adapters;

  /// Builds the registry from the raw `deliveryPlatforms` config section.
  /// An absent/invalid section yields an EMPTY registry (nothing activates).
  factory DeliveryPlatformRegistry.fromConfig(
    Object? raw, {
    required Map<String, DeliveryPlatformAdapterFactory> factories,
  }) {
    final configs = DeliveryPlatforms.enabledPlatforms(raw);
    final adapters = <String, DeliveryPlatformAdapter>{};
    for (final config in configs) {
      final factory = factories[config.id];
      if (factory != null) adapters[config.id] = factory(config);
    }
    return DeliveryPlatformRegistry._(configs, adapters);
  }

  /// The platform ids the CONFIG enabled (whether or not they ship an adapter).
  List<String> get enabledIds =>
      List<String>.unmodifiable(_configs.map((config) => config.id));

  /// True when an adapter is actually available for [platformId].
  bool isEnabled(String platformId) => _adapters.containsKey(platformId);

  /// The adapter for [platformId], or null when the platform is inert.
  DeliveryPlatformAdapter? adapterFor(String platformId) =>
      _adapters[platformId];

  /// The validated config row for [platformId] (the ACTIVE row only).
  DeliveryPlatformConfig? configFor(String platformId) {
    for (final config in _configs) {
      if (config.id == platformId) return config;
    }
    return null;
  }

  /// The adapter for [platformId]; throws [AdapterNotConfiguredError] instead of
  /// returning null (the call site must know that nothing will be pushed).
  DeliveryPlatformAdapter require(String platformId) {
    final adapter = _adapters[platformId];
    if (adapter == null) throw AdapterNotConfiguredError(platformId);
    return adapter;
  }
}
