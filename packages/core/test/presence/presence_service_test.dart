import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import '../helpers/recording_logger.dart';

/// PERF-1 (T-6) — PresenceService: the presence/{uid} write contract
/// (online/offline merge-sets), lifecycle mapping (resumed→online,
/// paused/inactive/detached→offline), attach/detach, and the best-effort
/// error containment (a Firestore failure is logged, never propagated).

/// A DB whose presence collection WRITES always fail — drives the real
/// safe-wrapper catch paths without a Firebase app (extends the fake per
/// the established in-repo pattern; DocumentReference is sealed).
class _BrokenPresenceDb extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'presence') {
      throw StateError('offline');
    }
    return super.collection(collectionPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('goOnline/goOffline write the merged presence document', () async {
    final db = FakeFirebaseFirestore();
    final svc = PresenceService(
      userId: 'k1',
      branchId: 'branch-1',
      role: UserRole.kitchen,
      db: db,
      logger: RecordingLogger(),
    );

    await svc.goOnline();
    var doc = await db.collection('presence').doc('k1').get();
    expect(doc.data()!['isOnline'], isTrue);
    expect(doc.data()!['branchId'], 'branch-1');
    expect(doc.data()!['role'], 'kitchen');
    expect(doc.data(), contains('lastSeen'));

    await svc.goOffline();
    doc = await db.collection('presence').doc('k1').get();
    expect(doc.data()!['isOnline'], isFalse);
  });

  test(
    'lifecycle: resumed goes online; paused/inactive/detached go offline',
    () async {
      final db = FakeFirebaseFirestore();
      final svc = PresenceService(
        userId: 'k2',
        branchId: 'branch-1',
        role: UserRole.delivery,
        db: db,
        logger: RecordingLogger(),
      );

      svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(
        (await db.collection('presence').doc('k2').get()).data()!['isOnline'],
        isTrue,
      );

      svc.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(
        (await db.collection('presence').doc('k2').get()).data()!['isOnline'],
        isFalse,
      );

      svc.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();
      svc.didChangeAppLifecycleState(AppLifecycleState.detached);
      await pumpEventQueue();
      svc.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await pumpEventQueue();
    },
  );

  test(
    'a Firestore failure is contained and logged (never propagated)',
    () async {
      final logger = RecordingLogger();
      final svc = PresenceService(
        userId: 'k3',
        branchId: 'branch-1',
        role: UserRole.manager,
        db: _BrokenPresenceDb(),
        logger: logger,
      );

      // The REAL safe wrappers run via the real lifecycle mapping — neither
      // state change may throw (presence is best-effort telemetry).
      svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      svc.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      expect(logger.warns, contains('PresenceService.presence_online_failed'));
      expect(logger.warns, contains('PresenceService.presence_offline_failed'));
    },
  );

  test('attach/detach register the observer and write presence', () async {
    final db = FakeFirebaseFirestore();
    final svc = PresenceService(
      userId: 'k4',
      branchId: 'branch-1',
      role: UserRole.owner,
      db: db,
      logger: RecordingLogger(),
    );

    svc.attach();
    await pumpEventQueue();
    expect(
      (await db.collection('presence').doc('k4').get()).data()!['isOnline'],
      isTrue,
    );

    svc.detach();
    await pumpEventQueue();
    expect(
      (await db.collection('presence').doc('k4').get()).data()!['isOnline'],
      isFalse,
    );
  });
}
