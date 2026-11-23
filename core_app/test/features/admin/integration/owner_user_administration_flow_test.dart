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
import 'package:go_router/go_router.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// COV-5 (WHITE_LABEL_b07_cov5.md acceptance #1): Owner dashboard
/// user-administration INTEGRATION — the real [AdminDataService] over a real
/// [FakeFirebaseFirestore] drives the whole user-branch / role-change flow:
/// sheet -> write -> W8.1(b) mapped snackbar on failure -> W8.1(a) mounted
/// guards -> W8.1(c) fresh `loadUser` re-read feeding the row. Every flow
/// below runs against the production widget + production service; only the
/// Firestore transport is faked.

/// Mock user with owner role (the signed-in dashboard operator).
final mockAuthUser = MockUser(uid: 'owner-test-1', email: 'owner@test.com');

/// Real [AdminDataService] whose two USER mutations are denied the way
/// Firestore rules deny them (RULES-1/RULES-2 fail-closed). Everything else
/// (loadUsers/loadUser/loadBranches) delegates to the real implementation —
/// the same harness idiom owner_dashboard_test.dart uses for
/// `_SlowAdminService` (T-5). Failure injection is required because
/// FakeFirebaseFirestore cannot simulate a rules denial.
class _DeniedAdminService extends AdminDataService {
  _DeniedAdminService({
    required super.firestore,
    required super.logger,
    super.tenantClaim = const FixedTenantClaim(),
  });

  @override
  Future<void> updateUserRole(String uid, UserRole role) async {
    throw FirebaseException(
      plugin: 'firestore',
      code: 'permission-denied',
      message: 'RULES-1: staff role write denied',
    );
  }

  @override
  Future<void> updateUserBranch(String uid, String? branchId) async {
    throw FirebaseException(
      plugin: 'firestore',
      code: 'permission-denied',
      message: 'RULES-1: staff branch write denied',
    );
  }
}

/// Fake gap compensation for the pagination flow: fake_cloud_firestore
/// cannot evaluate startAfterDocument on a String orderBy('email') query
/// (probed — page 2 returns 0 items even at service level), whereas real
/// Firestore defines it. This subclass emulates Firestore's OWN cursor
/// semantics over the same fake datastore so the UI flow under test
/// (Load More button -> stored cursor -> next-page merge -> hasMore latch)
/// stays a REAL end-to-end flow. Production `loadUsers`
/// (admin_data_service.dart:150-158) is untouched; its stored-cursor
/// contract remains the existing green service-level test.
class _PagingAdminService extends AdminDataService {
  final FirebaseFirestore db;

  _PagingAdminService({
    required this.db,
    required super.logger,
    super.tenantClaim = const FixedTenantClaim(),
  }) : super(firestore: db);

  @override
  Future<PageResult<UserModel>> loadUsers({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    // Ordered superset without the cursor (super applies orderBy email).
    final superset = await super.loadUsers(limit: 1000);
    final ordered = superset.items;

    List<UserModel> page;
    if (startAfter == null) {
      page = ordered.take(limit).toList();
    } else {
      final cursorEmail = (startAfter.data() as Map)['email'] as String;
      final cursorIndex = ordered.indexWhere((u) => u.email == cursorEmail);
      page = ordered.skip(cursorIndex + 1).take(limit).toList();
    }

    final lastId = page.isEmpty ? null : page.last.id;
    final lastDoc = lastId == null
        ? null
        : await db.collection('users').doc(lastId).get();
    return PageResult(items: page, lastDoc: lastDoc);
  }
}

/// Builds the widget tree with overridden providers for testing.
Widget buildTestWidget({
  required FirebaseFirestore firestore,
  User? authUser,
  AdminDataService? adminServiceOverride,
  FakeLogger? logger,
}) {
  final authStream = Stream<User?>.value(authUser);
  final adminService =
      adminServiceOverride ??
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      );
  final panicService = PanicSwitchService(
    firestore: firestore,
    tenantClaim: const FixedTenantClaim(),
  );

  final overrides = <Override>[
    // The dashboards log through loggerProvider — keep the whole run
    // hermetic and assertable by injecting the recording fake.
    loggerProvider.overrideWithValue(logger ?? FakeLogger()),
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    adminDataServiceProvider.overrideWithValue(adminService),
    // The REAL panic-switch chain (service over the fake Firestore) feeds the
    // overview banner — no ordersAcceptingProvider override here.
    panicSwitchServiceProvider.overrideWithValue(panicService),
  ];
  // W2.9: the RoleGate authorizes the signed-in role before rendering. The
  // authRepositoryProvider default is a FallbackAuthRepository (returns null
  // user data), so tests that exercise the authorized dashboard path must
  // resolve currentUserProvider to the expected role themselves.
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async =>
            const UserModel(id: 'owner-test-1', role: UserRole.owner),
      ),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      // ROUTER-2 W2.9: wrong/absent role navigates home via goNamed('home').
      // The dashboard lives at /dashboard so that navigation actually moves
      // away from it (a same-route redirect would leave the redirect spinner).
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const OwnerDashboard(),
          ),
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Home Route'))),
          ),
        ],
      ),
    ),
  );
}

/// Seeds one branch the way the branches tab stores them (BranchModel shape).
Future<void> seedBranch(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
}) async {
  await firestore.collection('branches').doc(id).set({
    'name': name,
    'address': '1 Main St',
    'isActive': true,
    'isDefault': false,
    'coordinates': const GeoPoint(0, 0),
    'deliveryRadiusMiles': 5.0,
  });
}

/// Seeds one user the way loadUsers orders them (orderBy email).
Future<void> seedUser(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String email,
  required String name,
  String role = 'customer',
  String? branchId,
}) async {
  await firestore.collection('users').doc(id).set({
    'email': email,
    'role': role,
    'name': name,
    if (branchId != null) 'branchId': branchId,
  });
}

/// The 4 s auto-hide SnackBar Timer must be drained or the binding's
/// !timersPending invariant fails (COV-3 harness finding, _drainSnackbar).
Future<void> _drainSnackbar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Drives the fake-Firestore mutation chain deterministically: advancing the
/// FakeAsync clock fires the fake's internal timers while each pump
/// materialises the frames the completion setStates schedule. Bare
/// pumpAndSettle alone is racy here — it only pumps while FRAMES are
/// scheduled and can return before a zero-duration fake timer fires.
Future<void> _settleMutation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// The rendered item count of the Users tab list. Rows build lazily, so the
/// delegate is the observable truth — but ListView.separated materializes
/// `2 * itemCount - 1` children (items + separators), hence the conversion.
int _userListChildCount(WidgetTester tester) {
  final delegate =
      tester.widget<ListView>(find.byType(ListView)).childrenDelegate
          as SliverChildBuilderDelegate;
  final childCount = delegate.childCount ?? -1;
  return (childCount + 1) ~/ 2;
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

  group('COV-5 owner user administration — assign-branch flow', () {
    testWidgets(
      '1. assigns a branch end-to-end: sheet -> Save -> Firestore write + fresh-read row refresh',
      (tester) async {
        await seedBranch(fakeFirestore, id: 'b1', name: 'Downtown');
        await seedUser(
          fakeFirestore,
          id: 'u1',
          email: 'u1@test.com',
          name: 'User One',
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);
        // Pre-mutation row renders the no-branch line.
        expect(find.text('Customer · — No branch —'), findsOneWidget);

        await tester.tap(find.byTooltip('Assign Branch'));
        await tester.pumpAndSettle();
        expect(find.text('Assign Branch — User One'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Downtown').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await _settleMutation(tester);

        // The sheet closed on success.
        expect(find.text('Assign Branch — User One'), findsNothing);
        // The REAL AdminDataService wrote the branch to Firestore.
        final doc = await fakeFirestore.collection('users').doc('u1').get();
        expect(doc.data()!['branchId'], 'b1');
        // W8.1(c): the row re-rendered from the FRESH loadUser (server
        // truth), not a client mirror edit. The row renders the branchId
        // (roleBranchLine uses u.branchId verbatim).
        expect(find.text('Customer · b1'), findsOneWidget);
      },
    );

    testWidgets(
      '2. un-assigns a branch: "— No branch —" writes null and the row re-renders',
      (tester) async {
        await seedBranch(fakeFirestore, id: 'b1', name: 'Downtown');
        await seedUser(
          fakeFirestore,
          id: 'u2',
          email: 'u2@test.com',
          name: 'User Two',
          branchId: 'b1',
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);
        expect(find.text('Customer · b1'), findsOneWidget);

        await tester.tap(find.byTooltip('Assign Branch'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('— No branch —').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await _settleMutation(tester);

        final doc = await fakeFirestore.collection('users').doc('u2').get();
        expect(doc.data()!['branchId'], isNull);
        expect(find.text('Customer · — No branch —'), findsOneWidget);
      },
    );

    testWidgets(
      '3. with no branches seeded, the sheet never opens (guard + mapped snackbar)',
      (tester) async {
        await seedUser(
          fakeFirestore,
          id: 'u3',
          email: 'u3@test.com',
          name: 'User Three',
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);
        await tester.tap(find.byTooltip('Assign Branch'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The empty-branches guard fires the mapped l10n message and returns
        // BEFORE showModalBottomSheet.
        expect(find.text('No branches found.'), findsOneWidget);
        expect(find.text('Assign Branch — User Three'), findsNothing);
        await _drainSnackbar(tester);
      },
    );
  });

  group('COV-5 owner user administration — role change propagation', () {
    testWidgets(
      '4. role dropdown propagates to Firestore and re-renders the row (Owner option suppressed for non-self)',
      (tester) async {
        await seedUser(
          fakeFirestore,
          id: 'u4',
          email: 'u4@test.com',
          name: 'Rita Manager',
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);

        await tester.tap(find.byType(DropdownButton<UserRole>));
        await tester.pumpAndSettle();
        // Fail-closed UI: a non-self row may never offer the Owner role.
        expect(find.text('Owner'), findsNothing);

        await tester.tap(find.text('Manager').last);
        await _settleMutation(tester);

        // The write landed through the real updateUserRole.
        final doc = await fakeFirestore.collection('users').doc('u4').get();
        expect(doc.data()!['role'], 'manager');
        // W8.1(c): fresh loadUser re-render — the role label propagated.
        expect(find.text('Manager · — No branch —'), findsOneWidget);
      },
    );

    testWidgets(
      '5. the signed-in owner row is fail-closed: assign + role controls disabled (isMe)',
      (tester) async {
        await seedUser(
          fakeFirestore,
          id: 'owner-test-1',
          email: 'owner@test.com',
          name: 'Owner One',
          role: 'owner',
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);

        final ownerTile = find.ancestor(
          of: find.text('Owner One'),
          matching: find.byType(SettingTile),
        );
        expect(ownerTile, findsOneWidget);
        // Find the IconButton WIDGET (not its inner Icon child).
        final assignButton = find.descendant(
          of: ownerTile,
          matching: find.byType(IconButton),
        );
        expect(assignButton, findsOneWidget);
        expect(tester.widget<IconButton>(assignButton).onPressed, isNull);
        final roleDropdown = find.descendant(
          of: ownerTile,
          matching: find.byType(DropdownButton<UserRole>),
        );
        expect(
          tester.widget<DropdownButton<UserRole>>(roleDropdown).onChanged,
          isNull,
        );

        // No self-demotion path exists in the datastore either.
        final doc = await fakeFirestore
            .collection('users')
            .doc('owner-test-1')
            .get();
        expect(doc.data()!['role'], 'owner');
      },
    );

    testWidgets(
      '6. denied role write: mapped snackbar, no row refresh, error logged (W8.1 fail-closed)',
      (tester) async {
        final logger = FakeLogger();
        await seedUser(
          fakeFirestore,
          id: 'u6',
          email: 'u6@test.com',
          name: 'User Six',
        );

        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            authUser: mockAuthUser,
            adminServiceOverride: _DeniedAdminService(
              firestore: fakeFirestore,
              logger: logger,
            ),
            logger: logger,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);

        await tester.tap(find.byType(DropdownButton<UserRole>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manager').last);
        await _settleMutation(tester);

        // W8.1(b): the Firestore rules denial maps to a human message.
        expect(
          find.text('You do not have permission to perform this action.'),
          findsOneWidget,
        );
        // The fresh-read refresh path was NOT taken (early return) — the row
        // still shows the old role.
        expect(find.text('Manager · — No branch —'), findsNothing);
        expect(find.text('Customer · — No branch —'), findsOneWidget);
        final doc = await fakeFirestore.collection('users').doc('u6').get();
        expect(doc.data()!['role'], 'customer');
        // Never silent: the failure reached the logger.
        expect(logger.loggedErrors, isNotEmpty);
        await _drainSnackbar(tester);
      },
    );
  });

  group('COV-5 owner user administration — write-failure + pagination', () {
    testWidgets(
      '7. denied branch write: snackbar shown, sheet stays open, nothing written (W8.1 fail-closed)',
      (tester) async {
        final logger = FakeLogger();
        await seedBranch(fakeFirestore, id: 'b1', name: 'Downtown');
        await seedUser(
          fakeFirestore,
          id: 'u7',
          email: 'u7@test.com',
          name: 'User Seven',
        );

        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            authUser: mockAuthUser,
            adminServiceOverride: _DeniedAdminService(
              firestore: fakeFirestore,
              logger: logger,
            ),
            logger: logger,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);

        await tester.tap(find.byTooltip('Assign Branch'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Downtown').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await _settleMutation(tester);

        expect(
          find.text('You do not have permission to perform this action.'),
          findsOneWidget,
        );
        // No Navigator.pop on the error path — the operator can retry.
        expect(find.text('Assign Branch — User Seven'), findsOneWidget);
        final doc = await fakeFirestore.collection('users').doc('u7').get();
        expect(doc.data()!['branchId'], isNull);
        expect(logger.loggedErrors, isNotEmpty);
        await _drainSnackbar(tester);
        // The sheet survives the snackbar drain (retry affordance intact).
        expect(find.text('Assign Branch — User Seven'), findsOneWidget);
      },
    );

    testWidgets(
      '8. Load More reuses the page cursor: 20 users then the 21st loads exactly once (no duplicates)',
      (tester) async {
        for (var i = 1; i <= 21; i++) {
          final nn = i.toString().padLeft(2, '0');
          await seedUser(
            fakeFirestore,
            id: 'page-u$nn',
            email: 'u$nn@test.com',
            name: 'User $nn',
          );
        }

        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            authUser: mockAuthUser,
            adminServiceOverride: _PagingAdminService(
              db: fakeFirestore,
              logger: FakeLogger(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await _settleMutation(tester);

        // Page 1: exactly the first 20 (orderBy email) + the Load More row.
        // The rows build lazily, so the observable truth is the delegate's
        // item count (a cursor bug re-fetching page 1 would duplicate to 41).
        expect(_userListChildCount(tester), 21);
        // The Load More row sits at the bottom of the lazily built list.
        await tester.drag(find.byType(ListView), const Offset(0, -30000));
        await tester.pump();
        final loadMore = find.widgetWithText(TextButton, 'Load More');
        expect(loadMore, findsOneWidget);

        await tester.tap(loadMore);
        await _settleMutation(tester);

        // The stored cursor advanced — page 2 adds ONLY the 21st user and
        // the Load More row disappears (1 < 20 page => hasMore false).
        expect(_userListChildCount(tester), 21);
        expect(find.widgetWithText(TextButton, 'Load More'), findsNothing);
        // The last row (bottom of the lazily built list) is the seeded 21st.
        await tester.drag(find.byType(ListView), const Offset(0, -30000));
        await tester.pump();
        expect(find.text('User 21'), findsOneWidget);
      },
    );
  });
}
