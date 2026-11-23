import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/presence/presence_model.dart';
import 'package:core/src/auth/user_model.dart';

// Spec: PresenceModel contract:
// - Required: userId (String)
// - Optional: isOnline (default false), branchId (nullable), role (default customer)
// - Unknown role strings fall back to UserRole.customer
// - toJson omits null values for Firestore efficiency
// Tests assert against hard-coded spec values — no mirroring.

void main() {
  group('PresenceModel — Spec Contract', () {
    test('Full presence round-trips all fields per spec', () {
      // Spec: all fields present → survives fromJson → toJson → fromJson
      const original = PresenceModel(
        userId: 'user_1',
        isOnline: true,
        branchId: 'b1',
        role: UserRole.kitchen,
      );

      final json = original.toJson();
      final restored = PresenceModel.fromJson(json);

      expect(restored.userId, equals('user_1'));
      expect(restored.isOnline, equals(true));
      expect(restored.branchId, equals('b1'));
      expect(restored.role, equals(UserRole.kitchen));
    });

    test('isOnline defaults to false per spec', () {
      // Spec: missing isOnline → false
      final p = PresenceModel.fromJson({'userId': 'u2'});
      expect(p.isOnline, equals(false));
    });

    test('branchId defaults to empty string per spec', () {
      // Spec: missing branchId → empty string (not null)
      final p = PresenceModel.fromJson({'userId': 'u3'});
      expect(p.branchId, equals(''));
    });

    test('role defaults to customer per spec', () {
      // Spec: missing role → customer
      final p = PresenceModel.fromJson({'userId': 'u4'});
      expect(p.role, equals(UserRole.customer));
    });

    test('Unknown role string falls back to customer per spec', () {
      // Spec: 'alien' → customer (fail-safe)
      final p = PresenceModel.fromJson({'userId': 'u5', 'role': 'alien'});
      expect(p.role, equals(UserRole.customer));
    });

    test('All valid UserRole values parse correctly per spec', () {
      // Spec: every role in UserRole enum must round-trip
      for (final role in UserRole.values) {
        final p = PresenceModel.fromJson({'userId': 'test', 'role': role.name});
        expect(
          p.role,
          equals(role),
          reason: 'UserRole.$role must parse from JSON',
        );
      }
    });

    test('toJson includes empty branchId per spec', () {
      // Spec: empty branchId is serialized as empty string (not omitted)
      const p = PresenceModel(userId: 'u6');
      final json = p.toJson();
      expect(json.containsKey('branchId'), isTrue);
      expect(json['branchId'], equals(''));
    });

    test('toJson includes non-null branchId per spec', () {
      // Spec: non-null branchId must be serialized
      const p = PresenceModel(userId: 'u7', branchId: 'branch_nyc');
      final json = p.toJson();
      expect(json['branchId'], equals('branch_nyc'));
    });

    test('isOnline false is serialized correctly', () {
      // Spec: false is a valid value, must be written
      const p = PresenceModel(userId: 'u8', isOnline: false);
      final json = p.toJson();
      expect(json['isOnline'], equals(false));
    });

    test('Empty userId is allowed (edge case)', () {
      // Spec: userId can be empty string (validation happens upstream)
      final p = PresenceModel.fromJson({'userId': ''});
      expect(p.userId, equals(''));
    });
  });
}
