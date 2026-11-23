/// Abstract configuration interface for the core package.
///
/// Core must never depend on app-specific configuration (e.g. `--dart-define`
/// flags, `flutter_dotenv`, or app-level values). App-specific values are
/// injected by the application layer via [CoreConfig.set] (Law 43: Anti-Shortcut).
abstract class CoreConfig {
  /// Whether the app is running in demo mode (no Cloud Functions).
  ///
  /// In the application this maps to `kDemoMode` from `demo_config.dart`.
  bool get isDemoMode;

  /// Stable per-app identifier used to scope server-side data (tax rates,
  /// feature flags, promo codes) to the correct client.
  ///
  /// In white-label builds this maps to the app's bundle ID (e.g.
  /// `com.halalboyz.app`), unique per generated app. The `calculateTax`
  /// Cloud Function requires this field to look up per-client rates.
  String get clientId;

  /// The Cloudinary unsigned upload preset used by the upload service.
  ///
  /// In the application this maps to `AppConfig.cloudinaryUploadPreset`.
  String get cloudinaryUploadPreset;

  /// The Cloudinary cloud name used by the upload service.
  ///
  /// Single source of truth for the Cloudinary account (Law 3). In the
  /// application this maps to `--dart-define=CLOUDINARY_CLOUD_NAME=...`.
  String get cloudinaryCloudName;

  /// Emails that should be granted the `owner` role on first run.
  ///
  /// In the application this maps to `--dart-define=OWNER_EMAILS=...`
  /// (comma-separated). Empty by default — seeding is a no-op.
  List<String> get ownerEmails;

  /// The kitchen LAN endpoint for offline order synchronisation.
  ///
  /// Every restaurant has a DIFFERENT kitchen terminal IP. This must be
  /// configurable per-restaurant at runtime (from Firestore restaurant_config
  /// or --dart-define), NOT a compile-time constant (Law 3).
  String get kitchenLanEndpoint;
}

/// Default configuration used when no override is provided.
///
/// Safe, production-like defaults so the package compiles and behaves
/// predictably standalone. The app layer overrides via [CoreConfig.set].
class DefaultCoreConfig implements CoreConfig {
  const DefaultCoreConfig();

  @override
  bool get isDemoMode => false;

  @override
  String get clientId => 'carnama';

  // OFFLINE_FALLBACK: app layer MUST inject the real per-build Cloudinary
  // preset via CoreConfig.set (from AppConfig / --dart-define). An empty
  // default guarantees a white-label shell can never silently upload into
  // someone else's (or the reference app's) live Cloudinary account if the
  // composition step is missed.
  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const [];

  // OFFLINE_FALLBACK: every restaurant has a DIFFERENT kitchen terminal IP.
  // This value is used only when the app layer has not yet injected a
  // per-restaurant endpoint (from Firestore restaurant_config or
  // --dart-define). It must never be shipped as a live endpoint for a real
  // client — the app layer overrides via CoreConfig.set (Law 3).
  @override
  String get kitchenLanEndpoint => 'http://192.168.1.100:8080/api/orders';
}

/// Global configuration holder for the core package.
///
/// Services read app-level values through [CoreConfig.instance]. The
/// application calls [CoreConfig.set] once during composition (e.g. in
/// `main.dart`) to inject its own values. Defaults are safe and testable.
class CoreConfigHolder {
  CoreConfigHolder._();

  static CoreConfig _instance = const DefaultCoreConfig();

  /// The active configuration. Defaults to [DefaultCoreConfig].
  static CoreConfig get instance => _instance;

  /// Replaces the active configuration. Call once at app startup.
  static void set(CoreConfig config) => _instance = config;
}
