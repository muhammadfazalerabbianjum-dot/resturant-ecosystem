import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// p28 lane B (T-4) — runtime construction of the W-1/W-2/W-3 data contracts.
///
/// WHY: every pre-existing test builds these options/steps/points inside
/// `const` lists (w1/w2/w3), so the `const` constructors only ever run at
/// compile time and the coverage engine records their declaration lines as
/// never executed — failing the fleet NEW-file rule (LH must equal LF) no
/// matter how many widget pumps run. These tests build the same contracts at
/// RUNTIME (computed values, never const-folded) and assert the behaviour
/// each construction exists for: exact value echo, caller-owned option echo,
/// rendered step text, rendered bucket labels.
void main() {
  /// Wraps a literal so the result is never a compile-time constant.
  ///
  /// WHY: `prefer_const_*` lints (fatal under --fatal-infos) would otherwise
  /// force these constructions into `const`, where the constructor only runs
  /// at compile time and its declaration line never registers coverage —
  /// the exact gap this file exists to close. No lint is suppressed; the
  /// value simply is not const-evaluable.
  T runtime<T>(T value) => value;

  group('runtime-constructed data-class contracts (p28 T-4)', () {
    testWidgets('SegmentSelector echoes the exact runtime-built value on tap', (
      tester,
    ) async {
      final computed = runtime(42); // runtime value — cannot be const-folded
      int? selected;
      final segments = <SegmentOption<int>>[
        SegmentOption(value: computed, label: 'Delivery'),
        SegmentOption(value: computed + 1, label: 'Pickup'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentSelector<int>(
              segments: segments,
              selectedValue: null,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );

      expect(find.text('Delivery'), findsOneWidget);
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();
      expect(selected, 42, reason: 'tapped runtime value echoed verbatim');
    });

    testWidgets('TipSelector reports the runtime-built option the user chose', (
      tester,
    ) async {
      final presets = <int>[5, 10, 15];
      final options = <TipOption<int>>[
        for (final p in presets) TipOption(value: p, label: '$p%'),
      ];
      TipOption<int>? chosen;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TipSelector<int>(
              options: options,
              selectedOption: null,
              onChanged: (option) => chosen = option,
            ),
          ),
        ),
      );

      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();
      expect(chosen, isNotNull);
      expect(chosen!.value, 10);
      expect(chosen!.label, '10%', reason: 'L24: caller label stays verbatim');
    });

    testWidgets('OrderTimeline renders runtime-built steps with timestamps', (
      tester,
    ) async {
      final steps = <OrderTimelineStep>[
        OrderTimelineStep(
          label: runtime('Placed'),
          timestamp: runtime('09:15'),
          state: TimelineStepState.completed,
        ),
        OrderTimelineStep(
          label: runtime('Preparing'),
          state: TimelineStepState.current,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: OrderTimeline(steps: steps)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Placed'), findsOneWidget);
      expect(find.text('09:15'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
    });

    testWidgets('BrandChart renders runtime-built buckets with their labels', (
      tester,
    ) async {
      final magnitudes = <double>[100, 500, 1000];
      const labels = <String>['Mon', 'Tue', 'Wed'];
      final points = <BrandChartPoint>[
        for (var i = 0; i < labels.length; i++)
          BrandChartPoint(label: labels[i], value: magnitudes[i]),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: BrandChart(
                  kind: BrandChartKind.bars,
                  points: points,
                  emptyTitle: 'No revenue yet',
                  emptySubtitle: 'A chart appears once data lands',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });
}
