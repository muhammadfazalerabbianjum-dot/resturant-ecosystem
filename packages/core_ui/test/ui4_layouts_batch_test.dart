import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-4 (p14) — layouts batch, written to the WHITE_LABEL_p14_ui4_layouts.md
/// §3 T-1..T-5 contract. Real behavior tests on real production code: no
/// skips, no vacuous assertions, no goldens. Layout primitives compose plain
/// widgets + theme/token reads only (rule 0.10) — no p12/p13 imports.
void main() {
  group('T-1 AppBreakpoints + ResponsiveBuilder — pure breakpoint algebra', () {
    test('exact bounds: compact < 600 <= medium < 1024 <= expanded', () {
      expect(AppBreakpoints.compact, 600);
      expect(AppBreakpoints.medium, 1024);

      // Exact asserted bounds — 599/600 and 1023/1024.
      expect(AppBreakpoints.laneFor(599), ResponsiveLane.compact);
      expect(AppBreakpoints.laneFor(600), ResponsiveLane.medium);
      expect(AppBreakpoints.laneFor(1023), ResponsiveLane.medium);
      expect(AppBreakpoints.laneFor(1024), ResponsiveLane.expanded);
    });

    testWidgets(
      'ResponsiveBuilder rebuilds on width crossing via LayoutBuilder, '
      'calls the right lane, returns childOf result',
      (tester) async {
        ResponsiveLane? seenLane;
        Widget build(double width) {
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          return MaterialApp(
            home: ResponsiveBuilder(
              builder: (context, lane) {
                seenLane = lane;
                return Text(lane.name);
              },
            ),
          );
        }

        await tester.pumpWidget(build(500));
        expect(seenLane, ResponsiveLane.compact);
        expect(find.text('compact'), findsOneWidget);

        // Crossing into medium rebuilds via LayoutBuilder.
        await tester.pumpWidget(build(700));
        expect(seenLane, ResponsiveLane.medium);
        expect(find.text('medium'), findsOneWidget);

        // Crossing into expanded rebuilds.
        await tester.pumpWidget(build(1200));
        expect(seenLane, ResponsiveLane.expanded);
        expect(find.text('expanded'), findsOneWidget);
      },
    );

    testWidgets('builder result is the ONLY child — no wrappers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 600)),
            child: ResponsiveBuilder(
              builder: (context, lane) => const KeyedSubtree(
                key: Key('result'),
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      // The builder's widget is returned directly from the LayoutBuilder
      // callback — no extra wrapper layers in between.
      final layoutBuilder = tester.widget<LayoutBuilder>(
        find.byType(LayoutBuilder),
      );
      final layout = layoutBuilder.builder(
        tester.element(find.byType(LayoutBuilder)),
        BoxConstraints.tight(const Size(400, 600)),
      );
      final sub = layout as KeyedSubtree;
      expect(sub.key, const Key('result'));
    });
  });

  group('T-2 ScreenScaffold — composition', () {
    testWidgets('SafeArea + ScaffoldBackground + body always rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenScaffold(
            body: KeyedSubtree(key: Key('body'), child: Text('body')),
          ),
        ),
      );
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(ScaffoldBackground), findsOneWidget);
      expect(find.byKey(const Key('body')), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('default maxContentWidth 640 centers and constrains body', (
      tester,
    ) async {
      double? maxWidth;
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ScreenScaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                maxWidth = constraints.maxWidth;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // The body is laid out within the constrained width, not the raw 1000.
      expect(maxWidth, 640);
      // Centered.
      final bodyCenter = tester.getCenter(find.byType(LayoutBuilder));
      expect(bodyCenter.dx, closeTo(500, 0.5));
    });

    testWidgets('null maxContentWidth = unconstrained', (tester) async {
      double? maxWidth;
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ScreenScaffold(
            maxContentWidth: null,
            body: LayoutBuilder(
              builder: (context, constraints) {
                maxWidth = constraints.maxWidth;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(maxWidth, 1000);
    });
    testWidgets('custom maxContentWidth honored', (tester) async {
      double? maxWidth;
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ScreenScaffold(
            maxContentWidth: 300,
            body: LayoutBuilder(
              builder: (context, constraints) {
                maxWidth = constraints.maxWidth;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(maxWidth, 300);
    });

    testWidgets('bottom nav slot passthrough renders the caller widget', (
      tester,
    ) async {
      const nav = KeyedSubtree(key: Key('nav'), child: Text('nav'));
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenScaffold(bottomNav: nav, body: Text('body')),
        ),
      );
      expect(find.byKey(const Key('nav')), findsOneWidget);
      expect(find.text('nav'), findsOneWidget);
      // It is wired into the Scaffold's bottomNavigationBar slot.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, same(nav));
    });
  });

  group('T-3 SectionHeader — pure layout, caller-supplied strings (L3)', () {
    testWidgets('title bold (w700) + action right-aligned', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Menu',
              action: KeyedSubtree(key: Key('action'), child: Text('See all')),
            ),
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Menu'));
      expect(title.style?.fontWeight, FontWeight.w700);
      // Action widget present and laid out to the right of the title.
      expect(find.byKey(const Key('action')), findsOneWidget);
      final titleX = tester.getTopLeft(find.text('Menu')).dx;
      final actionX = tester.getTopLeft(find.byKey(const Key('action'))).dx;
      expect(actionX, greaterThan(titleX));
    });

    testWidgets('optional subtitle renders secondary-colored', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              onSurfaceVariant: Color(0xFF123456),
            ),
          ),
          home: const Scaffold(
            body: SectionHeader(title: 'T', subtitle: 'S'),
          ),
        ),
      );
      final sub = tester.widget<Text>(find.text('S'));
      expect(sub.style?.color, const Color(0xFF123456));
    });

    testWidgets('overlong title ellipsized', (tester) async {
      const long = 'A very long title that certainly will not fit in one line';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 120, child: SectionHeader(title: long)),
          ),
        ),
      );
      final title = tester.widget<Text>(find.text(long));
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.maxLines, 1);
    });
  });
  group('T-4 AdaptiveRow — compact Column, medium/expanded Row', () {
    Future<void> pump(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveRow(
              spacing: 12,
              children: [Text('a'), Text('b'), Text('c')],
            ),
          ),
        ),
      );
    }

    testWidgets('compact -> Column with spacing between children', (
      tester,
    ) async {
      await pump(tester, 500);
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Row), findsNothing);
      // Order preserved.
      expect(
        tester.getTopLeft(find.text('a')).dy,
        lessThan(tester.getTopLeft(find.text('b')).dy),
      );
      expect(
        tester.getTopLeft(find.text('b')).dy,
        lessThan(tester.getTopLeft(find.text('c')).dy),
      );
      // Spacing between children: exactly 2 spacers of 12.
      final gaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(Column),
              matching: find.byType(SizedBox),
            ),
          )
          .where((s) => s.width == null && s.height == 12)
          .length;
      expect(gaps, 2);
    });

    testWidgets('medium -> Row with spacing between children', (tester) async {
      await pump(tester, 700);
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsNothing);
      // Order preserved left-to-right.
      expect(
        tester.getTopLeft(find.text('a')).dx,
        lessThan(tester.getTopLeft(find.text('b')).dx),
      );
      expect(
        tester.getTopLeft(find.text('b')).dx,
        lessThan(tester.getTopLeft(find.text('c')).dx),
      );
      final gaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(Row),
              matching: find.byType(SizedBox),
            ),
          )
          .where((s) => s.width == 12 && s.height == null)
          .length;
      expect(gaps, 2);
    });

    testWidgets('expanded -> Row (same as medium)', (tester) async {
      await pump(tester, 1200);
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets(
      'breakpoint flips from the ambient width via ResponsiveBuilder, '
      'not MediaQuery hacks',
      (tester) async {
        // Assert the flip point mechanically: same tree, widths straddling 600.
        await pump(tester, 599);
        expect(find.byType(Column), findsOneWidget);
        await pump(tester, 600);
        expect(find.byType(Row), findsOneWidget);
        // And the implementation builds on ResponsiveBuilder.
        expect(find.byType(ResponsiveBuilder), findsOneWidget);
      },
    );
  });

  group('T-5 Gap — constants + parameterized', () {
    test('h-constants delegate SizedBox with exact extents', () {
      expect(Gap.h8.width, 8);
      expect(Gap.h8.height, isNull);
      expect(Gap.h16.width, 16);
      expect(Gap.h16.height, isNull);
      expect(Gap.h24.width, 24);
      expect(Gap.h24.height, isNull);
      // Token parity.
      expect(Gap.h8.width, AppDimensions.paddingS);
      expect(Gap.h16.width, AppDimensions.paddingM);
    });

    test('v-constants delegate SizedBox with exact extents', () {
      expect(Gap.v8.width, isNull);
      expect(Gap.v8.height, 8);
      expect(Gap.v16.width, isNull);
      expect(Gap.v16.height, 16);
      expect(Gap.v24.width, isNull);
      expect(Gap.v24.height, 24);
    });

    test('parameterized Gap.h(n)/Gap.v(n)', () {
      final h = Gap.h(40);
      expect(h.width, 40);
      expect(h.height, isNull);
      final v = Gap.v(40);
      expect(v.width, isNull);
      expect(v.height, 40);
    });

    testWidgets('Gap renders as a SizedBox with the exact extent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(children: [Gap.h8, Gap.v16, const Text('x')]),
          ),
        ),
      );
      final h = tester.getSize(find.byWidget(Gap.h8));
      expect(h.width, 8);
      expect(h.height, 0);
      final v = tester.getSize(find.byWidget(Gap.v16));
      expect(v.width, 0);
      expect(v.height, 16);
    });
  });

  group('runtime construction (coverage of generative constructors)', () {
    testWidgets('AdaptiveRow constructed non-const with all params', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        // Deliberately non-const: this test exercises the generative
        // (runtime) constructor path that 100% line coverage requires.
        // ignore: prefer_const_constructors
        MaterialApp(
          // ignore: prefer_const_constructors
          home: Scaffold(
            // ignore: prefer_const_constructors
            body: AdaptiveRow(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('p'), Text('q')],
            ),
          ),
        ),
      );
      expect(find.byType(Row), findsOneWidget);
      expect(find.text('p'), findsOneWidget);
      expect(find.text('q'), findsOneWidget);
    });

    testWidgets('SectionHeader constructed non-const with all params', (
      tester,
    ) async {
      await tester.pumpWidget(
        // Deliberately non-const: this test exercises the generative
        // (runtime) constructor path that 100% line coverage requires.
        // ignore: prefer_const_constructors
        MaterialApp(
          // ignore: prefer_const_constructors
          home: Scaffold(
            // ignore: prefer_const_constructors
            body: SectionHeader(
              subtitle: 'Sub',
              action: const Text('Act'),
              title: 'Runtime',
            ),
          ),
        ),
      );
      expect(find.text('Runtime'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('Act'), findsOneWidget);
    });
  });
}
