import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import '../../support/tenant_claim_fakes.dart';

/// COV-1 — STAFF-QUEUE integration for the KITCHEN mutation path (the
/// batch-spec gap "queue-replay integration").
///
/// Proves the complete flaky-write loop END TO END inside the kitchen
/// territory: a Firestore status transaction killed by a flaky network leaves
/// the mutation durable in a REAL `IsarSyncQueue` (enqueued BEFORE the write),
/// and `processQueue()` replays it as the rules-legal merge-set that lands in
/// Firestore without clobbering the other order fields. The recording-writer
/// replay proof for other staff surfaces belongs to the admin/domain suite;
/// here the REAL queue + REAL writer are wired against a REAL FakeFirestore
/// so the replayed document itself is the assertion surface.

/// Flaky-network Firestore: reads and pre-flights work; the status
/// TRANSACTION dies with `unavailable` the first time (the exact
/// 02-P1-STAFF failure), then heals so a later replay can land.
class _FlakyTransactionFirestore extends FakeFirebaseFirestore {
  bool _failNextTransaction;

  _FlakyTransactionFirestore({bool failFirstTransaction = true})
    : _failNextTransaction = failFirstTransaction;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    if (_failNextTransaction) {
      _failNextTransaction = false;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      );
    }
    return super.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

class _SilentLogger extends LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {}
}

Future<({Isar isar, Directory dir})> _openTempIsar() async {
  final dir = Directory.systemTemp.createTempSync('kitchen_flaky_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  return (isar: isar, dir: dir);
}

Map<String, dynamic> _confirmedOrderDoc(String id, String branchId) => {
  'branchId': branchId,
  'status': 'confirmed',
  'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, 0)),
  'totalCents': 1500,
  'items': [],
  'userId': 'cust-1',
};

void main() {
  setUpAll(() async {
    await ensureIsarCoreForTests();
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('KitchenService — STAFF-QUEUE replay on flaky write (COV-1)', () {
    late Isar isar;
    late Directory dir;
    late _FlakyTransactionFirestore fakeFirestore;

    setUp(() async {
      final h = await _openTempIsar();
      isar = h.isar;
      dir = h.dir;
      fakeFirestore = _FlakyTransactionFirestore();
      await fakeFirestore
          .collection('orders')
          .doc('kq-1')
          .set(_confirmedOrderDoc('kq-1', 'branch-1'));
    });

    tearDown(() async {
      await isar.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    KitchenService buildService(SyncQueue queue) => KitchenService(
      firestore: fakeFirestore,
      logger: _SilentLogger(),
      syncQueue: queue,
      tenantClaim: const FixedTenantClaim(),
    );

    test(
      'a flaky status write stays durable in the queue and processQueue() lands it in Firestore',
      () async {
        final queue = IsarSyncQueue(
          IsarService.forTesting(Future.value(isar), _SilentLogger()),
          _SilentLogger(),
          firestore: FirestoreQueueWriter(fakeFirestore),
        );
        final service = buildService(queue);

        // The Firestore transaction dies with `unavailable`; the service
        // rethrows (fail-closed UI) but the op was enqueued BEFORE the write.
        await expectLater(
          service.updateOrderStatus('kq-1', OrderStatus.preparing),
          throwsA(isA<FirebaseException>()),
        );

        // Durability: the exact rules-legal payload sits in the REAL queue.
        final pending = await isar.isarPendingOperations.where().findAll();
        expect(pending, hasLength(1));
        expect(pending.first.operation, 'update');
        expect(pending.first.collectionName, 'orders');
        final decoded =
            jsonDecode(pending.first.dataString) as Map<String, dynamic>;
        expect(decoded, {'id': 'kq-1', 'status': 'preparing'});

        // Replay: the queue merge-sets the payload onto orders/kq-1 through
        // the REAL FirestoreQueueWriter, stamping updatedAt server-side.
        await queue.processQueue();

        expect(
          await isar.isarPendingOperations.count(),
          0,
          reason:
              'a successful replay removes the pending op — no duplicate replay',
        );

        final doc = await fakeFirestore.collection('orders').doc('kq-1').get();
        expect(
          doc.data()!['status'],
          'preparing',
          reason: 'the killed write is healed by the replay',
        );
        expect(
          doc.data()!['branchId'],
          'branch-1',
          reason: 'the replay is a MERGE — sibling fields must be preserved',
        );
        expect(doc.data()!['totalCents'], 1500);
      },
    );

    test(
      'a healthy write removes the queued op — no residue to replay later',
      () async {
        // Transaction now succeeds (default double does not fail).
        fakeFirestore = _FlakyTransactionFirestore(failFirstTransaction: false);
        await fakeFirestore
            .collection('orders')
            .doc('kq-1')
            .set(_confirmedOrderDoc('kq-1', 'branch-1'));

        final queue = IsarSyncQueue(
          IsarService.forTesting(Future.value(isar), _SilentLogger()),
          _SilentLogger(),
          firestore: FirestoreQueueWriter(fakeFirestore),
        );
        final service = buildService(queue);

        await service.updateOrderStatus('kq-1', OrderStatus.preparing);

        expect(
          await isar.isarPendingOperations.count(),
          0,
          reason:
              'success removes the op — an offline replay must never be double-applied',
        );
        final doc = await fakeFirestore.collection('orders').doc('kq-1').get();
        expect(doc.data()!['status'], 'preparing');
      },
    );
  });
}
