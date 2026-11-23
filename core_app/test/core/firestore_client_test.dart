import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late _MockLogger mockLogger;
  late FirestoreClient client;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockLogger = _MockLogger();
    // Use the private constructor signature if exposed, otherwise we test the public run/stream by injecting the instance conceptually.
    // For testability, if FirestoreClient doesn't expose the logger injection publicly we bypass or use standard initialization.
    // Assuming our recently written code:
    FirestoreClient.setMock(
      FirestoreClient.testInject(fakeFirestore, mockLogger),
    );
    client = FirestoreClient.instance;
  });

  group('FirestoreClient Compliance Validation', () {
    test(
      'run() method executes successfully without logging on happy path',
      () async {
        await fakeFirestore.collection('users').doc('u1').set({'name': 'Test'});

        final result = await client.run((db) async {
          final doc = await db.collection('users').doc('u1').get();
          return doc.data()?['name'];
        });

        expect(result, 'Test');
        expect(mockLogger.didLogError, false);
      },
    );

    test(
      'run() intercepts exceptions and maps them to logger immediately',
      () async {
        // Intentionally trigger a crash by bypassing normal mock limits or throwing directly inside the lambda
        Object? caughtException;

        try {
          await client.run((db) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            );
          });
        } catch (e) {
          caughtException = e;
        }

        expect(caughtException, isNotNull);
        expect(mockLogger.didLogError, true);
      },
    );

    test(
      'stream() intercepts AsyncErrors and funnels to telemetry logger gracefully',
      () async {
        final controller = StreamController<QuerySnapshot>.broadcast();

        final stream = client.stream((db) => controller.stream);

        bool errorEmittedLocal = false;
        stream.listen(
          (data) {},
          onError: (e) {
            errorEmittedLocal = true;
          },
        );

        controller.addError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        await Future.delayed(Duration.zero);

        expect(mockLogger.didLogError, true);
        expect(errorEmittedLocal, true);

        await controller.close();
      },
    );
  });
}

class _MockLogger extends ErrorLoggerService {
  bool didLogError = false;

  @override
  Future<void> recordNonFatalError(
    Object error,
    StackTrace? stack, {
    String? currentScreen,
    String? actionTaken,
  }) async {
    didLogError = true;
  }
}
