import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/owner/tabs/menu_item_editor.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_menu_tab.dart';

import 'owner_test_harness.dart';

/// p28 lane B (T-4) — owner_menu_tab.dart had 16 executable lines at DA:0:
/// the list separator, both sheet entry points (add/edit), the availability
/// switch write-through and the confirmed delete. One operator journey each.
void main() {
  setUpAll(setUpOwnerFirebase);

  late FakeFirebaseFirestore db;

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
  });

  Future<void> seedMenu() async {
    await db.collection('menus').doc('m1').set(<String, Object?>{
      'name': 'Pizza',
      'priceCents': 1250,
      'isAvailable': true,
    });
    await db.collection('menus').doc('m2').set(<String, Object?>{
      'name': 'Burger',
      'priceCents': 800,
      'isAvailable': false,
    });
  }

  testWidgets('two items render with a separator; switches mirror the store', (
    tester,
  ) async {
    await seedMenu();
    await tester.pumpWidget(ownerHarness(db, const OwnerMenuTab()));
    await tester.pumpAndSettle();

    expect(find.byType(MenuTile), findsNWidgets(2));
    expect(
      find.byType(Divider),
      findsOneWidget,
      reason: 'separator for 2 rows',
    );
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
  });

  testWidgets('the add action opens an empty item editor', (tester) async {
    await seedMenu();
    await tester.pumpWidget(ownerHarness(db, const OwnerMenuTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemEditor), findsOneWidget);
    // 5 since P6-1: name, price, description, tags, cross-contamination notes.
    expect(find.byType(BrandTextField), findsNWidgets(5));
    expect(find.widgetWithText(BrandTextField, 'Pizza'), findsNothing);
  });

  testWidgets('the edit action opens the editor prefilled from the store', (
    tester,
  ) async {
    await seedMenu();
    await tester.pumpWidget(ownerHarness(db, const OwnerMenuTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemEditor), findsOneWidget);
    expect(
      find.widgetWithText(BrandTextField, 'Pizza'),
      findsOneWidget,
      reason: 'name field prefilled from the stored item',
    );
  });

  testWidgets('flipping the availability switch writes through to the store', (
    tester,
  ) async {
    await seedMenu();
    await tester.pumpWidget(ownerHarness(db, const OwnerMenuTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first); // Pizza: true -> false
    await tester.pumpAndSettle();

    final snap = await db.collection('menus').doc('m1').get();
    expect(snap.data()?['isAvailable'], isFalse, reason: 'write-through');
  });

  testWidgets('a confirmed delete removes the item from the store', (
    tester,
  ) async {
    await seedMenu();
    await tester.pumpWidget(ownerHarness(db, const OwnerMenuTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNWidgets(2));

    await tester.tap(find.byType(TextButton).last); // confirm
    await tester.pumpAndSettle();

    final surviving = await db.collection('menus').get();
    expect(
      surviving.docs.map((doc) => doc.id),
      <String>['m2'],
      reason: 'confirmed delete removes exactly the chosen item',
    );
    final deleted = await db.collection('menus').doc('m1').get();
    expect(deleted.exists, isFalse, reason: 'm1 is gone');
  });
}
