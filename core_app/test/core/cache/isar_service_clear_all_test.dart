import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:core/core.dart';

/// B6-6 — IsarService.clearAll() purge-all-4 behavior test.
///
/// Verifies the P0-07 cross-user-leak guard supports B1-11/T7:
///  - clearing menu items + carts + pending operations + dead letters in ONE
///    atomic transaction;
///  - fail-closed: a mid-transaction fault rolls the purge back, so a sign-out
///    failure can NEVER leave half the previous user's cache behind.
void main() {
  setUpAll(ensureIsarCoreForTests);
  late Isar isar;
  late String isarDir;
  late IsarService service;
  late TestErrorCapturingLogger logger;

  setUp(() async {
    isarDir = Directory.systemTemp.createTempSync('isar_clearall_').path;
    isar = await Isar.open([
      IsarMenuItemSchema,
      IsarCartSchema,
      IsarPendingOperationSchema,
      IsarDeadLetterSchema,
    ], directory: isarDir);
    logger = TestErrorCapturingLogger();
    service = IsarService.forTesting(Future.value(isar), logger);
  });

  tearDown(() async {
    await isar.close();
    final dir = Directory(isarDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<void> seedAllFour({int perCollection = 2}) async {
    await isar.writeTxn(() async {
      for (var i = 0; i < perCollection; i++) {
        await isar.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'm_$i'
            ..name = 'Item $i'
            ..price = 1000 + i
            ..isAvailable = true
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
        await isar.isarCarts.put(
          IsarCart()
            ..firestoreId = 'cart_$i'
            ..quantity = i + 1
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now(),
        );
        await isar.isarPendingOperations.put(
          IsarPendingOperation()
            ..operation = 'createOrder'
            ..collectionName = 'orders'
            ..dataString = '{"id":"ord_$i"}'
            ..timestamp = DateTime.now()
            ..retryCount = 0,
        );
        await isar.isarDeadLetters.put(
          IsarDeadLetter()
            ..operation = 'createOrder'
            ..collectionName = 'orders'
            ..dataString = '{"id":"dl_$i"}'
            ..timestamp = DateTime.now()
            ..retryCount = 5
            ..lastError = 'boom',
        );
      }
    });
  }

  test(
    'clearAll() purges all four user-scoped collections in one transaction',
    () async {
      await seedAllFour();

      expect(await isar.isarMenuItems.count(), 2);
      expect(await isar.isarCarts.count(), 2);
      expect(await isar.isarPendingOperations.count(), 2);
      expect(await isar.isarDeadLetters.count(), 2);

      await service.clearAll();

      expect(
        await isar.isarMenuItems.count(),
        0,
        reason: 'menu items must be purged',
      );
      expect(await isar.isarCarts.count(), 0, reason: 'carts must be purged');
      expect(
        await isar.isarPendingOperations.count(),
        0,
        reason: 'pending ops must be purged',
      );
      expect(
        await isar.isarDeadLetters.count(),
        0,
        reason: 'dead letters must be purged',
      );
    },
  );

  test('clearAll() fails closed — a mid-transaction fault rolls back EVERY '
      'collection (nothing half cleared)', () async {
    await seedAllFour();

    expect(
      () => service.clearAll(
        atomicityProbe: () async => throw Exception('injected mid-transaction'),
      ),
      throwsA(isA<Exception>()),
    );

    // Fail-closed: the single writeTxn rolled the whole purge back.
    expect(await isar.isarMenuItems.count(), 2, reason: 'no partial purge');
    expect(await isar.isarCarts.count(), 2, reason: 'no partial purge');
    expect(
      await isar.isarPendingOperations.count(),
      2,
      reason: 'no partial purge',
    );
    expect(await isar.isarDeadLetters.count(), 2, reason: 'no partial purge');
    // The injected fault was logged, not swallowed.
    expect(logger.errorMessages, isNotEmpty);
  });

  test('clearAll() on an already-empty DB succeeds (idempotent)', () async {
    await service.clearAll();
    expect(await isar.isarMenuItems.count(), 0);
    expect(await isar.isarCarts.count(), 0);
    expect(await isar.isarPendingOperations.count(), 0);
    expect(await isar.isarDeadLetters.count(), 0);
  });
}

/// A LoggerService double that captures errors in memory (no file/Crashlytics).
class TestErrorCapturingLogger extends LoggerService {
  final List<String> errorMessages = [];

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    errorMessages.add('$message: $error');
  }
}
