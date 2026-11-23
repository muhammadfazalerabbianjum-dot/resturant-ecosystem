import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../../menu/domain/menu_modifier_model.dart';
import '../../menu/domain/menu_item_model.dart';
import '../domain/cart_model.dart';
import '../data/cart_repository.dart';

final cartRepositoryProvider = Provider.autoDispose<CartRepository>((ref) {
  return CartRepository(IsarService.shared(), ref.read(loggerProvider));
});

bool sameCartVariant(CartItemModel a, CartItemModel b) {
  if (a.item.id != b.item.id) return false;
  if (a.selectedOptions.length != b.selectedOptions.length) return false;
  for (int i = 0; i < a.selectedOptions.length; i++) {
    if (a.selectedOptions[i].id != b.selectedOptions[i].id) return false;
  }
  return true;
}

/// W8.9 (04-P2-5): cart hard limits (Law 20 — bounded memory/data).
/// Previously inline literals `10` / `50` with raw-English `Exception`s;
/// now named constants + TYPED exceptions the UI maps to localized copy.
const int kMaxQuantityPerItem = 10;
const int kMaxCartUniqueItems = 50;

/// Adding another unit of the SAME cart line would exceed
/// [kMaxQuantityPerItem]. Carries the limit so the UI renders the number.
class CartItemQuantityLimitException implements Exception {
  CartItemQuantityLimitException(this.maxQuantityPerItem);

  final int maxQuantityPerItem;

  @override
  String toString() =>
      'CartItemQuantityLimitException: max $maxQuantityPerItem per item';
}

/// Adding a NEW cart line would exceed [kMaxCartUniqueItems]. Carries the
/// limit so the UI renders the number.
class CartUniqueItemsLimitException implements Exception {
  CartUniqueItemsLimitException(this.maxUniqueItems);

  final int maxUniqueItems;

  @override
  String toString() =>
      'CartUniqueItemsLimitException: max $maxUniqueItems unique lines';
}

class CartNotifier extends StateNotifier<AsyncValue<CartModel>> {
  final CartRepository _repo;

  CartNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadCart();
  }

  Future<void> loadCart() async {
    try {
      final cart = await _repo.loadCart();
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(
    MenuItemModel item, {
    List<ModifierOption> selectedOptions = const [],
  }) async {
    if (state.value == null) return;

    final currentCart = state.value!;
    final items = List<CartItemModel>.from(currentCart.items);
    final targetItem = CartItemModel(
      item: item,
      selectedOptions: selectedOptions,
    );

    final index = items.indexWhere((i) => sameCartVariant(i, targetItem));

    if (index >= 0) {
      if (items[index].quantity >= kMaxQuantityPerItem) {
        // W8.9 (04-P2-5): TYPED limit exception — the UI maps it to its own
        // localized copy; the raw-English `Exception(String)` is gone.
        throw CartItemQuantityLimitException(kMaxQuantityPerItem);
      }
      items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    } else {
      if (items.length >= kMaxCartUniqueItems) {
        throw CartUniqueItemsLimitException(kMaxCartUniqueItems);
      }
      items.add(targetItem.copyWith(quantity: 1));
    }

    // W8.4 (03-P2-CART-DIVERGENCE): capture the pre-mutation state so a
    // failed Isar save can restore it — the optimistic UI must never show
    // state that is not actually persisted (items a user believes saved
    // currently vanish on restart when the save fails).
    final previous = state;
    final newCart = CartModel(items: items);
    state = AsyncValue.data(newCart);
    try {
      await _repo.saveCart(newCart);
    } catch (_) {
      state = previous; // revert optimistic state — nothing was persisted
      rethrow;
    }
  }

  /// Removes one unit of the EXACT cart line (dish + selected modifiers).
  ///
  /// [selectedOptions] is REQUIRED so a removal can never hit the wrong
  /// variant of the same dish (B2-1 / T4 — two lines with different
  /// modifiers must be removed independently). Callers must pass the full
  /// selected-option list of the line being removed.
  Future<void> removeItem(
    String itemId, {
    required List<ModifierOption> selectedOptions,
  }) async {
    if (state.value == null) return;

    final currentCart = state.value!;
    final items = List<CartItemModel>.from(currentCart.items);

    final index = items.indexWhere((i) {
      if (i.item.id != itemId) return false;
      if (i.selectedOptions.length != selectedOptions.length) return false;
      for (int j = 0; j < selectedOptions.length; j++) {
        if (i.selectedOptions[j].id != selectedOptions[j].id) return false;
      }
      return true;
    });
    if (index >= 0) {
      if (items[index].quantity > 1) {
        // copyWith preserves selectedOptions (Law 25 — never drop modifiers)
        items[index] = items[index].copyWith(
          quantity: items[index].quantity - 1,
        );
      } else {
        items.removeAt(index);
      }
    }

    // W8.4 (03-P2-CART-DIVERGENCE): capture before mutating — see addItem.
    final previous = state;
    final newCart = CartModel(items: items);
    state = AsyncValue.data(newCart);
    try {
      await _repo.saveCart(newCart);
    } catch (_) {
      state = previous; // revert optimistic state — nothing was persisted
      rethrow;
    }
  }

  Future<void> clearCart() async {
    // W8.4 (03-P2-CART-DIVERGENCE): clearCart runs even while state is
    // loading/error (no value guard), so restore the FULL previous
    // AsyncValue on failure — fabricating `data(previous)` would lie when
    // the pre-mutation state was not a loaded cart.
    final previous = state;
    const newCart = CartModel(items: []);
    state = const AsyncValue.data(newCart);
    try {
      await _repo.saveCart(newCart);
    } catch (_) {
      state = previous; // revert optimistic state — nothing was persisted
      rethrow;
    }
  }
}

final cartProvider =
    StateNotifierProvider.autoDispose<CartNotifier, AsyncValue<CartModel>>((
      ref,
    ) {
      final notifier = CartNotifier(ref.watch(cartRepositoryProvider));

      ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
        if (next.value == null && previous?.value != null) {
          notifier.clearCart();
        }
      });

      return notifier;
    });
