import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/admin_menu_manager.dart';
import 'package:labs/features/admin/presentation/analytics_snapshot.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:core_ui/core_ui.dart' show LogsScreen;

import '../helpers/router_test_harness.dart';

/// ROUTER-3 T-2 (W2.7, 07-P1-5) — every `RouteNames.*` constant resolves ONLY
/// when the active router mode registers it; mode-forbidden navigation fails
/// closed at the router (never reaches the forbidden screen).
///
/// The real whitelist split (drift note in the ROUTER-3 addendum): config mode
/// registers the 26 `screens[].id` routes; the static-only orphans `admin`,
/// `adminMenu`, `logs`, `errorLogs` and the four role dashboards are NOT
/// registerable in config mode.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every `RouteNames.*` constant declared today (`route_names.dart`),
  /// compile-checked by referencing the constants directly.
  const allRouteNames = <String>[
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.login,
    RouteNames.signup,
    RouteNames.home,
    RouteNames.dishDetail,
    RouteNames.menu,
    RouteNames.cart,
    RouteNames.checkout,
    RouteNames.profile,
    RouteNames.errorLogs,
    RouteNames.logs,
    RouteNames.orders,
    RouteNames.deleteAccount,
    RouteNames.orderTracker,
    RouteNames.loyalty,
    RouteNames.reservations,
    RouteNames.locations,
    RouteNames.admin,
    RouteNames.adminManage,
    RouteNames.adminMenu,
    RouteNames.privacy,
    RouteNames.waitlist,
    RouteNames.roleRouter,
    RouteNames.ownerDashboard,
    RouteNames.managerDashboard,
    RouteNames.kitchenDashboard,
    RouteNames.deliveryDashboard,
    RouteNames.adminGateway,
    RouteNames.pinDropMap,
    RouteNames.deliveryTracker,
    RouteNames.tierFlagManager,
    RouteNames.restaurantSetup,
    RouteNames.operatingHours,
    RouteNames.terms,
    RouteNames.deadLetterQueue,
  ];

  /// The route names config mode is allowed to register — derived from the
  /// REAL config screens through the ROUTER-1 `screenIdToRouteName` map.
  Set<String> configModeWhitelist() => AppConfig.screens
      .map((s) => screenIdToRouteName[s['id'] as String]!)
      .toSet();

  /// Path for a route name from the config `navigation.routes` map.
  ///
  /// CODEBASE INCONSISTENCY (recorded in the ROUTER-3 addendum):
  /// `RouteNames.errorLogs` is `'error_logs'` while the config vocabulary key
  /// (`W6.5` `knownRouteKeys`) is `'errorLogs'` — the alias makes that real
  /// drift explicit instead of silently renaming production constants.
  String? pathFor(String name) {
    final routes = AppConfig.navigationRoutes;
    if (routes.containsKey(name)) return routes[name];
    const aliases = <String, String>{RouteNames.errorLogs: 'errorLogs'};
    final alias = aliases[name];
    return alias == null ? null : routes[alias];
  }

  group(
    'ROUTER-3 T-2: RouteNames resolve only when mode-allowed (config mode)',
    () {
      setUp(() async {
        await loadRealConfigMode();
      });

      test('the source RouteNames list above has no duplicates', () {
        expect(
          allRouteNames.toSet().length,
          allRouteNames.length,
          reason: 'the compile-checked list must enumerate distinct constants',
        );
      });

      test(
        'every whitelisted RouteNames.* is registered with a resolvable path',
        () {
          final container = ProviderContainer(overrides: routerAuthOverrides());
          addTearDown(container.dispose);
          final registered = routerNamedRoutes(
            container.read(appRouterProvider),
          );

          final whitelist = configModeWhitelist();
          for (final name in whitelist) {
            expect(
              registered.containsKey(name),
              isTrue,
              reason: 'whitelisted $name must be registered in config mode',
            );
            expect(registered[name], isNotEmpty);
          }
        },
      );

      test('forbidden RouteNames.* are NOT registered in config mode '
          '(mode-forbidden fails closed at the route table)', () {
        final container = ProviderContainer(overrides: routerAuthOverrides());
        addTearDown(container.dispose);
        final registered = routerNamedRoutes(container.read(appRouterProvider));

        final whitelist = configModeWhitelist();
        final forbidden = allRouteNames
            .where((n) => !whitelist.contains(n))
            // QUEUE-1 (W5.1(d)): the DLQ ops route is the one sanctioned
            // INTERNAL route that config mode registers alongside the
            // whitelist — it is not a config screen, but it is not forbidden.
            .where((n) => n != RouteNames.deadLetterQueue)
            .toList();
        expect(
          forbidden,
          isNotEmpty,
          reason: 'there must be static-only orphans forbidden in config mode',
        );
        expect(forbidden, contains(RouteNames.admin));
        expect(forbidden, contains(RouteNames.adminManage));

        for (final name in forbidden) {
          expect(
            registered.containsKey(name),
            isFalse,
            reason:
                '$name must NOT be registered in config mode — a forbidden '
                'route that resolves here would let a kiosk build reach the '
                'admin surface',
          );
        }

        // QUEUE-1 (W5.1(d)): the DLQ internal route IS resolvable in config
        // mode even though no client config screen names it (ops surface).
        expect(
          registered[RouteNames.deadLetterQueue],
          '/dead-letters',
          reason:
              'the DLQ ops route must resolve in config mode so the banner '
              'link never fails closed on a kiosk build',
        );
      });

      test('RouteNames.adminManage is an orphan in EVERY mode — never '
          'registerable', () {
        final container = ProviderContainer(overrides: routerAuthOverrides());
        addTearDown(container.dispose);
        final configRegistered = routerNamedRoutes(
          container.read(appRouterProvider),
        );
        expect(configRegistered.containsKey(RouteNames.adminManage), isFalse);

        // Static fallback mode (screens empty).
        AppConfig.resetForTest();
        final staticContainer = ProviderContainer(
          overrides: routerAuthOverrides(),
        );
        addTearDown(staticContainer.dispose);
        final staticRegistered = routerNamedRoutes(
          staticContainer.read(appRouterProvider),
        );
        expect(staticRegistered.containsKey(RouteNames.adminManage), isFalse);
      });
      testWidgets(
        'widget-level: forbidden config-mode navigation fails CLOSED — '
        'the router error page renders, the forbidden screen never does',
        (tester) async {
          // Signed in as an OWNER so the anonymous→login redirect cannot mask
          // the route-level check: even an authorized owner must not reach the
          // static-only admin surfaces from config mode.
          final router = await pumpRouterApp(
            tester,
            overrides: routerAuthOverrides(
              authUser: MockUser(uid: 'router3-owner', email: 'owner@test.com'),
              user: const UserModel(id: 'router3-owner', role: UserRole.owner),
            ),
          );

          const forbiddenCases = <(String, Type)>[
            (RouteNames.admin, AnalyticsSnapshot),
            (RouteNames.adminMenu, AdminMenuManager),
            (RouteNames.logs, LogsScreen),
            (RouteNames.errorLogs, LogsScreen),
            (RouteNames.ownerDashboard, OwnerDashboard),
            (RouteNames.managerDashboard, ManagerDashboard),
            (RouteNames.kitchenDashboard, KitchenDashboard),
            (RouteNames.deliveryDashboard, DeliveryDashboard),
          ];

          for (final (name, forbiddenScreen) in forbiddenCases) {
            final path = pathFor(name);
            expect(
              path,
              isNotNull,
              reason: 'navigation.routes must declare a path for $name',
            );
            router.go(path!);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(
              find.text('Route Error'),
              findsOneWidget,
              reason: '$name ($path) must fail closed to the router error page',
            );
            expect(
              find.byType(forbiddenScreen),
              findsNothing,
              reason: '$name must never reach $forbiddenScreen in config mode',
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    },
  );
}
