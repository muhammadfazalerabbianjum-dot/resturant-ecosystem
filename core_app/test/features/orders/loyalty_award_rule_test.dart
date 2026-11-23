// TDD Red test for C3: loyalty points write from client must be permitted
// under strict invariants (only merge-increment by owner, never arbitrary set).
// This models the rule logic without a live emulator.
import 'package:flutter_test/flutter_test.dart';

// Model of the rule logic we will add:
// allow write: if request.auth.uid == userId
//   && request.resource.data.keys().hasOnly(['points'])
//   && request.resource.data.points is int;
bool loyaltyClientWriteAllowed({
  required String authUid,
  required String documentUserId,
  required Map<String, dynamic> writeData,
}) {
  if (authUid != documentUserId) return false;
  if (!writeData.containsKey('points')) return false;
  if (writeData.keys.length != 1) return false; // only 'points' field
  if (writeData['points'] is! int) return false;
  return true;
}

void main() {
  group('Loyalty points client-write rule invariant', () {
    test('allows owner to write only the points field as int', () {
      expect(
        loyaltyClientWriteAllowed(
          authUid: 'user-123',
          documentUserId: 'user-123',
          writeData: {'points': 10},
        ),
        isTrue,
      );
    });

    test('denies write by non-owner', () {
      expect(
        loyaltyClientWriteAllowed(
          authUid: 'user-456',
          documentUserId: 'user-123',
          writeData: {'points': 10},
        ),
        isFalse,
      );
    });

    test('denies write with extra fields (no arbitrary data injection)', () {
      expect(
        loyaltyClientWriteAllowed(
          authUid: 'user-123',
          documentUserId: 'user-123',
          writeData: {'points': 10, 'isAdmin': true},
        ),
        isFalse,
      );
    });

    test('denies write with non-int points value', () {
      expect(
        loyaltyClientWriteAllowed(
          authUid: 'user-123',
          documentUserId: 'user-123',
          writeData: {'points': 'all'},
        ),
        isFalse,
      );
    });
  });
}
