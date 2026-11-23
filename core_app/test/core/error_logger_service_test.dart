import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../mock_firebase.dart';

/// Manual mock that records all calls for verification.
class MockCrashReporter implements CrashReporter {
  final List<({String key, Object value})> customKeys = [];
  List<({Object error, StackTrace? stack, Object? reason})>? recordedErrors;
  final List<FlutterErrorDetails> recordedFlutter = [];

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys.add((key: key, value: value));
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Object? reason,
  }) async {
    recordedErrors ??= [];
    recordedErrors!.add((error: error, stack: stack, reason: reason));
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    recordedFlutter.add(details);
  }
}

void main() {
  setUpAll(() async {
    setupFirebaseAuthMocks();
    TestWidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('ErrorLoggerService (Law 11)', () {
    test(
      'recordNonFatalError attaches Custom Keys before recording crash',
      () async {
        final mockCrashReporter = MockCrashReporter();
        final service = ErrorLoggerService(mockCrashReporter);

        final fakeError = StateError('Something broke safely');
        final fakeStack = StackTrace.current;

        await service.recordNonFatalError(
          fakeError,
          fakeStack,
          currentScreen: 'CheckoutScreen',
          actionTaken: 'Tapped Pay Button',
        );

        // Verify custom keys were attached EXACTLY as mandated
        expect(
          mockCrashReporter.customKeys,
          containsAll([
            (key: 'user_id', value: 'unauthenticated'),
            (key: 'screen', value: 'CheckoutScreen'),
            (key: 'action', value: 'Tapped Pay Button'),
          ]),
        );

        // Verify the error was finally recorded — UX-3 (W9.11/06-P2-8): the
        // RAW error object NEVER reaches Crashlytics anymore; it is wrapped
        // in RedactedError (type visible in toString, payload scrubbed).
        expect(mockCrashReporter.recordedErrors, isNotNull);
        expect(mockCrashReporter.recordedErrors!.length, 1);
        expect(
          mockCrashReporter.recordedErrors!.first.error.toString(),
          contains('Bad state: Something broke safely'),
        );
      },
    );

    test(
      'T-6: PII-bearing exception is SCRUBBED before Crashlytics (06-P2-8)',
      () async {
        final mockCrashReporter = MockCrashReporter();
        final service = ErrorLoggerService(mockCrashReporter);

        await service.recordNonFatalError(
          Exception('user example@mail.com called 555-123-4567'),
          StackTrace.current,
        );

        final recorded = mockCrashReporter.recordedErrors!.single;
        final text = recorded.error.toString();
        expect(text, contains('[EMAIL_REDACTED]'));
        expect(text, contains('[PHONE_REDACTED]'));
        expect(text, isNot(contains('example@mail.com')));
        expect(text, isNot(contains('555-123-4567')));
        // Triage grouping keeps the original runtime type visible
        // (Dart's base Exception renders as `_Exception: ...`).
        expect(text, startsWith('_Exception:'));
      },
    );

    test(
      'T-6: recordFlutterError payload is SCRUBBED before Crashlytics',
      () async {
        final mockCrashReporter = MockCrashReporter();
        final service = ErrorLoggerService(mockCrashReporter);
        final previousOnError = FlutterError.onError;
        try {
          service.setupFlutterErrorLogging();

          FlutterError.reportError(
            FlutterErrorDetails(
              exception: Exception('crash for jane@example.com'),
              stack: StackTrace.current,
              library: 'test',
            ),
          );

          final recorded = mockCrashReporter.recordedFlutter.single;
          expect(recorded.exception.toString(), contains('[EMAIL_REDACTED]'));
          expect(
            recorded.exception.toString(),
            isNot(contains('jane@example.com')),
          );
        } finally {
          FlutterError.onError = previousOnError;
        }
      },
    );
  });
}
