// UI-2 (p12) motion batch contract suite — T-1..T-6 (WHITE_LABEL_p12_ui2_motion.md §3).
// Deterministic: explicit pump() steps against AppMotionTokens durations only (L8).
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget host(
  Widget child, {
  AppMotionStyle style = AppMotionStyle.full,
  AppMotionTokens? tokens,
  bool withTokens = true,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    extensions: withTokens
        ? {tokens ?? AppMotionTokens.forStyle(style)}
        : <ThemeExtension<dynamic>>{},
  ),
  home: Scaffold(body: Center(child: child)),
);

/// The *target* scale handed to [AnimatedScale] (the widget property holds the
/// target, not the animated value).
AnimatedScale scaleOf(WidgetTester tester) => tester.widget<AnimatedScale>(
  find.descendant(
    of: find.byType(PressableScale),
    matching: find.byType(AnimatedScale),
  ),
);

/// The *rendered* scale: the implicit animation's current value, read off the
/// transform matrix [ScaleTransition] builds (L8 — no target shortcuts).
double renderedScale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(AnimatedScale),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .entry(0, 0);

void main() {
  group('T-1 PressableScale', () {
    testWidgets(
      'press animates to 0.96 over motion.fast; release returns to 1.0; tap fires once',
      (tester) async {
        final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
        var taps = 0;
        await tester.pumpWidget(
          host(PressableScale(onTap: () => taps++, child: const Text('press'))),
        );
        await tester.pump(const Duration(milliseconds: 1));
        final gesture = await tester.press(find.text('press'));
        await tester.pump();
        await tester.pump(motion.fast);
        expect(scaleOf(tester).scale, 0.96);
        // The rendered transform really completed the press tick.
        expect(renderedScale(tester), closeTo(0.96, 1e-9));
        await gesture.up();
        await tester.pump();
        expect(taps, 1);
        await tester.pump(motion.fast);
        expect(renderedScale(tester), closeTo(1.0, 1e-9));
        // Pure transform wrapper (L7): no haptics-producing surface of its own.
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets('style: none → no AnimatedScale churn, tap still fires', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PressableScale(onTap: () => taps++, child: const Text('press')),
          style: AppMotionStyle.none,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.text('press'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AnimatedScale), findsNothing);
      expect(taps, 1);
    });

    testWidgets('style: subtle completes on the subtle fast (120ms)', (
      tester,
    ) async {
      final subtle = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      var taps = 0;
      await tester.pumpWidget(
        host(
          PressableScale(onTap: () => taps++, child: const Text('press')),
          style: AppMotionStyle.subtle,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final gesture = await tester.press(find.text('press'));
      await tester.pump();
      await tester.pump(subtle.fast);
      expect(scaleOf(tester).scale, 0.96);
      expect(renderedScale(tester), closeTo(0.96, 1e-9));
      await gesture.up();
      await tester.pump();
      await tester.pump(subtle.fast);
      expect(renderedScale(tester), closeTo(1.0, 1e-9));
      expect(taps, 1);
    });

    testWidgets('mid-press frame is strictly between 1.0 and 0.96', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(PressableScale(onTap: () {}, child: const Text('press'))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final gesture = await tester.press(find.text('press'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // half of fast=200
      final mid = renderedScale(tester);
      expect(mid, lessThan(1.0));
      expect(mid, greaterThan(0.96));
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('pointer cancel returns to 1.0 without firing onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PressableScale(onTap: () => taps++, child: const Text('press'))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final gesture = await tester.press(find.text('press'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester).scale, 0.96);
      expect(renderedScale(tester), closeTo(0.96, 1e-9));
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester).scale, 1.0);
      expect(renderedScale(tester), closeTo(1.0, 1e-9));
      expect(taps, 0);
    });

    testWidgets('onTap null → no crash, no transform residue', (tester) async {
      await tester.pumpWidget(host(const PressableScale(child: Text('press'))));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.text('press'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester).scale, 1.0);
      expect(renderedScale(tester), closeTo(1.0, 1e-9));
    });

    testWidgets('two tap cycles fire onTap exactly twice', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PressableScale(onTap: () => taps++, child: const Text('press'))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.text('press'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('press'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 2);
    });

    testWidgets('child semantics untouched (pure transform wrapper)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(PressableScale(onTap: () => taps++, child: const Text('press'))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.bySemanticsLabel('press'), findsOneWidget);
      await tester.tap(find.text('press'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      expect(find.bySemanticsLabel('press'), findsOneWidget);
      semantics.dispose();
    });
    testWidgets(
      'missing tokens (no extension) → no churn, tap still fires (L5)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          host(
            PressableScale(onTap: () => taps++, child: const Text('press')),
            withTokens: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(AnimatedScale), findsNothing);
        final gesture = await tester.press(find.text('press'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // No transform was ever applied (scoped to the wrapper: MaterialApp's
        // own chrome contains unrelated Transforms), and the press still
        // resolves.
        expect(
          find.descendant(
            of: find.byType(PressableScale),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        await gesture.up();
        await tester.pump();
        expect(taps, 1);
      },
    );
  });

  group('T-2 FadeSlideIn', () {
    testWidgets(
      'entrance: opacity 0→1 and slide Offset(0, 0.05)→zero over motion.standard',
      (tester) async {
        final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
        await tester.pumpWidget(host(const FadeSlideIn(child: Text('hi'))));
        final root = find.byType(FadeSlideIn);
        final fade = tester.widget<FadeTransition>(
          find
              .descendant(of: root, matching: find.byType(FadeTransition))
              .first,
        );
        expect(fade.opacity.value, 0.0);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(motion.standard);
        expect(fade.opacity.value, 1.0);
        final slide = tester.widget<SlideTransition>(
          find
              .descendant(of: root, matching: find.byType(SlideTransition))
              .first,
        );
        expect(slide.position.value, Offset.zero);
      },
    );

    testWidgets('mid-entrance frame: opacity in (0,1), offset in (0, 0.05)', (
      tester,
    ) async {
      await tester.pumpWidget(host(const FadeSlideIn(child: Text('hi'))));
      final root = find.byType(FadeSlideIn);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 150)); // half of 300
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: root, matching: find.byType(FadeTransition)).first,
      );
      final slide = tester.widget<SlideTransition>(
        find.descendant(of: root, matching: find.byType(SlideTransition)).first,
      );
      expect(fade.opacity.value, greaterThan(0.0));
      expect(fade.opacity.value, lessThan(1.0));
      expect(slide.position.value.dy, greaterThan(0.0));
      expect(slide.position.value.dy, lessThan(0.05));
      await tester.pump(const Duration(milliseconds: 300));
      // No overlay/opacity residue after settle.
      expect(fade.opacity.value, 1.0);
      expect(slide.position.value, Offset.zero);
    });

    testWidgets('style: none → final state rendered immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FadeSlideIn(child: Text('hi')), style: AppMotionStyle.none),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final root = find.byType(FadeSlideIn);
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: root, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1.0);
      final slide = tester.widget<SlideTransition>(
        find.descendant(of: root, matching: find.byType(SlideTransition)).first,
      );
      expect(slide.position.value, Offset.zero);
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('style: subtle settles on subtle standard (200ms)', (
      tester,
    ) async {
      final subtle = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      await tester.pumpWidget(
        host(
          const FadeSlideIn(child: Text('hi')),
          style: AppMotionStyle.subtle,
        ),
      );
      final root = find.byType(FadeSlideIn);
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: root, matching: find.byType(FadeTransition)).first,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(subtle.standard - const Duration(milliseconds: 50));
      expect(fade.opacity.value, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('missing tokens (no extension) → degrade to final state (L5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FadeSlideIn(child: Text('hi')), withTokens: false),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final root = find.byType(FadeSlideIn);
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: root, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1.0);
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('non-const construction (runtime child) enters and settles', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      final label = 'runtime-${motion.standard.inMilliseconds}';
      await tester.pumpWidget(host(FadeSlideIn(child: Text(label))));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(label), findsOneWidget);
      await tester.pump(motion.standard);
      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(FadeSlideIn),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1.0);
    });
  });

  group('T-3 StaggeredEntrance', () {
    testWidgets('children enter with per-index 60ms delay, order preserved', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      const stagger = Duration(milliseconds: 60);
      await tester.pumpWidget(
        host(
          const StaggeredEntrance(children: [Text('a'), Text('b'), Text('c')]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(motion.standard + stagger);
      final opacities = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(StaggeredEntrance),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      expect(opacities.length, 3);
      // Order preserved: earlier indices settle no later than later ones.
      expect(opacities[0].opacity.value, 1.0);
      expect(opacities[1].opacity.value, 1.0);
      expect(opacities[2].opacity.value, lessThan(1.0));
      await tester.pump(stagger * 2);
      expect(opacities[2].opacity.value, 1.0);
      expect(opacities[1].opacity.value, 1.0);
      expect(opacities[0].opacity.value, 1.0);
    });

    testWidgets('custom stagger delay is honored', (tester) async {
      const stagger = Duration(milliseconds: 200);
      await tester.pumpWidget(
        host(
          const StaggeredEntrance(
            stagger: stagger,
            children: [Text('a'), Text('b')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      final opacities = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(StaggeredEntrance),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      expect(opacities[0].opacity.value, 1.0);
      expect(opacities[1].opacity.value, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacities[1].opacity.value, 1.0);
    });

    testWidgets('style: none → all children final state immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StaggeredEntrance(children: [Text('a'), Text('b'), Text('c')]),
          style: AppMotionStyle.none,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      for (final t in ['a', 'b', 'c']) {
        expect(find.text(t), findsOneWidget);
      }
      final opacities = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(StaggeredEntrance),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      for (final o in opacities) {
        expect(o.opacity.value, 1.0);
      }
    });

    testWidgets('single child behaves as a plain FadeSlideIn', (tester) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      await tester.pumpWidget(
        host(const StaggeredEntrance(children: [Text('only')])),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(motion.standard);
      final opacities = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(StaggeredEntrance),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      expect(opacities, hasLength(1));
      expect(opacities[0].opacity.value, 1.0);
    });

    testWidgets('missing tokens → degrade to final state (L5)', (tester) async {
      await tester.pumpWidget(
        host(
          const StaggeredEntrance(children: [Text('a'), Text('b')]),
          withTokens: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('non-const construction (runtime child list) preserves order', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      final labels = ['r1', 'r2'];
      await tester.pumpWidget(
        host(StaggeredEntrance(children: [for (final l in labels) Text(l)])),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('r1'), findsOneWidget);
      expect(find.text('r2'), findsOneWidget);
      await tester.pump(motion.standard + motion.standard);
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(rendered, labels);
    });
  });

  group('T-4 AnimatedCountText', () {
    testWidgets('animates previous→new over motion.standard via moneyCents', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      await tester.pumpWidget(
        host(
          const AnimatedCountText(
            1000,
            style: TextStyle(fontSize: 20),
            currencyCode: 'USD',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(moneyCents(1000, currencyCode: 'USD')), findsOneWidget);
      // Identical value → no re-animation.
      await tester.pumpWidget(
        host(
          const AnimatedCountText(
            1000,
            style: TextStyle(fontSize: 20),
            currencyCode: 'USD',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(moneyCents(1000, currencyCode: 'USD')), findsOneWidget);
      // Change to 2500 → tween over standard.
      await tester.pumpWidget(
        host(
          const AnimatedCountText(
            2500,
            style: TextStyle(fontSize: 20),
            currencyCode: 'USD',
          ),
        ),
      );
      await tester.pump(motion.standard ~/ 2);
      final mid = tester.widget<Text>(
        find.descendant(
          of: find.byType(AnimatedCountText),
          matching: find.byType(Text),
        ),
      );
      final parsed = int.parse(mid.data!.replaceAll(RegExp(r'[^0-9]'), ''));
      expect(parsed, greaterThan(1000));
      expect(parsed, lessThan(2500));
      // Every frame is moneyCents-formatted (L2).
      expect(mid.data, moneyCents(parsed, currencyCode: 'USD'));
      await tester.pump(motion.standard);
      expect(find.text(moneyCents(2500, currencyCode: 'USD')), findsOneWidget);
    });

    testWidgets('currency config forwarded: EUR code + custom symbol', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AnimatedCountText(
            500,
            style: TextStyle(fontSize: 20),
            currencyCode: 'EUR',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(moneyCents(500, currencyCode: 'EUR')), findsOneWidget);
      await tester.pumpWidget(
        host(
          const AnimatedCountText(
            500,
            style: TextStyle(fontSize: 20),
            currencyCode: 'XXY',
            currencySymbol: '#',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.text(moneyCents(500, currencyCode: 'XXY', currencySymbol: '#')),
        findsOneWidget,
      );
    });

    testWidgets('style: none → jumps to the new value (L6/L8)', (tester) async {
      await tester.pumpWidget(
        host(
          const AnimatedCountText(1000, style: TextStyle(fontSize: 20)),
          style: AppMotionStyle.none,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(
        host(
          const AnimatedCountText(2500, style: TextStyle(fontSize: 20)),
          style: AppMotionStyle.none,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(moneyCents(2500)), findsOneWidget);
      // And it holds: no animation trails behind.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(moneyCents(2500)), findsOneWidget);
    });

    testWidgets('non-const construction (runtime value) lands formatted', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      final start = 600 + motion.standard.inMilliseconds; // 900
      await tester.pumpWidget(
        host(AnimatedCountText(start, style: const TextStyle(fontSize: 20))),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(moneyCents(start)), findsOneWidget);
      final target = start + 100;
      await tester.pumpWidget(
        host(AnimatedCountText(target, style: const TextStyle(fontSize: 20))),
      );
      await tester.pump(motion.standard);
      expect(find.text(moneyCents(target)), findsOneWidget);
    });

    testWidgets('missing tokens → shows the value formatted (L5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AnimatedCountText(750, style: TextStyle(fontSize: 20)),
          withTokens: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(moneyCents(750)), findsOneWidget);
    });
  });

  group('T-5 AnimatedVisibility', () {
    Widget body(
      bool visible, {
      AppMotionStyle style = AppMotionStyle.full,
      bool withTokens = true,
    }) => host(
      AnimatedVisibility(
        visible: visible,
        child: ElevatedButton(onPressed: () {}, child: const Text('btn')),
      ),
      style: style,
      withTokens: withTokens,
    );

    testWidgets('visible=false fades out over standard, then offstage', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.full);
      await tester.pumpWidget(body(true));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(body(false));
      await tester.pump(motion.standard);
      await tester.pump(motion.standard);
      // Hidden content findable only with skipOffstage: false.
      expect(find.text('btn'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Offstage && w.offstage,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hidden content is never interactive', (tester) async {
      var taps = 0;
      final b = host(
        AnimatedVisibility(
          visible: false,
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('btn'),
          ),
        ),
      );
      await tester.pumpWidget(b);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // Still in the tree (offstage), but invisible to the active tree...
      final hidden = find.text('btn', skipOffstage: false);
      expect(hidden, findsOneWidget);
      expect(find.text('btn'), findsNothing);
      // ...and never hit-testable: the offstage gate refuses the hit (P1 —
      // `RenderOffstage.hitTest` returns `!offstage && ...`).
      expect(hidden.hitTestable(), findsNothing);
      await tester.tap(hidden, warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('style: none → instant hide, offstage immediately', (
      tester,
    ) async {
      await tester.pumpWidget(body(true, style: AppMotionStyle.none));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(body(false, style: AppMotionStyle.none));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('btn'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Offstage && w.offstage,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('re-visible after hidden restores interactivity', (
      tester,
    ) async {
      var taps = 0;
      Widget b(bool visible) => host(
        AnimatedVisibility(
          visible: visible,
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('btn'),
          ),
        ),
      );
      await tester.pumpWidget(b(false));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(b(true));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('btn'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsNothing,
      );
      await tester.tap(find.text('btn'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('fade-out frame has opacity strictly between 0 and 1', (
      tester,
    ) async {
      await tester.pumpWidget(body(true));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(body(false));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 150));
      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(AnimatedVisibility),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0.0));
      expect(fade.opacity.value, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('missing tokens → degrade to visible state (L5)', (
      tester,
    ) async {
      await tester.pumpWidget(body(true, withTokens: false));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('btn'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsNothing,
      );
    });
  });

  group('T-6 FadeSlideTransitionPage motion seam', () {
    /// Drives [page]'s transitionsBuilder at t=0.5 and returns the rendered
    /// (opacity, slideOffset) so curve + begin-offset identity is asserted.
    Future<(double, Offset)> probeAtHalf(
      WidgetTester tester,
      Page<Object?> page,
    ) async {
      final asCustom = page as CustomTransitionPage<Object?>;
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      final proxy = Animation.fromValueListenable(controller);
      await tester.pumpWidget(
        Builder(
          builder: (context) => asCustom.transitionsBuilder(
            context,
            proxy,
            proxy,
            const SizedBox(key: ValueKey('child'), width: 10, height: 10),
          ),
        ),
      );
      final fade = tester.widget<FadeTransition>(
        find.byWidgetPredicate((w) => w is FadeTransition),
      );
      final slide = tester.widget<SlideTransition>(
        find.byWidgetPredicate((w) => w is SlideTransition),
      );
      final rendered = (fade.opacity.value, slide.position.value);
      controller.dispose();
      return rendered;
    }

    /// Pumps a single-route GoRouter and returns the LIVE route, captured
    /// through `ModalRoute.of` inside the page's child (L8: no observer
    /// ordering / `Page`-cast assumptions).
    Future<ModalRoute<Object?>> liveRoute(
      WidgetTester tester, {
      AppMotionTokens? motion,
    }) async {
      ModalRoute<Object?>? captured;
      final router = GoRouter(
        initialLocation: '/x',
        routes: <RouteBase>[
          GoRoute(
            path: '/x',
            name: 'x',
            pageBuilder: (context, state) => FadeSlideTransitionPage(
              key: const ValueKey('p'),
              motion: motion,
              child: Builder(
                builder: (context) {
                  captured = ModalRoute.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 1));
      expect(captured, isNotNull);
      return captured!;
    }

    /// Pushes a SECOND route through the same router and returns the live
    /// destination route. The *initial* route is completed by [Navigator]
    /// before its first tick (no animation frame), so the motion window can
    /// only be observed on a real push (L8 — explicit pumps, no wall clock).
    Future<ModalRoute<Object?>> pushedRoute(
      WidgetTester tester, {
      AppMotionTokens? motion,
    }) async {
      ModalRoute<Object?>? captured;
      final router = GoRouter(
        initialLocation: '/a',
        routes: <RouteBase>[
          GoRoute(
            path: '/a',
            name: 'a',
            pageBuilder: (context, state) => FadeSlideTransitionPage(
              key: const ValueKey('a'),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.go('/b'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/b',
            name: 'b',
            pageBuilder: (context, state) => FadeSlideTransitionPage(
              key: const ValueKey('b'),
              motion: motion,
              child: Builder(
                builder: (context) {
                  captured = ModalRoute.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(captured, isNotNull);
      return captured!;
    }

    testWidgets(
      'omitted motion → legacy default: 300ms, easeOut curve, Offset(0, 0.05)',
      (tester) async {
        final route = await liveRoute(tester);
        expect(route.transitionDuration, const Duration(milliseconds: 300));
        // Curve + begin-offset identity against the legacy constants.
        final legacyPage = FadeSlideTransitionPage<Object?>(
          key: const ValueKey('probe'),
          child: const SizedBox.shrink(),
        );
        final (opacity, offset) = await probeAtHalf(tester, legacyPage);
        final t = Curves.easeOut.transform(0.5);
        expect(opacity, 0.5);
        // Offset.lerp computes `0.05 - 0.05 * t`, this expectation computes
        // `0.05 * (1 - t)` — mathematically identical, 1 ulp apart, so the
        // identity is asserted at 1e-12 (a wrong curve/begin is off by ≫).
        expect(offset.dx, 0.0);
        expect(offset.dy, closeTo(0.05 * (1 - t), 1e-12));
        expect(Curves.easeOut.transform(0.5), isNot(closeTo(1.0, 1e-6)));
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets('supplied motion → duration = motion.standard (subtle 200ms)', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      final route = await liveRoute(tester, motion: motion);
      expect(route.transitionDuration, motion.standard);
      expect(route.transitionDuration, const Duration(milliseconds: 200));
      await tester.pump(motion.standard);
    });

    testWidgets('supplied motion → curve from motion.curve', (tester) async {
      const motion = AppMotionTokens(curve: Curves.linear);
      // Probe the linear-curve builder directly.
      final page = FadeSlideTransitionPage<Object?>(
        key: const ValueKey('probe'),
        child: const SizedBox.shrink(),
        motion: motion,
      );
      final (opacity, offset) = await probeAtHalf(tester, page);
      expect(opacity, 0.5);
      expect(offset.dx, 0.0);
      expect(offset.dy, closeTo(0.05 * 0.5, 1e-12));
    });

    testWidgets('subtle motion page drives a 200ms route transition', (
      tester,
    ) async {
      final motion = AppMotionTokens.forStyle(AppMotionStyle.subtle);
      final route = await pushedRoute(tester, motion: motion);
      expect(route.transitionDuration, motion.standard);
      // The push really animates: mid-flight at the head of the window...
      expect(route.animation!.status, AnimationStatus.forward);
      expect(route.animation!.value, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.status, AnimationStatus.forward);
      expect(route.animation!.value, greaterThan(0.0));
      expect(route.animation!.value, lessThan(1.0));
      // ...settling on the subtle standard, inside the legacy 300ms window.
      await tester.pump(motion.standard);
      expect(route.animation!.status, AnimationStatus.completed);
      expect(route.animation!.value, 1.0);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
