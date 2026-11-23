import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/setup/operating_hours_screen.dart';

import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

/// PERF-2 S4: real behavioral coverage for the owner-only Operating Hours
/// setup screen — the week loaded from BOTH Firestore paths (branch-scoped vs
/// `settings/defaultOperatingHours`), the day toggle, the time picker
/// round-trip (including the malformed-value fallback), the Save write-through,
/// and both FAIL-CLOSED error surfaces.
///
/// The two error paths are driven by the fake's REAL security-rules engine
/// (`FakeFirebaseFirestore(securityRules: ...)`): `isAllowed` is OR-across-
/// matches, so a path with NO `allow` rule denies the operation and the screen
/// must surface it instead of pretending success.
const _allowNothing = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /nothing/here {
      allow read, write;
    }
  }
}''';

/// Reads are allowed, writes are not (denial by OMISSION — no `allow write`).
const _readOnlyOperatingHours = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /settings/tenant_a_defaultOperatingHours {
      allow read;
    }
  }
}''';

/// The setup screen is a tall list (7 day cards + the Save button); the default
/// 800x600 test viewport leaves Save outside the built range, so size the view
/// like the golden tests do and make every control reachable.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Owner-authorized harness. `MaterialApp.router` (not `.home`) because the
/// RoleGate's denial path calls `context.goNamed(RouteNames.home)`.
Widget buildTestWidget(
  WidgetTester tester, {
  required FirebaseFirestore firestore,
  UserRole role = UserRole.owner,
  String? branchId,
  LoggerService? logger,
}) {
  _tallViewport(tester);
  return ProviderScope(
    overrides: [
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      firestoreProvider.overrideWithValue(firestore),
      loggerProvider.overrideWithValue(logger ?? FakeLogger()),
      currentUserProvider.overrideWith(
        (ref) async => UserModel(id: 'owner-1', role: role),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/operating-hours',
        routes: [
          GoRoute(
            path: '/operating-hours',
            builder: (_, _) => OperatingHoursScreen(branchId: branchId),
          ),
          GoRoute(
            path: '/',
            name: RouteNames.home,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('Home'))),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  Future<void> seedDefault(Map<String, dynamic> monday) async {
    await db.collection('settings').doc('tenant_a_defaultOperatingHours').set({
      'monday': monday,
      'holidayModeEnabled': false,
    });
  }

  testWidgets('owner loads the week from settings/defaultOperatingHours', (
    tester,
  ) async {
    await seedDefault({
      'isOpen': true,
      'openTime': '08:30',
      'closeTime': '21:15',
    });
    await tester.pumpWidget(buildTestWidget(tester, firestore: db));
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('21:15'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the load must complete — a stuck spinner hides the week',
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('branch-scoped hours come from branches/{id}/config/'
      'operatingHours, NOT the default doc', (tester) async {
    await db
        .collection('branches')
        .doc('b1')
        .collection('config')
        .doc('operatingHours')
        .set({
          'monday': {'isOpen': true, 'openTime': '07:45', 'closeTime': '20:00'},
        });
    // A deliberately DIFFERENT default: whichever value renders proves which
    // document the screen actually read.
    await seedDefault({
      'isOpen': true,
      'openTime': '11:11',
      'closeTime': '22:22',
    });

    await tester.pumpWidget(
      buildTestWidget(tester, firestore: db, branchId: 'b1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('07:45'), findsOneWidget);
    expect(find.text('11:11'), findsNothing);
  });

  testWidgets('toggling a day closed renders Closed and Save persists it', (
    tester,
  ) async {
    await seedDefault({
      'isOpen': true,
      'openTime': '08:30',
      'closeTime': '21:15',
    });
    await tester.pumpWidget(buildTestWidget(tester, firestore: db));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsNothing);
    await tester.tap(find.byType(Switch).first); // Monday
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(
      find.text('08:30'),
      findsNothing,
      reason: 'a closed day hides its open/close pickers',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final doc = await db
        .collection('settings')
        .doc('tenant_a_defaultOperatingHours')
        .get();
    expect(
      (doc.data()!['monday'] as Map)['isOpen'],
      isFalse,
      reason: 'the toggled day must reach Firestore (merge write)',
    );
    expect(find.text('Saved successfully'), findsOneWidget);
  });

  testWidgets('the time picker round-trips the stored HH:mm value', (
    tester,
  ) async {
    await seedDefault({
      'isOpen': true,
      'openTime': '08:30',
      'closeTime': '21:15',
    });
    await tester.pumpWidget(buildTestWidget(tester, firestore: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('08:30'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('08:30'),
      findsOneWidget,
      reason: 'parse -> TimeOfDay -> format must be lossless',
    );
  });

  testWidgets('a malformed stored time falls back to 09:00 in the picker', (
    tester,
  ) async {
    await seedDefault({
      'isOpen': true,
      'openTime': 'not-a-time',
      'closeTime': '21:15',
    });
    await tester.pumpWidget(buildTestWidget(tester, firestore: db));
    await tester.pumpAndSettle();

    // The raw value renders as-is until it is edited...
    expect(find.text('not-a-time'), findsOneWidget);
    await tester.tap(find.text('not-a-time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // ...and the picker's fallback (09:00) then replaces it: the malformed
    // value is gone and the day now shows the default open time.
    expect(find.text('not-a-time'), findsNothing);
    expect(find.text('09:00'), findsWidgets);
  });

  testWidgets('a denied save is FAIL-CLOSED: mapped error, never a success '
      'claim', (tester) async {
    final denied = FakeFirebaseFirestore(
      securityRules: _readOnlyOperatingHours,
    );
    final logger = FakeLogger();
    await tester.pumpWidget(
      buildTestWidget(tester, firestore: denied, logger: logger),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Failed to save: An unexpected error occurred. Please try again.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Saved successfully'),
      findsNothing,
      reason: 'a denied write must never claim success',
    );
    expect(
      logger.loggedErrors.any((m) => m.contains('OperatingHoursScreen_save')),
      isTrue,
      reason: 'the failure must reach the logger, not only the snackbar',
    );
  });

  testWidgets(
    'a denied load surfaces the mapped error (no silent empty week)',
    (tester) async {
      final denied = FakeFirebaseFirestore(securityRules: _allowNothing);
      final logger = FakeLogger();
      await tester.pumpWidget(
        buildTestWidget(tester, firestore: denied, logger: logger),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Failed to load: An unexpected error occurred. Please try again.',
        ),
        findsOneWidget,
      );
      expect(
        logger.loggedErrors.any((m) => m.contains('OperatingHoursScreen_load')),
        isTrue,
      );
      // The spinner is gone: the screen fails visibly instead of hanging.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('a non-owner never sees the setup surface (RoleGate)', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(tester, firestore: db, role: UserRole.manager),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsNothing);
    expect(find.text('No admin permission for this account.'), findsOneWidget);
    expect(
      find.text('Home'),
      findsOneWidget,
      reason: 'the gate redirects to RouteNames.home',
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
