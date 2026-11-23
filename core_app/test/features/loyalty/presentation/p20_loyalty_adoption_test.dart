// UI-10 (p20) Phase D — loyalty adoption: the points/tier metrics become
// StatTile cards (D1) and the loading state becomes L12 tile skeletons (D2).
// Written RED before the wiring (p20 §3 phase D).
//
// L14: the PERF-1 H-3 forged-negative clamp is a MODEL concern — this file
// re-asserts the rendered strings ('0 points' / 'BRONZE') so the restyle can
// never re-open that leak.
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/loyalty/presentation/loyalty_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

/// Signed-in customer with a deterministic loyalty stream.
Widget _screen({required Stream<LoyaltyModel> loyalty}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(MockUser(uid: 'u-1', email: 'customer@test.com')),
      ),
      userLoyaltyProvider.overrideWith((ref) => loyalty),
      restaurantConfigProvider.overrideWith(
        (ref) => Stream.value(const RestaurantConfigModel()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoyaltyScreen(),
    ),
  );
}

void main() {
  group('p20 D — loyalty adoption', () {
    testWidgets('D1: the points metric renders through a StatTile with the '
        'canonical localized string', (tester) async {
      await tester.pumpWidget(
        _screen(
          loyalty: Stream.value(
            const LoyaltyModel(totalPoints: 2100, uid: 'u-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<StatTile>(find.byType(StatTile));
      expect(
        tile.value,
        '2100 points',
        reason: 'the tile carries the exact localized metric string',
      );
      expect(find.text('2100 points'), findsOneWidget);
      // The tier headline survives the metric restyle.
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('D1: the surface enters through StaggeredEntrance (L12.3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          loyalty: Stream.value(
            const LoyaltyModel(totalPoints: 250, uid: 'u-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StaggeredEntrance), findsOneWidget);
      expect(find.byType(StatTile), findsOneWidget);
    });

    testWidgets('D2: the loading state renders tile skeletons, not a spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(loyalty: const Stream<LoyaltyModel>.empty()),
      );
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Shimmer repeats forever — unmount so no ticker outlives the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the tier + points semantics survive the restyle (L14)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _screen(
            loyalty: Stream.value(
              const LoyaltyModel(totalPoints: 2100, uid: 'u-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp('Current tier: Gold')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('2100 points')), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the forged-negative clamp still renders "0 points" / BRONZE', (
      tester,
    ) async {
      final forged = LoyaltyModel.fromJson({
        'uid': 'u-atk',
        'totalPoints': -50,
      });
      await tester.pumpWidget(_screen(loyalty: Stream.value(forged)));
      await tester.pumpAndSettle();

      expect(find.textContaining('-50'), findsNothing);
      expect(find.text('0 points'), findsOneWidget);
      expect(find.text('BRONZE'), findsOneWidget);
    });
  });
}
