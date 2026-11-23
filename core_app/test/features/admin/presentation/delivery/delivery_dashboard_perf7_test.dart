// PERF-7 — delivery dashboard: no-branch guard, Available-tab assignment,
// My Orders tab. Harness mirrors delivery_dashboard_test.dart (new file so
// the suites stay independently runnable).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import 'package:go_router/go_router.dart';
import '../../../../support/tenant_claim_fakes.dart';

class FakeDriverLocation extends DriverLocationService {
  FakeDriverLocation(FirebaseFirestore firestore)
    : super(
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<void> startTracking(String orderId) async {}

  @override
  Future<void> stopTracking() async {}
}

final mockDeliveryUser = MockUser(
  uid: 'delivery-test-1',
  email: 'delivery@test.com',
);

Widget buildTestWidget(
  FirebaseFirestore firestore, {
  User? authUser,
  // Explicit null = the "no branch assigned" state the guard must catch;
  // omitting the argument keeps the happy-path branch. (The old
  // `branchId ?? 'branch-1'` fallback made the no-branch case unreachable.)
  String? branchId = 'branch-1',
}) {
  final user = authUser ?? mockDeliveryUser;
  final authStream = Stream<User?>.value(user);
  final deliveryService = DeliveryService(
    firestore: firestore,
    locationService: FakeDriverLocation(firestore),
    logger: FakeLogger(),
    syncQueue: RecordingSyncQueue(),
    tenantClaim: const FixedTenantClaim(),
  );
  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => authStream),
    deliveryServiceProvider.overrideWithValue(deliveryService),
    currentUserProvider.overrideWith(
      (ref) async => UserModel(
        id: 'delivery-test-1',
        role: UserRole.delivery,
        branchId: branchId,
      ),
    ),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DeliveryDashboard(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
        ],
      ),
    ),
  );
}

// Canonical order doc shape — the WIRE format the parser actually reads.
//
// WHY hand-written and nested: `CartItemModel.fromJson` requires
// `json['item']` as a nested object (`MenuItemModel.fromJson`), so the flat
// `{'name','quantity','priceCents'}` maps used elsewhere in the suite cannot
// parse — `OrderModel.fromDoc` threw, the orders stream errored, and the
// order-card assertions silently found nothing.
//
// `OrderModel.toJson()` is deliberately NOT used here: it emits
// `'items': instance.items` (raw `CartItemModel` objects, see
// order_model.g.dart:50), which is not a Firestore-safe value.
//
// `createdAt` is MANDATORY and must be a Timestamp: the service queries
// `.orderBy('createdAt')` and Firestore omits docs missing an orderBy field.
Map<String, dynamic> readyOrderDoc({String? driver, String status = 'ready'}) =>
    {
      'id': 'order-1',
      'tenantId': 'tenant_a',
      'customerId': 'cust-1',
      'status': status,
      'totalCents': 1234,
      'branchId': 'branch-1',
      'assignedDriverId': driver,
      'createdAt': Timestamp.now(),
      'items': [
        {
          'item': {'id': 'i1', 'name': 'Burger', 'priceCents': 1234},
          'quantity': 1,
        },
      ],
    };

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('a delivery user with no branch sees the manager escalation', (
    tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    await tester.pumpWidget(buildTestWidget(fs, branchId: null));
    await tester.pumpAndSettle();

    expect(find.textContaining('No branch assigned'), findsOneWidget);
    expect(
      find.byType(TabBar),
      findsNothing,
      reason: 'without a branch the dashboard never reaches the tabs',
    );
  });

  testWidgets('available orders render and Assign-to-me assigns', (
    tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    await tester.pumpWidget(buildTestWidget(fs));
    await tester.pumpAndSettle();

    // Available is tab index 1.
    await tester.tap(find.text('Available'));
    await tester.pumpAndSettle();
    expect(find.text('No orders available'), findsOneWidget);

    // Seed while the live stream is open — the card must appear.
    await fs.collection('orders').doc('order-1').set(readyOrderDoc());
    await tester.pumpAndSettle();
    expect(find.text('Assign to me'), findsOneWidget);

    await tester.tap(find.text('Assign to me'));
    await tester.pumpAndSettle();
    final doc = await fs.collection('orders').doc('order-1').get();
    expect(
      doc.data()!['assignedDriverId'],
      'delivery-test-1',
      reason: 'assignment must write through to the order doc',
    );
  });

  testWidgets('my orders: a ready order offers NO dead-end deliver action', (
    tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    await fs
        .collection('orders')
        .doc('mine-1')
        .set(readyOrderDoc(driver: 'delivery-test-1'));
    await tester.pumpWidget(buildTestWidget(fs));
    await tester.pumpAndSettle();

    // My Orders is tab index 0 — the initial tab.
    // NOTE: exact ARB casing — `readyForPickup` is "Ready for pickup"
    // (lowercase p); title-casing it silently finds nothing.
    expect(find.text('Ready for pickup'), findsOneWidget);
    expect(
      find.text('Mark Delivered'),
      findsNothing,
      reason:
          'a ready order cannot transition to delivered '
          '(ready -> pickedUp|cancelled), so rendering the button would offer '
          'an action that always fails',
    );
  });

  testWidgets(
    'my orders: Mark Delivered demands proof-of-delivery before anything '
    'is written (cancelling leaves the order untouched)',
    (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs
          .collection('orders')
          .doc('mine-1')
          .set(readyOrderDoc(driver: 'delivery-test-1', status: 'pickedUp'));
      await tester.pumpWidget(buildTestWidget(fs));
      await tester.pumpAndSettle();

      // Exact ARB casing: `enRoute` is "En route".
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Mark Delivered'), findsOneWidget);

      await tester.tap(find.text('Mark Delivered'));
      await tester.pumpAndSettle();

      // CONTRACT (delivery_dashboard.dart `_markDelivered`): the button never
      // writes directly — it opens a barrierDismissible:false dialog whose
      // only write path is ProofOfDeliveryButton -> captureAndUpload. The
      // title AND the inner button both use `captureProofOfDelivery`, hence
      // findsWidgets rather than findsOneWidget.
      expect(
        find.text('Capture Proof of Delivery'),
        findsWidgets,
        reason: 'delivery is gated on photographic proof',
      );
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'the gate is a modal dialog, not an inline action',
      );

      // FAIL-CLOSED: dismissing the gate must write NOTHING. A driver cannot
      // reach `delivered` without proof, so the status stays `pickedUp`.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final doc = await fs.collection('orders').doc('mine-1').get();
      expect(
        doc.data()!['status'],
        'pickedUp',
        reason: 'no proof captured => no delivered transition, ever',
      );
      expect(
        doc.data()!.containsKey('proofOfDelivery'),
        isFalse,
        reason: 'a cancelled gate must not leave a phantom proof field',
      );
    },
  );
}
