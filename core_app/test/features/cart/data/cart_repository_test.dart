import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../../helpers/isar_test_boot.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

/// Helper to create an in-memory Isar instance for testing.
Future<Isar> createTestIsar() async {
  final dir = Directory.systemTemp.createTempSync('isar_test_cart_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  return isar;
}

class TestIsarService extends IsarService {
  final Isar testIsar;

  TestIsarService(this.testIsar) : super.forTesting();

  @override
  Future<Isar> get db async => testIsar;
}

/// Creates a properly initialized IsarCart
IsarCart createIsarCart({
  required String firestoreId,
  required int quantity,
  DateTime? lastUpdated,
}) {
  final now = lastUpdated ?? DateTime.now();
  return IsarCart()
    ..firestoreId = firestoreId
    ..quantity = quantity
    ..lastUpdated = now
    ..cachedAt = now;
}

void main() {
  setUpAll(ensureIsarCoreForTests);
  group('CartRepository — Isar Operations', () {
    late Isar isar;
    late String isarDir;
    late TestIsarService isarService;
    late CartRepository repository;

    setUp(() async {
      isar = await createTestIsar();
      isarDir = isar.directory!;
      isarService = TestIsarService(isar);
      repository = CartRepository(
        isarService,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
    });

    tearDown(() async {
      await isar.close();
      final dir = Directory(isarDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('loadCart returns empty cart when no items in Isar', () async {
      final cart = await repository.loadCart();
      expect(cart.items, isEmpty);
    });

    test('saveCart and loadCart round-trips cart items', () async {
      // First save a menu item so the cart can reference it
      final now = DateTime.now();
      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'menu_1'
            ..name = 'Burger'
            ..price = 999
            ..isAvailable = true
            ..lastUpdated = now
            ..cachedAt = now,
        );
      });

      // Save a cart with one item
      const cart = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(
              id: 'menu_1',
              name: 'Burger',
              priceCents: 999,
              category: 'General',
              isAvailable: true,
            ),
            quantity: 2,
          ),
        ],
      );

      await repository.saveCart(cart);

      // Load it back
      final loaded = await repository.loadCart();
      expect(loaded.items.length, equals(1));
      expect(loaded.items[0].item.name, equals('Burger'));
      expect(loaded.items[0].quantity, equals(2));
    });

    test('saveCart overwrites previous cart contents', () async {
      final now = DateTime.now();
      // Save menu items
      await isar.writeTxn(() async {
        await isar.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'menu_1'
            ..name = 'Burger'
            ..price = 999
            ..isAvailable = true
            ..lastUpdated = now
            ..cachedAt = now,
        );
        await isar.isarMenuItems.put(
          IsarMenuItem()
            ..firestoreId = 'menu_2'
            ..name = 'Pizza'
            ..price = 1299
            ..isAvailable = true
            ..lastUpdated = now
            ..cachedAt = now,
        );
      });

      // Save initial cart with 2 items
      const cart1 = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(
              id: 'menu_1',
              name: 'Burger',
              priceCents: 999,
              category: 'General',
              isAvailable: true,
            ),
            quantity: 1,
          ),
          CartItemModel(
            item: MenuItemModel(
              id: 'menu_2',
              name: 'Pizza',
              priceCents: 1299,
              category: 'General',
              isAvailable: true,
            ),
            quantity: 1,
          ),
        ],
      );
      await repository.saveCart(cart1);

      // Save replacement cart with 1 item
      const cart2 = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(
              id: 'menu_1',
              name: 'Burger',
              priceCents: 999,
              category: 'General',
              isAvailable: true,
            ),
            quantity: 3,
          ),
        ],
      );
      await repository.saveCart(cart2);

      final loaded = await repository.loadCart();
      expect(loaded.items.length, equals(1)); // Overwritten, not merged
      expect(loaded.items[0].quantity, equals(3));
    });

    test('loadCart skips items with no matching menu item', () async {
      // Save a cart item referencing menu that doesn't exist in menu items
      final now = DateTime.now();
      await isar.writeTxn(() async {
        await isar.isarCarts.put(
          createIsarCart(
            firestoreId: 'menu_nonexistent',
            quantity: 5,
            lastUpdated: now,
          ),
        );
      });

      final cart = await repository.loadCart();
      expect(cart.items, isEmpty); // Missing menu item → skipped
    });
  });
}
