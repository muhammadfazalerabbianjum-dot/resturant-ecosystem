import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:core/core.dart';
import 'dart:io';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// Fake [DriverLocationService] that records calls for verification.
class FakeDriverLocationService extends DriverLocationService {
  bool _tracking = false;
  String? _trackedOrderId;
  bool _stopped = false;

  FakeDriverLocationService()
    : super(
        FakeFirebaseFirestore(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<void> startTracking(String orderId) async {
    _tracking = true;
    _trackedOrderId = orderId;
  }

  @override
  Future<void> stopTracking() async {
    _stopped = true;
    _tracking = false;
  }

  bool get isTracking => _tracking;
  String? get trackedOrderId => _trackedOrderId;
  bool get isStopped => _stopped;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('DeliveryService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeDriverLocationService fakeLocationService;
    late RecordingSyncQueue syncQueue;
    late DeliveryService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeLocationService = FakeDriverLocationService();
      syncQueue = RecordingSyncQueue();
      service = DeliveryService(
        firestore: fakeFirestore,
        locationService: fakeLocationService,
        logger: LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
        syncQueue: syncQueue,
        tenantClaim: const FixedTenantClaim(),
      );
    });

    group('myOrders', () {
      test('returns empty stream when no orders assigned', () async {
        final orders = await service.myOrders('driver1', 'branch1').first;
        expect(orders, isEmpty);
      });

      test('returns only ready/pickedUp orders for the driver', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'assignedDriverId': 'driver1',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'assignedDriverId': 'driver1',
          'status': 'pickedUp',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 1)),
          'totalCents': 2000,
          'items': [],
        });
        // This one should NOT appear (status is 'delivered')
        await fakeFirestore.collection('orders').doc('o3').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'assignedDriverId': 'driver1',
          'status': 'delivered',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 2)),
          'totalCents': 3000,
          'items': [],
        });

        final orders = await service.myOrders('driver1', 'branch1').first;
        expect(orders.length, 2);
        expect(orders.any((o) => o.id == 'o3'), isFalse);
      });

      test('ignores orders assigned to other drivers', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'assignedDriverId': 'driver2',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });

        final orders = await service.myOrders('driver1', 'branch1').first;
        expect(orders, isEmpty);
      });
    });

    group('availableOrders', () {
      test('returns empty stream when no ready orders', () async {
        final orders = await service.availableOrders('branch1').first;
        expect(orders, isEmpty);
      });

      test('returns only unassigned ready orders for the branch', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        // Already assigned - should NOT appear
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 1)),
          'totalCents': 2000,
          'items': [],
          'assignedDriverId': 'driver2',
        });
        // Wrong branch
        await fakeFirestore.collection('orders').doc('o3').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch2',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 2)),
          'totalCents': 3000,
          'items': [],
        });

        final orders = await service.availableOrders('branch1').first;
        expect(orders.length, 1);
        expect(orders.first.id, 'o1');
      });
    });

    group('markDelivered', () {
      test('updates order status and stops GPS tracking', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'status': 'pickedUp',
          'updatedAt': null,
          'totalCents': 1000,
          'items': [],
        });

        await service.markDelivered('o1');

        final doc = await fakeFirestore.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'delivered');
        expect(fakeLocationService.isStopped, isTrue);
      });

      test('throws when order does not exist', () async {
        expect(
          () => service.markDelivered('nonexistent'),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('assignToMe', () {
      test('assigns unassigned order to driver', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'status': 'ready',
          'totalCents': 1000,
          'items': [],
        });

        await service.assignToMe('o1', 'driver1');

        final doc = await fakeFirestore.collection('orders').doc('o1').get();
        expect(doc.data()!['assignedDriverId'], 'driver1');
        expect(doc.data()!['status'], 'pickedUp');
      });

      test('throws when order is already assigned', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'status': 'ready',
          'totalCents': 1000,
          'items': [],
          'assignedDriverId': 'driver2',
        });

        expect(
          () => service.assignToMe('o1', 'driver1'),
          throwsA(
            predicate(
              (e) =>
                  e is Exception && e.toString().contains('already assigned'),
            ),
          ),
        );
      });

      test('throws when order does not exist', () async {
        expect(
          () => service.assignToMe('nonexistent', 'driver1'),
          throwsA(
            predicate(
              (e) => e is Exception && e.toString().contains('Order not found'),
            ),
          ),
        );
      });
    });

    group('GPS tracking delegation', () {
      test('startGpsTracking delegates to location service', () async {
        await service.startGpsTracking('o1');
        expect(fakeLocationService.isTracking, isTrue);
        expect(fakeLocationService.trackedOrderId, 'o1');
      });

      test('stopGpsTracking delegates to location service', () async {
        await service.stopGpsTracking();
        expect(fakeLocationService.isStopped, isTrue);
      });
    });

    group('markDelivered — W8.3 transition guard (T-3)', () {
      test(
        'delivered -> delivered re-delivery is rejected; GPS keeps running',
        () async {
          await fakeFirestore.collection('orders').doc('o-dead').set({
            'tenantId': 'tenant_a',
            'status': 'delivered',
            'totalCents': 1000,
            'items': [],
            'assignedDriverId': 'driver1',
          });

          await expectLater(
            service.markDelivered('o-dead'),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'Invalid status transition: delivered -> delivered',
                ),
              ),
            ),
          );

          final doc = await fakeFirestore
              .collection('orders')
              .doc('o-dead')
              .get();
          expect(
            doc.data()!['status'],
            'delivered',
            reason: 'fail-closed: the rejected write must not land',
          );
          expect(
            fakeLocationService.isStopped,
            isFalse,
            reason:
                'GPS must keep running when the delivered write is rejected',
          );
        },
      );

      test('ready order cannot jump straight to delivered', () async {
        await fakeFirestore.collection('orders').doc('o-ready').set({
          'tenantId': 'tenant_a',
          'status': 'ready',
          'totalCents': 1000,
          'items': [],
          'assignedDriverId': 'driver1',
        });

        await expectLater(
          service.markDelivered('o-ready'),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'Invalid status transition: ready -> delivered',
              ),
            ),
          ),
        );
        final doc = await fakeFirestore
            .collection('orders')
            .doc('o-ready')
            .get();
        expect(doc.data()!['status'], 'ready');
      });
    });

    group('W8.7 caps (T-2)', () {
      test('myOrders caps at kDriverOrdersStreamCap (100)', () async {
        const overCap = kDriverOrdersStreamCap + 10;
        for (var i = 0; i < overCap; i++) {
          await fakeFirestore.collection('orders').doc('my-o$i').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'assignedDriverId': 'driver1',
            'status': i.isEven ? 'ready' : 'pickedUp',
            'createdAt': Timestamp.fromDate(
              DateTime(2024, 1, 1).add(Duration(minutes: i)),
            ),
            'totalCents': 1000,
            'items': [],
          });
        }

        final orders = await service.myOrders('driver1', 'branch1').first;
        expect(
          orders.length,
          kDriverOrdersStreamCap,
          reason: 'W8.7: the driver my-orders stream must be hard-capped',
        );
      });

      test('availableOrders caps at kDriverOrdersStreamCap (100)', () async {
        const overCap = kDriverOrdersStreamCap + 10;
        for (var i = 0; i < overCap; i++) {
          await fakeFirestore.collection('orders').doc('av-o$i').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'ready',
            'createdAt': Timestamp.fromDate(
              DateTime(2024, 1, 1).add(Duration(minutes: i)),
            ),
            'totalCents': 1000,
            'items': [],
          });
        }

        final orders = await service.availableOrders('branch1').first;
        expect(
          orders.length,
          kDriverOrdersStreamCap,
          reason: 'W8.7: the available-orders stream must be hard-capped',
        );
        // Client-side unassigned filter preserved alongside the cap.
        expect(orders.every((o) => o.assignedDriverId == null), isTrue);
      });
    });

    group('STAFF-QUEUE (W5.4) — queued delivery writes', () {
      late RecordingFakeFirestore recordingFirestore;
      late RecordingSyncQueue recordingQueue;
      late List<String> timeline;
      late DeliveryService queuedService;

      setUp(() {
        timeline = <String>[];
        // One merged call-order timeline across the queue double and the
        // Firestore double — the T-1 enqueue-before-write proof surface.
        recordingQueue = RecordingSyncQueue(events: timeline);
        recordingFirestore = RecordingFakeFirestore(events: timeline);
        queuedService = DeliveryService(
          firestore: recordingFirestore,
          locationService: fakeLocationService,
          logger: LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
          syncQueue: recordingQueue,
          tenantClaim: const FixedTenantClaim(),
        );
      });

      Future<void> seedOrder(
        String orderId, {
        required String status,
        String? assignedDriverId,
      }) async {
        await recordingFirestore.collection('orders').doc(orderId).set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': status,
          if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        timeline.clear();
      }

      test(
        'T-1: markDelivered enqueues the update op BEFORE the Firestore write',
        () async {
          await seedOrder(
            'sq-md',
            status: 'pickedUp',
            assignedDriverId: 'driver1',
          );

          await queuedService.markDelivered('sq-md');

          expect(
            timeline.indexOf('enqueue:update:sq-md'),
            greaterThan(timeline.indexOf('collection:orders')),
            reason:
                'STAFF-QUEUE: the pre-flight transition read must precede '
                'the enqueue (fail-closed before any durable side effect)',
          );
          expect(
            timeline.indexOf('enqueue:update:sq-md'),
            lessThan(timeline.lastIndexOf('write:runTransaction')),
            reason:
                'T-1: the delivered op must be durably enqueued BEFORE the '
                'Firestore write so a killed write stays replayable',
          );
          expect(
            timeline.last,
            'remove:update:sq-md',
            reason: 'T-4: on success the op is removed last (before GPS stop)',
          );
          expect(
            recordingQueue.enqueuedPayloads.single,
            {'id': 'sq-md', 'status': 'delivered'},
            reason:
                'the replay payload must be EXACTLY the rules-legal '
                '{id, status} pair (queue stamps updatedAt on replay)',
          );
          expect(fakeLocationService.isStopped, isTrue);
        },
      );

      test(
        'T-1/T-4: assignToMe enqueues the claim op before the write and removes it on success',
        () async {
          await seedOrder('sq-claim', status: 'ready');

          await queuedService.assignToMe('sq-claim', 'driver1');

          expect(
            timeline.indexOf('enqueue:update:sq-claim'),
            lessThan(timeline.lastIndexOf('write:runTransaction')),
            reason: 'T-1: the claim op must be enqueued BEFORE the write',
          );
          expect(
            timeline.last,
            'remove:update:sq-claim',
            reason: 'T-4: on success the op is removed last',
          );
          expect(
            recordingQueue.enqueuedPayloads.single,
            {
              'id': 'sq-claim',
              'assignedDriverId': 'driver1',
              'status': 'pickedUp',
            },
            reason:
                'the claim replay payload must be EXACTLY the rules-legal '
                'claim shape (firestore.rules:420-423)',
          );
          final doc = await recordingFirestore
              .collection('orders')
              .doc('sq-claim')
              .get();
          expect(doc.data()!['status'], 'pickedUp');
          expect(doc.data()!['assignedDriverId'], 'driver1');
          expect(recordingQueue.pendingPayloads, isEmpty);
        },
      );

      test('T-4: queue is empty after a successful markDelivered', () async {
        await seedOrder(
          'sq-t4',
          status: 'pickedUp',
          assignedDriverId: 'driver1',
        );

        await queuedService.markDelivered('sq-t4');

        expect(
          recordingQueue.pendingPayloads,
          isEmpty,
          reason: 'T-4: the pending op must be removed once the write commits',
        );
        final doc = await recordingFirestore
            .collection('orders')
            .doc('sq-t4')
            .get();
        expect(doc.data()!['status'], 'delivered');
      });

      test(
        'invalid delivered transition leaves NO pending op (pre-flight guard precedes enqueue)',
        () async {
          await seedOrder('sq-dead', status: 'ready', assignedDriverId: 'd2');

          await expectLater(
            queuedService.markDelivered('sq-dead'),
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
                'the delivery rules window (pre ∈ {ready, pickedUp} -> '
                '{pickedUp, delivered}) would otherwise let a replay apply '
                'the ready -> delivered jump out-of-band',
          );
          expect(
            fakeLocationService.isStopped,
            isFalse,
            reason: 'GPS must keep running when the write is rejected',
          );
        },
      );

      test(
        'already-assigned claim leaves NO pending op (pre-flight guard precedes enqueue)',
        () async {
          await seedOrder(
            'sq-taken',
            status: 'ready',
            assignedDriverId: 'other-driver',
          );

          await expectLater(
            queuedService.assignToMe('sq-taken', 'driver1'),
            throwsA(
              predicate((e) => e.toString().contains('already assigned')),
            ),
          );
          expect(
            recordingQueue.enqueuedPayloads,
            isEmpty,
            reason: 'a claim that can never land must never be queued',
          );
        },
      );
    });
  });
}
