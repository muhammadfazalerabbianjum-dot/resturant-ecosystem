// P8 W4 (A-4 / T4) â€” menu_provider behaviour pins (straggler: 53% before).
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/menu/data/menu_repository.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/menu_provider.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';

import '../../../helpers/test_helpers.dart';

/// A repository double: the provider owns the wiring, the repository owns the
/// fetch â€” this isolates the wiring/precedence under test.
class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository(this.items)
    : super(FakeFirebaseFirestore(), IsarService.shared(), FakeLogger());

  final List<MenuItemModel> items;

  @override
  Future<List<MenuItemModel>> getMenuItems() async => items;
}

MenuItemModel _item(String id, String name, int priceCents) =>
    MenuItemModel(id: id, name: name, priceCents: priceCents);

void main() {
  group('menuRepositoryProvider', () {
    test(
      'resolves a MenuRepository wired to the injected Firestore and logger',
      () {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            // The real logger reaches path_provider (no plugin in unit tests).
            loggerProvider.overrideWithValue(FakeLogger()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(menuRepositoryProvider), isA<MenuRepository>());
      },
    );
  });

  group('menuItemsProvider', () {
    test('returns exactly the items the repository fetched', () async {
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          menuRepositoryProvider.overrideWith(
            (ref) => _FakeMenuRepository([_item('a', 'Soup', 500)]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(menuItemsProvider.future);

      expect(items.single.id, 'a');
      expect(items.single.name, 'Soup');
      expect(items.single.priceCents, 500);
    });
  });

  group('menuItemByIdProvider', () {
    test(
      'prefers the live merged item over the cached repository copy',
      () async {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            menuRepositoryProvider.overrideWith(
              (ref) => _FakeMenuRepository([_item('x', 'Cached', 100)]),
            ),
            mergedMenuProvider.overrideWith(
              (ref) => Stream.value([_item('x', 'Live', 200)]),
            ),
          ],
        );
        addTearDown(container.dispose);

        // LEDGER:PERF-2 (autoDispose trap): a bare read leaves these sources
        // listener-less, so they must be held open for the test to see data.
        final mergedSub = container.listen(mergedMenuProvider, (_, __) {});
        final itemsSub = container.listen(menuItemsProvider, (_, __) {});
        addTearDown(mergedSub.close);
        addTearDown(itemsSub.close);
        await container.read(mergedMenuProvider.future);
        await container.read(menuItemsProvider.future);

        final item = container.read(menuItemByIdProvider('x'));

        expect(item, isNotNull);
        expect(item!.name, 'Live');
        expect(item.priceCents, 200);
      },
    );

    test('falls back to the repository copy when the merged stream does not '
        'carry the id', () async {
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          menuRepositoryProvider.overrideWith(
            (ref) => _FakeMenuRepository([_item('y', 'Cached', 300)]),
          ),
          mergedMenuProvider.overrideWith(
            (ref) => Stream.value(<MenuItemModel>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final mergedSub = container.listen(mergedMenuProvider, (_, __) {});
      final itemsSub = container.listen(menuItemsProvider, (_, __) {});
      addTearDown(mergedSub.close);
      addTearDown(itemsSub.close);
      await container.read(mergedMenuProvider.future);
      await container.read(menuItemsProvider.future);

      final item = container.read(menuItemByIdProvider('y'));

      expect(item, isNotNull);
      expect(item!.name, 'Cached');
    });

    test('returns null for an unknown id instead of throwing', () async {
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          menuRepositoryProvider.overrideWith(
            (ref) => _FakeMenuRepository([_item('y', 'Cached', 300)]),
          ),
          mergedMenuProvider.overrideWith(
            (ref) => Stream.value([_item('x', 'Live', 200)]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final mergedSub = container.listen(mergedMenuProvider, (_, __) {});
      final itemsSub = container.listen(menuItemsProvider, (_, __) {});
      addTearDown(mergedSub.close);
      addTearDown(itemsSub.close);
      await container.read(mergedMenuProvider.future);
      await container.read(menuItemsProvider.future);

      expect(container.read(menuItemByIdProvider('missing')), isNull);
    });
  });
}
