import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('KitchenService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late RecordingSyncQueue syncQueue;
    late KitchenService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      syncQueue = RecordingSyncQueue();
      service = KitchenService(
        firestore: fakeFirestore,
        logger: LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
        syncQueue: syncQueue,
        tenantClaim: const FixedTenantClaim(),
      );
    });

    group('streamOrders', () {
      test('returns empty stream when no orders exist', () async {
        final orders = await service.streamOrders('branch1', [
          'confirmed',
        ]).first;
        expect(orders, isEmpty);
      });

      test('returns only orders matching branchId and statuses', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'preparing',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 1)),
          'totalCents': 2000,
          'items': [],
        });
        // Wrong status (ready) - should NOT appear
        await fakeFirestore.collection('orders').doc('o3').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'ready',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 2)),
          'totalCents': 3000,
          'items': [],
        });
        // Wrong branch - should NOT appear
        await fakeFirestore.collection('orders').doc('o4').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch2',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 3)),
          'totalCents': 4000,
          'items': [],
        });

        final orders = await service.streamOrders('branch1', [
          'confirmed',
          'preparing',
        ]).first;
        expect(orders.length, 2);
        expect(orders.any((o) => o.id == 'o1'), isTrue);
        expect(orders.any((o) => o.id == 'o2'), isTrue);
        expect(orders.any((o) => o.id == 'o3'), isFalse);
        expect(orders.any((o) => o.id == 'o4'), isFalse);
      });

      test('returns orders ordered by createdAt ascending', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 2)),
          'totalCents': 2000,
          'items': [],
        });
        await fakeFirestore.collection('orders').doc('o3').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 1)),
          'totalCents': 3000,
          'items': [],
        });

        final orders = await service.streamOrders('branch1', [
          'confirmed',
        ]).first;
        expect(orders.length, 3);
        // Should be ordered by createdAt ascending: o1, o3, o2
        expect(orders[0].id, 'o1');
        expect(orders[1].id, 'o3');
        expect(orders[2].id, 'o2');
      });

      test(
        'returns empty when status list does not match any orders',
        () async {
          await fakeFirestore.collection('orders').doc('o1').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });

          final orders = await service.streamOrders('branch1', [
            'confirmed',
            'preparing',
          ]).first;
          expect(orders, isEmpty);
        },
      );

      test('handles orders with items correctly', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1500,
          'items': [
            {
              'item': {
                'id': 'item1',
                'name': 'Burger',
                'priceCents': 800,
                'categoryId': 'cat1',
              },
              'quantity': 2,
              'modifiers': [],
            },
            {
              'item': {
                'id': 'item2',
                'name': 'Fries',
                'priceCents': 400,
                'categoryId': 'cat1',
              },
              'quantity': 1,
              'modifiers': [],
            },
          ],
        });

        final orders = await service.streamOrders('branch1', [
          'confirmed',
        ]).first;
        expect(orders.length, 1);
        expect(orders.first.items.length, 2);
        expect(orders.first.items[0].item.name, 'Burger');
        expect(orders.first.items[0].quantity, 2);
        expect(orders.first.items[1].item.name, 'Fries');
      });
    });

    group('updateOrderStatus', () {
      test('updates order status and updatedAt', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });

        await service.updateOrderStatus('o1', OrderStatus.preparing);

        final doc = await fakeFirestore.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'preparing');
        expect(doc.data()!['updatedAt'], isNotNull);
      });

      test('updates status to ready', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'preparing',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });

        await service.updateOrderStatus('o1', OrderStatus.ready);

        final doc = await fakeFirestore.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'ready');
      });

      test('throws FirebaseException when order does not exist', () async {
        expect(
          () => service.updateOrderStatus('nonexistent', OrderStatus.preparing),
          throwsA(isA<FirebaseException>()),
        );
      });

      test('preserves other fields when updating status', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 2500,
          'items': [
            {
              'item': {
                'id': 'item3',
                'name': 'Pizza',
                'priceCents': 1200,
                'categoryId': 'cat1',
              },
              'quantity': 1,
              'modifiers': [],
            },
          ],
          'customerId': 'cust123',
        });

        await service.updateOrderStatus('o1', OrderStatus.preparing);

        final doc = await fakeFirestore.collection('orders').doc('o1').get();
        expect(doc.data()!['status'], 'preparing');
        expect(doc.data()!['branchId'], 'branch1');
        expect(doc.data()!['totalCents'], 2500);
        expect(doc.data()!['customerId'], 'cust123');
      });
    });

    group('updateOrderStatus — W8.3 transition guard (T-3)', () {
      test(
        'delivered -> pickedUp is rejected fail-closed; document unchanged',
        () async {
          await fakeFirestore.collection('orders').doc('o-dead').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });

          await expectLater(
            service.updateOrderStatus('o-dead', OrderStatus.pickedUp),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'Invalid status transition: delivered -> pickedUp',
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
        },
      );

      test(
        'legal pending -> confirmed transition writes status + updatedAt',
        () async {
          await fakeFirestore.collection('orders').doc('o-new').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'pending',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });

          await service.updateOrderStatus('o-new', OrderStatus.confirmed);

          final doc = await fakeFirestore
              .collection('orders')
              .doc('o-new')
              .get();
          expect(doc.data()!['status'], 'confirmed');
          expect(doc.data()!['updatedAt'], isNotNull);
        },
      );

      test(
        'legacy cooking order can still reach ready (alias of preparing)',
        () async {
          await fakeFirestore.collection('orders').doc('o-legacy').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'cooking',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });

          await service.updateOrderStatus('o-legacy', OrderStatus.ready);

          final doc = await fakeFirestore
              .collection('orders')
              .doc('o-legacy')
              .get();
          expect(doc.data()!['status'], 'ready');
        },
      );

      test('same-status rewrite is rejected (no redundant writes)', () async {
        await fakeFirestore.collection('orders').doc('o-same').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'preparing',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });

        await expectLater(
          service.updateOrderStatus('o-same', OrderStatus.preparing),
          throwsA(
            predicate(
              (e) => e.toString().contains('Invalid status transition'),
            ),
          ),
        );
        final doc = await fakeFirestore
            .collection('orders')
            .doc('o-same')
            .get();
        expect(doc.data()!['status'], 'preparing');
      });

      test(
        'violation error maps to a user-facing message (mapped error)',
        () async {
          await fakeFirestore.collection('orders').doc('o-map').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });

          Object? caught;
          try {
            await service.updateOrderStatus('o-map', OrderStatus.pickedUp);
          } catch (e) {
            caught = e;
          }
          expect(caught, isNotNull);
          expect(
            FirebaseExceptionMapper.map(caught!),
            isNotEmpty,
            reason:
                'the UI snackbar surface (FirebaseExceptionMapper.map) must '
                'render a non-empty message for the mapped error',
          );
        },
      );
    });

    group('STAFF-QUEUE (W5.4) — queued status writes', () {
      late RecordingFakeFirestore recordingFirestore;
      late RecordingSyncQueue recordingQueue;
      late List<String> timeline;
      late KitchenService queuedService;

      setUp(() {
        timeline = <String>[];
        // One merged call-order timeline across the queue double and the
        // Firestore double — the T-1 enqueue-before-write proof surface.
        recordingQueue = RecordingSyncQueue(events: timeline);
        recordingFirestore = RecordingFakeFirestore(events: timeline);

        queuedService = KitchenService(
          firestore: recordingFirestore,
          logger: LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
          syncQueue: recordingQueue,
          tenantClaim: const FixedTenantClaim(),
        );
      });

      Future<void> seedConfirmedOrder(String orderId) async {
        await recordingFirestore.collection('orders').doc(orderId).set({
          'tenantId': 'tenant_a',
          'branchId': 'branch1',
          'status': 'confirmed',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
          'totalCents': 1000,
          'items': [],
        });
        timeline.clear();
      }

      test(
        'T-1: updateOrderStatus enqueues the update op BEFORE the Firestore write',
        () async {
          await seedConfirmedOrder('sq-o1');

          await queuedService.updateOrderStatus('sq-o1', OrderStatus.preparing);

          expect(
            timeline.indexOf('enqueue:update:sq-o1'),
            greaterThan(timeline.indexOf('collection:orders')),
            reason:
                'STAFF-QUEUE: the pre-flight transition read must precede '
                'the enqueue (fail-closed before any durable side effect)',
          );
          expect(
            timeline.indexOf('enqueue:update:sq-o1'),
            lessThan(timeline.lastIndexOf('write:runTransaction')),
            reason:
                'T-1: the update op must be durably enqueued BEFORE the '
                'Firestore write so a killed write stays replayable',
          );
          expect(
            timeline.last,
            'remove:update:sq-o1',
            reason: 'T-4: on success the op is removed last',
          );
          expect(
            recordingQueue.enqueuedPayloads.single,
            {'id': 'sq-o1', 'status': 'preparing'},
            reason:
                'the replay payload must be EXACTLY the rules-legal '
                '{id, status} pair (queue stamps updatedAt on replay)',
          );
        },
      );

      test(
        'T-4: queue is empty after a successful write (op removed)',
        () async {
          await seedConfirmedOrder('sq-t4');

          await queuedService.updateOrderStatus('sq-t4', OrderStatus.preparing);

          expect(
            recordingQueue.pendingPayloads,
            isEmpty,
            reason:
                'T-4: the pending op must be removed once the write commits — '
                'no duplicate replay can resurrect it',
          );
          final doc = await recordingFirestore
              .collection('orders')
              .doc('sq-t4')
              .get();
          expect(doc.data()!['status'], 'preparing');
        },
      );

      test(
        'invalid transition leaves NO pending op (pre-flight guard precedes enqueue)',
        () async {
          await recordingFirestore.collection('orders').doc('sq-dead').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
            'totalCents': 1000,
            'items': [],
          });
          timeline.clear();

          await expectLater(
            queuedService.updateOrderStatus('sq-dead', OrderStatus.preparing),
            throwsA(
              predicate(
                (e) =>
                    e.toString().contains('Invalid status transition') &&
                    e.toString().contains('delivered -> preparing'),
              ),
            ),
          );
          expect(
            recordingQueue.enqueuedPayloads,
            isEmpty,
            reason:
                'a business-invalid request must NEVER leave a pending op — '
                'a later replay could otherwise apply it out-of-band',
          );
        },
      );

      test(
        'missing order leaves NO pending op (not-found precedes enqueue)',
        () async {
          timeline.clear();

          await expectLater(
            queuedService.updateOrderStatus(
              'sq-missing',
              OrderStatus.preparing,
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
    });

    group('streamOrders — W8.7 cap (T-2)', () {
      test('caps the live stream at kKitchenOrdersStreamCap (200)', () async {
        const overCap = kKitchenOrdersStreamCap + 10;
        for (var i = 0; i < overCap; i++) {
          await fakeFirestore.collection('orders').doc('cap-o$i').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch1',
            'status': 'confirmed',
            'createdAt': Timestamp.fromDate(
              DateTime(2024, 1, 1).add(Duration(minutes: i)),
            ),
            'totalCents': 1000,
            'items': [],
          });
        }

        final orders = await service.streamOrders('branch1', [
          'confirmed',
        ]).first;

        expect(
          orders.length,
          kKitchenOrdersStreamCap,
          reason: 'W8.7: the kitchen FIFO stream must be hard-capped',
        );
        // FIFO semantics preserved: the cap keeps the OLDEST 200 docs
        // (ascending createdAt), truncating the newest tail.
        expect(orders.first.id, 'cap-o0');
        expect(orders.last.id, 'cap-o${kKitchenOrdersStreamCap - 1}');
      });
    });
  });
}
