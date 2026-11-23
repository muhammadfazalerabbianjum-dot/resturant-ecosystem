import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:isar_community/isar.dart';
import '../domain/menu_item_model.dart';

class MenuFetchException implements Exception {
  final Object error;
  final StackTrace? stackTrace;
  MenuFetchException(this.error, [this.stackTrace]);
  @override
  String toString() => 'MenuFetchException: $error';
}

/// Safety cap for maximum menu items fetched in one query (Law 20).
const int kMenuMaxItemsSafetyCap = 500;

class MenuRepository {
  final FirebaseFirestore _firestore;
  final IsarService _isarService;
  final LoggerService _logger;

  MenuRepository(this._firestore, this._isarService, this._logger);

  Future<List<MenuItemModel>> getMenuItems() async {
    try {
      final isar = await _isarService.db;

      // 1. Fetch from local cache first (Offline-First)
      final localItems = await isar.isarMenuItems.where().findAll();

      // 2. Map Isar to Domain models immediately to return fast to UI
      List<MenuItemModel> domainItems = localItems
          .map(
            (e) => MenuItemModel(
              id: e.firestoreId,
              name: e.name,
              priceCents: e.price,
              imageUrl: e.imageUrl,
              category: e.category,
              isAvailable: e.isAvailable,
            ),
          )
          .toList();

      // Check TTL (e.g., 1 hour for cache freshness)
      final now = DateTime.now();
      final bool cacheStale =
          localItems.isEmpty ||
          localItems.any((e) => now.difference(e.lastUpdated).inHours >= 1);

      if (cacheStale) {
        await _syncFromFirestore(isar);
        final freshLocal = await isar.isarMenuItems.where().findAll();
        domainItems = freshLocal
            .map(
              (e) => MenuItemModel(
                id: e.firestoreId,
                name: e.name,
                priceCents: e.price,
                imageUrl: e.imageUrl,
                category: e.category,
                isAvailable: e.isAvailable,
              ),
            )
            .toList();
      } else {
        // 3. Background sync from Firestore (doesn't block UI return)
        unawaited(
          _syncFromFirestore(isar).catchError((Object _) {
            // The failure is already logged inside the sync; the UI is
            // served from the fresh cache, so a background refresh must
            // never surface as an error.
          }),
        );
      }

      return domainItems;
    } catch (e, stack) {
      await _logger.error(e, 'MenuRepository_getMenuItems', stack: stack);
      // Fail loudly if no cache is available so UI renders error state
      final isar = await _isarService.db;
      final cached = await isar.isarMenuItems.where().findAll();
      if (cached.isEmpty) {
        throw MenuFetchException(e, stack);
      }
      return cached
          .map(
            (e) => MenuItemModel(
              id: e.firestoreId,
              name: e.name,
              priceCents: e.price,
              imageUrl: e.imageUrl,
              category: e.category,
              isAvailable: e.isAvailable,
            ),
          )
          .toList();
    }
  }

  Future<void> _syncFromFirestore(Isar isar) async {
    try {
      // QUEUE-2 (P-2): the menu read is retried on transient failures
      // (bounded, classified backoff — a rules `permission-denied`
      // rethrows immediately). The catch below logs and RETHROWS: the
      // foreground caller in getMenuItems then serves the stale cache
      // when one exists, or fails loud when there is none — a Firestore
      // outage must never masquerade as an empty menu.
      final snapshot = await NetworkRetry.withExponentialBackoff(
        () =>
            _firestore.collection('menus').limit(kMenuMaxItemsSafetyCap).get(),
      );
      final freshItems = snapshot.docs;

      await isar.writeTxn(() async {
        for (var doc in freshItems) {
          final data = doc.data();
          final resolvedCategory =
              (data['category'] as String?) ??
              ((data['tags'] as List<dynamic>?)?.firstOrNull as String?) ??
              'General';

          final isarModel = IsarMenuItem()
            ..firestoreId = doc.id
            ..name = (data['name'] as String?) ?? 'Unknown'
            ..price = (data['priceCents'] as int?) ?? 0
            ..imageUrl = data['imageUrl'] as String?
            ..category = resolvedCategory
            ..isAvailable = (data['isAvailable'] as bool?) ?? true
            ..lastUpdated = DateTime.now();
          await isar.isarMenuItems.put(isarModel);
        }
      });
    } catch (e, stack) {
      await _logger.error(e, 'MenuRepository_syncFromFirestore', stack: stack);
      rethrow;
    }
  }
}
