@Tags(['e2e', 'needs-emulator'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labs/main.dart' as app;

// CARNAMA CONSTITUTION Law 30: Centralized test infrastructure
import 'test_helpers/emulator_bootstrap.dart';
import 'test_helpers/navigation.dart';

/// Law 30 (Realtime Streams) + Law 34 (Live Updates)
///
/// Proves that a headless Firestore write to the emulator while the screen
/// is open causes the UI to update automatically WITHOUT a manual refresh.
/// The visible Text.data contents joined - failure evidence so a silent
/// empty or wrong screen names itself inside the assertion reason
/// (pattern proven in admin_e2e_flow_test's stage probes).
String _visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((d) => d.isNotEmpty)
    .join(' | ');

void main() {
  // CARNAMA CONSTITUTION Law 30: Bind exclusively to the emulator
  setUpAll(() async {
    await bootstrapEmulators();
  });

  group('Realtime Firestore → UI Update Tests (Laws 30, 34)', () {
    testWidgets('Headless write to emulator triggers live UI update', (
      tester,
    ) async {
      // 1. Launch the app against the emulator
      await app.main();
      // CARNAMA CONSTITUTION Law 8: Add timeout to prevent infinite hang
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 2. The dish does not exist yet: home renders the menu-empty state
      // (home_screen.dart:478-486, icon Icons.restaurant_menu). The bottom
      // shell has NO Menu tab — the customer menu IS the home feed, so this
      // suite's realtime proof starts from the empty state here. (The
      // restaurant_menu icon in that empty state is DECORATIVE: tapping it
      // never navigates — the first "green" attempts died asserting on a
      // screen that was never opened; receipt: green_r2_realtime_final.txt
      // tooltip dump showed only the shell nav, zero menu-row affordances.)

      // 3. Write directly to the emulated Firestore - HEADLESS (server-side
      // via emulator-admin REST): an unauthenticated client write is
      // correctly denied by firestore.rules (Law 12), and the harness must
      // never weaken them. The server-side change still fires the live
      // listener this test proves (red:
      // green_r2_realtime_dotenvfix.txt PERMISSION_DENIED at :40).
      // Collection is `menus` (menu_repository.dart:112 /
      // merged_menu_provider.dart:193 - the streams the UI actually watches),
      // NOT the `menu_items` name this suite guessed before it ever ran.
      // branchId is written as EXPLICIT null - production docs come from
      // freezed toJson (includeIfNull), and the stream filters
      // `where('branchId', isNull: true)`; an ABSENT field never matched
      // (red: greenv4 "Menu is empty" + probe showed branchId ABSENT).
      const testItemName = 'Realtime Test Dish';
      final itemId = await emulatorAdminCreateDocument(
        collection: 'menus',
        fields: {
          'name': testItemName,
          'priceCents': 999,
          'description': 'Added by integration test',
          'isAvailable': true,
          'modifiers': <Object>[],
          'imageUrl': '',
          'branchId': null,
        },
      );
      // A failed assertion below must NOT leak this doc into the next
      // boot/suite (red: greenv6's inline-only cleanup never ran, the
      // leftover flipped home's state and broke greenv7 line 44).
      // emulatorAdminDeleteDocument is 404-tolerant, so the inline delete
      // at the end of this test plus this teardown both converge cleanly.
      addTearDown(
        () => emulatorAdminDeleteDocument(
          collection: 'menus',
          documentId: itemId,
        ),
      );

      // 4. Wait for the real-time listener to propagate, then assert the
      // new item is visible in the home feed WITHOUT a manual refresh.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        find.text(testItemName),
        findsOneWidget,
        reason:
            'Real-time Firestore write must appear in UI without manual '
            'refresh; on-screen texts: ${_visibleTexts(tester)}',
      );

      // 5. Open the dish detail — the surface that renders availability:
      // dish_detail_screen.dart:243-254 draws the sold-out notice as a
      // VISIBLE Text(loc.soldOut(item.name)) ("{item} is sold out",
      // app_en.arb:152) and watches menuItemByIdProvider
      // (menu_provider.dart:26-35 → mergedMenuProvider stream), so the
      // headless update below flows live. The home grid tile
      // (home_screen.dart:592-645) carries no sold-out affordance at all.
      // 5. Navigate to the menu screen through the REAL production router
      // (`/menu` is public — app_router.dart:289 publicPaths — so a guest
      // reaches it). It renders the sold-out affordance as the add-button's
      // Semantics label + IconButton tooltip (menu_screen.dart:258-306).
      // The home grid tile carries none (home_screen.dart:592-645), and
      // dish detail is auth-gated (router redirect sends guests to /login —
      // red: green_r2_realtime_v13.txt), so the menu screen is the
      // guest-reachable availability surface.
      await tester.goToMenuScreen();
      expect(
        find.text(testItemName),
        findsOneWidget,
        reason:
            'the live dish must be listed on the menu screen; '
            'on-screen texts: ${_visibleTexts(tester)}',
      );

      // 6. Update availability → mark as unavailable
      await emulatorAdminUpdateDocument(
        collection: 'menus',
        documentId: itemId,
        fields: {'isAvailable': false},
      );

      // 7. The live update must reach the menu screen's add-button label:
      // menu_screen.dart:258-263 computes isSoldOut from !item.isAvailable
      // and renders loc.soldOut(item.name) ("{item} is sold out",
      // app_en.arb:152) as the IconButton tooltip (menu_screen.dart:306) —
      // never a Text, so byTooltip is the exact surface.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        find.byTooltip('$testItemName is sold out'),
        findsOneWidget,
        reason:
            'isAvailable: false must render the sold-out button label; '
            'on-screen texts: ${_visibleTexts(tester)}',
      );

      // Cleanup: remove the test doc
      await emulatorAdminDeleteDocument(
        collection: 'menus',
        documentId: itemId,
      );
    });

    testWidgets('Non-existent document read — UI does not hang or crash', (
      tester,
    ) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Attempt to read a doc that definitely does not exist. `menus` is the
      // PUBLICLY readable collection (v13: guests CAN read menus) - reading
      // a missing doc here exercises the true "non-existent document" path;
      // the old `orders` choice made this a permission-denied test instead
      // (guests CANNOT read orders), never reaching the assertion.
      final snap = await FirebaseFirestore.instance
          .collection('menus')
          .doc('DOES_NOT_EXIST_9999')
          .get();

      expect(snap.exists, isFalse);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Non-existent doc read must not crash the app',
      );
    });
  });
}
