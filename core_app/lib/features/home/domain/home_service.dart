import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';

/// Encapsulates business logic for the Home screen.
///
/// Extracted from [HomeScreen] to enable unit testing.
/// All platform dependencies (FirebaseFirestore) and the [LoggerService]
/// are injected so they can be mocked in tests. Never construct `LoggerService`
/// inline here — always inject via [homeServiceProvider] (Rule 5 grep gate).
class HomeService {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  HomeService({
    required FirebaseFirestore firestore,
    required LoggerService logger,
  }) : _firestore = firestore,
       _logger = logger;

  /// Filter menu items by search query (case-insensitive match on name/description).
  List<MenuItemModel> searchMenuItems(List<MenuItemModel> items, String query) {
    if (query.isEmpty) return items;
    final q = query.trim().toLowerCase();
    return items.where((i) {
      return i.name.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q);
    }).toList();
  }

  /// Filter menu items by category.
  List<MenuItemModel> filterByCategory(
    List<MenuItemModel> items,
    String category,
  ) {
    if (category.isEmpty) return items;
    final c = category.trim().toLowerCase();
    return items.where((i) {
      return i.category.toLowerCase() == c ||
          i.tags.any((t) => t.toLowerCase() == c);
    }).toList();
  }

  /// Filter menu items by price threshold (under a certain price in cents).
  List<MenuItemModel> filterByMaxPrice(
    List<MenuItemModel> items,
    int maxPriceCents,
  ) {
    return items.where((i) => i.priceCents <= maxPriceCents).toList();
  }

  /// Filter menu items by availability.
  List<MenuItemModel> filterAvailable(List<MenuItemModel> items) {
    return items.where((i) => i.isAvailable).toList();
  }

  /// Get a list of promotion/banner items from Firestore.
  ///
  /// Returns ONLY promotions the restaurant actually created (Law 3/4).
  /// If no promotions exist — or the query fails — returns an EMPTY list.
  /// NEVER fabricate promo tiles the restaurant didn't create (P5-09).
  Future<List<HomePromotion>> getPromotions() async {
    try {
      final snap = await _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return HomePromotion(
          id: doc.id,
          title: data['title'] as String? ?? '',
          subtitle: data['subtitle'] as String? ?? '',
          imageUrl: data['imageUrl'] as String?,
          backgroundColor: data['backgroundColor'] as String?,
          actionLabel: data['actionLabel'] as String?,
          actionRoute: data['actionRoute'] as String?,
        );
      }).toList();
    } catch (e, stack) {
      // No promos: render the empty state — never hardcoded placeholders.
      // B4-1: a silent fetch failure previously made the carousel look fine
      // while hiding a broken query. Log it so the owner can diagnose.
      await _logger.warn(e, 'HomeService.getPromotions failed', stack: stack);
      return const [];
    }
  }

  /// Fetch all active branches.
  ///
  /// Returns an EMPTY list on failure — never fabricate branches the
  /// restaurant didn't create (mirrors [getPromotions]'s fail-safe contract).
  Future<List<HomeBranch>> getBranches() async {
    try {
      final snap = await _firestore
          .collection('branches')
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return HomeBranch(
          id: doc.id,
          // B4-4: never a hardcoded 'Branch' label — surface the missing name
          // honestly and log so setup gaps are visible.
          name: data['name'] as String? ?? _missingBranchName(doc.id),
          address: data['address'] as String? ?? '',
          isMainBranch: data['isMainBranch'] as bool? ?? false,
          isOpen: data['isOpen'] as bool? ?? true,
        );
      }).toList();
    } catch (e, stack) {
      // No branches: render the empty state — never hardcoded placeholders.
      // B4-1: log the failure instead of silently pretending all is well.
      await _logger.warn(e, 'HomeService.getBranches failed', stack: stack);
      return const [];
    }
  }

  /// Honest placeholder for a branch document missing its `name` field.
  /// Using a neutral em-dash (not a fabricated label) matches the location
  /// fallback convention and triggers a traced warning for setup triage.
  String _missingBranchName(String branchId) {
    unawaited(
      _logger.warn(
        StateError('branches/$branchId missing required "name" field'),
        'HomeService.getBranches missing name',
      ),
    );
    return '—';
  }
}

/// A promotion/banner displayed on the Home feed.
class HomePromotion {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? backgroundColor;
  final String? actionLabel;
  final String? actionRoute;

  const HomePromotion({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.backgroundColor,
    this.actionLabel,
    this.actionRoute,
  });
}

/// A branch displayed in location selection.
class HomeBranch {
  final String id;
  final String name;
  final String address;
  final bool isMainBranch;
  final bool isOpen;

  const HomeBranch({
    required this.id,
    required this.name,
    this.address = '',
    this.isMainBranch = false,
    this.isOpen = true,
  });
}

/// Riverpod provider for [HomeService].
final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
  );
});
