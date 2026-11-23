// UI-13 (p21) phase F adoption receipts — M-5 delivery tracker (contract §3-F).
//
// RED against the pre-adoption screen, GREEN after the library composition:
// F1: the three hand-rolled `_StatusIcon` rows (each a decorated `Container`)
//     become the frozen `OrderTimeline` progress model + a `StatusTile`/
//     `BrandBadge` current-status badge + a `SkeletonLoader` loading state.
// F2: the stream error and the not-found state render `InfoBanner`, never a raw
//     trace.
// L16: the tracking/listener logic (the `singleOrderProvider` stream, the
//      contact-driver dial, the reorder path) is untouched — the pre-existing
//      tracking suites stay green unmodified (git-diff proof in the report).
import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart'
    show singleOrderProvider;
import 'package:labs/features/tracking/presentation/delivery_tracker_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

OrderModel _order({OrderStatus status = OrderStatus.cooking}) => OrderModel(
  id: 'order-1',
  customerId: 'user-test',
  status: status,
  totalCents: 1500,
  createdAt: DateTime(2026, 1, 1),
);

/// Pumps the tracker with a controlled order stream.
///
/// [stream] `Stream.empty()`-style sources keep the screen in its loading state.
Future<void> _pumpTracker(
  WidgetTester tester, {
  required Stream<OrderModel?> stream,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [singleOrderProvider('order-1').overrideWith((ref) => stream)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DeliveryTrackerScreen(orderId: 'order-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  List<TimelineStepState> statesFor(OrderStatus status) =>
      DeliveryTrackerScreen.timelineStepsFor(
        loc,
        status,
      ).map((step) => step.state).toList();

  group('P21 F1 — delivery progress model (pure mapping)', () {
    test('the model is three customer-facing stages, in delivery order', () {
      final steps = DeliveryTrackerScreen.timelineStepsFor(
        loc,
        OrderStatus.cooking,
      );
      expect(steps, hasLength(3));
      expect(steps[0].label, contains('Preparing'));
      expect(steps[1].label, contains('On the way'));
      expect(steps[2].label, contains('Arrived'));
      // L13/L14: OrderModel carries no per-step timestamps, so the timeline is
      // never fed fabricated times.
      expect(steps.every((s) => s.timestamp == null), isTrue);
    });

    test('pre-kitchen statuses sit on the first stage', () {
      for (final status in [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.cooking,
      ]) {
        expect(statesFor(status), [
          TimelineStepState.current,
          TimelineStepState.future,
          TimelineStepState.future,
        ], reason: '$status');
      }
    });

    test('ready and picked-up sit on the delivery stage', () {
      for (final status in [OrderStatus.ready, OrderStatus.pickedUp]) {
        expect(statesFor(status), [
          TimelineStepState.completed,
          TimelineStepState.current,
          TimelineStepState.future,
        ], reason: '$status');
      }
    });

    test('delivered closes every stage', () {
      expect(statesFor(OrderStatus.delivered), [
        TimelineStepState.completed,
        TimelineStepState.completed,
        TimelineStepState.completed,
      ]);
    });

    test('cancelled never fabricates a stage', () {
      // The order died somewhere outside the three customer stages and
      // `OrderModel` does not record where; the cancellation is communicated by
      // the badge + status label, never by an invented timeline position.
      expect(statesFor(OrderStatus.cancelled), [
        TimelineStepState.future,
        TimelineStepState.future,
        TimelineStepState.future,
      ]);
    });

    test('the status badge tone follows the status semantics', () {
      expect(
        DeliveryTrackerScreen.tileStatusFor(OrderStatus.delivered),
        TileStatus.ok,
      );
      expect(
        DeliveryTrackerScreen.tileStatusFor(OrderStatus.cancelled),
        TileStatus.failed,
      );
      for (final status in [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.cooking,
        OrderStatus.ready,
        OrderStatus.pickedUp,
      ]) {
        expect(
          DeliveryTrackerScreen.tileStatusFor(status),
          TileStatus.pending,
          reason: '$status',
        );
      }
    });
  });

  group('P21 F1 — delivery tracker library composition (widgets)', () {
    testWidgets('the progress model renders through OrderTimeline', (
      tester,
    ) async {
      await _pumpTracker(tester, stream: Stream<OrderModel?>.value(_order()));

      expect(find.byType(OrderTimeline), findsOneWidget);
      // The three pre-adoption stage rows survive as timeline steps.
      expect(find.textContaining('Preparing'), findsOneWidget);
      expect(find.textContaining('On the way'), findsOneWidget);
      expect(find.textContaining('Arrived'), findsOneWidget);
    });

    testWidgets('the current status renders through StatusTile + BrandBadge', (
      tester,
    ) async {
      await _pumpTracker(tester, stream: Stream<OrderModel?>.value(_order()));

      expect(find.byType(StatusTile), findsOneWidget);
      expect(find.byType(BrandBadge), findsOneWidget);
      // The pre-adoption uppercase status composition is preserved verbatim.
      expect(find.text('COOKING'), findsOneWidget);
      expect(find.text('Delivery Status'), findsAtLeastNWidgets(1));
    });

    testWidgets('an error status badge carries the negative tone', (
      tester,
    ) async {
      await _pumpTracker(
        tester,
        stream: Stream<OrderModel?>.value(
          _order(status: OrderStatus.cancelled),
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.byType(StatusTile), findsOneWidget);
    });

    testWidgets('the loading state renders skeletons, no raw spinner', (
      tester,
    ) async {
      final controller = StreamController<OrderModel?>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider(
              'order-1',
            ).overrideWith((ref) => controller.stream),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('P21 F2 — error paths are handled states, never raw traces', () {
    testWidgets('a failed stream renders InfoBanner with the existing copy', (
      tester,
    ) async {
      await _pumpTracker(
        tester,
        stream: Stream<OrderModel?>.error(StateError('stream broke')),
      );

      expect(find.byType(InfoBanner), findsOneWidget);
      expect(
        find.text('Could not load this order. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('StateError'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null order renders the not-found banner, not a trace', (
      tester,
    ) async {
      await _pumpTracker(tester, stream: Stream<OrderModel?>.value(null));

      expect(find.byType(InfoBanner), findsOneWidget);
      expect(find.text('Order not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P21 F3 — L16 preservation through the restyle', () {
    testWidgets('the two customer actions survive with their chrome intact', (
      tester,
    ) async {
      await _pumpTracker(tester, stream: Stream<OrderModel?>.value(_order()));

      // The pre-existing suites pin these by type, so the adoption keeps the
      // pre-adoption chrome for both actions (DECISIONS §9.6).
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsWidgets);
      expect(find.text('Contact Driver'), findsOneWidget);
      expect(find.text('Reorder Items'), findsOneWidget);
    });

    testWidgets('the order id still titles the app bar', (tester) async {
      await _pumpTracker(tester, stream: Stream<OrderModel?>.value(_order()));

      // The pre-existing suite pins this text too; the adoption must not add a
      // second widget carrying the order id.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('order-1'),
        ),
        findsOneWidget,
      );
    });
  });
}
