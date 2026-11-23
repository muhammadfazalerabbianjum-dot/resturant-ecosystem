import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:isar_community/isar.dart';

import 'helpers/isar_native.dart';
import 'helpers/recording_logger.dart';

/// Fault-injecting [QueueFirestoreWriter]: records every set/delete, and
/// fails `set` calls with the queued errors until the queue is empty.
class _FaultWriter implements QueueFirestoreWriter {
  final List<Object> _setFailures;
  final sets =
      <({String col, String? id, Map<String, dynamic> data, bool merge})>[];
  final deletes = <({String col, String id})>[];

  _FaultWriter([this._setFailures = const []]);

  @override
  Future<void> set(
    String collectionName,
    String? id,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    if (_setFailures.isNotEmpty) throw _setFailures.removeAt(0);
    sets.add((
      col: collectionName,
      id: id,
      data: data,
      merge: options?.merge == true,
    ));
  }

  @override
  Future<void> delete(String collectionName, String id) async {
    deletes.add((col: collectionName, id: id));
  }
}

void main() {
  setUpAll(ensureIsarCoreForTests);

  late Directory temp;
  // Unique Isar instance name per test: openDB's `Isar.getInstance(name)`
  // backstop would otherwise re-attach the PREVIOUS test's already-open
  // instance (same name → same handle → cross-test data bleed).
  var instanceSeq = 0;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('core_cov_syncq');
    instanceSeq++;
  });

  tearDown(() async {
    // Best-effort: Isar keeps the file handle until GC'd on Windows.
    try {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    } catch (_) {}
  });

  IsarSyncQueue queue(_FaultWriter writer, [RecordingLogger? logger]) =>
      IsarSyncQueue(
        IsarService.forTesting(
          null,
          logger ?? RecordingLogger(),
          'syncq-$instanceSeq',
          temp.path,
        ),
        logger ?? RecordingLogger(),
        firestore: writer,
      );

  test(
    'create ops are delivered with merge semantics and then removed',
    () async {
      final writer = _FaultWriter();
      final q = queue(writer);
      await q.enqueue('create', 'orders', <String, dynamic>{
        'id': 'o-1',
        'total': 12,
      });

      await q.processQueue();

      expect(writer.sets, hasLength(1));
      expect(writer.sets.single.col, 'orders');
      expect(writer.sets.single.id, 'o-1');
      expect(writer.sets.single.merge, isTrue, reason: 'idempotent replay');
      expect(writer.sets.single.data['total'], 12);
      expect(writer.sets.single.data['updatedAt'], isA<FieldValue>());
      final dead = await q.getDeadLetters();
      expect(dead, isEmpty);
    },
  );

  test(
    'a transient failure keeps the op pending and a retry delivers it',
    () async {
      final writer = _FaultWriter(<Object>[Exception('network blip')]);
      final q = queue(writer);
      await q.enqueue('create', 'orders', <String, dynamic>{'id': 'o-2'});

      await q.processQueue();
      expect(writer.sets, isEmpty, reason: 'the first attempt failed');

      await q.processQueue();
      expect(writer.sets, hasLength(1));
      expect(writer.sets.single.id, 'o-2');
      final dead = await q.getDeadLetters();
      expect(dead, isEmpty, reason: 'recovered — never dead-lettered');
    },
  );

  test('permission-denied goes STRAIGHT to the DLQ (no retry burn)', () async {
    final writer = _FaultWriter(<Object>[
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'rules reject',
      ),
    ]);
    final q = queue(writer);
    await q.enqueue('create', 'orders', <String, dynamic>{'id': 'o-3'});

    await q.processQueue();

    final dead = await q.getDeadLetters();
    expect(dead, hasLength(1));
    expect(dead.single.retryCount, 0);
    expect(dead.single.lastError, contains('permission-denied'));
    final data = jsonDecode(dead.single.dataString) as Map<String, dynamic>;
    expect(data['id'], 'o-3', reason: 'payload preserved for operator re-run');
  });

  test(
    'a delete op without an id is fail-closed (stays pending, retries)',
    () async {
      final writer = _FaultWriter();
      final q = queue(writer);
      await q.enqueue('delete', 'orders', <String, dynamic>{'nope': true});

      await q.processQueue();

      expect(writer.deletes, isEmpty, reason: 'nothing was silently dropped');
      final dead = await q.getDeadLetters();
      expect(dead, isEmpty, reason: 'transient-classified — retry path');
    },
  );

  test(
    'retryDeadLetter re-enqueues with a fresh retry count; dismiss drops',
    () async {
      final writer = _FaultWriter(<Object>[
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ]);
      final q = queue(writer);
      await q.enqueue('create', 'orders', <String, dynamic>{'id': 'o-4'});
      await q.processQueue();
      var dead = await q.getDeadLetters();
      expect(dead, hasLength(1));

      // Dismiss: dropped WITHOUT re-enqueue (operator judged it unrecoverable).
      await q.dismissDeadLetter(dead.single.id);
      expect(await q.getDeadLetters(), isEmpty);

      // Retry path: o-5 dead-letters first (writer still denying), then the
      // operator retries it and the writer recovers → delivered.
      await q.enqueue('create', 'orders', <String, dynamic>{'id': 'o-5'});
      await q.processQueue();
      dead = await q.getDeadLetters();
      expect(dead, hasLength(1));

      writer._setFailures.clear();
      await q.retryDeadLetter(dead.single.id);
      expect(await q.getDeadLetters(), isEmpty);

      await q.processQueue();
      expect(writer.sets.map((s) => s.id), contains('o-5'));
    },
  );

  test('removeOperation deletes only the matching pending op', () async {
    final writer = _FaultWriter();
    final q = queue(writer);
    await q.enqueue('create', 'orders', <String, dynamic>{'id': 'keep'});
    await q.enqueue('create', 'orders', <String, dynamic>{'id': 'drop'});

    await q.removeOperation('create', 'drop');
    await q.processQueue();

    expect(writer.sets.map((s) => s.id), ['keep']);
  });

  test(
    'the DLQ is FIFO-capped at kMaxDeadLetters (oldest evicted first)',
    () async {
      // Every write is rules-denied → each op lands in the DLQ on the first
      // processQueue pass; the (cap+1)-th put must evict the OLDEST entry.
      final writer = _FaultWriter(<Object>[
        ...List.generate(
          IsarSyncQueue.kMaxDeadLetters + 1,
          (_) => FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      ]);
      final q = queue(writer);
      for (var i = 0; i <= IsarSyncQueue.kMaxDeadLetters; i++) {
        await q.enqueue('create', 'orders', <String, dynamic>{
          'id': 'flood-$i',
        });
      }

      await q.processQueue();

      final dead = await q.getDeadLetters();
      expect(dead, hasLength(IsarSyncQueue.kMaxDeadLetters));
      final ids = dead.map((e) {
        final data = jsonDecode(e.dataString) as Map<String, dynamic>;
        return data['id'] as String;
      }).toSet();
      expect(
        ids.contains('flood-0'),
        isFalse,
        reason: 'the OLDEST entry was FIFO-evicted',
      );
      expect(
        ids.contains('flood-${IsarSyncQueue.kMaxDeadLetters}'),
        isTrue,
        reason: 'the NEWEST entry survived',
      );
    },
  );

  // ── P8(W3) coverage-hardening: the queue's failure paths are behavior ────
  // Every catch block below is a REAL product behavior (fail-closed logging,
  // DLQ move, empty-list backstop), so the tests drive the exact failure the
  // dependency surfaces rather than skipping them.
  group('P8(W3) failure-path behavior', () {
    late Directory temp2;
    var seq2 = 0;

    setUp(() async {
      temp2 = await Directory.systemTemp.createTemp('core_cov_syncq_fp');
      seq2++;
    });

    tearDown(() async {
      try {
        if (await temp2.exists()) await temp2.delete(recursive: true);
      } catch (_) {}
    });

    /// A queue whose Isar layer is already dead (the on-disk store failed to
    /// open — the brick every catch block exists for).
    (IsarSyncQueue, RecordingLogger) brokenQueue() {
      final logger = RecordingLogger();
      final q = IsarSyncQueue(
        IsarService.forTesting(
          Future<Isar>.error(StateError('store unavailable')),
          logger,
          'syncq-broken-$seq2',
          temp2.path,
        ),
        logger,
        firestore: _FaultWriter(),
      );
      return (q, logger);
    }

    test('enqueue swallows the store failure but logs it loudly', () async {
      final (q, logger) = brokenQueue();
      await q.enqueue('create', 'orders', {'id': 'x'});

      expect(logger.errors, contains('SyncQueue_enqueue'));
    });

    test('removeOperation logs the store failure', () async {
      final (q, logger) = brokenQueue();
      await q.removeOperation('create', 'x');
      expect(logger.errors, contains('SyncQueue_removeOperation'));
    });

    test('getDeadLetters fails closed to an empty list, with a log', () async {
      final (q, logger) = brokenQueue();
      expect(await q.getDeadLetters(), isEmpty);
      expect(logger.errors, contains('SyncQueue_getDeadLetters'));
    });

    test(
      'retryDeadLetter / dismissDeadLetter log instead of crashing',
      () async {
        final (q, logger) = brokenQueue();
        await q.retryDeadLetter(1);
        await q.dismissDeadLetter(1);
        expect(logger.errors, contains('SyncQueue_retryDeadLetter'));
        expect(logger.errors, contains('SyncQueue_dismissDeadLetter'));
      },
    );

    test('processQueue logs the store failure (outer catch)', () async {
      final (q, logger) = brokenQueue();
      await q.processQueue();
      expect(logger.errors, contains('SyncQueue_process'));
    });

    test('delete ops dispatch to the writer with the target id', () async {
      final writer = _FaultWriter();
      final logger = RecordingLogger();
      final service = IsarService.forTesting(
        null,
        logger,
        'syncq-del-$seq2',
        temp2.path,
      );
      final q = IsarSyncQueue(service, logger, firestore: writer);
      await q.enqueue('delete', 'orders', {'id': 'o-del-1'});

      await q.processQueue();

      expect(writer.deletes.single.col, 'orders');
      expect(writer.deletes.single.id, 'o-del-1');
      expect(await q.getDeadLetters(), isEmpty);
      final isar = await service.db;
      expect(
        await isar.isarPendingOperations.where().findAll(),
        isEmpty,
        reason: 'a delivered delete is removed from the queue',
      );
    });

    test('an op past kMaxRetries moves to the DLQ and is deleted', () async {
      final writer = _FaultWriter();
      final logger = RecordingLogger();
      final service = IsarService.forTesting(
        null,
        logger,
        'syncq-maxr-$seq2',
        temp2.path,
      );
      final isar = await service.db;
      final q = IsarSyncQueue(service, logger, firestore: writer);

      await q.enqueue('create', 'orders', {'id': 'o-poison'});
      // Age the op past the retry budget exactly as repeated drains would.
      final op = (await isar.isarPendingOperations.where().findAll()).single;
      await isar.writeTxn(() async {
        op.retryCount = IsarSyncQueue.kMaxRetries;
        await isar.isarPendingOperations.put(op);
      });

      await q.processQueue();

      final dead = await isar.isarDeadLetters.where().findAll();
      expect(dead, hasLength(1));
      expect(dead.single.dataString, contains('o-poison'));
      expect(dead.single.retryCount, IsarSyncQueue.kMaxRetries);
      expect(
        await isar.isarPendingOperations.where().findAll(),
        isEmpty,
        reason: 'the DLQ move consumed the pending op',
      );
      expect(logger.errors, contains('SyncQueue_max_retries'));
    });
  });
}
