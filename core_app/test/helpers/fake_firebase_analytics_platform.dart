import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';

/// Test double for the firebase_analytics platform channel (UX-4 / T-3).
///
/// WHY: UX-4 registers `FirebaseAnalyticsObserver` on the production router.
/// Under the test binary messenger `MethodChannelFirebaseAnalytics` has no
/// implementation, and a screen_view `logEvent` completes with a
/// [MissingPluginException] — which is NOT a [PlatformException], so the
/// observer's `catchError(test:)` filter lets it escape as an unhandled
/// async error. Installing this fake in `flutter_test_config.dart` makes the
/// analytics channel deterministic for EVERY test: calls are recorded,
/// nothing throws, no plugin registration is required.
class FakeFirebaseAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  /// Event names recorded since the last [reset] — assertions can prove the
  /// observer actually fired (T-3 beyond a code read).
  static final List<String> recordedEvents = <String>[];

  /// Clears the recording between tests/files.
  static void reset() => recordedEvents.clear();

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) => this;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    recordedEvents.add(name);
  }
}
