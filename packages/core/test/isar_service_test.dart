import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/isar_native.dart';
import 'helpers/recording_logger.dart';

/// CORE-COV Tier-2 CACHE suite (STATE-4 / W8.9): REAL temp-dir Isar-backed
/// proofs of the lazy memoized open (no constructor double-open race), the
/// `shared()` per-name memoization, the pending-order queue, the atomic
/// clearAll (rollback probe), the schema-version gate (cache wipe NEVER
/// touches pending ops / dead letters), and the TTL/cap eviction.
void main() {
  late Directory temp;

  setUpAll(ensureIsarCoreForTests);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('core_cov_isar');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  IsarService service(String name, [RecordingLogger? logger]) =>
      IsarService.forTesting(
        null,
        logger ?? RecordingLogger(),
        name,
        temp.path,
      );

  IsarMenuItem menu(String firestoreId, {DateTime? cachedAt}) => IsarMenuItem()
    ..firestoreId = firestoreId
    ..name = 'Dish $firestoreId'
    ..price = 1999
    ..isAvailable = true
    ..lastUpdated = DateTime(2026, 1, 1)
    ..cachedAt = cachedAt ?? DateTime.now();

  IsarPendingOperation op(String id, {DateTime? at}) => IsarPendingOperation()
    ..operation = 'createOrder'
    ..collectionName = 'orders'
    ..dataString = '{"id":"$id"}'
    ..timestamp = at ?? DateTime.now()
    ..retryCount = 0;

  IsarDeadLetter dead(String id) => IsarDeadLetter()
    ..operation = 'createOrder'
    ..collectionName = 'orders'
    ..dataString = '{"id":"$id"}'
    ..timestamp = DateTime.now()
    ..retryCount = 3
    ..lastError = 'boom';

  group('IsarService open lifecycle', () {
    test(
      'open is LAZY on first db read and memoized (W8.9 race removal)',
      () async {
        final svc = service('lazy-x');
        // Constructing the service must NOT open anything.
        expect(Isar.getInstance('lazy-x'), isNull);

        final db1 = await svc.db;
        final db2 = await svc.db;

        expect(identical(db1, db2), isTrue, reason: 'one memoized open future');
        expect(Isar.getInstance('lazy-x'), same(db1));
        await db1.close();
      },
    );

    test('shared() memoizes ONE service per instance name', () {
      final a = IsarService.shared(name: 'shared-core-cov');
      final b = IsarService.shared(name: 'shared-core-cov');
      final other = IsarService.shared(name: 'shared-core-cov-2');

      expect(identical(a, b), isTrue);
      expect(identical(a, other), isFalse);
    });
  });

  group('pending-order queue', () {
    test(
      'getPendingOrders returns queued ops; markOrdersSynced deletes them',
      () async {
        final svc = service('ops-x');
        final db = await svc.db;
        await db.writeTxn(() async {
          await db.isarPendingOperations.put(op('o1'));
        });

        final ops = await svc.getPendingOrders();

        expect(ops, hasLength(1));
        expect(ops.single.operation, 'createOrder');
        expect(ops.single.dataString, '{"id":"o1"}');

        await svc.markOrdersSynced(<dynamic>[ops.single.id]);
        expect(await svc.getPendingOrders(), isEmpty);
        await db.close();
      },
    );
  });

  group('clearAll — atomic sign-out purge (P0-07)', () {
    test('purges every user-scoped collection in ONE transaction', () async {
      final svc = service('purge-x');
      final db = await svc.db;
      await db.writeTxn(() async {
        await db.isarPendingOperations.put(op('o1'));
        await db.isarMenuItems.put(menu('m1'));
        await db.isarCarts.put(
          IsarCart()
            ..firestoreId = 'c1'
            ..quantity = 2
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
        await db.isarDeadLetters.put(dead('d1'));
      });

      await svc.clearAll();

      expect(await db.isarPendingOperations.count(), 0);
      expect(await db.isarMenuItems.count(), 0);
      expect(await db.isarCarts.count(), 0);
      expect(await db.isarDeadLetters.count(), 0);
      await db.close();
    });

    test(
      'a mid-transaction fault ROLLS BACK the purge (fail-closed)',
      () async {
        final svc = service('rollback-x');
        final db = await svc.db;
        await db.writeTxn(() async {
          await db.isarPendingOperations.put(op('o1'));
          await db.isarMenuItems.put(menu('m1'));
        });

        await expectLater(
          svc.clearAll(atomicityProbe: () => throw StateError('probe')),
          throwsA(isA<StateError>()),
        );

        // NOTHING reached disk — no half-purged sign-out.
        expect(await svc.getPendingOrders(), hasLength(1));
        expect(await db.isarMenuItems.where().findAll(), hasLength(1));
        await db.close();
      },
    );
  });
  group('schema-version gate (STATE-4 / W8.9 P-9)', () {
    test(
      'fresh install (no pref) adopts the shipped version WITHOUT wiping',
      () async {
        final svc = service('fresh-x');
        final db = await svc.db;
        await db.writeTxn(() async {
          await db.isarMenuItems.put(menu('m1'));
          await db.isarPendingOperations.put(op('o1'));
        });
        await db.close();

        // Reopen the SAME directory/name — the persisted store must survive.
        final svc2 = service('fresh-x');
        final db2 = await svc2.db;

        expect(await db2.isarMenuItems.where().findAll(), hasLength(1));
        expect(await db2.isarPendingOperations.where().findAll(), hasLength(1));
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(kIsarSchemaVersionPref),
          kIsarSchemaVersion,
          reason: 'the shipped schema IS this version\'s schema',
        );
        await db2.close();
      },
    );

    test(
      'a KNOWN bump wipes ONLY cache collections — queues SURVIVE',
      () async {
        final logger = RecordingLogger();
        final svc = service('bump-x', logger);
        final db = await svc.db;
        await db.writeTxn(() async {
          await db.isarMenuItems.put(menu('m1'));
          await db.isarCarts.put(
            IsarCart()
              ..firestoreId = 'c1'
              ..quantity = 1
              ..lastUpdated = DateTime.now()
              ..cachedAt = DateTime.now(),
          );
          await db.isarPendingOperations.put(op('o1'));
          await db.isarDeadLetters.put(dead('d1'));
        });
        await db.close();

        // Simulate the device having persisted a NEWER schema version.
        SharedPreferences.setMockInitialValues(<String, Object>{
          kIsarSchemaVersionPref: kIsarSchemaVersion + 1,
        });
        final svc2 = service('bump-x', logger);
        final db2 = await svc2.db;

        // Resyncable cache wiped; queues NEVER touched (P-9).
        expect(await db2.isarMenuItems.where().findAll(), isEmpty);
        expect(await db2.isarCarts.where().findAll(), isEmpty);
        expect(await db2.isarPendingOperations.where().findAll(), hasLength(1));
        expect(await db2.isarDeadLetters.where().findAll(), hasLength(1));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(kIsarSchemaVersionPref), kIsarSchemaVersion);
        expect(
          logger.infos,
          contains('IsarService_SCHEMA_VERSION_cache_wiped'),
        );
        await db2.close();
      },
    );
  });

  group('evictStaleCache', () {
    test(
      'drops menu items past the 24h TTL, keeps fresh + dead letters',
      () async {
        final svc = service('ttl-x');
        final db = await svc.db;
        final now = DateTime.now();
        await db.writeTxn(() async {
          await db.isarMenuItems.put(
            menu('old', cachedAt: now.subtract(const Duration(hours: 25))),
          );
          await db.isarMenuItems.put(menu('fresh', cachedAt: now));
          await db.isarDeadLetters.put(dead('d1'));
        });

        await svc.evictStaleCache(db);

        final remaining = await db.isarMenuItems.where().findAll();
        expect(remaining.map((m) => m.firestoreId).toList(), <String>['fresh']);
        expect(await db.isarDeadLetters.where().findAll(), hasLength(1));
        await db.close();
      },
    );

    test(
      'pending-ops cap evicts OLDEST beyond kMaxPendingOps (FIFO)',
      () async {
        final svc = service('cap-x');
        final db = await svc.db;
        final base = DateTime(2026, 1, 1);
        await db.writeTxn(() async {
          for (var i = 0; i < IsarService.kMaxPendingOps + 5; i++) {
            await db.isarPendingOperations.put(
              op('o$i', at: base.add(Duration(seconds: i))),
            );
          }
        });

        await svc.evictStaleCache(db);

        final remaining = await db.isarPendingOperations.where().findAll();
        expect(remaining, hasLength(IsarService.kMaxPendingOps));
        final oldest = remaining
            .map((o) => o.timestamp)
            .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
        expect(oldest, base.add(const Duration(seconds: 5)));
        await db.close();
      },
    );
  });
}
