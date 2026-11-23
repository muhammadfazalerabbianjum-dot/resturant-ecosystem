import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';

/// T-2 (STATE-1 / master W8.3): the FULL transition matrix of
/// [OrderStatus.canTransitionTo] — every legal pair accepted, every illegal
/// pair rejected over the exhaustive 8x8 matrix, terminal statuses closed.
void main() {
  group('OrderStatus.canTransitionTo — W8.3 order state machine (T-2)', () {
    const allowed = <OrderStatus, Set<OrderStatus>>{
      OrderStatus.pending: {
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.cancelled,
      },
      OrderStatus.confirmed: {
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.cancelled,
      },
      OrderStatus.preparing: {OrderStatus.ready, OrderStatus.cancelled},
      // `cooking` is the enum's own declared legacy alias of `preparing`
      // (order_model.dart) — identical outgoing edges, so a legacy `cooking`
      // order can never dead-end in the kitchen pipeline.
      OrderStatus.cooking: {OrderStatus.ready, OrderStatus.cancelled},
      OrderStatus.ready: {OrderStatus.pickedUp, OrderStatus.cancelled},
      OrderStatus.pickedUp: {OrderStatus.delivered},
      OrderStatus.delivered: {},
      OrderStatus.cancelled: {},
    };

    test('accepts every legal transition pair', () {
      allowed.forEach((from, targets) {
        for (final to in targets) {
          expect(
            from.canTransitionTo(to),
            isTrue,
            reason: '$from -> $to must be a legal transition',
          );
        }
      });
    });

    test('rejects every illegal pair in the exhaustive 8x8 matrix', () {
      for (final from in OrderStatus.values) {
        for (final to in OrderStatus.values) {
          final expected = allowed[from]!.contains(to);
          expect(
            from.canTransitionTo(to),
            expected,
            reason: '$from -> $to must be ${expected ? 'legal' : 'illegal'}',
          );
        }
      }
    });

    test('terminal statuses have no outgoing transitions', () {
      for (final terminal in [OrderStatus.delivered, OrderStatus.cancelled]) {
        for (final to in OrderStatus.values) {
          expect(
            terminal.canTransitionTo(to),
            isFalse,
            reason: 'terminal $terminal must never transition to $to',
          );
        }
      }
    });

    test(
      'the stale-snapshot flips that corrupted live orders are rejected',
      () {
        // The audit's 03-P1-TRANSITION failure class: dead orders revived.
        expect(
          OrderStatus.delivered.canTransitionTo(OrderStatus.pickedUp),
          isFalse,
          reason: 'a delivered order must never be revived',
        );
        expect(
          OrderStatus.cancelled.canTransitionTo(OrderStatus.preparing),
          isFalse,
          reason: 'a cancelled order must never re-enter the pipeline',
        );
        expect(
          OrderStatus.delivered.canTransitionTo(OrderStatus.delivered),
          isFalse,
          reason: 'self-transitions are redundant writes and must be rejected',
        );
        // Jumps skipping pipeline steps.
        expect(
          OrderStatus.pending.canTransitionTo(OrderStatus.ready),
          isFalse,
          reason: 'pending must pass through confirmed/preparing',
        );
        expect(
          OrderStatus.ready.canTransitionTo(OrderStatus.delivered),
          isFalse,
          reason: 'ready must be picked up before it can be delivered',
        );
      },
    );
  });
}
