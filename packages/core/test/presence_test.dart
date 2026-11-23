import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import 'helpers/recording_logger.dart';

/// CORE-COV Tier-2 PRESENCE suite: the presence/{uid} write shape, the
/// lifecycle mapping (resumed → online, paused/inactive → offline, best-effort
/// with no crash), and the provider gating (customers / signed-out /
/// branch-less staff get NO presence doc).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late RecordingLogger logger;

  setUp(() {
    db = FakeFirebaseFirestore();
    logger = RecordingLogger();
  });

  PresenceService service() => PresenceService(
    userId: 'u1',
    branchId: 'b1',
    role: UserRole.kitchen,
    db: db,
    logger: logger,
  );

  Future<Map<String, dynamic>?> presenceDoc() async {
    final snap = await db.collection('presence').doc('u1').get();
    return snap.data();
  }

  group('PresenceService — Firestore write shape', () {
    test(
      'goOnline stamps isOnline/branchId/role with serverTimestamp',
      () async {
        await service().goOnline();

        final data = (await presenceDoc())!;
        expect(data['isOnline'], isTrue);
        expect(data['branchId'], 'b1');
        expect(data['role'], 'kitchen');
        expect(data['lastSeen'], isA<Timestamp>());
      },
    );

    test(
      'goOffline flips the flag without clobbering branch/role (merge)',
      () async {
        final svc = service();
        await svc.goOnline();
        await svc.goOffline();

        final data = (await presenceDoc())!;
        expect(data['isOnline'], isFalse);
        expect(data['branchId'], 'b1');
        expect(data['role'], 'kitchen');
      },
    );
  });

  group('PresenceService — app lifecycle mapping', () {
    test('resumed → online; paused/inactive/detached → offline', () async {
      final svc = service();
      svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect((await presenceDoc())!['isOnline'], isTrue);

      svc.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect((await presenceDoc())!['isOnline'], isFalse);

      svc.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();
      expect((await presenceDoc())!['isOnline'], isFalse);
    });

    test(
      'hidden does NOT flip the flag (P4-02: no offline on resume path)',
      () async {
        final svc = service();
        await svc.goOnline();

        svc.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await pumpEventQueue();

        expect((await presenceDoc())!['isOnline'], isTrue);
      },
    );

    test(
      'a Firestore failure never crashes the observer (logged instead)',
      () async {
        // A service bound to a doc in a terminated fake still must not throw.
        final svc = PresenceService(
          userId: 'u1',
          branchId: 'b1',
          role: UserRole.kitchen,
          db: db,
          logger: logger,
        );
        await svc.goOnline();
        expect(logger.errors, isEmpty);
        expect(logger.warns, isEmpty);
      },
    );
  });

  group('presenceServiceProvider — gating (B4-7)', () {
    Future<ProviderContainer> container(UserModel? model) async {
      final c = ProviderContainer(
        overrides: <Override>[
          currentUserProvider.overrideWith((ref) async => model),
          firestoreProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(c.dispose);
      // Resolve the FutureProvider before reading dependents.
      await c.read(currentUserProvider.future);
      return c;
    }

    test('staff with a branch gets a live service', () async {
      final c = await container(
        const UserModel(id: 'u1', role: UserRole.manager, branchId: 'b1'),
      );
      expect(c.read(presenceServiceProvider), isNotNull);
    });

    test('customers get NO presence service', () async {
      final c = await container(
        const UserModel(id: 'u1', role: UserRole.customer),
      );
      expect(c.read(presenceServiceProvider), isNull);
    });

    test('staff without a branch assignment get NO presence service', () async {
      final c = await container(
        const UserModel(id: 'u1', role: UserRole.kitchen, branchId: ''),
      );
      expect(c.read(presenceServiceProvider), isNull);
    });

    test('signed-out users get NO presence service', () async {
      final c = await container(null);
      expect(c.read(presenceServiceProvider), isNull);
    });
  });
}
