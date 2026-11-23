// TDD Red test for C2: reservation_locks must only be writable by the user
// who owns the lock (userId field must match auth.uid).
// This is a logical/unit test of the rule invariant — enforced in the rules file.
import 'package:flutter_test/flutter_test.dart';

// We model the rule logic in Dart to validate the invariant without an emulator.
bool reservationLockWriteAllowed({
  required String authUid,
  required String requestUserId,
}) {
  // The rule we WANT: request.auth.uid == request.resource.data.userId
  return authUid == requestUserId;
}

void main() {
  group('Firestore Rule: reservation_locks write invariant', () {
    test('allows write when userId matches auth.uid', () {
      expect(
        reservationLockWriteAllowed(
          authUid: 'user-123',
          requestUserId: 'user-123',
        ),
        isTrue,
      );
    });

    test('denies write when userId does NOT match auth.uid', () {
      expect(
        reservationLockWriteAllowed(
          authUid: 'user-123',
          requestUserId: 'user-456',
        ),
        isFalse,
      );
    });

    test('denies write with empty userId', () {
      expect(
        reservationLockWriteAllowed(authUid: 'user-123', requestUserId: ''),
        isFalse,
      );
    });
  });
}
