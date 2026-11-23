import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labs/features/admin/domain/branch_model.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:core/core.dart'
    show firestoreProvider, loggerProvider, UserModel, UserRole, LoggerService;
import '../../menu/data/menu_repository.dart' show kMenuMaxItemsSafetyCap;
import '../../menu/domain/dietary_codes.dart' show validateDietaryCodes;
import '../../../app/tenancy/tenant_claim.dart';

/// W8.7 (04-P1-QUERY): manager branch history is bounded by the repo's 24 h
/// window precedent ([streamOverviewStats], this file) + newest-first order +
/// a hard cap — the ENTIRE branch order history must never stream live into
/// the manager dashboard (memory/bandwidth grew with every order ever
/// placed). Deeper history goes through the paginated [loadOrders] path.
const int kManagerOrdersHistoryCap = 200;
const Duration kManagerOrdersHistoryWindow = Duration(hours: 24);

/// A single page of results with the cursor to continue from.
///
/// Enables correct Firestore pagination (Law 27): the caller stores [lastDoc]
/// and passes it as `startAfterDocument` on the next page fetch.
class PageResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDoc;

  const PageResult({required this.items, this.lastDoc});
}

/// Centralized admin data access service.
/// Extracts all Firestore queries from owner_dashboard.dart
/// into injectable methods for testability.
class AdminDataService {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  /// One place that turns the claim into an id, or throws (D-035 / D-057).
  final TenantScope _scope;

  AdminDataService({
    required FirebaseFirestore firestore,
    required LoggerService logger,
    TenantClaimReader? tenantClaim,
  }) : _firestore = firestore,
       _logger = logger,
       _scope = TenantScope(tenantClaim);

  /// Get today's order stats for the overview tab.
  Future<AdminOverviewStats> getOverviewStats() async {
    try {
      final tenantId = await _scope.require('AdminDataService');
      final snap = await _firestore
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 24)),
            ),
          )
          .get();

      final docs = snap.docs;
      final todayOrders = docs.length;
      final todayRevenue = docs.fold<int>(
        0,
        (acc, d) => acc + ((d.data() as Map)['totalCents'] as int? ?? 0),
      );
      final activeOrders = docs
          .where(
            (d) => ![
              'delivered',
              'cancelled',
            ].contains((d.data() as Map)['status']),
          )
          .length;

      return AdminOverviewStats(
        todayOrders: todayOrders,
        todayRevenue: todayRevenue,
        activeOrders: activeOrders,
      );
    } catch (e, stack) {
      await _logger.error(e, 'getOverviewStats failed', stack: stack);
      rethrow;
    }
  }

  /// Stream today's order stats for the overview tab (real-time).
  Stream<AdminOverviewStats> streamOverviewStats() async* {
    final tenantId = await _scope.require('AdminDataService');
    yield* _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 24)),
          ),
        )
        .snapshots()
        .map((snap) {
          final docs = snap.docs;
          final todayOrders = docs.length;
          final todayRevenue = docs.fold<int>(
            0,
            (acc, d) => acc + ((d.data() as Map)['totalCents'] as int? ?? 0),
          );
          final activeOrders = docs
              .where(
                (d) => ![
                  'delivered',
                  'cancelled',
                ].contains((d.data() as Map)['status']),
              )
              .length;
          return AdminOverviewStats(
            todayOrders: todayOrders,
            todayRevenue: todayRevenue,
            activeOrders: activeOrders,
          );
        })
        .handleError((Object e, StackTrace stack) {
          unawaited(
            _logger.error(e, 'streamOverviewStats failed', stack: stack),
          );
          throw e;
        });
  }

  /// Load orders with pagination for the orders tab.
  ///
  /// Returns a [PageResult] carrying the orders plus the last document as the
  /// next-page cursor. Callers MUST store and reuse `lastDoc` on subsequent
  /// loads — otherwise every "load more" re-fetches the same first page.
  Future<PageResult<OrderModel>> loadOrders({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      final tenantId = await _scope.require('AdminDataService');
      Query q = _firestore
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('createdAt', descending: true);
      // PERF-2: the cursor is chained BEFORE `.limit()`. On the real
      // Firestore SDK the two are order-insensitive (both are delegate fields
      // serialized into one server-side query), but fake_cloud_firestore
      // composes its op chain in CALL order — `limit` then `startAfterDocument`
      // yields an empty page 2 there, which would leave this contract with no
      // executable proof.
      if (startAfter != null) q = q.startAfterDocument(startAfter);
      q = q.limit(limit);
      final snap = await q.get();
      return PageResult(
        items: snap.docs.map((d) => OrderModel.fromDoc(d)).toList(),
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e, stack) {
      await _logger.error(e, 'loadOrders failed', stack: stack);
      rethrow;
    }
  }

  /// Load users with pagination for the users tab.
  ///
  /// Returns a [PageResult] carrying the users plus the last document as the
  /// next-page cursor. Callers MUST store and reuse `lastDoc` on subsequent
  /// loads — otherwise every "load more" re-fetches the same first page.
  Future<PageResult<UserModel>> loadUsers({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query q = _firestore.collection('users').orderBy('email');
      // PERF-2: cursor BEFORE limit — see the loadOrders note above.
      if (startAfter != null) q = q.startAfterDocument(startAfter);
      q = q.limit(limit);
      final snap = await q.get();
      return PageResult(
        items: snap.docs
            .map(
              (d) => UserModel.fromDoc(d.data() as Map<String, dynamic>, d.id),
            )
            .toList(),
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e, stack) {
      await _logger.error(e, 'loadUsers failed', stack: stack);
      rethrow;
    }
  }

  /// Update a user's role.
  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      await _firestore.collection('users').doc(uid).update({'role': role.name});
    } catch (e, stack) {
      await _logger.error(
        e,
        'updateUserRole failed for uid: $uid',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Update a user's branch assignment.
  Future<void> updateUserBranch(String uid, String? branchId) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'branchId': branchId,
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'updateUserBranch failed for uid: $uid',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Load a single user document (fresh server read).
  ///
  /// W8.1 (03-P1-STATE-A): the owner dashboard's users tab must refresh a
  /// row from Firestore after a mutation instead of hand-reconstructing a
  /// `UserModel` mirror (the manual mirror carried only
  /// id/email/name/role/branchId and silently dropped every other field —
  /// tier, loyaltyPoints, displayName, username, phones, pushToken, isOnline,
  /// assignedOrderIds, createdAt — so it drifted from the server). Returns
  /// null when the document does not exist.
  Future<UserModel?> loadUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;
      return UserModel.fromDoc(data, doc.id);
    } catch (e, stack) {
      await _logger.error(e, 'loadUser failed for uid: $uid', stack: stack);
      rethrow;
    }
  }

  /// Load all branches.
  Future<List<BranchModel>> loadBranches() async {
    try {
      final snap = await _firestore.collection('branches').limit(50).get();
      return snap.docs.map((d) => BranchModel.fromDoc(d)).toList();
    } catch (e, stack) {
      await _logger.error(e, 'loadBranches failed', stack: stack);
      rethrow;
    }
  }

  /// Stream branches.
  Stream<List<BranchModel>> streamBranches() {
    return _firestore
        .collection('branches')
        .snapshots()
        .map((s) => s.docs.map((d) => BranchModel.fromDoc(d)).toList())
        .handleError((Object e, StackTrace stack) {
          unawaited(_logger.error(e, 'streamBranches failed', stack: stack));
          throw e;
        });
  }

  /// Create or update a branch.
  Future<void> saveBranch(
    Map<String, dynamic> data, {
    String? existingId,
  }) async {
    try {
      if (existingId != null) {
        await _firestore.collection('branches').doc(existingId).update(data);
      } else {
        // tenantOkCreate() compares this key to the caller's claim; the claim
        // wins over anything the caller passed in `data`.
        await _firestore.collection('branches').add(<String, dynamic>{
          ...data,
          'tenantId': await _scope.require('AdminDataService'),
        });
      }
    } catch (e, stack) {
      await _logger.error(e, 'saveBranch failed', stack: stack);
      rethrow;
    }
  }

  /// Soft-delete a branch if no pending orders.
  Future<bool> deleteBranch(String branchId) async {
    try {
      final tenantId = await _scope.require('AdminDataService');
      final pending = await _firestore
          .collection('orders')
          .where('tenantId', isEqualTo: tenantId)
          .where('branchId', isEqualTo: branchId)
          .where('status', whereIn: ['pending', 'confirmed', 'preparing'])
          .limit(1)
          .get();
      if (pending.docs.isNotEmpty) return false;

      await _firestore.collection('branches').doc(branchId).set({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      await _logger.error(
        e,
        'deleteBranch failed for branchId: $branchId',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Stream orders for a specific branch (for manager dashboard).
  ///
  /// W8.7 (04-P1-QUERY): bounded to [kManagerOrdersHistoryWindow] +
  /// newest-first + [kManagerOrdersHistoryCap]. The window drops older
  /// history by design (matching the [streamOverviewStats] precedent).
  Stream<List<OrderModel>> streamOrdersByBranch(
    String branchId, {
    Duration window = kManagerOrdersHistoryWindow,
  }) async* {
    final tenantId = await _scope.require('AdminDataService');
    yield* _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('branchId', isEqualTo: branchId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(window),
          ),
        )
        .orderBy('createdAt', descending: true)
        .limit(kManagerOrdersHistoryCap)
        .snapshots()
        .map((snap) => snap.docs.map((d) => OrderModel.fromDoc(d)).toList())
        .handleError((Object e, StackTrace stack) {
          unawaited(
            _logger.error(
              e,
              'streamOrdersByBranch failed for branchId: $branchId',
              stack: stack,
            ),
          );
          throw e;
        });
  }

  /// Load global menu items.
  ///
  /// W8.7 (04-P1-QUERY): capped at the repo's menu safety cap
  /// (kMenuMaxItemsSafetyCap, menu_repository.dart:16) — same bound as the
  /// customer-side menu streams (merged_menu_provider.dart).
  Stream<List<MenuItemModel>> streamGlobalMenu() {
    return _firestore
        .collection('menus')
        .limit(kMenuMaxItemsSafetyCap)
        .snapshots()
        .map((s) => s.docs.map((d) => MenuItemModel.fromDoc(d)).toList())
        .handleError((Object e, StackTrace stack) {
          unawaited(_logger.error(e, 'streamGlobalMenu failed', stack: stack));
          throw e;
        });
  }

  /// Save a menu item.
  Future<void> saveMenuItem(
    Map<String, dynamic> data, {
    String? existingId,
  }) async {
    // P6-1 (D-052): the write boundary rejects an unknown code. A silently
    // dropped allergen is a badge that cannot render, and a missing badge reads
    // as a missing allergen - so this fails loudly instead.
    _validateDietaryMetadata(data);
    try {
      if (existingId != null) {
        await _firestore.collection('menus').doc(existingId).update(data);
      } else {
        await _firestore.collection('menus').add(<String, dynamic>{
          ...data,
          'tenantId': await _scope.require('AdminDataService'),
        });
      }
    } catch (e, stack) {
      await _logger.error(e, 'saveMenuItem failed', stack: stack);
      rethrow;
    }
  }

  /// Validates the two code lists at the repository boundary (P6-1).
  void _validateDietaryMetadata(Map<String, dynamic> data) {
    for (final field in const ['allergens', 'dietary']) {
      final raw = data[field];
      if (raw == null) continue;
      if (raw is! List) {
        throw ArgumentError.value(raw, field, 'must be a list of codes');
      }
      for (final code in raw) {
        if (code is! String) {
          throw ArgumentError.value(code, field, 'code must be a string');
        }
      }
      validateDietaryCodes(field, raw.cast<String>());
    }
  }

  /// Toggle menu item availability.
  Future<void> toggleMenuItemAvailability(String id, bool available) async {
    try {
      await _firestore.collection('menus').doc(id).update({
        'isAvailable': available,
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'toggleMenuItemAvailability failed for id: $id',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Delete a menu item.
  Future<void> deleteMenuItem(String id) async {
    try {
      await _firestore.collection('menus').doc(id).delete();
    } catch (e, stack) {
      await _logger.error(e, 'deleteMenuItem failed for id: $id', stack: stack);
      rethrow;
    }
  }
}

/// Data class for overview stats.
class AdminOverviewStats {
  final int todayOrders;
  final int todayRevenue;
  final int activeOrders;

  const AdminOverviewStats({
    required this.todayOrders,
    required this.todayRevenue,
    required this.activeOrders,
  });
}

final adminDataServiceProvider = Provider<AdminDataService>((ref) {
  return AdminDataService(
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
    tenantClaim: ref.watch(tenantClaimProvider),
  );
});
