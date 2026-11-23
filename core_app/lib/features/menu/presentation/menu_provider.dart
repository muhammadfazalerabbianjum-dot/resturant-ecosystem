import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/menu_repository.dart';
import '../domain/menu_item_model.dart';
import 'package:core/core.dart';

import 'merged_menu_provider.dart';

final menuRepositoryProvider = Provider.autoDispose<MenuRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final isar = IsarService.shared();
  final logger = ref.watch(
    loggerProvider,
  ); // watch so refresh on provider rebuild
  return MenuRepository(firestore, isar, logger);
});

final menuItemsProvider = FutureProvider.autoDispose<List<MenuItemModel>>((
  ref,
) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuItems();
});

/// Resolves a single menu item by id from the live branch stream first (Law 4 — real data,
/// unlimited menu), falling back to repository menu if unmerged.
final menuItemByIdProvider = Provider.autoDispose
    .family<MenuItemModel?, String>((ref, itemId) {
      final mergedAsync = ref.watch(mergedMenuProvider);
      final mergedItem = mergedAsync.valueOrNull
          ?.where((i) => i.id == itemId)
          .firstOrNull;
      if (mergedItem != null) return mergedItem;
      final itemsAsync = ref.watch(menuItemsProvider);
      return itemsAsync.valueOrNull?.where((i) => i.id == itemId).firstOrNull;
    });
