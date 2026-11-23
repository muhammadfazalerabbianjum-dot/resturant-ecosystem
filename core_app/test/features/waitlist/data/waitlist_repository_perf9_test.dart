// PERF-9 T-2 (W2) — waitlist take-a-ticket (red→green).
//
// Contract (WHITE_LABEL_p09_perf9.md §3 T-2, design FIXED):
//  1. New doc `branches/{bid}/waitlist_meta` { nextTicket:int, nowServing:int }.
//  2. Join = transaction: assigns myTicket = nextTicket++ and writes the guest
//     doc { myTicket } in the SAME transaction (deterministic id `${branchId}_$userId`).
//  3. Serve/leave advances nowServing past the served ticket.
//  4. Customer position = myTicket − nowServing − 1, computed locally from two
//     READABLE docs (own guest doc + meta doc). No list-query. No CF fan-out.
//  5. Rules (W2): branch customers READ waitlist_meta; writes only via the
//     join/leave transaction paths + staff (pinned in the rules suite, T-4).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/waitlist/data/waitlist_repository.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

/// Reads `branches/{bid}/waitlist_meta` (the T-2.1 ordinal doc).
Future<DocumentSnapshot<Map<String, dynamic>>> readMeta(
  FakeFirebaseFirestore firestore,
  String branchId,
) => firestore
    .collection('branches')
    .doc(branchId)
    .collection('waitlist_meta')
    .doc('meta')
    .get();

void main() {
  group('PERF-9 T-2: waitlist take-a-ticket', () {
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

    test(
      'join assigns myTicket = nextTicket++ and writes BOTH docs in one txn',
      () async {
        final result = await repository.joinWaitlist(
          branchId: 'b1',
          userId: 'u1',
          partySize: 2,
        );

        expect(result, WaitlistJoinResult.joined);

        final meta = await readMeta(firestore, 'b1');
        expect(
          meta.exists,
          isTrue,
          reason: 'T-2.1: branches/b1/waitlist_meta must exist after a join',
        );
        expect(
          meta.data()?['nextTicket'],
          2,
          reason: 'nextTicket advanced past 1',
        );
        expect(meta.data()?['nowServing'], 0);

        final guest = await firestore.collection('waitlist').doc('b1_u1').get();
        expect(guest.exists, isTrue);
        expect(guest.data()?['myTicket'], 1);
        expect(guest.data()?['branchId'], 'b1');
        expect(guest.data()?['userId'], 'u1');
        expect(guest.data()?['partySize'], 2);
      },
    );

    test('second joiner gets the next ordinal ticket', () async {
      await repository.joinWaitlist(branchId: 'b1', userId: 'u1', partySize: 2);
      await repository.joinWaitlist(branchId: 'b1', userId: 'u2', partySize: 3);

      final u2 = await firestore.collection('waitlist').doc('b1_u2').get();
      expect(u2.data()?['myTicket'], 2);
      final meta = await readMeta(firestore, 'b1');
      expect(meta.data()?['nextTicket'], 3);
    });

    test('re-join is idempotent and does NOT burn a ticket', () async {
      final first = await repository.joinWaitlist(
        branchId: 'b1',
        userId: 'u1',
        partySize: 2,
      );
      final second = await repository.joinWaitlist(
        branchId: 'b1',
        userId: 'u1',
        partySize: 5,
      );

      expect(first, WaitlistJoinResult.joined);
      expect(second, WaitlistJoinResult.alreadyJoined);

      final meta = await readMeta(firestore, 'b1');
      expect(meta.data()?['nextTicket'], 2, reason: 'no ticket consumed');
      final guests = await firestore.collection('waitlist').get();
      expect(guests.docs, hasLength(1));
    });

    test('position = myTicket − nowServing − 1 (two ahead → 1)', () async {
      await repository.joinWaitlist(branchId: 'b1', userId: 'u1', partySize: 2);
      await repository.joinWaitlist(branchId: 'b1', userId: 'u2', partySize: 2);

      // nowServing = 0; u1 is ticket 1, u2 is ticket 2 → positions 0 and 1.
      final u1Pos = await repository.streamQueuePosition('b1', 'u1').first;
      final u2Pos = await repository.streamQueuePosition('b1', 'u2').first;
      expect(u1Pos, 0);
      expect(u2Pos, 1);

      // Staff serves ticket 1: nowServing advances → u2 becomes position 0.
      // (Assert the serve contract on the ordinal doc first — fake_cloud_firestore
      // can serve a pre-commit snapshot to a brand-new listener immediately
      // after a transaction; the direct read settles the harness.)
      await repository.serveNext(branchId: 'b1');
      final meta = await readMeta(firestore, 'b1');
      expect(
        meta.data()?['nowServing'],
        1,
        reason: 'serveNext advanced the ordinal',
      );
      final u2After = await repository.streamQueuePosition('b1', 'u2').first;
      expect(u2After, 0);
    });

    test(
      'guest leave advances nowServing past own ticket (own-doc path)',
      () async {
        await repository.joinWaitlist(
          branchId: 'b1',
          userId: 'u1',
          partySize: 2,
        );
        await repository.joinWaitlist(
          branchId: 'b1',
          userId: 'u2',
          partySize: 2,
        );

        final left = await repository.leaveWaitlist(
          branchId: 'b1',
          userId: 'u1',
        );
        expect(left, isTrue);

        final meta = await readMeta(firestore, 'b1');
        expect(meta.data()?['nowServing'], 1);

        final u2Pos = await repository.streamQueuePosition('b1', 'u2').first;
        expect(u2Pos, 0);
      },
    );

    test('leave is monotone-safe: nowServing never regresses', () async {
      await repository.joinWaitlist(branchId: 'b1', userId: 'u1', partySize: 2);
      await repository.joinWaitlist(branchId: 'b1', userId: 'u2', partySize: 2);

      await repository.leaveWaitlist(branchId: 'b1', userId: 'u2');
      // u1 leaves AFTER u2: the ticket-1 leave must not pull nowServing back.
      await repository.leaveWaitlist(branchId: 'b1', userId: 'u1');

      final meta = await readMeta(firestore, 'b1');
      expect(meta.data()?['nowServing'], 2);
    });

    test(
      'capacity gate: full joins consume no ticket (fail-closed cap)',
      () async {
        expect(
          await repository.joinWaitlist(
            branchId: 'b1',
            userId: 'u1',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.joined,
        );
        expect(
          await repository.joinWaitlist(
            branchId: 'b1',
            userId: 'u2',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.joined,
        );
        expect(
          await repository.joinWaitlist(
            branchId: 'b1',
            userId: 'u3',
            partySize: 2,
            maxEntries: 2,
          ),
          WaitlistJoinResult.full,
        );

        final meta = await readMeta(firestore, 'b1');
        expect(
          meta.data()?['nextTicket'],
          3,
          reason: 'only 2 tickets ever handed out',
        );

        final guests = await firestore.collection('waitlist').get();
        expect(guests.docs, hasLength(2));
      },
    );

    test('per-branch isolation: meta docs are per-branch', () async {
      await repository.joinWaitlist(branchId: 'b1', userId: 'u1', partySize: 2);
      await repository.joinWaitlist(branchId: 'b2', userId: 'u2', partySize: 2);

      final b1 = await readMeta(firestore, 'b1');
      final b2 = await readMeta(firestore, 'b2');
      expect(b1.data()?['nextTicket'], 2);
      expect(b2.data()?['nextTicket'], 2);
      // And the entry keys stay (branch, user)-scoped.
      final u2InB1 = await firestore.collection('waitlist').doc('b1_u2').get();
      expect(u2InB1.exists, isFalse);
    });

    test('position for a non-queued user is -1', () async {
      final pos = await repository.streamQueuePosition('b1', 'nobody').first;
      expect(pos, -1);
    });
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
