import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'crash_reporter.dart';
import 'pii_scrubber.dart';

/// Pre-Release Crash & Error Monitoring Strict Compliance (Law 11)
///
/// Records flutter errors and captures non-fatal errors explicitly.
/// Attaches custom keys for UserID, Current Screen, and Custom Action.
class ErrorLoggerService {
  final CrashReporter? _crashlytics;

  ErrorLoggerService([CrashReporter? crashlytics]) : _crashlytics = crashlytics;

  /// Convenience constructor wiring the production Firebase Crashlytics.
  factory ErrorLoggerService.firebase() =>
      ErrorLoggerService(FirebaseCrashReporter(FirebaseCrashlytics.instance));

  Future<void> recordNonFatalError(
    Object error,
    StackTrace? stack, {
    String? currentScreen,
    String? actionTaken,
  }) async {
    // Console log for local dev
    if (kDebugMode || kProfileMode) {
      debugPrint('🚨 [Non-Fatal Error] $error');
    }

    final crashlytics = _crashlytics;
    if (crashlytics == null) return;

    // Explicitly add context tags as demanded by the Constitution checklist
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unauthenticated';
      await crashlytics.setCustomKey('user_id', uid);

      if (currentScreen != null) {
        await crashlytics.setCustomKey('screen', currentScreen);
      }

      if (actionTaken != null) {
        await crashlytics.setCustomKey('action', actionTaken);
      }

      // W9.11 (06-P2-8): the audit flagged RAW error objects reaching
      // Crashlytics unscrubbed (emails/phones inside exception messages).
      // Redact through the shared canonical scrubber — the original runtime
      // type stays visible in the rendered string for triage grouping.
      await crashlytics.recordError(
        RedactedError(error),
        stack,
        reason: 'Handled exception in repository/service layer',
      );
    } catch (e) {
      if (kDebugMode || kProfileMode) {
        debugPrint('🚨 Failed to log to Crashlytics: $e');
      }
    }
  }

  void setupFlutterErrorLogging() {
    FlutterError.onError = (details) {
      // P4-07 (LAW 11): Preserve the default UI presentation (red screen in
      // debug, grey in release). Without this, release-mode error presentation
      // is SUPPRESSED — the user sees a frozen/blank screen with no error UI.
      FlutterError.presentError(details);

      if (kDebugMode || kProfileMode) {
        debugPrint('🚨 [FlutterError] ${details.exception}');
      }

      final crashlytics = _crashlytics;
      if (crashlytics != null) {
        // W9.11 (06-P2-8): redact the exception payload before it leaves the
        // device. The default presentation above already showed the RAW error
        // to the developer — the redaction applies to the Crashlytics copy.
        crashlytics.recordFlutterError(
          FlutterErrorDetails(
            exception: RedactedError(details.exception),
            stack: details.stack,
            library: details.library,
            context: details.context,
            informationCollector: details.informationCollector,
          ),
        );
      }
    };
  }
}
