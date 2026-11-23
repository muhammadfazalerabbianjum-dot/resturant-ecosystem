import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:labs/app/connectivity_sync_trigger.dart';

/// A [SyncQueue] recorder that counts processQueue invocations (T-4/T-5).
class RecordingSyncQueue implements SyncQueue {
  int processQueueCalls = 0;

  @override
  Future<void> enqueue(
    String operation,
    String collectionName,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> processQueue() async {
    processQueueCalls++;
  }

  @override
  Future<void> removeOperation(String operation, String id) async {}

  @override
  Future<List<IsarDeadLetter>> getDeadLetters() async => [];

  @override
  Future<void> retryDeadLetter(Id id) async {}

  @override
  Future<void> dismissDeadLetter(Id id) async {}
}

/// QUEUE-1 T-5 (W5.1(b)(2)) — `ConnectivitySyncTrigger` fires `processQueue`
/// ONLY on connectivity RESTORE, debounced 5s, and never double-fires for a
/// first "online" emission at boot (the app-start trigger already flushed).
///
/// Timers are fake inside `testWidgets` (AutomatedTestWidgetsFlutterBinding),
/// so `tester.pump(duration)` advances rxdart's debounce clock deterministically.
void main() {
  group('QUEUE-1 T-5: ConnectivitySyncTrigger', () {
    testWidgets('an offline→online edge flushes once after the 5s debounce', (
      tester,
    ) async {
      final controller = StreamController<List<ConnectivityResult>>();
      addTearDown(controller.close);
      final queue = RecordingSyncQueue();
      final trigger = ConnectivitySyncTrigger(
        syncQueue: queue,
        connectivityStream: controller.stream,
      );
      trigger.start();
      addTearDown(trigger.dispose);

      // Boot: first emission online must NOT flush (app-start already did).
      controller.add([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 5));
      expect(
        queue.processQueueCalls,
        0,
        reason: 'the boot-time online emission must not double-flush',
      );

      // Go offline, then restore — exactly ONE flush.
      controller.add([ConnectivityResult.none]);
      await tester.pump(const Duration(seconds: 5));
      controller.add([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 5));
      expect(queue.processQueueCalls, 1);

      // Staying online emits nothing further.
      controller.add([ConnectivityResult.mobile]);
      await tester.pump(const Duration(seconds: 5));
      expect(queue.processQueueCalls, 1);
    });

    testWidgets('a flapping radio collapses into ONE flush (debounce)', (
      tester,
    ) async {
      final controller = StreamController<List<ConnectivityResult>>();
      addTearDown(controller.close);
      final queue = RecordingSyncQueue();
      final trigger = ConnectivitySyncTrigger(
        syncQueue: queue,
        connectivityStream: controller.stream,
        debounce: const Duration(seconds: 5),
      );
      trigger.start();
      addTearDown(trigger.dispose);

      controller.add([ConnectivityResult.none]);
      await tester.pump(const Duration(seconds: 5));

      // Rapid toggles within the 5s debounce window.
      controller.add([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 1));
      controller.add([ConnectivityResult.none]);
      await tester.pump(const Duration(seconds: 1));
      controller.add([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 5));

      expect(
        queue.processQueueCalls,
        1,
        reason: 'only the final restored state may trigger a single flush',
      );
    });
  });
}
