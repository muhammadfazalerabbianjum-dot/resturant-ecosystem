// UI-5 (p15) — PROOF WAVE: the compatibility matrix is the contract (L9).
//
// WHITE_LABEL_p15_ui5_proof.md §3:
//   T-1 — all 26 §1 components render exception-free with content asserted
//         under light × dark × shape {default, AppShapeTokens(cardRadius: 24)};
//         the 5 motion components + the tile/grid components additionally
//         under AppMotionStyle.{full, subtle, none} (bounded combinatorics).
//   T-2 — an INJECTED custom BrandColors palette (hues distinct from every
//         AppColors constant) is resolved by the BrandColors-reading
//         components (L10) — config-driven rebranding, end to end.
//   T-3 — the captured golden set under test/goldens/ at the fixed light
//         theme (0.10: AppTheme test-guard path, System fonts in tests).
//   T-4 — the L11 semantics sweep: PriceTag merged label, stepper tooltips +
//         >= 48 dp tap targets, chip/card/tile tap semantics.
//
// No skips, no vacuous assertions, no golden re-capture to force green.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// SemanticsData.actions is the framework's action BITFIELD; `hasAction` is
/// the canonical check (action.index is the bit value).
bool _hasTapAction(SemanticsData data) => data.hasAction(SemanticsAction.tap);

/// A palette whose hues are deliberately DISTINCT from every `AppColors`
/// constant (L10): injected through the theme, it must be resolved by every
/// BrandColors-reading component — never silently replaced by the fallback.
const BrandColors kInjectedBrand = BrandColors(
  primary: Color(0xFF0044CC),
  secondary: Color(0xFF332211),
  accent: Color(0xFF123456),
  success: Color(0xFF008080),
  warning: Color(0xFF884400),
  error: Color(0xFFCC0000),
  soldOut: Color(0xFF778899),
  background: Color(0xFFF5F5F5),
  surface: Color(0xFFEFEFEF),
  textPrimary: Color(0xFF101418),
  textSecondary: Color(0xFF556677),
  textPrimary12: Color(0x1A101418),
);

ThemeData _themeFor({
  Brightness brightness = Brightness.light,
  double cardRadius = BrandShapes.large,
  AppMotionStyle motion = AppMotionStyle.full,
  BrandColors? brand,
}) => ThemeData(
  brightness: brightness,
  extensions: <ThemeExtension<dynamic>>[
    brand ?? const BrandColors.fallback(),
    AppShapeTokens(cardRadius: cardRadius),
    AppMotionTokens.forStyle(motion),
  ],
);

/// Pumps one matrix cell: a themed host at a fixed 900x1200 surface, settles
/// explicitly (L8) and fails on any exception thrown during pump/settle.
Future<void> _pumpCell(
  WidgetTester tester,
  WidgetBuilder build, {
  Brightness brightness = Brightness.light,
  double cardRadius = BrandShapes.large,
  AppMotionStyle motion = AppMotionStyle.full,
  BrandColors? brand,
  bool shimmering = false,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _themeFor(
        brightness: brightness,
        cardRadius: cardRadius,
        motion: motion,
        brand: brand,
      ),
      home: Scaffold(
        body: Center(child: Builder(builder: build)),
      ),
    ),
  );
  if (shimmering) {
    // The skeleton shimmer repeats forever — pump a fixed window (L8).
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}

void _expectTexts(List<String> texts) {
  for (final text in texts) {
    expect(find.text(text), findsOneWidget, reason: 'missing content: $text');
  }
}

/// One matrix row: the component under a (brightness × shape × motion) combo.
class _Case {
  const _Case(
    this.build, {
    this.texts = const <String>[],
    this.shimmering = false,
  });
  final WidgetBuilder build;
  final List<String> texts;

  /// True for the skeleton family: its shimmer never settles, so the cell is
  /// pumped with a fixed window instead of pumpAndSettle (L8 discipline).
  final bool shimmering;
}

/// All 26 §1 components as matrix rows (L9: every component, no exception).
Map<String, _Case> _matrixCases() => <String, _Case>{
  'shapes (BrandShapes vocabulary)': _Case(
    (_) => Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BrandShapes.borderPill,
      ),
      child: const Text('shapes-content'),
    ),
    texts: <String>['shapes-content'],
  ),
  'brand_card': _Case(
    (_) => BrandCard(
      onTap: () {},
      borderColor: AppColors.textSecondary,
      child: const Text('card-body'),
    ),
    texts: <String>['card-body'],
  ),
  'brand_chip': _Case(
    (_) => const BrandChip(
      label: 'Filter',
      icon: Icons.filter_list,
      selected: true,
    ),
    texts: <String>['Filter'],
  ),
  'brand_badge': _Case(
    (_) => const BrandBadge(label: 'Open now', tone: BadgeTone.positive),
    texts: <String>['Open now'],
  ),
  'price_tag': _Case(
    (_) =>
        const PriceTag(cents: 1234, compareAtCents: 2000, currencySymbol: r'$'),
    texts: <String>[r'$12.34', r'$20.00'],
  ),
  'brand_divider': _Case(
    (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('above'),
        BrandDivider(),
        SizedBox(height: 4),
        BrandDivider.dashed(),
        Text('below'),
      ],
    ),
    texts: <String>['above', 'below'],
  ),
  'info_banner': _Case(
    (_) => InfoBanner(
      tone: InfoTone.warning,
      title: 'Kitchen',
      onDismiss: () {},
      child: const Text('3 items ready'),
    ),
    texts: <String>['Kitchen', '3 items ready'],
  ),
  'gradient_scaffold': _Case(
    (_) => const GradientScaffold(body: Center(child: Text('gradient-body'))),
    texts: <String>['gradient-body'],
  ),
  'brand_text_field': _Case(
    (_) =>
        const BrandTextField(labelText: 'Email', hintText: 'you@example.com'),
    texts: <String>['Email'],
  ),
  'quantity_stepper': _Case(
    (_) => QuantityStepper(value: 2, onChanged: (_) {}),
    texts: <String>['2'],
  ),
  'pressable_scale': _Case(
    (_) => PressableScale(onTap: () {}, child: const Text('pressable')),
    texts: <String>['pressable'],
  ),
  'fade_slide_in': _Case(
    (_) => const FadeSlideIn(child: Text('fades in')),
    texts: <String>['fades in'],
  ),
  'staggered_entrance': _Case(
    (_) => const StaggeredEntrance(
      children: <Widget>[Text('s1'), Text('s2'), Text('s3')],
    ),
    texts: <String>['s1', 's2', 's3'],
  ),
  'animated_count_text': _Case(
    (_) => const AnimatedCountText(987654, currencySymbol: r'$'),
    texts: <String>[r'$9,876.54'],
  ),
  'animated_visibility': _Case(
    (_) => const AnimatedVisibility(visible: true, child: Text('visibility')),
    texts: <String>['visibility'],
  ),
  'stat_tile': _Case(
    (_) => StatTile(
      label: 'Orders',
      value: '128',
      icon: Icons.receipt_long,
      delta: '+12',
      onTap: () {},
    ),
    texts: <String>['Orders', '128', '+12'],
  ),
  'setting_tile': _Case(
    (_) => SettingTile(
      icon: Icons.settings,
      title: 'Notifications',
      subtitle: 'Push, email',
      onTap: () {},
    ),
    texts: <String>['Notifications', 'Push, email'],
  ),
  'menu_tile': _Case(
    (_) => const MenuTile(
      title: 'Margherita',
      subtitle: 'Classic 12"',
      cents: 1250,
      compareAtCents: 1500,
      currencySymbol: r'$',
    ),
    texts: <String>['Margherita', 'Classic 12"', r'$12.50', r'$15.00'],
  ),
  'status_tile': _Case(
    (_) => StatusTile(
      status: TileStatus.failed,
      label: 'Out of stock',
      onTap: () {},
    ),
    texts: <String>['Out of stock'],
  ),
  'tile_grid': _Case(
    (_) => const SizedBox(
      width: 300,
      height: 300,
      child: TileGrid(
        crossAxisCount: 2,
        children: <Widget>[Text('g1'), Text('g2'), Text('g3'), Text('g4')],
      ),
    ),
    texts: <String>['g1', 'g2', 'g3', 'g4'],
  ),
  'tile_skeletons': _Case(
    (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TileSkeletons.stat(),
        const SizedBox(height: 4),
        TileSkeletons.setting(),
        const SizedBox(height: 4),
        TileSkeletons.menu(),
      ],
    ),
    shimmering: true,
  ),
  'app_breakpoints (ResponsiveBuilder)': _Case(
    (_) => ResponsiveBuilder(
      builder: (_, ResponsiveLane lane) => Text('lane:${lane.name}'),
    ),
    texts: <String>['lane:medium'],
  ),
  'screen_scaffold': _Case(
    (_) => const ScreenScaffold(
      body: Center(child: Text('screen-body')),
      bottomNav: SizedBox(height: 48, child: Text('bottom-nav')),
    ),
    texts: <String>['screen-body', 'bottom-nav'],
  ),
  'section_header': _Case(
    (_) => const SectionHeader(
      title: 'Popular',
      subtitle: 'Top picks',
      action: Text('See all'),
    ),
    texts: <String>['Popular', 'Top picks', 'See all'],
  ),
  'adaptive_row': _Case(
    (_) => const AdaptiveRow(children: <Widget>[Text('ar1'), Text('ar2')]),
    texts: <String>['ar1', 'ar2'],
  ),
  'gap': _Case(
    (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('gap-top'),
        Gap.h16,
        const Text('gap-mid'),
        Gap.v16,
        const Text('gap-bottom'),
      ],
    ),
    texts: <String>['gap-top', 'gap-mid', 'gap-bottom'],
  ),
};

void main() {
  group('T-1 compatibility matrix (L9: 26 × light/dark × shape variants)', () {
    final cases = _matrixCases();
    for (final brightness in Brightness.values) {
      for (final shape in <double, String>{
        BrandShapes.large: 'default',
        24: 'cardRadius:24',
      }.entries) {
        testWidgets('all 26 components render: ${brightness.name} × shape '
            '${shape.value}', (tester) async {
          for (final entry in cases.entries) {
            final row = entry.value;
            await _pumpCell(
              tester,
              row.build,
              brightness: brightness,
              cardRadius: shape.key,
              shimmering: row.shimmering,
            );
            _expectTexts(row.texts);
          }
        });
      }
    }

    testWidgets('shape token variant actually reshapes card surfaces', (
      tester,
    ) async {
      // At the default token the card radius is BrandShapes.large (16);
      // at AppShapeTokens(cardRadius: 24) it is 24 — no component edits.
      await _pumpCell(tester, (_) => const BrandCard(child: Text('card-body')));
      expect(
        (tester
                    .widget<Material>(
                      find.descendant(
                        of: find.byType(BrandCard),
                        matching: find.byType(Material),
                      ),
                    )
                    .shape!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(BrandShapes.large),
      );
      await _pumpCell(
        tester,
        (_) => const BrandCard(child: Text('card-body')),
        cardRadius: 24,
      );
      expect(
        (tester
                    .widget<Material>(
                      find.descendant(
                        of: find.byType(BrandCard),
                        matching: find.byType(Material),
                      ),
                    )
                    .shape!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(24),
      );
      // And the tile family rides the same token.
      await _pumpCell(
        tester,
        (_) => const StatTile(label: 'Orders', value: '128'),
        cardRadius: 24,
      );
      expect(
        (tester
                    .widget<Material>(
                      find.descendant(
                        of: find.byType(StatTile),
                        matching: find.byType(Material),
                      ),
                    )
                    .shape!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(24),
      );
    });
  });

  group(
    'T-1 style variants (L9: motion {full,subtle,none} × 5 motion components '
    '+ the tile/grid components)',
    () {
      for (final style in AppMotionStyle.values) {
        testWidgets('PressableScale under ${style.name}', (tester) async {
          var taps = 0;
          await _pumpCell(
            tester,
            (_) => PressableScale(
              onTap: () => taps++,
              child: const Text('pressable'),
            ),
            motion: style,
          );
          if (style != AppMotionStyle.none) {
            // Animated press transform is wired to the motion tokens.
            expect(find.byType(AnimatedScale), findsOneWidget);
          } else {
            // Zero controller churn — the tap still fires (L5/L6).
            expect(find.byType(AnimatedScale), findsNothing);
          }
          final gesture = await tester.startGesture(
            tester.getCenter(find.text('pressable')),
          );
          await tester.pump();
          if (style != AppMotionStyle.none) {
            await tester.pump(const Duration(milliseconds: 250));
            expect(
              tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
              0.96,
            );
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(taps, 1);
        });

        testWidgets('FadeSlideIn under ${style.name}', (tester) async {
          await _pumpCell(
            tester,
            (_) => const FadeSlideIn(child: Text('fades in')),
            motion: style,
          );
          expect(
            tester
                .widget<FadeTransition>(
                  find.descendant(
                    of: find.byType(FadeSlideIn),
                    matching: find.byType(FadeTransition),
                  ),
                )
                .opacity
                .value,
            1,
            reason: 'content must reach full visibility under ${style.name}',
          );
          if (style != AppMotionStyle.none) {
            // A fresh mount animates from invisible: one frame in, still dark.
            await tester.pumpWidget(
              MaterialApp(
                theme: _themeFor(motion: style),
                home: const Scaffold(
                  body: Center(child: FadeSlideIn(child: Text('again'))),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 1));
            expect(
              tester
                  .widget<FadeTransition>(
                    find.descendant(
                      of: find.byType(FadeSlideIn),
                      matching: find.byType(FadeTransition),
                    ),
                  )
                  .opacity
                  .value,
              lessThan(1),
            );
            await tester.pumpAndSettle();
            expect(find.text('again'), findsOneWidget);
          }
        });

        testWidgets('StaggeredEntrance under ${style.name}', (tester) async {
          await _pumpCell(
            tester,
            (_) => const StaggeredEntrance(
              children: <Widget>[Text('s1'), Text('s2'), Text('s3')],
            ),
            motion: style,
          );
          final opacities = tester
              .widgetList<FadeTransition>(
                find.descendant(
                  of: find.byType(StaggeredEntrance),
                  matching: find.byType(FadeTransition),
                ),
              )
              .map((FadeTransition w) => w.opacity.value)
              .toList();
          expect(opacities.length, 3);
          for (final value in opacities) {
            expect(value, 1, reason: 'every child must settle visible');
          }
          // Order preserved (vertical, top-to-bottom).
          expect(
            tester.getTopLeft(find.text('s1')).dy,
            lessThan(tester.getTopLeft(find.text('s2')).dy),
          );
          expect(
            tester.getTopLeft(find.text('s2')).dy,
            lessThan(tester.getTopLeft(find.text('s3')).dy),
          );
        });
        testWidgets('AnimatedCountText under ${style.name}', (tester) async {
          Widget host(int value) => MaterialApp(
            theme: _themeFor(motion: style),
            home: Scaffold(
              body: AnimatedCountText(value, currencySymbol: r'$'),
            ),
          );
          tester.view.physicalSize = const Size(900, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(host(1500));
          expect(find.text(r'$15.00'), findsOneWidget);
          await tester.pumpWidget(host(2500));
          if (style == AppMotionStyle.none) {
            // Instant jump — no controller churn.
            expect(find.text(r'$25.00'), findsOneWidget);
          } else {
            // Mid-animation the old value is still on screen, then settles.
            await tester.pump(const Duration(milliseconds: 1));
            expect(find.text(r'$25.00'), findsNothing);
            await tester.pumpAndSettle();
            expect(find.text(r'$25.00'), findsOneWidget);
          }
        });

        testWidgets('AnimatedVisibility under ${style.name}', (tester) async {
          Widget host(bool visible) => MaterialApp(
            theme: _themeFor(motion: style),
            home: Scaffold(
              body: AnimatedVisibility(
                visible: visible,
                child: const Text('visibility'),
              ),
            ),
          );
          tester.view.physicalSize = const Size(900, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(host(true));
          expect(find.text('visibility'), findsOneWidget);
          await tester.pumpWidget(host(false));
          if (style == AppMotionStyle.none) {
            // Instant switch, still alive in the tree (L5).
            expect(find.text('visibility'), findsNothing);
          } else {
            await tester.pumpAndSettle();
            expect(find.text('visibility'), findsNothing);
          }
          expect(
            find.text('visibility', skipOffstage: false),
            findsOneWidget,
            reason: 'hidden content is kept alive offstage, never destroyed',
          );
          await tester.pumpWidget(host(true));
          await tester.pumpAndSettle();
          expect(find.text('visibility'), findsOneWidget);
        });

        testWidgets('tiles/grid are style-agnostic under ${style.name}', (
          tester,
        ) async {
          await _pumpCell(
            tester,
            (_) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StatTile(label: 'Orders', value: '128'),
                SizedBox(height: 8),
                SettingTile(icon: Icons.settings, title: 'Notifications'),
                SizedBox(height: 8),
                MenuTile(
                  title: 'Margherita',
                  cents: 1250,
                  currencySymbol: r'$',
                ),
              ],
            ),
            motion: style,
          );
          _expectTexts(<String>[
            'Orders',
            '128',
            'Notifications',
            'Margherita',
            r'$12.50',
          ]);
          await _pumpCell(
            tester,
            (_) => const SizedBox(
              width: 300,
              height: 300,
              child: TileGrid(
                crossAxisCount: 2,
                children: <Widget>[
                  Text('g1'),
                  Text('g2'),
                  Text('g3'),
                  Text('g4'),
                ],
              ),
            ),
            motion: style,
          );
          _expectTexts(<String>['g1', 'g2', 'g3', 'g4']);
        });
      }
    },
  );

  group('T-2 injected palette (L10: BrandColors injection is resolved)', () {
    testWidgets('BrandChip renders the injected primary/surface', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const BrandChip(label: 'Filter', selected: true),
        brand: kInjectedBrand,
      );
      final selected =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(selected.color, kInjectedBrand.primary);
      expect(
        tester.widget<Text>(find.text('Filter')).style!.color,
        AppColors.background,
      );
      await _pumpCell(
        tester,
        (_) => const BrandChip(label: 'Filter'),
        brand: kInjectedBrand,
      );
      final unselected =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(unselected.color, kInjectedBrand.surface);
      expect(
        tester.widget<Text>(find.text('Filter')).style!.color,
        kInjectedBrand.textSecondary,
      );
    });

    testWidgets('BrandBadge positive renders the injected success', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const BrandBadge(label: 'Open now', tone: BadgeTone.positive),
        brand: kInjectedBrand,
      );
      expect(
        (tester.widget<Container>(find.byType(Container)).decoration!
                as BoxDecoration)
            .color,
        kInjectedBrand.success,
      );
    });

    testWidgets('InfoBanner warning renders the injected warning', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const InfoBanner(
          tone: InfoTone.warning,
          child: Text('3 items ready'),
        ),
        brand: kInjectedBrand,
      );
      expect(
        tester
            .widget<Icon>(find.byIcon(InfoBanner.iconFor(InfoTone.warning)))
            .color,
        kInjectedBrand.warning,
      );
      expect(
        (tester.widget<Container>(find.byType(Container)).decoration!
                as BoxDecoration)
            .color,
        kInjectedBrand.warning.withValues(alpha: 0.08),
      );
    });

    testWidgets(
      'InfoBanner body copy renders the injected textPrimary (no AppColors '
      'leak)',
      (tester) async {
        await _pumpCell(
          tester,
          (_) => const InfoBanner(
            tone: InfoTone.error,
            child: Text('Order could not be placed'),
          ),
          brand: kInjectedBrand,
        );
        // The message color arrives via DefaultTextStyle.merge — resolve the
        // INHERITED style at the Text's element, not Text.style (which is null).
        final inherited = DefaultTextStyle.of(
          tester.element(find.text('Order could not be placed')),
        );
        expect(
          inherited.style.color,
          kInjectedBrand.textPrimary,
          reason:
              'the banner body must resolve the CLIENT ink token — a hardcoded '
              'AppColors.textPrimary silently overrides every rebrand (Q3)',
        );
      },
    );

    testWidgets(
      'EmptyStateWidget subtitle renders the injected textSecondary (no '
      'AppColors leak)',
      (tester) async {
        await _pumpCell(
          tester,
          (_) => const EmptyStateWidget(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            subtitle: 'Browse the menu to get started',
          ),
          brand: kInjectedBrand,
        );
        expect(
          tester
              .widget<Text>(find.text('Browse the menu to get started'))
              .style!
              .color,
          kInjectedBrand.textSecondary,
          reason:
              'the empty-state subtitle must resolve the CLIENT muted token — '
              'a hardcoded AppColors.textSecondary silently overrides every '
              'rebrand (Q3)',
        );
      },
    );

    testWidgets('PriceTag compare-at renders the injected textSecondary', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const PriceTag(
          cents: 500,
          compareAtCents: 999,
          currencySymbol: r'$',
        ),
        brand: kInjectedBrand,
      );
      expect(
        tester.widget<Text>(find.text(r'$9.99')).style!.color,
        kInjectedBrand.textSecondary,
      );
    });

    testWidgets('QuantityStepper renders the injected chrome colors', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => QuantityStepper(value: 2, onChanged: (_) {}),
        brand: kInjectedBrand,
      );
      // The IconButtons own the color via IconTheme (the Icon widget's own
      // `color` stays null) — assert the ACTUALLY RENDERED glyph color (the
      // RichText under the button's Semantics wrapper).
      RenderParagraph glyphOf(IconData icon) =>
          tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.ancestor(
                of: find.byIcon(icon),
                matching: find.byType(IconButton),
              ),
              matching: find.byWidgetPredicate((Widget w) => w is RichText),
            ),
          );
      expect(
        glyphOf(Icons.remove_circle_outline).text.style!.color,
        kInjectedBrand.textSecondary,
      );
      expect(
        glyphOf(Icons.add_circle_outline).text.style!.color,
        kInjectedBrand.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text('2')).style!.color,
        kInjectedBrand.textPrimary,
      );
    });
    testWidgets('stat/setting/status tiles + menu render injected hues', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const StatTile(
          label: 'Orders',
          value: '128',
          icon: Icons.receipt_long,
          delta: '+12',
        ),
        brand: kInjectedBrand,
      );
      expect(
        tester.widget<Text>(find.text('Orders')).style!.color,
        kInjectedBrand.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text('128')).style!.color,
        kInjectedBrand.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('+12')).style!.color,
        kInjectedBrand.success,
      );
      await _pumpCell(
        tester,
        (_) => const SettingTile(icon: Icons.settings, title: 'Notifications'),
        brand: kInjectedBrand,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.settings)).color,
        kInjectedBrand.primary,
      );
      expect(
        tester.widget<Text>(find.text('Notifications')).style!.color,
        kInjectedBrand.textPrimary,
      );
      await _pumpCell(
        tester,
        (_) => const StatusTile(status: TileStatus.failed, label: 'Failed'),
        brand: kInjectedBrand,
      );
      expect(
        (tester.widget<Container>(find.byType(Container)).decoration!
                as BoxDecoration)
            .color,
        kInjectedBrand.error,
      );
      await _pumpCell(
        tester,
        (_) => const MenuTile(
          title: 'Margherita',
          cents: 1250,
          currencySymbol: r'$',
        ),
        brand: kInjectedBrand,
      );
      expect(
        tester.widget<Text>(find.text('Margherita')).style!.color,
        kInjectedBrand.textPrimary,
      );
    });

    testWidgets('GradientScaffold gradient starts at the injected primary', (
      tester,
    ) async {
      await _pumpCell(
        tester,
        (_) => const GradientScaffold(
          applyOverlay: false,
          body: Center(child: Text('gradient-body')),
        ),
        brand: kInjectedBrand,
      );
      final gradient =
          (tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(
        gradient.colors.first,
        kInjectedBrand.primary.withValues(alpha: 0.06),
      );
    });

    testWidgets(
      'contrast: WITHOUT injection the SAME slots resolve the AppColors '
      'constants (the injection is what moved them, L10)',
      (tester) async {
        await _pumpCell(
          tester,
          (_) => const BrandChip(label: 'Filter', selected: true),
        );
        expect(
          (tester
                      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                      .decoration
                  as BoxDecoration)
              .color,
          AppColors.primary,
        );
        await _pumpCell(
          tester,
          (_) => const StatTile(label: 'Orders', value: '128'),
        );
        expect(
          tester.widget<Text>(find.text('Orders')).style!.color,
          AppColors.textSecondary,
        );
      },
    );
  });

  group('T-3 goldens (captured set, fixed light theme, 0.10)', () {
    // Every capture: AppTheme.lightTheme (System fonts via the _isTest
    // test-guard seam), fixed 1.0 dpr surface, explicit settle, exception-free.
    Future<void> golden(
      WidgetTester tester,
      String name,
      Widget child, {
      Size size = const Size(400, 220),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: Center(child: child)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name'),
      );
    }

    testWidgets('brand_card', (tester) async {
      await golden(
        tester,
        'brand_card.png',
        BrandCard(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Brand card'),
          ),
        ),
      );
    });

    testWidgets('brand_chip', (tester) async {
      await golden(
        tester,
        'brand_chip.png',
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandChip(label: 'Filter'),
            const SizedBox(width: 8),
            BrandChip(label: 'Selected', selected: true, onTap: () {}),
          ],
        ),
      );
    });

    testWidgets('brand_badge', (tester) async {
      await golden(
        tester,
        'brand_badge.png',
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BrandBadge(label: 'Open'),
            SizedBox(width: 8),
            BrandBadge(label: 'Slow', tone: BadgeTone.warning),
            SizedBox(width: 8),
            BrandBadge(label: 'Closed', tone: BadgeTone.negative),
          ],
        ),
      );
    });

    testWidgets('price_tag', (tester) async {
      await golden(
        tester,
        'price_tag.png',
        const PriceTag(cents: 500, compareAtCents: 999, currencySymbol: r'$'),
      );
    });

    testWidgets('brand_divider solid', (tester) async {
      await golden(
        tester,
        'brand_divider_solid.png',
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[Text('above'), BrandDivider(), Text('below')],
        ),
      );
    });

    testWidgets('brand_divider dashed', (tester) async {
      await golden(
        tester,
        'brand_divider_dashed.png',
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('above'),
            BrandDivider.dashed(dashWidth: 6, dashGap: 4),
            Text('below'),
          ],
        ),
      );
    });
    testWidgets('info_banner', (tester) async {
      await golden(
        tester,
        'info_banner.png',
        InfoBanner(
          tone: InfoTone.success,
          title: 'Order updated',
          onDismiss: () {},
          child: const Text('Your order is being prepared.'),
        ),
      );
    });

    testWidgets('stat_tile', (tester) async {
      await golden(
        tester,
        'stat_tile.png',
        SizedBox(
          width: 200,
          child: StatTile(
            label: 'Orders',
            value: '128',
            icon: Icons.receipt_long,
            delta: '+12',
            onTap: () {},
          ),
        ),
      );
    });

    testWidgets('setting_tile', (tester) async {
      await golden(
        tester,
        'setting_tile.png',
        SettingTile(
          icon: Icons.settings,
          title: 'Notifications',
          subtitle: 'Push, email',
          onTap: () {},
        ),
      );
    });

    testWidgets('menu_tile', (tester) async {
      await golden(
        tester,
        'menu_tile.png',
        const MenuTile(
          title: 'Margherita',
          subtitle: 'Classic 12"',
          cents: 1250,
          compareAtCents: 1500,
          currencySymbol: r'$',
        ),
      );
    });

    testWidgets('section_header', (tester) async {
      await golden(
        tester,
        'section_header.png',
        const Padding(
          padding: EdgeInsets.all(16),
          child: SectionHeader(
            title: 'Popular',
            subtitle: 'Top picks',
            action: Text('See all'),
          ),
        ),
      );
    });

    testWidgets('gradient_scaffold', (tester) async {
      await golden(
        tester,
        'gradient_scaffold.png',
        const SizedBox(
          width: 400,
          height: 220,
          child: GradientScaffold(
            applyOverlay: false,
            body: Center(child: Text('Home')),
          ),
        ),
      );
    });

    testWidgets('quantity_stepper', (tester) async {
      await golden(
        tester,
        'quantity_stepper.png',
        QuantityStepper(value: 2, onChanged: (_) {}),
      );
    });
  });

  group('T-4 a11y sweep (L11: semantics handles on the interactive set)', () {
    // Enables the semantics tree for one pumped host and disposes the handle
    // BEFORE the test ends (the framework verifies disposal at test end).
    Future<void> a11yHost(WidgetTester tester, Widget child) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: Center(child: child)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      handle.dispose();
    }

    testWidgets('PriceTag merges the full formatted sentence', (tester) async {
      await a11yHost(
        tester,
        const PriceTag(cents: 500, compareAtCents: 999, currencySymbol: r'$'),
      );
      final SemanticsData priceData = tester
          .getSemantics(find.byType(PriceTag))
          .getSemanticsData();
      // The container label IS the full formatted sentence (the child Text
      // labels are merged after it by the framework — duplication is a
      // documented residual, not a missing handle).
      expect(
        priceData.label,
        startsWith(r'$5.00, was $9.99'),
        reason: 'one coherent amount, not fragments',
      );
      await a11yHost(tester, const PriceTag(cents: 500, currencySymbol: r'$'));
      final SemanticsData singleData = tester
          .getSemantics(find.byType(PriceTag))
          .getSemanticsData();
      expect(singleData.label, startsWith(r'$5.00'));
      expect(singleData.label, isNot(contains('was')));
    });

    testWidgets('QuantityStepper exposes tooltips on both controls', (
      tester,
    ) async {
      await a11yHost(tester, QuantityStepper(value: 2, onChanged: (_) {}));
      final buttons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .toList();
      expect(buttons.length, 2);
      expect(buttons.first.tooltip, kDefaultDecreaseTooltip);
      expect(buttons.last.tooltip, kDefaultIncreaseTooltip);
      // The BUTTON's semantics node carries the tooltip (the icon's own node
      // does not) — it must be exposed as a semantics label.
      final SemanticsData decData = tester
          .getSemantics(
            find.ancestor(
              of: find.byIcon(Icons.remove_circle_outline),
              matching: find.byType(IconButton),
            ),
          )
          .getSemanticsData();
      expect(
        '${decData.label} ${decData.tooltip}',
        contains(kDefaultDecreaseTooltip),
      );
      final SemanticsData incData = tester
          .getSemantics(
            find.ancestor(
              of: find.byIcon(Icons.add_circle_outline),
              matching: find.byType(IconButton),
            ),
          )
          .getSemanticsData();
      expect(
        '${incData.label} ${incData.tooltip}',
        contains(kDefaultIncreaseTooltip),
      );
      // L11 gate: both tap targets are >= 48 dp in BOTH axes.
      final Size decBox = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.remove_circle_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(decBox.width, greaterThanOrEqualTo(48));
      expect(decBox.height, greaterThanOrEqualTo(48));
      final Size incBox = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.add_circle_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(incBox.width, greaterThanOrEqualTo(48));
      expect(incBox.height, greaterThanOrEqualTo(48));
    });

    testWidgets('QuantityStepper disables at a bound (no tap path)', (
      tester,
    ) async {
      await a11yHost(tester, QuantityStepper(value: 0, onChanged: (_) {}));
      expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .map((IconButton b) => b.onPressed)
            .toList(),
        <Matcher>[isNull, isNotNull],
        reason: 'the button at a bound is disabled — out-of-range unreachable',
      );
      expect(
        _hasTapAction(
          tester
              .getSemantics(find.byIcon(Icons.remove_circle_outline))
              .getSemanticsData(),
        ),
        isFalse,
        reason: 'the disabled control exposes no tap action',
      );
    });
    testWidgets('chip + card expose tap semantics (and inert when null)', (
      tester,
    ) async {
      await a11yHost(tester, BrandChip(label: 'Filter', onTap: () {}));
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(InkWell)).getSemanticsData(),
        ),
        isTrue,
      );
      await a11yHost(tester, const BrandChip(label: 'Filter'));
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).onTap,
        isNull,
        reason: 'no onTap => no tap path exists at all',
      );
      await a11yHost(
        tester,
        BrandCard(onTap: () {}, child: const Text('card-body')),
      );
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(InkWell)).getSemanticsData(),
        ),
        isTrue,
      );
      await a11yHost(tester, const BrandCard(child: Text('card-body')));
      // With no onTap the card is inert: the ONLY tap surface is a real
      // InkWell when onTap is supplied — none exists otherwise (P5-13).
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('tile family exposes tap semantics (and inert when null)', (
      tester,
    ) async {
      await a11yHost(
        tester,
        StatTile(label: 'Orders', value: '128', onTap: () {}),
      );
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(InkWell)).getSemanticsData(),
        ),
        isTrue,
      );
      await a11yHost(
        tester,
        SettingTile(icon: Icons.settings, title: 'Notifications', onTap: () {}),
      );
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(InkWell)).getSemanticsData(),
        ),
        isTrue,
      );
      await a11yHost(
        tester,
        const MenuTile(title: 'Margherita', cents: 1250, onTap: null),
      );
      expect(find.byType(InkWell), findsNothing);
      await a11yHost(
        tester,
        StatusTile(status: TileStatus.ok, label: 'Live', onTap: () {}),
      );
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(InkWell)).getSemanticsData(),
        ),
        isTrue,
      );
      await a11yHost(
        tester,
        const SettingTile(icon: Icons.settings, title: 'Notifications'),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('InfoBanner dismiss exposes the tooltip + tap handle', (
      tester,
    ) async {
      await a11yHost(
        tester,
        InfoBanner(
          tone: InfoTone.info,
          onDismiss: () {},
          child: const Text('body'),
        ),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).tooltip,
        InfoBanner.kDefaultDismissTooltip,
      );
      final SemanticsData dismissData = tester
          .getSemantics(find.byType(IconButton))
          .getSemanticsData();
      expect(
        '${dismissData.label} ${dismissData.tooltip}',
        contains(InfoBanner.kDefaultDismissTooltip),
      );
      expect(_hasTapAction(dismissData), isTrue);
    });

    testWidgets('PressableScale forwards a tap handle via the gesture', (
      tester,
    ) async {
      await a11yHost(
        tester,
        PressableScale(onTap: () {}, child: const Text('pressable')),
      );
      expect(
        _hasTapAction(
          tester.getSemantics(find.byType(PressableScale)).getSemanticsData(),
        ),
        isTrue,
      );
    });
  });
}
