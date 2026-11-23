import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// COV-5 (WHITE_LABEL_b07_cov5.md acceptance #3): Kitchen + delivery INTEGRATION —
/// the staff update path proven end-to-end with `updatedAt` allowed by
/// RULES-1's shape locks (rules harness parity).
///
/// RULES-1 locks (firestore.rules, kitchen :397-402 / delivery :403-427):
/// a kitchen/delivery status write is ALLOWED only when its affected keys
/// stay inside `hasOnly(['status', 'updatedAt'])` (delivery additionally
/// admits 'assignedDriverId' / 'proofOfDelivery'). The harness
/// (core_app/test/rules/firestore_rules_test.js) proves the SERVER side;
/// these tests prove the CLIENT side produces exactly the matching writes:
/// the committed transaction diff, the STAFF-QUEUE replay payload + merge-set
/// shape, the queue lifecycle (enqueue-before-write, drained on success), and
/// the dashboards driving the real services live.

/// Fake [DriverLocationService] recording calls (same idiom as
/// delivery_service_test.dart's FakeDriverLocationService).
class _RecordingDriverLocationService extends DriverLocationService {
  _RecordingDriverLocationService()
    : super(FakeFirebaseFirestore(), FakeLogger());

  bool stopped = false;

  @override
  Future<void> startTracking(String orderId) async {}

  @override
  Future<void> stopTracking() async {
    stopped = true;
  }
}

/// Seeds an order doc WITH its own `id` field — the CF `createOrder` shape
/// every staff update depends on (the 'id' merged by the queue replay equals
/// the doc id, so it never enters affectedKeys()).
Future<void> seedOrderDoc(
  FakeFirebaseFirestore firestore, {
  required String orderId,
  required String status,
  DateTime? createdAt,
  String branchId = 'branch-1',
  String? assignedDriverId,
  int totalCents = 1500,
}) async {
  await firestore.collection('orders').doc(orderId).set({
    'tenantId': 'tenant_a',
    'id': orderId,
    'branchId': branchId,
    'status': status,
    'totalCents': totalCents,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'items': <Object>[],
    if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
  });
}

/// Fresh read of an order doc (null-safe map).
Future<Map<String, dynamic>> orderData(
  FakeFirebaseFirestore firestore,
  String orderId,
) async {
  final snap = await firestore.collection('orders').doc(orderId).get();
  return snap.data() ?? <String, dynamic>{};
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('RULES-1 shape locks — service-layer update paths', () {
    late RecordingSyncQueue syncQueue;
    late KitchenService kitchenService;
    late DeliveryService deliveryService;
    late _RecordingDriverLocationService locationService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      syncQueue = RecordingSyncQueue();
      locationService = _RecordingDriverLocationService();
      kitchenService = KitchenService(
        firestore: fakeFirestore,
        logger: FakeLogger(),
        syncQueue: syncQueue,
        tenantClaim: const FixedTenantClaim(),
      );
      deliveryService = DeliveryService(
        firestore: fakeFirestore,
        locationService: locationService,
        logger: FakeLogger(),
        syncQueue: syncQueue,
        tenantClaim: const FixedTenantClaim(),
      );
    });

    test(
      '1. kitchen transition commits EXACTLY {status, updatedAt} and drains the queue',
      () async {
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'k-shape-1',
          status: 'confirmed',
        );
        final before = await orderData(fakeFirestore, 'k-shape-1');

        await kitchenService.updateOrderStatus(
          'k-shape-1',
          OrderStatus.preparing,
        );

        final after = await orderData(fakeFirestore, 'k-shape-1');
        expect(after['status'], 'preparing');
        expect(after['updatedAt'], isA<Timestamp>());
        // RULES-1 kitchen lock: hasOnly(['status', 'updatedAt']) — value-diff
        // keys of the committed write add ONLY updatedAt, remove nothing.
        expect(
          after.keys.toSet()..removeAll(before.keys.toSet()),
          {'updatedAt'},
          reason: 'committed kitchen write must add ONLY updatedAt',
        );
        expect(
          before.keys.toSet()..removeAll(after.keys.toSet()),
          isEmpty,
          reason: 'committed kitchen write must remove NO field',
        );
        // Everything else untouched (id/branchId/totalCents/createdAt).
        expect(after['id'], 'k-shape-1');
        expect(after['totalCents'], 1500);

        // STAFF-QUEUE: the rules-legal replay payload rode BEFORE the write and
        // was removed after the commit.
        expect(syncQueue.enqueuedPayloads.single, {
          'id': 'k-shape-1',
          'status': 'preparing',
        });
        expect(syncQueue.pendingPayloads, isEmpty);
      },
    );

    test(
      '2. queue replay parity: merge-setting the payload + queue-stamped updatedAt stays inside the lock',
      () async {
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'k-replay-1',
          status: 'confirmed',
        );
        final before = await orderData(fakeFirestore, 'k-replay-1');

        // EXACTLY what IsarSyncQueue.processQueue replays: the stored payload
        // merge-set with its own queue-stamped updatedAt.
        final payload = buildKitchenStatusUpdatePayload(
          'k-replay-1',
          OrderStatus.ready.name,
        );
        expect(payload, {'id': 'k-replay-1', 'status': 'ready'});
        await fakeFirestore.collection('orders').doc('k-replay-1').set({
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final after = await orderData(fakeFirestore, 'k-replay-1');
        expect(after['status'], 'ready');
        // The merged 'id' equals the doc id (unchanged value) so the replay
        // never leaves the hasOnly(['status', 'updatedAt']) lock.
        expect(after['id'], 'k-replay-1');
        expect(after.keys.toSet()..removeAll(before.keys.toSet()), {
          'updatedAt',
        });
        expect(before.keys.toSet()..removeAll(after.keys.toSet()), isEmpty);
      },
    );

    test(
      '3. delivery claim commits {assignedDriverId, status, updatedAt}, drains the queue, leaves GPS alone',
      () async {
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'dv-shape-1',
          status: 'ready',
        );
        final before = await orderData(fakeFirestore, 'dv-shape-1');

        await deliveryService.assignToMe('dv-shape-1', 'driver-1');

        final after = await orderData(fakeFirestore, 'dv-shape-1');
        expect(after['status'], 'pickedUp');
        expect(after['assignedDriverId'], 'driver-1');
        expect(after['updatedAt'], isA<Timestamp>());
        expect(
          after.keys.toSet()..removeAll(before.keys.toSet()),
          {'assignedDriverId', 'updatedAt'},
          reason:
              'RULES-1 delivery lock: claim adds ONLY assignedDriverId+updatedAt',
        );
        expect(before.keys.toSet()..removeAll(after.keys.toSet()), isEmpty);

        expect(syncQueue.enqueuedPayloads.single, {
          'id': 'dv-shape-1',
          'assignedDriverId': 'driver-1',
          'status': 'pickedUp',
        });
        expect(syncQueue.pendingPayloads, isEmpty);
        // The claim does NOT touch GPS (only markDelivered stops tracking).
        expect(locationService.stopped, isFalse);
      },
    );

    test(
      '4. claim race: a second driver is REJECTED with no write and no queued op (pre-flight precedes enqueue)',
      () async {
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'dv-race-1',
          status: 'ready',
        );
        await deliveryService.assignToMe('dv-race-1', 'driver-1');
        final afterFirst = await orderData(fakeFirestore, 'dv-race-1');

        final secondQueue = RecordingSyncQueue();
        final secondService = DeliveryService(
          firestore: fakeFirestore,
          locationService: _RecordingDriverLocationService(),
          logger: FakeLogger(),
          syncQueue: secondQueue,
          tenantClaim: const FixedTenantClaim(),
        );

        await expectLater(
          secondService.assignToMe('dv-race-1', 'driver-2'),
          throwsA(
            predicate(
              (e) => e.toString().contains('already assigned'),
              'Order already assigned to someone else',
            ),
          ),
        );

        // Nothing changed — the claim is idempotent per driver.
        final afterRace = await orderData(fakeFirestore, 'dv-race-1');
        expect(afterRace['assignedDriverId'], 'driver-1');
        expect(afterRace['status'], afterFirst['status']);
        // The losing claim never reached the queue (fail-closed pre-flight).
        expect(secondQueue.enqueuedPayloads, isEmpty);
        expect(secondQueue.pendingPayloads, isEmpty);
      },
    );

    test(
      '5. kitchen invalid transition (delivered -> preparing): error thrown, NO write, NO queued op',
      () async {
        final committedAt = Timestamp.fromDate(DateTime(2024, 1, 1));
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'k-dead-1',
          status: 'delivered',
        );
        await fakeFirestore.collection('orders').doc('k-dead-1').update({
          'updatedAt': committedAt,
        });
        final before = await orderData(fakeFirestore, 'k-dead-1');

        await expectLater(
          kitchenService.updateOrderStatus('k-dead-1', OrderStatus.preparing),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('Invalid status transition') &&
                  e.toString().contains('delivered -> preparing'),
            ),
          ),
        );

        // Zero mutation — the W8.3 state machine + RULES-1 stay intact.
        final after = await orderData(fakeFirestore, 'k-dead-1');
        expect(after, before);
        expect(syncQueue.enqueuedPayloads, isEmpty);
        expect(syncQueue.pendingPayloads, isEmpty);
      },
    );

    test(
      '6. markDelivered commits EXACTLY {status, updatedAt} and stops GPS only after the commit',
      () async {
        await seedOrderDoc(
          fakeFirestore,
          orderId: 'dv-deliv-1',
          status: 'pickedUp',
          assignedDriverId: 'driver-1',
        );
        final before = await orderData(fakeFirestore, 'dv-deliv-1');

        await deliveryService.markDelivered('dv-deliv-1');

        final after = await orderData(fakeFirestore, 'dv-deliv-1');
        expect(after['status'], 'delivered');
        expect(after['updatedAt'], isA<Timestamp>());
        expect(
          after.keys.toSet()..removeAll(before.keys.toSet()),
          {'updatedAt'},
          reason: 'RULES-1 delivery lock: delivered write adds ONLY updatedAt',
        );
        expect(before.keys.toSet()..removeAll(after.keys.toSet()), isEmpty);
        expect(syncQueue.enqueuedPayloads.single, {
          'id': 'dv-deliv-1',
          'status': 'delivered',
        });
        expect(syncQueue.pendingPayloads, isEmpty);
        // GPS livestream stops once the delivered write actually committed.
        expect(locationService.stopped, isTrue);
      },
    );
  });

  group('COV-5 kitchen dashboard — FIFO staff workflow end-to-end', () {
    testWidgets(
      'Start Preparing -> Mark Ready through the REAL service + queue + live stream',
      (tester) async {
        // Isolation: a fresh store so the seeded order cannot leak into the
        // delivery test's Available stream below (and vice versa).
        fakeFirestore = FakeFirebaseFirestore();
        final syncQueue = RecordingSyncQueue();
        final now = DateTime.now();
        await fakeFirestore.collection('orders').doc('k-o1').set({
          'tenantId': 'tenant_a',
          'id': 'k-o1',
          'branchId': 'branch-1',
          'status': 'confirmed',
          'totalCents': 2500,
          'createdAt': Timestamp.fromDate(now),
          'userId': 'cust-1',
          'userName': 'C1',
          'items': [
            {
              'item': {'id': 'm1', 'name': 'Burger', 'priceCents': 1250},
              'quantity': 2,
              'selectedOptions': <Object>[],
            },
          ],
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firestoreProvider.overrideWithValue(fakeFirestore),
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(
                  MockUser(uid: 'kitchen-test-1', email: 'kitchen@test.com'),
                ),
              ),
              kitchenServiceProvider.overrideWithValue(
                KitchenService(
                  firestore: fakeFirestore,
                  logger: FakeLogger(),
                  syncQueue: syncQueue,
                  tenantClaim: const FixedTenantClaim(),
                ),
              ),
              currentUserProvider.overrideWith(
                (ref) async => const UserModel(
                  id: 'kitchen-test-1',
                  role: UserRole.kitchen,
                  branchId: 'branch-1',
                ),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              routerConfig: GoRouter(
                initialLocation: '/dashboard',
                routes: [
                  GoRoute(
                    path: '/dashboard',
                    name: 'dashboard',
                    builder: (_, __) => const KitchenDashboard(),
                  ),
                  GoRoute(
                    path: '/',
                    name: 'home',
                    builder: (_, __) =>
                        const Scaffold(body: Center(child: Text('Home Route'))),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        // BOUNDED pumps only: the W8.5 live-refresh chip renders an always-on
        // CircularProgressIndicator in the data state, so pumpAndSettle would
        // never settle.
        await tester.pump(const Duration(seconds: 1));

        // The confirmed order sits on the Preparing tab with its FIFO action.
        // safeOrderToken upper-cases the doc id: 'k-o1' -> '#K-O1'.
        expect(find.text('#K-O1'), findsOneWidget);
        // The CartItemModel payload parses through the dashboard card.
        expect(find.text('• Burger × 2'), findsOneWidget);
        expect(find.text('Start Preparing'), findsOneWidget);

        await tester.tap(find.text('Start Preparing'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // REAL KitchenService committed the transaction write.
        final preparing = await orderData(fakeFirestore, 'k-o1');
        expect(preparing['status'], 'preparing');
        expect(preparing['updatedAt'], isA<Timestamp>());
        expect(preparing['totalCents'], 2500);
        expect(syncQueue.enqueuedPayloads, [
          {'id': 'k-o1', 'status': 'preparing'},
        ]);
        expect(syncQueue.pendingPayloads, isEmpty);

        // The live stream pushed the new state into the SAME card: the action
        // is now Mark Ready (preparing) — no stale 'Start Preparing'.
        expect(find.text('Mark Ready'), findsOneWidget);
        expect(find.text('Start Preparing'), findsNothing);

        // Continue the FIFO: preparing -> ready.
        await tester.tap(find.text('Mark Ready'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        final ready = await orderData(fakeFirestore, 'k-o1');
        expect(ready['status'], 'ready');
        expect(syncQueue.enqueuedPayloads, [
          {'id': 'k-o1', 'status': 'preparing'},
          {'id': 'k-o1', 'status': 'ready'},
        ]);
        expect(syncQueue.pendingPayloads, isEmpty);

        // The order left the Preparing tab (statuses confirmed,preparing).
        expect(find.text('#K-O1'), findsNothing);
        expect(find.text('No active orders'), findsOneWidget);
      },
    );
  });

  group('COV-5 delivery dashboard — claim workflow end-to-end', () {
    testWidgets(
      'Assign To Me on the Available tab claims the order for real and it appears under My Orders',
      (tester) async {
        // Isolation: fresh store (the kitchen test above leaves a 'ready'
        // branch-1 order that would otherwise appear as a second card here).
        fakeFirestore = FakeFirebaseFirestore();
        final syncQueue = RecordingSyncQueue();
        await fakeFirestore.collection('orders').doc('dv-o1').set({
          'tenantId': 'tenant_a',
          'id': 'dv-o1',
          'branchId': 'branch-1',
          'status': 'ready',
          'totalCents': 1800,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'items': <Object>[],
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firestoreProvider.overrideWithValue(fakeFirestore),
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(
                  MockUser(uid: 'driver-1', email: 'driver@test.com'),
                ),
              ),
              deliveryServiceProvider.overrideWithValue(
                DeliveryService(
                  firestore: fakeFirestore,
                  locationService: _RecordingDriverLocationService(),
                  logger: FakeLogger(),
                  syncQueue: syncQueue,
                  tenantClaim: const FixedTenantClaim(),
                ),
              ),
              currentUserProvider.overrideWith(
                (ref) async => const UserModel(
                  id: 'driver-1',
                  role: UserRole.delivery,
                  branchId: 'branch-1',
                ),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
              routerConfig: GoRouter(
                initialLocation: '/dashboard',
                routes: [
                  GoRoute(
                    path: '/dashboard',
                    name: 'dashboard',
                    builder: (_, __) => const DeliveryDashboard(),
                  ),
                  GoRoute(
                    path: '/',
                    name: 'home',
                    builder: (_, __) =>
                        const Scaffold(body: Center(child: Text('Home Route'))),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Initial tab = My Orders, empty for this driver.
        expect(find.text('No active deliveries'), findsOneWidget);

        await tester.tap(find.text('Available'));
        await tester.pumpAndSettle();
        // safeOrderToken upper-cases the doc id: 'dv-o1' -> '#DV-O1';
        // the trailing button is loc.assignToMe.
        expect(find.text('#DV-O1'), findsOneWidget);
        expect(find.text('Assign to me'), findsOneWidget);

        await tester.tap(find.text('Assign to me'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // REAL DeliveryService claim committed the rules-legal write.
        final claimed = await orderData(fakeFirestore, 'dv-o1');
        expect(claimed['assignedDriverId'], 'driver-1');
        expect(claimed['status'], 'pickedUp');
        expect(claimed['updatedAt'], isA<Timestamp>());
        expect(syncQueue.enqueuedPayloads.single, {
          'id': 'dv-o1',
          'assignedDriverId': 'driver-1',
          'status': 'pickedUp',
        });
        expect(syncQueue.pendingPayloads, isEmpty);

        // Staff feedback fires (orderAssignedPickup).
        expect(
          find.text('Order assigned! Head to the branch for pickup.'),
          findsOneWidget,
        );

        // Cross-tab: the claimed order now streams into My Orders. Drain the
        // snackbar's 4 s auto-hide timer first so the tab switch is clean.
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('My Orders'));
        await tester.pumpAndSettle();
        expect(find.text('#DV-O1'), findsOneWidget);
      },
    );
  });
}
