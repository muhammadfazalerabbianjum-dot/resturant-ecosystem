import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../../helpers/isar_test_boot.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/driver/proof_of_delivery_service.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import '../../../support/tenant_claim_fakes.dart';

// ── STAFF-QUEUE (W5.4) T-2 — replay through the REAL IsarSyncQueue ─────────
// Proves the queue side of the contract: a pending staff 'update' op is
// replayed by `IsarSyncQueue.processQueue` as set(payload, {merge:true}) on
// orders/{id}, with the queue-stamped updatedAt and EXACTLY the rules-legal
// key set the W4.1 rules clauses admit (firestore.rules:391-428).

/// Helper to create an on-disk temp Isar instance for testing (mirrors the
/// proven sync_queue_test.dart harness).
Future<Isar> createTestIsar() async {
  final dir = Directory.systemTemp.createTempSync('isar_staff_queue_test_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  return isar;
}

class TestLoggerService extends LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}
}

class TestIsarService extends IsarService {
  final Isar testIsar;

  TestIsarService(this.testIsar) : super.forTesting() {
    db = Future.value(testIsar);
  }
}

/// Records every set() the queue issues — the T-2 assertion surface.
class _RecordingQueueWriter implements QueueFirestoreWriter {
  final setCalls = <_RecordedSet>[];

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    setCalls.add(
      _RecordedSet(
        collectionName: collectionName,
        id: id,
        data: Map<String, dynamic>.of(data),
        options: options,
      ),
    );
  }

  @override
  Future<void> delete(String collectionName, String id) async {}
}

class _RecordedSet {
  final String collectionName;
  final String? id;
  final Map<String, dynamic> data;
  final SetOptions? options;

  const _RecordedSet({
    required this.collectionName,
    required this.id,
    required this.data,
    required this.options,
  });
}

/// Fake Firestore whose TRANSACTIONS always die with the exact transient
/// error a flaky network produces (02-P1-STAFF's "flaky networks lose the
/// mutation") — reads still work, so the STAFF-QUEUE pre-flight guard passes
/// and the op is enqueued before the killed write. This is the precise P1
/// scenario the batch fixes: the status mutation used to be LOST; now it
/// survives as a pending queue op.
class _UnavailableTransactionFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is currently unavailable.',
    );
  }
}

class _FakeDriverLocationService extends DriverLocationService {
  _FakeDriverLocationService()
    : super(
        FakeFirebaseFirestore(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<void> startTracking(String orderId) async {}

  @override
  Future<void> stopTracking() async {}
}

void main() {
  setUpAll(() async {
    await ensureIsarCoreForTests();
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('STAFF-QUEUE T-2 — processQueue replays staff update ops', () {
    late Isar isar;
    late TestIsarService isarService;
    late _RecordingQueueWriter writer;
    late IsarSyncQueue queue;

    setUp(() async {
      isar = await createTestIsar();
      isarService = TestIsarService(isar);
      writer = _RecordingQueueWriter();
      queue = IsarSyncQueue(
        isarService,
        TestLoggerService(),
        firestore: writer,
      );
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
    });

    test(
      'T-2: a network-killed markDelivered leaves a pending op that processQueue replays as set(merge:true) on orders/{id}',
      () async {
        final fakeFirestore = _UnavailableTransactionFirestore();
        await fakeFirestore.collection('orders').doc('sq-r1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch-1',
          'status': 'pickedUp',
          'assignedDriverId': 'driver1',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });

        final service = DeliveryService(
          firestore: fakeFirestore,
          locationService: _FakeDriverLocationService(),
          logger: TestLoggerService(),
          syncQueue: queue,
          tenantClaim: const FixedTenantClaim(),
        );

        // The write dies with `unavailable` — the pre-QUEUE behaviour lost
        // the mutation here; the queued op must survive it.
        await expectLater(
          service.markDelivered('sq-r1'),
          throwsA(isA<FirebaseException>()),
        );

        // The op is STILL pending, carrying the exact rules-legal payload.
        final pending = await isar.isarPendingOperations.where().findAll();
        expect(
          pending,
          hasLength(1),
          reason: 'the killed write must leave the op replayable',
        );
        expect(pending.first.operation, 'update');
        expect(pending.first.collectionName, 'orders');
        final decoded =
            jsonDecode(pending.first.dataString) as Map<String, dynamic>;
        expect(decoded, {'id': 'sq-r1', 'status': 'delivered'});

        // Replay: the queue merge-sets the payload onto orders/{id}.
        await queue.processQueue();

        expect(writer.setCalls, hasLength(1));
        final call = writer.setCalls.single;
        expect(call.collectionName, 'orders');
        expect(call.id, 'sq-r1');
        expect(
          call.options!.merge,
          isTrue,
          reason:
              'T-2: the replay MUST be a merge-set (last-write-wins, '
              'no clobbering of the stored order)',
        );
        expect(
          call.data.keys.toSet(),
          {'id', 'status', 'updatedAt'},
          reason:
              'the replayed payload must be EXACTLY the rules-legal key set '
              "(kitchen/manager/delivery hasOnly clauses) — 'id' is UNCHANGED "
              'vs the stored doc so it never appears in affectedKeys()',
        );
        expect(call.data['status'], 'delivered');
        expect(
          call.data['updatedAt'],
          isA<FieldValue>(),
          reason: 'the queue stamps updatedAt with a serverTimestamp sentinel',
        );

        final afterReplay = await isar.isarPendingOperations.where().findAll();
        expect(
          afterReplay,
          isEmpty,
          reason: 'a successful replay removes the op',
        );
      },
    );
    test(
      'T-2: kitchen status-update payload replays as set(merge:true) on orders/{id}',
      () async {
        await queue.enqueue(
          'update',
          'orders',
          buildKitchenStatusUpdatePayload('sq-r2', 'preparing'),
        );

        await queue.processQueue();

        final call = writer.setCalls.single;
        expect(call.collectionName, 'orders');
        expect(call.id, 'sq-r2');
        expect(call.options!.merge, isTrue);
        expect(call.data.keys.toSet(), {'id', 'status', 'updatedAt'});
        expect(call.data['status'], 'preparing');
      },
    );

    test(
      'T-2: delivery claim payload replays as set(merge:true) on orders/{id}',
      () async {
        await queue.enqueue(
          'update',
          'orders',
          buildDeliveryClaimPayload('sq-r3', 'driver-uid'),
        );

        await queue.processQueue();

        final call = writer.setCalls.single;
        expect(call.collectionName, 'orders');
        expect(call.id, 'sq-r3');
        expect(call.options!.merge, isTrue);
        expect(call.data.keys.toSet(), {
          'id',
          'assignedDriverId',
          'status',
          'updatedAt',
        });
        expect(call.data['assignedDriverId'], 'driver-uid');
        expect(call.data['status'], 'pickedUp');
      },
    );

    test(
      'T-2: proof-of-delivery payload survives the Isar JSON round-trip and replays as set(merge:true)',
      () async {
        await queue.enqueue(
          'update',
          'orders',
          buildProofOfDeliveryPayload(
            orderId: 'sq-r4',
            downloadUrl: 'https://storage.example/pod.jpg',
            driverId: 'driver-uid',
            capturedAt: DateTime.parse('2026-01-01T00:00:00.000'),
          ),
        );

        await queue.processQueue();

        final call = writer.setCalls.single;
        expect(call.collectionName, 'orders');
        expect(call.id, 'sq-r4');
        expect(call.options!.merge, isTrue);
        expect(call.data.keys.toSet(), {
          'id',
          'status',
          'proofOfDelivery',
          'updatedAt',
        });
        expect(call.data['status'], 'delivered');
        final pod = call.data['proofOfDelivery'] as Map<String, dynamic>;
        expect(pod['url'], 'https://storage.example/pod.jpg');
        expect(pod['uploadedBy'], 'driver-uid');
        expect(pod['capturedAt'], '2026-01-01T00:00:00.000');
      },
    );
  });
}
