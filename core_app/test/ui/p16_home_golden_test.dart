/// UI-6 (p16) Phase C — before/after golden pairs for BOTH home variants (C3).
///
/// The grid pair (the byte-for-byte default: configs without variant keys) and
/// the showcase pair render the REAL HomeScreen through the screen-variant
/// registry (the same override path home_variant_test.dart drives). Items
/// carry NO imageUrl, so every card paints the deterministic icon fallback
/// (no network state in the golden — house discipline); one seeded promo
/// keeps the hero band stable.
///
/// Both captures are archived into tool_uilib/p16/visual_review/ as
/// before/after pairs for the owner's appeal verdict (L12.6). Explicit pumps
/// only — the hero carousel's 5 s periodic timer must never be settled past
/// (home-suite pattern); flutter_animate's entrance stagger is drained before
/// the snapshot.
library;

import 'dart:io';

import 'package:core/core.dart'
    show
        currentUserProvider,
        deadLetterCountProvider,
        firestoreProvider,
        kGdprAnalyticsConsentKey,
        loggerProvider,
        LoggerService,
        pendingSyncCountProvider;
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/config/screen_variants.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _items = <MenuItemModel>[
  MenuItemModel(
    id: 'g1',
    name: 'Truffle Burger',
    description: 'Smashed patty, truffle aioli',
    priceCents: 1850,
    category: 'mains',
    isAvailable: true,
  ),
  MenuItemModel(
    id: 'g2',
    name: 'Margherita Pizza',
    description: 'San Marzano, fior di latte',
    priceCents: 1599,
    category: 'pizza',
    isAvailable: true,
  ),
  MenuItemModel(
    id: 'g3',
    name: 'Salmon Roll',
    description: 'Cut to order',
    priceCents: 3500,
    category: 'sushi',
    isAvailable: true,
  ),
];

/// Full-screen harness: real menu/promotion streams over a hermetic fake
/// Firestore, deterministic USD money rendering, GDPR pre-decided, and the
/// pending-sync/DLQ streams pinned to 0 (home-suite house overrides).
/// [variantTable] null = the byte-for-byte default grid.
Future<Widget> _homeGoldenHarness({Map<String, String>? variantTable}) async {
  SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
  final firestore = FakeFirebaseFirestore();
  for (final item in _items) {
    await firestore.collection('menus').doc(item.id).set({
      'name': item.name,
      'category': item.category,
      'priceCents': item.priceCents,
      'isAvailable': true,
      'branchId': null,
    });
  }
  await firestore.collection('promotions').doc('p1').set({
    'title': 'Fresh from the kitchen',
    'subtitle': '',
    'isActive': true,
    'priority': 1,
  });
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      ),
      currentUserProvider.overrideWith((ref) async => null),
      pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      restaurantConfigProvider.overrideWith(
        (ref) => Stream<RestaurantConfigModel>.value(
          const RestaurantConfigModel(currency: 'USD'),
        ),
      ),
      if (variantTable != null)
        screenVariantsProvider.overrideWithValue(variantTable),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
}

/// Streams resolve + consent no-op + flutter_animate stagger drain + a
/// residual frame — all explicit, never pumpAndSettle (hero timer).
Future<void> _settleGolden(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P16 home grid golden — adoption pair (default variant)', (
    tester,
  ) async {
    await tester.pumpWidget(await _homeGoldenHarness());
    await _settleGolden(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SliverGrid), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p16_home_grid.png'),
    );
  });

  testWidgets('P16 home showcase golden — adoption pair (variant=showcase)', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _homeGoldenHarness(
        variantTable: const {
          ScreenVariants.homeScreenId: ScreenVariants.homeShowcaseVariant,
        },
      ),
    );
    await _settleGolden(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Showcase'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p16_home_showcase.png'),
    );
  });
}
