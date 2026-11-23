/// Carnama Labs — the white-label app package (white-label fleet ARCH-1).
///
/// `labs` (core_app) is the SINGLE place the real app code lives (one code
/// base serving every client). This barrel is its importable public surface:
/// a generated shell path-deps on `labs` and imports its config, router,
/// providers, and every real feature screen from here — instead of carrying
/// its own placeholder `lib/features/*` (the pre-ARCH-1 architecture gap).
///
/// Conventions:
/// - Only app-layer PUBLIC symbols are re-exported. Private internals
///   (`_*` names, template app wiring) are never surfaced; generated
///   `*.g.dart`/`*.freezed.dart` parts stay reachable through their owning
///   files and are never exported directly.
/// - Money is integer cents rendered through [formatCurrencyCents] (Law 3).
/// - Route vocabulary is [RouteNames]; the config-driven route table is
///   [appRouterProvider] + [screenIdToRouteName] (26 whitelisted screens,
///   plus the one internal DLQ ops route registered by the router).
/// - The labs copy of [GdprConsentDialog] is the canonical one — shells
///   that ALSO import `core_ui` must hide the core_ui duplicate exactly
///   like `core_app/lib/app_bootstrap.dart:38` and
///   `core_app/lib/features/home/presentation/home_screen.dart:1` do
///   (`core_ui` exports no `ForceUpdateGuard`; those are the repo's only
///   cross-package `hide` clauses).
library;

// ── Shared app bootstrap (ARCH-2): the ONE init sequence ─────────────────
// `initCarnamaApp` + its [CarnamaBootstrap] inputs ARE the entire boot
// chain (the 16 documented steps in `app_bootstrap.dart`). A shell loads
// ITS OWN per-project `firebase_options.dart` + client config and calls
// the SAME function the template app calls — `main.dart` itself is a thin
// wrapper over this and is NOT surfaced.
export 'app_bootstrap.dart'
    show
        CarnamaBootstrap,
        CoreApp,
        buildGracefulErrorWidget,
        firebaseKeyConfigured,
        initCarnamaApp,
        navigatorKey,
        pushNavigationBridge;

// Router: config-driven route table + the static fallback + go_router ref.
export 'app/app_router.dart'
    show appRouterProvider, screenIdToRouteName, activeRouter;
export 'app/navigation/route_names.dart' show RouteNames;

// App config: the layered config loader (defaults < dotenv < client JSON),
// theme statics, screens registry, and the per-client theme provider.
export 'app/config/app_config.dart'
    show AppConfig, screenVariantProvider, screenVariantsProvider;

// PERF-5: the config-driven screen-variant registry (validated vocabulary,
// resolver, byte-for-byte default). The loadConfig gate consuming it lives
// in app_config.dart.
export 'app/config/screen_variants.dart' show ScreenVariants;

// Fail-closed schema gate screen (labs copy; the shell owns its own
// ConfigErrorScreen — the missing-Firebase-key gate is client-specific).
export 'app/config/config_validation_error_screen.dart'
    show ConfigValidationErrorScreen;

// Money (integer cents, single canonical customer-facing formatter).
export 'app/config/currency_format.dart'
    show formatCurrencyCents, currencySymbolFor;

// Force-update chain (labs copies — canonical, see library doc).
export 'app/config/force_update_service.dart'
    show ForceUpdateService, ForceUpdateStatus;
export 'app/config/force_update_guard.dart'
    show ForceUpdateGuard, ForceUpdateDecision, forceUpdateStatusProvider;

// GDPR analytics consent (labs copy — canonical, see library doc).
export 'app/compliance/gdpr_consent_dialog.dart' show GdprConsentDialog;

// Status/role label maps (exhaustive switches — never `.name` in UI).
export 'app/l10n/status_role_labels.dart' show orderStatusLabel, userRoleLabel;

// l10n (complete en+ar ARB — the shell's own ARB set was deleted in ARCH-1).
export 'l10n/app_localizations.dart' show AppLocalizations;

// ── Boot/service wiring helpers (offline queue + kitchen heartbeat) ───────
// Shells wire these after their own Firebase/Isar init, mirroring
// `core_app/lib/main.dart`. OrderPayloadAdapter bridges the feature-layer
// OrderModel into the core KitchenOfflineService contract.
export 'app/sync_queue_auto_trigger.dart' show SyncQueueAutoTrigger;
export 'app/kitchen_heartbeat_scheduler.dart' show KitchenHeartbeatScheduler;
export 'app/queue_sync_scheduler.dart' show QueueSyncScheduler;
export 'features/orders/domain/order_payload_adapter.dart'
    show OrderPayloadAdapter;

// ── Key providers on the real screens (menu/cart/home feed) ───────────────
export 'features/menu/presentation/merged_menu_provider.dart'
    show mergedMenuProvider, currentBranchIdProvider;
export 'features/home/domain/home_service.dart'
    show HomeService, HomePromotion, HomeBranch, homeServiceProvider;
export 'app/config/restaurant_config_service.dart'
    show restaurantConfigProvider, restaurantConfigRepositoryProvider;
export 'app/models/restaurant_config_model.dart' show RestaurantConfigModel;
export 'app/config/feature_flags_service.dart'
    show FeatureFlagsService, featureFlagsProvider;
export 'features/menu/domain/menu_item_model.dart' show MenuItemModel;

// ── Real feature screens (the white-label shell's entire UI) ──────────────
// Splash + onboarding
export 'features/splash/presentation/splash_screen.dart' show SplashScreen;
export 'features/onboarding/presentation/onboarding_screen.dart'
    show OnboardingScreen;
// Auth
export 'features/auth/presentation/login_screen.dart' show LoginScreen;
export 'features/auth/presentation/signup_screen.dart' show SignupScreen;
export 'features/auth/presentation/terms_of_service_screen.dart'
    show TermsOfServiceScreen;
// Customer: home / menu / dish detail
export 'features/home/presentation/home_screen.dart' show HomeScreen;
export 'features/menu/presentation/menu_screen.dart' show MenuScreen;
export 'features/menu/presentation/dish_detail_screen.dart'
    show DishDetailScreen;
// Cart + checkout
export 'features/cart/presentation/cart_screen.dart' show CartScreen;
export 'features/checkout/presentation/checkout_screen.dart'
    show CheckoutScreen;
// Orders + tracking
export 'features/orders/presentation/order_tracker_screen.dart'
    show OrderTrackerScreen;
export 'features/orders/presentation/order_history_screen.dart'
    show OrderHistoryScreen;
export 'features/tracking/presentation/delivery_tracker_screen.dart'
    show DeliveryTrackerScreen;
// Locations + waitlist
export 'features/locations/presentation/location_screen.dart'
    show LocationScreen;
export 'features/location/presentation/pin_drop_map_screen.dart'
    show PinDropMapScreen;
export 'features/waitlist/presentation/waitlist_screen.dart'
    show WaitlistScreen;
// Reservations + loyalty + profile
export 'features/reservations/presentation/reservation_screen.dart'
    show ReservationScreen;
export 'features/loyalty/presentation/loyalty_screen.dart' show LoyaltyScreen;
export 'features/profile/presentation/profile_screen.dart' show ProfileScreen;
// Compliance (GDPR Art.17)
export 'features/compliance/presentation/delete_account_screen.dart'
    show DeleteAccountScreen;
// Admin: gateway + dashboards + setup + ops
export 'features/admin/presentation/analytics_snapshot.dart'
    show AnalyticsSnapshot;
export 'features/admin/presentation/admin_menu_manager.dart'
    show AdminMenuManager;
export 'features/admin/presentation/privacy_policy_screen.dart'
    show PrivacyPolicyScreen;
export 'features/admin/presentation/role_router_screen.dart'
    show RoleRouterScreen;
export 'features/admin/presentation/owner/owner_dashboard.dart'
    show OwnerDashboard;
export 'features/admin/presentation/manager/manager_dashboard.dart'
    show ManagerDashboard;
export 'features/admin/presentation/kitchen/kitchen_dashboard.dart'
    show KitchenDashboard;
export 'features/admin/presentation/delivery/delivery_dashboard.dart'
    show DeliveryDashboard;
export 'features/admin/presentation/gateway/admin_gateway_screen.dart'
    show AdminGatewayScreen;
export 'features/admin/presentation/dead_letter_screen.dart'
    show DeadLetterScreen;
export 'features/admin/presentation/setup/tier_flag_manager_screen.dart'
    show TierFlagManagerScreen;
export 'features/admin/presentation/setup/restaurant_setup_screen.dart'
    show RestaurantSetupScreen;
export 'features/admin/presentation/setup/operating_hours_screen.dart'
    show OperatingHoursScreen;
