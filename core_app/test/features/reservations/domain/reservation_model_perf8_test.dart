// P8 W4 (A-4 / T4) — ReservationModel pins (domain straggler: 17% before).
//
// P9 W1 (T-5, register W4-5): the `ReservationModel.fromDoc` factory had no
// production caller (the admin tab reads `fromJson`); it and its three pins
// were deleted — tests of dead code are test-theater. The fromJson /
// toFirestore / defaults contract below is what the live callers depend on,
// and it stays pinned.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/reservations/domain/reservation_model.dart';

void main() {
  group('ReservationModel.fromJson', () {
    test('fromJson requires an id — a payload without one is rejected', () {
      expect(
        () => ReservationModel.fromJson({
          'startTime': DateTime(2026, 1, 1).toIso8601String(),
        }),
        throwsA(anything),
      );
    });
  });

  group('ReservationModel.toFirestore', () {
    test('emits a Timestamp start time, keeps the branch and omits null notes '
        'and the document id', () {
      final model = ReservationModel(
        id: 'r1',
        userId: 'u1',
        branchId: 'b1',
        customerName: 'Ada',
        customerPhone: '555-0101',
        startTime: DateTime(2026, 1, 2, 18, 0),
        partySize: 2,
      );

      final data = model.toFirestore();

      expect(data['startTime'], isA<Timestamp>());
      expect(
        (data['startTime'] as Timestamp).toDate(),
        DateTime(2026, 1, 2, 18, 0),
      );
      expect(data['branchId'], 'b1');
      expect(data['partySize'], 2);
      expect(data.containsKey('notes'), isFalse);
      expect(
        data.containsKey('id'),
        isFalse,
        reason:
            'the Firestore document id comes from the path, never the '
            'payload — writing it as a field would fork the identity',
      );
    });

    test('keeps notes when present and survives a JSON round-trip', () {
      final model = ReservationModel(
        id: 'r2',
        userId: 'u1',
        branchId: 'b1',
        startTime: DateTime(2026, 3, 4, 20, 15),
        partySize: 6,
        notes: 'Window seat',
      );

      final data = model.toFirestore();
      expect(data['notes'], 'Window seat');

      final reread = ReservationModel.fromJson(<String, dynamic>{
        ...data,
        'id': model.id,
        'startTime': model.startTime.toIso8601String(),
      });

      expect(reread.notes, 'Window seat');
      expect(reread.partySize, 6);
      expect(reread.startTime, model.startTime);
    });
  });

  group('ReservationModel defaults', () {
    test('a minimal reservation carries the guest identity defaults', () {
      final model = ReservationModel(id: 'r3', startTime: DateTime(2026, 5, 5));

      expect(model.userId, '');
      expect(model.branchId, '');
      expect(model.customerName, 'Guest');
      expect(model.customerPhone, '—');
      expect(model.partySize, 1);
      expect(model.notes, isNull);
    });
  });
}
