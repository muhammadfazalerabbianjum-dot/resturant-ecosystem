import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/error_logger/error_logger_service.dart';
import 'package:core/src/network/firestore_client.dart';

/// PERF-1 (T-6) — the centralized FirestoreClient wrapper: exception
/// mapping on `run` (mapped Exception, never raw SDK text), stream error
/// containment on `stream`, and the mock/test-injection seams.

void main() {
  // The null-reporter logger is a proven safe no-op (error_logger_test).
  final logger = ErrorLoggerService(null);

  group('FirestoreClient.run — exception mapping (Law 46)', () {
    test('a successful action returns its value untouched', () async {
      final client = FirestoreClient.testInject(
        FakeFirebaseFirestore(),
        logger,
      );

      final result = await client.run<int>((db) async => 7, tag: 'probe');
      expect(result, 7);
    });

    test('a failure is rethrown as the MAPPED exception (never raw)', () async {
      final client = FirestoreClient.testInject(
        FakeFirebaseFirestore(),
        logger,
      );

      await expectLater(
        client.run<Object>(
          (db) async => throw StateError('RAW_INTERNALS'),
          tag: 'order-write',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FirestoreClient.stream — error containment', () {
    test('a healthy stream passes values through', () async {
      final client = FirestoreClient.testInject(
        FakeFirebaseFirestore(),
        logger,
      );

      final values = await client
          .stream<int>(
            (db) => Stream<int>.fromIterable([1, 2, 3]),
            tag: 'probe-stream',
          )
          .toList();
      expect(values, [1, 2, 3]);
    });

    test('a stream error is recorded then rethrown to the listener', () async {
      final client = FirestoreClient.testInject(
        FakeFirebaseFirestore(),
        logger,
      );

      await expectLater(
        client.stream<int>(
          (db) => Stream<int>.error(StateError('stream broke')),
          tag: 'probe-stream',
        ),
        emitsError(isA<StateError>()),
        reason: 'the ORIGINAL error rethrows — the wrapper only records it',
      );
    });
  });

  group('FirestoreClient — seams', () {
    test(
      'setMock overrides instance; testInject builds an injected client',
      () {
        final injected = FirestoreClient.testInject(
          FakeFirebaseFirestore(),
          logger,
        );
        FirestoreClient.setMock(injected);
        expect(identical(FirestoreClient.instance, injected), isTrue);
        // Restore the production singleton for any later reader.
        FirestoreClient.setMock(
          FirestoreClient.testInject(FakeFirebaseFirestore(), logger),
        );
      },
    );
  });
}
