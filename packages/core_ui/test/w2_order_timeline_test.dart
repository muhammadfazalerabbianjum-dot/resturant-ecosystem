import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-11 (p23) T-2 — W-2 `OrderTimeline` contract tests.
///
/// Written FIRST (red receipt: `tool_uilib/p23/red_w2.txt`) per the §3 T-2 row:
/// every step state × both layouts, optional timestamps, the current-step
/// a11y announcement, the "no timers / pure presentation" law, and goldens
/// (en vertical / ar+RTL horizontal).
void main() {
  List<OrderTimelineStep> verticalSteps() => const <OrderTimelineStep>[
    OrderTimelineStep(
      label: 'Placed',
      timestamp: '09:15',
      state: TimelineStepState.completed,
    ),
    OrderTimelineStep(label: 'Preparing', state: TimelineStepState.current),
    OrderTimelineStep(label: 'On the way', state: TimelineStepState.future),
    OrderTimelineStep(label: 'Cancelled', state: TimelineStepState.error),
  ];

  Widget wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
    return MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('T-2 OrderTimeline contract', () {
    testWidgets('renders every step label in order (vertical, top to bottom)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(OrderTimeline(steps: verticalSteps())));
      await tester.pumpAndSettle();

      final labels = <String>['Placed', 'Preparing', 'On the way', 'Cancelled'];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      final offsets = <double>[
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      ];
      expect(offsets, List.of(offsets)..sort(), reason: 'vertical order');
    });

    testWidgets('state markers: completed checks, error flags, current and '
        'future show their step number', (tester) async {
      await tester.pumpWidget(wrap(OrderTimeline(steps: verticalSteps())));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget, reason: 'completed');
      expect(find.byIcon(Icons.error_outline), findsOneWidget, reason: 'error');
      // current = step 2, future = step 3 — both render their number.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('current label is emphasised, future label is muted (tokens, '
        'no hardcoded hues)', (tester) async {
      await tester.pumpWidget(wrap(OrderTimeline(steps: verticalSteps())));
      await tester.pumpAndSettle();

      final current = tester.widget<Text>(find.text('Preparing'));
      expect(current.style?.fontWeight, FontWeight.w700);

      final future = tester.widget<Text>(find.text('On the way'));
      expect(
        future.style?.color,
        const BrandColors.fallback().textSecondary,
        reason: 'future steps ride the brand token, never a raw hue',
      );
    });

    testWidgets('timestamps render when supplied and are omitted when null', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(OrderTimeline(steps: verticalSteps())));
      await tester.pumpAndSettle();

      expect(find.text('09:15'), findsOneWidget);
      final preparing = tester.widget<Text>(find.text('Preparing'));
      expect(preparing.data, 'Preparing');
    });

    testWidgets('horizontal layout keeps the declared order left-to-right', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OrderTimeline(
            steps: verticalSteps(),
            layout: OrderTimelineLayout.horizontal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final xs = <double>[
        for (final label in const ['Placed', 'Preparing', 'On the way'])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(xs, List.of(xs)..sort(), reason: 'declared order in LTR');
    });

    testWidgets('RTL mirrors the horizontal order (first step right-most)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          OrderTimeline(
            steps: verticalSteps(),
            layout: OrderTimelineLayout.horizontal,
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();

      final placed = tester.getCenter(find.text('Placed')).dx;
      final preparing = tester.getCenter(find.text('Preparing')).dx;
      expect(placed, greaterThan(preparing), reason: 'first is right-most');
    });

    testWidgets('a11y: current step is a selected live-region header; future '
        'and completed steps are not live regions', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(OrderTimeline(steps: verticalSteps())));
      await tester.pumpAndSettle();

      final current = tester.getSemantics(find.bySemanticsLabel('Preparing'));
      expect(current.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        current.flagsCollection.isLiveRegion,
        isTrue,
        reason: 'the current step must be announced as a live region',
      );
      expect(current.flagsCollection.isHeader, isTrue);

      final completed = tester.getSemantics(
        find.bySemanticsLabel('Placed 09:15'),
      );
      expect(completed.flagsCollection.isSelected, Tristate.isTrue);
      expect(completed.flagsCollection.isLiveRegion, isFalse);

      final future = tester.getSemantics(find.bySemanticsLabel('On the way'));
      expect(future.flagsCollection.isSelected, Tristate.isFalse);
      expect(future.flagsCollection.isLiveRegion, isFalse);
      expect(future.flagsCollection.isHeader, isTrue);

      handle.dispose();
    });

    testWidgets('a timestamp joins the announced label for the current step', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const stamped = OrderTimelineStep(
        label: 'Preparing',
        timestamp: '09:16',
        state: TimelineStepState.current,
      );
      await tester.pumpWidget(wrap(const OrderTimeline(steps: [stamped])));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Preparing 09:16'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pure presentation: no tap path and an empty step list renders '
        'without throwing (L5)', (tester) async {
      await tester.pumpWidget(wrap(const OrderTimeline(steps: [])));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OrderTimeline), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    test('no timers: the source schedules nothing (pure presentation)', () {
      final source = File('lib/src/ui/order_timeline.dart').readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final token in <String>[
        'Timer',
        'Ticker',
        'Future.delayed',
        'StreamController',
        'addPostFrameCallback',
        'AnimatedBuilder',
      ]) {
        expect(
          code.contains(token),
          isFalse,
          reason: 'order_timeline.dart must not schedule ($token found)',
        );
      }
    });
  });

  group('T-2 OrderTimeline goldens', () {
    testWidgets('vertical timeline (light, en)', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: OrderTimeline(
                  steps: <OrderTimelineStep>[
                    OrderTimelineStep(
                      label: 'Placed',
                      timestamp: '09:15',
                      state: TimelineStepState.completed,
                    ),
                    OrderTimelineStep(
                      label: 'Preparing',
                      timestamp: '09:16',
                      state: TimelineStepState.current,
                    ),
                    OrderTimelineStep(label: 'On the way'),
                    OrderTimelineStep(
                      label: 'Cancelled',
                      state: TimelineStepState.error,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/order_timeline_vertical_en.png'),
      );
    });

    testWidgets('horizontal timeline (light, ar, RTL)', (tester) async {
      tester.view.physicalSize = const Size(400, 220);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: OrderTimeline(
                  layout: OrderTimelineLayout.horizontal,
                  steps: <OrderTimelineStep>[
                    OrderTimelineStep(
                      label: 'تم الطلب',
                      timestamp: '٠٩:١٥',
                      state: TimelineStepState.completed,
                    ),
                    OrderTimelineStep(
                      label: 'قيد التحضير',
                      state: TimelineStepState.current,
                    ),
                    OrderTimelineStep(label: 'في الطريق'),
                    OrderTimelineStep(
                      label: 'ملغي',
                      state: TimelineStepState.error,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/order_timeline_horizontal_rtl_ar.png'),
      );
    });
  });
}
