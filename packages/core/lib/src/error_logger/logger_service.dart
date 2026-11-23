import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'log_directory.dart';
import 'log_sink.dart';
import 'pii_scrubber.dart';

/// WHY: Law 11 (Silent Telemetry) + Law 46/47 (Exception Surface Mapping).
/// Every error that hits this service is:
///   1. Scrubbed of PII (GDPR compliance)
///   2. Tagged with contextual Crashlytics custom keys for triage
///   3. Written to a local log file for offline review
class LoggerService {
  /// W9.11 (06-P2-8): `app_logs.txt` is capped — when the size cap is exceeded
  /// the current file is rotated to `app_logs.1.txt` (single generation:
  /// bounded disk usage, last-but-one generation retained for post-mortem)
  /// and a fresh file starts. [maxLogFileSize] is injectable so tests can
  /// exercise rotation deterministically with a tiny cap.
  static const int kMaxLogFileSize = 1024 * 1024;

  /// P2-1a: typed as [LogDirectory] — on the VM that IS `dart:io`'s
  /// `Directory` (a typedef), so all existing call sites are unchanged, while
  /// the web build no longer needs `dart:io` to name this parameter.
  final LogDirectory? testDirectory;
  final int maxLogFileSize;
  LogSink? _sink;

  // Active context — set by screens before async operations
  String? _currentScreen;
  String? _currentUserId;
  String? _lastAction;

  LoggerService({this.testDirectory, this.maxLogFileSize = kMaxLogFileSize});

  /// Call from each screen's initState or on route change.
  void setContext({String? screen, String? userId, String? action}) {
    _currentScreen = screen;
    _currentUserId = userId;
    _lastAction = action;
  }

  Future<void> init() async {
    // The DESTINATION is platform-chosen (file on the VM, memory on the web);
    // the logger only formats lines. This is the edge that used to make the
    // whole error path unbuildable on the web (P2-1a).
    final sink = await openLogSink(testDirectory, maxLogFileSize);
    await sink.open();
    _sink = sink;
  }

  Future<void> info(Map<String, dynamic> context, String message) async {
    await _writeLog('INFO', message, context);
  }

  Future<void> warn(Object error, String message, {StackTrace? stack}) async {
    final ctx = {'warning': error.toString()};
    if (stack != null) {
      ctx['stack'] = stack.toString();
    }
    await _writeLog('WARN', message, ctx);
  }

  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    final ctx = {'error': error.toString()};
    if (stack != null) {
      ctx['stack'] = stack.toString();
    }
    await _writeLog('ERROR', message, ctx);

    // WHY: Law 11 — every caught error reaches Crashlytics immediately.
    // Custom keys give on-call engineers instant triage context without
    // needing to reproduce the crash scenario.
    if (!kIsWeb) {
      try {
        final crashlytics = FirebaseCrashlytics.instance;
        if (_currentScreen != null) {
          await crashlytics.setCustomKey('screen', _currentScreen!);
        }
        if (_currentUserId != null) {
          await crashlytics.setCustomKey('userId', _currentUserId!);
        }
        if (_lastAction != null) {
          await crashlytics.setCustomKey('lastAction', _lastAction!);
        }
        // W9.11 (06-P2-8): the error OBJECT itself may embed PII (exception
        // messages carry emails/phones) — redact it through the shared
        // scrubber instead of passing the raw object to Crashlytics.
        await crashlytics.recordError(
          RedactedError(error),
          stack,
          reason: scrubPii(message),
          fatal: false,
        );
      } catch (_) {
        // WHY: Never let Crashlytics itself crash the main error handler.
        // If Crashlytics is unavailable (test env / no network), swallow silently.
      }
    }
  }

  Future<void> _writeLog(
    String level,
    String message,
    Map<String, dynamic> context,
  ) async {
    if (_sink == null) await init();
    // W9.11 (06-P2-8): rotate BEFORE appending once the cap is exceeded —
    // app_logs.txt never grows unbounded; the superseded generation survives
    // as app_logs.1.txt (single generation, bounded disk).
    // WHY (p26 T-2 per-test sink seam): the probe must tolerate a MISSING
    // file. A per-test directory starts empty (the old machine-global
    // %TEMP%\app_logs.txt only "worked" because it survived between runs),
    // and concurrent fire-and-forget writes can probe while init()'s
    // create() is still in flight — length() on a missing file throws
    // PathNotFoundException on Windows.
    // (rotation now belongs to the sink — same rule, one implementation)
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Scrub PII before saving or sending logs (shared canonical scrubber)
    final scrubbedMessage = scrubPii(message);
    final contextJson = scrubPii(jsonEncode(context));

    final encodedContext = Uri.encodeComponent(contextJson);
    final logLine =
        '[$timestamp] [$level] $scrubbedMessage | $encodedContext\n';
    await _sink!.append(logLine);
  }

  Future<List<String>> readLogs() async {
    if (_sink == null) await init();
    return _sink!.readLines();
  }

  Future<void> clearLogs() async {
    if (_sink == null) await init();
    // W9.11: a user-requested clear removes BOTH generations — the rotated
    // archive must not outlive the explicit clear.
    await _sink!.clear();
  }
}
