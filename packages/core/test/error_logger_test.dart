import 'dart:io';

import 'package:core/src/error_logger/pii_scrubber.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// CORE-COV Tier-1 ERROR_LOGGER suite (UX-3 / W9.11): the single canonical
/// PII scrubber + RedactedError wrapper, the file logger (rotation, scrub,
/// clear), the FirebaseExceptionMapper table (Law 46), and the
/// [ErrorLoggerService]/CrashReporter redaction contract.
void main() {
  group('scrubPii — single canonical scrubber (GDPR/CCPA)', () {
    test('scrubs emails', () {
      expect(
        scrubPii('customer jane.doe+99@example.co.uk wrote'),
        'customer [EMAIL_REDACTED] wrote',
      );
    });

    test('scrubs standard dashed and dotted phones', () {
      expect(scrubPii('call 555-123-4567'), 'call [PHONE_REDACTED]');
      expect(scrubPii('call 555.123.4567'), 'call [PHONE_REDACTED]');
    });

    test('scrubs international phones', () {
      expect(
        scrubPii('from +971501234567 thanks'),
        'from [PHONE_REDACTED] thanks',
      );
    });

    test('scrubs multiple PII tokens in one payload', () {
      final out = scrubPii('a@b.com paid for 555-123-4567');
      expect(out, contains('[EMAIL_REDACTED]'));
      expect(out, contains('[PHONE_REDACTED]'));
      expect(out.contains('a@b.com'), isFalse);
      expect(out.contains('555'), isFalse);
    });

    test('clean strings pass through byte-identical', () {
      const clean = 'Order ORD-123 confirmed for 1999 cents';
      expect(scrubPii(clean), clean);
    });
  });

  group('RedactedError — type-preserving redaction (triage grouping)', () {
    test('keeps the runtime type visible and scrubs the payload', () {
      final redacted = RedactedError(
        Exception('jane@example.com 555-123-4567'),
      );

      final rendered = redacted.toString();
      // The original runtime type stays visible (string interpolation of the
      // type), the payload is scrubbed.
      expect(rendered, contains('Exception'));
      expect(rendered, contains('[EMAIL_REDACTED]'));
      expect(rendered, contains('[PHONE_REDACTED]'));
      expect(rendered.contains('jane@example.com'), isFalse);
      expect(rendered.contains('555-123-4567'), isFalse);
    });
  });

  group('FirebaseExceptionMapper.map (Law 46 surface mapping)', () {
    String mapCode(String code) => FirebaseExceptionMapper.map(
      FirebaseException(plugin: 'cloud_firestore', code: code),
    );

    test('maps the known Firebase codes', () {
      expect(
        mapCode('permission-denied'),
        'You do not have permission to perform this action.',
      );
      expect(mapCode('unavailable'), contains('temporarily unavailable'));
      expect(mapCode('deadline-exceeded'), contains('took too long'));
      expect(mapCode('not-found'), contains('was not found'));
      expect(mapCode('unauthenticated'), contains('Please log in'));
      expect(
        mapCode('network-request-failed'),
        contains('internet connection'),
      );
      expect(mapCode('user-disabled'), contains('has been disabled'));
      expect(mapCode('wrong-password'), 'Incorrect email or password.');
      expect(mapCode('user-not-found'), 'Incorrect email or password.');
      expect(mapCode('invalid-credential'), 'Incorrect email or password.');
      expect(mapCode('email-already-in-use'), contains('already exists'));
      expect(
        mapCode('weak-password'),
        'That password is too weak. Please choose a stronger one.',
      );
      expect(
        mapCode('too-many-requests'),
        'Too many attempts. Please try again later.',
      );
      expect(mapCode('invalid-email'), 'Please enter a valid email address.');
    });

    test('PERF-1 T-3: the H-2 auth codes map to their dedicated copy and '
        'unknown codes still fall back to the code-naming text', () {
      expect(
        mapCode('weak-password'),
        'That password is too weak. Please choose a stronger one.',
      );
      expect(
        mapCode('too-many-requests'),
        'Too many attempts. Please try again later.',
      );
      expect(mapCode('invalid-email'), 'Please enter a valid email address.');
      expect(
        mapCode('app-check-token-invalid'),
        contains('app-check-token-invalid'),
        reason:
            'a code without a dedicated case still names the code — '
            'no silent generic fallback',
      );
    });

    test('unknown Firebase code names the code (no silent generic)', () {
      expect(mapCode('mystery-code'), contains('mystery-code'));
    });

    test(
      'maps PlatformException network_error; everything else falls back',
      () {
        expect(
          FirebaseExceptionMapper.map(
            PlatformException(code: 'network_error', message: 'x'),
          ),
          contains('Network error'),
        );
        expect(
          FirebaseExceptionMapper.map(StateError('boom')),
          'An unexpected error occurred. Please try again.',
        );
      },
    );
  });
  group('LoggerService — file sink (real temp files)', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('core_cov_logger');
    });

    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    LoggerService logger() =>
        LoggerService(testDirectory: temp, maxLogFileSize: 700);

    test(
      'info/warn/error append level-tagged lines; readLogs returns them',
      () async {
        final log = logger();
        await log.info(<String, dynamic>{'k': 'v'}, 'hello');
        await log.warn(StateError('w'), 'careful');
        await log.error(Exception('e'), 'failed');

        final lines = await log.readLogs();
        expect(lines, hasLength(3));
        expect(lines[0], contains('[INFO]'));
        expect(lines[0], contains('hello'));
        expect(lines[1], contains('[WARN]'));
        expect(lines[2], contains('[ERROR]'));
      },
    );

    test('PERF-1: setContext tags the active screen/user/action', () async {
      final log = logger();
      log.setContext(screen: 'Checkout', userId: 'u-7', action: 'pay');
      await log.error(Exception('x'), 'context tagged');

      final lines = await log.readLogs();
      expect(lines, hasLength(1));
      expect(lines.single, contains('context tagged'));
    });

    test(
      'PERF-1: warn carries an optional stack trace into the context',
      () async {
        final log = logger();
        await log.warn(StateError('boom'), 'warned', stack: StackTrace.current);

        final lines = await log.readLogs();
        expect(lines.single, contains('[WARN]'));
        expect(lines.single, contains('stack'));
      },
    );

    test(
      'PII is scrubbed from BOTH the message and the encoded context',
      () async {
        final log = logger();
        await log.info(<String, dynamic>{
          'email': 'jane@example.com',
        }, 'login by 555-123-4567');

        final line = (await log.readLogs()).single;
        // The context is URI-encoded before appending — decode to inspect the
        // scrubbed values exactly as they were scrubbed pre-encode.
        final decoded = Uri.decodeComponent(line);
        expect(decoded, contains('[EMAIL_REDACTED]'));
        expect(decoded, contains('[PHONE_REDACTED]'));
        expect(decoded.contains('jane@example.com'), isFalse);
        expect(decoded.contains('555-123-4567'), isFalse);
      },
    );

    test(
      'rotation caps app_logs.txt and preserves one archive generation',
      () async {
        final log = logger();
        // Each line ~120 bytes; the cap is 700 — the write that SEES the size
        // already over the cap must trigger the rotation.
        for (var i = 0; i < 9; i++) {
          await log.info(
            <String, dynamic>{},
            'line $i with a generous amount of padding padding padding padding to grow the file quickly',
          );
        }

        final rotated = File('${temp.path}/app_logs.1.txt');
        expect(await rotated.exists(), isTrue);
        final active = File('${temp.path}/app_logs.txt');
        expect(await active.exists(), isTrue);
        expect(
          await active.length(),
          lessThanOrEqualTo(700 + 200),
          reason: 'the active file never grows unbounded after rotation',
        );
      },
    );

    test('clearLogs removes BOTH generations', () async {
      final log = logger();
      for (var i = 0; i < 6; i++) {
        await log.info(<String, dynamic>{}, 'line $i padding padding padding');
      }
      await log.clearLogs();

      expect(await File('${temp.path}/app_logs.txt').exists(), isFalse);
      expect(await File('${temp.path}/app_logs.1.txt').exists(), isFalse);
      expect(await log.readLogs(), isEmpty);
    });

    test(
      'error() is contained when Crashlytics is unavailable (test env)',
      () async {
        final log = logger();
        await log.error(Exception('x'), 'context missing crashlytics');
        expect(
          (await log.readLogs()).single,
          contains('context missing crashlytics'),
        );
      },
    );
  });
  group('ErrorLoggerService — Crashlytics contract', () {
    late _RecordingCrashReporter reporter;
    dynamic originalOnError;
    dynamic originalPresentError;

    setUp(() {
      reporter = _RecordingCrashReporter();
      originalOnError = FlutterError.onError;
      originalPresentError = FlutterError.presentError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
      FlutterError.presentError = originalPresentError;
    });

    test(
      'a null reporter is a safe no-op (never crashes the error path)',
      () async {
        await ErrorLoggerService(null).recordNonFatalError(
          Exception('x'),
          StackTrace.current,
          currentScreen: 'Home',
        );
        ErrorLoggerService(null).setupFlutterErrorLogging();
      },
    );

    test(
      'recordNonFatalError is contained when the Firebase runtime is absent',
      () async {
        // FirebaseAuth.instance cannot resolve without an initialized app —
        // the service must swallow that and still complete (the error path
        // may never crash), reporting nothing unattributed to Crashlytics.
        await ErrorLoggerService(reporter).recordNonFatalError(
          Exception('user@example.com 555-123-4567'),
          StackTrace.current,
          currentScreen: 'Checkout',
          actionTaken: 'pay',
        );
        expect(reporter.errors, isEmpty);
      },
    );

    test(
      'setupFlutterErrorLogging redacts the exception before Crashlytics (W9.11)',
      () async {
        FlutterError.presentError = (FlutterErrorDetails details) {};
        final service = ErrorLoggerService(reporter);
        service.setupFlutterErrorLogging();

        FlutterError.reportError(
          FlutterErrorDetails(
            exception: Exception('leak jane@example.com 555-123-4567'),
            stack: StackTrace.current,
            library: 'test',
          ),
        );
        await pumpEventQueue();

        expect(reporter.flutterErrors, hasLength(1));
        final redacted =
            reporter.flutterErrors.single.exception as RedactedError;
        final rendered = redacted.toString();
        expect(rendered, contains('Exception'));
        expect(rendered, contains('[EMAIL_REDACTED]'));
        expect(rendered, contains('[PHONE_REDACTED]'));
        expect(rendered.contains('jane@example.com'), isFalse);
      },
    );
  });
}

/// Hand-rolled recording double for [CrashReporter] — captures the exact
/// objects the service hands to the crash backend.
class _RecordingCrashReporter implements CrashReporter {
  final Map<String, Object> keys = <String, Object>{};
  final List<Object> errors = <Object>[];
  final List<FlutterErrorDetails> flutterErrors = <FlutterErrorDetails>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {
    keys[key] = value;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Object? reason,
  }) async {
    errors.add(error);
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    flutterErrors.add(details);
  }
}
