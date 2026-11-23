import 'package:core/core.dart';
import 'package:workmanager/workmanager.dart';
import 'order_payload_adapter.dart';

/// Top-level Workmanager entry point for the app's background periodic tasks.
///
/// Must be annotated with `@pragma('vm:entry-point')` so the tree-shaker keeps
/// it. Lives in the feature layer because it wires the core service to the
/// feature-side [OrderPayloadAdapter] — core cannot import features.
///
/// QUEUE-1 (W5.1(b)(3)): this is also the dispatcher for `kQueueSyncTask`
/// (the offline-queue 15-minute safety net) so the app keeps a SINGLE
/// Workmanager callback/dispatcher — two `Workmanager().initialize(...)`
/// calls would clobber each other when PUSH-1 wires the kitchen heartbeat.
@pragma('vm:entry-point')
void kitchenTaskDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case kKitchenHeartbeatTask:
        await KitchenOfflineService(
          orderPayloadParser: OrderPayloadAdapter.fromJson,
        ).runHeartbeat();
        break;
      case kQueueSyncTask:
        await IsarSyncQueue(
          IsarService.shared(),
          LoggerService(),
          firestore: FirestoreQueueWriter(FirestoreClient.instance.db),
        ).processQueue();
        break;
    }
    return Future.value(true);
  });
}
