import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:labs/features/driver/proof_of_delivery_service.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

class MockTask extends Mock implements UploadTask {}

class MockTaskSnapshot extends Mock implements TaskSnapshot {}

class MockXFile extends Mock implements XFile {}

class FakeFile extends Fake implements File {}

void main() {
  setUpAll(() {
    // mocktail needs fallback instances for the non-mocked parameter types
    // used by `any()` in the storage-upload stubs.
    registerFallbackValue(FakeFile());
    registerFallbackValue(SettableMetadata());
  });

  group('ProofOfDeliveryService (TC1)', () {
    testWidgets('ProofOfDeliveryButton renders default state natively', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProofOfDeliveryButton(
                orderId: 'ORDER_123',
                driverId: 'DRIVER_456',
              ),
            ),
          ),
        ),
      );

      // Verify widget boundaries map beautifully
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Capture Proof of Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(
        find.bySemanticsLabel('Capture proof of delivery photo'),
        findsOneWidget,
      );
    });

    test(
      'ProofOfDeliveryService constructs lazily without eager Firebase crashes',
      () {
        // Validates lazy getters block unmounted native testing hooks
        final svc = ProofOfDeliveryService(
          db: FakeFirebaseFirestore(),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
        );
        expect(svc, isNotNull);
      },
    );
  });

  group('buildProofOfDeliveryPayload — the RULES-LEGAL replay payload', () {
    test('carries exactly the delivery-clause keys with an ISO capturedAt', () {
      final capturedAt = DateTime.parse('2026-09-14T09:30:00.000');

      final payload = buildProofOfDeliveryPayload(
        orderId: 'order-1',
        downloadUrl: 'https://cdn/pod.jpg',
        driverId: 'driver-1',
        capturedAt: capturedAt,
      );

      expect(payload.keys, <String>['id', 'status', 'proofOfDelivery']);
      expect(payload['id'], 'order-1');
      expect(payload['status'], 'delivered');
      final pod = payload['proofOfDelivery'] as Map<String, dynamic>;
      expect(pod['url'], 'https://cdn/pod.jpg');
      expect(pod['uploadedBy'], 'driver-1');
      expect(
        pod['capturedAt'],
        capturedAt.toIso8601String(),
        reason:
            'the queued payload is JSON-encoded into Isar — a FieldValue '
            'sentinel cannot survive that round-trip',
      );
    });
  });

  group('ProofOfDeliveryService.writeProofOfDelivery — queue-before-write', () {
    late RecordingFakeFirestore db;
    late RecordingSyncQueue queue;
    late List<String> events;

    setUp(() {
      events = <String>[];
      db = RecordingFakeFirestore(events: events);
      queue = RecordingSyncQueue(events: events);
    });

    Future<void> seedOrder(String status) async {
      await db.collection('orders').doc('o1').set(<String, dynamic>{
        'status': status,
      });
      events.clear(); // scope the call-order log to the call under test
    }

    test(
      'enqueues the rules-legal payload BEFORE the Firestore write and removes it on success',
      () async {
        // pickedUp -> delivered is the ONLY legal route to 'delivered' in the
        // W8.3 state machine the pre-flight guard enforces.
        await seedOrder('pickedUp');
        final svc = ProofOfDeliveryService(
          db: db,
          logger: FakeLogger(),
          syncQueue: queue,
        );

        await svc.writeProofOfDelivery(
          orderId: 'o1',
          driverId: 'd1',
          downloadUrl: 'https://cdn/x.jpg',
        );

        expect(events, contains('enqueue:update:o1'));
        expect(
          events.indexOf('enqueue:update:o1'),
          lessThan(events.lastIndexOf('collection:orders')),
          reason: 'the durable enqueue happens BEFORE the online write',
        );
        expect(events.last, 'remove:update:o1');
        expect(
          queue.pendingPayloads,
          isEmpty,
          reason: 'nothing stays pending after a successful write',
        );

        final doc = await db.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'delivered');
        final pod = doc.data()!['proofOfDelivery'] as Map<String, dynamic>;
        expect(pod['url'], 'https://cdn/x.jpg');
        expect(pod['uploadedBy'], 'd1');
      },
    );

    test('a missing order fails CLOSED before anything is queued', () async {
      final svc = ProofOfDeliveryService(
        db: db,
        logger: FakeLogger(),
        syncQueue: queue,
      );

      await expectLater(
        svc.writeProofOfDelivery(
          orderId: 'missing',
          driverId: 'd1',
          downloadUrl: 'https://cdn/x.jpg',
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        queue.enqueuedPayloads,
        isEmpty,
        reason: 'a never-found order is never queued',
      );
    });

    test(
      'a terminal status cannot transition to delivered — nothing queued',
      () async {
        await seedOrder('delivered');
        final svc = ProofOfDeliveryService(
          db: db,
          logger: FakeLogger(),
          syncQueue: queue,
        );

        await expectLater(
          svc.writeProofOfDelivery(
            orderId: 'o1',
            driverId: 'd1',
            downloadUrl: 'https://cdn/x.jpg',
          ),
          throwsA(isA<Exception>()),
        );
        expect(queue.enqueuedPayloads, isEmpty);
      },
    );
  });

  group('ProofOfDeliveryService.captureAndUpload — storage integration', () {
    test(
      'the full happy path: camera → storage upload → rules-legal write → URL',
      () async {
        final events = <String>[];
        final db = RecordingFakeFirestore(events: events);
        final queue = RecordingSyncQueue(events: events);
        await db.collection('orders').doc('o1').set(<String, dynamic>{
          'status': 'pickedUp',
        });
        events.clear();

        final picker = MockImagePicker();
        final storage = MockFirebaseStorage();
        final ref = MockReference();
        final task = MockTask();
        final snapshot = MockTaskSnapshot();
        final photo = MockXFile();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          ),
        ).thenAnswer((_) async => photo);
        when(() => photo.path).thenReturn('photo.jpg');
        when(() => storage.ref(any())).thenReturn(ref);
        // putFile returns an UploadTask — which IS-A Future<TaskSnapshot> — so
        // mocktail requires thenAnswer (thenReturn rejects Future instances).
        when(() => ref.putFile(any(), any())).thenAnswer((_) => task);
        when(() => task.whenComplete(any())).thenAnswer((_) async => snapshot);
        when(() => snapshot.ref).thenReturn(ref);
        when(
          () => ref.getDownloadURL(),
        ).thenAnswer((_) async => 'https://cdn/pod.jpg');

        final svc = ProofOfDeliveryService(
          db: db,
          logger: FakeLogger(),
          syncQueue: queue,
          storage: storage,
          picker: picker,
        );

        final url = await svc.captureAndUpload(orderId: 'o1', driverId: 'd1');

        expect(url, 'https://cdn/pod.jpg');
        verify(() => ref.putFile(any(), any())).called(1);
        expect(queue.enqueuedPayloads, isNotEmpty);
        expect(queue.pendingPayloads, isEmpty);

        final doc = await db.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'delivered');
      },
    );

    test(
      'a camera cancel (null photo) returns null with zero side effects',
      () async {
        final queue = RecordingSyncQueue();
        final picker = MockImagePicker();
        final storage = MockFirebaseStorage();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          ),
        ).thenAnswer((_) async => null);

        final svc = ProofOfDeliveryService(
          db: FakeFirebaseFirestore(),
          logger: FakeLogger(),
          syncQueue: queue,
          storage: storage,
          picker: picker,
        );

        expect(
          await svc.captureAndUpload(orderId: 'o1', driverId: 'd1'),
          isNull,
        );
        verifyNever(() => storage.ref(any()));
        expect(queue.enqueuedPayloads, isEmpty);
      },
    );

    test(
      'a capture failure is logged then RETHROWN (never swallowed)',
      () async {
        final picker = MockImagePicker();
        when(
          () => picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1280,
          ),
        ).thenThrow(StateError('camera locked'));
        final logger = FakeLogger();

        final svc = ProofOfDeliveryService(
          db: FakeFirebaseFirestore(),
          logger: logger,
          syncQueue: RecordingSyncQueue(),
          picker: picker,
        );

        await expectLater(
          svc.captureAndUpload(orderId: 'o1', driverId: 'd1'),
          throwsA(isA<StateError>()),
        );
        expect(logger.loggedErrors, contains('proof_of_delivery_failed'));
      },
    );
  });
}
