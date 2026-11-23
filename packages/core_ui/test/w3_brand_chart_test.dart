import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-11 (p23) T-3 — W-3 `BrandChart` family contract tests.
///
/// Written FIRST (red receipt: `tool_uilib/p23/red_w3.txt`) per the §3 T-3 row
/// and **L26 (chart honesty)**: empty series => the library's
/// `EmptyStateWidget`, single-point series => no divide-by-zero, discrete
/// buckets => no implied interpolation, token colours only, optional legend,
/// label truncation, extreme values, RTL.
void main() {
  List<BrandChartPoint> three() => const <BrandChartPoint>[
    BrandChartPoint(label: 'Mon', value: 0),
    BrandChartPoint(label: 'Tue', value: 500),
    BrandChartPoint(label: 'Wed', value: 1000),
  ];

  BrandChart chart(
    BrandChartKind kind,
    List<BrandChartPoint> points, {
    String? title,
    bool showLegend = false,
  }) {
    return BrandChart(
      kind: kind,
      points: points,
      emptyTitle: 'No revenue yet',
      emptySubtitle: 'A chart appears once data lands',
      title: title,
      showLegend: showLegend,
    );
  }

  Widget wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
    return MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    );
  }

  CustomPaint findPaint(WidgetTester tester, Object painterType) {
    return tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter.runtimeType == painterType,
      ),
    );
  }

  List<double?> barFactors(WidgetTester tester) => tester
      .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
      .map((box) => box.heightFactor)
      .toList();

  group('T-3 BrandChart contract (L26)', () {
    testWidgets('empty series renders the library EmptyStateWidget for every '
        'kind — never a fake axis', (tester) async {
      for (final kind in BrandChartKind.values) {
        await tester.pumpWidget(wrap(chart(kind, const [])));
        await tester.pumpAndSettle();

        expect(find.byType(EmptyStateWidget), findsOneWidget, reason: '$kind');
        expect(find.text('No revenue yet'), findsOneWidget);
        expect(find.text('A chart appears once data lands'), findsOneWidget);
        expect(
          tester.widgetList<CustomPaint>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  (widget.painter is BrandChartLinePainter ||
                      widget.painter is BrandChartDonutPainter),
            ),
          ),
          isEmpty,
          reason: 'no axis/painter is painted for an empty series',
        );
      }
    });

    testWidgets('bars: one bar per point, scaled against the max value', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(chart(BrandChartKind.bars, three())));
      await tester.pumpAndSettle();

      final factors = barFactors(tester);
      expect(factors, hasLength(3));
      expect(factors[0], 0.0, reason: 'zero value => zero-height bar');
      expect(factors[1], 0.5);
      expect(factors[2], 1.0, reason: 'max value fills the plot');
      expect(tester.takeException(), isNull);
    });

    testWidgets('single point: bars fill without dividing by zero; no NaN on '
        'screen', (tester) async {
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.bars, const [
            BrandChartPoint(label: 'Only', value: 42),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(barFactors(tester), [1.0]);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });
    testWidgets('extreme values: 0 and 1e9 side by side stay finite; an '
        'all-zero series renders flat bars', (tester) async {
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.bars, const [
            BrandChartPoint(label: 'Low', value: 0),
            BrandChartPoint(label: 'High', value: 1000000000),
            BrandChartPoint(label: 'Neg', value: -50),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final factors = barFactors(tester);
      expect(factors, everyElement(isNotNull));
      expect(factors.every((f) => f != null && f.isFinite), isTrue);
      expect(factors, [0.0, 1.0, 0.0], reason: 'negatives clamp to zero');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.bars, const [
            BrandChartPoint(label: 'A', value: 0),
            BrandChartPoint(label: 'B', value: 0),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(barFactors(tester), [
        0.0,
        0.0,
      ], reason: 'no NaN when every value is zero');
      expect(tester.takeException(), isNull);
    });

    testWidgets('line: a single point plots at the centre with finite '
        'coordinates (the divide-by-zero guard)', (tester) async {
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.line, const [
            BrandChartPoint(label: 'Only', value: 500),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final painter =
          findPaint(tester, BrandChartLinePainter).painter!
              as BrandChartLinePainter;
      final offsets = painter.plot(const Size(100, 50));
      expect(offsets, hasLength(1));
      expect(offsets.single.dx, 50.0, reason: 'centred, not divided by n-1');
      expect(offsets.single.dy.isFinite, isTrue);
      expect(offsets.single.dy, 0.0, reason: 'single point = full height');
    });

    testWidgets('line: multi-point spacing is strictly linear — vertices sit '
        'on the straight segment', (tester) async {
      await tester.pumpWidget(wrap(chart(BrandChartKind.line, three())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final painter =
          findPaint(tester, BrandChartLinePainter).painter!
              as BrandChartLinePainter;
      final offsets = painter.plot(const Size(100, 50));

      expect(offsets.map((o) => o.dx), [0.0, 50.0, 100.0]);
      expect(offsets.map((o) => o.dy), [50.0, 25.0, 0.0]);
      // A spline would bow away from the straight-segment midpoint.
      expect(Offset.lerp(offsets[0], offsets[1], 0.5)!.dy, 37.5);

      // Re-pump with different data so the painter's update path runs too.
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.line, const [
            BrandChartPoint(label: 'X', value: 10),
            BrandChartPoint(label: 'Y', value: 20),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('line: an all-zero series plots without NaN', (tester) async {
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.line, const [
            BrandChartPoint(label: 'A', value: 0),
            BrandChartPoint(label: 'B', value: 0),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final painter =
          findPaint(tester, BrandChartLinePainter).painter!
              as BrandChartLinePainter;
      final offsets = painter.plot(const Size(100, 50));
      expect(offsets.map((o) => o.dy), [50.0, 50.0]);
      expect(offsets.every((o) => o.dx.isFinite && o.dy.isFinite), isTrue);
    });
    test('no implied interpolation: the source draws no splines', () {
      final source = File('lib/src/ui/brand_chart.dart').readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final token in <String>[
        'cubicTo',
        'quadraticBezierTo',
        'conicTo',
        'smooth',
      ]) {
        expect(
          code.contains(token),
          isFalse,
          reason: 'brand_chart.dart must not interpolate ($token found)',
        );
      }
    });

    test('donut fractions: single point fills the ring, zeros split evenly, '
        'negatives clamp (no divide-by-zero)', () {
      BrandChartDonutPainter painter(List<BrandChartPoint> points) {
        return BrandChartDonutPainter(
          points: points,
          colors: const [Colors.red],
        );
      }

      final single = painter(const [
        BrandChartPoint(label: 'Only', value: 7),
      ]).fractions();
      expect(single, [1.0]);

      final zeros = painter(const [
        BrandChartPoint(label: 'A', value: 0),
        BrandChartPoint(label: 'B', value: 0),
        BrandChartPoint(label: 'C', value: 0),
      ]).fractions();
      expect(zeros, everyElement(closeTo(1 / 3, 1e-9)));

      final mixed = painter(const [
        BrandChartPoint(label: 'A', value: -10),
        BrandChartPoint(label: 'B', value: 30),
        BrandChartPoint(label: 'C', value: 70),
      ]).fractions();
      expect(mixed[0], 0.0, reason: 'negative clamped to zero');
      expect(mixed[1], closeTo(0.3, 1e-9));
      expect(mixed[2], closeTo(0.7, 1e-9));
      expect(mixed.fold<double>(0, (sum, f) => sum + f), closeTo(1.0, 1e-9));
    });

    testWidgets('donut renders with brand-token colours only (L1)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(chart(BrandChartKind.donut, three())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final painter =
          findPaint(tester, BrandChartDonutPainter).painter!
              as BrandChartDonutPainter;
      const brand = BrandColors.fallback();
      expect(painter.colors, [brand.primary, brand.secondary, brand.accent]);

      // Re-pump with different data so the painter's update path runs too.
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.donut, const [
            BrandChartPoint(label: 'A', value: 1),
            BrandChartPoint(label: 'B', value: 2),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels truncate with an ellipsis instead of overflowing', (
      tester,
    ) async {
      const longLabel = 'A very long bucket label that cannot possibly fit';
      await tester.pumpWidget(
        wrap(
          chart(BrandChartKind.bars, const [
            BrandChartPoint(label: longLabel, value: 10),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(find.text(longLabel));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL mirrors the bar order (first bucket right-most)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(chart(BrandChartKind.bars, three()), direction: TextDirection.rtl),
      );
      await tester.pumpAndSettle();

      final first = tester.getCenter(find.text('Mon')).dx;
      final last = tester.getCenter(find.text('Wed')).dx;
      expect(first, greaterThan(last));
    });

    testWidgets('legend is optional: off renders labels once, on renders a '
        'second dot+label entry per point', (tester) async {
      await tester.pumpWidget(wrap(chart(BrandChartKind.bars, three())));
      await tester.pumpAndSettle();
      expect(find.text('Mon'), findsOneWidget);

      await tester.pumpWidget(
        wrap(chart(BrandChartKind.bars, three(), showLegend: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mon'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('caller-supplied title renders; omitted title adds nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(chart(BrandChartKind.bars, three(), title: 'Revenue by day')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Revenue by day'), findsOneWidget);

      await tester.pumpWidget(wrap(chart(BrandChartKind.bars, three())));
      await tester.pumpAndSettle();
      expect(find.text('Revenue by day'), findsNothing);
    });

    testWidgets('golden: bars (light, en) with title', (tester) async {
      tester.view.physicalSize = const Size(400, 280);
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
                child: BrandChart(
                  kind: BrandChartKind.bars,
                  title: 'Revenue by day',
                  emptyTitle: 'No revenue yet',
                  emptySubtitle: 'A chart appears once data lands',
                  showLegend: true,
                  points: <BrandChartPoint>[
                    BrandChartPoint(label: 'Mon', value: 0),
                    BrandChartPoint(label: 'Tue', value: 500),
                    BrandChartPoint(label: 'Wed', value: 1000),
                    BrandChartPoint(label: 'Thu', value: 750),
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
        matchesGoldenFile('goldens/brand_chart_bars_en.png'),
      );
    });

    testWidgets('golden: donut (light, ar, RTL) with legend', (tester) async {
      tester.view.physicalSize = const Size(400, 280);
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
                child: BrandChart(
                  kind: BrandChartKind.donut,
                  title: 'مبيعات الأسبوع',
                  emptyTitle: 'لا توجد بيانات',
                  emptySubtitle: 'يظهر المخطط بعد وصول البيانات',
                  showLegend: true,
                  points: <BrandChartPoint>[
                    BrandChartPoint(label: 'طعام', value: 1200),
                    BrandChartPoint(label: 'مشروبات', value: 600),
                    BrandChartPoint(label: 'حلويات', value: 300),
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
        matchesGoldenFile('goldens/brand_chart_donut_rtl_ar.png'),
      );
    });
  });
}
