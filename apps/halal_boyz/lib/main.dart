import 'package:core/core.dart' show CoreConfigHolder;
import 'package:flutter/material.dart';
import 'package:labs/app_bootstrap.dart' show CarnamaBootstrap, initCarnamaApp;

import 'app/app.dart';
import 'app/client_config_loader.dart';
import 'app/config_error_screen.dart';
import 'app/core_config_adapter.dart';
import 'firebase_options.dart';

/// The generated shell's entry point (white-label fleet ARCH-2).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // W6.3: read assets/client_config.json without ever throwing.
  final loaded = await loadClientConfig();
  if (loaded.error != null) {
    debugPrint('client_config.json could not be loaded: ${loaded.error}');
  }

  // W6.1 fail-closed: without a REAL Firebase API key the shell renders a
  // blocking error screen and NEVER initializes Firebase (no auth,
  // Firestore, FCM). The old silent offline boot is gone.
  if (!firebaseKeyConfigured(loaded.config)) {
    debugPrint(
      'FATAL: Firebase API key missing or placeholder '
      '(environment.firebaseAndroidApiKey / environment.firebaseIosApiKey). '
      'Boot blocked - contact the operator.',
    );
    runApp(const ConfigErrorScreen());
    return;
  }

  // B7-2 identity fast-fail: a white-label shell without its OWN
  // app.bundleId must never boot (assert in debug, throw in release).
  final coreConfig = ClientCoreConfig(loaded.config);
  CoreConfigHolder.set(coreConfig);
  CoreConfigHolder.instance.clientId;

  // The SHARED 16-step init chain (package:labs app_bootstrap.dart) with
  // the shell's own inputs. The blocking-screen builder switches the boot
  // to the shell's FAIL-CLOSED policy: a missing key or a Firebase init
  // failure renders the screen — never a silent auth-less shell.
  await initCarnamaApp(
    bootstrap: CarnamaBootstrap(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      coreConfig: coreConfig,
      appBuilder: () => GeneratedApp(config: loaded.config),
      firebaseErrorScreenBuilder: ConfigErrorScreen.new,
    ),
  );
}
