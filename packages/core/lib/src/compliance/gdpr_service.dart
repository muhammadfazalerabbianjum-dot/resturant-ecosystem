import 'package:core/src/network/firestore_client.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:core/src/config/core_config.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/error_logger/logger_provider.dart';
import 'package:core/src/network/network_retry.dart';
import 'package:core/src/providers/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client-side interface to the `deleteUserData` GDPR Cloud Function.
/// In demo mode, performs client-side batch deletes directly.
/// In production, the Admin SDK Cloud Function handles cascade deletion.
///
/// P4-05 (LAW 11): Two-phase deletion strategy.
///   1. Persist a `deletion_requests/{userId}` marker FIRST (durable intent).
///   2. Run the Firestore batch atomically.
///   3. Wrap Auth user.delete() in try/catch — if it fails, the marker stays
///      'in_progress' so a server-side retry can pick it up later.
///   4. Log EVERY failure with the userId for auditability (GDPR requires
///      demonstrating the erasure was attempted).
class GdprService {
  /// Optional injected callable transport (tests). Resolved LAZILY via
  /// [_functions] on the production callable path only — the constructor must
  /// not touch `FirebaseFunctions.instance` (Firebase may not be initialized
  /// for demo-mode erasure or pure Firestore/unit harnesses).
  final FirebaseFunctions? _injectedFn;
  final LoggerService _logger;
  final FirebaseFirestore _db;

  /// Optional injected auth (tests). Resolved LAZILY via [_auth] on the
  /// first `deleteMyData()` call — the constructor must not touch
  /// `FirebaseAuth.instance` (pure Firestore harnesses never sign in).
  final FirebaseAuth? _injectedAuth;
  final GdprStorageEraser _eraser;

  /// Resolved on first production-path use only (demo mode never needs it).
  FirebaseFunctions get _fn => _injectedFn ?? FirebaseFunctions.instance;

  /// Firestore's hard batch-write cap; erasure chunks stay well under it so
  /// a user with >400 user-scoped docs still erases successfully.
  static const int kEraseChunkSize = 400;

  GdprService({
    FirebaseFunctions? functions,
    LoggerService? logger,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    GdprStorageEraser? storageEraser,
  }) : _injectedFn = functions,
       _logger = logger ?? LoggerService(),
       _db = firestore ?? FirestoreClient.instance.db,
       _injectedAuth = auth,
       _eraser = storageEraser ?? const FirebaseStorageEraser();

  /// Resolved on the first auth use (demo or production `deleteMyData`).
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  /// Collects every Firestore document reference owned by `uid` (GDPR Art.17
  /// erasure set). Mirrors the Cloud Function `collectUserDocs` so demo and
  /// production erase the same canonical set.
  ///
  /// Query-key guard: reservations are keyed by `userId` (NEVER `customerId`;
  /// reservations_repository.dart writes only userId/branchId/customerName/
  /// customerPhone/startTime/partySize/notes and firestore.rules forbids
  /// `customerId` on reservation creates). `users/{uid}` is collected LAST so
  /// the profile record survives until every dependent document is gone.
  Future<List<DocumentReference>> collectUserDocs(String uid) async {
    final refs = <DocumentReference>[];

    final orders = await _db
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .get();
    final orderIds = <String>{};
    for (final doc in orders.docs) {
      refs.add(doc.reference);
      orderIds.add(doc.id);
    }

    // MONEY-3 (W3.5): deliveries — the delivery doc id IS the order id. The
    // user's own rows are erased by order id; a DRIVER's rows are covered both
    // by the order ids of every order they were assigned (covers legacy
    // pre-driverId rows) and by `deliveries.where('driverId', ==, uid)` (rows
    // stamped since MONEY-3). Mirrors the Cloud Function exactly.
    final driverOrders = await _db
        .collection('orders')
        .where('assignedDriverId', isEqualTo: uid)
        .get();
    for (final doc in driverOrders.docs) {
      orderIds.add(doc.id);
    }
    for (final orderId in orderIds) {
      refs.add(_db.collection('deliveries').doc(orderId));
    }
    final deliveryRowsByDriver = await _db
        .collection('deliveries')
        .where('driverId', isEqualTo: uid)
        .get();
    for (final doc in deliveryRowsByDriver.docs) {
      refs.add(doc.reference);
    }

    // MONEY-3 (W3.5): analyticsEvents — every row is uid-queryable.
    final analyticsEvents = await _db
        .collection('analyticsEvents')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in analyticsEvents.docs) {
      refs.add(doc.reference);
    }

    // MONEY-3 (W3.5): audit_log — erase ONLY the user's own rows
    // (collection == 'users', i.e. ROLE_CHANGE events). Settings-config rows
    // (collection == 'settings') are retained as the immutable audit trail of
    // configuration writes (legal basis documented in the Cloud Function).
    final auditRows = await _db
        .collection('audit_log')
        .where('documentId', isEqualTo: uid)
        .get();
    for (final doc in auditRows.docs) {
      if (doc.data()['collection'] == 'users') {
        refs.add(doc.reference);
      }
    }

    final reservations = await _db
        .collection('reservations')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in reservations.docs) {
      refs.add(doc.reference);
    }

    final locks = await _db
        .collection('reservation_locks')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in locks.docs) {
      refs.add(doc.reference);
    }

    final waitlist = await _db
        .collection('waitlist')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in waitlist.docs) {
      refs.add(doc.reference);
    }

    final promoUsage = await _db
        .collection('promo_usage')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in promoUsage.docs) {
      refs.add(doc.reference);
    }

    final notifications = await _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .get();
    for (final doc in notifications.docs) {
      refs.add(doc.reference);
    }
    refs.add(_db.collection('notifications').doc(uid));

    refs
      ..add(_db.collection('carts').doc(uid))
      ..add(_db.collection('presence').doc(uid))
      ..add(_db.collection('loyalty').doc(uid))
      ..add(_db.collection('driverLocations').doc(uid));

    // users/{uid} LAST — the profile record survives until every dependent
    // document is gone (mirrors the Cloud Function collectUserDocs).
    refs.add(_db.collection('users').doc(uid));

    return refs;
  }

  /// Deletes `refs` in chunks of at most [chunkSize] (default 400), committing
  /// each chunk sequentially so the total stays under Firestore's 500-write
  /// batch limit. Missing docs are no-ops, so erasure is idempotent for retries
  /// and double-taps on Delete Account. Returns the number of refs erased.
  Future<int> eraseRefsChunked(
    List<DocumentReference> refs, {
    int chunkSize = GdprService.kEraseChunkSize,
  }) async {
    var erased = 0;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, refs.length);
      final chunk = refs.sublist(i, end);
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
      erased += chunk.length;
    }
    return erased;
  }

  /// MONEY-3 (W3.5): demo-mode mirror of the Cloud Function's
  /// `eraseUserStorage`. Deletes `avatars/{uid}/*` and
  /// `proof_of_delivery/{orderId}/*` (recursive, mirroring the server's
  /// `bucket.deleteFiles({prefix})` semantics) for EVERY order the user owns
  /// OR was assigned to as a driver, through the injectable
  /// [GdprStorageEraser] seam (production default: [FirebaseStorageEraser]).
  /// Runs storage-FIRST (order docs still exist so the POD prefixes resolve) —
  /// mirrors the Cloud Function's runErase ordering. A Storage failure
  /// propagates (fail-closed: the deletion_requests marker stays `in_progress`
  /// for the server-side retrier).
  Future<void> _eraseUserStorage(String uid) async {
    final avatars = await _eraser.listAllUnder('avatars/$uid');
    for (final path in avatars) {
      await _eraser.deleteObject(path);
    }
    final orderIds = <String>{};
    final owned = await _db
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .get();
    for (final doc in owned.docs) {
      orderIds.add(doc.id);
    }
    final assigned = await _db
        .collection('orders')
        .where('assignedDriverId', isEqualTo: uid)
        .get();
    for (final doc in assigned.docs) {
      orderIds.add(doc.id);
    }
    for (final orderId in orderIds) {
      final pod = await _eraser.listAllUnder('proof_of_delivery/$orderId');
      for (final path in pod) {
        await _eraser.deleteObject(path);
      }
    }
  }

  /// Permanently deletes all user PII.
  Future<bool> deleteMyData() async {
    // ── DEMO MODE: Client-side batch delete ──────────────────────────────────
    if (CoreConfigHolder.instance.isDemoMode) {
      final user = _auth.currentUser;
      if (user == null) return false;
      final uid = user.uid;

      // Phase 0: persist the deletion intent FIRST (durable marker).
      // If any later step fails, a server-side retry can pick this up.
      try {
        await _db.collection('deletion_requests').doc(uid).set({
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'in_progress',
        });
      } catch (e, stack) {
        await _logger.error(e, 'gdpr_deletion_marker_failed', stack: stack);
        rethrow;
      }

      // Phase 1: erase every user-scoped doc (chunked below the write cap) +
      // user Storage objects (avatars/{uid}/*, proof_of_delivery/{orderId}/*).
      try {
        final refs = await collectUserDocs(uid);
        // MONEY-3 (W3.5): Storage objects are deleted FIRST (order docs still
        // exist, so proof_of_delivery/{orderId} paths resolve) — mirrors the
        // Cloud Function's runErase ordering.
        await _eraseUserStorage(uid);
        await eraseRefsChunked(refs);
      } catch (e, stack) {
        await _logger.error(e, 'gdpr_batch_delete_failed', stack: stack);
        rethrow;
      }

      // Phase 2: delete the Auth account (may fail on network — retry later).
      // The deletion_requests marker stays 'in_progress' so a server-side
      // function can retry the Auth delete (idempotent, eventually consistent).
      try {
        await user.delete();
        await _db.collection('deletion_requests').doc(uid).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e, stack) {
        await _logger.error(e, 'gdpr_auth_delete_failed', stack: stack);
        // LEAVE status='in_progress' — server-side retry picks it up.
        rethrow;
      }
    }
    // ── PRODUCTION MODE: Cloud Function (Admin SDK cascade) ──────────────────
    final user = _auth.currentUser;
    if (user == null) return false;
    final uid = user.uid;

    // Durable marker FIRST (before the fragile callable): if the client dies mid-call
    // the server-side retrier still completes the erasure. The marker is the audit
    // proof of erasure and is intentionally never deleted.
    try {
      await _db.collection('deletion_requests').doc(uid).set({
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
      });

      // QUEUE-2 (P-3): the erasure callable is retried on transient
      // failures with bounded classified backoff. A re-run after a
      // committed-but-unacked cascade is safe: every document delete is
      // idempotent and the durable marker above records the intent (the
      // marker stays `in_progress` until the function reports success).
      final result = await NetworkRetry.withExponentialBackoff(
        () => _fn.httpsCallable('deleteUserData').call(),
      );
      // `success: true` is the erasure-completion contract; anything else
      // means the server-side erasure did not complete.
      return result.data['success'] == true;
    } catch (e, stack) {
      await _logger.error(e, 'gdpr_cloud_function_failed', stack: stack);
      // Marker stays 'in_progress' — the retrier completes it later.
      rethrow;
    }
  }
}

/// Injectable [GdprService] for UI/DI tests.
///
/// Resolves the overridable `firestoreProvider` + `loggerProvider` so a widget
/// test can override them (fake DB / mock logger) instead of constructing a
/// bare `GdprService()` (`Firebase Functions/Auth` untouched).
final gdprServiceProvider = Provider<GdprService>((ref) {
  return GdprService(
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Narrow Firebase Storage seam for the demo-mode erasure mirror (MONEY-3,
/// W3.5). The demo mirror MUST erase the SAME canonical set as the server's
/// `eraseUserStorage` (functions/src/index.ts): `avatars/{uid}/*` and
/// `proof_of_delivery/{orderId}/*` for every order the user owns OR was
/// assigned to as a driver. The seam is injectable so pure-Dart tests can
/// prove the exact prefixes without Firebase Storage platform channels;
/// [FirebaseStorageEraser] is the production default.
abstract class GdprStorageEraser {
  /// Full object paths of EVERY descendant of [prefix] — recursive, mirroring
  /// the server's `bucket.deleteFiles({prefix})` semantics.
  Future<List<String>> listAllUnder(String prefix);

  /// Deletes the single object at [objectPath].
  Future<void> deleteObject(String objectPath);
}

/// Production default: wraps [FirebaseStorage.instance]. The instance is
/// resolved LAZILY inside the methods (never at construction) so a
/// [GdprService] constructed in a plain Dart test without a Storage platform
/// mock stays safe; erasure tests exercise the seam via an injectable fake.
class FirebaseStorageEraser implements GdprStorageEraser {
  const FirebaseStorageEraser();

  @override
  Future<List<String>> listAllUnder(String prefix) async {
    final result = await FirebaseStorage.instance.ref(prefix).listAll();
    final paths = <String>[for (final item in result.items) item.fullPath];
    // listAll() is one level deep; walk sub-prefixes to mirror the server's
    // recursive prefix deletion exactly.
    for (final sub in result.prefixes) {
      paths.addAll(await listAllUnder(sub.fullPath));
    }
    return paths;
  }

  @override
  Future<void> deleteObject(String objectPath) =>
      FirebaseStorage.instance.ref(objectPath).delete();
}
