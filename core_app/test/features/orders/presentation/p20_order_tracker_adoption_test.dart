// UI-10 (p20) Phase B — order-tracker adoption (InfoBanner status header +
// PriceTag total + skeletons). Written RED before the wiring (p20 §3 phase B).
//
// L16 SANCTUARY: this file only asserts PRESENTATION. The tracker's state
// logic, timers and listeners are untouched — the state-machine suites and the
// step live-region semantics are the sanctuary guards, asserted here too so a
// future regression is caught.
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:labs/app/config/currency_format.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/orders/data/order_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart';
import 'package:labs/features/orders/presentation/order_tracker_steps_widget.dart';
import 'package:labs/l10n/app_localizations.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

OrderModel _order({
  String id = 'ord-1',
  OrderStatus status = OrderStatus.preparing,
  int totalCents = 2500,
}) => OrderModel(
  id: id,
  customerId: 'user-1',
  status: status,
  totalCents: totalCents,
  createdAt: DateTime(2026, 9, 27),
);

/// [currency] drives the config provider the total reads; a null code means the
/// provider never emits, so the documented `$` fallback renders.
Widget _harness(
  String orderId,
  OrderRepository repo, {
  String? currency,
  bool loading = false,
}) => ProviderScope(
  key: ValueKey<String>('p20-tracker-${currency ?? 'fallback'}-$loading'),
  overrides: [
    orderRepositoryProvider.overrideWithValue(repo),
    restaurantConfigProvider.overrideWith(
      (ref) => currency == null || loading
          ? const Stream<RestaurantConfigModel>.empty()
          : Stream<RestaurantConfigModel>.value(
              RestaurantConfigModel(currency: currency),
            ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: OrderTrackerScreen(orderId: orderId),
  ),
);

void main() {
  group('p20 B — tracker tone mapping (pure)', () {
    test('trackerInfoToneFor is total over OrderStatus', () {
      for (final status in OrderStatus.values) {
        expect(
          trackerInfoToneFor(status),
          isA<InfoTone>(),
          reason: '$status must resolve a banner tone',
        );
      }
      expect(trackerInfoToneFor(OrderStatus.cancelled), InfoTone.error);
      expect(trackerInfoToneFor(OrderStatus.delivered), InfoTone.success);
      expect(trackerInfoToneFor(OrderStatus.preparing), InfoTone.info);
      expect(trackerInfoToneFor(OrderStatus.ready), InfoTone.warning);
    });
  });

  group('p20 B — tracker adoption', () {
    testWidgets('B1: the status header is an InfoBanner with the status tone', (
      tester,
    ) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('ord-1'),
      ).thenAnswer((_) => Stream.value(_order()));

      await tester.pumpWidget(_harness('ord-1', repo, currency: 'USD'));
      await tester.pumpAndSettle();

      expect(find.byType(InfoBanner), findsOneWidget);
      final banner = tester.widget<InfoBanner>(find.byType(InfoBanner));
      expect(banner.tone, trackerInfoToneFor(OrderStatus.preparing));
      expect(banner.title, 'Delivery Status');
    });

    testWidgets('B1: the total renders through PriceTag, byte-identical to '
        'formatCurrencyCents (L13 parity)', (tester) async {
      const codes = <String?>[null, 'USD', 'AED', 'SAR', 'usd', 'XYZ'];
      const centsSet = [2500, 1234567, 0];

      for (final code in codes) {
        for (final cents in centsSet) {
          final repo = MockOrderRepository();
          when(
            () => repo.streamOrder('ord-1'),
          ).thenAnswer((_) => Stream.value(_order(totalCents: cents)));

          await tester.pumpWidget(_harness('ord-1', repo, currency: code));
          await tester.pumpAndSettle();

          expect(
            tester.widget<PriceTag>(find.byType(PriceTag)).cents,
            cents,
            reason: 'cents forwarded verbatim — never recomputed',
          );
          expect(
            find.text(formatCurrencyCents(cents, currencyCode: code)),
            findsOneWidget,
            reason: 'PriceTag($code, $cents) must render the canonical string',
          );
        }
      }
    });

    testWidgets('B1: the loading state renders tile skeletons', (tester) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('ord-1'),
      ).thenAnswer((_) => const Stream<OrderModel>.empty());

      await tester.pumpWidget(_harness('ord-1', repo, loading: true));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Shimmer repeats forever — unmount so no ticker outlives the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('B2: the step live-region semantics survive the restyle', (
      tester,
    ) async {
      final repo = MockOrderRepository();
      when(
        () => repo.streamOrder('ord-1'),
      ).thenAnswer((_) => Stream.value(_order()));

      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_harness('ord-1', repo, currency: 'USD'));
        await tester.pumpAndSettle();

        // preparing = index 2 → "Step 3 of 8", selected + live region.
        final currentFinder = find.bySemanticsLabel(RegExp('Step 3 of 8'));
        expect(currentFinder, findsOneWidget);
        final node = tester.getSemantics(currentFinder);
        expect(node.flagsCollection.isLiveRegion, isTrue);
        expect(node.flagsCollection.isHeader, isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'B2: the steps widget keeps its glassmorphism + animated containers '
      '(frozen visual contract)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: OrderTrackerStepsWidget(
                order: _order(),
                currentStatus: OrderStatus.preparing,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsWidgets);
      },
    );
  });
}
