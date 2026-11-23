// PERF-6b — widget coverage for the Tax tab in RestaurantSetupScreen.
//
// Owner-gated: the currentUserProvider override authorizes the RoleGate lane
// (tier_flag_manager_screen_test pattern). The tab drives the REAL
// TaxRatesRepository against a FakeFirebaseFirestore, so the full chain
// exercised here is: stream populate -> percent edit -> save -> fraction
// write to settings/<tenantId>_taxRates.clients[clientId] (D-038; clientId =
// 'carnama', the DefaultCoreConfig value active under test). The tenant is
// stated at the widget override — the fake seeds the document the app reads.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/features/admin/presentation/setup/restaurant_setup_screen.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// The tenant this suite runs under; the tax table doc id derives from it.
const String kTenantId = 'tenant_a';
const String kTaxRatesDoc = '${kTenantId}_taxRates';

Widget buildTestWidget(FakeFirebaseFirestore firestore) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
      ),
      tenantClaimProvider.overrideWithValue(const FixedTenantClaim(kTenantId)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: RestaurantSetupScreen(),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  Future<void> openTaxTab(WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget(fakeFirestore));
    await tester.pumpAndSettle();
    // 7 scrollable tabs exceed the default test viewport — 'Tax' starts
    // off-screen, so it must be scrolled into view before the tap.
    await tester.ensureVisible(find.text('Tax'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tax'));
    await tester.pumpAndSettle();
  }

  testWidgets('Tax tab renders default-rate field and add-state control', (
    tester,
  ) async {
    await openTaxTab(tester);
    expect(find.text('Default tax rate'), findsOneWidget);
    expect(find.text('Add state rate'), findsOneWidget);
    expect(
      find.text('State'),
      findsNothing,
      reason: 'no per-state rows until the owner adds one',
    );
  });

  testWidgets('add-state row + percent input saves fractions', (tester) async {
    await openTaxTab(tester);

    await tester.tap(find.text('Add state rate'));
    await tester.pumpAndSettle();
    expect(find.text('State'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'State'), 'ny');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'State tax rate'),
      '8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Default tax rate'),
      '5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final doc = await fakeFirestore
        .collection('settings')
        .doc(kTaxRatesDoc)
        .get();
    final clients = doc.data()!['clients'] as Map<String, dynamic>;
    final row = clients['carnama'] as Map<String, dynamic>?;
    expect(row, isNotNull, reason: 'save must write THIS client row');
    expect((row!['stateRates'] as Map)['NY'], 0.08);
    expect(row['defaultRate'], 0.05);
  });

  testWidgets('a saved row re-populates as percent on reload', (tester) async {
    await fakeFirestore.collection('settings').doc(kTaxRatesDoc).set({
      'clients': {
        'carnama': {
          'stateRates': {'NY': 0.08},
          'defaultRate': 0.05,
        },
      },
    });
    await openTaxTab(tester);
    expect(find.text('NY'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
