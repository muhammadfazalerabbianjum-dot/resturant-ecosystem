class RouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const signup = 'signup';
  static const home = 'home';
  static const dishDetail = 'dishDetail';
  static const menu = 'menu';
  static const cart = 'cart';
  static const checkout = 'checkout';
  static const String profile = 'profile';
  static const String errorLogs = 'error_logs';
  static const logs = 'logs';
  static const orders = 'orders';
  static const deleteAccount = 'deleteAccount';
  static const orderTracker = 'orderTracker';
  static const loyalty = 'loyalty';
  static const reservations = 'reservations';
  static const locations = 'locations';
  static const admin = 'admin';
  static const adminManage = 'adminManage';
  static const adminMenu = 'adminMenu';
  static const privacy = 'privacy';
  static const waitlist = 'waitlist';
  static const roleRouter = 'roleRouter';
  static const ownerDashboard = 'ownerDashboard';
  static const managerDashboard = 'managerDashboard';
  static const kitchenDashboard = 'kitchenDashboard';
  static const deliveryDashboard = 'deliveryDashboard';
  static const adminGateway = 'adminGateway';

  /// QUEUE-1 (W5.1(d)): operator DLQ screen (owner/admin). Registered in BOTH
  /// router modes — static fallback AND config mode (see `app_router.dart`).
  static const deadLetterQueue = 'deadLetterQueue';

  // ── Config-mode route names (ROUTER-1 / W2.1 screen-id resolution) ────────
  /// Registered for `PinDropMapScreen` (`/location/map`), config-mode only.
  static const pinDropMap = 'pinDropMap';

  /// Registered for `DeliveryTrackerScreen` (`/tracking/:orderId`), config-mode only.
  static const deliveryTracker = 'deliveryTracker';

  /// Registered for `TierFlagManagerScreen` (`/admin/setup/tier-flags`), config-mode only.
  static const tierFlagManager = 'tierFlagManager';

  /// Registered for `RestaurantSetupScreen` (`/admin/setup/restaurant`), config-mode only.
  static const restaurantSetup = 'restaurantSetup';

  /// Registered for `OperatingHoursScreen` (`/admin/setup/hours`), config-mode only.
  static const operatingHours = 'operatingHours';

  /// Terms of service; the static route table registers `/terms` under the
  /// same name literal (`core_app/lib/app/app_router.dart`).
  static const terms = 'terms';
}
