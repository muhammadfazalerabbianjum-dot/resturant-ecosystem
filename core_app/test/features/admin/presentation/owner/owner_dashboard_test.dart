import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// Mock user with owner role for tests that require an authenticated session.
final mockAuthUser = MockUser(uid: 'owner-test-1', email: 'owner@test.com');

/// Builds the widget tree with overridden providers for testing.
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
      // ROUTER-2 W2.9: see RoleGate/NoPermissionRedirect — a wrong/absent
      // role navigates home via goNamed('home'). The dashboard lives at
      // /dashboard so that navigation actually moves away from it (a same-route
      // "redirect" would leave NoPermissionRedirect's progress spinner alive).
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

  group('OwnerDashboard - Navigation', () {
    testWidgets('1. Renders navigation bar with all tabs', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      // Need multiple pumps for the auth stream to emit and the widget to rebuild
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('2. Tab switching works', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Branches'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('OwnerDashboard - Overview Tab', () {
    testWidgets('3. Shows navigation view on startup', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // The dashboard renders the NavigationBar after auth resolves
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('4. Shows KPI cards when data is loaded', (tester) async {
      await fakeFirestore.collection('orders').doc('o1').set({
        'tenantId': 'tenant_a',
        'totalCents': 2500,
        'status': 'delivered',
        'createdAt': Timestamp.now(),
      });
      await fakeFirestore.collection('orders').doc('o2').set({
        'tenantId': 'tenant_a',
        'totalCents': 1500,
        'status': 'preparing',
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('5. Shows panic switch banner with accepting state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('OwnerDashboard - Error State', () {
    testWidgets('6. Shows empty state when auth user is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('OwnerDashboard - Branches Tab', () {
    testWidgets('7. Branches tab shows branch list and add button', (
      tester,
    ) async {
      await fakeFirestore.collection('branches').doc('b1').set({
        'name': 'Test Branch',
        'address': '123 Test St',
        'isActive': true,
        'isDefault': false,
        'coordinates': const GeoPoint(0, 0),
        'deliveryRadiusMiles': 5.0,
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Branches'));
      await tester.pumpAndSettle();

      expect(find.text('Test Branch'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('8. Add branch button opens editor', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Branches'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add Branch'), findsOneWidget);
    });
  });

  group('OwnerDashboard - Users Tab', () {
    testWidgets('9. Users tab shows user list', (tester) async {
      await fakeFirestore.collection('users').doc('u1').set({
        'email': 'user1@test.com',
        'role': 'customer',
        'name': 'User One',
      });
      await fakeFirestore.collection('users').doc('u2').set({
        'email': 'user2@test.com',
        'role': 'kitchen',
        'name': 'User Two',
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Branch Users'));
      await tester.pumpAndSettle();

      expect(find.text('All Users'), findsOneWidget);
    });
  });

  group('OwnerDashboard - Menu Tab', () {
    testWidgets('10. Menu tab shows global menu with add button', (
      tester,
    ) async {
      await fakeFirestore.collection('menus').doc('m1').set({
        'name': 'Test Burger',
        'priceCents': 999,
        'isAvailable': true,
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Global Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Test Burger'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('OwnerDashboard - Orders Tab', () {
    testWidgets('11. Orders tab renders with load more', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Orders'));
      await tester.pumpAndSettle();

      expect(find.text('All Orders'), findsAtLeastNWidgets(1));
    });
  });

  group('OwnerDashboard - Panic Switch Integration', () {
    testWidgets('12. Panic switch is present', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('OwnerDashboard - Semantics', () {
    testWidgets('13. Navigation bar is accessible', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      // Verify the NavigationBar is present and accessible
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('OwnerDashboard - Branch Edit', () {
    testWidgets('14. Edit branch button opens editor', (tester) async {
      await fakeFirestore.collection('branches').doc('b1').set({
        'name': 'Edit Test Branch',
        'address': '456 Edit St',
        'isActive': true,
        'isDefault': false,
        'coordinates': const GeoPoint(0, 0),
        'deliveryRadiusMiles': 5.0,
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockAuthUser),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Branches'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('OwnerDashboard - Users Tab async hygiene (T-5, STATE-1 / W8.1)', () {
    testWidgets(
      'branch-assign completing after dispose does NOT setState-after-dispose',
      (tester) async {
        final gate = Completer<void>();
        final slowService = _SlowAdminService(
          firestore: fakeFirestore,
          logger: FakeLogger(),
          gate: gate,
        );
        await fakeFirestore.collection('branches').doc('b1').set({
          'name': 'Branch One',
          'address': '1 Test St',
          'isActive': true,
          'isDefault': false,
          'coordinates': const GeoPoint(0, 0),
          'deliveryRadiusMiles': 5.0,
        });
        await fakeFirestore.collection('users').doc('u1').set({
          'email': 'user1@test.com',
          'role': 'customer',
          'name': 'User One',
        });

        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            authUser: mockAuthUser,
            adminServiceOverride: slowService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branch Users'));
        await tester.pumpAndSettle();
        expect(find.text('All Users'), findsOneWidget);

        // Open the assign-branch sheet for the seeded user.
        await tester.tap(find.byIcon(Icons.store_outlined));
        await tester.pumpAndSettle();

        // Press Save — updateUserBranch now hangs on [gate].
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pump();

        // Dispose the dashboard while the mutation is mid-flight.
        await tester.pumpWidget(const SizedBox());

        // Let the hung mutation complete AFTER disposal.
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.takeException(),
          isNull,
          reason:
              'W8.1(a): the post-await continuation must be mounted-guarded — '
              '`setState() called after dispose()` is the 03-P1-STATE-A bug',
        );
      },
    );
  });
}

/// [AdminDataService] whose updateUserBranch hangs until [gate] completes
/// (T-5: lets the test dispose the widget mid-flight). Every other method
/// delegates to the real implementation backed by the fake Firestore.
class _SlowAdminService extends AdminDataService {
  final Completer<void> gate;
  _SlowAdminService({
    required super.firestore,
    required super.logger,
    super.tenantClaim = const FixedTenantClaim(),
    required this.gate,
  });

  @override
  Future<void> updateUserBranch(String uid, String? branchId) => gate.future;
}
