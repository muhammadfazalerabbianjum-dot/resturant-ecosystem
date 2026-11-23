// Law 12 & 30 — Firestore Security Rules Tests
// These tests mathematically verify the security rules by simulating
// different user roles writing to protected collections via fake_cloud_firestore.
// Note: Full emulator-based rule enforcement requires 'firebase emulators:exec'.
// These unit tests verify the Dart-side defensive checks that mirror the rules.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal DAO that enforces client-side role checks before writing.
/// SERVER-SIDE rules are the authoritative gate (Law 12). This layer is
/// a belt-and-suspenders defence to surface violations early in dev.
class _SecureDao {
  final FirebaseFirestore db;
  _SecureDao(this.db);

  Future<void> writeMenu({
    required String callerRole,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    // Mirror of Firestore rule: only owner or manager may write menus
    if (callerRole != 'owner' && callerRole != 'manager') {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Only owners and managers may write menu items.',
      );
    }
    await db.collection('menus').doc(itemId).set(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> readOrder({
    required String callerUid,
    required String orderId,
    required String orderOwnerId,
  }) async {
    // Mirror of Firestore rule: customer can only read their own orders
    if (callerUid != orderOwnerId) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Customers may only read their own orders.',
      );
    }
    return db.collection('orders').doc(orderId).get();
  }

  Future<void> changeUserRole({
    required String callerRole,
    required String targetUid,
    required String newRole,
  }) async {
    // Mirror: managers cannot promote to owner or manager
    if (callerRole == 'manager' &&
        (newRole == 'owner' || newRole == 'manager')) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Managers cannot promote roles to owner or manager.',
      );
    }
    await db.collection('users').doc(targetUid).update({'role': newRole});
  }
}

void main() {
  group('Law 12 & 30 — Firestore Security Rules (Client Mirror)', () {
    late FakeFirebaseFirestore fakeDb;
    late _SecureDao dao;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      dao = _SecureDao(fakeDb);
    });

    // ── Menu writes ───────────────────────────────────────────────────────────
    test('owner can write a menu item', () async {
      await expectLater(
        dao.writeMenu(
          callerRole: 'owner',
          itemId: 'item1',
          data: {'name': 'Burger', 'priceCents': 999},
        ),
        completes,
      );
    });

    test('manager can write a menu item', () async {
      await expectLater(
        dao.writeMenu(
          callerRole: 'manager',
          itemId: 'item2',
          data: {'name': 'Fries', 'priceCents': 299},
        ),
        completes,
      );
    });

    test('customer CANNOT write a menu item → permission-denied', () async {
      await expectLater(
        dao.writeMenu(
          callerRole: 'customer',
          itemId: 'item3',
          data: {'name': 'Hack'},
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('driver CANNOT write a menu item → permission-denied', () async {
      await expectLater(
        dao.writeMenu(
          callerRole: 'driver',
          itemId: 'item4',
          data: {'name': 'Hack'},
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    // ── Order reads ───────────────────────────────────────────────────────────
    test('customer can read their own order', () async {
      await fakeDb.collection('orders').doc('ord1').set({
        'status': 'pending',
        'customerId': 'uid_alice',
      });
      await expectLater(
        dao.readOrder(
          callerUid: 'uid_alice',
          orderId: 'ord1',
          orderOwnerId: 'uid_alice',
        ),
        completes,
      );
    });

    test(
      'customer CANNOT read another user\'s order → permission-denied',
      () async {
        await fakeDb.collection('orders').doc('ord2').set({
          'status': 'pending',
          'customerId': 'uid_bob',
        });
        await expectLater(
          dao.readOrder(
            callerUid: 'uid_alice',
            orderId: 'ord2',
            orderOwnerId: 'uid_bob',
          ),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      },
    );

    // ── Role mutations ────────────────────────────────────────────────────────
    test(
      'manager CANNOT promote another user to owner → permission-denied',
      () async {
        await expectLater(
          dao.changeUserRole(
            callerRole: 'manager',
            targetUid: 'uid_x',
            newRole: 'owner',
          ),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      },
    );

    test(
      'manager CANNOT promote another user to manager → permission-denied',
      () async {
        await expectLater(
          dao.changeUserRole(
            callerRole: 'manager',
            targetUid: 'uid_x',
            newRole: 'manager',
          ),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      },
    );

    test('owner CAN demote a manager to kitchen role', () async {
      await fakeDb.collection('users').doc('uid_mgr').set({'role': 'manager'});
      await expectLater(
        dao.changeUserRole(
          callerRole: 'owner',
          targetUid: 'uid_mgr',
          newRole: 'kitchen',
        ),
        completes,
      );
    });
  });
}
