// UI-12 (p22) phase B — visual pack for the two surfaces this phase touches.
//
// Written BEFORE the B restyle so the FIRST generation of each master records
// the pre-adoption pixels; every master is then re-captured after the wiring,
// giving the p20 DRIFT-5 before/after pair for each view. Whole-screen finders
// (not widget finders) are used deliberately so the master renders on both
// versions of the source.
//
// `manager_dashboard.png` (the pre-existing master) cannot serve this purpose:
// it seeds an UNAUTHENTICATED state, so it captures the role-gate spinner, not
// the order rows this phase restyles.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/presentation/dead_letter_screen.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../helpers/test_helpers.dart';
import '../support/tenant_claim_fakes.dart';

final _managerUser = MockUser(uid: 'manager-p22-g', email: 'g22@test.com');

IsarDeadLetter _deadLetter({required String lastError}) => IsarDeadLetter()
  ..operation = 'create'
  ..collectionName = 'orders'
  ..dataString = '{"id":"ord-dlq"}'
  ..timestamp = DateTime(2026, 1, 1)
  ..retryCount = 2
  ..lastError = lastError;

/// Pins the pixel viewport used by the existing `test/ui` goldens.
void _pinView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _managerApp(FirebaseFirestore firestore) => ProviderScope(
  overrides: [
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(_managerUser)),
    adminDataServiceProvider.overrideWithValue(
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(
        id: 'manager-p22-g',
        role: UserRole.manager,
        branchId: 'branch-1',
      ),
    ),
  ],
  child: const MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ManagerDashboard(),
  ),
);

Widget _dlqApp(List<IsarDeadLetter> entries) => ProviderScope(
  overrides: [
    deadLettersProvider.overrideWith((ref) => Stream.value(entries)),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(id: 'owner-p22-g', role: UserRole.owner),
    ),
  ],
  child: const MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DeadLetterScreen(),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('p22 B — manager dashboard order rows (populated)', (
    tester,
  ) async {
    _pinView(tester);
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('manager-p22-g').set({
      'email': 'g22@test.com',
      'role': 'manager',
      'branchId': 'branch-1',
      'name': 'Golden Manager',
    });
    await firestore.collection('orders').doc('o1').set({
      'tenantId': 'tenant_a',
      'branchId': 'branch-1',
      'totalCents': 1234,
      'status': 'pending',
      // p32 T-2 originally pinned FIXED timestamps (row order + pixel
      // stability); that baseline self-expired: getOverviewStats() filters
      // createdAt > DateTime.now()-24h (admin_data_service.dart:48-53), so
      // fixed past stamps slid OUT of the rolling window daily and the golden
      // went deterministically red (observed 2026-10-07 after the 10-06 green).
      // Seeds are now relative to now — always inside the 24h window, pixels
      // unchanged (nothing in the row renders the timestamp:
      // manager_dashboard.dart:185-207 shows id, status, amount only), and
      // o1 (-1h) stays NEWER than o2 (-2h) so the DESC query still pins o1
      // first, the order the committed baseline records.
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 1)),
      ),
      'items': <Object>[],
    });
    await firestore.collection('orders').doc('o2').set({
      'tenantId': 'tenant_a',
      'branchId': 'branch-1',
      'totalCents': 5678,
      'status': 'ready',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 2)),
      ),
      'items': <Object>[],
    });

    await tester.pumpWidget(_managerApp(firestore));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await expectLater(
      find.byType(ManagerDashboard),
      matchesGoldenFile('goldens/p22_manager_dashboard_rows.png'),
    );
  });

  testWidgets('p22 B — dead-letter queue (populated)', (tester) async {
    _pinView(tester);
    await tester.pumpWidget(
      _dlqApp([_deadLetter(lastError: 'permission-denied')]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The master is only meaningful if the row actually rendered.
    expect(find.text('create · orders'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsOneWidget);

    await expectLater(
      find.byType(DeadLetterScreen),
      matchesGoldenFile('goldens/p22_dead_letter_populated.png'),
    );
  });

  testWidgets('p22 B — dead-letter queue (healthy)', (tester) async {
    _pinView(tester);
    await tester.pumpWidget(_dlqApp(const <IsarDeadLetter>[]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('No failed operations'), findsOneWidget);

    await expectLater(
      find.byType(DeadLetterScreen),
      matchesGoldenFile('goldens/p22_dead_letter_empty.png'),
    );
  });
}
