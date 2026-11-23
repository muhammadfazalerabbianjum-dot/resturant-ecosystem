import 'order_model.dart';

/// QUEUE-1 (W5.1(a)) — builds the RULES-LEGAL enqueue payload for an offline
/// order intent.
///
/// Firestore create rules only admit orders with `status == 'pending'`
/// (`core_app/firestore.rules:373-380`; the customer update branch does not
/// exist), so a `confirmed` offline replay would be rules-DENIED forever and
/// silently rot in the DLQ. This builder returns a SEPARATE map:
///
///   status:       'pending'  (rules-legal create)
///   offlineQueued: true      (offline-traceable marker)
///   queuedAt:     ISO-8601   (when the intent was queued)
///
/// The in-memory/UI [OrderModel] is NEVER mutated — the caller keeps showing
/// its real `confirmed` status while the queued intent is `pending`. Money
/// stays CF-authoritative: an unpaid intent is never replayed as `confirmed`.
///
/// p26 T-4 (D-P26-4(a)): the create rule now carries a KEY SHAPE LOCK
/// (`firestore.rules`, orders `allow create:` →
/// `request.resource.data.keys().hasOnly([...])`), and the allowlist excludes
/// `orderSource` — a server-owned field that only the admin-SDK platform
/// ingest (p19 L18) may write. `OrderModel.toJson()` emits that field as an
/// explicit `null` (the freezed factory has no `includeIfNull: false`), and a
/// null value still occupies a key slot in the candidate document, so the
/// replay would be DENIED and dead-lettered (Law 15). The key is therefore
/// removed here — the client side of the hardening. Receipts:
/// test/rules/order_create_payload_contract_test.dart (rule text read off
/// disk + subset check) and harness q-T3/q-T5.
Map<String, dynamic> buildOfflineOrderPayload(
  OrderModel order, {
  DateTime? queuedAt,
  required String tenantId,
}) {
  final payload = order.copyWith(status: OrderStatus.pending).toJson();
  payload.remove('orderSource');
  payload['offlineQueued'] = true;
  payload['queuedAt'] = (queuedAt ?? DateTime.now()).toIso8601String();
  // D-039: the create rule compares this key to the caller's `tenantId` claim,
  // so it is stamped from the claim (TenantClaim), never from config.
  payload['tenantId'] = tenantId;
  return payload;
}
