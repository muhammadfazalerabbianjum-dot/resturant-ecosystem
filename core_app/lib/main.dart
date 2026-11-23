import 'app_bootstrap.dart';
import 'app/config/core_config_adapter.dart';
import 'firebase_options.dart';

/// Carnama template app entry point (white-label fleet ARCH-2).
///
/// A THIN WRAPPER: the entire 16-step init sequence lives in
/// `app_bootstrap.dart` (`initCarnamaApp`) — this file only supplies the
/// template app's inputs: its own per-project `firebase_options.dart`
/// (API keys via --dart-define per Law 16 — zero keys in source control),
/// the `CoreAppConfig` adapter (Law 43) and the `CoreApp` root widget.
/// Every generated shell calls the SAME function with ITS options/config/
/// widget (see `core_app/tool/whitelabel.dart`).
Future<void> main() async {
  await initCarnamaApp(
    bootstrap: CarnamaBootstrap(
      // The template app's own per-platform Firebase options.
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      // Law 43: app-level values injected into the core package.
      coreConfig: const CoreAppConfig(),
      // The real app widget (router + config theme + l10n + overlays).
      appBuilder: () => const CoreApp(),
      // The template app opts into the OPTIONAL .env layer (Law 16
      // layer-2; absence is an explicit, non-fatal degradation — STEP 06);
      // shells don't.
      loadEnv: true,
    ),
  );
}
