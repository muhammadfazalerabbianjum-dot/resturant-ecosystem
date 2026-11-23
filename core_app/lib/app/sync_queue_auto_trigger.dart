import 'dart:async';

import 'package:core/core.dart';
import 'package:labs/app/connectivity_sync_trigger.dart';

/// QUEUE-1 (W5.1(b)) — composition-root for the offline queue's IMPULSE
/// auto-triggers. `main()` builds it after `IsarService.shared().openDB()` and calls
/// [start], which:
///
///   1. runs one app-start `processQueue()` flush (unawaited, exactly once);
///   2. starts the [ConnectivitySyncTrigger] (5 s-debounced, offline→online
///      edge only).
///
/// The periodic Workmanager safety net is registered separately via
/// `QueueSyncScheduler` at the same wiring site (`core_app/lib/app_bootstrap.dart`); keeping it out
/// of this class lets the impulse triggers remain platform-channel-free (the
/// app-start + connectivity behavior is fully unit-testable).
class SyncQueueAutoTrigger {
  SyncQueueAutoTrigger({
    required SyncQueue syncQueue,
    ConnectivitySyncTrigger? connectivityTrigger,
  }) : _syncQueue = syncQueue,
       _connectivityTrigger =
           connectivityTrigger ?? ConnectivitySyncTrigger(syncQueue: syncQueue);

  final SyncQueue _syncQueue;
  final ConnectivitySyncTrigger _connectivityTrigger;

  /// Starts the impulse triggers: one app-start flush + the connectivity edge
  /// trigger. Idempotent as a whole (repeat calls just re-flush harmlessly).
  void start() {
    unawaited(_syncQueue.processQueue());
    _connectivityTrigger.start();
  }

  Future<void> dispose() => _connectivityTrigger.dispose();
}
