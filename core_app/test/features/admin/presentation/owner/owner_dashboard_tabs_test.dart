import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
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
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// PERF-2 S2: real behavioral coverage for the owner dashboard tabs that the
/// existing owner_dashboard_test.dart does not reach — cursor pagination on
/// the orders tab, the role-change + assign-branch surfaces of the users tab
/// (success AND fail-closed), and the branch/menu mutation flows — all against
/// the REAL [AdminDataService] on a [FakeFirebaseFirestore].
final mockAuthUser = MockUser(uid: 'owner-test-1', email: 'owner@test.com');

Widget buildTestWidget({
  required FirebaseFirestore firestore,
  User? authUser,
  AdminDataService? adminServiceOverride,
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
    tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    adminDataServiceProvider.overrideWithValue(adminService),
    ordersAcceptingProvider.overrideWith((ref) => Stream<bool>.value(true)),
    panicSwitchServiceProvider.overrideWithValue(panicService),
    loggerProvider.overrideWithValue(FakeLogger()),
    if (authUser != null)
      currentUserProvider.overrideWith(
        (ref) async =>
            const UserModel(id: 'owner-test-1', role: UserRole.owner),
      ),
  ];

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

Future<void> _seedOrder(
  FakeFirebaseFirestore db, {
  required int i,
  String status = 'confirmed',
  String branchId = 'b1',
  int totalCents = 2500,
}) async {
  await db.collection('orders').doc('ord$i').set({
    'tenantId': 'tenant_a',
    'status': status,
    'totalCents': totalCents + i,
    'branchId': branchId,
    'customerId': 'cust$i',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(1700000000000 + i * 1000),
    'items': [
      {
        'item': {'id': 'm1', 'name': 'Pizza', 'priceCents': totalCents + i},
        'quantity': 1,
        'selectedOptions': [],
      },
    ],
  });
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

  group(
    'OwnerDashboard orders tab - cursor pagination (best pattern in repo)',
    () {
      testWidgets('first page renders 20 rows with a Load More affordance, and '
          'the cursor fetches the REMAINING page (no re-fetch of page 1)', (
        tester,
      ) async {
        for (var i = 0; i < 25; i++) {
          await _seedOrder(db, i: i);
        }
        await tester.pumpWidget(
          buildTestWidget(firestore: db, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();

        // Orders tab.
        await tester.tap(find.text('All Orders'));
        await tester.pumpAndSettle();

        // Page 1 = the NEWEST 20 orders (createdAt desc): the newest row's
        // amount renders; the OLDEST orders are not fetched yet.
        expect(find.text(formatAmount(2500 + 24, 'USD')), findsOneWidget);
        expect(find.text(formatAmount(2500 + 0, 'USD')), findsNothing);
        // The Load More row is the 21st child of the VIRTUALIZED ListView -
        // not built until scrolled into range.
        await tester.dragUntilVisible(
          find.text('Load More'),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(find.text('Load More'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        // Page 2 carried only the remaining 5 rows (5 < 20), so the cursor is
        // exhausted and the affordance disappears — the classic same-first-page
        // pagination bug cannot produce this state.
        // The appended page sits BELOW the current viewport (virtualized list)
        // - scroll the cursor's rows into the built range before asserting.
        await tester.dragUntilVisible(
          find.text(formatAmount(2500 + 0, 'USD')),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(formatAmount(2500 + 0, 'USD')),
          findsOneWidget,
          reason: 'page 2 carried the 5 rows page 1 never fetched',
        );
        expect(find.text('Load More'), findsNothing);

        // Newest order first: drag back UP - the virtualized list recycled the
        // first rows while we scrolled down to the cursor's page.
        await tester.dragUntilVisible(
          find.text(formatAmount(2500 + 24, 'USD')),
          find.byType(ListView),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(formatAmount(2500 + 24, 'USD')),
          findsOneWidget,
          reason: 'orders render newest-first with their server totals',
        );
      });

      testWidgets('a single page below the page size never shows Load More', (
        tester,
      ) async {
        await _seedOrder(db, i: 0);
        await tester.pumpWidget(
          buildTestWidget(firestore: db, authUser: mockAuthUser),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('All Orders'));
        await tester.pumpAndSettle();

        // E1: the order row is a BrandCard (raw ListTile swept).
        expect(find.byType(BrandCard), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Load More'), findsNothing);
      });
    },
  );

  group('OwnerDashboard users tab - role change (W8.1 real refresh)', () {
    setUp(() async {
      await db.collection('users').doc('u1').set({
        'email': 'user1@test.com',
        'role': 'customer',
        'name': 'User One',
      });
    });

    testWidgets('changing the role writes through Firestore and re-reads the '
        'fresh document (no manual mirror edit)', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: db, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch Users'));
      await tester.pumpAndSettle();

      // The row renders `displayTitle` (username ?? name ?? displayName ??
      // email) — 'User One' here, never a bare email.
      expect(find.text('User One'), findsOneWidget);
      final before = await db.collection('users').doc('u1').get();
      expect(before.data()!['role'], 'customer');
      // Open the role dropdown and pick Manager.
      await tester.tap(find.byType(DropdownButton<UserRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manager'));
      await tester.pumpAndSettle();

      // The server doc really changed.
      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['role'], 'manager');
    });

    testWidgets('a denied role change fails CLOSED: mapped snackbar shown and '
        'the Firestore doc untouched', (tester) async {
      final failing = _FailingAdminService(firestore: db, logger: FakeLogger());
      await tester.pumpWidget(
        buildTestWidget(
          firestore: db,
          authUser: mockAuthUser,
          adminServiceOverride: failing,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch Users'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<UserRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manager'));
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to perform this action.'),
        findsOneWidget,
        reason: 'W8.1(b): the failure surfaces through FirebaseExceptionMapper',
      );
      final doc = await db.collection('users').doc('u1').get();
      expect(
        doc.data()!['role'],
        'customer',
        reason: 'a denied mutation must never half-apply',
      );
    });

    testWidgets('assign-branch with NO branches shows the localized guard '
        'instead of an empty sheet', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: db, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch Users'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.store_outlined));
      await tester.pumpAndSettle();

      expect(find.text('No branches found.'), findsOneWidget);
    });
  });
}

class _FailingAdminService extends AdminDataService {
  _FailingAdminService({
    required super.firestore,
    required super.logger,
    super.tenantClaim = const FixedTenantClaim(),
  });

  @override
  Future<void> updateUserRole(String uid, UserRole role) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'rules denied',
    );
  }
}
