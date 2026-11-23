import 'dart:async';

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_firebase_analytics_platform.dart';
import 'helpers/network_blocker.dart';

/// Global widget-test bootstrap (ROUTER-3 / W2.8). Runs once per test file,
/// BEFORE any test in it.
///
/// The transport is isolated for EVERY test in this package:
/// [blockAllNetwork] installs the documented blocker
/// (test/helpers/network_blocker.dart): every outbound `dart:io`
/// `HttpClient` request — including `NetworkImage`/`Image.network`, which
/// obtain their client through `HttpClient()` — throws
/// `NetworkBlockedException`. Widget tests can never silently hit the real
/// network or be order-dependent on real HTTP responses.
///
/// SPEC AMENDMENT (recorded in the ROUTER-3 addendum): the master wave W2.8
/// claims this file "already runs `setupFirebaseAuthMocks()` for every test".
/// That is drift — the file was an empty pipeline (verified by ROUTER-2), and
/// wiring `setupFirebaseAuthMocks()` GLOBALLY is NOT safe: it flips
/// `Firebase.apps` to non-empty for every test, which breaks the
/// Crashlytics-guard contract exercised by `test/app/error_widget_restart_test.dart`
/// (the guard skips `recordFlutterError` only when no Firebase app exists;
/// with a mock app present the async Crashlytics record throws an unhandled
/// MissingPluginException → "Multiple exceptions (2)"). The auth-mock bootstrap
/// therefore stays per-file (`mock_firebase.dart`, already used by the suites
/// that need it); the global pipeline here is the typed network blocker.
///
/// A test that intentionally needs non-image HTTP (e.g. a local `HttpServer`
/// mock) must use the documented escape hatches
/// `blockNetworkImages`/`restoreNetwork` from the helper file — never a
/// blanket bypass.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  blockAllNetwork();
  // UX-4 (07-P1-7): the production router now carries the
  // FirebaseAnalyticsObserver. Under the test binary messenger the analytics
  // method channel has no implementation, so its screen_view logEvent would
  // surface as an unhandled MissingPluginException (not a PlatformException —
  // the observer's catchError filter lets it escape). Install the recording
  // fake ONCE per test file: analytics calls become deterministic no-ops
  // that tests can assert against (test/helpers/
  // fake_firebase_analytics_platform.dart). Firebase-less tests are
  // unaffected — AnalyticsService.routeObservers() returns [] when
  // Firebase.apps is empty.
  FirebaseAnalyticsPlatform.instance = FakeFirebaseAnalyticsPlatform();
  // Belt-and-braces: if any code ever swaps the platform instance back to the
  // method-channel delegate, the channel itself still answers every call, so
  // a MissingPluginException can never escape from the analytics path.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_analytics'),
        (call) async => null,
      );
  // PERF-3 T-5 disposition (recorded): tests may print "AppTheme: fontFamily
  // \"Inter\" is not a registered bundled font (the FontManifest.json has not
  // been loaded yet)". This is EXPECTED and benign under the test binding —
  // there is no FontManifest asset here, so AppTheme degrades through its
  // documented graceful-fallback path (app_theme.dart catch →
  // `_fontManifestFailed` flag → built-in typefaces). Real builds register the
  // bundled fonts from pubspec; no action is required for this notice.
  await testMain();
}
