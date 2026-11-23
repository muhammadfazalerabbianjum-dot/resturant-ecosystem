// P8 W4 (A-4) — ReservationsRepository data-layer pins: the capacity counter
// is the only thing standing between two concurrent parties and an over-booked
// slot, so every rejection path must be fail-closed AND write nothing.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';

import '../../../helpers/test_helpers.dart';

/// Firestore double whose collection lookups always fail (offline client).
class _UnavailableFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'client is offline',
    );
  }
}

/// Firestore double whose transactions always fail (write rejected mid-flight).
class _FailingTransactionFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'client is offline',
    );
  }
}

final DateTime _slot = DateTime(2026, 7, 24, 18);

ReservationModel _reservation({
  String id = 'res1',
  String userId = 'user1',
  String branchId = 'branch1',
  int partySize = 4,
  DateTime? startTime,
}) => ReservationModel(
  id: id,
  userId: userId,
  branchId: branchId,
  customerName: 'Ada',
  customerPhone: '555-0101',
  startTime: startTime ?? _slot,
  partySize: partySize,
);

Future<int> _writtenDocs(FakeFirebaseFirestore firestore) async {
  final counters =
      (await firestore.collection('reservation_counters').get()).docs.length;
  final locks =
      (await firestore.collection('reservation_locks').get()).docs.length;
  final reservations =
      (await firestore.collection('reservations').get()).docs.length;
  return counters + locks + reservations;
}

void main() {
  group('ReservationsRepository.requestSlot — malformed bookings', () {
    test('a party size of zero is rejected and nothing is written', () async {
      final firestore = FakeFirebaseFirestore();
      final logger = FakeLogger();
      final repository = ReservationsRepository(firestore, logger);

      final result = await repository.requestSlot(
        _reservation(partySize: 0),
        50,
        tenantId: 'tenant_a',
      );

      expect(result, isFalse);
      expect(
        await _writtenDocs(firestore),
        0,
        reason:
            'P8-W4 F3: a rejected booking must leave no counter, lock or '
            'reservation document behind',
      );
      expect(
        logger.loggedErrors,
        contains('requestSlot rejected a non-positive party size'),
      );
    });

    test('a negative party size is rejected — it would decrement the capacity '
        'counter and mint phantom seats for the next party', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ReservationsRepository(firestore, FakeLogger());

      final result = await repository.requestSlot(
        _reservation(partySize: -5),
        50,
        tenantId: 'tenant_a',
      );

      expect(result, isFalse);
      expect(await _writtenDocs(firestore), 0);
    });

    test('a reservation with no branch id is rejected (Law 25) and nothing is '
        'written', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ReservationsRepository(firestore, FakeLogger());

      final result = await repository.requestSlot(
        _reservation(branchId: ''),
        50,
        tenantId: 'tenant_a',
      );

      expect(result, isFalse);
      expect(await _writtenDocs(firestore), 0);
    });
  });

  group('ReservationsRepository.requestSlot — capacity + lock integrity', () {
    test(
      'a party larger than the remaining capacity is rejected without taking '
      'the lock',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());

        final result = await repository.requestSlot(
          _reservation(partySize: 60),
          50,
          tenantId: 'tenant_a',
        );

        expect(result, isFalse);
        expect(await _writtenDocs(firestore), 0);
      },
    );

    test(
      'a second submit for the same user and slot is rejected and the counter '
      'is charged exactly once',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());

        final first = await repository.requestSlot(
          _reservation(),
          50,
          tenantId: 'tenant_a',
        );
        final second = await repository.requestSlot(
          _reservation(id: 'res2'),
          50,
          tenantId: 'tenant_a',
        );

        expect(first, isTrue);
        expect(second, isFalse);
        final counterId = 'branch1_${_slot.millisecondsSinceEpoch}';
        final counter = await firestore
            .collection('reservation_counters')
            .doc(counterId)
            .get();
        expect(counter.data()?['booked'], 4);
        expect(
          (await firestore.collection('reservations').get()).docs.length,
          1,
          reason: 'the rejected retry must not write a second reservation',
        );
      },
    );

    test('the accepted booking writes branchId, partySize and a Timestamp '
        'start time, and takes the per-user slot lock', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ReservationsRepository(firestore, FakeLogger());

      await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');

      final doc = await firestore.collection('reservations').doc('res1').get();
      expect(doc.data()?['branchId'], 'branch1');
      expect(doc.data()?['partySize'], 4);
      expect(doc.data()?['startTime'], isA<Timestamp>());
      final lockId = 'branch1_${_slot.millisecondsSinceEpoch}_user1';
      expect(
        (await firestore.collection('reservation_locks').doc(lockId).get())
            .exists,
        isTrue,
      );
    });
  });

  group('ReservationsRepository — failure paths are fail-closed', () {
    test(
      'requestSlot returns false and logs when the transaction fails',
      () async {
        final logger = FakeLogger();
        final repository = ReservationsRepository(
          _FailingTransactionFirestore(),
          logger,
        );

        final result = await repository.requestSlot(
          _reservation(),
          50,
          tenantId: 'tenant_a',
        );

        expect(result, isFalse);
        expect(logger.loggedErrors, contains('requestSlot failed'));
      },
    );

    test(
      'getAvailableCapacity rethrows a Firestore failure instead of reporting '
      'phantom capacity',
      () async {
        final logger = FakeLogger();
        final repository = ReservationsRepository(
          _UnavailableFirestore(),
          logger,
        );

        await expectLater(
          repository.getAvailableCapacity('branch1', _slot, 50),
          throwsA(isA<FirebaseException>()),
        );
        expect(
          logger.loggedErrors.single,
          contains('getAvailableCapacity failed'),
        );
      },
    );
  });
}
