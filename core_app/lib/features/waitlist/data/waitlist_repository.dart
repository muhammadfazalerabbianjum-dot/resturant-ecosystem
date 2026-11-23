import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../../app/tenancy/tenant_claim.dart';

/// Result of a waitlist join attempt (B4-9). The deterministic doc key that
/// made joins idempotent is retained — but instead of every re-join silently
/// "succeeding", the caller now gets the real state of the world.
enum WaitlistJoinResult {
  /// The user was NOT on the list and is now queued.
  joined,

  /// The user was already on the list — the write was NOT duplicated.
  alreadyJoined,

  /// The branch's waitlist has reached its configured [WaitlistRepository.joinWaitlist] max.
  full,

  /// The write could not be confirmed (logged internally). Fail closed.
  error,
}

/// PERF-9 T-2 — waitlist TAKE-A-TICKET.
///
/// A counter answers "how many", not "how far am I" — an ordinal is required
/// (B-2). Every queued guest now holds a monotonic `myTicket`, and the branch
/// carries a single ordinal doc `branches/{bid}/waitlist_meta/meta`
/// `{ nextTicket:int, nowServing:int }`:
///
///  * join  = one transaction: `myTicket = nextTicket++` AND the guest doc
///    write (deterministic key `${branchId}_$userId`) in the SAME transaction.
///  * serve/leave advances `nowServing` past the served ticket (never
///    regresses — a stale/late leave cannot rewind the queue).
///  * customer position = `myTicket − nowServing − 1`, computed locally from
///    two READABLE docs (own guest doc + meta doc). NO list-query (the old
///    branch-scoped `where('branchId')` read is DENIED by the rules for
///    customers once 2+ users are queued — B-2 — so it was removed) and no
///    CF fan-out. The rules side pins this in
///    `core_app/test/rules/firestore_rules_test.js` (T-2/W1-T7 pin).
class WaitlistRepository {
  WaitlistRepository(this._firestore, this._logger, this._tenant);

  /// D-035: the client tenant is the ID token claim.
  final TenantClaimReader _tenant;

  static const String _metaCollection = 'waitlist_meta';
  static const String _metaDocId = 'meta';
  static const String statusWaiting = 'waiting';
  static const String statusLeft = 'left';

  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  DocumentReference<Map<String, dynamic>> _metaRef(String branchId) =>
      _firestore
          .collection('branches')
          .doc(branchId)
          .collection(_metaCollection)
          .doc(_metaDocId);

  DocumentReference<Map<String, dynamic>> _entryRef(
    String branchId,
    String userId,
  ) => _firestore.collection('waitlist').doc('${branchId}_$userId');

  /// Atomically joins a branch's waitlist using a deterministic document key.
  ///
  /// Semantics (T-2.2):
  ///  * The entry key `waitlist/{branchId}_{userId}` makes the write idempotent
  ///    by construction — a concurrent double-tap CANNOT create a duplicate.
  ///  * `myTicket = nextTicket++` is read off `branches/{bid}/waitlist_meta`
  ///    and written to the guest doc in the SAME transaction (globally
  ///    monotonic, per-branch ordinal — no collection scan).
  ///  * When [maxEntries] is provided and the branch already has that many
  ///    WAITING guests (`nextTicket − 1 − nowServing`), the join is rejected
  ///    with `full` and consumes no ticket.
  ///
  /// Returns [WaitlistJoinResult.alreadyJoined] (no write, no duplicate) when
  /// the deterministic entry already exists — re-joining is visible to the
  /// UI instead of a fake success.
  Future<WaitlistJoinResult> joinWaitlist({
    required String branchId,
    required String userId,
    required int partySize,
    int? maxEntries,
  }) async {
    final entryRef = _entryRef(branchId, userId);
    final metaRef = _metaRef(branchId);

    // Every document below is tenant-scoped; without the claim the writes can
    // only be denied, so fail closed before starting a doomed transaction.
    final String? tenantId = await _tenant.read();
    if (tenantId == null) return WaitlistJoinResult.error;

    try {
      return await _firestore.runTransaction((transaction) async {
        // 1. Pre-check the deterministic key INSIDE the transaction.
        final entryDoc = await transaction.get(entryRef);
        if (entryDoc.exists) {
          return WaitlistJoinResult.alreadyJoined;
        }

        // 2. Read the branch ordinal doc (create-on-first-join).
        final metaDoc = await transaction.get(metaRef);
        final nextTicket =
            (metaDoc.data()?['nextTicket'] as num?)?.toInt() ?? 1;
        final nowServing =
            (metaDoc.data()?['nowServing'] as num?)?.toInt() ?? 0;

        // 3. Optional capacity gate (fail-closed: only reject when a cap is
        //    set). Waiting guests = tickets handed out and not yet served.
        final waitingGuests = nextTicket - 1 - nowServing;
        if (maxEntries != null && waitingGuests >= maxEntries) {
          return WaitlistJoinResult.full;
        }

        transaction.set(entryRef, {
          'tenantId': tenantId,
          'branchId': branchId,
          'userId': userId,
          'partySize': partySize,
          'myTicket': nextTicket,
          'joinedAt': FieldValue.serverTimestamp(),
          'status': statusWaiting,
        });
        transaction.set(metaRef, <String, Object>{
          'tenantId': tenantId,
          'nextTicket': nextTicket + 1,
          'nowServing': nowServing,
        });
        return WaitlistJoinResult.joined;
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'WaitlistRepository.joinWaitlist failed',
        stack: stack,
      );
      return WaitlistJoinResult.error;
    }
  }

  /// Staff serve path (T-2.3): advances `nowServing` past the served ticket.
  ///
  /// The head of the queue is ticket `nowServing + 1`; serving advances the
  /// ordinal by one and never runs past the last handed-out ticket
  /// (`nextTicket − 1`). Returns the new `nowServing`, or `-1` when the
  /// branch has no waitlist yet (nothing to serve — no write).
  Future<int> serveNext({required String branchId}) async {
    final metaRef = _metaRef(branchId);
    final String? tenantId = await _tenant.read();
    if (tenantId == null) return -1;
    try {
      return await _firestore.runTransaction((transaction) async {
        final metaDoc = await transaction.get(metaRef);
        if (!metaDoc.exists) return -1;
        final nextTicket =
            (metaDoc.data()?['nextTicket'] as num?)?.toInt() ?? 0;
        final nowServing =
            (metaDoc.data()?['nowServing'] as num?)?.toInt() ?? 0;
        final advanced = nowServing < nextTicket - 1
            ? nowServing + 1
            : nowServing;
        transaction.set(metaRef, <String, Object>{
          'tenantId': tenantId,
          'nextTicket': nextTicket,
          'nowServing': advanced,
        });
        return advanced;
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'WaitlistRepository.serveNext failed',
        stack: stack,
      );
      return -1;
    }
  }

  /// Guest leave path (T-2.3, own-doc route): the guest marks their OWN entry
  /// `left` and the SAME transaction advances `nowServing` PAST the leaver's
  /// ticket — monotonically: `nowServing = max(nowServing, myTicket)`. A
  /// late/stale leave (ticket already served) can never rewind the queue.
  ///
  /// Returns `false` when the user has no entry on this branch (no write).
  Future<bool> leaveWaitlist({
    required String branchId,
    required String userId,
  }) async {
    final entryRef = _entryRef(branchId, userId);
    final metaRef = _metaRef(branchId);
    final String? tenantId = await _tenant.read();
    if (tenantId == null) return false;
    try {
      return await _firestore.runTransaction((transaction) async {
        final entryDoc = await transaction.get(entryRef);
        if (!entryDoc.exists) return false;
        final myTicket = (entryDoc.data()?['myTicket'] as num?)?.toInt() ?? 0;
        if (myTicket <= 0) return false;

        final metaDoc = await transaction.get(metaRef);
        final nextTicket =
            (metaDoc.data()?['nextTicket'] as num?)?.toInt() ?? myTicket + 1;
        final nowServing =
            (metaDoc.data()?['nowServing'] as num?)?.toInt() ?? 0;

        transaction.update(entryRef, {
          'status': statusLeft,
          'leftAt': FieldValue.serverTimestamp(),
        });
        transaction.set(metaRef, <String, Object>{
          'tenantId': tenantId,
          'nextTicket': nextTicket,
          'nowServing': myTicket > nowServing ? myTicket : nowServing,
        });
        return true;
      });
    } catch (e, stack) {
      await _logger.error(
        e,
        'WaitlistRepository.leaveWaitlist failed',
        stack: stack,
      );
      return false;
    }
  }

  /// Streams the customer's queue position for a SINGLE branch — the T-2.4
  /// ordinal, computed locally from two READABLE docs: the user's OWN guest
  /// doc (`waitlist/{branchId}_{userId}`) and the branch ordinal doc
  /// (`branches/{bid}/waitlist_meta`). NO list-query and NO CF fan-out.
  ///
  ///  * `position = myTicket − nowServing − 1` (people ahead in line).
  ///  * Emits `-1` when the user is not on the list (no doc, no ticket, or
  ///    already served/left).
  Stream<int> streamQueuePosition(String branchId, String userId) {
    final guestStream = _entryRef(branchId, userId).snapshots();
    final metaStream = _metaRef(branchId).snapshots();

    late StreamController<int> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? guestSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? metaSub;

    var guestTicket = -1;
    var guestResolved = false;
    var metaNowServing = 0;
    var metaResolved = false;

    void emit() {
      if (!guestResolved || !metaResolved) return;
      if (guestTicket <= 0) {
        controller.add(-1);
        return;
      }
      final position = guestTicket - metaNowServing - 1;
      controller.add(position >= 0 ? position : -1);
    }

    controller = StreamController<int>(
      onListen: () {
        guestSub = guestStream.listen((snapshot) {
          guestResolved = true;
          final data = snapshot.data();
          final status = data?['status'] as String?;
          final ticket = (data?['myTicket'] as num?)?.toInt() ?? 0;
          guestTicket = (status == statusWaiting && ticket > 0) ? ticket : -1;
          emit();
        });
        metaSub = metaStream.listen((snapshot) {
          metaResolved = true;
          metaNowServing =
              (snapshot.data()?['nowServing'] as num?)?.toInt() ?? 0;
          emit();
        });
      },
      onPause: () {
        guestSub?.pause();
        metaSub?.pause();
      },
      onResume: () {
        guestSub?.resume();
        metaSub?.resume();
      },
      onCancel: () async {
        await guestSub?.cancel();
        await metaSub?.cancel();
        // close_sinks: the outer controller must release when the listener
        // cancels — re-listens create a fresh stream (autoDispose provider).
        await controller.close();
      },
    );
    return controller.stream;
  }
}

final waitlistRepositoryProvider = Provider<WaitlistRepository>((ref) {
  return WaitlistRepository(
    ref.watch(firestoreProvider),
    ref.read(loggerProvider),
    ref.watch(tenantClaimProvider),
  );
});

/// Streams the current user's queue position for the given (branch, user) pair.
/// Emits `-1` when the user is not on the list — the UI renders nothing then.
final waitlistPositionProvider = StreamProvider.autoDispose
    .family<int, ({String branchId, String userId})>((ref, args) {
      return ref
          .watch(waitlistRepositoryProvider)
          .streamQueuePosition(args.branchId, args.userId);
    });
