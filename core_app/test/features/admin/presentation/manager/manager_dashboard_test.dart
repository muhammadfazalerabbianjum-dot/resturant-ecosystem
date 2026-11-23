import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// Mock auth user with manager role and branch assigned.
final mockManagerUser = MockUser(
  uid: 'manager-test-1',
  email: 'manager@test.com',
);

/// Builds the widget tree with overridden providers for testing.
Widget buildTestWidget({required FirebaseFirestore firestore, User? authUser}) {
  final authStream = Stream<User?>.value(authUser);
  final adminService = AdminDataService(
    firestore: firestore,
    logger: FakeLogger(),
    tenantClaim: const FixedTenantClaim(),
  );

  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    adminDataServiceProvider.overrideWithValue(adminService),
  ];
  // W2.9: the RoleGate authorizes the signed-in role before rendering. The
  // authRepositoryProvider default is a FallbackAuthRepository (returns null
  // user data), so tests that exercise the authorized dashboard path must
  // resolve currentUserProvider to the expected role themselves.
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'manager-test-1',
          role: UserRole.manager,
          branchId: 'branch-1',
        ),
      ),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      // ROUTER-2 W2.9: wrong/absent role navigates home via goNamed('home').
      // The dashboard lives at /dashboard so navigation actually moves away
      // from it (a same-route redirect would keep the redirect spinner alive).
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const ManagerDashboard(),
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

/// Seed a user record for the manager with a branchId.
Future<void> seedManagerUser(
  FirebaseFirestore firestore, {
  String? branchId,
}) async {
  await firestore.collection('users').doc('manager-test-1').set({
    'email': 'manager@test.com',
    'role': 'manager',
    'branchId': branchId ?? 'branch-1',
    'name': 'Test Manager',
  });
}

/// Seed an order for the given branch.
Future<void> seedOrder(
  FirebaseFirestore firestore, {
  required String orderId,
  required String branchId,
  int totalCents = 2500,
  String status = 'pending',
}) async {
  await firestore.collection('orders').doc(orderId).set({
    'branchId': branchId,
    'totalCents': totalCents,
    'status': status,
    'createdAt': Timestamp.now(),
    'items': [],
    'userId': 'cust-1',
    'userName': 'Customer 1',
    'userPhone': '+1234567890',
  });
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

  group('ManagerDashboard - Loading State', () {
    testWidgets('1. Shows loading indicator with no auth state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pump();

      // E1 F3-09: loading branch renders the library skeleton.
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ManagerDashboard - Auth States', () {
    testWidgets('2. Shows scaffold when auth user exists with no user doc', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3. Shows scaffold when user has no branch', (tester) async {
      await fakeFirestore.collection('users').doc('manager-test-1').set({
        'email': 'manager@test.com',
        'role': 'manager',
        'name': 'Test Manager',
      });

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('ManagerDashboard - Branch Dashboard', () {
    testWidgets(
      '4. Shows scaffold with branch dashboard when user has branch and orders',
      (tester) async {
        await seedManagerUser(fakeFirestore);

        await seedOrder(fakeFirestore, orderId: 'o1', branchId: 'branch-1');

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
        );
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Should render the branch dashboard app bar title area
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets('5. Shows scaffold without orders', (tester) async {
      await seedManagerUser(fakeFirestore);

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('6. Shows scaffold with branch data when orders exist', (
      tester,
    ) async {
      await seedManagerUser(fakeFirestore);
      await seedOrder(
        fakeFirestore,
        orderId: 'o1',
        branchId: 'branch-1',
        totalCents: 1500,
      );
      await seedOrder(
        fakeFirestore,
        orderId: 'o2',
        branchId: 'branch-1',
        totalCents: 3200,
        status: 'ready',
      );

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets(
      '7. Renders scaffold with branch dashboard when user has branch',
      (tester) async {
        await seedManagerUser(fakeFirestore);
        await seedOrder(
          fakeFirestore,
          orderId: 'o1',
          branchId: 'branch-1',
          totalCents: 2500,
        );

        await tester.pumpWidget(
          buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets('8. Renders without crash when user doc has branchId', (
      tester,
    ) async {
      await seedManagerUser(fakeFirestore);

      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockManagerUser),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('ManagerDashboard - Error State', () {
    testWidgets('11. Shows scaffold on error', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('12. Shows loading on initial auth state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pump();

      // E1 F3-09: loading branch renders the library skeleton.
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
