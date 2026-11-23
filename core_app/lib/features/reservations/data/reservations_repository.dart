import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import '../domain/reservation_model.dart';

class ReservationsRepository {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  ReservationsRepository(this._firestore, this._logger);

  Future<bool> requestSlot(
    ReservationModel reservation,
    int branchCapacity, {
    required String tenantId,
  }) async {
    // P8 W4 (A-4): fail closed on malformed bookings BEFORE anything is
    // written. WHY: a non-positive partySize passes the capacity comparison
    // below (`partySize > branchCapacity - booked` is false for negatives),
    // consumes a lock document and then DECREMENTS the atomic counter at the
    // end of the transaction — minting phantom capacity that lets a later
    // party over-book the slot. The screen validator
    // (reservation_screen.dart:301-307) rejects those values, but this
    // repository owns the counter and is the last line of defence for every
    // non-UI caller.
    if (reservation.partySize <= 0) {
      await _logger.warn(
        StateError('requestSlot rejected: partySize=${reservation.partySize}'),
        'requestSlot rejected a non-positive party size',
      );
      return false;
    }
    // Law 25: a reservation without a branch id would be written under a
    // branch no capacity counter is keyed to.
    if (reservation.branchId.isEmpty) {
      await _logger.warn(
        StateError('requestSlot rejected: empty branchId'),
        'requestSlot rejected a reservation with no branchId',
      );
      return false;
    }

    // Use a Firestore transaction to atomically check capacity + lock the slot.
    // Firestore transactions only support DocumentReference reads (not queries),
    // so we use a deterministic counter doc keyed by (branchId + startTime).
    final counterRef = _firestore
        .collection('reservation_counters')
        .doc(
          '${reservation.branchId}_${reservation.startTime.millisecondsSinceEpoch}',
        );
    final lockRef = _firestore
        .collection('reservation_locks')
        .doc(
          '${reservation.branchId}_${reservation.startTime.millisecondsSinceEpoch}_${reservation.userId}',
        );

    try {
      return await _firestore.runTransaction((transaction) async {
        // 1. Read the capacity counter atomically
        final counterDoc = await transaction.get(counterRef);
        final booked = (counterDoc.data()?['booked'] as num?)?.toInt() ?? 0;
        if (reservation.partySize > (branchCapacity - booked)) {
          return false;
        }

        // 2. Check the lock
        final lockDoc = await transaction.get(lockRef);
        if (lockDoc.exists) {
          return false;
        }

        // 3. Lock the slot
        transaction.set(lockRef, {
          'lockedAt': FieldValue.serverTimestamp(),
          'userId': reservation.userId,
          'tenantId': tenantId,
        });

        // 4. Increment the capacity counter atomically
        transaction.set(counterRef, {
          'booked': booked + reservation.partySize,
          'tenantId': tenantId,
        }, SetOptions(merge: true));

        // 5. Create the reservation (WITH branchId — Law 25)
        final resRef = _firestore
            .collection('reservations')
            .doc(reservation.id);
        transaction.set(resRef, {
          'tenantId': tenantId,
          'branchId': reservation.branchId,
          'userId': reservation.userId,
          'customerName': reservation.customerName,
          'customerPhone': reservation.customerPhone,
          'startTime': Timestamp.fromDate(reservation.startTime),
          'partySize': reservation.partySize,
          if (reservation.notes != null) 'notes': reservation.notes,
        });

        return true;
      });
    } catch (e, stack) {
      await _logger.error(e, 'requestSlot failed', stack: stack);
      return false;
    }
  }

  Future<int> getAvailableCapacity(
    String branchId,
    DateTime startTime,
    int branchCapacity,
  ) async {
    try {
      final counterDoc = await _firestore
          .collection('reservation_counters')
          .doc('${branchId}_${startTime.millisecondsSinceEpoch}')
          .get();
      final booked = (counterDoc.data()?['booked'] as num?)?.toInt() ?? 0;
      return (branchCapacity - booked).clamp(0, branchCapacity);
    } catch (e, stack) {
      await _logger.error(
        e,
        'getAvailableCapacity failed for branchId: $branchId',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Closed transition vocabulary (P9 W1 T-1): a booking is born
  /// implicit-pending — the create write MUST NOT gain a `status` key because
  /// the rules lock the create key set (firestore.rules:517-518 hasOnly) — and
  /// cancellation is the only transition this repository owns. Any other
  /// status is terminal and can never be cancelled.
  static const String statusCancelled = 'cancelled';
  static const List<String?> _cancellableStatuses = <String?>[null, 'pending'];

  /// P9 W1 (T-1) — the cancel transition + compensating capacity decrement.
  ///
  /// B-1 (PERF-8 W4): the counter was monotonic — seats taken by a reservation
  /// were never returned, so every cancellation permanently shrank the slot.
  /// The transition lives at this chokepoint (the repository is the only
  /// writer of `reservations` + `reservation_counters` — P1 enumeration in
  /// tool_archive/perf2_cited/tool_perf2/p9_w1_findings.md) and the decrement runs in the SAME
  /// transaction as the status write: "cancelled ⇒ seats released" holds
  /// atomically or nothing is written.
  ///
  /// Guard: the status precondition. Only a document whose `status` is absent
  /// (implicit-pending) or `'pending'` may transition to
  /// [statusCancelled]; a retry after a successful cancel sees the terminal
  /// status and is refused, so the decrement can never run twice. The counter
  /// write is clamped at ≥0 — pre-existing counter drift can never mint
  /// phantom negative capacity. A corrupt document (missing
  /// branchId/startTime/partySize) is refused whole: the reservation is never
  /// marked cancelled without its compensating decrement.
  ///
  /// Rules: the reservation update touches only {status, cancelledAt}
  /// (doc-owner update — firestore.rules:519-523 reserves only
  /// userId/branchId) and the counter merge-set keeps the
  /// isValidReservationCounter shape `{booked: int ≥ 0}`
  /// (firestore.rules:491-498).
  ///
  /// Returns true only when THIS call moved the reservation to
  /// [statusCancelled] (and released its seats); false = reservation missing,
  /// already terminal, corrupt, or the transaction failed (all logged,
  /// nothing written).
  Future<bool> cancelReservation(String reservationId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final resRef = _firestore.collection('reservations').doc(reservationId);
        final resDoc = await transaction.get(resRef);
        if (!resDoc.exists) {
          await _logger.warn(
            StateError(
              'cancelReservation: reservation $reservationId not found',
            ),
            'cancelReservation rejected: reservation does not exist',
          );
          return false;
        }
        final data = resDoc.data() ?? const <String, dynamic>{};
        final status = data['status'] as String?;
        if (!_cancellableStatuses.contains(status)) {
          await _logger.warn(
            StateError(
              'cancelReservation: reservation $reservationId status=$status',
            ),
            'cancelReservation rejected: reservation is not cancellable',
          );
          return false;
        }
        final partySize = (data['partySize'] as num?)?.toInt() ?? 0;
        final branchId = data['branchId'] as String? ?? '';
        final startTimeMs =
            (data['startTime'] as Timestamp?)?.millisecondsSinceEpoch;
        if (partySize <= 0 || branchId.isEmpty || startTimeMs == null) {
          await _logger.error(
            StateError(
              'cancelReservation: reservation $reservationId is corrupt '
              '(partySize=$partySize branchId=$branchId startTime=$startTimeMs)',
            ),
            'cancelReservation rejected: corrupt reservation document',
          );
          return false;
        }

        // The compensating decrement — SAME transaction as the status write,
        // clamped at ≥0 (drift can never go negative).
        final counterRef = _firestore
            .collection('reservation_counters')
            .doc('${branchId}_$startTimeMs');
        final counterDoc = await transaction.get(counterRef);
        final booked = (counterDoc.data()?['booked'] as num?)?.toInt() ?? 0;
        final remaining = booked - partySize;
        transaction.update(resRef, {
          'status': statusCancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        transaction.set(counterRef, {
          'booked': remaining > 0 ? remaining : 0,
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e, stack) {
      await _logger.error(e, 'cancelReservation failed', stack: stack);
      return false;
    }
  }
}
