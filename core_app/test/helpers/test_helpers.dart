import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:isar_community/isar.dart' show Id;
import 'package:labs/l10n/app_localizations.dart';

/// Creates a MaterialApp with localization delegates.
/// For tests that need a standalone widget with localizations.
Widget pumpWithLocalizations(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// No-op [LoggerService] double for unit tests that must inject a logger into
/// a service constructor (DI hygiene — no bare `LoggerService()`).
/// Records emitted messages so a test can assert on them.
class FakeLogger implements LoggerService {
  final List<String> _infoMessages = [];
  final List<String> _errorMessages = [];

  List<String> get loggedInfo => _infoMessages;
  List<String> get loggedErrors => _errorMessages;

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    _errorMessages.add(message);
  }

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {
    _errorMessages.add(message);
  }

  @override
  Future<void> info(Map<String, dynamic> context, String message) async {
    _infoMessages.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// STAFF-QUEUE (W5.4) test double for [SyncQueue]: records every
/// enqueue/removeOperation call IN CALL ORDER so service tests can prove the
/// queue-before-write / remove-on-success contract without a real Isar
/// database. `processQueue` is a no-op — replay coverage lives in the real
/// [IsarSyncQueue] tests (staff_status_queue_replay_test.dart).
class RecordingSyncQueue implements SyncQueue {
  /// Ordered event log: 'enqueue:<op>:<id>' and 'remove:<op>:<id>'. When a
  /// shared list is passed to BOTH this double and [RecordingFakeFirestore],
  /// the merged log gives one call-order timeline across queue and Firestore
  /// (the T-1 enqueue-before-write proof surface).
  RecordingSyncQueue({List<String>? events}) : events = events ?? <String>[];

  final List<String> events;

  /// Snapshot of every payload passed to [enqueue], in call order.
  final List<Map<String, dynamic>> enqueuedPayloads = [];

  /// Every id passed to [removeOperation], in call order.
  final List<String> removedIds = [];

  /// Payloads still pending (enqueued and not yet removed) — the durability
  /// assertion surface for T-4 ("queue empty after a successful write").
  List<Map<String, dynamic>> get pendingPayloads {
    final removed = removedIds.toSet();
    return enqueuedPayloads
        .where((payload) => !removed.contains(payload['id']))
        .toList();
  }

  @override
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  ) async {
    events.add('enqueue:$operation:${data['id']}');
    enqueuedPayloads.add(Map<String, dynamic>.of(data));
  }

  @override
  Future<void> removeOperation(String operation, String id) async {
    events.add('remove:$operation:$id');
    removedIds.add(id);
  }

  @override
  Future<void> processQueue() async {}

  @override
  Future<List<IsarDeadLetter>> getDeadLetters() async => <IsarDeadLetter>[];

  @override
  Future<void> retryDeadLetter(Id id) async {}

  @override
  Future<void> dismissDeadLetter(Id id) async {}
}

/// STAFF-QUEUE (W5.4) fake Firestore that records WRITE entry points in call
/// order ([runTransaction] and [collection]), so service tests can prove the
/// queue-enqueue happens BEFORE the Firestore write (T-1). Clear [events]
/// after seeding to scope the log to the call under test.
class RecordingFakeFirestore extends FakeFirebaseFirestore {
  /// Write entry-point log ('collection:<path>', 'write:runTransaction').
  /// Pass a SHARED list with [RecordingSyncQueue]'s to get one merged
  /// call-order timeline for the T-1 ordering assertions.
  RecordingFakeFirestore({List<String>? events})
    : events = events ?? <String>[];

  final List<String> events;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    events.add('write:runTransaction');
    return super.runTransaction<T>(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    // update()-style writes enter through collection(); get() pre-flights do
    // too — record only the collection op, the caller scopes via events.clear().
    events.add('collection:$collectionPath');
    return super.collection(collectionPath);
  }
}
