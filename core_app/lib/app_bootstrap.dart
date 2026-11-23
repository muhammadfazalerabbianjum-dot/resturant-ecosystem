/// CARNAMA SHARED APP BOOTSTRAP (white-label fleet ARCH-2).
///
/// ONE init sequence for every app in the fleet: the template app
/// (`core_app/lib/main.dart`) and every generated shell call the SAME
/// `initCarnamaApp()` with THEIR inputs ([CarnamaBootstrap]). A caller never
/// re-implements init — it loads its own per-project `firebase_options.dart`
/// and client config and hands them in.
///
/// ## INIT ORDER (the 16-step boot chain — ARCH-2 T-3 pins the source order
/// of the call sites below to this list):
///
/// ```text
/// STEP 01 — fail-fast demo-mode release guard     (before any Flutter binding)
/// STEP 02 — background FCM handler registration   (before anything else touches Firebase)
/// STEP 03 — graceful error widget builder         (BEFORE Firebase init — must work without it)
/// STEP 04 — PlatformDispatcher.onError handler    (logger + Crashlytics, set ONCE)
/// STEP 05 — WidgetsFlutterBinding.ensureInitialized (first statement inside the guarded zone)
/// STEP 06 — dotenv .env load (template app only)  (Law 16 layer-2, before the config load)
/// STEP 07 — AppConfig.loadConfig()                (layer-3 client config; records loadError/schemaError)
/// STEP 08 — AppTheme font-registry hydration      (awaited: registered before the first ThemeData)
/// STEP 09 — CoreConfigHolder.set(coreConfig)      (Law 43 injection — after the config load)
/// STEP 10 — LoggerService init                    (BEFORE Firebase — captures early crashes)
/// STEP 11 — config load-failure surfacing         (W6.4(2); recorded via the logger — never silent)
/// STEP 12 — W6.5 schema gate                      (blocking screen BEFORE runApp and Firebase)
/// STEP 13 — W6.1 Firebase key gate                (blocking screen BEFORE Firebase.initializeApp)
/// STEP 14 — Firebase init chain                   (emulators, AppCheck, GDPR consent, FCM, Push,
///                                                  Stripe: consent AFTER Firebase; push AFTER FCM)
/// STEP 15 — Isar openDB                           (sync-queue triggers + kitchen heartbeat AFTER Isar)
/// STEP 16 — push navigation bridge + runApp       (ProviderScope overrides + ForceUpdateGuard)
/// ```
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart' hide GdprConsentDialog;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

import 'app/app_router.dart';
import 'app/compliance/gdpr_consent_dialog.dart';
import 'app/config/app_config.dart';
import 'app/config/config_validation_error_screen.dart';
import 'app/config/demo_config.dart';
import 'app/config/force_update_guard.dart';
import 'app/kitchen_heartbeat_scheduler.dart';
import 'app/navigation/route_names.dart';
import 'app/presence_lifecycle_observer.dart';
import 'app/queue_sync_scheduler.dart';
import 'app/sync_queue_auto_trigger.dart';
import 'features/orders/domain/order_payload_adapter.dart';
import 'l10n/app_localizations.dart';

/// The caller-supplied inputs for [initCarnamaApp] (ARCH-2 acceptance
/// contract 1). Every app in the fleet — the template app and every
/// generated shell — supplies ITS OWN values; nothing here is hardcoded to
/// the template app.
class CarnamaBootstrap {
  const CarnamaBootstrap({
    required this.firebaseOptions,
    required this.coreConfig,
    required this.appBuilder,
    this.loadEnv = false,
    this.firebaseErrorScreenBuilder,
  });

  /// The caller's per-platform [FirebaseOptions] — the generated defaults
  /// from the CALLER's own `firebase_options.dart` (each app's file stays
  /// per-project; it is never extracted into this bootstrap). The init
  /// chain merges the caller's client-config ids over these defaults with
  /// the same precedence the template app always used (config wins when
  /// non-empty, generated default otherwise).
  final FirebaseOptions firebaseOptions;

  /// The [CoreConfig] injected into [CoreConfigHolder] (Law 43: app-level
  /// values must reach the core package exactly once, after the config
  /// load). The template app passes `CoreAppConfig`; a shell passes its
  /// `ClientCoreConfig` (which fails fast on a missing `app.bundleId`).
  final CoreConfig coreConfig;

  /// Builds the app's root widget — `CoreApp` for the template app, the
  /// shell's `GeneratedApp` (a thin wrapper over `CoreApp`) for a shell.
  /// Wrapped in [ForceUpdateGuard] at the runApp step (STEP 16).
  final Widget Function() appBuilder;

  /// Whether the init runs the dotenv layer (STEP 06). The template app
  /// sets `true`: `.env` is loaded OPTIONALLY (Law 16 layer-2) — a missing
  /// asset is an explicit, printed absence, never a boot abort, and nothing
  /// is ever fabricated (FIX-B1 T-1). Generated shells keep the `false`
  /// default and never touch dotenv at all (FIX-B1 T-3).
  final bool loadEnv;

  /// The shell's fail-closed blocking screen (W6.1/W6.3 vocabulary: the
  /// Firebase configuration is missing — contact the operator).
  ///
  /// When non-null the boot runs the shell's FAIL-CLOSED policy:
  ///   * STEP 13 — a missing/placeholder resolved Firebase API key blocks
  ///     the boot on this screen (Firebase is never initialized);
  ///   * STEP 14 — a thrown `Firebase.initializeApp` (or any Firebase-chain
  ///     failure) blocks the boot on this screen instead of silently
  ///     continuing into an auth/Firestore/FCM-less UI.
  ///
  /// When null (the template app's semantics) there is no key gate and a
  /// Firebase-chain failure is logged (`FirebaseInitError`) and the boot
  /// continues — exactly the template app's pre-ARCH-2 behavior.
  final Widget Function()? firebaseErrorScreenBuilder;
}

/// Global navigator key used to access the app context outside of the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Documented placeholder fragments (mirrors the generator's validate()
/// gate, W6.1). No app may ever initialize Firebase with a placeholder
/// credential, so the same vocabulary is rejected at runtime.
final RegExp _placeholderKeyPattern = RegExp(
  'REPLACE_ME|changeme|<your',
  caseSensitive: false,
);

/// True when [options]' API key is present and is not a documented
/// placeholder (W6.1 fail-closed gate on the RESOLVED options — exactly the
/// credential [Firebase.initializeApp] would use).
@visibleForTesting
bool firebaseKeyConfigured(FirebaseOptions options) {
  final key = options.apiKey;
  return key.trim().isNotEmpty && !_placeholderKeyPattern.hasMatch(key);
}

/// True when [projectId] is present and is not a documented placeholder —
/// the SAME vocabulary as [firebaseKeyConfigured], applied to the config key
/// `firebase.projectId` (FIX-B1 T-2 / F-AUD2-05). A `REPLACE_ME_*` project
/// id must never reach `Firebase.initializeApp`: it is excluded from the
/// options merge, and the STEP 13 gate fails CLEARLY (naming the key) when
/// nothing real resolved.
@visibleForTesting
bool firebaseProjectIdConfigured(String projectId) =>
    projectId.trim().isNotEmpty && !_placeholderKeyPattern.hasMatch(projectId);

/// The per-platform defaults supplied by the caller ([CarnamaBootstrap
/// .firebaseOptions]), stashed at STEP 00 so both the foreground merge and
/// the background FCM handler (which can run in a separate isolate before
/// [initCarnamaApp] ever ran) resolve the CALLER's project — never some
/// other app's options. Null until the first init: the background handler
/// then fails closed (log + skip) instead of initializing the wrong project.
FirebaseOptions? _bootFirebaseOptions;

/// Builds the [FirebaseOptions] the app boots with: the caller's generated
/// defaults merged with the caller's client-config ids (STEP 13's input).
///
/// Precedence (unchanged from the pre-ARCH-2 template `main.dart`): config
/// values win when non-empty; otherwise the caller's generated default is
/// the safe fallback. The apiKey always comes from the caller's generated
/// options (the config never carries the key for the template app).
FirebaseOptions _buildFirebaseOptions() {
  final defaults = _bootFirebaseOptions;
  if (defaults == null) {
    throw StateError(
      '_buildFirebaseOptions called before initCarnamaApp stashed the '
      'caller options — the boot chain owns the merge order',
    );
  }
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final configAppId = isAndroid
      ? AppConfig.firebaseAndroidAppId
      : AppConfig.firebaseIosAppId;
  return FirebaseOptions(
    apiKey: defaults.apiKey,
    appId: configAppId.isNotEmpty ? configAppId : defaults.appId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId.isNotEmpty
        ? AppConfig.firebaseMessagingSenderId
        : defaults.messagingSenderId,
    // FIX-B1 T-2 / F-AUD2-05: a documented REPLACE_ME_* placeholder in the
    // client config is EXCLUDED from the merge (treated like empty) — the
    // caller's generated default is the safe fallback. The boot gate in
    // STEP 13 still fails closed if NOTHING real resolves.
    projectId: firebaseProjectIdConfigured(AppConfig.firebaseProjectId)
        ? AppConfig.firebaseProjectId
        : defaults.projectId,
    storageBucket: defaults.storageBucket,
  );
}

/// Top-level background FCM handler — MUST have @pragma for tree-shaking.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    final options = _bootFirebaseOptions;
    if (options == null) {
      // Fail-closed: the handler can fire in a background isolate before
      // the app's init ran. Without the caller's options there is no safe
      // project to initialize — log-and-skip (never a wrong-project init).
      developer.log(
        'BackgroundMessageSkipped: no boot Firebase options resolved yet',
      );
      return;
    }
    await Firebase.initializeApp(options: options);
  }
  developer.log('Background message: ${message.messageId}');
}

/// Rejects a release build that ships DEMO_MODE=true (Law 12/43).
///
/// Demo mode simulates Stripe payments — shipping it to production means
/// customers are "charged" with no real money movement. This is a
/// catastrophic silent failure, so we fail fast instead.
void _assertSafeBuildConfig() {
  assert(
    !kReleaseMode || !kDemoMode,
    'DEMO MODE IS FORBIDDEN IN RELEASE BUILDS. '
    'You must NOT ship demo/simulated payments to production.',
  );
  if (kReleaseMode && kDemoMode) {
    throw StateError('DEMO_MODE=true in release build is a production hazard');
  }
}

/// QUEUE-1 (W5.1(b)) — wires the offline queue's auto-triggers AFTER Isar is
/// open (STEP 15, called right after `IsarService.shared().openDB()`):
///
///   1. app-start flush — `unawaited(syncQueue.processQueue())`;
///   2. connectivity-restored flush — `ConnectivitySyncTrigger` (5 s debounce);
///   3. periodic safety net — Workmanager 15-min task (existingWorkPolicy keep)
///      routed through the app's single dispatcher (`kitchenTaskDispatcher`);
///   4. PUSH-1 (W5.3) — kitchen heartbeat: the SAME single dispatcher is
///      initialized via `KitchenOfflineService.initialize` and the 15-min
///      heartbeat (`kKitchenHeartbeatTask`) is registered exactly once
///      (guarded bool in `KitchenHeartbeatScheduler` + `keep` policy).
///
/// Every trigger is fail-closed: any failure is logged via [logger] and the
/// queue stays parked for the next trigger — never silently lost.
void _startSyncQueueTriggers(LoggerService logger) {
  final syncQueue = IsarSyncQueue(
    IsarService.shared(),
    logger,
    firestore: FirestoreQueueWriter(FirestoreClient.instance.db),
  );
  SyncQueueAutoTrigger(syncQueue: syncQueue).start();
  unawaited(_schedulePeriodicQueueSync(logger));
}

Future<void> _schedulePeriodicQueueSync(LoggerService logger) async {
  // PUSH-1 (W5.3): the kitchen heartbeat owns the Workmanager().initialize —
  // performed INSIDE KitchenOfflineService.initialize with the app's SINGLE
  // dispatcher (`kitchenTaskDispatcher`, which routes BOTH
  // `kKitchenHeartbeatTask` and `kQueueSyncTask`), then the heartbeat is
  // registered exactly once (guarded bool in `KitchenHeartbeatScheduler`;
  // `existingWorkPolicy: keep` keeps the OS registration idempotent across
  // app restarts). Fail-closed: any failure is logged and the heartbeat is
  // re-attempted on the next app start — never silent.
  try {
    await KitchenHeartbeatScheduler(
      service: KitchenOfflineService(
        logger: logger,
        orderPayloadParser: OrderPayloadAdapter.fromJson,
      ),
    ).schedule();
  } catch (e, stack) {
    await logger.error(e, 'KitchenHeartbeatInitError', stack: stack);
  }
  try {
    // QUEUE-1 (W5.1(b)(3)): periodic safety net for the offline queue. The
    // Workmanager is ALREADY initialized above with the same single
    // dispatcher — re-initializing would clobber the registered callback.
    await QueueSyncScheduler().schedule();
  } catch (e, stack) {
    await logger.error(e, 'QueuePeriodicSyncInitError', stack: stack);
  }
}

/// Graceful error widget — prevents the red error screen in release
/// (App Store requirement). Extracted as a top-level function so widget tests
/// install the EXACT production builder (ROUTER-1 T-4).
///
/// The Restart button navigates through go_router (`context.go('/')` on the
/// main app's navigator context — the `InheritedGoRouter` is an ancestor of
/// the navigator, so `GoRouter.of` resolves there). The deprecated Navigator
/// name-API restart fired on a go_router stack where the name `'/'` was never
/// registered (00-P0-3). Crashlytics is guarded: the
/// builder is installed BEFORE Firebase init (STEP 03 before STEP 14), so an
/// early crash must still render the graceful fallback instead of crashing
/// the error UI itself.
Widget buildGracefulErrorWidget(FlutterErrorDetails details) {
  try {
    FirebaseCrashlytics.instance.recordFlutterError(details);
  } catch (e) {
    developer.log('ErrorWidgetCrashlyticsUnavailable: $e');
  }
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).gracefulErrorBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final BuildContext? navContext =
                        navigatorKey.currentContext;
                    if (navContext == null) {
                      // Fail-closed: no main-app navigator exists to restart.
                      developer.log(
                        'ErrorWidgetRestartSkipped: no active navigator context',
                      );
                      return;
                    }
                    navContext.go('/');
                  },
                  child: Text(AppLocalizations.of(context).restart),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The dotenv layer of the boot chain (executed by STEP 06), extracted so
/// the FIX-B1 boot tests exercise the REAL production code path — not a
/// mirror.
///
/// * [enabled] mirrors `CarnamaBootstrap.loadEnv`: shells (the default
///   `false`) return BEFORE touching dotenv at all — zero blast radius for
///   shipping clients (FIX-B1 T-3).
/// * The template app (`true`) loads `.env` OPTIONALLY
///   (`isOptional: true`, flutter_dotenv 5.2.1): a missing bundled asset
///   degrades to an EXPLICIT, printed absence — never a throw (F-AUD2-01
///   was a hard boot abort through `handleBootFailure` before `runApp`).
/// * Documented precedence when `.env` is absent (Law 16 layers):
///   `.env` -> `--dart-define` -> `assets/client_config.json`. Absence
///   fabricates NOTHING: the layer stays empty and every consumer falls
///   through to its next layer or stays empty/fail-closed.
///
/// Returns true when a `.env` asset was actually loaded, false when the
/// layer is disabled or the asset is absent.
@visibleForTesting
Future<bool> loadEnvLayer({required bool enabled}) async {
  if (!enabled) {
    // Shells never touch dotenv — not even a read.
    return false;
  }
  // p34 T-2 (red: green_r2_realtime_greenv7.txt): load() is a full
  // clean()+reload. On boot 2 in one isolate (integration_test boots per
  // test) the asset FlutterError escapes into initCarnamaApp's zone guard
  // and boot dies before bootDone — app.main() hangs. No reload needed.
  if (dotenv.isInitialized) {
    return dotenv.env.isNotEmpty;
  }
  // 5.2.1 converts only FileNotFoundError; the asset path can throw an
  // Error instead (empty/missing .env) — catch Object, empty layer, no
  // values fabricated (fail-closed contract unchanged).
  try {
    await dotenv.load(isOptional: true);
  } catch (e) {
    dotenv.testLoad(fileInput: '');
    debugPrint(
      'EnvFileMissing: .env not bundled as an asset - boot continues. '
      'Precedence: .env -> --dart-define -> config. No values fabricated. ($e)',
    );
    return false;
  }
  if (dotenv.env.isEmpty) {
    debugPrint(
      'EnvFileMissing: .env not bundled as an asset - boot continues. '
      'Precedence: .env -> --dart-define -> config (assets/client_config.json). '
      'No values were fabricated (the dotenv layer stays empty and every '
      'consumer falls through fail-closed).',
    );
    return false;
  }
  return true;
}

/// T-FLAKE-1 (determinism law §0.7): under `flutter test` every test FILE is
/// its own process, and the old machine-global `%TEMP%/app_logs.txt` was
/// snapshot+deleted+overwritten CONCURRENTLY by every harness process
/// (`test/helpers/boot_env_harness.dart`) — one process could delete another's
/// boot lines between the write and `freshBootLog()`, so `bootLog` read back
/// `''` (~1 in 5 full-suite runs; DEFERRED T-FLAKE-1). A per-PID subdirectory
/// makes cross-process clobbering structurally impossible. This function is
/// the single source of truth: the `FLUTTER_TEST` logger branch below, the
/// boot-failure crash fallback and the test harness all resolve it.
/// Production (no `FLUTTER_TEST`) never calls it.
Directory bootLogDirectoryForTest() =>
    Directory('${Directory.systemTemp.path}/carnama_boot_logs_$pid');

/// The ONE shared init sequence (ARCH-2): the entire pre-ARCH-2 template
/// `main()` chain — parameterized, not duplicated. Every step below carries
/// its STEP number from the library doc comment; the T-3 init-order test
/// pins the source order of these call sites to that list.
///
/// Preserved invariants (spec §2.2 acceptance contract 5/6): logger BEFORE
/// Firebase, schema check BEFORE runApp, error widget builder BEFORE Firebase
/// init, heartbeat + queue triggers AFTER Isar, push AFTER FCM, consent AFTER
/// Firebase — and every config-reading step reads the CALLER's parameterized
/// config ([AppConfig] hydrated from the caller's own bundled asset).
Future<void> initCarnamaApp({required CarnamaBootstrap bootstrap}) async {
  // STEP 00: stash the caller's per-platform options before anything
  // (including a background FCM isolate) may resolve Firebase identity.
  _bootFirebaseOptions = bootstrap.firebaseOptions;

  // STEP 01 — fail fast if a release build ships demo mode (Law 12/43).
  _assertSafeBuildConfig();

  // STEP 02 — register background FCM handler before anything else. The
  // registration future is fire-and-forget: on a platform without the FCM
  // plugin wired up (unit/widget test hosts), the internal
  // `Messaging#startBackgroundIsolate` method-channel call throws an
  // UNHANDLED async MissingPluginException. Left bare, that error falls into
  // the guarded-zone handler below, whose own LoggerService fallback fails
  // the same way and re-enters the handler — an infinite unhandled-error
  // loop that never lets the boot future complete. Contain the registration
  // in its own guarded zone (production registers normally; test hosts log
  // and move on).
  runZonedGuarded(
    () => FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    ),
    (error, stack) {
      debugPrint('FCM background handler registration skipped: $error');
    },
  );

  // STEP 03 — graceful error widget: prevents the red error screen in
  // release (App Store requirement). Installed BEFORE Firebase init.
  // p34 T-2: skipped under the e2e lane (INTEGRATION_TEST define) — the
  // test binding fails any test whose boot leaves ErrorWidget.builder
  // modified (binding.dart:1799 _verifyErrorWidgetBuilderUnset; first
  // real run: green_r2_admin_navfix4.txt).
  if (!const bool.fromEnvironment('INTEGRATION_TEST')) {
    ErrorWidget.builder = buildGracefulErrorWidget;
  }

  // STEP 04 — single PlatformDispatcher.onError handler, set ONCE.
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('PlatformDispatcherError: $error\n$stack');
    // Fire-and-forget with the failure contained: the sync try/catch below
    // cannot catch an ASYNC logger failure (it escapes the returned
    // Future), and an unhandled one would re-enter the guarded-zone
    // handler.
    unawaited(
      LoggerService()
          .error(error, 'PlatformDispatcherError', stack: stack)
          .catchError((Object e, StackTrace s) {
            developer.log('PlatformDispatcherLoggerError: $e');
          }),
    );
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    } catch (e) {
      developer.log('PlatformDispatcherError: $e');
      return true;
    }
    return false;
  };

  // STEP 05-16 run inside a guarded zone. CRITICAL: `runZonedGuarded`'s
  // returned future NEVER completes when the zone body dies with an
  // uncaught error (the error goes to the handler instead) — so awaiting
  // it directly would hang `initCarnamaApp` forever on ANY body failure
  // (e.g. `runApp`'s inTest assertion in a plain test host). The boot
  // future is therefore completed explicitly in a finally, and body errors
  // are routed through the same failure handler the zone uses.
  void handleBootFailure(Object error, StackTrace stack) {
    // Fallback logger for early crashes
    developer.log('UncaughtZoneError: $error\n$stack');
    try {
      // Boot-crash fallback: append `<app>_fatal_crash.log` to the PROCESS
      // temp directory (p26 T-2: comment corrected — this is not the
      // documents-dir path; in tests the boot harness snapshots/restores
      // this file, boot_env_harness.dart). T-FLAKE-1: under `flutter test`
      // the file lands in the same PER-PID directory as the boot log so
      // parallel harness processes can never delete each other's crash
      // bytes; production keeps the machine temp root.
      final Directory dir =
          (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))
          ? bootLogDirectoryForTest()
          : Directory.systemTemp;
      dir.createSync(recursive: true); // per-PID dir may not exist yet
      File(
        '${dir.path}/${AppConfig.appName.toLowerCase()}_fatal_crash.log',
      ).writeAsStringSync(
        'UncaughtZoneError: $error\n$stack\n',
        mode: FileMode.append,
      );
    } catch (e) {
      developer.log('FatalCrashLogError: $e');
    }

    // The logger's own file init can itself throw on a host without the
    // path_provider plugin (test environments). An unhandled async failure
    // here re-enters THIS handler and loops forever, so the error call is
    // fire-and-forget with its failure contained.
    unawaited(
      LoggerService()
          .error(error, 'UncaughtZoneError', stack: stack)
          .catchError((Object e, StackTrace s) {
            developer.log('FatalCrashLogError: $e');
          }),
    );
  }

  final bootDone = Completer<void>();
  unawaited(
    runZonedGuarded(() async {
      try {
        // STEP 05 — binding first inside the guarded zone.
        WidgetsFlutterBinding.ensureInitialized();

        // STEP 06 — load environment variables from .env (Law 16). Template
        // app only, and OPTIONAL: shells skip dotenv entirely (loadEnvLayer
        // returns before touching it), and the template app degrades
        // explicitly when no `.env` is bundled — see loadEnvLayer for the
        // documented precedence `.env -> --dart-define -> config` and the
        // no-fabrication rule (FIX-B1 T-1 / F-AUD2-01).
        await loadEnvLayer(enabled: bootstrap.loadEnv);

        // STEP 07 — load the caller's client config from ITS bundled asset
        // (Phase 2.2 Batch 1). Reads assets/client_config.json via rootBundle;
        // falls back to in-code defaults + dotenv when missing/malformed.
        await AppConfig.loadConfig();

        // STEP 08 — RELEASE-1 / W11.3: hydrate the typography guard's font
        // registry from the built FontManifest.json. AWAITED (not
        // fire-and-forget) so the manifest is registered before the
        // ThemeData is built and the first build can never race the family
        // lookup. loadBundledFontFamilies NEVER throws (missing/malformed
        // manifest degrades to the guard's fail-closed fallback).
        await AppTheme.loadBundledFontFamilies();

        // STEP 09 — inject app-level values into the core package (Law 43).
        // This must happen AFTER config load so clientId (bundleId), demo
        // mode, and the kitchen endpoint are resolved before any core
        // service reads them.
        CoreConfigHolder.set(bootstrap.coreConfig);

        // STEP 10 — initialize Logger *before* Firebase to capture early
        // crashes.
        //
        // Test hosts (flutter_tester sets FLUTTER_TEST) have no
        // path_provider plugin: under the test binding's fake async the
        // documents-directory method channel NEVER answers, so the awaited
        // init would hang the whole boot. Route test logs to a PER-PROCESS
        // temp directory (`bootLogDirectoryForTest()` — T-FLAKE-1: parallel
        // test processes must never share one log file); production is
        // untouched (FLUTTER_TEST is never set outside `flutter test`).
        final logger = LoggerService(
          testDirectory:
              (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))
              ? bootLogDirectoryForTest()
              : null,
        );
        try {
          await logger.init();
        } catch (e) {
          developer.log('LoggerInitError: $e');
        }

        // STEP 11 — W6.4(2)/W6.5: a failed client-config load is NEVER
        // silent. The load error is recorded via the logger (release: log
        // only); a REQUIRED-field schema violation additionally fails the
        // boot CLOSED below.
        if (AppConfig.loadFailed) {
          try {
            await logger.error(
              AppConfig.loadError ?? 'unknown client config load failure',
              'ClientConfigLoadFailed',
            );
          } catch (e) {
            developer.log('ConfigLoadLoggerError: $e');
          }
        }

        // STEP 12 — W6.5 fail-closed schema gate: a config that PARSES but
        // violates the REQUIRED-field schema blocks the boot on the
        // ConfigValidationErrorScreen — never silently boots on defaults.
        final schemaError = AppConfig.schemaError;
        if (schemaError != null) {
          developer.log(
            'FATAL: client_config.json failed schema validation: $schemaError',
          );
          runApp(ConfigValidationErrorScreen(error: schemaError));
          return;
        }

        // The merged boot options (caller defaults + caller config ids).
        final options = _buildFirebaseOptions();

        // STEP 13 — W6.1 fail-closed key gate (shell policy): without a REAL
        // Firebase API key the boot renders the caller's blocking screen and
        // NEVER initializes Firebase (no auth, Firestore, FCM). The template
        // app (no blocking screen) keeps its logged-continue semantics.
        if (bootstrap.firebaseErrorScreenBuilder != null &&
            !firebaseKeyConfigured(options)) {
          debugPrint(
            'FATAL: Firebase API key missing or placeholder '
            '(the resolved ${defaultTargetPlatform.name} options carry no real '
            'key). Boot blocked - contact the operator.',
          );
          runApp(bootstrap.firebaseErrorScreenBuilder!());
          return;
        }

        // STEP 13 (continued) — FIX-B1 T-2 / F-AUD2-05 fail-closed projectId
        // gate: the placeholder is excluded from the merge (see
        // _buildFirebaseOptions), but a resolved id can still be a
        // placeholder/empty (caller defaults carry one too, or nothing real
        // resolved at all). That must fail CLEARLY here — the message names
        // the key `firebase.projectId` — and must NEVER become a silent
        // Firebase init against a bogus project.
        bool skipFirebaseChain = false;
        if (!firebaseProjectIdConfigured(options.projectId)) {
          debugPrint(
            'FATAL: firebase.projectId is missing or a documented '
            'placeholder (resolved: "${options.projectId}"). Set a real '
            'project id in assets/client_config.json '
            '(key: firebase.projectId) or the .env FIREBASE_PROJECT_ID '
            'before shipping. Firebase init is withheld - the boot never '
            'targets a REPLACE_ME project (FIX-B1 T-2 / F-AUD2-05).',
          );
          if (bootstrap.firebaseErrorScreenBuilder != null) {
            // Shell policy: block the boot on the operator-facing screen
            // (the same W6.1 contract as the key gate above).
            runApp(bootstrap.firebaseErrorScreenBuilder!());
            return;
          }
          // Template policy (logged-continue): keep booting, but withhold
          // the Firebase init — STEP 14 then fails fast downstream (no app
          // registered) into its own catch: the template logs and continues
          // to STEP 16, shells already blocked at the gate above.
          skipFirebaseChain = true;
        }

        // STEP 14 — the Firebase chain (fail-closed for shells, logged-
        // continue for the template app — both pre-ARCH-2 semantics).
        try {
          if (skipFirebaseChain) {
            // FIX-B1 T-2: init WITHHELD — the STEP 13 gate already printed
            // the FATAL naming `firebase.projectId`, and with no app
            // registered every downstream call in this chain fails fast
            // into the catch below (never a silent placeholder init).
          } else if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(options: options);
          }

          // Platform-aware emulator host (Law 30). The Android EMULATOR
          // reaches the host machine via 10.0.2.2, everything else uses
          // localhost. For a PHYSICAL phone on the same Wi-Fi, pass
          // --dart-define=EMULATOR_HOST=<PC-LAN-IP> (the emulator suite binds
          // 0.0.0.0 per core_app/firebase.json). No-op by default —
          // production builds never pass the defines.
          if (const bool.fromEnvironment('USE_EMULATORS')) {
            const override = String.fromEnvironment('EMULATOR_HOST');
            final emulatorHost = override.isNotEmpty
                ? override
                : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
            FirestoreClient.instance.db.useFirestoreEmulator(
              emulatorHost,
              8080,
            );
            await usePlatformAuthEmulator(emulatorHost, 9099);
          }

          // App Check: native providers for mobile, ReCaptcha for web.
          // The 0.4.x activate() takes *AppCheckProvider classes in
          // providerAndroid/providerApple — the legacy AndroidProvider /
          // AppleProvider enums belong to the deprecated androidProvider /
          // appleProvider params and must NEVER be cast across (the cast
          // compiles but throws _TypeError, and the fail-closed policy turns
          // it into the blocking boot screen).
          await FirebaseAppCheck.instance.activate(
            providerAndroid: kDebugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode
                ? const AppleDebugProvider()
                : const AppleAppAttestProvider(),
            providerWeb: kIsWeb
                ? (kDebugMode
                      ? ReCaptchaV3Provider(
                          '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI',
                        )
                      : ReCaptchaV3Provider(
                          const String.fromEnvironment('RECAPTCHA_WEB_KEY'),
                        ))
                : null,
          );

          // GDPR consent guard for FirebaseAnalytics (Law 36) — AFTER
          // Firebase.
          final hasConsent = await GdprConsentDialog.hasConsent();
          await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
            hasConsent,
          );
          GdprConsentDialog.onConsentChangedStream.listen((consentGranted) {
            FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
              consentGranted,
            );
          });

          // Fire-and-forget FCM init with Crashlytics error logging
          unawaited(
            FcmService()
                .init()
                .then((_) {
                  developer.log('FCM initialized successfully');
                })
                .catchError((e, stack) {
                  developer.log('FcmInitError: $e');
                  FirebaseCrashlytics.instance.recordError(
                    e,
                    stack as StackTrace?,
                    fatal: false,
                    information: ['context=FcmService.init'],
                  );
                }),
          );

          // PUSH-2 P-1: the push service was DEAD CODE before PUSH-2 —
          // initialize it here, after Firebase is ready. FcmService above has
          // only OBSERVED consent (P-4: never prompts from boot); tap routing
          // starts now. Push AFTER FCM.
          unawaited(
            PushNotificationService.initialize()
                .then((_) {
                  developer.log('PushNotificationService initialized');
                })
                .catchError((e, stack) {
                  developer.log('PushInitError: $e');
                  FirebaseCrashlytics.instance.recordError(
                    e,
                    stack as StackTrace?,
                    fatal: false,
                    information: ['context=PushNotificationService.initialize'],
                  );
                }),
          );

          // Initialize Stripe (P0-19). The guard below is a DEBUG-ONLY assert
          // (stripped from release builds): it fails fast in debug/test when
          // STRIPE_PUBLISHABLE_KEY is missing, while a release boot with an
          // empty key proceeds and payments fail CLOSED later at
          // payment-sheet init — never a silent charge against a bogus key.
          // Deliberately NOT promoted to a release-visible check (F-AUD2-06
          // doc truth: the old comment claimed a production fail-fast the
          // assert cannot deliver).
          Stripe.publishableKey = const String.fromEnvironment(
            'STRIPE_PUBLISHABLE_KEY',
            defaultValue: '',
          );
          assert(
            Stripe.publishableKey.isNotEmpty,
            'STRIPE_PUBLISHABLE_KEY is empty (debug-only guard; release '
            'builds proceed and payments fail closed at payment-sheet '
            'init)',
          );
          if (Stripe.publishableKey.isNotEmpty) {
            await Stripe.instance.applySettings();
          }
        } catch (e, stack) {
          developer.log('FirebaseInitError: $e');
          await logger.error(e, 'FirebaseInitError', stack: stack);
          if (bootstrap.firebaseErrorScreenBuilder != null) {
            // Shell fail-closed policy: an app that cannot initialize
            // Firebase must not silently continue into an auth/Firestore/
            // FCM-less UI.
            runApp(bootstrap.firebaseErrorScreenBuilder!());
            return;
          }
        }

        // STEP 15 — Isar open (fail-closed: logged, never silent), then the
        // offline-queue auto-triggers + kitchen heartbeat AFTER Isar.
        try {
          await IsarService.shared().openDB();
        } catch (e, stack) {
          developer.log('IsarInitError: $e');
          await logger.error(e, 'IsarInitError', stack: stack);
        }

        // QUEUE-1 (W5.1(b)): offline-queue auto-triggers — app-start flush,
        // connectivity-restored flush, and the 15-min Workmanager safety net.
        // Runs unconditionally after the openDB attempt: if Isar failed the
        // queue's own error handling keeps a parked, never-lost state.
        _startSyncQueueTriggers(logger);

        // STEP 16 — PUSH-2 P-2: push taps navigate through the SAME go_router
        // stack as deep links (Law 34). The bridge is a top-level function
        // (like [navigatorKey]) so widget tests exercise the REAL production
        // bridge. Then runApp.
        PushNotificationService.navigationHandler = pushNavigationBridge;

        runApp(
          ProviderScope(
            overrides: [
              loggerProvider.overrideWithValue(logger),
              authRepositoryProvider.overrideWith(
                (ref) => createPlatformAuthRepository(
                  firestore: FirestoreClient.instance.db,
                  logger: ref.watch(loggerProvider),
                  // P2-1a (D-050): the mobile app's sign-out wipe stays Isar-backed.
                  cache: const IsarLocalCache(),
                  onSignOutNavigated: () {
                    // W2.2: go_router path/name navigation — the Navigator
                    // name API never registered '/login' on a go_router stack.
                    final router = activeRouter;
                    if (router == null) {
                      developer.log(
                        'SignOutNavigationSkipped: no active router for '
                        '${RouteNames.login}',
                      );
                      return;
                    }
                    // Defer one frame: this callback fires INSIDE the
                    // auth-state notification cycle (auth_repository.signOut),
                    // and go_router asserts 'uri.path.startsWith(
                    // newMatchedLocation)' (match.dart:235) when .go()
                    // re-enters route parsing from inside a notification
                    // dispatch — logging out from Profile crashed the
                    // router (red: green_r2_full_battery_v4.txt golden_a_z).
                    // The post-frame callback runs after the cycle completes.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      router.go(RouteNames.login);
                    });
                  },
                ),
              ),
              deepLinkServiceProvider.overrideWithValue(
                DeepLinkService(
                  navigationHandler: (path) async {
                    // W2.2: go_router PATH navigation (the Navigator name API
                    // was fed a path on a go_router stack — 00-P0-2). The
                    // DeepLinkService validates against the pruned
                    // DeepLinkRouteTable and catches handler errors, so an
                    // unknown path is logged-and-ignored upstream, never
                    // thrown.
                    final router = activeRouter;
                    if (router == null) {
                      // Log-and-ignore: a link arriving before the router
                      // exists must never throw.
                      developer.log(
                        'DeepLinkNavigationSkipped: no active router for $path',
                      );
                      return;
                    }
                    await router.push(path);
                  },
                ),
              ),
            ],
            // STATE-3 (04-P1-BOOT): the guard now sits INSIDE the
            // ProviderScope so its mount-time watch consumes the shared
            // `forceUpdateStatusProvider` future (started by
            // splashInitProvider as a parallel check) and renders the first
            // frame immediately — the version check never blocks boot.
            child: ForceUpdateGuard(child: bootstrap.appBuilder()),
          ),
        );
      } catch (error, stack) {
        handleBootFailure(error, stack);
      } finally {
        if (!bootDone.isCompleted) {
          bootDone.complete();
        }
      }
    }, handleBootFailure),
  );
  await bootDone.future;
}

/// PUSH-2 P-2/P-3: the tap→router bridge installed as
/// [PushNotificationService.navigationHandler] in STEP 16.
///
/// Mirrors the deep-link handler exactly: go_router PATH navigation is the
/// only navigation API (00-P0-2), the live router is resolved through
/// [activeRouter], and a tap arriving before the router exists is
/// logged-and-ignored — never thrown. Exported (like [navigatorKey]) so
/// widget tests exercise the REAL production bridge, not a mirror.
Future<void> pushNavigationBridge(String path) async {
  final router = activeRouter;
  if (router == null) {
    developer.log('PushNavigationSkipped: no active router for $path');
    return;
  }
  await router.push(path);
}

/// The REAL app widget: config theme + go_router + l10n + the overlay chain
/// (bug reporter, presence observer, debug config banner). The template app
/// and every shell (through its thin `GeneratedApp` wrapper) render THIS
/// widget — the screens, the 27-screen config-driven router, and the full
/// en+ar l10n are the labs package's single source.
class CoreApp extends ConsumerStatefulWidget {
  const CoreApp({super.key});

  @override
  ConsumerState<CoreApp> createState() => _CoreAppState();
}

class _CoreAppState extends ConsumerState<CoreApp> {
  @override
  void initState() {
    super.initState();
    // Initialize deep linking (app_links) stream interceptor
    Future.microtask(() => ref.read(deepLinkServiceProvider).init());
    // PUSH-2 P-3: consume a cold-start (terminated-state) notification tap
    // now that the router is mounted. Gated on [ready] — a cold-start payload
    // can only exist if initialize() ran far enough to stash it, so no timer
    // is needed here (a pending Future never blocks startup and never trips
    // the framework's no-pending-timers teardown invariant).
    unawaited(
      PushNotificationService.ready.then(
        (_) => PushNotificationService.consumePendingColdStartTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(themeModeProvider); // Law 6: Dynamic observance
    // UI-15 (p24) T-1: the stored end-user language choice — `null` means
    // "follow the device", i.e. exactly the pre-p24 behaviour (L-P2). The
    // value hydrates off the boot path and applies at most one frame after the
    // first paint (L-P5).
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      restorationScopeId: 'app',
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppConfig.theme,
      darkTheme: AppConfig.darkTheme,
      themeMode: theme, // FIX: Law 6 (No longer hardcoded ThemeMode.light)
      locale: locale, // UI-15 (p24) T-1: F3-01 — null = follow the device
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        Widget content = BugReporterOverlay(
          navigatorKey: navigatorKey,
          child: PresenceLifecycleObserver(child: child!),
        );
        // W6.4(2): in debug builds a failed config load is surfaced with a
        // visible banner on top of the running app; release builds record
        // the failure via the logger only (see the boot path above).
        if (kDebugMode && AppConfig.loadFailed) {
          content = Stack(
            children: [
              content,
              const Align(
                alignment: Alignment.topRight,
                child: ConfigLoadFailureBanner(),
              ),
            ],
          );
        }
        return content;
      },
    );
  }
}
