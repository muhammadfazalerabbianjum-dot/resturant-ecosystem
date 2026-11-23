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
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/tenant_claim_fakes.dart';

final mockKitchenUser = MockUser(
  uid: 'kitchen-test-1',
  email: 'kitchen@test.com',
);

Widget buildTestWidget({required FirebaseFirestore firestore, User? authUser}) {
  final authStream = Stream<User?>.value(authUser);
  final kitchenService = KitchenService(
    firestore: firestore,
    logger: FakeLogger(),
    syncQueue: RecordingSyncQueue(),
    tenantClaim: const FixedTenantClaim(),
  );

  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    kitchenServiceProvider.overrideWithValue(kitchenService),
  ];
  // W2.9: see owner/manager harnesses — RoleGate authorizes the signed-in
  // role; resolve currentUserProvider directly because the fallback auth
  // repository returns null user data.
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'kitchen-test-1',
          role: UserRole.kitchen,
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
            builder: (_, __) => const KitchenDashboard(),
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

Future<void> seedKitchenUser(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('kitchen-test-1').set({
    'email': 'kitchen@test.com',
    'role': 'kitchen',
    'branchId': 'branch-1',
    'name': 'Test Chef',
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

  group('KitchenDashboard - Loading', () {
    testWidgets('1. Shows loading indicator with no auth state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      await tester.pump();
      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('2. Shows scaffold when no user record', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockKitchenUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3. Shows scaffold without branchId', (tester) async {
      await fakeFirestore.collection('users').doc('kitchen-test-1').set({
        'email': 'kitchen@test.com',
        'role': 'kitchen',
        'name': 'Test Chef',
      });
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockKitchenUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('KitchenDashboard - Data', () {
    testWidgets('4. Shows scaffold with branch', (tester) async {
      await seedKitchenUser(fakeFirestore);
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockKitchenUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('5. Shows scaffold with orders', (tester) async {
      await seedKitchenUser(fakeFirestore);
      await fakeFirestore.collection('orders').doc('o1').set({
        'tenantId': 'tenant_a',
        'branchId': 'branch-1',
        'totalCents': 2500,
        'status': 'confirmed',
        'createdAt': Timestamp.now(),
        'items': [
          {'name': 'Burger', 'quantity': 2, 'priceCents': 1250},
        ],
        'userId': 'cust-1',
        'userName': 'C1',
        'userPhone': '+1234567890',
      });
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockKitchenUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('6. Shows scaffold with ready orders', (tester) async {
      await seedKitchenUser(fakeFirestore);
      await fakeFirestore.collection('orders').doc('o2').set({
        'tenantId': 'tenant_a',
        'branchId': 'branch-1',
        'totalCents': 1500,
        'status': 'ready',
        'createdAt': Timestamp.now(),
        'items': [
          {'name': 'Pizza', 'quantity': 1, 'priceCents': 1500},
        ],
        'userId': 'cust-2',
        'userName': 'C2',
        'userPhone': '+1234567891',
      });
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: mockKitchenUser),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('KitchenDashboard - Error', () {
    testWidgets('7. Shows scaffold on auth failure', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(firestore: fakeFirestore, authUser: null),
      );
      // W2.9: null auth → NoPermissionRedirect → goNamed(home). Wait for the
      // route transition so the final tree holds the single home Scaffold.
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
