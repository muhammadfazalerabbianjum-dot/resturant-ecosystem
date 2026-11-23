import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Typed abstraction over crash-reporting backends (Law 46 — no dynamic calls).
///
/// WHY: `ErrorLoggerService` previously held a `dynamic _crashlytics` field,
/// which hid type errors at runtime and required `ignore_for_file:
/// avoid_dynamic_calls`. This interface lets tests inject a mock while
/// production passes a [FirebaseCrashReporter] wrapping `FirebaseCrashlytics`.
abstract interface class CrashReporter {
  Future<void> setCustomKey(String key, Object value);

  Future<void> recordError(Object error, StackTrace? stack, {Object? reason});

  Future<void> recordFlutterError(FlutterErrorDetails details);
}

/// Adapts [FirebaseCrashlytics] to [CrashReporter].
class FirebaseCrashReporter implements CrashReporter {
  final FirebaseCrashlytics _crashlytics;

  FirebaseCrashReporter(this._crashlytics);

  @override
  Future<void> setCustomKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {Object? reason}) =>
      _crashlytics.recordError(error, stack, reason: reason);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      _crashlytics.recordFlutterError(details);
}
