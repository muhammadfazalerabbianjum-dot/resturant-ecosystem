import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/navigation/route_names.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../app_bootstrap.dart' show navigatorKey;
import 'config/app_config.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/menu/presentation/menu_screen.dart';
import '../features/menu/presentation/dish_detail_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/orders/presentation/order_history_screen.dart';
import '../features/reservations/presentation/reservation_screen.dart';
import '../features/loyalty/presentation/loyalty_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/admin/presentation/analytics_snapshot.dart';
import '../features/admin/presentation/admin_menu_manager.dart';
import '../features/admin/presentation/privacy_policy_screen.dart';
import '../features/locations/presentation/location_screen.dart';
import '../features/waitlist/presentation/waitlist_screen.dart';
import '../features/orders/presentation/order_tracker_screen.dart';
import '../features/compliance/presentation/delete_account_screen.dart';
import '../features/menu/domain/menu_item_model.dart';
import '../features/admin/presentation/role_router_screen.dart';
import '../features/admin/presentation/owner/owner_dashboard.dart';
import '../features/admin/presentation/manager/manager_dashboard.dart';
import '../features/admin/presentation/kitchen/kitchen_dashboard.dart';
import '../features/admin/presentation/delivery/delivery_dashboard.dart';
import '../features/auth/presentation/terms_of_service_screen.dart';
import '../features/admin/presentation/gateway/admin_gateway_screen.dart';
import '../features/admin/presentation/dead_letter_screen.dart';
import '../features/admin/presentation/setup/tier_flag_manager_screen.dart';
import '../features/admin/presentation/setup/restaurant_setup_screen.dart';
import '../features/admin/presentation/setup/operating_hours_screen.dart';
import '../features/location/presentation/pin_drop_map_screen.dart';
import '../features/tracking/presentation/delivery_tracker_screen.dart';

/// Maps a screen ID from the client config `screens` section to its widget,
/// honouring path parameters, query parameters, and router extras exactly like
/// the static route list (no suboptimal empty-parameter fallbacks).
Widget _getScreenWidget(String screenId, GoRouterState state) {
  switch (screenId) {
    case 'SplashScreen':
      return const SplashScreen();
    case 'OnboardingScreen':
      return const OnboardingScreen();
    case 'LoginScreen':
      return const LoginScreen();
    case 'SignupScreen':
      return const SignupScreen();
    case 'HomeScreen':
      return const HomeScreen();
    case 'MenuScreen':
      return MenuScreen(initialCategory: state.uri.queryParameters['category']);
    case 'DishDetailScreen':
      final menuItem = state.extra as MenuItemModel?;
      return DishDetailScreen(
        menuItemId: menuItem?.id ?? state.pathParameters['id'] ?? '',
      );
    case 'CartScreen':
      return const CartScreen();
    case 'CheckoutScreen':
      return const CheckoutScreen();
    case 'OrderTrackerScreen':
      return OrderTrackerScreen(orderId: state.pathParameters['orderId'] ?? '');
    case 'OrderHistoryScreen':
      return const OrderHistoryScreen();
    case 'ReservationScreen':
      return const ReservationScreen();
    case 'LocationScreen':
      return const LocationScreen();
    case 'PinDropMapScreen':
      return const PinDropMapScreen();
    case 'WaitlistScreen':
      return const WaitlistScreen();
    case 'LoyaltyScreen':
      return const LoyaltyScreen();
    case 'ProfileScreen':
      return const ProfileScreen();
    case 'DeleteAccountScreen':
      return const DeleteAccountScreen();
    case 'DeliveryTrackerScreen':
      return DeliveryTrackerScreen(
        orderId: state.pathParameters['orderId'] ?? '',
      );
    case 'TermsOfServiceScreen':
      return const TermsOfServiceScreen();
    case 'PrivacyPolicyScreen':
      return const PrivacyPolicyScreen();
    case 'RoleRouterScreen':
      return const RoleRouterScreen();
    case 'AdminGatewayScreen':
      return const AdminGatewayScreen();
    case 'TierFlagManagerScreen':
      return const TierFlagManagerScreen();
    case 'RestaurantSetupScreen':
      return const RestaurantSetupScreen();
    case 'OperatingHoursScreen':
      return const OperatingHoursScreen();
    // static-mode-only orphan (W2.6): no client_config screens[].id reaches
    // this case — never routed in config mode (debug log surface only).
    case 'LogsScreen':
      return const LogsScreen();
    case 'OwnerDashboard':
      return const OwnerDashboard();
    case 'ManagerDashboard':
      return const ManagerDashboard();
    case 'KitchenDashboard':
      return const KitchenDashboard();
    case 'DeliveryDashboard':
      return const DeliveryDashboard();
    case 'AnalyticsSnapshot':
      return const AnalyticsSnapshot();
    // static-mode-only orphan (W2.6): no client_config screens[].id reaches
    // this case — never routed in config mode (static `/admin/menu` only).
    case 'AdminMenuManager':
      return const AdminMenuManager();
    default:
      // All 27 screens from the config template are explicitly mapped above.
      // This is a safety net for genuinely unknown client-defined screen IDs.
      return Scaffold(
        appBar: AppBar(
          title: Builder(
            builder: (context) => Text(
              AppLocalizations.of(context).configFallbackScreenTitle(screenId),
            ),
          ),
        ),
        body: Center(
          child: Builder(
            builder: (context) => Text(
              AppLocalizations.of(context).configFallbackScreenBody(screenId),
            ),
          ),
        ),
      );
  }
}

/// Maps a config `screens[].id` to its registered route name.
///
/// `RouteNames` constants are the single source for named navigation (the
/// named-nav call sites in `lib/`): config-mode registration resolves screen
/// ids THROUGH this compile-checked map, never the reverse. Every
/// `screens[].id` present in BOTH `core_app/assets/client_config.json` and
/// `apps/halal_boyz/assets/client_config.json` must be a key here —
/// `core_app/test/app/app_router_test.dart` (T-1) asserts that against the
/// real JSON files. Registering under the raw screen id instead left every
/// `goNamed`/`pushNamed(RouteNames.*)` call site crashing on go_router's
/// "unknown route name" failure (00-P0-1).
const Map<String, String> screenIdToRouteName = {
  'SplashScreen': RouteNames.splash,
  'OnboardingScreen': RouteNames.onboarding,
  'LoginScreen': RouteNames.login,
  'SignupScreen': RouteNames.signup,
  'HomeScreen': RouteNames.home,
  'MenuScreen': RouteNames.menu,
  'DishDetailScreen': RouteNames.dishDetail,
  'CartScreen': RouteNames.cart,
  'CheckoutScreen': RouteNames.checkout,
  'OrderTrackerScreen': RouteNames.orderTracker,
  'OrderHistoryScreen': RouteNames.orders,
  'ReservationScreen': RouteNames.reservations,
  'LocationScreen': RouteNames.locations,
  'PinDropMapScreen': RouteNames.pinDropMap,
  'WaitlistScreen': RouteNames.waitlist,
  'LoyaltyScreen': RouteNames.loyalty,
  'ProfileScreen': RouteNames.profile,
  'DeliveryTrackerScreen': RouteNames.deliveryTracker,
  'DeleteAccountScreen': RouteNames.deleteAccount,
  'TermsOfServiceScreen': RouteNames.terms,
  'PrivacyPolicyScreen': RouteNames.privacy,
  'RoleRouterScreen': RouteNames.roleRouter,
  'AdminGatewayScreen': RouteNames.adminGateway,
  'TierFlagManagerScreen': RouteNames.tierFlagManager,
  'RestaurantSetupScreen': RouteNames.restaurantSetup,
  'OperatingHoursScreen': RouteNames.operatingHours,
};

/// The active [GoRouter] built by [appRouterProvider].
///
/// Out-of-widget callbacks (the deep-link handler and sign-out navigation in
/// `main.dart`) resolve the live router through this reference — go_router is
/// the only navigation stack, so nothing may fall back to the deprecated
/// `Navigator` name API. Refreshed on every provider rebuild and nulled on
/// dispose so a stale router is never navigable.
GoRouter? activeRouter;

/// Builds [GoRoute]s from the client config `screens` section (Phase 2.2).
///
/// When the config has no screens (fallback), returns an empty list so the
/// caller can use the static route list instead. Routes are registered under
/// their [RouteNames] constant (resolved through [screenIdToRouteName]) so
/// `goNamed`/`pushNamed(RouteNames.*)` call sites resolve in config mode too.
/// An id missing from [screenIdToRouteName] fails closed: assert + log + SKIP
/// registration in debug, log-and-skip in release (W2.1).
List<GoRoute> _buildRoutesFromConfig(LoggerService logger) {
  final screens = AppConfig.screens;
  if (screens.isEmpty) return const [];

  final routes = <GoRoute>[];
  for (final screen in screens) {
    final id = screen['id'] as String?;
    final route = screen['route'] as String?;
    if (id == null || route == null || route.isEmpty) continue;
    final routeName = screenIdToRouteName[id];
    if (routeName == null) {
      // Fail-closed (W2.1): an unmapped id must never register a route under
      // an unusable name. Debug: assert + log. Release: log-and-skip.
      assert(false, 'screen id $id has no RouteNames mapping');
      unawaited(
        logger.error(
          StateError('screen id $id has no RouteNames mapping'),
          'RouterConfigUnmappedScreenId',
        ),
      );
      continue;
    }
    routes.add(
      GoRoute(
        name: routeName,
        path: route,
        pageBuilder: (c, s) => FadeSlideTransitionPage(
          name: routeName,
          child: _getScreenWidget(id, s),
        ),
      ),
    );
  }
  return routes;
}

// keepAlive
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userState = ref.watch(currentUserProvider);
  final logger = ref.watch(loggerProvider);

  // Phase 2.2: use config-driven routes when available; fall back to static.
  final configRoutes = _buildRoutesFromConfig(logger);
  final baseRoutes = configRoutes.isNotEmpty ? configRoutes : _staticRoutes;
  // QUEUE-1 (W5.1(d)): the DLQ ops route is an INTERNAL route, registered in
  // BOTH router modes — config mode registers exactly the whitelisted
  // `screens[].id` routes PLUS this one sanctioned internal ops route.
  final routes = [...baseRoutes, ..._deadLetterQueueRoute];

  final router = GoRouter(
    navigatorKey: navigatorKey,
    // UX-4 (07-P1-7): screen_view analytics. The observer emits one
    // screen_view per named route transition (names exported on every page
    // below). Empty list when Firebase is uninitialized — router
    // construction must never crash for analytics.
    observers: AnalyticsService.routeObservers(),
    initialLocation: AppConfig.navigationEntryPoint,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).routeErrorTitle)),
      body: Center(
        child: Text(
          AppLocalizations.of(context).routeErrorBody(state.error.toString()),
        ),
      ),
    ),
    redirect: (context, state) {
      if (authState.isLoading || userState.isLoading) {
        return null; // Wait for auth to resolve
      }
      final isLoggedIn = authState.valueOrNull != null;
      final role = userState.valueOrNull?.role ?? 'customer';
      final path = state.matchedLocation;

      if (path == '/splash') {
        return null; // Splash screen controls its own navigation
      }

      final publicPaths = [
        '/login',
        '/signup',
        '/',
        '/menu',
        '/cart',
        '/onboarding',
        '/locations',
        '/waitlist',
        '/privacy', // Must be reachable without login (store rejection reason #36)
        '/terms', // Must be reachable without login (store rejection reason #36)
        '/admin-gateway', // Gateway PIN screen reached via 20-tap; validated inside
      ];
      final isPublic = publicPaths.contains(path);

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn &&
          (path == '/login' || path == '/signup' || path == '/onboarding')) {
        return '/';
      }

      // Security enforced by Firestore Rules – no client-side role checks.
      // The role variable is intentionally unused here to prevent
      // client-side enforcement that could be bypassed.
      (role); // reference to avoid unused variable warning

      return null;
    },
    routes: routes,
  );

  activeRouter = router;
  ref.onDispose(() {
    if (identical(activeRouter, router)) {
      activeRouter = null;
    }
  });
  return router;
});

/// QUEUE-1 (W5.1(d)): the operator DLQ screen is an internal route that must
/// resolve in BOTH router modes. Config mode otherwise registers exactly the
/// whitelisted screens — this single sanctioned internal ops route is appended
/// to whichever base table is active (see `appRouterProvider`).
final List<GoRoute> _deadLetterQueueRoute = [
  GoRoute(
    name: RouteNames.deadLetterQueue,
    path: '/dead-letters',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.deadLetterQueue,
      child: const DeadLetterScreen(),
    ),
  ),
];

/// Static fallback routes used when the client config has no `screens` section.
final List<GoRoute> _staticRoutes = [
  GoRoute(
    name: RouteNames.splash,
    path: '/splash',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.splash,
      child: const SplashScreen(),
    ),
  ),
  GoRoute(
    name: RouteNames.onboarding,
    path: '/onboarding',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.onboarding,
      child: const OnboardingScreen(),
    ),
  ),
  // ── Auth ──────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.login,
    path: '/login',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.login,
      child: const LoginScreen(),
    ),
  ),
  GoRoute(
    name: RouteNames.signup,
    path: '/signup',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.signup,
      child: const SignupScreen(),
    ),
  ),

  // ── Home ──────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.home,
    path: '/',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.home,
      child: const HomeScreen(),
    ),
  ),

  // ── Menu ──────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.menu,
    path: '/menu',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.menu,
      child: MenuScreen(initialCategory: s.uri.queryParameters['category']),
    ),
  ),

  // ── Dish Detail ───────────────────────────────────────────
  GoRoute(
    name: RouteNames.dishDetail,
    path: '/dish/:id',
    pageBuilder: (c, s) {
      // Extra is passed by the router
      final menuItem = s.extra as MenuItemModel?;
      return FadeSlideTransitionPage(
        name: RouteNames.dishDetail,
        child: DishDetailScreen(
          menuItemId: menuItem?.id ?? s.pathParameters['id'] ?? '',
        ),
      );
    },
  ),

  // ── Cart ──────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.cart,
    path: '/cart',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.cart,
      child: const CartScreen(),
    ),
  ),

  // ── Checkout ──────────────────────────────────────────────
  GoRoute(
    name: RouteNames.checkout,
    path: '/checkout',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.checkout,
      child: const CheckoutScreen(),
    ),
  ),

  // ── Order Tracker ─────────────────────────────────────────
  GoRoute(
    name: RouteNames.orderTracker,
    path: '/orders/:orderId',
    pageBuilder: (c, s) {
      final orderId = s.pathParameters['orderId'] ?? '';
      return FadeSlideTransitionPage(
        name: RouteNames.orderTracker,
        child: OrderTrackerScreen(orderId: orderId),
      );
    },
  ),

  // ── Orders ────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.orders,
    path: '/orders',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.orders,
      child: const OrderHistoryScreen(),
    ),
  ),

  // ── Reservations ──────────────────────────────────────────
  GoRoute(
    name: RouteNames.reservations,
    path: '/reservations',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.reservations,
      child: const ReservationScreen(),
    ),
  ),

  // ── Locations ─────────────────────────────────────────────
  GoRoute(
    name: RouteNames.locations,
    path: '/locations',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.locations,
      child: const LocationScreen(),
    ),
  ),

  // ── Pin-Drop Map ────────────────────────────────────────────
  // W2.6: surfaced from LocationScreen (one icon button -> pushNamed).
  // The config-mode route is registered through the client_config screens
  // section; this static route keeps the fallback mode crash-free.
  GoRoute(
    name: RouteNames.pinDropMap,
    path: '/location/map',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.pinDropMap,
      child: const PinDropMapScreen(),
    ),
  ),

  // ── Waitlist ──────────────────────────────────────────────
  GoRoute(
    name: RouteNames.waitlist,
    path: '/waitlist',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.waitlist,
      child: const WaitlistScreen(),
    ),
  ),

  // ── Loyalty ───────────────────────────────────────────────
  GoRoute(
    name: RouteNames.loyalty,
    path: '/loyalty',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.loyalty,
      child: const LoyaltyScreen(),
    ),
  ),

  // ── Profile ───────────────────────────────────────────────
  GoRoute(
    name: RouteNames.profile,
    path: '/profile',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.profile,
      child: const ProfileScreen(),
    ),
  ),

  // ── Hidden Logs ───────────────────────────────────────────
  GoRoute(
    name: RouteNames.errorLogs,
    path: '/error-logs',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.errorLogs,
      child: const LogsScreen(),
    ),
  ),

  // ── Admin ─────────────────────────────────────────────────
  GoRoute(
    name: RouteNames.admin,
    path: '/admin',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.admin,
      child: const AnalyticsSnapshot(),
    ),
    routes: [
      GoRoute(
        name: RouteNames.adminMenu,
        path: 'menu',
        pageBuilder: (c, s) => FadeSlideTransitionPage(
          name: RouteNames.adminMenu,
          child: const AdminMenuManager(),
        ),
      ),
    ],
  ),

  // ── Role-Based Admin Dashboards ───────────────────────────
  GoRoute(
    name: RouteNames.roleRouter,
    path: '/role-router',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.roleRouter,
      child: const RoleRouterScreen(),
    ),
  ),
  GoRoute(
    name: RouteNames.ownerDashboard,
    path: '/owner',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.ownerDashboard,
      child: const OwnerDashboard(),
    ),
  ),
  GoRoute(
    name: RouteNames.managerDashboard,
    path: '/manager',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.managerDashboard,
      child: const ManagerDashboard(),
    ),
  ),
  GoRoute(
    name: RouteNames.kitchenDashboard,
    path: '/kitchen',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.kitchenDashboard,
      child: const KitchenDashboard(),
    ),
  ),
  GoRoute(
    name: RouteNames.deliveryDashboard,
    path: '/delivery',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.deliveryDashboard,
      child: const DeliveryDashboard(),
    ),
  ),

  // ── Privacy ───────────────────────────────────────────────
  GoRoute(
    name: RouteNames.privacy,
    path: '/privacy',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.privacy,
      child: const PrivacyPolicyScreen(),
    ),
  ),

  // ── Terms of Service ──────────────────────────────────────
  GoRoute(
    name: 'terms',
    path: '/terms',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: 'terms',
      child: const TermsOfServiceScreen(),
    ),
  ),

  // ── Delete Account (GDPR Art.17) ──────────────────────────
  GoRoute(
    name: 'deleteAccount',
    path: '/delete-account',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: 'deleteAccount',
      child: const DeleteAccountScreen(),
    ),
  ),

  // ── Logs (debug) ──────────────────────────────────────────
  GoRoute(
    name: RouteNames.logs,
    path: '/logs',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.logs,
      child: const LogsScreen(),
    ),
  ),

  // ── Admin Gateway (role-verified staff entry) ───────────────────
  GoRoute(
    name: RouteNames.adminGateway,
    path: '/admin-gateway',
    pageBuilder: (c, s) => FadeSlideTransitionPage(
      name: RouteNames.adminGateway,
      child: const AdminGatewayScreen(),
    ),
  ),
];
