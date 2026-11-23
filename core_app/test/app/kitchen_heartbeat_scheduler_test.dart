import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../helpers/isar_test_boot.dart';
import 'package:labs/app/kitchen_heartbeat_scheduler.dart';

/// No-op logger double — never touches `path_provider`/Crashlytics.
class _NoopLogger extends LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {}
}

/// Counting double — overrides the two Workmanager-backed methods so the
/// test never touches platform channels while still exercising the REAL
/// scheduler logic (guarded bool + call order).
///
/// The super constructor receives a REAL offline Isar-backed `IsarService`
/// (temp dir — the same DI harness as the kitchen_offline_service tests)
/// because the production shared service (`IsarService.shared()`) opens its
/// store through the `path_provider` platform channel, which is unavailable
/// in unit tests (its lazy `openDB()` would throw MissingPluginException on
/// the first `db` read). The parser lambda throws if ever invoked —
/// the overridden methods below must be the only entry points exercised.
class _CountingKitchenService extends KitchenOfflineService {
  _CountingKitchenService(IsarService inertIsarService)
    : super(
        isarService: inertIsarService,
        orderPayloadParser: (json) =>
            throw UnimplementedError('parser must never be called'),
      );

  int initializeCalls = 0;
  int scheduleHeartbeatCalls = 0;
  final List<String> calls = <String>[];

  @override
  Future<void> initialize(void Function() dispatcher) async {
    initializeCalls++;
    calls.add('initialize');
  }

  @override
  Future<void> scheduleHeartbeat() async {
    scheduleHeartbeatCalls++;
    calls.add('scheduleHeartbeat');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One REAL offline Isar (temp dir) shared by the counting doubles: the
  // service methods under test are overridden, so the DB is never touched —
  // it exists only so the double's constructor avoids the production
  // `IsarService.shared()` service (see _CountingKitchenService).
  late Isar isar;
  late Directory dir;
  late IsarService inertIsarService;

  setUpAll(() async {
    await ensureIsarCoreForTests();
    dir = Directory.systemTemp.createTempSync('heartbeat_scheduler_');
    isar = await Isar.open([
      IsarMenuItemSchema,
      IsarCartSchema,
      IsarPendingOperationSchema,
      IsarDeadLetterSchema,
    ], directory: dir.path);
    inertIsarService = IsarService.forTesting(
      Future.value(isar),
      _NoopLogger(),
    );
  });

  tearDownAll(() async {
    await isar.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('KitchenHeartbeatScheduler', () {
    test('schedule() initializes the single dispatcher THEN registers the '
        'heartbeat, exactly once', () async {
      final service = _CountingKitchenService(inertIsarService);
      final scheduler = KitchenHeartbeatScheduler(service: service);

      await scheduler.schedule();

      expect(scheduler.isScheduled, isTrue);
      expect(service.initializeCalls, 1);
      expect(service.scheduleHeartbeatCalls, 1);
      // Contract order: Workmanager().initialize (via service.initialize)
      // MUST precede registerPeriodicTask (via scheduleHeartbeat).
      expect(service.calls, ['initialize', 'scheduleHeartbeat']);
    });

    test('repeat schedule() calls are a no-op (guarded bool)', () async {
      final service = _CountingKitchenService(inertIsarService);
      final scheduler = KitchenHeartbeatScheduler(service: service);

      await scheduler.schedule();
      await scheduler.schedule();
      await scheduler.schedule();

      expect(service.initializeCalls, 1);
      expect(service.scheduleHeartbeatCalls, 1);
    });

    test('separate instances schedule independently (main() builds exactly ONE '
        'instance, so the app schedules once per process)', () async {
      final service = _CountingKitchenService(inertIsarService);
      await KitchenHeartbeatScheduler(service: service).schedule();
      await KitchenHeartbeatScheduler(service: service).schedule();

      expect(service.initializeCalls, 2);
      expect(service.scheduleHeartbeatCalls, 2);
    });

    test('A5 wiring conformance: initCarnamaApp delegates to the guarded '
        'scheduler and Workmanager().initialize has exactly ONE app-side '
        'site (inside KitchenOfflineService.initialize)', () {
      final mainSource = File('lib/app_bootstrap.dart').readAsStringSync();
      final schedulerSource = File(
        'lib/app/kitchen_heartbeat_scheduler.dart',
      ).readAsStringSync();
      final coreServiceSource = File(
        '../packages/core/lib/src/kitchen/kitchen_offline_service.dart',
      ).readAsStringSync();

      // app_bootstrap.dart wires the kitchen heartbeat through the scheduler:
      expect('KitchenHeartbeatScheduler('.allMatches(mainSource).length, 1);
      expect(mainSource, contains('OrderPayloadAdapter.fromJson'));

      // Single-initialize invariant: ZERO direct Workmanager().initialize
      // calls in the app layer (a second dispatcher would clobber the
      // registered callback).
      expect('Workmanager().initialize('.allMatches(mainSource).length, 0);

      // The guarded bool exists in the scheduler...
      expect(schedulerSource, contains('if (_scheduled) return;'));
      // ...the ONLY initialize site in the estate is the core service...
      expect(
        'Workmanager().initialize('.allMatches(coreServiceSource).length,
        1,
      );
      // ...and the app's single dispatcher routes BOTH background task
      // kinds (kitchen heartbeat + queue sync).
      final dispatcherSource = File(
        'lib/features/orders/domain/kitchen_task_dispatcher.dart',
      ).readAsStringSync();
      expect(dispatcherSource, contains('kKitchenHeartbeatTask'));
      expect(dispatcherSource, contains('kQueueSyncTask'));
    });
  });
}
