import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/privacy_policy_screen.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/auth/presentation/terms_of_service_screen.dart';

import '../helpers/router_test_harness.dart';

/// ROUTER-3 T-1/T-2 — the router's SECOND real mode: the static fallback table
/// used ONLY when the config has no `screens` section. Every static route is
/// asserted registered with its documented name+path, the config-vs-static
/// whitelist split is pinned (the two modes are the real "ConfigMode values"
/// of this codebase — see the ROUTER-3 addendum drift note), and
/// representative routes render end-to-end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The exact `_staticRoutes` table (`core_app/lib/app/app_router.dart`).
  /// Pinned here so an unintended static-route addition/removal/rename is a
  /// reviewable change instead of silently shipping.
  const staticRouteTable = <String, String>{
    RouteNames.splash: '/splash',
    RouteNames.onboarding: '/onboarding',
    RouteNames.login: '/login',
    RouteNames.signup: '/signup',
    RouteNames.home: '/',
    RouteNames.menu: '/menu',
    RouteNames.dishDetail: '/dish/:id',
    RouteNames.cart: '/cart',
    RouteNames.checkout: '/checkout',
    RouteNames.orderTracker: '/orders/:orderId',
    RouteNames.orders: '/orders',
    RouteNames.reservations: '/reservations',
    RouteNames.locations: '/locations',
    RouteNames.pinDropMap: '/location/map',
    RouteNames.waitlist: '/waitlist',
    RouteNames.loyalty: '/loyalty',
    RouteNames.profile: '/profile',
    RouteNames.errorLogs: '/error-logs',
    RouteNames.admin: '/admin',
    RouteNames.adminMenu: '/admin/menu',
    RouteNames.roleRouter: '/role-router',
    RouteNames.ownerDashboard: '/owner',
    RouteNames.managerDashboard: '/manager',
    RouteNames.kitchenDashboard: '/kitchen',
    RouteNames.deliveryDashboard: '/delivery',
    RouteNames.privacy: '/privacy',
    RouteNames.terms: '/terms',
    RouteNames.deleteAccount: '/delete-account',
    RouteNames.logs: '/logs',
    RouteNames.adminGateway: '/admin-gateway',
    // QUEUE-1 (W5.1(d)): the DLQ ops route is registered in BOTH router modes.
    RouteNames.deadLetterQueue: '/dead-letters',
  };

  group('ROUTER-3 T-1/T-2: static fallback mode', () {
    setUp(() {
      // No loadConfig(): a reset AppConfig has an empty screens whitelist,
      // which is exactly the router's static-fallback trigger.
      AppConfig.resetForTest();
    });

    test('the pinned static table enumerates every route exactly once', () {
      expect(staticRouteTable.keys.toSet().length, staticRouteTable.length);
      expect(
        staticRouteTable.length,
        31,
        reason:
            'the pinned static table above must enumerate every route — '
            'update it when _staticRoutes changes (reviewable drift)',
      );
    });

    test('resetForTest leaves screens empty → router is in static fallback '
        'mode', () {
      expect(AppConfig.screens, isEmpty);
    });

    test('static fallback registers EXACTLY the documented route table', () {
      final container = ProviderContainer(overrides: routerAuthOverrides());
      addTearDown(container.dispose);
      final registered = routerNamedRoutes(container.read(appRouterProvider));
      expect(
        registered,
        staticRouteTable,
        reason: 'the static fallback routes must match _staticRoutes exactly',
      );
    });
    test('mode whitelist split: config-only names are NOT registerable in '
        'static mode and static-only orphans ARE the documented set', () {
      final container = ProviderContainer(overrides: routerAuthOverrides());
      addTearDown(container.dispose);
      final registered = routerNamedRoutes(container.read(appRouterProvider));

      final configOnly = screenIdToRouteName.values
          .where((n) => !staticRouteTable.containsKey(n))
          .toSet();
      expect(
        configOnly,
        const <String>{
          RouteNames.deliveryTracker,
          RouteNames.tierFlagManager,
          RouteNames.restaurantSetup,
          RouteNames.operatingHours,
        },
        reason:
            'these four routes are config-screen-only and must not '
            'resolve in static fallback mode',
      );
      for (final name in configOnly) {
        expect(
          registered.containsKey(name),
          isFalse,
          reason: '$name must fail closed in static fallback mode',
        );
      }

      final staticOnly = staticRouteTable.keys
          .where((n) => !screenIdToRouteName.containsValue(n))
          .toSet();
      expect(
        staticOnly,
        const <String>{
          RouteNames.errorLogs,
          RouteNames.admin,
          RouteNames.adminMenu,
          RouteNames.logs,
          RouteNames.ownerDashboard,
          RouteNames.managerDashboard,
          RouteNames.kitchenDashboard,
          RouteNames.deliveryDashboard,
          RouteNames.deadLetterQueue,
        },
        reason:
            'the static-only routes are the admin/log/dashboard routes plus '
            'the QUEUE-1 DLQ internal ops route (the DLQ route is ALSO '
            'registered in config mode as the one sanctioned internal route, '
            'but it is not a config screen — hence static-only by this test)',
      );
    });

    testWidgets('representative static routes render their screens, never the '
        'router error page', (tester) async {
      final router = await pumpRouterApp(
        tester,
        overrides: routerAuthOverrides(),
      );

      expect(find.text('Route Error'), findsNothing);
      expect(tester.takeException(), isNull);

      const probes = <(String, Type)>[
        (RouteNames.login, LoginScreen),
        (RouteNames.privacy, PrivacyPolicyScreen),
        (RouteNames.terms, TermsOfServiceScreen),
      ];
      for (final (name, screenType) in probes) {
        router.goNamed(name);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byType(screenType),
          findsOneWidget,
          reason: 'goNamed($name) must land on $screenType in static mode',
        );
        expect(
          find.text('Route Error'),
          findsNothing,
          reason: 'goNamed($name) must never render the router error page',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
