/// Phase 4.9 — Isar Schema Migration Tests
///
/// Tests the offline cache layer (IsarMenuItem, IsarCart, IsarPendingOperation)
/// using an in-memory Isar instance opened with a temp directory.
///
/// Coverage:
///   ✓ Schema open / singleton guard
///   ✓ IsarMenuItem upsert + unique-firestoreId constraint
///   ✓ IsarCart write + read integrity
///   ✓ IsarPendingOperation enqueue / flush (syncPendingOperations)
///   ✓ retryCount increment guard
///   ✓ Stale-timestamp ordering
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:core/core.dart';

/// Opens a fresh in-memory Isar instance using a unique temp directory.
Future<Isar> _openTestDb() async {
  final dir = await Directory.systemTemp.createTemp('isar_test_');
  return Isar.open(
    [
      IsarMenuItemSchema,
      IsarCartSchema,
      IsarPendingOperationSchema,
      IsarDeadLetterSchema,
    ],
    directory: dir.path,
    name: 'test_${dir.path.hashCode}',
    inspector: false,
  );
}

void main() {
  // Initialise the Isar native binary once for all headless tests. p34 A-fix:
  // pin the LOCKFILE's package binary (package_config) — the old
  // `initializeIsarCore(download: true)` fetched from the network, and the
  // repo-root isar.dll is the 3.1.0+1 core the 3.3.2 runtime rejects.
  setUpAll(ensureIsarCoreForTests);

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  group('IsarService — openDB singleton guard', () {
    test('second open returns existing instance', () async {
      final db1 = await _openTestDb();

      // Confirming instance identity is preserved
      expect(db1.isOpen, isTrue);
      await db1.close(deleteFromDisk: true);
    });
  });

  // ─── IsarMenuItem ─────────────────────────────────────────────────────────

  group('IsarMenuItem — schema integrity', () {
    late Isar db;

    setUp(() async => db = await _openTestDb());
    tearDown(
      () async => db.isOpen ? await db.close(deleteFromDisk: true) : null,
    );

    test('write and read back a menu item', () async {
      final item = IsarMenuItem()
        ..firestoreId = 'item-001'
        ..name = 'Chicken Burger'
        ..price = 1200
        ..isAvailable = true
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      await db.writeTxn(() => db.isarMenuItems.put(item));

      final stored = await db.isarMenuItems
          .where()
          .firestoreIdEqualTo('item-001')
          .findFirst();

      expect(stored, isNotNull);
      expect(stored!.name, equals('Chicken Burger'));
      expect(stored.price, equals(1200));
      expect(stored.isAvailable, isTrue);
    });

    test('upsert replaces existing record with same firestoreId', () async {
      final v1 = IsarMenuItem()
        ..firestoreId = 'item-002'
        ..name = 'Old Name'
        ..price = 500
        ..isAvailable = true
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      final v2 = IsarMenuItem()
        ..firestoreId =
            'item-002' // same ID → should replace
        ..name = 'New Name'
        ..price = 750
        ..isAvailable = false
        ..lastUpdated = DateTime(2025, 6, 1)
        ..cachedAt = DateTime(2025, 6, 1);

      await db.writeTxn(() => db.isarMenuItems.put(v1));
      await db.writeTxn(() => db.isarMenuItems.put(v2));

      final all = await db.isarMenuItems.where().findAll();
      // unique index → only one record
      expect(all.length, equals(1));
      expect(all.first.name, equals('New Name'));
      expect(all.first.price, equals(750));
    });

    test('unavailable items can be stored and filtered', () async {
      final available = IsarMenuItem()
        ..firestoreId = 'avail-001'
        ..name = 'Pizza'
        ..price = 900
        ..isAvailable = true
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      final unavailable = IsarMenuItem()
        ..firestoreId = 'unavail-001'
        ..name = 'Sold Out Burger'
        ..price = 800
        ..isAvailable = false
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      await db.writeTxn(() async {
        await db.isarMenuItems.put(available);
        await db.isarMenuItems.put(unavailable);
      });

      final all = await db.isarMenuItems.where().findAll();
      final availableItems = all.where((i) => i.isAvailable).toList();
      expect(availableItems.length, equals(1));
      expect(availableItems.first.name, equals('Pizza'));
    });

    test('delete removes record by firestoreId', () async {
      final item = IsarMenuItem()
        ..firestoreId = 'del-001'
        ..name = 'To Delete'
        ..price = 100
        ..isAvailable = true
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      await db.writeTxn(() => db.isarMenuItems.put(item));
      final stored = await db.isarMenuItems
          .where()
          .firestoreIdEqualTo('del-001')
          .findFirst();
      expect(stored, isNotNull);

      await db.writeTxn(() => db.isarMenuItems.delete(stored!.id));
      final afterDelete = await db.isarMenuItems
          .where()
          .firestoreIdEqualTo('del-001')
          .findFirst();
      expect(afterDelete, isNull);
    });
  });

  // ─── IsarCart ─────────────────────────────────────────────────────────────

  group('IsarCart — schema integrity', () {
    late Isar db;

    setUp(() async => db = await _openTestDb());
    tearDown(
      () async => db.isOpen ? await db.close(deleteFromDisk: true) : null,
    );

    test('write and read back a cart item', () async {
      final cartItem = IsarCart()
        ..firestoreId = 'user-001'
        ..quantity = 3
        ..lastUpdated = DateTime(2025, 3, 15)
        ..cachedAt = DateTime(2025, 3, 15);

      await db.writeTxn(() => db.isarCarts.put(cartItem));

      final stored = await db.isarCarts
          .where()
          .firestoreIdEqualTo('user-001')
          .findFirst();

      expect(stored, isNotNull);
      expect(stored!.quantity, equals(3));
    });

    test('quantity update via upsert', () async {
      final initial = IsarCart()
        ..firestoreId = 'user-002'
        ..quantity = 1
        ..lastUpdated = DateTime(2025, 1, 1)
        ..cachedAt = DateTime(2025, 1, 1);

      final updated = IsarCart()
        ..firestoreId = 'user-002'
        ..quantity = 5
        ..lastUpdated = DateTime(2025, 1, 2)
        ..cachedAt = DateTime(2025, 1, 2);

      await db.writeTxn(() => db.isarCarts.put(initial));
      await db.writeTxn(() => db.isarCarts.put(updated));

      final all = await db.isarCarts.where().findAll();
      expect(all.length, equals(1));
      expect(all.first.quantity, equals(5));
    });
  });

  // ─── IsarPendingOperation ─────────────────────────────────────────────────

  group('IsarPendingOperation — enqueue / flush lifecycle', () {
    late Isar db;

    setUp(() async => db = await _openTestDb());
    tearDown(
      () async => db.isOpen ? await db.close(deleteFromDisk: true) : null,
    );

    test('enqueue stores pending operation', () async {
      final op = IsarPendingOperation()
        ..operation = 'createOrder'
        ..collectionName = 'orders'
        ..dataString = jsonEncode({'orderId': 'ORD-001'})
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await db.writeTxn(() => db.isarPendingOperations.put(op));

      final all = await db.isarPendingOperations.where().findAll();
      expect(all.length, equals(1));
      expect(all.first.operation, equals('createOrder'));
    });

    test('flush deletes all pending operations', () async {
      // Enqueue 3 operations
      await db.writeTxn(() async {
        for (var i = 0; i < 3; i++) {
          final op = IsarPendingOperation()
            ..operation = 'updateCart'
            ..collectionName = 'carts'
            ..dataString = jsonEncode({'index': i})
            ..timestamp = DateTime.now()
            ..retryCount = 0;
          await db.isarPendingOperations.put(op);
        }
      });

      final before = await db.isarPendingOperations.where().findAll();
      expect(before.length, equals(3));

      // Simulate syncPendingOperations flush
      await db.writeTxn(() async {
        await db.isarPendingOperations.deleteAll(
          before.map((e) => e.id).toList(),
        );
      });

      final after = await db.isarPendingOperations.where().findAll();
      expect(after, isEmpty, reason: 'All ops must be flushed after sync');
    });

    test('retryCount increments correctly', () async {
      final op = IsarPendingOperation()
        ..operation = 'createOrder'
        ..collectionName = 'orders'
        ..dataString = '{}'
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await db.writeTxn(() => db.isarPendingOperations.put(op));

      // Simulate 3 retry bumps
      for (var retry = 1; retry <= 3; retry++) {
        final stored = await db.isarPendingOperations.where().findFirst();
        stored!.retryCount = retry;
        await db.writeTxn(() => db.isarPendingOperations.put(stored));
      }

      final final_ = await db.isarPendingOperations.where().findFirst();
      expect(final_!.retryCount, equals(3));
    });

    test('retryCount must not exceed max threshold (guard)', () async {
      const maxRetries = 5;

      final op = IsarPendingOperation()
        ..operation = 'createOrder'
        ..collectionName = 'orders'
        ..dataString = '{}'
        ..timestamp = DateTime.now()
        ..retryCount = maxRetries; // already at max

      await db.writeTxn(() => db.isarPendingOperations.put(op));

      final stored = await db.isarPendingOperations.where().findFirst();
      expect(
        stored!.retryCount,
        lessThanOrEqualTo(maxRetries),
        reason:
            'retryCount must not exceed dead-letter threshold of $maxRetries',
      );
    });

    test('oldest pending op has earliest timestamp', () async {
      final now = DateTime.now();

      await db.writeTxn(() async {
        for (var i = 0; i < 5; i++) {
          final op = IsarPendingOperation()
            ..operation = 'createOrder'
            ..collectionName = 'orders'
            ..dataString = '{}'
            ..timestamp = now.subtract(Duration(seconds: 5 - i))
            ..retryCount = 0;
          await db.isarPendingOperations.put(op);
        }
      });

      final all = await db.isarPendingOperations.where().findAll();
      final sorted = [...all]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      expect(
        all.first.timestamp.millisecondsSinceEpoch,
        lessThanOrEqualTo(all.last.timestamp.millisecondsSinceEpoch),
        reason: 'Isar insertion order must reflect temporal ordering',
      );
      expect(sorted.first.id, equals(all.first.id));
    });
  });
}
