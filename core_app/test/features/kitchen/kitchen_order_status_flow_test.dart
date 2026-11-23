import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// COV-1 — KITCHEN order-status flow.
///
/// The kitchen screen advances orders through the pipeline using the single
/// encoded state machine `OrderStatus.canTransitionTo`
/// (order_model.dart:28-63). This suite pins the KITCHEN slice of that matrix
/// as a workflow test — the legal kitchen path, the jumps kitchen staff must
/// never make, the direct-ready shortcut, legacy `cooking` parity, and the
/// terminal closes. (The exhaustive 8x8 matrix lives in the orders territory;
/// this is the kitchen-pipeline reading of the same oracle.)
void main() {
  group('Kitchen order-status flow — canTransitionTo', () {
    test('an order advances through the kitchen pipeline in legal steps', () {
      var status = OrderStatus.pending;
      expect(status.canTransitionTo(OrderStatus.confirmed), isTrue);
      status = OrderStatus.confirmed;
      expect(status.canTransitionTo(OrderStatus.preparing), isTrue);
      status = OrderStatus.preparing;
      expect(status.canTransitionTo(OrderStatus.ready), isTrue);
      // Ready leaves the kitchen to pickup + delivery downstream.
      status = OrderStatus.ready;
      expect(status.canTransitionTo(OrderStatus.pickedUp), isTrue);
      status = OrderStatus.pickedUp;
      expect(status.canTransitionTo(OrderStatus.delivered), isTrue);
    });

    test('kitchen staff cannot skip pipeline steps', () {
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.ready), isFalse);
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.delivered),
        isFalse,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.pickedUp),
        isFalse,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.delivered),
        isFalse,
      );
      // A ready order must be picked up before anything can deliver it.
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.delivered), isFalse);
    });

    test(
      'a confirmed order may be marked ready directly (finish-before-start)',
      () {
        // The kitchen UI offers "Start Preparing" for confirmed orders, but a
        // chef who completes an order before tapping start must not be blocked:
        // the machine allows confirmed -> ready in one step.
        expect(
          OrderStatus.confirmed.canTransitionTo(OrderStatus.ready),
          isTrue,
        );
      },
    );

    test('cancel is available at every non-terminal kitchen stage', () {
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.cancelled), isTrue);
      // ...but a delivered order is final (no revive-out-of-terminal).
      expect(
        OrderStatus.delivered.canTransitionTo(OrderStatus.cancelled),
        isFalse,
      );
    });

    test('legacy cooking orders advance exactly like preparing', () {
      expect(OrderStatus.cooking.canTransitionTo(OrderStatus.ready), isTrue);
      expect(
        OrderStatus.cooking.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.cooking.canTransitionTo(OrderStatus.pickedUp),
        isFalse,
      );
      expect(
        OrderStatus.cooking.canTransitionTo(OrderStatus.delivered),
        isFalse,
      );
    });

    test(
      'terminal statuses close the flow — stale-snapshot flips are rejected',
      () {
        for (final terminal in [OrderStatus.delivered, OrderStatus.cancelled]) {
          for (final next in OrderStatus.values) {
            expect(
              terminal.canTransitionTo(next),
              isFalse,
              reason: 'terminal $terminal must never advance to $next',
            );
          }
        }
        // The exact audit failure class: dead orders revived by stale snapshots.
        expect(
          OrderStatus.delivered.canTransitionTo(OrderStatus.preparing),
          isFalse,
          reason: 'a delivered order must never re-enter the kitchen pipeline',
        );
        expect(
          OrderStatus.cancelled.canTransitionTo(OrderStatus.confirmed),
          isFalse,
          reason: 'a cancelled order must never be revived',
        );
      },
    );
  });
}
