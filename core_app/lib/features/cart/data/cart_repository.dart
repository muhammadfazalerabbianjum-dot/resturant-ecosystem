import 'dart:convert';

import 'package:core/core.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:isar_community/isar.dart';

class CartRepository {
  final IsarService _isar;
  final LoggerService _logger;

  CartRepository(this._isar, this._logger);

  Future<CartModel> loadCart() async {
    try {
      final db = await _isar.db;
      final isarCarts = await db.isarCarts.where().findAll();
      final List<CartItemModel> items = [];

      for (var ic in isarCarts) {
        final isarMenu = await db.isarMenuItems
            .where()
            .firestoreIdEqualTo(ic.firestoreId)
            .findFirst();
        if (isarMenu != null) {
          // Rebuild the full modifier selections (Law 25) — never drop them.
          final List<ModifierOption> selectedOptions = [];
          try {
            final decoded = jsonDecode(ic.selectedOptionsJson) as List<dynamic>;
            selectedOptions.addAll(
              decoded.map(
                (e) => ModifierOption.fromJson(e as Map<String, dynamic>),
              ),
            );
          } catch (_) {
            // Malformed legacy cart row — treat as no options. cart row
            // will be replaced on the next save.
          }

          final menuItem = MenuItemModel(
            id: isarMenu.firestoreId,
            name: isarMenu.name,
            priceCents: isarMenu.price,
            imageUrl: isarMenu.imageUrl,
            // Persisted category — the menu repository resolves it from the
            // Firestore doc (category or first tag) and stores it on the cache
            // row (B2-2: never stamp a fake 'General' on rehydrated carts).
            category: isarMenu.category,
            isAvailable: isarMenu.isAvailable,
          );
          items.add(
            CartItemModel(
              item: menuItem,
              quantity: ic.quantity,
              selectedOptions: selectedOptions,
            ),
          );
        }
      }
      return CartModel(items: items);
    } catch (e, stack) {
      await _logger.error(e, 'loadCart failed', stack: stack);
      rethrow;
    }
  }

  Future<void> saveCart(CartModel cart) async {
    try {
      final db = await _isar.db;
      await db.writeTxn(() async {
        await db.isarCarts.clear(); // Remove obsolete items
        for (var cartItem in cart.items) {
          final isarCart = IsarCart()
            ..firestoreId = cartItem.item.id
            ..quantity = cartItem.quantity
            ..selectedOptionsJson = jsonEncode(
              cartItem.selectedOptions.map((o) => o.toJson()).toList(),
            )
            ..lastUpdated = DateTime.now()
            ..cachedAt = DateTime.now();
          await db.isarCarts.put(isarCart);
        }
      });
    } catch (e, stack) {
      await _logger.error(e, 'saveCart failed', stack: stack);
      rethrow;
    }
  }
}
