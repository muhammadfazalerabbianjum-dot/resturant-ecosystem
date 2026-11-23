// P9 W1 (T-1) — seats-on-cancel: the compensating capacity decrement.
//
// B-1 (PERF-8 W4): the reservation capacity counter is monotonic at HEAD —
// requestSlot increments `booked` and NOTHING ever releases seats, so a
// cancelled reservation permanently eats capacity. The fix (spec §3 T-1,
// design FIXED): a `cancelReservation` transition at the single chokepoint
// that owns transitions (ReservationsRepository — the only writer of
// `reservations` + `reservation_counters`), which decrements the counter in
// the SAME Firestore transaction as the `pending→cancelled` status write,
// guarded by a status precondition so retries cannot double-decrement, and
// clamped at ≥0 so counter drift can never mint phantom negative capacity.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';

import '../../../helpers/test_helpers.dart';

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
final String _counterId = 'branch1_${_slot.millisecondsSinceEpoch}';

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

Future<int> _booked(FakeFirebaseFirestore firestore) async {
  final doc = await firestore
      .collection('reservation_counters')
      .doc(_counterId)
      .get();
  return (doc.data()?['booked'] as num?)?.toInt() ?? 0;
}

void main() {
  group('ReservationsRepository.cancelReservation — seats are released (T-1)', () {
    test(
      'the spec red proof: book 2 parties, cancel 1, the slot capacity returns',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());

        final first = await repository.requestSlot(
          _reservation(),
          10,
          tenantId: 'tenant_a',
        );
        final second = await repository.requestSlot(
          _reservation(id: 'res2', userId: 'user2'),
          10,
          tenantId: 'tenant_a',
        );
        expect(first, isTrue);
        expect(second, isTrue);
        expect(await repository.getAvailableCapacity('branch1', _slot, 10), 2);

        final cancelled = await repository.cancelReservation('res1');

        expect(cancelled, isTrue);
        expect(
          await repository.getAvailableCapacity('branch1', _slot, 10),
          6,
          reason:
              'B-1: the compensating decrement must return the cancelled '
              "party's seats to the slot in the same transaction as the "
              'status transition',
        );
      },
    );
    test(
      'the cancelled document carries status=cancelled + cancelledAt',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());
        await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');

        await repository.cancelReservation('res1');

        final doc = await firestore
            .collection('reservations')
            .doc('res1')
            .get();
        expect(doc.data()?['status'], 'cancelled');
        expect(doc.data()?['cancelledAt'], isA<Timestamp>());
      },
    );

    test(
      'a retry cannot double-decrement (status precondition guard)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());
        await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');

        expect(await repository.cancelReservation('res1'), isTrue);
        expect(await repository.cancelReservation('res1'), isFalse);

        expect(
          await _booked(firestore),
          0,
          reason:
              'the second cancel must be refused by the status guard — '
              'exactly one decrement per reservation, ever',
        );
      },
    );

    test(
      'a drifted counter is clamped at 0 — drift can never go negative',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());
        await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');
        // Drift: an operator wiped the counter doc, but the reservation is live.
        await firestore.collection('reservation_counters').doc(_counterId).set({
          'booked': 0,
        });

        expect(await repository.cancelReservation('res1'), isTrue);

        expect(
          await _booked(firestore),
          0,
          reason:
              'the decrement is clamped — a drifted counter must never '
              'report negative booked (phantom capacity)',
        );
      },
    );

    test('a missing reservation is refused and writes nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ReservationsRepository(firestore, FakeLogger());
      await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');
      final before = await _booked(firestore);

      final result = await repository.cancelReservation('ghost');

      expect(result, isFalse);
      expect(await _booked(firestore), before);
    });

    test(
      'a terminal reservation (already completed) cannot be cancelled',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());
        await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');
        await firestore.collection('reservations').doc('res1').update({
          'status': 'completed',
        });
        final before = await _booked(firestore);

        final result = await repository.cancelReservation('res1');

        expect(result, isFalse);
        expect(await _booked(firestore), before);
        expect(
          (await firestore.collection('reservations').doc('res1').get())
              .data()?['status'],
          'completed',
          reason: 'a terminal document is never rewritten by a cancel attempt',
        );
      },
    );

    test(
      'a corrupt document (no partySize) is refused — fail-closed, no decrement',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = ReservationsRepository(firestore, FakeLogger());
        await repository.requestSlot(_reservation(), 50, tenantId: 'tenant_a');
        await firestore.collection('reservations').doc('res1').update({
          'partySize': FieldValue.delete(),
        });
        final before = await _booked(firestore);

        final result = await repository.cancelReservation('res1');

        expect(result, isFalse);
        expect(await _booked(firestore), before);
        expect(
          (await firestore.collection('reservations').doc('res1').get())
              .data()
              ?.containsKey('status'),
          isFalse,
          reason:
              'cancelled ⇒ seats released is atomic: a cancel that cannot '
              'compute its compensating decrement must not transition the doc',
        );
      },
    );

    test(
      'a transaction failure returns false and logs (fail-closed)',
      () async {
        final logger = FakeLogger();
        final repository = ReservationsRepository(
          _FailingTransactionFirestore(),
          logger,
        );

        final result = await repository.cancelReservation('res1');

        expect(result, isFalse);
        expect(logger.loggedErrors, contains('cancelReservation failed'));
      },
    );
  });
}
