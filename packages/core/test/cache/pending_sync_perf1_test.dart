import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/isar_native.dart';
import '../helpers/recording_logger.dart';

/// PERF-1 (T-6) — the offline-queue DI surface: queue/badge provider seams,
/// the canonical [FirestoreQueueWriter], and the [KitchenOfflineService]
/// Workmanager fail-and-rethrow contract.
///
/// RESIDUAL (honest): the reactive badge streams (pendingSyncCount/
/// deadLetterCount/deadLetters) resist deterministic coverage under plain
/// `flutter test` (Isar watchLazy → asyncMap emission is not deliverable on
/// the test runner's event loop) — they are exercised by the QUEUE-1 DLQ
/// widget suite in core_app through the same overridden provider graph.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Restore the production-like config for any later reader.
    CoreConfigHolder.set(const DefaultCoreConfig());
  });

  test('syncQueueProvider builds the Isar-backed queue from the DI graph '
      '(canonical Firestore writer)', () {
    // The default provider reads FirestoreClient.instance.db — inject the
    // mock so the DI resolution runs without a Firebase app.
    FirestoreClient.setMock(
      FirestoreClient.testInject(
        FakeFirebaseFirestore(),
        ErrorLoggerService(null),
      ),
    );
    final logger = RecordingLogger();
    // A construction-only service: the memoized future is never awaited by
    // the provider under test, so no DB is opened.
    final service = IsarService.forTesting(Completer<Isar>().future, logger);
    final container = ProviderContainer(
      overrides: [
        isarServiceProvider.overrideWithValue(service),
        loggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(syncQueueProvider), isA<IsarSyncQueue>());
  });

  test('the isarServiceProvider default resolves the shared singleton', () {
    final container = ProviderContainer(
      overrides: [loggerProvider.overrideWithValue(RecordingLogger())],
    );
    addTearDown(container.dispose);

    // The shared() memoization path — no DB is opened by construction.
    expect(container.read(isarServiceProvider), isA<IsarService>());
  });

  group('FirestoreQueueWriter — canonical Firestore adapter (PERF-1)', () {
    test(
      'set with an explicit id upserts the payload (merge honored)',
      () async {
        final db = FakeFirebaseFirestore();
        final writer = FirestoreQueueWriter(db);

        await writer.set('orders', 'ord-1', <String, dynamic>{
          'total': 1999,
        }, options: SetOptions(merge: true));

        final doc = await db.collection('orders').doc('ord-1').get();
        expect(doc.data(), <String, dynamic>{'total': 1999});
      },
    );

    test(
      'set with a NULL id auto-generates one (the pre-QUEUE-1 contract)',
      () async {
        final db = FakeFirebaseFirestore();
        final writer = FirestoreQueueWriter(db);

        await writer.set('orders', null, <String, dynamic>{'total': 500});

        final docs = (await db.collection('orders').get()).docs;
        expect(docs, hasLength(1));
        expect(docs.single.id, isNotEmpty);
      },
    );

    test('delete removes the targeted document', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('orders').doc('ord-9').set(<String, dynamic>{});
      final writer = FirestoreQueueWriter(db);

      await writer.delete('orders', 'ord-9');

      expect(
        (await db.collection('orders').doc('ord-9').get()).exists,
        isFalse,
      );
    });
  });

  group('KitchenOfflineService — Workmanager fail-and-rethrow (PERF-1)', () {
    OrderPayload stubParser(Map<String, dynamic> json) => _StubPayload();

    test('the default constructor resolves its own dependencies', () {
      // No isarService/logger injected → shared() + LoggerService() defaults
      // resolve lazily without any I/O.
      expect(
        KitchenOfflineService(orderPayloadParser: stubParser),
        isA<KitchenOfflineService>(),
      );
    });

    test(
      'initialize surfaces the platform failure as a logged rethrow',
      () async {
        final logger = RecordingLogger();
        final svc = KitchenOfflineService(
          logger: logger,
          orderPayloadParser: stubParser,
        );

        await expectLater(
          svc.initialize(() {}),
          throwsA(anything),
          reason: 'the Workmanager platform channel is absent in tests',
        );
        expect(
          logger.errors,
          contains('KitchenOfflineService.initialize failed'),
        );
      },
    );

    test(
      'scheduleHeartbeat rethrows the platform failure after logging',
      () async {
        final logger = RecordingLogger();
        final svc = KitchenOfflineService(
          logger: logger,
          orderPayloadParser: stubParser,
        );

        await expectLater(svc.scheduleHeartbeat(), throwsA(anything));
        expect(
          logger.errors,
          contains('KitchenOfflineService.scheduleHeartbeat failed'),
        );
      },
    );

    test('cancel rethrows the platform failure after logging', () async {
      final logger = RecordingLogger();
      final svc = KitchenOfflineService(
        logger: logger,
        orderPayloadParser: stubParser,
      );

      await expectLater(svc.cancel(), throwsA(anything));
      expect(logger.errors, isNotEmpty);
    });
  });

  group('IsarService — test-constructor contracts (PERF-1)', () {
    late Directory temp;
    final openedIsars = <Isar>[];

    setUpAll(ensureIsarCoreForTests);

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('perf1_isar_svc');
    });

    tearDown(() async {
      // Release the native file handles BEFORE deleting (Windows locks).
      for (final isar in openedIsars) {
        try {
          await isar.close();
        } catch (_) {
          // best-effort cleanup
        }
      }
      openedIsars.clear();
      try {
        if (await temp.exists()) await temp.delete(recursive: true);
      } catch (_) {
        // A still-locked temp dir is tolerable — every dir is unique.
      }
    });

    test('forTestingWithIsar wraps an ALREADY-OPEN instance (same instance '
        'served)', () async {
      final logger = RecordingLogger();
      final source = IsarService.forTesting(
        null,
        logger,
        'perf1-wrap',
        temp.path,
      );
      final isar = await source.db;
      openedIsars.add(isar);

      final wrapped = IsarService.forTestingWithIsar(isar, logger);
      expect(identical(await wrapped.db, isar), isTrue);
    });

    test(
      'a pre-memoized dbFuture is served directly (never re-opened)',
      () async {
        final logger = RecordingLogger();
        final source = IsarService.forTesting(
          null,
          logger,
          'perf1-memo',
          temp.path,
        );
        final isar = await source.db;
        openedIsars.add(isar);

        final wrapped = IsarService.forTesting(
          Completer<Isar>().future,
          logger,
        );
        wrapped.db = Future.value(isar);
        expect(identical(await wrapped.db, isar), isTrue);
      },
    );

    test(
      'an UNRECOVERABLE open failure is logged and rethrown unchanged',
      () async {
        final logger = RecordingLogger();
        final broken = IsarService.forTesting(
          null,
          logger,
          'perf1-broken',
          '${temp.path}/does/not/exist',
        );

        // The failure is an IsarError (an Error, not an Exception) — the
        // service logs it via the canonical seam and rethrows UNCHANGED.
        await expectLater(broken.db, throwsA(isA<IsarError>()));
        expect(logger.errors, contains('IsarService_openDB failed'));
      },
    );
  });
}

/// Minimal [OrderPayload] double for the parser stub.
class _StubPayload implements OrderPayload {
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'stub': true};
}
