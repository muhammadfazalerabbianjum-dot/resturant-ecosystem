import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/features/admin/presentation/role_router_screen.dart';

import '../../../helpers/app_localizations_test_helper.dart';

/// COV-4 — AUTH role-gate integration: the post-login role resolution chain
/// authState → REAL FirebaseAuthRepository.getUserData(users/{uid}) →
/// currentUserProvider → RoleRouterScreen/RoleGate. Wrong role must bounce
/// through NoPermissionRedirect (permission snackbar + home); staff must
/// reach their dashboard; a signed-out visitor must land on login; a
/// signed-in user with NO profile doc must fail closed to home.
///
/// This is the auth-side complement to the admin-surface role_gate tests
/// (which parameterize RoleGate alone): here the REAL repository performs
/// the profile read over the fake Firestore.

class _StubbedFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockLogger extends Mock implements LoggerService {}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/role-router',
  routes: [
    GoRoute(
      path: '/role-router',
      name: RouteNames.roleRouter,
      builder: (_, _) => const RoleRouterScreen(),
    ),
    GoRoute(
      path: '/home',
      name: RouteNames.home,
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('Home Route'))),
    ),
    GoRoute(
      path: '/login',
      name: RouteNames.login,
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('Login Route'))),
    ),
  ],
);

Future<void> seedUser(
  FakeFirebaseFirestore firestore, {
  required String uid,
  String? role,
  String? branchId,
}) async {
  final data = <String, dynamic>{'email': '$uid@test.com'};
  if (role != null) data['role'] = role;
  if (branchId != null) data['branchId'] = branchId;
  await firestore.collection('users').doc(uid).set(data);
}

/// Pumps the production RoleRouterScreen inside a real GoRouter with the
/// REAL FirebaseAuthRepository performing the users/{uid} profile read.
/// Uses fixed polling pumps (spinners never settle).
Future<void> pumpRouterApp(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final router = _buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizationsTestHelper.delegates,
        supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      ),
    ),
  );
  await tester.pump();
}

List<Override> _overrides({
  required FakeFirebaseFirestore firestore,
  required _MockLogger logger,
  required User? authUser,
}) {
  return [
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    authRepositoryProvider.overrideWithValue(
      FirebaseAuthRepository(
        _StubbedFirebaseAuth(),
        firestore,
        logger,
        cache: const NoOpLocalCache(),
      ),
    ),
    loggerProvider.overrideWithValue(logger),
  ];
}

_MockLogger _stubbedLogger() {
  final logger = _MockLogger();
  when(() => logger.info(any(), any())).thenAnswer((_) async {});
  when(
    () => logger.error(any(), any(), stack: any(named: 'stack')),
  ).thenAnswer((_) async {});
  return logger;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('customer reaching the role-router is bounced through '
      'NoPermissionRedirect to home with the permission snackbar', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final logger = _stubbedLogger();
    await seedUser(firestore, uid: 'u-cust', role: 'customer');

    await pumpRouterApp(
      tester,
      overrides: _overrides(
        firestore: firestore,
        logger: logger,
        authUser: MockUser(uid: 'u-cust', email: 'cust@test.com'),
      ),
    );

    var sawRedirect = false;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(NoPermissionRedirect).evaluate().isNotEmpty) {
        sawRedirect = true;
      }
    }
    expect(
      sawRedirect,
      isTrue,
      reason: 'a customer must be bounced through NoPermissionRedirect',
    );
    expect(find.text('Home Route'), findsOneWidget);
    expect(
      find.text('No admin permission for this account.'),
      findsAtLeastNWidgets(1),
      reason: 'the permission message must surface (snackbar and/or label)',
    );
    expect(find.byType(KitchenDashboard), findsNothing);
  });

  testWidgets(
    'a signed-out visitor reaching the role-router is redirected to login',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final logger = _stubbedLogger();

      await pumpRouterApp(
        tester,
        overrides: _overrides(
          firestore: firestore,
          logger: logger,
          authUser: null,
        ),
      );

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.text('Login Route').evaluate().isNotEmpty) break;
      }
      expect(find.text('Login Route'), findsOneWidget);
    },
  );

  testWidgets(
    'kitchen staff reaching the role-router lands on the kitchen dashboard',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final logger = _stubbedLogger();
      await seedUser(
        firestore,
        uid: 'u-kitchen',
        role: 'kitchen',
        branchId: 'branch-1',
      );

      await pumpRouterApp(
        tester,
        overrides: _overrides(
          firestore: firestore,
          logger: logger,
          authUser: MockUser(uid: 'u-kitchen', email: 'k@test.com'),
        ),
      );

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.byType(KitchenDashboard).evaluate().isNotEmpty) break;
      }
      expect(find.byType(KitchenDashboard), findsOneWidget);
      // The dashboard's tabs render (RoleGate allowed the kitchen role).
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Home Route'), findsNothing);
    },
  );

  testWidgets(
    'a signed-in user with NO profile doc fails closed: unable-to-verify '
    'snackbar + home (never a dashboard)',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final logger = _stubbedLogger();
      // Signed in, but users/{uid} was never provisioned.

      await pumpRouterApp(
        tester,
        overrides: _overrides(
          firestore: firestore,
          logger: logger,
          authUser: MockUser(uid: 'u-ghost', email: 'ghost@test.com'),
        ),
      );

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.text('Home Route').evaluate().isNotEmpty) break;
      }
      expect(find.text('Home Route'), findsOneWidget);
      expect(
        find.text('Unable to verify role. Please try again.'),
        findsAtLeastNWidgets(1),
        reason: 'the verification failure must surface (snackbar and/or label)',
      );
      expect(find.byType(KitchenDashboard), findsNothing);
    },
  );
}
