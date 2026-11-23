import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-1 (p11) — real behavior tests for the shapes + primitives batch,
/// written to the WHITE_LABEL_p11_ui1_shapes.md §3 T-x contract. Every test
/// asserts a real outcome on real production code: no skips, no vacuous
/// assertions, no golden dependence. Components consume the ambient theme
/// (BrandColors.of / AppShapeTokens / ColorScheme) — the BrandColors.fallback
/// path covers bare MaterialApp test themes exactly as the COLOR-1 pattern
/// prescribes.
void main() {
  group('T-1 BrandShapes — pure vocabulary', () {
    test('canonical radii are the documented constants', () {
      expect(BrandShapes.small, 8.0);
      expect(BrandShapes.medium, 12.0);
      expect(BrandShapes.large, 16.0);
      expect(BrandShapes.pill, 999.0);
    });

    test('border getters track their radii', () {
      expect(BrandShapes.borderSmall, BorderRadius.circular(BrandShapes.small));
      expect(
        BrandShapes.borderMedium,
        BorderRadius.circular(BrandShapes.medium),
      );
      expect(BrandShapes.borderLarge, BorderRadius.circular(BrandShapes.large));
      expect(BrandShapes.borderPill, BorderRadius.circular(BrandShapes.pill));
    });

    test('tileShape carries the large radius and an optional side', () {
      final plain = BrandShapes.tileShape();
      expect(plain.borderRadius, BrandShapes.borderLarge);
      // Flutter 3.x: RoundedRectangleBorder.side is non-nullable; "no side"
      // is BorderSide.none.
      expect(plain.side, BorderSide.none);

      const sideColor = Color(0xFF123456);
      final sided = BrandShapes.tileShape(borderColor: sideColor);
      expect(sided.borderRadius, BrandShapes.borderLarge);
      expect(sided.side, isNotNull);
      expect(sided.side.color, sideColor);
    });

    test(
      'stadium is a StadiumBorder; outlinedMedium carries radius + side',
      () {
        expect(BrandShapes.stadium, isA<StadiumBorder>());

        const edge = Color(0xFFABCDEF);
        final outlined = BrandShapes.outlinedMedium(color: edge, width: 2);
        expect(outlined.borderRadius, BrandShapes.borderMedium);
        expect(outlined.side, isNotNull);
        expect(outlined.side.color, edge);
        expect(outlined.side.width, 2.0);
        expect(BrandShapes.outlinedMedium().side, BorderSide.none);
      },
    );
  });

  group('T-2 BrandCard — token-radius card', () {
    testWidgets('default radius is the token default (16)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrandCard(child: Text('card body'))),
        ),
      );

      expect(find.text('card body'), findsOneWidget);
      // Descendant: the Scaffold's own Material is an ANCESTOR — resolve the
      // card's Material specifically.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BrandCard),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      // No onTap → no tap path at all (inert container, not a fake button).
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('AppShapeTokens.cardRadius overrides the default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: const <ThemeExtension<dynamic>>[
              AppShapeTokens(cardRadius: 24),
            ],
          ),
          home: const Scaffold(body: BrandCard(child: Text('token card'))),
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BrandCard),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('an onTap provides exactly one InkWell tap path', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandCard(onTap: () => taps++, child: const Text('tappable')),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('tappable'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('explicit color and borderColor are honored', (tester) async {
      const custom = Color(0xFF00FF00);
      const border = Color(0xFFFF00FF);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandCard(
              color: custom,
              borderColor: border,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BrandCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, custom);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, isNotNull);
      expect(shape.side.color, border);
    });
  });

  group('T-3 BrandChip — selectable stadium chip', () {
    testWidgets('renders label + icon; tap fires exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandChip(
              label: 'Grill',
              icon: Icons.local_fire_department,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('Grill'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      await tester.tap(find.text('Grill'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('selected state uses primary/onPrimary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrandChip(label: 'Spicy', selected: true)),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const BrandColors.fallback().primary);
      expect(decoration.borderRadius, BrandShapes.borderPill);
      final text = tester.widget<Text>(find.text('Spicy'));
      // BrandButton precedent: filled brand surfaces use AppColors.background
      // as the contrasting foreground (Law 3 constant, AA-pass on primary).
      expect(text.style!.color, AppColors.background);
    });

    testWidgets('unselected state uses surface + a textSecondary outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrandChip(label: 'Mild')),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const BrandColors.fallback().surface);
      expect(decoration.borderRadius, BrandShapes.borderPill);
      expect(decoration.border, isA<Border>());
      expect(
        (decoration.border! as Border).top.color,
        const BrandColors.fallback().textSecondary,
      );
    });
  });

  group('T-4 Badge — 4-tone pill', () {
    const tones = <BadgeTone, List<Color>>{
      BadgeTone.neutral: [Color(0x1F1E1E1E), Color(0xFF1E1E1E)],
      BadgeTone.positive: [Color(0xFF2E7D32), Color(0xFFFFFFFF)],
      BadgeTone.warning: [Color(0xFFFFC107), Color(0xFF1E1E1E)],
      BadgeTone.negative: [Color(0xFFE53935), Color(0xFFFFFFFF)],
    };

    test('the four tones have four DISTINCT (bg, fg) pairs', () {
      final pairs = tones.values.map((pair) => pair.join('|')).toSet();
      expect(pairs.length, 4);
    });

    for (final entry in tones.entries) {
      testWidgets('tone ${entry.key.name} resolves its documented (bg, fg)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrandBadge(label: 'B', tone: entry.key),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, entry.value[0]);
        expect(decoration.borderRadius, BrandShapes.borderPill);
        final text = tester.widget<Text>(find.text('B'));
        expect(text.style!.color, entry.value[1]);
      });
    }

    testWidgets('long labels are single-line ellipsized', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandBadge(label: 'a very long badge label indeed'),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text('a very long badge label indeed'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('T-5 PriceTag — display-only money (delegates to moneyCents)', () {
    testWidgets('formats integer cents through moneyCents literals', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PriceTag(cents: 1234))),
      );
      expect(find.text(r'$12.34'), findsOneWidget);
    });

    testWidgets('small, grouped and negative cents literals', (tester) async {
      // 5 → $0.05 · 123456 → $1,234.56 · −150 → −$1.50 (moneyCents owns the
      // minus; PriceTag never does arithmetic).
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriceTag(cents: 5),
                PriceTag(cents: 123456),
                PriceTag(cents: -150),
              ],
            ),
          ),
        ),
      );
      expect(find.text(r'$0.05'), findsOneWidget);
      expect(find.text(r'$1,234.56'), findsOneWidget);
      expect(find.text(r'-$1.50'), findsOneWidget);
    });

    testWidgets('currency config flows through to moneyCents', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriceTag(cents: 100, currencyCode: 'EUR'),
                PriceTag(cents: 100, currencyCode: 'XXX', currencySymbol: '¤'),
              ],
            ),
          ),
        ),
      );
      expect(find.text(r'€1.00'), findsOneWidget);
      expect(find.text(r'¤1.00'), findsOneWidget);
    });

    testWidgets('compare-at renders strikethrough ONLY when greater', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriceTag(cents: 500, compareAtCents: 999),
                PriceTag(cents: 500, compareAtCents: 300),
              ],
            ),
          ),
        ),
      );

      expect(find.text(r'$5.00'), findsNWidgets(2));
      final compare = tester.widget<Text>(find.text(r'$9.99'));
      expect(compare.style!.decoration, TextDecoration.lineThrough);
      // A compare-at ≤ price is nonsense: suppressed, not rendered.
      expect(find.text(r'$3.00'), findsNothing);
    });

    testWidgets('large variant scales the primary amount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriceTag(cents: 100, large: true),
                PriceTag(cents: 100),
              ],
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<Text>(find.text(r'$1.00'))
          .map((t) => t.style!.fontSize)
          .toList();
      expect(sizes, [22.0, 16.0]);
    });

    testWidgets('runtime construction formats identically', (tester) async {
      // Deliberately non-const construction with a runtime-computed config —
      // exercises the runtime constructor path const contexts never execute.
      // A const literal is fine — the runtime path comes from the helper
      // call below (a function call is never const-evaluated).
      const code = 'USD';
      // Runtime construction through a helper (a call is never const-promoted).
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtimePriceTag(code))),
      );

      expect(find.text(r'$0.77'), findsOneWidget);
    });

    testWidgets('merged semantics carries the full formatted sentence', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PriceTag(cents: 500, compareAtCents: 999)),
        ),
      );

      final semantics = tester.getSemantics(find.byType(PriceTag));
      expect(semantics.label, contains(r'$5.00'));
      expect(semantics.label, contains(r'$9.99'));
    });
  });

  group('T-6 BrandDivider — solid + dashed', () {
    testWidgets('solid divider honors thickness + explicit color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandDivider(thickness: 3, color: Color(0xFF112233)),
          ),
        ),
      );

      final size = tester.getSize(find.byType(Container).first);
      expect(size.height, 3);
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, const Color(0xFF112233));
    });

    testWidgets('solid divider falls back to the theme divider color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandDivider())),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, ThemeData().dividerColor);
      expect(tester.getSize(find.byType(Container).first).height, 1);
    });

    testWidgets('dashed variant paints through DashedLinePainter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandDivider.dashed())),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is DashedLinePainter,
        ),
      );
      expect(customPaint.painter, isA<DashedLinePainter>());
    });

    testWidgets('dashed variant supports runtime construction + indents', (
      tester,
    ) async {
      // Deliberately non-const construction: exercises the runtime `.dashed`
      // constructor path const contexts never execute, plus the indents.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtimeDashedDivider())),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      // T-4 (p18): margin is now EdgeInsetsDirectional — pin the RESOLVED
      // behavior in both directions (LTR byte-identical, RTL mirrored).
      final dashedMargin = container.margin!;
      expect(
        dashedMargin.resolve(TextDirection.ltr),
        const EdgeInsets.only(left: 8, right: 8),
      );
      expect(
        dashedMargin.resolve(TextDirection.rtl),
        const EdgeInsets.only(left: 8, right: 8),
        reason: 'symmetric indents resolve identically in both directions',
      );
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is DashedLinePainter,
        ),
      );
      final painter = paint.painter! as DashedLinePainter;
      expect(painter.thickness, 2);
      expect(painter.dashWidth, 4);
      expect(painter.dashGap, 3);
    });

    test('dashOffsets is exact, inclusive-fit arithmetic', () {
      // Dash 4 gap 3 over 20 → starts 0, 7, 14 (14+4=18 ≤ 20).
      expect(DashedLinePainter.dashOffsets(20, 4, 3), <double>[0, 7, 14]);
      // 17 → 14+4=18 > 17 is dropped.
      expect(DashedLinePainter.dashOffsets(17, 4, 3), <double>[0, 7]);
      // Exact fit 4 over 4 → single dash.
      expect(DashedLinePainter.dashOffsets(4, 4, 3), <double>[0]);
      // Narrower than one dash → nothing paints (cosmetic layer, L5).
      expect(DashedLinePainter.dashOffsets(2, 4, 3), isEmpty);
    });

    test('shouldRepaint keys on every field', () {
      const base = DashedLinePainter(
        color: Color(0xFF112233),
        thickness: 1,
        dashWidth: 4,
        dashGap: 3,
      );
      const same = DashedLinePainter(
        color: Color(0xFF112233),
        thickness: 1,
        dashWidth: 4,
        dashGap: 3,
      );
      expect(base.shouldRepaint(same), isFalse);
      expect(
        base.shouldRepaint(
          const DashedLinePainter(
            color: Color(0xFF000000),
            thickness: 1,
            dashWidth: 4,
            dashGap: 3,
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const DashedLinePainter(
            color: Color(0xFF112233),
            thickness: 2,
            dashWidth: 4,
            dashGap: 3,
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const DashedLinePainter(
            color: Color(0xFF112233),
            thickness: 1,
            dashWidth: 5,
            dashGap: 3,
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const DashedLinePainter(
            color: Color(0xFF112233),
            thickness: 1,
            dashWidth: 4,
            dashGap: 4,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('indent and endIndent shape the solid margin', (tester) async {
      // Deliberately non-const construction: exercises the runtime
      // constructor path const contexts never execute.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtimeSolidDivider())),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      // T-4 (p18): margin is now EdgeInsetsDirectional — pin the RESOLVED
      // behavior in both directions (LTR byte-identical, RTL mirrored).
      final solidMargin = container.margin!;
      expect(
        solidMargin.resolve(TextDirection.ltr),
        const EdgeInsets.only(left: 16, right: 32),
      );
      expect(
        solidMargin.resolve(TextDirection.rtl),
        const EdgeInsets.only(left: 32, right: 16),
        reason: 'indent/endIndent are start/end — mirrored in RTL',
      );
      expect(tester.getSize(find.byType(Container).first).height, 2);
    });
  });

  group('T-7 InfoBanner — semantic banner', () {
    test('the five tones map to five DISTINCT icons and colors', () {
      final icons = <IconData>{
        for (final tone in InfoTone.values) InfoBanner.iconFor(tone),
      };
      final colors = <Color>{
        for (final tone in InfoTone.values)
          InfoBanner.colorFor(tone, const BrandColors.fallback()),
      };
      expect(icons.length, 5);
      expect(colors.length, 5);
      // The documented mapping (Law 3 chain: BrandColors → AppColors).
      expect(
        InfoBanner.colorFor(InfoTone.info, const BrandColors.fallback()),
        AppColors.primary,
      );
      expect(
        InfoBanner.colorFor(InfoTone.success, const BrandColors.fallback()),
        AppColors.success,
      );
      expect(
        InfoBanner.colorFor(InfoTone.warning, const BrandColors.fallback()),
        AppColors.warning,
      );
      expect(
        InfoBanner.colorFor(InfoTone.error, const BrandColors.fallback()),
        AppColors.error,
      );
      // Q3: sold-out is its own semantic state — distinct hue, distinct icon.
      expect(
        InfoBanner.colorFor(InfoTone.soldOut, const BrandColors.fallback()),
        AppColors.soldOut,
      );
    });

    testWidgets('each tone renders its tone icon in the banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final tone in InfoTone.values)
                  InfoBanner(tone: tone, child: Text(tone.name)),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(InfoBanner.iconFor(InfoTone.info)), findsOneWidget);
      expect(find.byIcon(InfoBanner.iconFor(InfoTone.success)), findsOneWidget);
      expect(find.byIcon(InfoBanner.iconFor(InfoTone.warning)), findsOneWidget);
      expect(find.byIcon(InfoBanner.iconFor(InfoTone.error)), findsOneWidget);
      expect(find.byIcon(InfoBanner.iconFor(InfoTone.soldOut)), findsOneWidget);
      expect(find.text('info'), findsOneWidget);
    });

    testWidgets('container tint is the tone color at alpha .08', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoBanner(tone: InfoTone.info, child: Text('m')),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.primary.withValues(alpha: 0.08));
      expect(decoration.borderRadius, BrandShapes.borderMedium);
    });

    testWidgets('optional dismiss fires exactly once', (tester) async {
      var dismisses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoBanner(
              tone: InfoTone.success,
              onDismiss: () => dismisses++,
              child: const Text('Saved'),
            ),
          ),
        ),
      );

      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(dismisses, 1);
    });

    testWidgets('a title renders bold above the message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoBanner(
              tone: InfoTone.warning,
              title: 'Heads up',
              child: Text('The kitchen closes soon'),
            ),
          ),
        ),
      );

      expect(find.text('Heads up'), findsOneWidget);
      expect(find.text('The kitchen closes soon'), findsOneWidget);
      final title = tester.widget<Text>(find.text('Heads up'));
      expect(title.style!.fontWeight, FontWeight.w700);
    });

    test('the dismiss tooltip fallback is the documented constant', () {
      expect(InfoBanner.kDefaultDismissTooltip, 'Dismiss');
    });
  });

  group('T-8 GradientScaffold — composed backdrop', () {
    testWidgets(
      'renders body; gradient derived from brand primary; no overlay image '
      'when unconfigured',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: GradientScaffold(body: Text('content'))),
        );

        expect(find.text('content'), findsOneWidget);
        // Bare test theme → BrandColors.fallback().primary drives the
        // gradient (Law 3 chain, same expression as the implementation).
        final decorated = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final gradient =
            (decorated.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(
          gradient.colors.first,
          const Color(0xFFC84F00).withValues(alpha: 0.06),
        );
        expect(gradient.colors.last, ThemeData().scaffoldBackgroundColor);
        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
        // No overlay token → ScaffoldBackground degrades without an image.
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets('applyGradient=false removes the gradient layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GradientScaffold(applyGradient: false, body: Text('flat')),
        ),
      );

      expect(find.text('flat'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('applyOverlay=false removes the ScaffoldBackground layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GradientScaffold(applyOverlay: false, body: Text('no overlay')),
        ),
      );

      expect(find.text('no overlay'), findsOneWidget);
      expect(find.byType(ScaffoldBackground), findsNothing);
      // The gradient layer is still present by default.
      expect(find.byType(DecoratedBox), findsOneWidget);
    });

    testWidgets('an overlay token renders the decorative image layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: const <ThemeExtension<dynamic>>[
              AppBackdropTokens(overlayAsset: 'assets/images/map.png'),
            ],
          ),
          home: const GradientScaffold(body: Text('overlaid')),
        ),
      );

      expect(find.text('overlaid'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      // Fixed decorative intensity — the b10 mechanism token, not artwork.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0.08,
        ),
        findsOneWidget,
      );
    });
    testWidgets('runtime construction still composes both layers', (
      tester,
    ) async {
      // Deliberately non-const construction: exercises the runtime
      // constructor path AND the both-layers composition (gradient WITH the
      // overlay wrapper), which the isolated-toggle tests never cover.
      await tester.pumpWidget(MaterialApp(home: runtimeGradientScaffold()));

      expect(find.text('runtime'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.byType(ScaffoldBackground), findsOneWidget);
    });
  });

  group('T-9 BrandTextField — wiring over the ambient input theme', () {
    testWidgets('renders label, hint and prefix icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandTextField(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icons.alternate_email,
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email), findsOneWidget);
    });

    testWidgets('errorText surfaces; onChanged fires per edit', (tester) async {
      final entered = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandTextField(
              labelText: 'Name',
              errorText: 'Required',
              onChanged: entered.add,
            ),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Ali');
      expect(entered, ['Ali']);
    });

    testWidgets('validator is wired through Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: const BrandTextField(validator: _requiredValidator),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'ok');
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('obscure/disabled/keyboard/submit params forward', (
      tester,
    ) async {
      final controller = TextEditingController(text: 's3cret');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandTextField(
              controller: controller,
              obscureText: true,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              maxLines: 1,
              onFieldSubmitted: (_) {},
            ),
          ),
        ),
      );

      // Assert on the widget that owns the input surface: the inner
      // TextField (TextFormField is the Form wrapper and no longer exposes
      // these getters on this Flutter version).
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.enabled, isFalse);
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.textInputAction, TextInputAction.next);
      expect(field.maxLines, 1);
      expect(field.controller, controller);
      expect(field.onSubmitted, isNotNull);
    });
  });

  group('T-10 QuantityStepper — clamped integer step', () {
    testWidgets('increment emits value+1; decrement emits value-1', (
      tester,
    ) async {
      final events = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(value: 2, onChanged: events.add),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip(kDefaultIncreaseTooltip));
      await tester.tap(find.byTooltip(kDefaultDecreaseTooltip));
      await tester.pump();
      expect(events, [3, 1]);
    });

    testWidgets('min bound disables decrement (no event)', (tester) async {
      final events = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(value: 0, onChanged: events.add),
          ),
        ),
      );

      expect(_stepperButton(tester, kDefaultDecreaseTooltip).onPressed, isNull);
      await tester.tap(find.byTooltip(kDefaultIncreaseTooltip));
      await tester.pump();
      expect(events, [1]);
    });

    testWidgets('max bound disables increment (no event)', (tester) async {
      final events = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(value: 99, onChanged: events.add),
          ),
        ),
      );

      expect(_stepperButton(tester, kDefaultIncreaseTooltip).onPressed, isNull);
      await tester.tap(find.byTooltip(kDefaultDecreaseTooltip));
      await tester.pump();
      expect(events, [98]);
    });

    testWidgets('a custom range [2, 3] clamps at both ends', (tester) async {
      final events = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 2,
              minValue: 2,
              maxValue: 3,
              onChanged: events.add,
            ),
          ),
        ),
      );

      expect(_stepperButton(tester, kDefaultDecreaseTooltip).onPressed, isNull);
      await tester.tap(find.byTooltip(kDefaultIncreaseTooltip));
      await tester.pump();
      expect(events, [3]);
      // The stepper is STATELESS — the caller owns `value`. Re-pump at the
      // emitted value to prove the upper clamp disables increment.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 3,
              minValue: 2,
              maxValue: 3,
              onChanged: events.add,
            ),
          ),
        ),
      );
      expect(_stepperButton(tester, kDefaultIncreaseTooltip).onPressed, isNull);
    });

    test('fallback a11y tooltips are the documented constants', () {
      expect(kDefaultDecreaseTooltip, 'Decrease');
      expect(kDefaultIncreaseTooltip, 'Increase');
    });
  });
}

/// Shared Form validator for the T-9 wiring tests (top-level so it can be
/// const-constructed inside `const BrandTextField`).
String? _requiredValidator(String? value) =>
    (value == null || value.isEmpty) ? 'Required' : null;

/// Resolves the [IconButton] that OWNS a tooltip: `find.byTooltip` itself
/// resolves to the internal `Tooltip` widget (a `RawTooltip` on this Flutter
/// version), so the button is found as its ancestor.
IconButton _stepperButton(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first,
    );

// ── Runtime-construction helpers ────────────────────────────────────────────
// A function call can never be const-promoted by the linter, so these force
// the RUNTIME constructor path of each component — the lines const contexts
// never execute (verified against lcov during UI-1).

BrandDivider runtimeSolidDivider() =>
    // Deliberately RUNTIME construction — const-evaluated constructors never
    // execute, which is exactly what these helpers exist to cover.
    // ignore: prefer_const_constructors
    BrandDivider(thickness: 2, indent: 16, endIndent: 32);

BrandDivider runtimeDashedDivider() =>
    // Deliberately RUNTIME construction (see runtimeSolidDivider).
    // ignore: prefer_const_constructors
    BrandDivider.dashed(thickness: 2, indent: 8, endIndent: 8);

GradientScaffold runtimeGradientScaffold() =>
    // Deliberately RUNTIME construction (see runtimeSolidDivider).
    // ignore: prefer_const_constructors
    GradientScaffold(
      body: const Text('runtime'),
      applyGradient: true,
      applyOverlay: true,
    );

PriceTag runtimePriceTag(String code) =>
    PriceTag(cents: 77, currencyCode: code);
