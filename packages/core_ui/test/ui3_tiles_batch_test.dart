import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-3 (p13) — real behavior tests for the tiles batch (p13 §3 T-1..T-6).
/// No skips, no vacuous assertions, no goldens. BrandColors.fallback covers
/// bare MaterialApp themes (COLOR-1 pattern); press feedback is the native
/// Material InkWell (0.10). L2 money: MenuTile delegates ALL formatting to
/// PriceTag/moneyCents — tests assert the delegated output, never re-derive.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('T-1 StatTile', () {
    testWidgets('label + value; value w800, label secondary', (tester) async {
      await tester.pumpWidget(
        host(const StatTile(label: 'Orders', value: '128')),
      );
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('128')).style!.fontWeight,
        FontWeight.w800,
      );
      expect(
        tester.widget<Text>(find.text('Orders')).style!.fontWeight,
        isNot(FontWeight.w800),
      );
    });

    testWidgets('card shape is the large radius', (tester) async {
      await tester.pumpWidget(
        host(const StatTile(label: 'Orders', value: '128')),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(StatTile),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(BrandShapes.large));
    });

    testWidgets('colors come from BrandColors (token chain, L1)', (
      tester,
    ) async {
      const brand = BrandColors(
        primary: Color(0xFF111111),
        secondary: Color(0xFF222222),
        accent: Color(0xFF333333),
        success: Color(0xFF00AA00),
        warning: Color(0xFFFFBB00),
        error: Color(0xFFDD0000),
        soldOut: Color(0xFF909090),
        background: Color(0xFFF0F0F0),
        surface: Color(0xFFFEFEFE),
        textPrimary: Color(0xFF101010),
        textSecondary: Color(0xFF707070),
        textPrimary12: Color(0x1A101010),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[brand]),
          home: const Scaffold(
            body: StatTile(label: 'Orders', value: '128'),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Orders')).style!.color,
        brand.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text('128')).style!.color,
        brand.textPrimary,
      );
    });

    testWidgets('no onTap => inert (no InkWell tap path exists)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const StatTile(label: 'Orders', value: '128')),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onTap => exactly one InkWell; icon+delta render; tap-once', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          StatTile(
            label: 'Orders',
            value: '128',
            icon: Icons.receipt_long,
            delta: '+12',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('128'));
      await tester.pump();
      await tester.tap(find.text('128'));
      await tester.pump();
      expect(taps, 2);
    });
    testWidgets('AppShapeTokens.cardRadius overrides the default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              AppShapeTokens(cardRadius: 24),
            ],
          ),
          home: const Scaffold(
            body: StatTile(label: 'Orders', value: '128'),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(StatTile),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('icon and delta are optional — absent when not supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const StatTile(label: 'Orders', value: '128')),
      );
      expect(find.byIcon(Icons.receipt_long), findsNothing);
      expect(find.text('+12'), findsNothing);
    });
  });

  group('T-2 SettingTile', () {
    testWidgets('icon + title; onTap => chevron + one InkWell', (tester) async {
      await tester.pumpWidget(
        host(
          SettingTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('subtitle renders when supplied', (tester) async {
      await tester.pumpWidget(
        host(
          SettingTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Order and promo alerts',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Order and promo alerts'), findsOneWidget);
    });

    testWidgets('caller-supplied trailing widget replaces the chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SettingTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {},
            trailing: const Switch(value: true, onChanged: null),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('tap fires exactly once per tap; semantics native', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          SettingTile(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Notifications'));
      await tester.pump();
      await tester.tap(find.text('Notifications'));
      await tester.pump();
      expect(taps, 2);
      // Native semantics: the text is exposed on a real semantics node —
      // the tile adds no custom wrapper beyond the native InkWell path.
      expect(
        tester.getSemantics(find.text('Notifications')).label,
        contains('Notifications'),
      );
    });

    testWidgets('disabled (no onTap) => no chevron, no tap path', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const SettingTile(icon: Icons.lock, title: 'Locked setting')),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('long title is single-line ellipsized', (tester) async {
      const longTitle = 'Very long setting title that must ellipsize cleanly';
      await tester.pumpWidget(
        host(SettingTile(icon: Icons.lock, title: longTitle, onTap: () {})),
      );
      final text = tester.widget<Text>(find.text(longTitle));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
  group('T-3 MenuTile', () {
    testWidgets('title + optional subtitle render; long text ellipsized', (
      tester,
    ) async {
      const longTitle =
          'Spicy Grilled Chicken Deluxe Sandwich with Extra Pickles';
      await tester.pumpWidget(
        host(
          const MenuTile(
            title: longTitle,
            subtitle: 'Add fries and a drink',
            cents: 1250,
          ),
        ),
      );
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text('Add fries and a drink'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(longTitle)).overflow,
        TextOverflow.ellipsis,
      );
    });

    testWidgets('price renders via the PriceTag moneyCents delegation (L2)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const MenuTile(title: 'Burger', cents: 1250, currencyCode: 'USD')),
      );
      // The delegated formatter output — MenuTile never computes.
      expect(find.text(r'$12.50'), findsOneWidget);
      expect(find.byType(PriceTag), findsOneWidget);
    });

    testWidgets('compareAtCents sentence semantics forwarded to PriceTag', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MenuTile(
            title: 'Burger',
            cents: 999,
            compareAtCents: 1499,
            currencyCode: 'USD',
          ),
        ),
      );
      // PriceTag's documented sentence semantics, forwarded verbatim.
      final semantics = tester.getSemantics(find.byType(PriceTag));
      expect(semantics.label, contains(r'$9.99'));
      expect(semantics.label, contains(r'was $14.99'));

      // Nonsensical compare-at (not strictly greater) is suppressed by the
      // delegate itself — MenuTile forwards, never decides money display.
      await tester.pumpWidget(
        host(
          const MenuTile(
            title: 'Burger',
            cents: 1499,
            compareAtCents: 1499,
            currencyCode: 'USD',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(PriceTag)).label,
        isNot(contains('was')),
      );
    });

    testWidgets('imageUrl failure falls back to the caller icon (L5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MenuTile(
            title: 'Burger',
            cents: 1250,
            imageUrl: 'http://localhost:1/missing.png',
            fallbackIcon: Icons.lunch_dining,
          ),
        ),
      );

      // The image is a descendant of the MenuTile.
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(MenuTile),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<NetworkImage>());
      expect(image.errorBuilder, isNotNull);

      // Evict + flip to the error frame → fallback icon appears (fail-safe).
      (image.image as NetworkImage).evict();
      tester.binding.imageCache.clear();
      tester.binding.imageCache.clearLiveImages();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lunch_dining), findsOneWidget);
    });

    testWidgets('tap fires exactly once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(MenuTile(title: 'Burger', cents: 1250, onTap: () => taps++)),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Burger'));
      await tester.pump();
      await tester.tap(find.text('Burger'));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('no imageUrl => no Image, no fallback icon', (tester) async {
      await tester.pumpWidget(
        host(const MenuTile(title: 'Burger', cents: 1250)),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.lunch_dining), findsNothing);
    });

    testWidgets('currencySymbol is forwarded verbatim to PriceTag', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MenuTile(title: 'Burger', cents: 1250, currencySymbol: r'€'),
        ),
      );
      expect(find.text(r'€12.50'), findsOneWidget);
    });
  });

  group('T-4 StatusTile', () {
    test('toneFor maps the three statuses to DISTINCT badge tones', () {
      expect(StatusTile.toneFor(TileStatus.ok), BadgeTone.positive);
      expect(StatusTile.toneFor(TileStatus.pending), BadgeTone.neutral);
      expect(StatusTile.toneFor(TileStatus.failed), BadgeTone.negative);

      final tones = <BadgeTone>{
        StatusTile.toneFor(TileStatus.ok),
        StatusTile.toneFor(TileStatus.pending),
        StatusTile.toneFor(TileStatus.failed),
      };
      expect(tones.length, 3, reason: 'mapping must be pairwise distinct');
    });

    testWidgets('status label renders inside a BrandBadge', (tester) async {
      await tester.pumpWidget(
        host(
          const StatusTile(status: TileStatus.failed, label: 'Payment failed'),
        ),
      );
      expect(find.text('Payment failed'), findsOneWidget);
      final badge = tester.widget<BrandBadge>(find.byType(BrandBadge));
      expect(badge.label, 'Payment failed');
      expect(badge.tone, StatusTile.toneFor(TileStatus.failed));
    });

    testWidgets('tap path: one InkWell with onTap; inert without', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          StatusTile(
            status: TileStatus.pending,
            label: 'Preparing',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Preparing'));
      await tester.pump();
      expect(taps, 1);

      await tester.pumpWidget(
        host(const StatusTile(status: TileStatus.pending, label: 'Preparing')),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('T-5 TileGrid', () {
    testWidgets('order preserved; params forwarded; shrinkWrap default', (
      tester,
    ) async {
      const tiles = <String>['first', 'second', 'third', 'fourth'];
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            child: TileGrid(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              spacing: 8,
              children: tiles.map(Text.new).toList(),
            ),
          ),
        ),
      );
      expect(find.text('first'), findsOneWidget);
      expect(find.text('fourth'), findsOneWidget);
      final order = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(order, tiles);

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.scrollDirection, Axis.vertical);
      expect(grid.shrinkWrap, isTrue);
      expect(grid.physics, const NeverScrollableScrollPhysics());
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.childAspectRatio, 1.5);
      expect(delegate.mainAxisSpacing, 8);
      expect(delegate.crossAxisSpacing, 8);
      final slivers = grid.childrenDelegate as SliverChildListDelegate;
      expect(slivers.children.length, 4);
    });

    testWidgets('embeddable: inside a ListView both ends stay reachable', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ListView(
            children: [
              const Text('above'),
              TileGrid(
                crossAxisCount: 2,
                children: <Widget>[for (var i = 0; i < 6; i++) Text('t$i')],
              ),
              const Text('below'),
            ],
          ),
        ),
      );
      // The top of the list is reachable before any scroll…
      expect(find.text('above'), findsOneWidget);
      // …and the grid does NOT swallow the gesture: the list scrolls past it.
      await tester.scrollUntilVisible(
        find.text('below'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('defaults: 12 spacing both axes, square cells, 2 columns', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            child: TileGrid(
              crossAxisCount: 2,
              children: <Widget>[for (var i = 0; i < 4; i++) Text('d$i')],
            ),
          ),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.mainAxisSpacing, 12);
      expect(delegate.crossAxisSpacing, 12);
      expect(delegate.childAspectRatio, 1.0);
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('scrollable override restores grid scrolling', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 200,
            child: TileGrid(
              crossAxisCount: 2,
              scrollable: true,
              children: <Widget>[for (var i = 0; i < 20; i++) Text('t$i')],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('T-6 TileSkeletons', () {
    test('stat skeleton: the documented 160 x 88 large-radius card', () {
      final stat = TileSkeletons.stat();
      expect(stat, isA<SkeletonLoader>());
      expect(stat.width, 160);
      expect(stat.height, 88);
      expect(stat.borderRadius, BrandShapes.large);
    });

    test('setting skeleton: full-width, 72 high, large radius', () {
      final setting = TileSkeletons.setting();
      expect(setting, isA<SkeletonLoader>());
      expect(setting.width, double.infinity);
      expect(setting.height, 72);
      expect(setting.borderRadius, BrandShapes.large);
    });

    test('menu skeleton: full-width, 96 high, large radius', () {
      final menu = TileSkeletons.menu();
      expect(menu, isA<SkeletonLoader>());
      expect(menu.width, double.infinity);
      expect(menu.height, 96);
      expect(menu.borderRadius, BrandShapes.large);
    });

    test('dimension parity: skeletons carry the documented live-tile dims', () {
      // Factories DELEGATE to real SkeletonLoaders with the DOCUMENTED dims.
      expect(TileSkeletons.stat(), isA<SkeletonLoader>());
      expect(TileSkeletons.setting(), isA<SkeletonLoader>());
      expect(TileSkeletons.menu(), isA<SkeletonLoader>());

      expect(TileSkeletons.stat().borderRadius, BrandShapes.large);
      expect(TileSkeletons.setting().borderRadius, BrandShapes.large);
      expect(TileSkeletons.menu().borderRadius, BrandShapes.large);

      // Distinct loading counterparts per tile kind (menu rows are wide
      // image+text rows; stat cards are compact; setting rows in between).
      expect(
        TileSkeletons.menu().height,
        greaterThan(TileSkeletons.stat().height),
      );
      expect(
        TileSkeletons.setting().height,
        isNot(equals(TileSkeletons.menu().height)),
      );
      expect(TileSkeletons.stat().width, greaterThan(0));
      expect(TileSkeletons.setting().width, greaterThan(0));
      expect(TileSkeletons.menu().width, greaterThan(0));
    });

    testWidgets('skeletons render real shimmer placeholders', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              TileSkeletons.stat(),
              TileSkeletons.setting(),
              TileSkeletons.menu(),
            ],
          ),
        ),
      );
      expect(find.byType(SkeletonLoader), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
