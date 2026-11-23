// UI-12 (p22) Phase E — OPERATOR ADOPTION SWEEP (E1, the operator half of
// F3-09..F3-15).
//
// RED receipt: every expectation below is the TARGET state — it fails until
// the sweep lands. Covers the widget-level half of the sweep; the occurrence
// counts (raw removal proof) are receipted in
// `tool_uilib/p22/receipts/p22_phaseE_sweep_before.txt` / `_after.txt`.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/tabs/branch_editor.dart';
import 'package:labs/features/admin/presentation/owner/tabs/menu_item_editor.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_branches_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_menu_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_orders_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/owner_users_tab.dart';
import 'package:labs/features/admin/presentation/owner/tabs/panic_switch_banner.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

Widget _harness(FirebaseFirestore firestore, Widget child) {
  final authStream = Stream<User?>.value(
    MockUser(uid: 'owner-e1', email: 'owner@test.com'),
  );
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => authStream),
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'owner-e1', role: UserRole.owner),
      ),
      adminDataServiceProvider.overrideWithValue(
        AdminDataService(
          firestore: firestore,
          logger: FakeLogger(),
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
      ordersAcceptingProvider.overrideWith((ref) => Stream<bool>.value(true)),
      panicSwitchServiceProvider.overrideWithValue(
        PanicSwitchService(
          firestore: firestore,
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
      loggerProvider.overrideWithValue(FakeLogger()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Scaffold supplies the Material ancestor the sheet surfaces provide in
      // production (editors + rows are sheet/list content, not routes).
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore db;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    await Firebase.initializeApp();
    db = FakeFirebaseFirestore();
  });

  group('E1 F3-12: editors adopt BrandTextField + BrandButton(isLoading)', () {
    testWidgets('BranchEditor renders 5 BrandTextField, no spinner', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db, const BranchEditor()));
      await tester.pumpAndSettle();

      expect(find.byType(BrandTextField), findsNWidgets(5));
      expect(find.byType(BrandButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('MenuItemEditor renders 5 BrandTextField, no spinner', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db, const MenuItemEditor()));
      await tester.pumpAndSettle();

      // 5 since P6-1: the cross-contamination notes field joined the four.
      expect(find.byType(BrandTextField), findsNWidgets(5));
      expect(find.byType(BrandButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('E1 F3-10/F3-11: owner rows adopt the tile/card family', () {
    testWidgets('panic banner is a BrandCard row - no raw Card/ListTile', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db, const PanicSwitchBanner()));
      await tester.pumpAndSettle();

      expect(find.byType(BrandCard), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('branches tab rows are SettingTile, not ListTile', (
      tester,
    ) async {
      await db.collection('branches').doc('b1').set({
        'name': 'Main Branch',
        'address': '1 Main St',
      });
      await tester.pumpWidget(_harness(db, const OwnerBranchesTab()));
      await tester.pumpAndSettle();

      expect(find.byType(SettingTile), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('branches add opens a BrandSheet (F3-13 adoption)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db, const OwnerBranchesTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add Branch'));
      await tester.pumpAndSettle();

      expect(find.byType(BrandSheet), findsOneWidget);
      expect(find.text('Add Branch'), findsOneWidget);
    });

    testWidgets('menu tab rows are MenuTile, not ListTile', (tester) async {
      await db.collection('menus').doc('m1').set({
        'name': 'Pizza',
        'priceCents': 1250,
      });
      await tester.pumpWidget(_harness(db, const OwnerMenuTab()));
      await tester.pumpAndSettle();

      expect(find.byType(MenuTile), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      // L13: the price string is still the formatAmount/moneyCents output.
      expect(find.text('\$12.50'), findsOneWidget);
    });

    testWidgets('orders tab rows are BrandCard, not ListTile', (tester) async {
      await db.collection('orders').doc('ord1').set({
        'tenantId': 'tenant_a',
        'status': 'confirmed',
        'totalCents': 2500,
        'branchId': 'b1',
        'customerId': 'cust1',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
        'items': [
          {
            'item': {'id': 'm1', 'name': 'Pizza', 'priceCents': 2500},
            'quantity': 1,
            'selectedOptions': [],
          },
        ],
      });
      await tester.pumpWidget(_harness(db, const OwnerOrdersTab()));
      await tester.pumpAndSettle();

      expect(find.byType(BrandCard), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('\$25.00'), findsOneWidget);
    });

    testWidgets('users tab rows are SettingTile, not ListTile', (tester) async {
      await db.collection('users').doc('u2').set({
        'email': 'manager@test.com',
        'name': 'Manager Two',
        'role': 'manager',
      });
      await tester.pumpWidget(_harness(db, const OwnerUsersTab()));
      await tester.pumpAndSettle();

      expect(find.byType(SettingTile), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Manager Two'), findsOneWidget);
    });
  });
}
