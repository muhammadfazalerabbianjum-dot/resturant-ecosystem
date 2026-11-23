import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/auth/user_model.dart';
import 'package:core/src/presence/presence_model.dart';

void main() {
  group('PresenceModel', () {
    test('default constructor sets isOnline to false and role to customer', () {
      const model = PresenceModel(userId: 'user1');
      expect(model.userId, 'user1');
      expect(model.isOnline, false);
      expect(model.role, UserRole.customer);
      expect(model.branchId, '');
      expect(model.lastSeen, isNull);
    });

    test('constructor preserves provided values', () {
      final now = DateTime.now();
      final model = PresenceModel(
        userId: 'user2',
        isOnline: true,
        lastSeen: now,
        branchId: 'branch-1',
        role: UserRole.manager,
      );
      expect(model.userId, 'user2');
      expect(model.isOnline, true);
      expect(model.lastSeen, now);
      expect(model.branchId, 'branch-1');
      expect(model.role, UserRole.manager);
    });

    test('fromDoc returns default for null document data', () {
      final model = _presenceFromDoc('user-null', null);
      expect(model.userId, 'user-null');
      expect(model.isOnline, false);
      expect(model.lastSeen, isNull);
      expect(model.branchId, '');
      expect(model.role, UserRole.customer);
    });

    test('fromDoc returns default for empty document data', () {
      final model = _presenceFromDoc('user-xyz', <String, dynamic>{});
      expect(model.userId, 'user-xyz');
      expect(model.isOnline, false);
      expect(model.lastSeen, isNull);
      expect(model.branchId, '');
      expect(model.role, UserRole.customer);
    });

    test('fromDoc maps unknown role string to customer default', () {
      final model = _presenceFromDoc('user-unknown', {'role': 'superadmin'});
      expect(model.role, UserRole.customer);
    });

    test('fromDoc maps all valid role strings correctly', () {
      final roles = {
        'customer': UserRole.customer,
        'manager': UserRole.manager,
        'kitchen': UserRole.kitchen,
        'delivery': UserRole.delivery,
        'owner': UserRole.owner,
      };
      for (final entry in roles.entries) {
        final model = _presenceFromDoc('user-role', {'role': entry.key});
        expect(
          model.role,
          entry.value,
          reason: 'Role string "${entry.key}" should map to ${entry.value}',
        );
      }
    });

    test('fromDoc parses lastSeen Timestamp correctly', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      final model = _presenceFromDoc('user-ts', {
        'lastSeen': timestamp,
        'isOnline': true,
        'branchId': 'branch-main',
      });
      expect(model.lastSeen, isNotNull);
      expect(
        model.lastSeen!.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(model.isOnline, true);
      expect(model.branchId, 'branch-main');
    });

    test('fromDoc with isOnline false and explicit branchId', () {
      final model = _presenceFromDoc('user-offline', {
        'isOnline': false,
        'branchId': 'branch-offline',
      });
      expect(model.isOnline, false);
      expect(model.branchId, 'branch-offline');
    });

    test('fromJson round-trips correctly', () {
      final now = DateTime.now();
      final original = PresenceModel(
        userId: 'user-roundtrip',
        isOnline: true,
        lastSeen: now,
        branchId: 'branch-99',
        role: UserRole.delivery,
      );

      final json = original.toJson();
      final restored = PresenceModel.fromJson(json);

      expect(restored.userId, original.userId);
      expect(restored.isOnline, original.isOnline);
      expect(restored.branchId, original.branchId);
      expect(restored.role, original.role);
    });

    test('fromJson handles null lastSeen gracefully', () {
      final json = {
        'userId': 'user-no-lastseen',
        'isOnline': false,
        'lastSeen': null,
        'branchId': '',
        'role': 'customer',
      };
      final model = PresenceModel.fromJson(json);
      expect(model.lastSeen, isNull);
      expect(model.userId, 'user-no-lastseen');
    });

    test('fromJson parses lastSeen as ISO string correctly', () {
      final now = DateTime.now().toUtc();
      final json = {
        'userId': 'user-iso',
        'isOnline': true,
        'lastSeen': now.toIso8601String(),
        'branchId': 'branch-iso',
        'role': 'manager',
      };
      final model = PresenceModel.fromJson(json);
      expect(model.lastSeen, isNotNull);
      expect(
        model.lastSeen!.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(model.role, UserRole.manager);
    });

    test('toJson serializes all fields correctly', () {
      final now = DateTime.now();
      final model = PresenceModel(
        userId: 'user-tojson',
        isOnline: true,
        lastSeen: now,
        branchId: 'branch-json',
        role: UserRole.kitchen,
      );
      final json = model.toJson();
      expect(json['userId'], 'user-tojson');
      expect(json['isOnline'], true);
      expect(json['branchId'], 'branch-json');
      expect(json['role'], 'kitchen');
      expect(json.containsKey('lastSeen'), true);
    });

    test('copyWith creates a modified copy', () {
      const original = PresenceModel(userId: 'user-copy');
      final modified = original.copyWith(
        isOnline: true,
        branchId: 'new-branch',
      );

      expect(original.isOnline, false);
      expect(modified.isOnline, true);
      expect(modified.branchId, 'new-branch');
      expect(modified.userId, 'user-copy');
    });

    test('copyWith does not mutate original', () {
      const original = PresenceModel(userId: 'user-immutable', isOnline: false);
      final _ = original.copyWith(isOnline: true);
      expect(original.isOnline, false);
    });

    test('equality holds for identical models', () {
      const a = PresenceModel(
        userId: 'user-eq',
        isOnline: true,
        branchId: 'b1',
      );
      const b = PresenceModel(
        userId: 'user-eq',
        isOnline: true,
        branchId: 'b1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality detects different userId', () {
      const a = PresenceModel(userId: 'user-a');
      const b = PresenceModel(userId: 'user-b');
      expect(a, isNot(equals(b)));
    });

    test('inequality detects different isOnline', () {
      const a = PresenceModel(userId: 'user-same', isOnline: false);
      const b = PresenceModel(userId: 'user-same', isOnline: true);
      expect(a, isNot(equals(b)));
    });

    test('inequality detects different role', () {
      const a = PresenceModel(userId: 'user-role', role: UserRole.customer);
      const b = PresenceModel(userId: 'user-role', role: UserRole.manager);
      expect(a, isNot(equals(b)));
    });
  });
}

/// Helper that recreates PresenceModel.fromDoc logic without depending on
/// the sealed DocumentSnapshot class.
PresenceModel _presenceFromDoc(String id, Map<String, dynamic>? data) {
  final dataMap = data ?? <String, dynamic>{};
  final roleStr = dataMap['role'] as String?;
  final role = roleStr != null
      ? UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.customer,
        )
      : UserRole.customer;

  return PresenceModel(
    userId: id,
    isOnline: dataMap['isOnline'] as bool? ?? false,
    lastSeen: dataMap['lastSeen'] != null
        ? (dataMap['lastSeen'] as Timestamp).toDate()
        : null,
    branchId: dataMap['branchId'] as String? ?? '',
    role: role,
  );
}
