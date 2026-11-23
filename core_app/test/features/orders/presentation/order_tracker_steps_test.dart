import 'dart:ui' show Tristate;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/features/orders/presentation/order_tracker_steps_widget.dart';
import 'package:labs/features/orders/domain/order_model.dart';

void main() {
  group('OrderTracker Aesthetic Tests (Law 6 Compliance)', () {
    testWidgets(
      'Injects Tier-1 Glassmorphism and AnimatedContainers on Order Steps',
      (WidgetTester tester) async {
        final dummyOrder = OrderModel(
          id: 'ord123',
          customerId: 'user1',
          totalCents: 1500,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: OrderTrackerStepsWidget(
                order: dummyOrder,
                currentStatus: OrderStatus.preparing,
              ),
            ),
          ),
        );

        // Assert Tier-1 Glassmorphism elements exist
        expect(find.byType(BackdropFilter), findsOneWidget);
        // Assert high-frame-rate animations exist for the timeline
        expect(find.byType(AnimatedContainer), findsWidgets);
      },
    );
  });

  group(
    'OrderTracker — T-2 step announcements (UX-2 / 05-P1-A11Y-TRACKER)',
    () {
      Future<SemanticsHandle> pumpTracker(
        WidgetTester tester,
        OrderStatus status,
      ) async {
        final handle = tester.ensureSemantics();
        final order = OrderModel(
          id: 'ord123',
          customerId: 'user1',
          totalCents: 1500,
          createdAt: DateTime.now(),
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: OrderTrackerStepsWidget(
                order: order,
                currentStatus: status,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return handle;
      }

      testWidgets('the CURRENT step is selected + live-region announced with a '
          'step-of-total phrase', (tester) async {
        final handle = await pumpTracker(tester, OrderStatus.preparing);

        // 8 OrderStatus values; preparing is index 2 → "Step 3 of 8".
        final currentFinder = find.bySemanticsLabel(RegExp('Step 3 of 8'));
        expect(currentFinder, findsOneWidget);

        final node = tester.getSemantics(currentFinder);
        expect(node.flagsCollection.isSelected, Tristate.isTrue);
        expect(
          node.flagsCollection.isLiveRegion,
          isTrue,
          reason: 'the current step must be announced as a live region',
        );
        expect(
          node.flagsCollection.isHeader,
          isTrue,
          reason: 'each step is a section header',
        );

        handle.dispose();
      });

      testWidgets(
        'future steps are headers but NOT selected and NOT live regions',
        (tester) async {
          final handle = await pumpTracker(tester, OrderStatus.preparing);

          // Step 8 of 8 (cancelled) is ahead of the current "preparing" step.
          final futureFinder = tester.getSemantics(
            find.bySemanticsLabel(RegExp('Step 8 of 8')),
          );
          expect(futureFinder.flagsCollection.isSelected, Tristate.isFalse);
          expect(futureFinder.flagsCollection.isLiveRegion, isFalse);
          expect(futureFinder.flagsCollection.isHeader, isTrue);

          handle.dispose();
        },
      );

      testWidgets(
        'completed steps carry selected state without a live region',
        (tester) async {
          final handle = await pumpTracker(tester, OrderStatus.preparing);

          final confirmedFinder = tester.getSemantics(
            find.bySemanticsLabel(RegExp('Step 2 of 8')),
          );
          expect(confirmedFinder.flagsCollection.isSelected, Tristate.isTrue);
          expect(confirmedFinder.flagsCollection.isLiveRegion, isFalse);

          handle.dispose();
        },
      );

      testWidgets(
        'status names come from the localized map, never enum .name',
        (tester) async {
          final handle = await pumpTracker(tester, OrderStatus.preparing);

          // 'Preparing' is the loc.orderStatus_preparing value; the raw enum
          // identifier "preparing" as a standalone node label is gone.
          expect(find.bySemanticsLabel(RegExp('Step 3 of 8')), findsOneWidget);

          handle.dispose();
        },
      );
    },
  );

  group('UI-13 (p21 B) — OrderTimeline adoption (M-8)', () {
    OrderModel makeOrder() => OrderModel(
      id: 'ord123',
      customerId: 'user1',
      totalCents: 1500,
      createdAt: DateTime.now(),
    );

    Future<OrderTimeline> pumpSteps(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OrderTrackerStepsWidget(
              order: makeOrder(),
              currentStatus: OrderStatus.preparing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<OrderTimeline>(find.byType(OrderTimeline));
    }

    testWidgets('steps render through the frozen OrderTimeline (B1)', (
      tester,
    ) async {
      final timeline = await pumpSteps(tester);

      expect(find.byType(OrderTimeline), findsOneWidget);
      expect(timeline.layout, OrderTimelineLayout.vertical);
      // The hand-rolled ListTile rows are gone (F3-10 customer sweep).
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets(
      'OrderStatus -> TimelineStepState mapping + UX-2 labels (preparing = '
      'index 2 of 8)',
      (tester) async {
        final timeline = await pumpSteps(tester);

        expect(timeline.steps, hasLength(OrderStatus.values.length));
        expect(timeline.steps.map((s) => s.state), <TimelineStepState>[
          TimelineStepState.completed, // pending
          TimelineStepState.completed, // confirmed
          TimelineStepState.current, // preparing
          TimelineStepState.future, // cooking
          TimelineStepState.future, // ready
          TimelineStepState.future, // pickedUp
          TimelineStepState.future, // delivered
          TimelineStepState.future, // cancelled
        ]);

        // UX-2: the step-of-total phrase stays inside the caller label
        // (byte-identical composition with the localized status name).
        expect(timeline.steps[2].label, 'Step 3 of 8: Preparing');
        // OrderModel carries no per-step timestamps — nothing invented (L13).
        expect(timeline.steps.every((s) => s.timestamp == null), isTrue);
      },
    );
  });
}
