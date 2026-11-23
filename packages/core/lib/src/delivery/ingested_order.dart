/// UI-9 (p19) L2 + L6: the ingested-order vocabulary — the platform→our-menu
/// line mapping, the namespaced idempotency key, the `platform:<id>` order
/// source and the server-shaped order document.
///
/// Two laws are encoded here rather than in prose:
///
/// * **L2 idempotency** — the key of an ingested order is the PLATFORM's order
///   id, namespaced with the platform (`uber_eats:ORDER123`), so a webhook
///   replay can only ever find the existing order (no double-orders) and two
///   platforms can never collide on the same platform-side id.
/// * **L6 isolation** — a platform order belongs to the PLATFORM's customer, so
///   the persisted document carries `orderSource: platform:<id>` and NO
///   `customerId`. The consumer history query filters `customerId == uid`
///   (pinned by `core_app/test/rules/query_scope_source_scan_test.dart`), which
///   no platform order can ever match — while the kitchen dashboards read the
///   order by branch/status and DO see it.
///
/// Money (0.10): a draft carries the platform's claimed prices ONLY so the
/// server can re-derive them through the existing money-authority path
/// (`verifyMenuPricing` in `core_app/functions/src/payment.ts`); they are never
/// persisted as truth. `platformClaimedTotalCents` is recorded as a reference.
library;

/// The `orderSource` vocabulary and the consumer-history isolation rule.
class OrderSource {
  /// Prefix of every ingested platform order: `platform:uber_eats`.
  static const String platformPrefix = 'platform:';

  /// The order source of a platform order.
  static String forPlatform(String platformId) => '$platformPrefix$platformId';

  /// True when [source] is a platform order source (`platform:<id>`).
  static bool isPlatformOrder(Object? source) =>
      source is String && source.startsWith(platformPrefix);

  /// The platform id of a platform order source, or null for anything else.
  static String? platformOf(Object? source) {
    if (!isPlatformOrder(source)) return null;
    return (source as String).substring(platformPrefix.length);
  }

  /// The field the consumer order-history query filters on
  /// (`order_repository.dart`: `.where('customerId', isEqualTo: userId)`).
  /// A platform order never carries it (see [IngestedOrderDraft]).
  static const String consumerHistoryFilterField = 'customerId';
}

/// One selected modifier option on an ingested line.
class IngestedOption {
  const IngestedOption({required this.id, this.upchargeCents});

  /// The modifier option id, as published to the platform with OUR id.
  final String id;

  /// The platform's claimed upcharge (re-derived server-side; may be null).
  final int? upchargeCents;

  /// The flat option shape the server money path consumes.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (upchargeCents != null) 'upchargeCents': upchargeCents,
  };

  @override
  String toString() => 'IngestedOption($id)';
}

/// One ingested line, already resolved to OUR `menus/{id}` document id.
///
/// The catalog push (T-3) publishes our menu ids as the platform's item ids, so
/// an inbound line references OUR id directly — the re-derivation needs no
/// extra mapping table.
class IngestedOrderLine {
  const IngestedOrderLine({
    required this.menuItemId,
    required this.quantity,
    this.claimedUnitPriceCents,
    this.selectedOptions = const <IngestedOption>[],
  });

  final String menuItemId;
  final int quantity;

  /// The platform's claimed unit price in integer minor units (reference only).
  final int? claimedUnitPriceCents;

  final List<IngestedOption> selectedOptions;

  /// The FLAT line shape `extractMenuPricingInput` (the existing server
  /// re-derivation) consumes.
  Map<String, dynamic> toPricingInput() => <String, dynamic>{
    'id': menuItemId,
    'quantity': quantity,
    'priceCents': claimedUnitPriceCents,
    'selectedOptions': selectedOptions
        .map((option) => option.toJson())
        .toList(),
  };
}

/// What a platform adapter produces for one inbound order, before the server
/// re-derives the money.
class IngestedOrderDraft {
  const IngestedOrderDraft({
    required this.platformId,
    required this.platformOrderId,
    required this.storeId,
    required this.lines,
    this.claimedTotalCents,
  });

  final String platformId;
  final String platformOrderId;
  final String storeId;
  final List<IngestedOrderLine> lines;

  /// The platform's own total claim (integer minor units) — REFERENCE ONLY
  /// (0.10: platform pricing lives on the platform's ledger, ours on ours).
  final int? claimedTotalCents;

  /// L2: the idempotency key — the platform's order id, namespaced.
  String get idempotencyKey => '$platformId:$platformOrderId';

  /// L6: `platform:<id>`.
  String get orderSource => OrderSource.forPlatform(platformId);

  /// The deterministic document id for the persisted order (replays write the
  /// SAME document — belt-and-braces with the idempotency key).
  String get documentId => '${platformId}_$platformOrderId';

  /// The flat lines the existing money-authority re-derivation consumes.
  List<Map<String, dynamic>> get pricingLines =>
      lines.map((line) => line.toPricingInput()).toList();

  /// The server-built order document. It carries the VERIFIED money only
  /// (`itemsSubtotalCents` from the re-derivation, mirrored into `totalCents`)
  /// and deliberately has NO `customerId` and no customer PII (L6): the
  /// platform's customer is the platform's, not a Carnama user.
  Map<String, dynamic> toPersistedDocument({
    required List<Object?> canonicalItems,
    required int itemsSubtotalCents,
    required String branchId,
    required int? platformClaimedTotalCents,
  }) => <String, dynamic>{
    'orderSource': orderSource,
    'platformId': platformId,
    'platformStoreId': storeId,
    'platformOrderId': platformOrderId,
    'idempotencyKey': idempotencyKey,
    'status': 'confirmed',
    'branchId': branchId,
    'items': canonicalItems,
    'itemsSubtotalCents': itemsSubtotalCents,
    'totalCents': itemsSubtotalCents,
    'platformClaimedTotalCents': platformClaimedTotalCents,
  };
}
