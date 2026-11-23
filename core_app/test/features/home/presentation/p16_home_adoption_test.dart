// UI-6 (p16) Phase C — home adoption (feed cards -> BrandCard composition,
// feed section header -> SectionHeader, BOTH variants re-rendered). Written
// RED before the wiring (p16 §3 phase C).
//
// Scope notes (honest, per spec C1/C2/C3):
//  * C1 adopts BrandCard-based composition for BOTH feed cards: the default
//    2-column grid tile (home_screen.dart) and the showcase row
//    (home_feed_showcase.dart). MenuTile is deliberately NOT chosen: these
//    feed cards are image-block compositions (grid: image above the details;
//    showcase: 96x96 block beside them) with an add-to-cart affordance —
//    the spec names BrandCard as the primary primitive ("BrandCard-based
//    composition ... or MenuTile where the content is a dish"); the dish ROW
//    surfaces already adopted MenuTile in phase A.
//  * Prices keep `formatCurrencyCents` untouched this phase (C1/C2 name no
//    money component; L13 parity therefore holds by NOT touching the money
//    lines at all — the gate receipt proves it by diff).
//  * The search tab's ListTile rows are NOT feed cards — out of C's scope.
//  * L12.3: the grid's existing flutter_animate stagger must survive; the
//    showcase list (motionless before) adopts the same stagger.
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
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/screen_variants.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kImageUrl =
    'https://res.cloudinary.com/carnama/image/upload/v1721000000/menu/margherita.jpg';

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
    'branchId': null,
    if (imageUrl != null) 'imageUrl': imageUrl,
  });
}

/// Localized harness; [variantTable] resolves the showcase variant through
/// the registry (same override path as home_variant_test.dart). No override
/// = the byte-for-byte default ('grid').
Widget _homeHarness(
  FakeFirebaseFirestore firestore, {
  Map<String, String>? variantTable,
}) {
  SharedPreferences.setMockInitialValues({kGdprAnalyticsConsentKey: true});
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
      if (variantTable != null)
        screenVariantsProvider.overrideWithValue(variantTable),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
  );
}

/// Two settle pumps: the menu/promotion streams resolve on the fake
/// Firestore's async bridge and the post-frame consent no-op completes.
Future<void> _settleHome(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Drains flutter_animate's post-rebuild zero-duration Timers and the
/// fade/slide effect windows (~1000 ms worst case), so no Timer survives the
/// test-teardown pending-timer assertion (home-suite house pattern).
Future<void> _settleAnimate(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1000));
}

/// The transport-blocked thumbnail errored into the fallback, which makes
/// flutter_cache_manager schedule its one-shot 10 s cleanup Timer — the
/// home-suite drains it with a final 15 s pump (then 400 ms for the frame).
Future<void> _drainImageCache(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 15));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P16 C — home adoption', () {
    testWidgets(
      'C1: the default grid composes its feed cards from BrandCard — Hero, '
      'entrance motion, composed add-to-cart semantics and the snackbar path '
      'all survive',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        await _seedItem(
          firestore,
          id: 'm1',
          name: 'Margherita Pizza',
          category: 'pizza',
          priceCents: 1500,
          imageUrl: _kImageUrl,
        );
        await _seedItem(
          firestore,
          id: 'm2',
          name: 'Salmon Roll',
          category: 'sushi',
          priceCents: 3500,
        );

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_homeHarness(firestore));
        await _settleHome(tester);

        // C1: the feed cards ARE BrandCard compositions (RED before wiring).
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SliverGrid),
            matching: find.byType(BrandCard),
          ),
          findsNWidgets(2),
          reason: 'C1: both grid tiles are BrandCard compositions',
        );
        expect(
          find.byType(Card),
          findsNothing,
          reason: 'C1: the hand-rolled feed Card is replaced, not stacked',
        );

        // L14 preservation through the new composition:
        //  * Hero tag on the dish image (only m1 carries an imageUrl).
        expect(find.byType(Hero), findsOneWidget);
        expect(
          tester.widget<Hero>(find.byType(Hero)).tag,
          'm1',
          reason: 'L14: the dish-image Hero tag survives the re-composition',
        );
        //  * L12.3: the grid keeps its entrance motion (flutter_animate
        //    stagger — the preservation branch of the law).
        expect(
          find.byType(Animate),
          findsWidgets,
          reason: 'L12.3: the grid keeps its entrance motion',
        );

        // Let the entrance complete before reading semantics: RenderOpacity
        // (FadeTransition) intentionally EXCLUDES child semantics while
        // alpha == 0 (Flutter SDK, proxy_box.dart visitChildrenForSemantics),
        // so the composed label is only exposed at the STEADY STATE — the
        // state a screen reader actually meets. Menu's A1 asserts the same
        // way (after settle).
        await _settleAnimate(tester);

        //  * the composed Semantics label on the add affordance (en copy).
        //    The card's texts merge into the SAME semantics node ahead of it
        //    with '\n' separators — asserted as the anchored full label (the
        //    menu A1 test asserts its merge the same way).
        expect(
          find.bySemanticsLabel(
            RegExp(
              r'^Margherita Pizza\n\$15\.00\nAdd Margherita Pizza to cart$',
            ),
          ),
          findsOneWidget,
          reason: 'L14: the composed add-to-cart semantics label is preserved',
        );

        // Behavior: the add button still fires the haptic+snackbar path.
        // The grid tile's details sit below the initial fold — scroll the
        // button into view first (dish-detail house pattern), then tap.
        await tester.ensureVisible(find.byIcon(Icons.add_circle).first);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byIcon(Icons.add_circle).first);
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Margherita Pizza'),
          findsWidgets,
          reason: 'the localized "added" snackbar names the dish',
        );

        await _drainImageCache(tester);
        handle.dispose();
      },
    );

    testWidgets(
      'C2/C3: the showcase variant renders its section header through '
      'SectionHeader and its rows through BrandCard, with entrance motion '
      'adopted and the grid chrome gone',
      (tester) async {
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

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _homeHarness(
            firestore,
            variantTable: const {
              ScreenVariants.homeScreenId: ScreenVariants.homeShowcaseVariant,
            },
          ),
        );
        await _settleHome(tester);

        // C2: the feed's section title renders through SectionHeader with the
        // caller-supplied localized string (RED before wiring).
        expect(find.byType(SectionHeader), findsOneWidget);
        expect(
          tester.widget<SectionHeader>(find.byType(SectionHeader)).title,
          'Showcase',
          reason:
              'C2: the l10n string stays caller-supplied via AppLocalizations',
        );
        expect(
          find.text('Showcase'),
          findsOneWidget,
          reason: 'the header still renders its visible title',
        );

        // C1: showcase rows are BrandCard compositions too.
        expect(
          find.byType(BrandCard),
          findsNWidgets(2),
          reason: 'C1: both showcase rows are BrandCard compositions',
        );
        expect(
          find.byType(Card),
          findsNothing,
          reason: 'C1: the hand-rolled showcase Card is replaced, not stacked',
        );

        // C3: the variant contract holds — no default-grid chrome leaks in.
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.text('Margherita Pizza'), findsOneWidget);
        expect(find.text('Salmon Roll'), findsOneWidget);

        // L12.3: the showcase list (motionless before) adopts the grid's
        // entrance stagger.
        expect(
          find.byType(Animate),
          findsWidgets,
          reason: 'L12.3: the showcase list gains an entrance motion',
        );

        // Steady-state semantics (see the grid test): FadeTransition hides
        // child semantics while alpha == 0, so read them after the entrance.
        await _settleAnimate(tester);

        // L14: the composed add-to-cart semantics label on the showcase card
        // (suffix-anchored: the card's own texts may merge ahead of it with
        // '\n' separators — same merge pattern as the grid / menu A1).
        expect(
          find.bySemanticsLabel(RegExp(r'(^|\n)Add Margherita Pizza to cart$')),
          findsOneWidget,
        );

        // Behavior: the showcase card's add button still fires the snackbar.
        await tester.tap(find.byIcon(Icons.add_circle).first);
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);

        handle.dispose();
      },
    );
  });
}
