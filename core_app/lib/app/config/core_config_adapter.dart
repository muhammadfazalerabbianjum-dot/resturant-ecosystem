import 'package:core/core.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/config/demo_config.dart';

/// Adapter that injects app-level values into the `core` package.
///
/// `core` must never depend on app-level configuration (Law 43). This adapter
/// bridges [AppConfig] and [kDemoMode] into [CoreConfigHolder] once at startup
/// (see `main.dart`).
class CoreAppConfig implements CoreConfig {
  const CoreAppConfig();

  @override
  bool get isDemoMode => kDemoMode;

  /// The bundle ID is the stable per-app identifier used by the Cloud
  /// Function `calculateTax` to look up per-client tax rates. It is unique
  /// per white-label build.
  @override
  String get clientId => AppConfig.bundleId;

  @override
  String get cloudinaryUploadPreset => AppConfig.cloudinaryUploadPreset;

  @override
  String get cloudinaryCloudName => AppConfig.cloudinaryCloudName;

  @override
  List<String> get ownerEmails => const [];

  /// OFFLINE_FALLBACK: Kitchen LAN endpoint used only when the restaurant has
  /// not yet configured their kitchen terminal IP. W6.4(3): the endpoint is
  /// CONFIG-DRIVEN (`environment.kitchenLanEndpoint` in client_config.json,
  /// layered over the `KITCHEN_LAN_ENDPOINT` dotenv value) — the stale
  /// hard-coded fallback IP is gone. Empty means "not configured" (the same
  /// fail-closed semantics as the generated shell's adapter); the
  /// per-restaurant live override remains Firestore
  /// `settings/restaurantConfig.kitchenLanEndpoint`.
  @override
  String get kitchenLanEndpoint => AppConfig.kitchenLanEndpoint;
}
