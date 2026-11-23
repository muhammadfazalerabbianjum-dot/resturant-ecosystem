import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/cloud_function_mocks.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late ProviderContainer container;
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fakeDb),
        loggerProvider.overrideWithValue(FakeLogger()),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Returns the REAL CloudFunctionMocksService (kDemoMode is false in tests,
  /// so no timers/subscriptions are started).
  CloudFunctionMocksService service() =>
      container.read(cloudFunctionMocksProvider);

  group('CloudFunctionMocks TTL Logic', () {
    test('does nothing when no expired locks', () async {
      await service().enforceReservationLockTTL();
      final locks = await fakeDb.collection('reservation_locks').get();
      expect(locks.docs.length, equals(0));
    });

    test('deletes expired locks but keeps non-expired locks', () async {
      final past = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final future = Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 10)),
      );

      await fakeDb.collection('reservation_locks').doc('lock1').set({
        'expiresAt': past,
      });
      await fakeDb.collection('reservation_locks').doc('lock2').set({
        'expiresAt': future,
      });

      await service().enforceReservationLockTTL();

      final remaining = await fakeDb.collection('reservation_locks').get();
      expect(remaining.docs.length, equals(1));
      expect(remaining.docs[0].id, equals('lock2'));
    });

    test('deletes multiple expired locks', () async {
      final past = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );

      for (var i = 0; i < 5; i++) {
        await fakeDb.collection('reservation_locks').doc('lock$i').set({
          'expiresAt': past,
        });
      }

      await service().enforceReservationLockTTL();

      final remaining = await fakeDb.collection('reservation_locks').get();
      expect(remaining.docs.length, equals(0));
    });

    test('is idempotent when no locks exist', () async {
      await service().enforceReservationLockTTL();
      await service().enforceReservationLockTTL();
    });

    test('locks expiring exactly now are also removed', () async {
      final exactNow = Timestamp.now();
      await fakeDb.collection('reservation_locks').doc('edgeLock').set({
        'expiresAt': exactNow,
      });
      await service().enforceReservationLockTTL();
      final remaining = await fakeDb.collection('reservation_locks').get();
      expect(remaining.docs.length, equals(0));
    });
  });

  group('CloudFunctionMocks Driver Abandonment', () {
    test('does nothing when no accepted orders', () async {
      final count = await service().scanAbandonedDriversNow();
      expect(count, equals(0));
    });

    test('does nothing when driver is recently active', () async {
      final recentTimestamp = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await fakeDb.collection('orders').doc('order1').set({
        'tenantId': 'tenant_a',
        'status': 'accepted',
        'assignedDriverId': 'driver1',
      });
      await fakeDb.collection('driverLocations').doc('driver1').set({
        'updatedAt': recentTimestamp,
      });

      final count = await service().scanAbandonedDriversNow();
      expect(count, equals(0));
    });

    test('unassigns driver inactive for more than 15 minutes', () async {
      final staleTimestamp = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 20)),
      );
      await fakeDb.collection('orders').doc('order1').set({
        'tenantId': 'tenant_a',
        'status': 'accepted',
        'assignedDriverId': 'driver1',
      });
      await fakeDb.collection('driverLocations').doc('driver1').set({
        'updatedAt': staleTimestamp,
      });

      final count = await service().scanAbandonedDriversNow();
      expect(count, equals(1));

      final updatedOrder = await fakeDb
          .collection('orders')
          .doc('order1')
          .get();
      expect(updatedOrder.data()?['assignedDriverId'], isNull);
      expect(updatedOrder.data()?['status'], equals('ready'));
    });

    test('handles multiple stale drivers simultaneously', () async {
      final staleTimestamp = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 20)),
      );
      for (var i = 0; i < 3; i++) {
        await fakeDb.collection('orders').doc('order$i').set({
          'tenantId': 'tenant_a',
          'status': 'accepted',
          'assignedDriverId': 'driver$i',
        });
        await fakeDb.collection('driverLocations').doc('driver$i').set({
          'updatedAt': staleTimestamp,
        });
      }

      final count = await service().scanAbandonedDriversNow();
      expect(count, equals(3));
    });

    test('leaves recently-active driver assigned', () async {
      final recentTimestamp = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      await fakeDb.collection('orders').doc('order1').set({
        'tenantId': 'tenant_a',
        'status': 'accepted',
        'assignedDriverId': 'driver1',
      });
      await fakeDb.collection('driverLocations').doc('driver1').set({
        'updatedAt': recentTimestamp,
      });

      final count = await service().scanAbandonedDriversNow();
      expect(count, equals(0));
    });
  });

  /// PERF-2 S4: the daemon half of the service — `startDaemons`/`stopDaemons`
  /// and the two realtime listeners the provider only starts under kDemoMode
  /// (so nothing else in the suite ever reaches them).
  group('CloudFunctionMocks daemons', () {
    late ProviderContainer daemonContainer;
    late FakeFirebaseFirestore daemonDb;
    late FakeLogger daemonLogger;
    late ProviderSubscription<CloudFunctionMocksService> daemonSub;
    final mockUser = MockUser(uid: 'owner-1', email: 'owner@test.com');

    setUp(() {
      daemonDb = FakeFirebaseFirestore();
      daemonLogger = FakeLogger();
      daemonContainer = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(daemonDb),
          loggerProvider.overrideWithValue(daemonLogger),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockUser),
          ),
        ],
      );
      // cloudFunctionMocksProvider is autoDispose: a bare `read` leaves it with
      // no listener, so the container tears it down at once and `onDispose`
      // cancels the daemons before they can ever fire. Hold a subscription for
      // the duration of the test.
      daemonSub = daemonContainer.listen(cloudFunctionMocksProvider, (_, _) {});
    });

    tearDown(() {
      daemonContainer.read(cloudFunctionMocksProvider).stopDaemons();
      daemonSub.close();
      daemonContainer.dispose();
    });

    CloudFunctionMocksService daemons() =>
        daemonContainer.read(cloudFunctionMocksProvider);

    test('startDaemons is idempotent; stopDaemons reports the stop', () async {
      final service = daemons();
      service.startDaemons();
      service.startDaemons(); // the _isRunning guard must absorb this

      expect(
        daemonLogger.loggedInfo
            .where((m) => m.contains('Starting Local Cloud Function Mocks'))
            .length,
        1,
        reason: 'a second start must not re-arm the timers/listeners',
      );

      service.stopDaemons();
      expect(
        daemonLogger.loggedInfo.any(
          (m) => m.contains('Stopped Local Cloud Function Mocks'),
        ),
        isTrue,
      );
    });

    test(
      'a queued push becomes a notification item and drains the queue',
      () async {
        daemons().startDaemons();
        await pumpEventQueue();

        await daemonDb.collection('notification_queue').add({
          'targetUid': 'u1',
          'title': 'Order ready',
          'body': 'Pick it up',
          'route': '/orders',
        });
        await pumpEventQueue();

        final items = await daemonDb
            .collection('notifications')
            .doc('u1')
            .collection('items')
            .get();
        expect(items.docs.length, 1);
        expect(items.docs.single.data()['title'], 'Order ready');
        expect(items.docs.single.data()['body'], 'Pick it up');
        expect(items.docs.single.data()['route'], '/orders');
        expect(
          items.docs.single.data()['isRead'],
          isFalse,
          reason: 'a freshly materialized push starts unread',
        );

        final queue = await daemonDb.collection('notification_queue').get();
        expect(
          queue.docs,
          isEmpty,
          reason: 'the queue doc is drained once processed',
        );
        expect(
          daemonLogger.loggedInfo.any(
            (m) => m.contains('Processed push notification to u1'),
          ),
          isTrue,
        );
      },
    );

    test('a malformed queue doc is drained without a notification', () async {
      daemons().startDaemons();
      await pumpEventQueue();

      await daemonDb.collection('notification_queue').add({
        'body': 'no target',
      });
      await pumpEventQueue();

      final queue = await daemonDb.collection('notification_queue').get();
      expect(queue.docs, isEmpty);
      final users = await daemonDb.collection('notifications').get();
      expect(
        users.docs,
        isEmpty,
        reason: 'a doc without targetUid/title must not fabricate a recipient',
      );
    });

    test(
      'a duplicate inside the debounce window is dropped, not re-sent',
      () async {
        // A notification for the same title was delivered just now.
        await daemonDb
            .collection('notifications')
            .doc('u1')
            .collection('items')
            .add({
              'title': 'Order ready',
              'body': 'first',
              'isRead': false,
              'createdAt': Timestamp.fromDate(DateTime.now()),
            });

        daemons().startDaemons();
        await pumpEventQueue();

        await daemonDb.collection('notification_queue').add({
          'targetUid': 'u1',
          'title': 'Order ready',
          'body': 'duplicate',
        });
        await pumpEventQueue();

        final items = await daemonDb
            .collection('notifications')
            .doc('u1')
            .collection('items')
            .get();
        expect(
          items.docs.length,
          1,
          reason: 'the debounce must prevent a double-send inside 30s',
        );
        expect(items.docs.single.data()['body'], 'first');
        expect(
          daemonLogger.loggedInfo.any(
            (m) => m.contains('Debounced duplicate notification to u1'),
          ),
          isTrue,
        );
        // The queue doc is still drained — otherwise it would replay forever.
        final queue = await daemonDb.collection('notification_queue').get();
        expect(queue.docs, isEmpty);
      },
    );

    test(
      'modifying a menu item writes an IAM audit_log entry with the actor',
      () async {
        daemons().startDaemons();
        await pumpEventQueue();

        await daemonDb.collection('menus').doc('m1').set({
          'name': 'Margherita',
          'priceCents': 1200,
        });
        await pumpEventQueue();
        // The listener reacts to MODIFIED changes only.
        await daemonDb.collection('menus').doc('m1').update({
          'priceCents': 1350,
        });
        await pumpEventQueue();

        final logs = await daemonDb.collection('audit_log').get();
        expect(logs.docs.length, 1);
        final entry = logs.docs.single.data();
        expect(entry['action'], 'MENU_MODIFY');
        expect(entry['collection'], 'menus');
        expect(entry['docId'], 'm1');
        expect(entry['actorUid'], 'owner-1');
        expect(entry['actorEmail'], 'owner@test.com');
        expect(
          entry['note'] as String,
          contains('1350'),
          reason: 'the audit note records the NEW price',
        );
      },
    );
  });
}
