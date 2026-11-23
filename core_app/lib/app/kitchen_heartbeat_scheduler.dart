import 'package:core/core.dart';

import '../features/orders/domain/kitchen_task_dispatcher.dart';

/// PUSH-1 (W5.3 / 02-P1-KITCHEN) — composition-root registration of the
/// kitchen heartbeat's 15-minute Workmanager task.
///
/// Before this class existed, `KitchenOfflineService.initialize` +
/// `scheduleHeartbeat` had ZERO callers in `lib/` (audit 02-P1-KITCHEN) —
/// the kitchen LAN offline fallback was dead code in production.
///
/// `core_app/lib/app_bootstrap.dart` (`_schedulePeriodicQueueSync`) constructs ONE instance after
/// `IsarService.shared().openDB()` and calls [schedule], which:
///
///   1. `service.initialize(kitchenTaskDispatcher)` — registers the app's
///      SINGLE Workmanager callback (`kitchenTaskDispatcher` routes BOTH
///      `kKitchenHeartbeatTask` AND QUEUE-1's `kQueueSyncTask`). Calling
///      `Workmanager().initialize` with a DIFFERENT dispatcher later would
///      silently clobber the registered callback, so this is the only
///      initialize site in the app;
///   2. `service.scheduleHeartbeat()` — `registerPeriodicTask` for
///      `kKitchenHeartbeatTask` with `existingWorkPolicy: keep` (idempotent
///      OS registration across app restarts).
///
/// The guarded [_scheduled] bool makes [schedule] a no-op on repeat calls in
/// the same process (defense-in-depth on top of the `keep` policy).
class KitchenHeartbeatScheduler {
  KitchenHeartbeatScheduler({required KitchenOfflineService service})
    : _service = service;

  final KitchenOfflineService _service;

  bool _scheduled = false;

  /// True once this instance has registered the heartbeat.
  bool get isScheduled => _scheduled;

  /// Registers the heartbeat exactly once per instance (the app builds a
  /// single instance in `main()`, so once per process). Idempotent thereafter.
  Future<void> schedule() async {
    if (_scheduled) return;
    _scheduled = true;
    await _service.initialize(kitchenTaskDispatcher);
    await _service.scheduleHeartbeat();
  }
}
