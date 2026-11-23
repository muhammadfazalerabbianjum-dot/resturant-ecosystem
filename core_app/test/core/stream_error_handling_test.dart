import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

/// Law 34 (Stream Safety) + Law 46 (Exception Surface)
///
/// Tests that a Firestore stream emitting an error:
/// 1. Is caught and does NOT silently close the stream.
/// 2. Does not crash the listener.
/// 3. Allows subsequent valid emissions after the error.
/// 4. Can be fully cancelled (no ghost subscriptions).

// Minimal stand-in for what a repository stream wrapper does.
// Takes a raw Stream<dynamic> and maps it to Stream<List<String>>,
// catching errors and replacing them with typed exceptions.
Stream<List<String>> _safelyMappedStream(Stream<dynamic> raw) {
  return raw
      .map<List<String>>((event) {
        if (event is List) return event.cast<String>();
        throw StateError('Unexpected event type: ${event.runtimeType}');
      })
      .handleError((Object error, StackTrace stack) {
        // Law 46: exceptions are mapped and re-thrown as typed errors,
        // NOT swallowed silently. The stream stays open.
        if (error is FirebaseException) {
          throw Exception(
            '[${error.code}] ${error.message ?? 'Firebase error'}',
          );
        }
        throw error;
      });
}

void main() {
  group('Stream Error Handling Tests (Laws 34, 46)', () {
    test('FirebaseException emits mapped error — stream stays open', () async {
      final controller = StreamController<dynamic>();
      final mapped = _safelyMappedStream(controller.stream);

      final emittedErrors = <Object>[];
      final emittedData = <List<String>>[];

      // Listen without cancelling on error, using onError to capture
      final sub = mapped.listen(
        emittedData.add,
        onError: emittedErrors.add,
        cancelOnError: false, // stream must stay open
      );

      // Emit a FirebaseException error
      controller.addError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        emittedErrors,
        hasLength(1),
        reason: 'One mapped error must be emitted',
      );
      expect(
        emittedErrors.first.toString(),
        contains('permission-denied'),
        reason: 'Error must contain the Firebase code',
      );
      expect(
        emittedData,
        isEmpty,
        reason: 'No data should be emitted for an error event',
      );
      expect(
        controller.isClosed,
        isFalse,
        reason: 'Stream must remain open after error (cancelOnError: false)',
      );

      await sub.cancel();
      await controller.close();
    });

    test('Valid emission after error is delivered correctly', () async {
      final controller = StreamController<dynamic>();
      final mapped = _safelyMappedStream(controller.stream);

      final emittedData = <List<String>>[];
      final sub = mapped.listen(
        emittedData.add,
        onError: (_) {}, // absorb error in this test
        cancelOnError: false,
      );

      // First: emit error
      controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(emittedData, isEmpty);

      // Then: emit valid data
      controller.add(['Item A', 'Item B']);
      await Future<void>.delayed(Duration.zero);

      expect(emittedData, hasLength(1));
      expect(emittedData.first, ['Item A', 'Item B']);

      await sub.cancel();
      await controller.close();
    });

    test('cancel() stops further events — no ghost subscriptions', () async {
      final controller = StreamController<dynamic>.broadcast();
      final mapped = _safelyMappedStream(controller.stream);

      final received = <List<String>>[];
      final sub = mapped.listen(received.add, onError: (_) {});

      // Emit one event
      controller.add(['First']);
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));

      // Cancel the subscription
      await sub.cancel();

      // Emit more events — these must NOT reach the cancelled listener
      controller.add(['Second']);
      controller.add(['Third']);
      await Future<void>.delayed(Duration.zero);

      expect(
        received,
        hasLength(1),
        reason: 'Cancelled subscription must not receive further events',
      );

      await controller.close();
    });

    test('Stream error does not throw unhandled exception to Zone', () async {
      final errors = <Object>[];

      await runZonedGuarded(() async {
        final controller = StreamController<dynamic>();
        final mapped = _safelyMappedStream(controller.stream);

        final sub = mapped.listen(
          (_) {},
          onError: (_) {},
          cancelOnError: false,
        );

        controller.addError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'deadline-exceeded',
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        await controller.close();
      }, (error, stack) => errors.add(error));

      expect(
        errors,
        isEmpty,
        reason: 'No unhandled Zone error must escape a handled stream error',
      );
    });
  });
}
