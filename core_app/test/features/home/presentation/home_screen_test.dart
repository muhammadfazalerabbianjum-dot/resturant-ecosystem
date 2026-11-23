import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart'
    show
        cloudinaryThumb,
        currentUserProvider,
        deadLetterCountProvider,
        firestoreProvider,
        kGdprAnalyticsConsentKey,
        loggerProvider,
        LoggerService,
        pendingSyncCountProvider;
import 'package:core_ui/core_ui.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/home/domain/home_service.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// COV-3 — HomeScreen real-behavior tests (replaces the B4-era smoke
/// type-checks). Every test drives the REAL production widgets over a
/// hermetic [FakeFirebaseFirestore]: the merged menu stream, the category
/// chips (HomeService.filterByCategory / filterByMaxPrice), the hero promo
/// carousel (HomeService.getPromotions) and the STATE-3 cloudinaryThumb
/// application sites (feed w_400, search row w_100).
///
/// Harness discipline:
///  * The GDPR consent chain is pre-decided through the CANONICAL key
///    (kGdprAnalyticsConsentKey) so showIfNeeded no-ops — never a literal.
///  * pendingSyncCount/deadLetterCount streams are overridden to 0 so the
///    PendingSyncBanner never constructs the real Isar singleton in tests.
///  * currentUserProvider is overridden to a signed-out user: the banner's
///    role branch is exercised, FirebaseAuth is never touched.
///  * NO pumpAndSettle while the hero carousel is mounted: its periodic 5 s
///    timer re-schedules animation frames forever. Explicit pumps only.
///  * CachedNetworkImage attempts are transport-blocked by the global
///    network blocker; flutter_cache_manager schedules a one-shot cleanup
///    Timer (10 s interval) on its first cache lookup, so image tests drain
///    it with a final 15 s pump before the pending-timer assertion.

const String _kRawCloudinaryUrl =
    'https://res.cloudinary.com/carnama/image/upload/v1721000000/menu/margherita.jpg';
const String _kForeignUrl = 'https://cdn.example.com/upload/margherita.jpg';

/// Fault-injection double for the honest promo-failure state: production
/// wiring everywhere, only getPromotions throws (repository-layer chaos, the
/// repo's documented failure-simulation convention).
class _BrokenPromotionsHomeService extends HomeService {
  _BrokenPromotionsHomeService({
    required super.firestore,
    required super.logger,
  });

  @override
  Future<List<HomePromotion>> getPromotions() async {
    throw StateError('chaos: promotions query broken');
  }
}

/// Deterministic logger for the failure-path test: the production catch block
/// in _loadPromotions AWAITS logger.error(..) which performs real file I/O +
/// Crashlytics; under the fake-async test clock that real I/O completion is
/// not clock-bound, so the *write* is stubbed (the screen's catch->setState
/// handling under test is untouched).
class _ImmediateLoggerService extends LoggerService {
  _ImmediateLoggerService()
    : super(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}
}

Future<void> _seedItem(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  required String category,
  required int priceCents,
  String? imageUrl,
}) async {
  await firestore.collection('menus').doc(id).set({
    'name': name,
    'category': category,
    'priceCents': priceCents,
    'isAvailable': true,
    // null branchId = global item (mergedMenuProvider's global stream).
    'branchId': null,
    if (imageUrl != null) 'imageUrl': imageUrl,
  });
}

Future<void> _seedPromotion(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String title,
  required int priority,
}) async {
  await firestore.collection('promotions').doc(id).set({
    'title': title,
    'subtitle': '',
    'isActive': true,
    'priority': priority,
  });
}

Future<Widget> _homeHarness(
  FakeFirebaseFirestore firestore, {
  LoggerService? logger,
  HomeService? homeService,
}) async {
  SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
  final resolvedLogger =
      logger ??
      LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(resolvedLogger),
      currentUserProvider.overrideWith((ref) async => null),
      pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      deadLetterCountProvider.overrideWith((ref) => Stream<int>.value(0)),
      if (homeService != null)
        homeServiceProvider.overrideWithValue(homeService),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
  );
}

/// Two settle pumps: the menu/config/promotion streams resolve on the fake
/// Firestore's async bridge and the post-frame consent no-op completes.
Future<void> _settleHome(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Lets flutter_animate's post-rebuild zero-duration Timers fire and their
/// fade/slide effects complete (~300 ms worst case for the feed cards), so
/// no Timer survives the test-teardown pending-timer assertion.
Future<void> _settleAnimate(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1000));
}

void main() {
  group('HomeScreen — feed grid (mergedMenuProvider)', () {
    testWidgets('renders the seeded menu items from the real stream', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(find.text('Salmon Roll'), findsOneWidget);
    });

    testWidgets('category chip filters the grid; deselecting restores', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      await tester.tap(find.text('Sushi'));
      await tester.pump();

      expect(find.text('Salmon Roll'), findsOneWidget);
      expect(find.text('Margherita Pizza'), findsNothing);

      // Deselect restores the unfiltered grid.
      await tester.tap(find.text('Sushi'));
      await tester.pump();
      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(find.text('Salmon Roll'), findsOneWidget);

      // The rebuild armed flutter_animate's post-frame Timer — drain it.
      await _settleAnimate(tester);
    });

    testWidgets('the price-band chip is labeled with the configured amount', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      // No settings/restaurantConfig doc -> the model's default threshold
      // (freeDeliveryThresholdCents = 3000) governs the under_30 filter.
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Budget Bento',
        category: 'snacks',
        priceCents: 2500,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Deluxe Feast',
        category: 'feast',
        priceCents: 4500,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      await tester.tap(find.text(r'Under $30.00'));
      await tester.pump();

      expect(find.text('Budget Bento'), findsOneWidget);
      expect(find.text('Deluxe Feast'), findsNothing);

      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, r'Under $30.00'),
      );
      expect(chip.selected, isTrue);

      await _settleAnimate(tester);
    });

    testWidgets('chips derive from the LIVE menu — no demo categories (P2-1)', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Charcoal Kofta',
        category: 'grill',
        priceCents: 1200,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Baklava',
        category: 'Desserts',
        priceCents: 400,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      // The chips are the OWNER's categories (known demo-era keys localize,
      // unknown values title-case) — pizza/sushi/vegan no longer render
      // unless the menu actually carries them.
      expect(find.widgetWithText(FilterChip, 'Grill'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Desserts'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, r'Under $30.00'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Pizza'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Sushi'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Vegan'), findsNothing);

      await _settleAnimate(tester);
    });

    testWidgets('an empty menu renders no category chips at all (P2-1)', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(EmptyStateWidget), findsOneWidget);

      await _settleAnimate(tester);
    });
  });

  group('HomeScreen — hero promo carousel (getPromotions)', () {
    testWidgets('renders the seeded promotions', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedPromotion(
        firestore,
        id: 'p1',
        title: 'Summer Sale',
        priority: 10,
      );
      await _seedPromotion(
        firestore,
        id: 'p2',
        title: 'Winter Deal',
        priority: 5,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      expect(find.byType(PageView), findsOneWidget);
      // Page 0 is the current page — its promo card is on stage.
      expect(find.text('Summer Sale'), findsOneWidget);
    });

    testWidgets('auto-advances to the next promo on its 5 s tick', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedPromotion(
        firestore,
        id: 'p1',
        title: 'Summer Sale',
        priority: 10,
      );
      await _seedPromotion(
        firestore,
        id: 'p2',
        title: 'Winter Deal',
        priority: 5,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      // The periodic hero timer fires at +5 s and animates for 400 ms.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Winter Deal'), findsOneWidget);
    });

    testWidgets('promotions fetch failure surfaces the honest error state', (
      tester,
    ) async {
      final logger = _ImmediateLoggerService();
      final broken = _BrokenPromotionsHomeService(
        firestore: FakeFirebaseFirestore(),
        logger: logger,
      );
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );

      await tester.pumpWidget(
        await _homeHarness(firestore, logger: logger, homeService: broken),
      );
      await _settleHome(tester);
      // The failure path runs catch -> await logger.error -> setState; give
      // that extra async chain its own settle turn.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Could not load promotions.'), findsOneWidget);
      // The rest of the feed is unaffected by the promo failure.
      expect(find.text('Margherita Pizza'), findsOneWidget);
    });
  });

  group('HomeScreen — STATE-3 thumbnails + search', () {
    testWidgets(
      'feed grid downloads CDN thumbnails (w_400), foreign URLs pass',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await _seedItem(
          firestore,
          id: 'm1',
          name: 'Margherita Pizza',
          category: 'pizza',
          priceCents: 1500,
          imageUrl: _kRawCloudinaryUrl,
        );
        await _seedItem(
          firestore,
          id: 'm2',
          name: 'Foreign Pie',
          category: 'pizza',
          priceCents: 1500,
          imageUrl: _kForeignUrl,
        );

        await tester.pumpWidget(await _homeHarness(firestore));
        await _settleHome(tester);

        // STATE-3 (04-P1-IMG): the feed's CachedNetworkImage receives the
        // cloudinaryThumb-transformed URL (w_400,q_auto,f_auto), never the raw
        // full-resolution original.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CachedNetworkImage &&
                w.imageUrl == cloudinaryThumb(_kRawCloudinaryUrl, width: 400),
          ),
          findsOneWidget,
        );
        // A foreign CDN URL must pass through untouched at the widget site.
        expect(
          find.byWidgetPredicate(
            (w) => w is CachedNetworkImage && w.imageUrl == _kForeignUrl,
          ),
          findsOneWidget,
        );

        // Drain flutter_cache_manager's 10 s cleanup Timer so the test ends
        // with zero pending timers (the image fetches were transport-blocked
        // and already errored into their errorWidgets).
        await tester.pump(const Duration(seconds: 15));
      },
    );

    testWidgets('search tab filters in-situ and shows the empty state', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Margherita Pizza',
        category: 'pizza',
        priceCents: 1500,
      );
      await _seedItem(
        firestore,
        id: 'm2',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      // Open the Search tab (NavigationBar destination index 1).
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'sal');
      await tester.pump();

      // Search result rows are MenuTiles (UI-13 p21 H2: the hand-rolled
      // `Card` > `ListTile` row adopted the frozen MenuTile; the feed is a
      // grid), so this scoped finder is unambiguous even while the feed stays
      // mounted. Assertion strength is unchanged — a row that contains the
      // title exists / does not exist.
      expect(find.widgetWithText(MenuTile, 'Salmon Roll'), findsOneWidget);
      expect(find.widgetWithText(MenuTile, 'Margherita Pizza'), findsNothing);
      // Non-empty query arms the clear affordance.
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.widgetWithText(MenuTile, 'Salmon Roll'), findsNothing);
      expect(find.text('No items found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      await _settleAnimate(tester);
    });

    testWidgets('search rows download CDN thumbnails (w_100)', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedItem(
        firestore,
        id: 'm1',
        name: 'Salmon Roll',
        category: 'sushi',
        priceCents: 3500,
        imageUrl: _kRawCloudinaryUrl,
      );

      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'sal');
      await tester.pump();

      // STATE-3 (04-P1-IMG): the 56px search row uses w_100.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CachedNetworkImage &&
              w.imageUrl == cloudinaryThumb(_kRawCloudinaryUrl, width: 100),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 15));
    });
  });

  group('HomeScreen — search tab top-inset safety', () {
    testWidgets('the search field clears the system status bar (no overlap)', (
      tester,
    ) async {
      // Emulated capture geometry: 1280×2856 physical @3.0 with a 48
      // logical px status-bar inset (= 144 PHYSICAL px — FakeViewPadding
      // takes physical pixels, like FlutterView.padding). The shell only
      // owns an AppBar on the home tab, so pre-fix the AppBar-less search
      // tab laid its field out at dy=12 — under the inset (the device
      // screenshot 19 defect).
      tester.view.physicalSize = const Size(1280, 2856);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 144);
      addTearDown(tester.view.reset);

      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(await _homeHarness(firestore));
      await _settleHome(tester);

      await tester.tap(find.byIcon(Icons.search).first);
      await _settleHome(tester);

      final field = find.byType(TextField);
      expect(field, findsOneWidget);

      final fieldTop = tester.getTopLeft(field).dy;
      expect(
        fieldTop,
        greaterThanOrEqualTo(48.0),
        reason:
            'the search field must start below the 48px status bar — the '
            'shell SafeArea(top) owns this for AppBar-less tabs',
      );

      await _settleAnimate(tester);
    });
  });
}
