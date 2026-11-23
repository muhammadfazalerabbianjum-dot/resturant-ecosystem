// UI-12 (p22) phase A — Amendment A1 receipts: the scoped `OrderModel.orderSource`
// domain seam granted by the coordinator (spec Section 2 Amendment A1, main@940f1ab).
//
// Written RED before the seam exists (p22 spec Section 3 phase A).
// REQUIRED RECEIPTS covered here:
//  * Law 24 roundtrip: platform value / absent / malformed (`12345` -> null, no throw).
//  * Client create path: `buildOfflineOrderPayload(...)` carries NO
//    `orderSource` key at all — the client can never forge the platform tag.
//    (p26 T-4 / D-P26-4(a) re-pin: the create rule's `hasOnly` allowlist
//    excludes the server-owned key, so the generator DROPS it instead of
//    emitting `orderSource: null`; a null value would still occupy a key slot
//    and be denied. Both assertions below therefore pin ABSENCE, which is
//    strictly stronger than the pre-T-4 `null` pin.)
//  * The accepted consequence (disclosed, not hidden): `OrderModel.toJson()`
//    still carries an `orderSource` key (null for locally-created orders) —
//    that is the model surface, unchanged by T-4.
// Consumer-isolation (p19 L6 query unchanged) is re-verified by the untouched
// `test/rules/query_scope_source_scan_test.dart` — run green in this phase.
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_offline_payload.dart';

OrderModel _order({Object? orderSource}) => OrderModel.fromJson({
  'id': 'o1',
  'status': 'confirmed',
  'createdAt': '2026-09-28T00:00:00.000',
  if (orderSource != null) 'orderSource': orderSource,
});

void main() {
  group('A1 seam — Law 24 roundtrip (platform / absent / malformed)', () {
    test('platform value round-trips fromJson -> toJson verbatim', () {
      final model = _order(orderSource: 'platform:uber_eats');
      expect(model.orderSource, 'platform:uber_eats');
      expect(model.toJson()['orderSource'], 'platform:uber_eats');
      expect(OrderSource.isPlatformOrder(model.orderSource), isTrue);
      expect(OrderSource.platformOf(model.orderSource), 'uber_eats');
    });

    test('absent orderSource stays null (renders exactly as today)', () {
      expect(_order().orderSource, isNull);
      expect(OrderSource.isPlatformOrder(_order().orderSource), isFalse);
      expect(OrderSource.platformOf(_order().orderSource), isNull);
    });

    test('malformed values fail closed to null and NEVER throw', () {
      expect(_order(orderSource: 12345).orderSource, isNull);
      expect(_order(orderSource: {'platform': 1}).orderSource, isNull);
      expect(_order(orderSource: true).orderSource, isNull);
      expect(_order(orderSource: '').orderSource, isNull);
      // A non-platform string is data, not a platform tag: the field keeps it,
      // the vocabulary check belongs to the badge.
      expect(_order(orderSource: 'driver-app').orderSource, 'driver-app');
      expect(OrderSource.isPlatformOrder('driver-app'), isFalse);
    });
  });

  group('A1 seam — client create path cannot forge the tag', () {
    test('buildOfflineOrderPayload carries NO orderSource key', () {
      final payload = buildOfflineOrderPayload(_order(), tenantId: 'tenant_a');
      expect(payload.containsKey('orderSource'), isFalse);
    });

    test('buildOfflineOrderPayload keeps a server-set platform tag out of the '
        'payload', () {
      // The offline create replay is a CLIENT write: even if a model in memory
      // somehow carried a tag, the pending-order builder must not emit it —
      // not as a truth value and not as a null placeholder (the create rule's
      // allowlist excludes the key; a present null key would be DENIED).
      final tagged = OrderModel.fromJson({
        'id': 'o1',
        'status': 'confirmed',
        'createdAt': '2026-09-28T00:00:00.000',
        'orderSource': 'platform:uber_eats',
      });
      final payload = buildOfflineOrderPayload(
        tagged,
        tenantId: 'tenant_a',
        queuedAt: DateTime.utc(2026, 9, 28),
      );
      expect(payload['status'], 'pending');
      expect(payload['offlineQueued'], isTrue);
      expect(payload.containsKey('orderSource'), isFalse);
    });

    test('the staff queue payload shape is EXACTLY two keys (L17)', () {
      expect(buildKitchenStatusUpdatePayload('o1', 'preparing'), {
        'id': 'o1',
        'status': 'preparing',
      });
    });
  });
}
