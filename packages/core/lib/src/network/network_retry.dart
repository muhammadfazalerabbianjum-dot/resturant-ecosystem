import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctionsException;
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Global networking utility to protect against 2G edge networks and infinite loads.
class NetworkRetry {
  /// Error codes that can NEVER succeed on retry — the request itself is
  /// invalid, forbidden, or already settled (batch QUEUE-2, P-4).
  ///
  /// Retrying these burns exponential backoff on a permanent condition,
  /// delays the user's error message by up to 7s, and multiplies server
  /// load during incidents. The same gRPC-derived code set applies to both
  /// [FirebaseFunctionsException] (callables) and [FirebaseException]
  /// (Firestore/Auth/Storage — e.g. a Firestore `permission-denied` read
  /// never heals by retrying).
  static const _nonRetryableCodes = <String>{
    'permission-denied', // rules/authz rejection — deterministic
    'not-found', // missing document/function — deterministic
    'invalid-argument', // client bug — redrawing the same request cannot fix it
    'unauthenticated', // expired/absent token — needs re-auth, not a retry
    'failed-precondition', // server-side state veto (e.g. promo exhausted)
    'already-exists', // conflicting create — re-running cannot succeed
  };

  /// Whether [error] is worth retrying with backoff (batch QUEUE-2, contract 1).
  ///
  /// FIX-B5 QUEUE-3 (T-1): this is the SINGLE canonical classifier — both
  /// retry entry points (`NetworkRetry.withExponentialBackoff` and the
  /// offline outbox via `IsarSyncQueue.isPermanentFailure`, a delegating
  /// shim) route through this predicate, so a code can never be "permanent"
  /// for one twin and "retryable" for the other (AUD1-03).
  ///
  /// Classification rules:
  /// - [FirebaseFunctionsException] / [FirebaseException]: retryable unless
  ///   the code is one of the permanent codes in [_nonRetryableCodes]
  ///   (`permission-denied`, `not-found`, `invalid-argument`,
  ///   `unauthenticated`, `failed-precondition`, `already-exists`).
  /// - Everything else (SocketException, TimeoutException, http
  ///   ClientException, ...) is transport-level and assumed transient —
  ///   fail-closed callers still surface the final error after the bounded
  ///   attempts, so this default cannot mask a failure.
  static bool isRetryable(Object error) {
    if (error is FirebaseFunctionsException) {
      return !_nonRetryableCodes.contains(error.code);
    }
    if (error is FirebaseException) {
      return !_nonRetryableCodes.contains(error.code);
    }
    return true;
  }

  /// Delay injection seam for tests (batch QUEUE-2, T-2). Production code
  /// MUST NOT reassign this: the default is a real [Future.delayed], so the
  /// shipped backoff (1s → 2s → 4s) is fully live. Tests swap in a recorder
  /// or a no-op to prove the exponential sequence without wall-clock waits.
  @visibleForTesting
  static Future<void> Function(Duration duration) delay = Future<void>.delayed;

  /// Wraps an async [computation] in an exponential backoff engine.
  /// Enforces a hard [timeout] per attempt (default 10s) and retries up to [maxRetries].
  ///
  /// QUEUE-2 (P-4): a retry is only attempted when [isRetryable] classifies
  /// the failure as transient — permanent errors (permission-denied,
  /// failed-precondition, ...) rethrow IMMEDIATELY so fail-closed callers
  /// surface the real reason without burning the backoff ladder. The final
  /// error (retryable-but-exhausted or permanent) is always rethrown
  /// unchanged, preserving every call site's fail-closed semantics.
  static Future<T> withExponentialBackoff<T>(
    Future<T> Function() computation, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await computation().timeout(timeout);
      } catch (e) {
        if (!isRetryable(e) || attempt >= maxRetries) {
          rethrow;
        }
        // Base delay 1000ms, doubling each attempt: 1s, 2s, 4s...
        final backoff = pow(2, attempt) * 1000;
        await delay(Duration(milliseconds: backoff.toInt()));
        attempt++;
      }
    }
  }
}
