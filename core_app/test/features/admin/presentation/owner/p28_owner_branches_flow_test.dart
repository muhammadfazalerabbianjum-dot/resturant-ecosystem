import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/presentation/owner/tabs/branch_editor.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_branches_tab.dart';

import 'owner_test_harness.dart';

/// p28 lane B (T-4) — owner_branches_tab.dart had 18 executable lines at
/// DA:0: the list separator, the default chip, both editor entry points and
/// the entire delete flow (confirm gate → refusal snackbar → soft delete).
/// Each test drives one real operator journey against a fake Firestore.
void main() {
  setUpAll(setUpOwnerFirebase);

  late FakeFirebaseFirestore db;

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
  });

  Future<void> seedBranches() async {
    await db.collection('branches').doc('b1').set(<String, Object?>{
      'name': 'Main Branch',
      'address': '1 Main St',
      'coordinates': const GeoPoint(24.5, 67.25),
      'isDefault': true,
      'isActive': true,
    });
    await db.collection('branches').doc('b2').set(<String, Object?>{
      'name': 'Second Branch',
      'address': '2 Second St',
      'coordinates': const GeoPoint(25.5, 68.25),
      'isActive': true,
    });
  }

  testWidgets('two stored branches render with a separator and default chip', (
    tester,
  ) async {
    await seedBranches();
    await tester.pumpWidget(ownerHarness(db, const OwnerBranchesTab()));
    await tester.pumpAndSettle();

    expect(find.byType(SettingTile), findsNWidgets(2));
    expect(
      find.byType(Divider),
      findsOneWidget,
      reason: 'separator for 2 rows',
    );
    expect(
      find.byType(Chip),
      findsOneWidget,
      reason: 'only the default branch',
    );
    expect(find.text('Main Branch'), findsOneWidget);
    expect(find.text('Second Branch'), findsOneWidget);
  });

  testWidgets('the edit action opens the editor prefilled from the store', (
    tester,
  ) async {
    await seedBranches();
    await tester.pumpWidget(ownerHarness(db, const OwnerBranchesTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    expect(find.byType(BranchEditor), findsOneWidget);
    expect(find.byType(BrandTextField), findsNWidgets(5));
    expect(
      find.widgetWithText(BrandTextField, 'Main Branch'),
      findsOneWidget,
      reason: 'name field prefilled from the stored branch',
    );
  });

  testWidgets('cancel at the confirm gate leaves the branch untouched', (
    tester,
  ) async {
    await seedBranches();
    await tester.pumpWidget(ownerHarness(db, const OwnerBranchesTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNWidgets(2));

    await tester.tap(find.byType(TextButton).first); // cancel
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing, reason: 'gate closed');
    expect(find.byType(SnackBar), findsNothing);
    final snap = await db.collection('branches').doc('b1').get();
    expect(snap.data()?['isActive'], isTrue);
    expect(snap.data()?['deletedAt'], isNull);
  });

  testWidgets(
    'a confirmed delete with pending orders is refused with a snackbar',
    (tester) async {
      await seedBranches();
      await db.collection('orders').doc('o1').set(<String, Object?>{
        'tenantId': 'tenant_a',
        'branchId': 'b1',
        'status': 'confirmed',
      });
      await tester.pumpWidget(ownerHarness(db, const OwnerBranchesTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).last); // confirm
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SnackBar), findsOneWidget, reason: 'refusal surfaced');
      await tester.pumpAndSettle();

      final snap = await db.collection('branches').doc('b1').get();
      expect(snap.data()?['isActive'], isTrue, reason: 'not deleted');
      expect(snap.data()?['deletedAt'], isNull);
    },
  );

  testWidgets(
    'a confirmed delete with a clear order book soft-deletes the branch',
    (tester) async {
      await seedBranches();
      await tester.pumpWidget(ownerHarness(db, const OwnerBranchesTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete).last); // b2, no orders
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).last); // confirm
      await tester.pumpAndSettle();

      final snap = await db.collection('branches').doc('b2').get();
      expect(snap.data()?['isActive'], isFalse, reason: 'soft-deleted');
      expect(snap.data()?['deletedAt'], isNotNull);
    },
  );
}
