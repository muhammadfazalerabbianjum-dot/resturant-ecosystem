import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/waitlist/data/waitlist_repository.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  group('WaitlistRepository', () {
    late FakeFirebaseFirestore firestore;
    late WaitlistRepository repository;
    late LoggerService logger;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      logger = LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );
      repository = WaitlistRepository(firestore, logger, _FixedTenantClaim());
    });

    /// fake_cloud_firestore can serve a PRE-COMMIT snapshot to a brand-new
    /// listener created immediately after a transaction commit. A direct
    /// get() settles the local cache â€” harness timing, not production
    /// semantics (real Firestore listeners are server-authoritative).
    Future<void> settle(String branchId) async {
      await firestore.collection('waitlist').get();
      await firestore
          .collection('branches')
          .doc(branchId)
          .collection('waitlist_meta')
          .doc('meta')
          .get();
    }

    test('joinWaitlist adds user to waitlist', () async {
      final result = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      expect(result, WaitlistJoinResult.joined);
      final snapshot = await firestore.collection('waitlist').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['userId'], 'user1');
      expect(snapshot.docs.first.data()['branchId'], 'branch1');
      expect(snapshot.docs.first.data()['partySize'], 2);
      // B4-8 â†’ T-2: a per-branch monotonic ordinal ticket is assigned atomically.
      expect(snapshot.docs.first.data()['myTicket'], 1);
    });

    test('joinWaitlist returns alreadyJoined on re-join (B4-9)', () async {
      final first = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      final second = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 4,
      );
      expect(first, WaitlistJoinResult.joined);
      expect(second, WaitlistJoinResult.alreadyJoined);
      final snapshot = await firestore.collection('waitlist').get();
      // Idempotent: same (branchId, userId) â†’ SAME doc, not a duplicate.
      expect(snapshot.docs.length, 1);
      // The earlier joined doc is NOT overwritten on a re-join.
      expect(snapshot.docs.first.data()['partySize'], 2);
    });

    test('joinWaitlist concurrent double-tap creates ONE doc (P5-10)', () async {
      final results = await Future.wait([
        repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user1',
          partySize: 2,
        ),
        repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user1',
          partySize: 2,
        ),
      ]);
      // B4-9: the deterministic key `waitlist/{branchId}_{userId}` is the
      // de-dup invariant â€” TWO racing writes hit the SAME doc, so at most ONE
      // entry can ever exist. (fake_cloud_firestore's _DummyTransaction is
      // non-atomic, so both may report `joined`; real Firestore aborts one and
      // retries to `alreadyJoined` â€” either way, one doc is the contract that
      // holds everywhere.)
      expect(
        results.every(
          (r) =>
              r == WaitlistJoinResult.joined ||
              r == WaitlistJoinResult.alreadyJoined,
        ),
        isTrue,
        reason: 'a double-tap must never return an error',
      );
      final snapshot = await firestore.collection('waitlist').get();
      expect(snapshot.docs.length, 1, reason: 'double-tap -> exactly ONE doc');
    });

    test('joinWaitlist allows multiple different users', () async {
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user2',
        partySize: 3,
      );
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user3',
        partySize: 4,
      );
      final snapshot = await firestore.collection('waitlist').get();
      expect(snapshot.docs.length, 3);
    });

    test('joinWaitlist returns full when maxEntries reached (B4-9)', () async {
      final full1 = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
        maxEntries: 2,
      );
      expect(full1, WaitlistJoinResult.joined);

      final full2 = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user2',
        partySize: 2,
        maxEntries: 2,
      );
      expect(full2, WaitlistJoinResult.joined);

      final full3 = await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user3',
        partySize: 2,
        maxEntries: 2,
      );
      expect(full3, WaitlistJoinResult.full);
      final snapshot = await firestore.collection('waitlist').get();
      expect(snapshot.docs.length, 2);
    });

    test('streamQueuePosition: first user has 0 people ahead (T-2)', () async {
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );

      await settle('branch1');
      final position = await repository
          .streamQueuePosition('branch1', 'user1')
          .first;
      expect(position, 0);
    });

    test('streamQueuePosition is BRANCH-SCOPED (B4-8)', () async {
      // Same user in a DIFFERENT branch must not affect branch1's position.
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      await repository.joinWaitlist(
        branchId: 'branch2',
        userId: 'user2',
        partySize: 3,
      );
      await settle('branch1');

      final position = await repository
          .streamQueuePosition('branch1', 'user1')
          .first;
      expect(position, 0);
    });

    test(
      'streamQueuePosition returns correct position for second user',
      () async {
        await repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user1',
          partySize: 2,
        );
        await repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user2',
          partySize: 3,
        );

        await settle('branch1');
        final position = await repository
            .streamQueuePosition('branch1', 'user2')
            .first;
        expect(position, 1);
      },
    );

    test('streamQueuePosition returns -1 for user not in queue', () async {
      await settle('branch1');
      final position = await repository
          .streamQueuePosition('branch1', 'nonexistent')
          .first;
      expect(position, -1);
    });

    test('streamQueuePosition ranks by myTicket (T-2)', () async {
      // Seed docs directly with explicit tickets to assert ordering
      // independent of serverTimestamp resolution order.
      // T-2: the key IS `${branchId}_$userId` — the position is read from the
      // user's OWN doc, so the seed must use the deterministic key.
      await firestore.collection('waitlist').doc('b1_userA').set({
        'userId': 'userA',
        'branchId': 'b1',
        'myTicket': 1,
        'status': 'waiting',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 7, 24, 10, 0)),
      });
      await firestore.collection('waitlist').doc('b1_userB').set({
        'userId': 'userB',
        'branchId': 'b1',
        'myTicket': 2,
        'status': 'waiting',
        'joinedAt': Timestamp.fromDate(DateTime(2026, 7, 24, 10, 5)),
      });
      await firestore
          .collection('branches')
          .doc('b1')
          .collection('waitlist_meta')
          .doc('meta')
          .set({'nextTicket': 3, 'nowServing': 0});
      await settle('b1');

      final positionA = await repository
          .streamQueuePosition('b1', 'userA')
          .first;
      final positionB = await repository
          .streamQueuePosition('b1', 'userB')
          .first;
      expect(positionA, 0);
      expect(positionB, 1);
    });

    test('streamQueuePosition excludes removed entries (B4-8)', () async {
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user2',
        partySize: 3,
      );
      // Simulate a host removing user2 from the list (status flip â€” the
      // serve/leave ordinal path is pinned separately in the T-2 suite).
      await firestore.collection('waitlist').doc('branch1_user2').update({
        'status': 'removed',
      });
      await settle('branch1');

      final user1 = await repository
          .streamQueuePosition('branch1', 'user1')
          .first;
      final user2 = await repository
          .streamQueuePosition('branch1', 'user2')
          .first;
      expect(user1, 0, reason: 'removed entries do not rank ahead');
      expect(user2, -1, reason: 'a removed entry is no longer queued');
    });

    test('joinWaitlist sets joinedAt + status', () async {
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      final snapshot = await firestore.collection('waitlist').get();
      expect(snapshot.docs.first.data()['joinedAt'], isNotNull);
      expect(snapshot.docs.first.data()['status'], 'waiting');
    });

    test(
      'joinWaitlist bumps the branch ordinal doc transactionally (T-2)',
      () async {
        // T-2: nextTicket is assigned from a per-branch ordinal doc in the
        // SAME transaction â€” the doc must reflect every accepted join.
        await repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user1',
          partySize: 2,
        );
        await repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user2',
          partySize: 3,
        );
        await repository.joinWaitlist(
          branchId: 'branch1',
          userId: 'user3',
          partySize: 4,
        );

        final meta = await firestore
            .collection('branches')
            .doc('branch1')
            .collection('waitlist_meta')
            .doc('meta')
            .get();
        expect(meta.data()?['nextTicket'], 4);

        // And the entries got the monotonic per-branch tickets 1..3.
        final entries = await firestore.collection('waitlist').get();
        final tickets = entries.docs.map((d) => d.data()['myTicket']).toList()
          ..sort();
        expect(tickets, [1, 2, 3]);
      },
    );

    test('waitlist_meta docs are per-branch isolated (T-2)', () async {
      await repository.joinWaitlist(
        branchId: 'branch1',
        userId: 'user1',
        partySize: 2,
      );
      await repository.joinWaitlist(
        branchId: 'branch2',
        userId: 'user2',
        partySize: 2,
      );

      final b1 = await firestore
          .collection('branches')
          .doc('branch1')
          .collection('waitlist_meta')
          .doc('meta')
          .get();
      final b2 = await firestore
          .collection('branches')
          .doc('branch2')
          .collection('waitlist_meta')
          .doc('meta')
          .get();
      expect(b1.data()?['nextTicket'], 2);
      expect(b2.data()?['nextTicket'], 2);
    });

    test(
      'full + alreadyJoined joins never burn a ticket (fail-closed cap, T-2)',
      () async {
        expect(
          await repository.joinWaitlist(
            branchId: 'branch1',
            userId: 'u1',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.joined,
        );
        expect(
          await repository.joinWaitlist(
            branchId: 'branch1',
            userId: 'u2',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.joined,
        );
        // Capacity reached: this join is rejected and must NOT consume a slot.
        expect(
          await repository.joinWaitlist(
            branchId: 'branch1',
            userId: 'u3',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.full,
        );
        // Re-join is a no-op â€” the idempotent key means NO duplicate ticket.
        expect(
          await repository.joinWaitlist(
            branchId: 'branch1',
            userId: 'u1',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.alreadyJoined,
        );

        final meta = await firestore
            .collection('branches')
            .doc('branch1')
            .collection('waitlist_meta')
            .doc('meta')
            .get();
        expect(
          meta.data()?['nextTicket'],
          3,
          reason: 'full/alreadyJoined must never hand out a ticket',
        );
        final snapshot = await firestore.collection('waitlist').get();
        expect(snapshot.docs.length, 2);
      },
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
