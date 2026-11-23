// UI-10 (p20) Phase A — order-history adoption (SettingTile rows + BrandBadge
// state + PriceTag totals + SectionHeader status groups + tile skeletons +
// StaggeredEntrance). Written RED before the wiring (p20 §3 phase A); the A2
// money-parity table is the mandatory L13 guard, and the pure group/tone
// mappings are the A1 spot-check surface.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

OrderModel _order({
  required String id,
  OrderStatus status = OrderStatus.pending,
  int totalCents = 1234,
}) => OrderModel(
  id: id,
  status: status,
  totalCents: totalCents,
  createdAt: DateTime(2026, 9, 27),
);

/// Localized harness. [currency] drives the config provider the production row
/// reads (W9.3 config-driven currency); a null code means the provider never
/// emits, so `valueOrNull?.currency` resolves to the documented `$` fallback.
Widget _harness({
  required List<OrderModel> orders,
  String? currency,
  bool loading = false,
}) {
  final router = GoRouter(
    initialLocation: '/orders',
    routes: [
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (_, __) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/tracker/:orderId',
        name: 'orderTracker',
        builder: (_, state) =>
            Scaffold(body: Text('Tracker ${state.pathParameters['orderId']}')),
      ),
    ],
  );

  return ProviderScope(
    // Riverpod applies `overrides` when the ProviderContainer is created, so
    // re-keying the scope per currency gives every iteration a FRESH container
    // (otherwise the A2 loop would silently reuse the first currency).
    key: ValueKey<String>(
      'p20-${currency ?? 'fallback'}-$loading-${orders.length}',
    ),
    overrides: [
      userOrdersProvider.overrideWith(
        (ref) => loading
            ? const Stream<List<OrderModel>>.empty()
            : Stream.value(orders),
      ),
      restaurantConfigProvider.overrideWith(
        (ref) => currency == null || loading
            ? const Stream<RestaurantConfigModel>.empty()
            : Stream<RestaurantConfigModel>.value(
                RestaurantConfigModel(currency: currency),
              ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  group('p20 A — order-history pure mappings (A1 status mapping)', () {
    test('orderHistoryGroupFor groups every status into exactly one group', () {
      expect(
        orderHistoryGroupFor(OrderStatus.pending),
        OrderHistoryGroup.active,
      );
      expect(
        orderHistoryGroupFor(OrderStatus.confirmed),
        OrderHistoryGroup.active,
      );
      expect(
        orderHistoryGroupFor(OrderStatus.preparing),
        OrderHistoryGroup.active,
      );
      expect(
        orderHistoryGroupFor(OrderStatus.cooking),
        OrderHistoryGroup.active,
      );
      expect(orderHistoryGroupFor(OrderStatus.ready), OrderHistoryGroup.active);
      expect(
        orderHistoryGroupFor(OrderStatus.pickedUp),
        OrderHistoryGroup.active,
      );
      expect(
        orderHistoryGroupFor(OrderStatus.delivered),
        OrderHistoryGroup.delivered,
      );
      expect(
        orderHistoryGroupFor(OrderStatus.cancelled),
        OrderHistoryGroup.cancelled,
      );
      // Every enum member resolves (no silent default bucket).
      expect(
        OrderStatus.values.map(orderHistoryGroupFor).toSet(),
        OrderHistoryGroup.values.toSet(),
      );
    });

    test('orderHistoryToneFor reuses the frozen StatusTile tone mapping', () {
      for (final status in OrderStatus.values) {
        expect(
          orderHistoryToneFor(status),
          StatusTile.toneFor(_expectedTileStatus(status)),
          reason: 'the badge tone must come from the frozen StatusTile map',
        );
      }
      expect(orderHistoryToneFor(OrderStatus.delivered), BadgeTone.positive);
      expect(orderHistoryToneFor(OrderStatus.cancelled), BadgeTone.negative);
      expect(orderHistoryToneFor(OrderStatus.pending), BadgeTone.neutral);
    });
  });

  group('p20 A — order-history adoption', () {
    testWidgets('A2: totals render through PriceTag, byte-identical to '
        'formatCurrencyCents across the supported code set (L13 parity)', (
      tester,
    ) async {
      // The L13 edge set: the null-code $ fallback, known codes, a
      // lower-case code and an unknown code (fail-closed CODE prefix).
      const codes = <String?>[null, 'USD', 'AED', 'SAR', 'JPY', 'usd', 'XYZ'];
      const centsSet = [1250, 1234567, 0];

      for (final code in codes) {
        final orders = [
          for (var i = 0; i < centsSet.length; i++)
            _order(id: 'o$i', totalCents: centsSet[i]),
        ];
        await tester.pumpWidget(_harness(orders: orders, currency: code));
        await tester.pumpAndSettle();

        // RED signal: the history rows must adopt the library PriceTag.
        expect(
          find.byType(PriceTag),
          findsNWidgets(centsSet.length),
          reason: 'every order total must render via PriceTag (code=$code)',
        );
        expect(
          tester
              .widgetList<PriceTag>(find.byType(PriceTag))
              .map((t) => t.cents)
              .toList(),
          centsSet,
          reason: 'cents forwarded verbatim — never recomputed (code=$code)',
        );

        for (final cents in centsSet) {
          final expected = formatCurrencyCents(cents, currencyCode: code);
          expect(
            find.text(expected),
            findsOneWidget,
            reason: 'PriceTag($code, $cents) must render exactly "$expected"',
          );
        }
      }
    });

    testWidgets('A1: rows compose SettingTile + BrandBadge + PriceTag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          orders: [
            _order(id: 'a1', status: OrderStatus.pending, totalCents: 900),
            _order(id: 'b2', status: OrderStatus.delivered, totalCents: 1500),
            _order(id: 'c3', status: OrderStatus.cancelled, totalCents: 700),
          ],
          currency: 'USD',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingTile), findsNWidgets(3));
      expect(find.byType(BrandBadge), findsNWidgets(3));
      expect(find.byType(PriceTag), findsNWidgets(3));

      final tones = tester
          .widgetList<BrandBadge>(find.byType(BrandBadge))
          .map((b) => b.tone)
          .toList();
      expect(tones, [
        BadgeTone.neutral,
        BadgeTone.positive,
        BadgeTone.negative,
      ]);
    });

    testWidgets(
      'A1: rows group under SectionHeaders in Active -> Delivered -> Cancelled '
      'order',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            orders: [
              _order(id: 'a1', status: OrderStatus.pending),
              _order(id: 'b2', status: OrderStatus.delivered),
              _order(id: 'c3', status: OrderStatus.cancelled),
            ],
            currency: 'USD',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SectionHeader), findsNWidgets(3));
        final titles = tester
            .widgetList<SectionHeader>(find.byType(SectionHeader))
            .map((h) => h.title)
            .toList();
        // Headers are localized labels, never raw enum identifiers.
        for (final title in titles) {
          expect(title, isNotEmpty);
          expect(title, isNot(contains('OrderStatus')));
        }
        expect(find.text('Active Orders'), findsOneWidget);

        // One header per group: two rows sharing a status render ONE header.
        await tester.pumpWidget(
          _harness(
            orders: [
              _order(id: 'd1', status: OrderStatus.preparing),
              _order(id: 'd2', status: OrderStatus.ready),
            ],
            currency: 'USD',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SectionHeader), findsOneWidget);
        expect(find.byType(SettingTile), findsNWidgets(2));
      },
    );

    testWidgets('A1: the composed row Semantics label is preserved', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _harness(
            orders: [
              _order(
                id: 'ZZZ1',
                status: OrderStatus.delivered,
                totalCents: 1250,
              ),
            ],
            currency: 'USD',
          ),
        );
        await tester.pumpAndSettle();

        final loc = AppLocalizations.of(
          tester.element(find.byType(OrderHistoryScreen)),
        );
        final expected =
            '${loc.orderNumber('ZZZ1')}, '
            '${orderStatusLabel(loc, OrderStatus.delivered)}, '
            '${formatCurrencyCents(1250, currencyCode: 'USD')}';
        expect(
          // The composed label leads the node; the tile's own texts merge in
          // behind it with '\n' separators (asserted as an anchored prefix,
          // the p16 menu-row pattern).
          find.bySemanticsLabel(RegExp('^${RegExp.escape(expected)}')),
          findsOneWidget,
          reason: 'the composed row label (order, status, total) must survive',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('A1: tapping a row still routes to the tracker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          orders: [_order(id: 'TAP1', status: OrderStatus.ready)],
          currency: 'USD',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SettingTile));
      await tester.pumpAndSettle();

      expect(find.text('Tracker TAP1'), findsOneWidget);
    });

    testWidgets('A2: the loading state renders tile skeletons', (tester) async {
      await tester.pumpWidget(_harness(orders: const [], loading: true));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);

      // Shimmer repeats forever — unmount so no ticker outlives the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('A3: the list enters through StaggeredEntrance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          orders: [
            _order(id: 'e1'),
            _order(id: 'e2'),
          ],
          currency: 'USD',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StaggeredEntrance), findsOneWidget);
    });
  });
}

TileStatus _expectedTileStatus(OrderStatus status) => switch (status) {
  OrderStatus.pending => TileStatus.pending,
  OrderStatus.confirmed => TileStatus.pending,
  OrderStatus.preparing => TileStatus.pending,
  OrderStatus.cooking => TileStatus.pending,
  OrderStatus.ready => TileStatus.pending,
  OrderStatus.pickedUp => TileStatus.pending,
  OrderStatus.delivered => TileStatus.ok,
  OrderStatus.cancelled => TileStatus.failed,
};
