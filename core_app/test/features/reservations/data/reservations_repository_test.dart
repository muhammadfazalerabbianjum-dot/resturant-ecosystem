import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/reservations/data/reservations_repository.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';

void main() {
  group('ReservationsRepository', () {
    late FakeFirebaseFirestore firestore;
    late ReservationsRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ReservationsRepository(
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
    });

    test(
      'getAvailableCapacity returns full capacity when no reservations',
      () async {
        final capacity = await repository.getAvailableCapacity(
          'branch1',
          DateTime(2026, 7, 24, 18, 0),
          50,
        );
        expect(capacity, 50);
      },
    );

    test(
      'getAvailableCapacity reduces capacity for existing reservations',
      () async {
        final counterId =
            'branch1_${DateTime(2026, 7, 24, 18, 0).millisecondsSinceEpoch}';
        await firestore.collection('reservation_counters').doc(counterId).set({
          'booked': 15,
        });

        final capacity = await repository.getAvailableCapacity(
          'branch1',
          DateTime(2026, 7, 24, 18, 0),
          50,
        );
        expect(capacity, 35);
      },
    );

    test('getAvailableCapacity clamps to 0 when over capacity', () async {
      final counterId =
          'branch1_${DateTime(2026, 7, 24, 18, 0).millisecondsSinceEpoch}';
      await firestore.collection('reservation_counters').doc(counterId).set({
        'booked': 60,
      });

      final capacity = await repository.getAvailableCapacity(
        'branch1',
        DateTime(2026, 7, 24, 18, 0),
        50,
      );
      expect(capacity, 0);
    });

    test('getAvailableCapacity ignores other branches', () async {
      final otherCounterId =
          'branch2_${DateTime(2026, 7, 24, 18, 0).millisecondsSinceEpoch}';
      await firestore
          .collection('reservation_counters')
          .doc(otherCounterId)
          .set({'booked': 100});

      final capacity = await repository.getAvailableCapacity(
        'branch1',
        DateTime(2026, 7, 24, 18, 0),
        50,
      );
      expect(capacity, 50);
    });

    test('getAvailableCapacity ignores other time slots', () async {
      final otherCounterId =
          'branch1_${DateTime(2026, 7, 24, 19, 0).millisecondsSinceEpoch}';
      await firestore
          .collection('reservation_counters')
          .doc(otherCounterId)
          .set({'booked': 40});

      final capacity = await repository.getAvailableCapacity(
        'branch1',
        DateTime(2026, 7, 24, 18, 0),
        50,
      );
      expect(capacity, 50);
    });

    test('requestSlot returns false when capacity is exceeded', () async {
      final reservation = ReservationModel(
        id: 'res1',
        userId: 'user1',
        customerName: 'John',
        customerPhone: '555-0100',
        startTime: DateTime(2026, 7, 24, 18, 0),
        partySize: 60,
        branchId: 'branch1',
      );

      final result = await repository.requestSlot(
        reservation,
        50,
        tenantId: 'tenant_a',
      );
      expect(result, false);
    });

    test('requestSlot returns true when slot is available', () async {
      final reservation = ReservationModel(
        id: 'res1',
        userId: 'user1',
        customerName: 'John',
        customerPhone: '555-0100',
        startTime: DateTime(2026, 7, 24, 18, 0),
        partySize: 4,
        branchId: 'branch1',
      );

      final result = await repository.requestSlot(
        reservation,
        50,
        tenantId: 'tenant_a',
      );
      expect(result, true);
    });

    test('requestSlot creates reservation document on success', () async {
      final reservation = ReservationModel(
        id: 'res1',
        userId: 'user1',
        customerName: 'John',
        customerPhone: '555-0100',
        startTime: DateTime(2026, 7, 24, 18, 0),
        partySize: 4,
        branchId: 'branch1',
      );

      await repository.requestSlot(reservation, 50, tenantId: 'tenant_a');

      final doc = await firestore.collection('reservations').doc('res1').get();
      expect(doc.exists, true);
      expect(doc.data()?['customerName'], 'John');
    });

    test('requestSlot creates lock document on success', () async {
      final reservation = ReservationModel(
        id: 'res1',
        userId: 'user1',
        customerName: 'John',
        customerPhone: '555-0100',
        startTime: DateTime(2026, 7, 24, 18, 0),
        partySize: 4,
        branchId: 'branch1',
      );

      await repository.requestSlot(reservation, 50, tenantId: 'tenant_a');

      final lockId =
          'branch1_${reservation.startTime.millisecondsSinceEpoch}_user1';
      final lockDoc = await firestore
          .collection('reservation_locks')
          .doc(lockId)
          .get();
      expect(lockDoc.exists, true);
    });

    // ------------------------------------------------------------------
    // PERF-10 T-8 mutant-kill pins (tool_archive/perf2_cited/tool_perf2/t78_mutants/manifest.json):
    // the counter/lock boundaries the suite above left open. M-D08..M-D12
    // all survived a green run of this file; each test below fails with its
    // mutant applied (tool_perf2/t78_logs/t78_mutants/*.out.log).
    // ------------------------------------------------------------------

    // KILLS M-D08 (`partySize <= 0` -> `partySize < 0`).
    test(
      'requestSlot rejects a zero-party booking (no lock, no doc)',
      () async {
        final start = DateTime(2026, 7, 24, 18, 0);
        final reservation = ReservationModel(
          id: 'res-zero',
          userId: 'user1',
          customerName: 'John',
          customerPhone: '555-0100',
          startTime: start,
          partySize: 0,
          branchId: 'branch1',
        );

        expect(
          await repository.requestSlot(reservation, 50, tenantId: 'tenant_a'),
          false,
        );

        final counterId = 'branch1_${start.millisecondsSinceEpoch}';
        final counter = await firestore
            .collection('reservation_counters')
            .doc(counterId)
            .get();
        expect((counter.data()?['booked'] as num?)?.toInt() ?? 0, 0);
        final lock = await firestore
            .collection('reservation_locks')
            .doc('${counterId}_user1')
            .get();
        expect(
          lock.exists,
          false,
          reason: 'no seat may be locked for a 0 party',
        );
        final doc = await firestore
            .collection('reservations')
            .doc('res-zero')
            .get();
        expect(doc.exists, false);
      },
    );

    // KILLS M-D09 (`if (lockDoc.exists)` -> `if (false)`).
    test(
      'requestSlot refuses a second booking of the same slot by one user',
      () async {
        final start = DateTime(2026, 7, 24, 18, 0);
        ReservationModel booking() => ReservationModel(
          id: 'res-dup',
          userId: 'user1',
          customerName: 'John',
          customerPhone: '555-0100',
          startTime: start,
          partySize: 4,
          branchId: 'branch1',
        );

        expect(
          await repository.requestSlot(booking(), 50, tenantId: 'tenant_a'),
          true,
        );
        expect(
          await repository.requestSlot(booking(), 50, tenantId: 'tenant_a'),
          false,
        );

        final counter = await firestore
            .collection('reservation_counters')
            .doc('branch1_${start.millisecondsSinceEpoch}')
            .get();
        expect(
          (counter.data()!['booked'] as num).toInt(),
          4,
          reason: 'the refused duplicate must not charge the slot twice',
        );
      },
    );

    // KILLS M-D10 (`'booked': booked + partySize` -> `booked - partySize`).
    test(
      'requestSlot increments the counter by exactly the party size',
      () async {
        final start = DateTime(2026, 7, 24, 18, 0);
        final reservation = ReservationModel(
          id: 'res-inc',
          userId: 'user1',
          customerName: 'John',
          customerPhone: '555-0100',
          startTime: start,
          partySize: 4,
          branchId: 'branch1',
        );

        expect(
          await repository.requestSlot(reservation, 50, tenantId: 'tenant_a'),
          true,
        );

        final counter = await firestore
            .collection('reservation_counters')
            .doc('branch1_${start.millisecondsSinceEpoch}')
            .get();
        expect((counter.data()!['booked'] as num).toInt(), 4);
      },
    );

    // KILLS M-D12 (`partySize > (branchCapacity - booked)` -> `>=`).
    test(
      'requestSlot accepts a party of exactly the remaining capacity',
      () async {
        final start = DateTime(2026, 7, 24, 18, 0);
        final counterRef = firestore
            .collection('reservation_counters')
            .doc('branch1_${start.millisecondsSinceEpoch}');
        await counterRef.set({'booked': 46}); // 4 of 50 seats left

        final reservation = ReservationModel(
          id: 'res-exact',
          userId: 'user1',
          customerName: 'John',
          customerPhone: '555-0100',
          startTime: start,
          partySize: 4,
          branchId: 'branch1',
        );

        expect(
          await repository.requestSlot(reservation, 50, tenantId: 'tenant_a'),
          true,
        );
        final counter = await counterRef.get();
        expect((counter.data()!['booked'] as num).toInt(), 50);
      },
    );

    // KILLS M-D11 (`remaining > 0 ? remaining : 0` -> `remaining`).
    test('cancelReservation clamps the released counter at zero', () async {
      final start = DateTime(2026, 7, 24, 18, 0);
      await firestore.collection('reservations').doc('res-drift').set({
        'userId': 'user1',
        'branchId': 'branch1',
        'customerName': 'John',
        'customerPhone': '555-0100',
        'startTime': Timestamp.fromDate(start),
        'partySize': 4,
        'status': 'pending',
      });
      // Counter drift: the slot was already zeroed (e.g. an admin edit).
      final counterRef = firestore
          .collection('reservation_counters')
          .doc('branch1_${start.millisecondsSinceEpoch}');
      await counterRef.set({'booked': 0});

      expect(await repository.cancelReservation('res-drift'), true);

      final counter = await counterRef.get();
      expect(
        (counter.data()!['booked'] as num).toInt(),
        0,
        reason: 'a release must never mint negative capacity',
      );
      final res = await firestore
          .collection('reservations')
          .doc('res-drift')
          .get();
      expect(res.data()!['status'], ReservationsRepository.statusCancelled);
    });
  });
}
