import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:labs/features/driver/proof_of_delivery_service.dart';
import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

// --- Fakes ---

class FakeImagePicker extends ImagePicker {
  bool willCancel;
  FakeImagePicker({this.willCancel = false});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (willCancel) return null;

    // Create a dummy temp file to mimic a captured photo
    final dir = Directory.systemTemp;
    final dummyFile = File('${dir.path}/dummy_photo.jpg');
    if (!dummyFile.existsSync()) {
      dummyFile.writeAsBytesSync([0x00, 0x01]);
    }
    return XFile(dummyFile.path);
  }
}

void main() {
  group('ProofOfDeliveryService', () {
    test('returns null if driver cancels camera picker', () async {
      final fakePicker = FakeImagePicker(willCancel: true);
      final syncQueue = RecordingSyncQueue();
      final service = ProofOfDeliveryService(
        picker: fakePicker,
        db: FakeFirebaseFirestore(),
        logger: LoggerService(),
        syncQueue: syncQueue,
      );

      final result = await service.captureAndUpload(
        orderId: 'ORDER_123',
        driverId: 'DRIVER_99',
      );

      expect(result, isNull);
      // STAFF-QUEUE (W5.4): a cancelled capture must never queue anything —
      // no write was intended, so no replayable op may exist.
      expect(syncQueue.enqueuedPayloads, isEmpty);
    });
  });

  group('ProofOfDeliveryService — STAFF-QUEUE (W5.4) queued write', () {
    late RecordingFakeFirestore recordingFirestore;
    late RecordingSyncQueue recordingQueue;
    late List<String> timeline;
    late ProofOfDeliveryService service;

    setUp(() {
      timeline = <String>[];
      // One merged call-order timeline across the queue double and the
      // Firestore double — the T-1 enqueue-before-write proof surface.
      recordingQueue = RecordingSyncQueue(events: timeline);
      recordingFirestore = RecordingFakeFirestore(events: timeline);
      service = ProofOfDeliveryService(
        db: recordingFirestore,
        logger: LoggerService(),
        syncQueue: recordingQueue,
      );
    });

    Future<void> seedOrder(String orderId, String status) async {
      await recordingFirestore.collection('orders').doc(orderId).set({
        'branchId': 'branch1',
        'status': status,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
        'totalCents': 1000,
        'items': [],
      });
      timeline.clear();
    }

    test(
      'T-1: writeProofOfDelivery enqueues the update op BEFORE the Firestore write',
      () async {
        await seedOrder('sq-pod', 'pickedUp');

        await service.writeProofOfDelivery(
          orderId: 'sq-pod',
          driverId: 'DRIVER_99',
          downloadUrl: 'https://storage.example/pod.jpg',
        );

        expect(
          timeline.indexOf('enqueue:update:sq-pod'),
          greaterThan(timeline.indexOf('collection:orders')),
          reason:
              'STAFF-QUEUE: the pre-flight read must precede the enqueue '
              '(fail-closed before any durable side effect)',
        );
        expect(
          timeline.indexOf('enqueue:update:sq-pod'),
          lessThan(timeline.lastIndexOf('collection:orders')),
          reason:
              'T-1: the update op must be durably enqueued BEFORE the '
              'Firestore update (the write enters through the LAST '
              "collection('orders') call) so a killed write stays replayable",
        );
        expect(
          timeline.last,
          'remove:update:sq-pod',
          reason: 'T-4: on success the op is removed last',
        );
        expect(recordingQueue.enqueuedPayloads.single['id'], 'sq-pod');
        expect(recordingQueue.enqueuedPayloads.single['status'], 'delivered');
        final pod =
            recordingQueue.enqueuedPayloads.single['proofOfDelivery']
                as Map<String, dynamic>;
        expect(pod['url'], 'https://storage.example/pod.jpg');
        expect(pod['uploadedBy'], 'DRIVER_99');
        expect(
          pod['capturedAt'],
          isA<String>(),
          reason:
              'the queued capturedAt must be an ISO-8601 string — a '
              'FieldValue sentinel cannot survive the Isar JSON round-trip',
        );
      },
    );

    test(
      'T-4: queue is empty after a successful proof-of-delivery write',
      () async {
        await seedOrder('sq-pod4', 'pickedUp');

        await service.writeProofOfDelivery(
          orderId: 'sq-pod4',
          driverId: 'DRIVER_99',
          downloadUrl: 'https://storage.example/pod.jpg',
        );

        expect(
          recordingQueue.pendingPayloads,
          isEmpty,
          reason: 'T-4: the pending op must be removed once the write commits',
        );
        final doc = await recordingFirestore
            .collection('orders')
            .doc('sq-pod4')
            .get();
        expect(doc.data()!['status'], 'delivered');
        expect(
          (doc.data()!['proofOfDelivery'] as Map<String, dynamic>)['url'],
          'https://storage.example/pod.jpg',
        );
      },
    );

    test(
      'invalid delivered transition leaves NO pending op (pre-flight guard precedes enqueue)',
      () async {
        await seedOrder('sq-pod-dead', 'ready');

        await expectLater(
          service.writeProofOfDelivery(
            orderId: 'sq-pod-dead',
            driverId: 'DRIVER_99',
            downloadUrl: 'https://storage.example/pod.jpg',
          ),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('Invalid status transition') &&
                  e.toString().contains('ready -> delivered'),
            ),
          ),
        );
        expect(
          recordingQueue.enqueuedPayloads,
          isEmpty,
          reason:
              'a business-invalid request must NEVER leave a pending op — '
              'a later replay could otherwise apply the ready -> delivered '
              'jump out-of-band',
        );
      },
    );

    test(
      'missing order leaves NO pending op (not-found precedes enqueue)',
      () async {
        await expectLater(
          service.writeProofOfDelivery(
            orderId: 'sq-pod-missing',
            driverId: 'DRIVER_99',
            downloadUrl: 'https://storage.example/pod.jpg',
          ),
          throwsA(isA<FirebaseException>()),
        );
        expect(
          recordingQueue.enqueuedPayloads,
          isEmpty,
          reason: 'a not-found order must never be queued',
        );
      },
    );

    test('buildProofOfDeliveryPayload emits the EXACT rules-legal key set', () {
      final payload = buildProofOfDeliveryPayload(
        orderId: 'o1',
        downloadUrl: 'https://storage.example/pod.jpg',
        driverId: 'driver-1',
        capturedAt: DateTime.parse('2026-01-01T00:00:00.000'),
      );
      // The delivery rules clause (firestore.rules:403-427) admits only
      // affectedKeys().hasOnly([status, assignedDriverId, updatedAt,
      // proofOfDelivery]) — the queued payload contributes
      // {id, status, proofOfDelivery} and the queue stamps updatedAt on
      // replay; the id is UNCHANGED vs the stored doc (proven invariant),
      // so any EXTRA key here would rules-DENY the replay into the DLQ.
      expect(payload.keys.toSet(), {'id', 'status', 'proofOfDelivery'});
      expect(payload['id'], 'o1');
      expect(payload['status'], 'delivered');
      expect(
        (payload['proofOfDelivery'] as Map<String, dynamic>).keys.toSet(),
        {'url', 'uploadedBy', 'capturedAt'},
      );
    });
  });
}
