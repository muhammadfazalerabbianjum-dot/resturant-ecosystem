import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';

/// Helper to create an in-memory Isar instance for testing.
Future<Isar> createTestIsar() async {
  final dir = Directory.systemTemp.createTempSync('isar_test_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  return isar;
}

void main() {
  setUpAll(ensureIsarCoreForTests);
  group('IsarMenuItem operations', () {
    late Isar isar;
    late String isarDir;

    setUp(() async {
      isar = await createTestIsar();
      isarDir = isar.directory!;
    });

    tearDown(() async {
      await isar.close();
      // Clean up temp directory
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('write and read a menu item', () async {
      final item = IsarMenuItem()
        ..firestoreId = 'menu_1'
        ..name = 'Burger'
        ..price = 999
        ..isAvailable = true
        ..lastUpdated = DateTime.now()
        ..cachedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(item);
      });

      final loaded = await isar.isarMenuItems.where().findFirst();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Burger');
      expect(loaded.price, 999);
      expect(loaded.isAvailable, isTrue);
    });

    test('unique firestoreId replaces existing', () async {
      final item1 = IsarMenuItem()
        ..firestoreId = 'menu_1'
        ..name = 'Burger'
        ..price = 999
        ..isAvailable = true
        ..lastUpdated = DateTime.now()
        ..cachedAt = DateTime.now();

      final item2 = IsarMenuItem()
        ..firestoreId =
            'menu_1' // Same firestoreId
        ..name = 'Pizza'
        ..price = 1299
        ..isAvailable = true
        ..lastUpdated = DateTime.now()
        ..cachedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(item1);
        await isar.isarMenuItems.put(item2);
      });

      final count = await isar.isarMenuItems.where().count();
      expect(count, 1); // Replaced, not duplicated

      final loaded = await isar.isarMenuItems.where().findFirst();
      expect(loaded!.name, 'Pizza');
    });

    test('delete item', () async {
      final item = IsarMenuItem()
        ..firestoreId = 'menu_1'
        ..name = 'Burger'
        ..price = 999
        ..isAvailable = true
        ..lastUpdated = DateTime.now()
        ..cachedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(item);
      });
      await isar.writeTxn(() async {
        await isar.isarMenuItems.delete(item.id);
      });

      final count = await isar.isarMenuItems.where().count();
      expect(count, 0);
    });
  });

  group('IsarPendingOperation', () {
    late Isar isar;
    late String isarDir;

    setUp(() async {
      isar = await createTestIsar();
      isarDir = isar.directory!;
    });

    tearDown(() async {
      await isar.close();
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('write and read pending operation', () async {
      final op = IsarPendingOperation()
        ..operation = 'createOrder'
        ..collectionName = 'orders'
        ..dataString = '{"id":"ord_1","total":1500}'
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await isar.writeTxn(() async {
        await isar.isarPendingOperations.put(op);
      });

      final loaded = await isar.isarPendingOperations.where().findFirst();
      expect(loaded, isNotNull);
      expect(loaded!.operation, 'createOrder');
      expect(loaded.retryCount, 0);
    });

    test('retry count increments', () async {
      final op = IsarPendingOperation()
        ..operation = 'createOrder'
        ..collectionName = 'orders'
        ..dataString = '{}'
        ..timestamp = DateTime.now()
        ..retryCount = 0;

      await isar.writeTxn(() async {
        await isar.isarPendingOperations.put(op);
      });

      // Increment retry
      await isar.writeTxn(() async {
        final loaded = await isar.isarPendingOperations.where().findFirst();
        loaded!.retryCount += 1;
        await isar.isarPendingOperations.put(loaded);
      });

      final updated = await isar.isarPendingOperations.where().findFirst();
      expect(updated!.retryCount, 1);
    });
  });

  group('IsarService integration', () {
    test('evictStaleCache handles empty database', () async {
      final isar = await createTestIsar();
      final isarDir = isar.directory!;
      final service = IsarService.forTesting();
      await service.evictStaleCache(isar);
      final menuCount = await isar.isarMenuItems.where().count();
      expect(menuCount, 0);
      await isar.close();
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('evictStaleCache removes old menu items', () async {
      final isar = await createTestIsar();
      final isarDir = isar.directory!;
      final oldItem = IsarMenuItem()
        ..firestoreId = 'old_item'
        ..name = 'Old Burger'
        ..price = 500
        ..isAvailable = true
        ..lastUpdated = DateTime.now().subtract(const Duration(hours: 48))
        ..cachedAt = DateTime.now().subtract(const Duration(hours: 48));

      final freshItem = IsarMenuItem()
        ..firestoreId = 'fresh_item'
        ..name = 'Fresh Burger'
        ..price = 999
        ..isAvailable = true
        ..lastUpdated = DateTime.now()
        ..cachedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(oldItem);
        await isar.isarMenuItems.put(freshItem);
      });

      final service = IsarService.forTesting();
      await service.evictStaleCache(isar);

      final remaining = await isar.isarMenuItems.where().findAll();
      expect(remaining.length, 1);
      expect(remaining.first.name, 'Fresh Burger');
      await isar.close();
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
  });

  // ─── W8.9 (T-3): schema-version gate + recovery + shared() unification ────
  //
  // These tests run the REAL `openDB()` against REAL Isar stores in temp
  // directories: `IsarService.forTesting` replaces the production
  // `path_provider` documents directory with a per-test temp dir, so no
  // platform channel is needed (the gate, the backstop and the wipe/recovery
  // path are exercised end-to-end, not mocked).
  group('IsarService W8.9 — schema gate, recovery, shared()', () {
    final LoggerService logger = LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    );

    void cleanupDir(String path) {
      final dir = Directory(path);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }

    /// Seeds a store directly (as a previous app build would have left it)
    /// and closes it, leaving its files on disk for `openDB()` to open.
    Future<void> seedStore(
      String dirPath,
      String name, {
      bool withQueueRow = false,
    }) async {
      final seeded = await Isar.open(
        [
          IsarMenuItemSchema,
          IsarCartSchema,
          IsarPendingOperationSchema,
          IsarDeadLetterSchema,
        ],
        directory: dirPath,
        name: name,
        inspector: false,
      );
      await seeded.writeTxn(() async {
        await seeded.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'seed_m'
            ..name = 'Seed'
            ..price = 100
            ..isAvailable = true
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
        await seeded.isarCarts.put(
          IsarCart()
            ..firestoreId = 'seed_c'
            ..quantity = 1
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
        if (withQueueRow) {
          await seeded.isarPendingOperations.put(
            IsarPendingOperation()
              ..operation = 'createOrder'
              ..collectionName = 'orders'
              ..dataString = '{"total":100}'
              ..timestamp = DateTime.now()
              ..retryCount = 0,
          );
        }
      });
      await seeded.close();
    }

    test('shared() memoizes one service per name (T-1 unification)', () {
      final a = IsarService.shared();
      final b = IsarService.shared();
      expect(
        identical(a, b),
        isTrue,
        reason: 'the SAME service must back every production call site',
      );
      final other = IsarService.shared(name: 'shared_other_t3');
      expect(identical(a, other), isFalse);
      expect(a.instanceName, Isar.defaultName);
      expect(other.instanceName, 'shared_other_t3');
    });

    test(
      'openDB attaches to an ALREADY-OPEN instance (backstop guard)',
      () async {
        final dir = Directory.systemTemp.createTempSync('isar_backstop_t3_');
        addTearDown(() => cleanupDir(dir.path));
        const name = 'backstop_t3';
        final direct = await Isar.open(
          [
            IsarMenuItemSchema,
            IsarCartSchema,
            IsarPendingOperationSchema,
            IsarDeadLetterSchema,
          ],
          directory: dir.path,
          name: name,
          inspector: false,
        );
        final svc = IsarService.forTesting(null, logger, name, dir.path);
        final viaService = await svc.openDB();
        expect(
          identical(direct, viaService),
          isTrue,
          reason:
              'opening an already-open instance must return IT, '
              'never crash (the old TOCTOU loser path)',
        );
        await direct.close();
      },
    );

    test(
      'version bump wipes ONLY cache collections, NEVER the queue (T-3)',
      () async {
        final dir = Directory.systemTemp.createTempSync('isar_gate_t3_');
        addTearDown(() => cleanupDir(dir.path));
        const name = 'gate_t3';
        await seedStore(dir.path, name, withQueueRow: true);

        // Stored version 0 ≠ current kIsarSchemaVersion (1) → gate wipes cache.
        SharedPreferences.setMockInitialValues({kIsarSchemaVersionPref: 0});
        final svc = IsarService.forTesting(null, logger, name, dir.path);
        final isar = await svc.openDB();

        expect(
          await isar.isarMenuItems.where().count(),
          0,
          reason:
              'menu cache is resyncable → wiped by the gate '
              '(timestamps are FRESH, so TTL eviction alone would have '
              'kept them — only the gate removes them)',
        );
        expect(
          await isar.isarCarts.where().count(),
          0,
          reason: 'cart cache is resyncable → wiped by the gate',
        );
        expect(
          await isar.isarPendingOperations.where().count(),
          1,
          reason: 'NEVER wipe the pending-operations queue',
        );
        expect(
          (await SharedPreferences.getInstance()).getInt(
            kIsarSchemaVersionPref,
          ),
          kIsarSchemaVersion,
          reason: 'the new version must be stamped after the wipe',
        );
        await isar.close();
      },
    );

    test('fresh install adopts the version WITHOUT wiping (T-3)', () async {
      final dir = Directory.systemTemp.createTempSync('isar_adopt_t3_');
      addTearDown(() => cleanupDir(dir.path));
      const name = 'adopt_t3';
      await seedStore(dir.path, name);

      // No stored version (fresh install) → adopt, no wipe.
      SharedPreferences.setMockInitialValues({});
      final svc = IsarService.forTesting(null, logger, name, dir.path);
      final isar = await svc.openDB();

      expect(
        await isar.isarMenuItems.where().count(),
        1,
        reason: 'no version transition → no wipe',
      );
      expect(
        (await SharedPreferences.getInstance()).getInt(kIsarSchemaVersionPref),
        kIsarSchemaVersion,
      );
      await isar.close();
    });

    test(
      'schema-classified open failure recovers via file wipe (T-3)',
      () async {
        final dir = Directory.systemTemp.createTempSync('isar_recover_t3_');
        addTearDown(() => cleanupDir(dir.path));
        const name = 'recover_t3';
        // A store file that is NOT a valid Isar database — the same
        // class of hard-open failure as the audit-02 foreign-schema brick.
        File(
          '${dir.path}/$name.isar',
        ).writeAsBytesSync(List<int>.filled(4097, 0xAB));
        File(
          '${dir.path}/$name.isar.lock',
        ).writeAsBytesSync(List<int>.filled(64, 0xAB));

        final svc = IsarService.forTesting(null, logger, name, dir.path);
        // Must NOT throw: the recovery path wipes the broken files and reopens.
        final isar = await svc.openDB();
        expect(await isar.isarMenuItems.where().count(), 0);
        // The recovered store is fully usable.
        await isar.writeTxn(() async {
          await isar.isarMenuItems.put(
            IsarMenuItem()
              ..firestoreId = 'post_recovery'
              ..name = 'OK'
              ..price = 1
              ..isAvailable = true
              ..lastUpdated = DateTime.now()
              ..cachedAt = DateTime.now(),
          );
        });
        expect(await isar.isarMenuItems.where().count(), 1);
        expect(
          File('${dir.path}/$name.isar').lengthSync(),
          isNot(4097),
          reason: 'the garbage store file was replaced by a real one',
        );
        await isar.close();
      },
    );

    test('two instances sharing one directory stay isolated (T-1)', () async {
      final dir = Directory.systemTemp.createTempSync('isar_iso_t3_');
      addTearDown(() => cleanupDir(dir.path));
      final cacheSvc = IsarService.forTesting(
        null,
        logger,
        'iso_cache_t3',
        dir.path,
      );
      final queueSvc = IsarService.forTesting(
        null,
        logger,
        'iso_queue_t3',
        dir.path,
      );
      final cacheDb = await cacheSvc.openDB();
      final queueDb = await queueSvc.openDB();
      expect(identical(cacheDb, queueDb), isFalse);
      await cacheDb.writeTxn(() async {
        await cacheDb.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'iso_m'
            ..name = 'OnlyInCache'
            ..price = 1
            ..isAvailable = true
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
      });
      expect(await cacheDb.isarMenuItems.where().count(), 1);
      expect(
        await queueDb.isarMenuItems.where().count(),
        0,
        reason:
            'separate instance names → separate stores, even in the '
            'same directory',
      );
      await cacheDb.close();
      await queueDb.close();
    });
  });
}
