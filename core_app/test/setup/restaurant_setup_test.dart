import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/presentation/setup/restaurant_setup_screen.dart';

void main() {
  // ────────────── RestaurantConfigModel Unit Tests ──────────────────────
  group('RestaurantConfigModel', () {
    test('fromFirestore uses defaults when document is empty', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      // Simulate an empty Firestore doc
      final snap = fakeFirestore.collection('settings').doc('restaurantConfig');
      final snapshot = await snap.get();
      final config = RestaurantConfigModel.fromFirestore(snapshot);
      // This will hit the catch / empty path, defaults should apply
      expect(config.currency, 'USD');
      expect(config.pointsPerDollar, 10);
      expect(config.minimumOrderCents, 0);
    });

    test('defaults are sane for a US Starter tier restaurant', () {
      const config = RestaurantConfigModel();
      expect(config.currency, 'USD');
      expect(config.notificationTone, 'casual');
      expect(config.notificationOptIn, 'after_first_order');
      expect(config.tipEnabled, true);
      expect(config.deliveryFeeType, 'flat');
      expect(config.loyaltyProgramName, 'Rewards');
      expect(config.signupBonusPoints, 0);
    });

    test('copyWith correctly mutates specific fields', () {
      const original = RestaurantConfigModel();
      final updated = original.copyWith(
        restaurantName: 'Taco Palace',
        currency: 'GBP',
        pointsPerDollar: 20,
      );
      expect(updated.restaurantName, 'Taco Palace');
      expect(updated.currency, 'GBP');
      expect(updated.pointsPerDollar, 20);
      // Unchanged fields preserved
      expect(updated.tipEnabled, true);
      expect(updated.deliveryFeeType, 'flat');
    });

    test('toFirestore round-trips all fields correctly', () {
      const config = RestaurantConfigModel(
        restaurantName: 'Carnama Kitchen',
        currency: 'USD',
        minimumOrderCents: 1500,
        deliveryFeeCents: 299,
        pointsPerDollar: 10,
        redemptionThresholdPoints: 500,
        socialLinks: {'instagram': 'https://instagram.com/carnama'},
      );
      final map = config.toFirestore();
      expect(map['restaurantName'], 'Carnama Kitchen');
      expect(map['currency'], 'USD');
      expect(map['minimumOrderCents'], 1500);
      expect(map['deliveryFeeCents'], 299);
      expect(
        (map['socialLinks'] as Map)['instagram'],
        'https://instagram.com/carnama',
      );
    });

    test(
      'operatingHours round-trips through toFirestore/fromFirestore',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        const hoursModel = OperatingHoursModel(
          monday: DayHours(isOpen: true, openTime: '08:00', closeTime: '21:00'),
          sunday: DayHours(isOpen: false),
        );
        final hoursMap = hoursModel.toMap();
        final config = RestaurantConfigModel(operatingHours: hoursMap);
        final map = config.toFirestore();
        expect(map['operatingHours'], isNotNull);

        await fakeFirestore
            .collection('settings')
            .doc('restaurantConfig')
            .set(map);
        final snap = await fakeFirestore
            .collection('settings')
            .doc('restaurantConfig')
            .get();
        final restored = RestaurantConfigModel.fromFirestore(snap);
        expect(restored.operatingHours, isNotEmpty);
        final hours = OperatingHoursModel.fromMap(restored.operatingHours);
        expect(hours.monday.openTime, '08:00');
        expect(hours.monday.closeTime, '21:00');
        expect(hours.sunday.isOpen, false);
      },
    );
  });

  // ────────────── OperatingHoursModel Unit Tests ────────────────────────
  group('OperatingHoursModel', () {
    test('default hours are sensible', () {
      const hours = OperatingHoursModel();
      expect(hours.monday.isOpen, true);
      expect(hours.monday.openTime, '09:00');
      expect(hours.saturday.openTime, '10:00');
      expect(hours.holidayModeEnabled, false);
    });

    test('fromMap and toMap round-trip correctly', () {
      const original = OperatingHoursModel(holidayModeEnabled: true);
      final map = original.toMap();
      final restored = OperatingHoursModel.fromMap(map);
      expect(restored.holidayModeEnabled, true);
      expect(restored.monday.openTime, '09:00');
      expect(restored.saturday.openTime, '10:00');
    });

    test('entries list contains all 7 days in order', () {
      const hours = OperatingHoursModel();
      final names = hours.entries.map((e) => e.$1).toList();
      expect(names, [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ]);
    });

    test('DayHours copyWith updates only specified fields', () {
      const day = DayHours(isOpen: true, openTime: '09:00', closeTime: '22:00');
      final updated = day.copyWith(isOpen: false);
      expect(updated.isOpen, false);
      expect(updated.openTime, '09:00');
      expect(updated.closeTime, '22:00');
    });

    test('fromMap handles missing keys gracefully', () {
      final result = OperatingHoursModel.fromMap({});
      expect(result.monday.isOpen, true);
      expect(result.holidayModeEnabled, false);
    });
  });

  // P9 W1 (T-5): the AllergenDisclaimerBanner widget group was deleted with
  // the dead banner itself (zero production importers — the widget was never
  // mounted by any screen; tests of dead code are test-theater).
  // PERF-10 closure (O-1 = owner Option B): the `allergenDisclaimerEnabled`
  // config field was then REMOVED entirely from RestaurantConfigModel, the
  // RestaurantSetupScreen toggle, and l10n — the no-op round-trip is gone,
  // pinned by the banned-identifier scan in `core_app/test/app/deleted_sources_pin_test.dart`.

  group('RestaurantSetupScreen widget', () {
    // W2.9: RestaurantSetupScreen is owner-gated — authorize the RoleGate.
    final ownerOverride = currentUserProvider.overrideWith(
      (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
    );

    testWidgets('renders all 6 tabs in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restaurantConfigProvider.overrideWith(
              (_) => Stream.value(const RestaurantConfigModel()),
            ),
            ownerOverride,
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RestaurantSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Loyalty'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Social & Legal'), findsOneWidget);
      expect(find.text('Hours'), findsOneWidget);
    });

    testWidgets('Brand tab shows identity field labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restaurantConfigProvider.overrideWith(
              (_) => Stream.value(const RestaurantConfigModel()),
            ),
            ownerOverride,
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RestaurantSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restaurant Name *'), findsOneWidget);
      expect(find.text('Support Email'), findsOneWidget);
    });

    testWidgets('shows loading indicator when config is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restaurantConfigProvider.overrideWith((_) => const Stream.empty()),
            ownerOverride,
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RestaurantSetupScreen(),
          ),
        ),
      );
      await tester.pump();
      // E1 F3-09: the config loading branch renders the library skeleton.
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
