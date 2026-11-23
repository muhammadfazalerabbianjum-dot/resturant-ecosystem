/// UI-6 (p16) Phase A — before/after golden pair for the MENU screen.
///
/// The baseline in `goldens/p16_menu_screen.png` is re-captured deliberately
/// once per phase (red = pre-wiring look, green = adoption look); both
/// captures are copied into `tool_uilib/p16/visual_review/` for the owner's
/// appeal verdict (L12.6). Items are transport-blocked so the thumbnail
/// fallback path renders deterministically.
library;

import 'dart:io';

import 'package:core/core.dart'
    show
        currentUserProvider,
        deadLetterCountProvider,
        firestoreProvider,
        loggerProvider,
        LoggerService,
        pendingSyncCountProvider;
import 'package:core_ui/src/theme/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

void main() {
  testWidgets('P16 menu screen golden — adoption pair', (tester) async {
    final items = <MenuItemModel>[
      const MenuItemModel(
        id: 'g1',
        name: 'Truffle Burger',
        description: 'Smashed patty, truffle aioli',
        priceCents: 1850,
        category: 'mains',
        tags: ['popular'],
        isAvailable: true,
      ),
      const MenuItemModel(
        id: 'g2',
        name: 'Margherita Pizza',
        description: 'San Marzano, fior di latte',
        priceCents: 1599,
        category: 'pizza',
        isAvailable: true,
      ),
      const MenuItemModel(
        id: 'g3',
        name: 'Salmon Roll',
        description: 'Sold out today',
        priceCents: 3500,
        category: 'sushi',
        isAvailable: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mergedMenuProvider.overrideWith((ref) => Stream.value(items)),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          loggerProvider.overrideWithValue(
            LoggerService(
              testDirectory: Directory.systemTemp.createTempSync(
                'carnama_logs_',
              ),
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
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MenuScreen(),
        ),
      ),
    );
    await tester.pump();
    // Explicit pumps (home-suite pattern): pumpAndSettle never settles while
    // the transport-blocked thumbnail's skeleton shimmer is visible.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // Drain flutter_cache_manager's one-shot 10 s cleanup Timer (the
    // transport-blocked image fetch already errored into the fallback).
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/p16_menu_screen.png'),
    );
  });
}
