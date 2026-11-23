import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import 'helpers/mock_firebase.dart';

/// CORE-COV Tier-1 NETWORK suite (QUEUE-2): the isRetryable classification
/// and the exponential-backoff engine's retry/rethrow/timeout contracts.
void main() {
  final recordedDelays = <Duration>[];

  setUp(() {
    recordedDelays.clear();
    NetworkRetry.delay = (Duration duration) async {
      recordedDelays.add(duration);
    };
  });

  tearDown(() {
    // Restore the REAL backoff delay — production code must never run with a
    // test double left in the shared static.
    NetworkRetry.delay = Future<void>.delayed;
  });

  group('NetworkRetry.isRetryable — permanent-code classification', () {
    const permanentCodes = <String>[
      'permission-denied',
      'not-found',
      'invalid-argument',
      'unauthenticated',
      'failed-precondition',
      'already-exists',
    ];

    test('Firestore permanent codes are NOT retryable', () {
      for (final code in permanentCodes) {
        expect(
          NetworkRetry.isRetryable(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isFalse,
          reason: '$code is deterministic — retrying only burns the ladder',
        );
      }
    });

    test('Firestore transient codes ARE retryable', () {
      for (final code in const <String>['unavailable', 'internal', 'aborted']) {
        expect(
          NetworkRetry.isRetryable(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isTrue,
        );
      }
    });

    test('callable (FirebaseFunctionsException) uses the same code set', () {
      expect(
        NetworkRetry.isRetryable(TestFunctionsException('failed-precondition')),
        isFalse,
      );
      expect(
        NetworkRetry.isRetryable(TestFunctionsException('unavailable')),
        isTrue,
      );
    });

    test('transport-level errors default to retryable (transient)', () {
      expect(
        NetworkRetry.isRetryable(const SocketException('offline')),
        isTrue,
      );
      expect(NetworkRetry.isRetryable(TimeoutException('slow')), isTrue);
      expect(NetworkRetry.isRetryable(StateError('logic')), isTrue);
    });
  });

  group('NetworkRetry.withExponentialBackoff', () {
    test('retries transient failures and returns the first success', () async {
      var attempts = 0;
      final result = await NetworkRetry.withExponentialBackoff<int>(() async {
        attempts++;
        if (attempts < 3) throw const SocketException('flaky');
        return 42;
      });

      expect(result, 42);
      expect(attempts, 3);
      expect(recordedDelays, <Duration>[
        const Duration(milliseconds: 1000),
        const Duration(milliseconds: 2000),
      ]);
    });

    test(
      'rethrows the FINAL error unchanged after the full 1s/2s/4s ladder',
      () async {
        var attempts = 0;
        Object? finalError;
        try {
          await NetworkRetry.withExponentialBackoff<int>(() async {
            attempts++;
            throw StateError('always failing #$attempts');
          });
        } catch (e) {
          finalError = e;
        }

        expect(finalError, isA<StateError>());
        expect((finalError as StateError).message, 'always failing #4');
        expect(attempts, 4);
        expect(recordedDelays, <Duration>[
          const Duration(milliseconds: 1000),
          const Duration(milliseconds: 2000),
          const Duration(milliseconds: 4000),
        ]);
      },
    );

    test('permanent errors rethrow IMMEDIATELY with zero backoff', () async {
      final permanent = TestFunctionsException('permission-denied');
      var attempts = 0;
      Object? finalError;
      try {
        await NetworkRetry.withExponentialBackoff<int>(() async {
          attempts++;
          throw permanent;
        });
      } catch (e) {
        finalError = e;
      }

      expect(identical(finalError, permanent), isTrue);
      expect(attempts, 1);
      expect(recordedDelays, isEmpty);
    });

    test(
      'per-attempt timeout rethrows TimeoutException (fail-closed)',
      () async {
        await expectLater(
          NetworkRetry.withExponentialBackoff<int>(
            () => Completer<int>().future,
            maxRetries: 0,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      },
    );
  });
}
