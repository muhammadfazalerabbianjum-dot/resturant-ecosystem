import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// PERF-1 (T-6) — PresenceModel parse contract: fromDoc (Firestore shape,
/// role resolution, timestamp conversion, defaults) and the generated
/// fromJson/toJson round-trip (unknown/missing roles fail closed to
/// customer — the B3 P2 converter contract).

void main() {
  group('PresenceModel.fromDoc — Firestore document shape', () {
    test('a full staff document parses every field', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('presence').doc('staff-1').set({
        'isOnline': true,
        'branchId': 'branch-9',
        'role': 'kitchen',
      });
      final doc = await db.collection('presence').doc('staff-1').get();

      final model = PresenceModel.fromDoc(doc);
      expect(model.userId, 'staff-1');
      expect(model.isOnline, isTrue);
      expect(model.branchId, 'branch-9');
      expect(model.role, UserRole.kitchen);
    });

    test('lastSeen Timestamp converts to a local DateTime', () async {
      final db = FakeFirebaseFirestore();
      final at = DateTime.utc(2026, 9, 14, 8, 30);
      await db.collection('presence').doc('staff-2').set({
        'lastSeen': Timestamp.fromDate(at),
      });
      final doc = await db.collection('presence').doc('staff-2').get();

      final model = PresenceModel.fromDoc(doc);
      expect(
        model.lastSeen!.toUtc(),
        at,
        reason: 'the Timestamp instant is preserved (timezone-agnostic)',
      );
    });

    test('missing/unknown fields fail closed to safe defaults', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('presence').doc('staff-3').set(<String, dynamic>{});
      final doc = await db.collection('presence').doc('staff-3').get();

      final model = PresenceModel.fromDoc(doc);
      expect(model.isOnline, isFalse);
      expect(model.branchId, '');
      expect(model.role, UserRole.customer, reason: 'missing role → customer');
    });

    test('an unknown role string falls back to customer (no crash)', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('presence').doc('staff-4').set({
        'role': 'supreme-overlord',
      });
      final doc = await db.collection('presence').doc('staff-4').get();

      expect(PresenceModel.fromDoc(doc).role, UserRole.customer);
    });
  });

  group('PresenceModel — generated JSON round-trip', () {
    test('fromJson restores every field (role via converter)', () {
      final model = PresenceModel.fromJson({
        'userId': 'u1',
        'isOnline': true,
        'branchId': 'b1',
        'role': 'delivery',
      });
      expect(model.userId, 'u1');
      expect(model.isOnline, isTrue);
      expect(model.branchId, 'b1');
      expect(model.role, UserRole.delivery);
    });

    test('toJson emits the role name; a round-trip is stable', () {
      const model = PresenceModel(
        userId: 'u2',
        isOnline: false,
        branchId: 'b2',
        role: UserRole.manager,
      );
      final json = model.toJson();
      expect(json['role'], 'manager');

      final restored = PresenceModel.fromJson(json);
      expect(restored, model, reason: 'fromJson(toJson(m)) == m');
    });

    test('an unknown/missing role in JSON fails closed to customer', () {
      expect(
        PresenceModel.fromJson({'userId': 'u3', 'role': 'nope'}).role,
        UserRole.customer,
      );
      expect(PresenceModel.fromJson({'userId': 'u4'}).role, UserRole.customer);
    });
  });
}
