import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/connectivity_sync_trigger.dart';
import 'package:labs/app/sync_queue_auto_trigger.dart';

import 'connectivity_sync_trigger_test.dart' show RecordingSyncQueue;

/// QUEUE-1 T-4 (W5.1(b)(1)) — the app-start trigger flushes the offline queue
/// EXACTLY ONCE.
///
/// `SyncQueueAutoTrigger` is the exact composition-root `initCarnamaApp()`
/// constructs after `IsarService.shared().openDB()` (see
/// `app_bootstrap.dart:_startSyncQueueTriggers`), so
/// this unit test drives the production startup flush path without booting
/// Firebase/Stripe/Workmanager platform channels.
void main() {
  group('QUEUE-1 T-4: app-start auto-trigger', () {
    testWidgets('start() flushes processQueue exactly once', (tester) async {
      final queue = RecordingSyncQueue();
      final connectivityController =
          StreamController<List<ConnectivityResult>>();
      addTearDown(connectivityController.close);
      final connectivityTrigger = ConnectivitySyncTrigger(
        syncQueue: queue,
        connectivityStream: connectivityController.stream,
      );

      final trigger = SyncQueueAutoTrigger(
        syncQueue: queue,
        connectivityTrigger: connectivityTrigger,
      );
      trigger.start();
      addTearDown(trigger.dispose);

      await tester.pump();
      expect(
        queue.processQueueCalls,
        1,
        reason: 'app start must flush the queue exactly once',
      );

      // No connectivity events queued → no additional flushes from the edge
      // trigger; idempotence holds across an extra pump.
      await tester.pump(const Duration(seconds: 6));
      expect(
        queue.processQueueCalls,
        1,
        reason: 'no connectivity restore must not add a second flush',
      );
    });

    test(
      'start() flushes on the BARE event loop (no widget tree); dispose() is safe + idempotent',
      () async {
        final queue = RecordingSyncQueue();
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        addTearDown(connectivityController.close);
        final trigger = SyncQueueAutoTrigger(
          syncQueue: queue,
          connectivityTrigger: ConnectivitySyncTrigger(
            syncQueue: queue,
            connectivityStream: connectivityController.stream,
          ),
        );
        trigger.start();

        // main() has no tester.pump — the flush must land on the bare event
        // loop. Poll deterministically (bounded) instead of asserting nothing.
        for (var i = 0; i < 100 && queue.processQueueCalls == 0; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(
          queue.processQueueCalls,
          1,
          reason: 'the app-start flush must work outside a widget tree too',
        );

        await trigger.dispose();
        await trigger.dispose(); // idempotent — must not throw
        await Future<void>.delayed(Duration.zero);
        expect(
          queue.processQueueCalls,
          1,
          reason: 'dispose must not schedule another flush',
        );
      },
    );
  });
}
