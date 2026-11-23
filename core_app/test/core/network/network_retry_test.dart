// BATCH QUEUE-2 — NetworkRetry classification (T-1) + backoff engine (T-2).
//
// T-1 proves the exact permanent-code skip set from the batch contract:
// permission-denied | not-found | invalid-argument | unauthenticated |
// failed-precondition | already-exists are NEVER retried.
// T-2 proves the exponential ladder is bounded and that the delay seam is
// the real Future.delayed by default (production), recorded when swapped.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    // Restore the PRODUCTION delay so no other suite inherits the recorder.
    NetworkRetry.delay = Future<void>.delayed;
  });

  group('T-1 — isRetryable classification (batch contract 1)', () {
    test('callables: the six permanent codes are NOT retryable', () {
      const permanentCodes = {
        'permission-denied',
        'not-found',
        'invalid-argument',
        'unauthenticated',
        'failed-precondition',
        'already-exists',
      };
      for (final code in permanentCodes) {
        expect(
          NetworkRetry.isRetryable(
            FirebaseFunctionsException(code: code, message: code),
          ),
          isFalse,
          reason: '$code can never heal — must not be retried',
        );
      }
    });

    test('callables: transient infrastructure codes ARE retryable', () {
      const transientCodes = {
        'unavailable',
        'internal',
        'deadline-exceeded',
        'resource-exhausted',
        'unknown',
      };
      for (final code in transientCodes) {
        expect(
          NetworkRetry.isRetryable(
            FirebaseFunctionsException(code: code, message: code),
          ),
          isTrue,
          reason: '$code is transient and must be retried with backoff',
        );
      }
    });

    test('firestore: permission-denied is NOT retryable (contract 1)', () {
      expect(
        NetworkRetry.isRetryable(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isFalse,
        reason: 'a rules rejection never heals — retrying only burns backoff',
      );
    });

    test('firestore: transient codes are retryable', () {
      expect(
        NetworkRetry.isRetryable(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isTrue,
      );
    });

    test('raw transport errors default to retryable', () {
      // SocketException / TimeoutException / http ClientException are
      // transport-level and transient by nature.
      expect(NetworkRetry.isRetryable(TimeoutException('stall')), isTrue);
      expect(NetworkRetry.isRetryable(Exception('socket error')), isTrue);
    });
  });

  group('T-2 — exponential backoff is classified and bounded', () {
    test('transient x2 then success: 3 attempts, delays 1s then 2s', () async {
      final delays = <Duration>[];
      NetworkRetry.delay = (d) async => delays.add(d);
      var attempts = 0;

      final result = await NetworkRetry.withExponentialBackoff<int>(() async {
        attempts++;
        if (attempts < 3) {
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'blip',
          );
        }
        return 42;
      });

      expect(result, 42);
      expect(attempts, 3);
      expect(delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ], reason: 'exponential ladder: 1000ms * 2^attempt');
    });

    test(
      'PERMANENT failure: ONE attempt, zero backoff, error rethrown',
      () async {
        final delays = <Duration>[];
        NetworkRetry.delay = (d) async => delays.add(d);
        var attempts = 0;

        await expectLater(
          NetworkRetry.withExponentialBackoff<int>(() async {
            attempts++;
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'rules',
            );
          }),
          throwsA(isA<FirebaseFunctionsException>()),
        );

        expect(
          attempts,
          1,
          reason: 'permanent errors must not burn the backoff ladder',
        );
        expect(delays, isEmpty, reason: 'no sleep for a permanent failure');
      },
    );

    test(
      'retryable-but-exhausted: bounded at maxRetries + 1 (1s,2s,4s)',
      () async {
        final delays = <Duration>[];
        NetworkRetry.delay = (d) async => delays.add(d);
        var attempts = 0;

        await expectLater(
          NetworkRetry.withExponentialBackoff<int>(() async {
            attempts++;
            throw TimeoutException('transport down');
          }),
          throwsA(isA<TimeoutException>()),
          reason: 'the ORIGINAL error is rethrown unchanged after exhaustion',
        );

        expect(
          attempts,
          4,
          reason: 'initial attempt + maxRetries(3) — bounded, never infinite',
        );
        expect(delays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
        ]);
      },
    );

    test('default delay is the REAL Future.delayed in production', () {
      expect(
        NetworkRetry.delay,
        same(Future<void>.delayed),
        reason:
            'the @visibleForTesting seam must default to real backoff — '
            'production always sleeps the full ladder',
      );
    });
  });
}
