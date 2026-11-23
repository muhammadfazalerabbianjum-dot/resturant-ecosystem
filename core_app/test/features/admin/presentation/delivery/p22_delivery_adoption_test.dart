// UI-12 (p22) phase A — delivery adoption (A1 ticket cards, A2 action
// affordances incl. assign/POD re-skin, A3 empty/loading, L18 source badge,
// L19 operator density ceiling). Written RED before the wiring.
//
// L17 SANCTUARY: `_markDelivered` / `_assignToMe` service calls are untouched;
// the queue payload shape is pinned in p22_order_source_seam_test.dart and the
// phase's git-diff proof covers delivery_service.dart / proof_of_delivery_service.dart.
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
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
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

class _FakeDriverLocation extends DriverLocationService {
  _FakeDriverLocation(FirebaseFirestore firestore)
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

final _deliveryUser = MockUser(uid: 'delivery-p22-1', email: 'd22@test.com');

Widget _harness(
  FirebaseFirestore firestore, {
  User? authUser,
  Stream<List<OrderModel>>? myOrdersOverride,
}) {
  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    deliveryServiceProvider.overrideWithValue(
      DeliveryService(
        firestore: firestore,
        locationService: _FakeDriverLocation(firestore),
        logger: FakeLogger(),
        syncQueue: RecordingSyncQueue(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
  ];
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'delivery-p22-1',
          role: UserRole.delivery,
          branchId: 'branch-1',
        ),
      ),
    );
  }
  if (myOrdersOverride != null) {
    overrides.add(
      myOrdersProvider.overrideWith((ref, key) => myOrdersOverride),
    );
  }
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
  );
}

Future<void> _seedUser(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('delivery-p22-1').set({
    'email': 'd22@test.com',
    'role': 'delivery',
    'branchId': 'branch-1',
    'name': 'Test Driver',
  });
}

Map<String, dynamic> _orderDoc({
  required String status,
  String? driver,
  Object? orderSource,
}) => {
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
  if (orderSource != null) 'orderSource': orderSource,
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _expect48(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  try {
    final buttons = tester.widgetList<BrandButton>(find.byType(BrandButton));
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      final size = tester.getSize(find.byWidget(button));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }
  } finally {
    handle.dispose();
  }
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  testWidgets('my-orders platform ticket: badge + BrandCard + 48dp actions', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore
        .collection('orders')
        .doc('order-1')
        .set(
          _orderDoc(
            status: 'pickedUp',
            driver: 'delivery-p22-1',
            orderSource: 'platform:uber_eats',
          ),
        );
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _deliveryUser));
    await _settle(tester);

    // L18 source badge, labelled from OrderSource.platformOf(...).
    expect(find.text('uber_eats'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('uber_eats'),
        matching: find.byType(BrandBadge),
      ),
      findsOneWidget,
    );
    // A1: BrandCard composition, raw primitives gone.
    expect(find.byType(BrandCard), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Chip), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    // A2 actions preserved verbatim (L14).
    expect(find.text('Mark Delivered'), findsOneWidget);
    expect(find.text('Go Live (GPS)'), findsOneWidget);
    await _expect48(tester);
  });

  testWidgets('available tab platform ticket: badge + 48dp assign action', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore
        .collection('orders')
        .doc('order-1')
        .set(_orderDoc(status: 'ready', orderSource: 'platform:uber_eats'));
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _deliveryUser));
    await _settle(tester);

    await tester.tap(find.text('Available'));
    await _settle(tester);

    expect(find.text('uber_eats'), findsOneWidget);
    expect(find.byType(BrandCard), findsWidgets);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Assign to me'), findsOneWidget);
    await _expect48(tester);
  });

  testWidgets('L18 absent orderSource renders NO source badge', (tester) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore
        .collection('orders')
        .doc('order-1')
        .set(_orderDoc(status: 'pickedUp', driver: 'delivery-p22-1'));
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _deliveryUser));
    await _settle(tester);

    expect(find.text('uber_eats'), findsNothing);
    // Only the status badge ('En route') renders.
    expect(find.byType(BrandBadge), findsOneWidget);
    expect(find.byType(BrandCard), findsOneWidget);
  });

  testWidgets('A3 my-orders loading shows skeletons, not a spinner', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    final controller = StreamController<List<OrderModel>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _harness(
        fakeFirestore,
        authUser: _deliveryUser,
        myOrdersOverride: controller.stream,
      ),
    );
    await _settle(tester);

    expect(find.byType(SkeletonLoader), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('A3 empty my-orders renders the EmptyStateWidget', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _deliveryUser));
    await _settle(tester);

    expect(find.byType(EmptyStateWidget), findsOneWidget);
    expect(find.text('No active deliveries'), findsOneWidget);
  });
}
