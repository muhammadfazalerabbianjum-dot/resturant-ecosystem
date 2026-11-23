import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart' show DeliveryLocationModel;
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/owner/tabs/branch_editor.dart';

import 'owner_test_harness.dart';

/// p28 lane B (T-4) — branch_editor.dart had 25 executable lines at DA:0:
/// the whole `_save()` body (data build → store write → pop → spinner
/// reset), the pin-drop result handling and the default-switch toggle.
/// Each test drives one real journey through the shared owner harness.
void main() {
  setUpAll(setUpOwnerFirebase);

  late FakeFirebaseFirestore db;

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
  });

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      ownerLauncherHarness(
        db,
        openLabel: 'open editor',
        buildSubject: () => const BranchEditor(),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    expect(find.byType(BranchEditor), findsOneWidget);
    expect(find.byType(BrandTextField), findsNWidgets(5));
  }

  testWidgets(
    'saving the typed branch writes every field and closes the sheet',
    (tester) async {
      await openEditor(tester);

      await tester.enterText(find.byType(EditableText).at(0), 'New Branch');
      await tester.enterText(find.byType(EditableText).at(1), '10 New Rd');
      await tester.enterText(find.byType(EditableText).at(2), '24.500000');
      await tester.enterText(find.byType(EditableText).at(3), '67.250000');
      await tester.enterText(find.byType(EditableText).at(4), '7.5');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      await tester.tap(find.byType(BrandButton));
      await tester.pumpAndSettle();

      expect(find.byType(BranchEditor), findsNothing, reason: 'sheet popped');
      final snap = await db.collection('branches').get();
      expect(snap.docs, hasLength(1));
      final data = snap.docs.first.data();
      expect(data['name'], 'New Branch');
      expect(data['address'], '10 New Rd');
      final coordinates = data['coordinates'] as GeoPoint;
      expect(coordinates.latitude, 24.5);
      expect(coordinates.longitude, 67.25);
      expect(data['deliveryRadiusMiles'], 7.5);
      expect(data['isDefault'], isTrue, reason: 'switch flipped before save');
      expect(data['isActive'], isTrue);
    },
  );

  testWidgets('a pin-drop result lands in the coordinate and address fields', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byIcon(Icons.pin_drop));
    // Pop with a value BEFORE the map route ever builds — the contract under
    // test is the editor's result handling, not the map screen itself.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(
      const DeliveryLocationModel(
        latitude: 24.5,
        longitude: 67.25,
        address: '1 Main St',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('24.500000'), findsOneWidget, reason: 'lat from result');
    expect(find.text('67.250000'), findsOneWidget, reason: 'lng from result');
    expect(
      find.text('1 Main St'),
      findsOneWidget,
      reason: 'address adopted when non-empty',
    );
  });
}
