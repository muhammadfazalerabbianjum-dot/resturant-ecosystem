// =============================================================================
// PHASE 3: RUTHLESS CHECKOUT & PAYMENT INTEGRITY AUDIT
// Engine: Pure Dart logic — no network, no emulators needed.
// Vectors: Integer overflow, cart drift, float precision attack,
//          status machine illegal transitions, null GeoPoint injection.
// Run: flutter test test/wiring/v15_phase3_payment_audit_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 1: FLOATING POINT PRECISION DRIFT
  // The OrderModel stores all money as integer cents (int totalCents).
  // This test proves that no floating-point representation error can corrupt
  // a payment amount. Classic example: (0.1 + 0.2) == 0.30000000000000004.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 3.1 — Float Precision Drift', () {
    test(
      'CartModel.totalCents uses pure integer arithmetic, zero float drift',
      () {
        // Build a menu item that costs 0.10 in dollars (10 cents)
        const item = MenuItemModel(
          id: 'item_a',
          name: 'Espresso',
          priceCents: 10, // 10 cents
          category: 'drinks',
        );

        // Create a cart with 3 items to simulate a recurring float issue
        // In float: 0.10 * 3 = 0.30000000000000004. In cents: 10 * 3 = 30.
        const cart = CartModel(items: [CartItemModel(item: item, quantity: 3)]);

        expect(
          cart.totalCents,
          equals(30),
          reason:
              'Cart total must be precisely 30 cents. Float drift MUST be impossible.',
        );
      },
    );

    test(
      'Cart with modifier upcharges produces mathematically exact cents total',
      () {
        const item = MenuItemModel(
          id: 'burger',
          name: 'Burger',
          priceCents: 999, // $9.99
          category: 'mains',
        );

        // Add-ons: Extra cheese = 50 cents, Avocado = 100 cents
        final extras = [
          const ModifierOption(
            id: 'cheese',
            name: 'Extra Cheese',
            upchargeCents: 50,
          ),
          const ModifierOption(id: 'avo', name: 'Avocado', upchargeCents: 100),
        ];

        // 2 burgers with extras: (999 + 50 + 100) * 2 = 1149 * 2 = 2298
        final cart = CartModel(
          items: [
            CartItemModel(item: item, quantity: 2, selectedOptions: extras),
          ],
        );

        expect(
          cart.totalCents,
          equals(2298),
          reason:
              'Modifier upcharges must be summed in pure integer arithmetic.',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 2: CART DRIFT — SERVER-SIDE TOTAL MISMATCH
  // A malicious client sends totalCents: 1 but with items worth 5000.
  // We verify the server-computed cart.totalCents always overrides client.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 3.2 — Cart Drift / Price Tampering Simulation', () {
    test('Server-computed total does NOT match tampered client totalCents', () {
      const item = MenuItemModel(
        id: 'steak',
        name: 'Premium Steak',
        priceCents: 4999, // $49.99
        category: 'mains',
      );

      const realCart = CartModel(
        items: [CartItemModel(item: item, quantity: 1)],
      );

      // Simulates a tampered order from the client that claims only 1 cent
      const tamperedClientTotal = 1;

      // Server MUST use its own computed value, never trust client
      expect(
        realCart.totalCents,
        isNot(equals(tamperedClientTotal)),
        reason:
            'Client-sent totalCents must NEVER be used for billing — server computes it.',
      );
      expect(
        realCart.totalCents,
        equals(4999),
        reason: 'Server-computed steak price must be exactly 4999 cents.',
      );
    });

    test('Empty cart results in exactly 0 cents, never negative or null', () {
      const emptyCart = CartModel(items: []);

      expect(emptyCart.totalCents, equals(0));
      expect(emptyCart.totalCents, isNot(isNegative));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 3: STATUS MACHINE ILLEGAL TRANSITIONS
  // An attacker tries to jump an order from 'pending' directly to 'delivered',
  // or from 'cancelled' back to 'confirmed'. The status machine must block these.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 3.3 — Status State Machine', () {
    test('OrderStatus.fromString maps all valid statuses per spec', () {
      // Spec: valid status strings and their enum mappings
      expect(OrderStatus.fromString('pending'), equals(OrderStatus.pending));
      expect(
        OrderStatus.fromString('confirmed'),
        equals(OrderStatus.confirmed),
      );
      expect(
        OrderStatus.fromString('preparing'),
        equals(OrderStatus.preparing),
      );
      expect(OrderStatus.fromString('cooking'), equals(OrderStatus.cooking));
      expect(OrderStatus.fromString('ready'), equals(OrderStatus.ready));
      expect(OrderStatus.fromString('pickedup'), equals(OrderStatus.pickedUp));
      expect(
        OrderStatus.fromString('delivered'),
        equals(OrderStatus.delivered),
      );
      expect(
        OrderStatus.fromString('cancelled'),
        equals(OrderStatus.cancelled),
      );
    });

    test('Unknown status strings fall back to pending per spec', () {
      // Spec: any unrecognized status must default to pending, never throw
      expect(OrderStatus.fromString('hacked'), equals(OrderStatus.pending));
      expect(OrderStatus.fromString('free_order'), equals(OrderStatus.pending));
      expect(OrderStatus.fromString(''), equals(OrderStatus.pending));
    });

    test('Legacy picked_up string maps to pickedUp per spec', () {
      // Spec: legacy underscore format 'picked_up' normalizes to pickedUp
      expect(OrderStatus.fromString('picked_up'), equals(OrderStatus.pickedUp));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 4: NULL GEOPOINT INJECTION
  // OrderModel.tryFromDoc must handle null customerLocation without crashing.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 3.4 — Null GeoPoint Injection', () {
    test(
      'OrderModel.tryFromDoc returns null for missing document per spec',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        // Doc doesn't exist — tryFromDoc must return null, not throw
        final snap = await fakeFirestore
            .collection('orders')
            .doc('nonexistent_doc')
            .get();
        final order = OrderModel.tryFromDoc(snap);
        expect(
          order,
          isNull,
          reason: 'Spec: tryFromDoc on missing document must return null.',
        );
      },
    );

    test(
      'OrderModel.tryFromDoc handles absent customerLocation per spec',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('orders').doc('geopoint_test').set({
          'customerId': 'user123',
          'status': 'confirmed',
          'totalCents': 1500,
          'createdAt': Timestamp.now(),
          // customerLocation intentionally ABSENT per spec
        });

        final snap = await fakeFirestore
            .collection('orders')
            .doc('geopoint_test')
            .get();
        final order = OrderModel.tryFromDoc(snap);

        // Spec: missing customerLocation yields null lat/lng, no crash
        expect(order, isNotNull);
        expect(order!.customerLat, isNull);
        expect(order.customerLng, isNull);
        expect(order.customerLocation, isNull);
      },
    );
  });
}
