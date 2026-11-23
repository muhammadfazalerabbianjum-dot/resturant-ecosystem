import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';

void main() {
  group('cartRepositoryProvider', () {
    test('is defined', () {
      expect(cartRepositoryProvider, isNotNull);
    });

    test('provider type is Provider.autoDispose', () {
      expect(
        cartRepositoryProvider.runtimeType.toString(),
        contains('Provider'),
      );
    });

    test('provider has autoDispose suffix', () {
      expect(
        cartRepositoryProvider.runtimeType.toString(),
        contains('AutoDispose'),
      );
    });
  });

  group('cartProvider', () {
    test('is defined', () {
      expect(cartProvider, isNotNull);
    });

    test('provider type is StateNotifierProvider', () {
      expect(
        cartProvider.runtimeType.toString(),
        contains('StateNotifierProvider'),
      );
    });

    test('provider has autoDispose modifier', () {
      expect(cartProvider.runtimeType.toString(), contains('AutoDispose'));
    });
  });

  group('CartNotifier - Static checks', () {
    test('CartNotifier class exists and can be referenced', () {
      expect(CartNotifier, isNotNull);
    });

    test('CartNotifier is a Type', () {
      expect(CartNotifier, isA<Type>());
    });
  });

  group('CartNotifier - add/remove/clear behavior (PERF-3 T-1)', () {
    late _RecordingOkRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _RecordingOkRepository();
      container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
      );
      addTearDown(container.dispose);
    });

    /// Keeps the autoDispose provider alive and waits until loadCart resolves
    /// (same keep-alive requirement as the revert group below).
    Future<void> pumpLoaded() async {
      container.listen(cartProvider, (_, __) {});
      for (
        var i = 0;
        i < 100 && container.read(cartProvider).value == null;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(cartProvider).value, isNotNull);
    }

    test(
      'addItem: same variant merges quantity; selectedOptions optional',
      () async {
        await pumpLoaded();
        final notifier = container.read(cartProvider.notifier);
        await notifier.addItem(_FailingSaveRepository.newItem('item_1'));
        await notifier.addItem(_FailingSaveRepository.newItem('item_1'));

        final cart = container.read(cartProvider).value!;
        expect(cart.items, hasLength(1));
        expect(cart.items.single.item.id, 'item_1');
        expect(
          cart.items.single.quantity,
          2,
          reason: 'the same dish+options variant must merge, not duplicate',
        );
      },
    );

    test(
      'addItem with different selectedOptions: variants stay SEPARATE lines',
      () async {
        await pumpLoaded();
        final notifier = container.read(cartProvider.notifier);
        await notifier.addItem(
          _FailingSaveRepository.newItem('item_1'),
          selectedOptions: const [ModifierOption(id: 'opt_1')],
        );
        await notifier.addItem(
          _FailingSaveRepository.newItem('item_1'),
          selectedOptions: const [],
        );

        final cart = container.read(cartProvider).value!;
        expect(
          cart.items,
          hasLength(2),
          reason:
              'B2-1: modifier variants of the same dish are independent lines',
        );
      },
    );

    test(
      'removeItem: decrements one unit of the exact line; last unit removes it',
      () async {
        await pumpLoaded();
        final notifier = container.read(cartProvider.notifier);
        await notifier.addItem(_FailingSaveRepository.newItem('item_2'));
        await notifier.addItem(_FailingSaveRepository.newItem('item_2'));

        await notifier.removeItem('item_2', selectedOptions: const []);
        expect(
          container.read(cartProvider).value!.items.single.quantity,
          1,
          reason: 'one remove call decrements exactly one unit',
        );

        await notifier.removeItem('item_2', selectedOptions: const []);
        expect(
          container.read(cartProvider).value!.items,
          isEmpty,
          reason: 'removing the last unit drops the line',
        );
      },
    );

    test('clearCart: empties the cart AND persists the empty cart', () async {
      await pumpLoaded();
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(_FailingSaveRepository.newItem('item_3'));
      await notifier.clearCart();

      expect(container.read(cartProvider).value!.items, isEmpty);
      expect(
        repo.savedCarts.last.items,
        isEmpty,
        reason: 'the empty cart must be persisted (restart-safe clear)',
      );
    });

    test(
      'mutators are async and Future<void>-typed (public contract)',
      () async {
        await pumpLoaded();
        final notifier = container.read(cartProvider.notifier);

        final f1 = notifier.addItem(_FailingSaveRepository.newItem('item_4'));
        expect(f1, isA<Future<void>>());
        await f1;

        final f2 = notifier.removeItem('item_4', selectedOptions: const []);
        expect(f2, isA<Future<void>>());
        await f2;

        final f3 = notifier.clearCart();
        expect(f3, isA<Future<void>>());
        await f3;
      },
    );
  });

  group('CartNotifier — optimistic revert (T-4, STATE-1 / W8.4)', () {
    late _FailingSaveRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FailingSaveRepository();
      container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
      );
      addTearDown(container.dispose);
    });

    /// Flushes the constructor-triggered loadCart() until the state is data.
    /// A keep-alive listener is REQUIRED: cartProvider is autoDispose, and a
    /// bare `container.read` would dispose the notifier between reads (its
    /// loadCart state would never be observed).
    Future<void> pumpLoaded(ProviderContainer target) async {
      target.listen(cartProvider, (_, __) {});
      for (var i = 0; i < 100 && target.read(cartProvider).value == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        target.read(cartProvider).value,
        isNotNull,
        reason: 'fake loadCart must resolve to the seeded cart',
      );
    }

    test(
      'addItem: failed saveCart reverts the optimistic state to previous',
      () async {
        await pumpLoaded(container);
        final before = container.read(cartProvider).value!;
        expect(before.items.length, 1);
        expect(before.items.first.item.id, 'item_0');

        await expectLater(
          container
              .read(cartProvider.notifier)
              .addItem(_FailingSaveRepository.newItem('item_1')),
          throwsA(isA<Exception>()),
        );

        final after = container.read(cartProvider).value!;
        expect(
          after.items.length,
          1,
          reason: 'state must be reverted to the pre-mutation cart',
        );
        expect(after.items.first.item.id, 'item_0');
        expect(repo.saveCalls, 1);
      },
    );

    test(
      'removeItem: failed saveCart reverts — the line is NOT lost',
      () async {
        await pumpLoaded(container);

        await expectLater(
          container
              .read(cartProvider.notifier)
              .removeItem('item_0', selectedOptions: const []),
          throwsA(isA<Exception>()),
        );

        final after = container.read(cartProvider).value!;
        expect(
          after.items.length,
          1,
          reason: 'reverted — the user still has the item',
        );
        expect(after.items.first.item.id, 'item_0');
        expect(repo.saveCalls, 1);
      },
    );

    test(
      'clearCart: failed saveCart reverts — items a user believes saved do not vanish',
      () async {
        await pumpLoaded(container);

        await expectLater(
          container.read(cartProvider.notifier).clearCart(),
          throwsA(isA<Exception>()),
        );

        final after = container.read(cartProvider).value!;
        expect(
          after.items.length,
          1,
          reason: 'the cart must be restored (restart would otherwise lose it)',
        );
        expect(after.items.first.item.id, 'item_0');
        expect(repo.saveCalls, 1);
      },
    );

    test('successful saves do not revert (control)', () async {
      final okRepo = _RecordingOkRepository();
      final okContainer = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(okRepo),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
      );
      addTearDown(okContainer.dispose);
      await pumpLoaded(okContainer);

      await okContainer
          .read(cartProvider.notifier)
          .addItem(_FailingSaveRepository.newItem('item_1'));

      final cart = okContainer.read(cartProvider).value!;
      expect(
        cart.items.length,
        1,
        reason:
            'with a successful save the optimistic add persists (no revert)',
      );
      expect(cart.items.first.item.id, 'item_1');
      expect(okRepo.saveCalls, 1, reason: 'the successful save must have run');
    });
  });
}

/// Fake [CartRepository] whose saveCart ALWAYS fails (T-4). The seed cart
/// carries one line (item_0) so every revert assertion checks against a
/// non-trivial previous state.
class _FailingSaveRepository implements CartRepository {
  int saveCalls = 0;

  static MenuItemModel newItem(String id) => MenuItemModel(
    id: id,
    name: 'Item $id',
    priceCents: 500,
    imageUrl: '',
    category: 'Test',
    isAvailable: true,
  );

  @override
  Future<CartModel> loadCart() async => CartModel(
    items: [
      CartItemModel(
        item: newItem('item_0').copyWith(priceCents: 1000),
        quantity: 1,
      ),
    ],
  );

  @override
  Future<void> saveCart(CartModel cart) async {
    saveCalls++;
    throw Exception('simulated Isar write failure');
  }
}

/// Fake [CartRepository] whose saveCart succeeds (T-4 control group; also the
/// recording backend for the PERF-3 T-1 behavior group).
class _RecordingOkRepository implements CartRepository {
  int saveCalls = 0;
  final savedCarts = <CartModel>[];

  @override
  Future<CartModel> loadCart() async => const CartModel(items: []);

  @override
  Future<void> saveCart(CartModel cart) async {
    saveCalls++;
    savedCarts.add(cart);
  }
}
