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
import 'package:labs/features/home/presentation/home_feed_showcase.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/l10n/app_localizations.dart';

/// PERF-5 T-4: the pilot `showcase` variant's visual regression guard.
/// The items carry NO imageUrl, so every card renders its deterministic
/// icon fallback (no network state in the golden). Light + dark pairs,
/// same discipline as the house goldens (Laws 6, 17).
void main() {
  final items = <MenuItemModel>[
    const MenuItemModel(
      id: 'm1',
      name: 'Margherita Pizza',
      category: 'pizza',
      priceCents: 1500,
    ),
    const MenuItemModel(
      id: 'm2',
      name: 'Salmon Roll',
      category: 'sushi',
      priceCents: 3500,
    ),
    const MenuItemModel(
      id: 'm3',
      name: 'Truffle Feast',
      category: 'feast',
      priceCents: 4900,
    ),
  ];

  Widget showcaseHarness({ThemeMode themeMode = ThemeMode.light}) {
    final firestore = FakeFirebaseFirestore();
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
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(slivers: [ShowcaseHomeFeed(items: items)]),
        ),
      ),
    );
  }

  testWidgets('showcase variant golden — light mode baseline', (tester) async {
    await tester.pumpWidget(showcaseHarness());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // p16 C3 (mechanical timing update): the showcase rows carry the grid's
    // flutter_animate entrance (L12.3) — drain it so the golden captures the
    // SETTLED state, never a mid-fade frame.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_showcase_variant.png'),
    );
  });

  testWidgets('showcase variant golden — dark mode (Law 6)', (tester) async {
    await tester.pumpWidget(showcaseHarness(themeMode: ThemeMode.dark));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // p16 C3 (mechanical timing update): see the light-mode twin above.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_showcase_variant_dark.png'),
    );
  });
}
