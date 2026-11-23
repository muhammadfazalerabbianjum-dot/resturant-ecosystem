import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/admin_menu_manager.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';
import 'package:labs/features/admin/presentation/setup/operating_hours_screen.dart';
import 'package:labs/features/admin/presentation/setup/restaurant_setup_screen.dart';
import 'package:labs/features/admin/presentation/setup/tier_flag_manager_screen.dart';
import 'package:labs/features/reservations/presentation/admin_reservations_tab.dart';
import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// ROUTER-2 W2.9 / T-4 + T-5 — role gating (defense-in-depth).
///
/// Every unguarded admin surface must render [NoPermissionRedirect] (not its
/// chrome) for a wrong-role user, and render normally for an authorized role.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group(
    'T-4: wrong-role users are redirected, never see the surface chrome',
    () {
      // (surface, role that must NOT see it)
      final cases = <String, (Widget, UserRole)>{
        'OwnerDashboard': (const OwnerDashboard(), UserRole.manager),
        'ManagerDashboard': (const ManagerDashboard(), UserRole.kitchen),
        'KitchenDashboard': (const KitchenDashboard(), UserRole.delivery),
        'DeliveryDashboard': (const DeliveryDashboard(), UserRole.owner),
        'AdminMenuManager': (const AdminMenuManager(), UserRole.kitchen),
        'TierFlagManagerScreen': (
          const TierFlagManagerScreen(),
          UserRole.manager,
        ),
        'RestaurantSetupScreen': (
          const RestaurantSetupScreen(),
          UserRole.manager,
        ),
        'OperatingHoursScreen': (
          const OperatingHoursScreen(),
          UserRole.manager,
        ),
        'AnalyticsSnapshot': (const AnalyticsSnapshot(), UserRole.kitchen),
        'AdminReservationsTab': (
          const AdminReservationsTab(),
          UserRole.kitchen,
        ),
      };

      for (final entry in cases.entries) {
        testWidgets(
          '${entry.key} renders NoPermissionRedirect for ${entry.value.$2.name}',
          (tester) async {
            await tester.pumpWidget(
              wrongRoleHarness(surface: entry.value.$1, role: entry.value.$2),
            );
            // Resolve the currentUserProvider future.
            await tester.pump();
            await tester.pump();

            // The shared redirect shows instead of the gated surface.
            expect(find.byType(NoPermissionRedirect), findsOneWidget);

            // It then navigates home — never the surface chrome.
            await tester.pump();
            await tester.pump();
            expect(find.text('Home'), findsOneWidget);
          },
        );
      }
    },
  );

  group('T-5: correct-role users see the gated surface', () {
    testWidgets('RoleGate renders its child for an allowed role', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
            ),
          ],
          child: const MaterialApp(
            home: RoleGate(
              allowedRoles: {UserRole.owner},
              builder: _gatedContent,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('GATED CONTENT'), findsOneWidget);
    });

    testWidgets('OwnerDashboard renders for an owner-role user', (
      tester,
    ) async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('users').doc('owner-test-1').set({
        'email': 'owner@test.com',
        'role': 'owner',
        'name': 'Test Owner',
      });
      final authUser = MockUser(uid: 'owner-test-1', email: 'owner@test.com');
      final adminService = AdminDataService(
        firestore: fake,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      );
      final panicService = PanicSwitchService(
        firestore: fake,
        tenantClaim: const FixedTenantClaim(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fake),
            authStateProvider.overrideWith(
              (ref) => Stream<User?>.value(authUser),
            ),
            // Default authRepositoryProvider is a FallbackAuthRepository that
            // returns null user data — the RoleGate would treat that as a
            // customer and redirect. Wire the real repository to the fake
            // Firestore so the seeded users/{uid} role doc is actually read.
            authRepositoryProvider.overrideWith(
              (ref) => FirebaseAuthRepository(
                FirebaseAuth.instance,
                fake,
                FakeLogger(),
                cache: const NoOpLocalCache(),
              ),
            ),
            adminDataServiceProvider.overrideWithValue(adminService),
            ordersAcceptingProvider.overrideWith(
              (ref) => Stream<bool>.value(true),
            ),
            panicSwitchServiceProvider.overrideWithValue(panicService),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  name: 'home',
                  builder: (_, __) => const OwnerDashboard(),
                ),
              ],
            ),
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The authorized owner sees the dashboard chrome (NavigationBar).
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NoPermissionRedirect), findsNothing);
    });
  });
}

Widget _gatedContent(BuildContext context) => const Text('GATED CONTENT');

/// Builds a router-backed harness: the gated [surface] plus a `home` route
/// that [NoPermissionRedirect] navigates to when the role is denied.
Widget wrongRoleHarness({required Widget surface, required UserRole role}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) async => UserModel(id: 'u1', role: role),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/surface',
        routes: [
          GoRoute(path: '/surface', builder: (_, __) => surface),
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Home'))),
          ),
        ],
      ),
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    ),
  );
}
