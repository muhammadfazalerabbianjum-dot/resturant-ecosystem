import 'package:core/core.dart';
import 'package:workmanager/workmanager.dart';

/// QUEUE-1 (W5.1(b)(3)) — periodic safety net for the offline queue.
///
/// A Workmanager periodic task calls `processQueue()` every 15 minutes (the
/// minimum Android frequency) so the queue self-delivers even when no other
/// trigger fires — e.g. the process was backgrounded for hours after a failed
/// connectivity restore detection. `existingWorkPolicy: keep` makes the OS
/// registration idempotent across app restarts and duplicates the app-start
/// flush deliberately (documented QUEUE-1 residual); `processQueue` is
/// idempotent so a double trigger is a no-op flush.
///
/// The background callback that routes `kQueueSyncTask` to the queue lives in
/// `kitchen_task_dispatcher.dart` (the app's single Workmanager entry point).
class QueueSyncScheduler {
  static const String uniqueName = 'queue-sync-periodic';

  Future<void> schedule() async {
    await Workmanager().registerPeriodicTask(
      uniqueName,
      kQueueSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
