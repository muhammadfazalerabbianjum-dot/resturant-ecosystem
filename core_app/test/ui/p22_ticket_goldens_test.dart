// UI-12 (p22) phase A — L18 golden pairs: the platform source badge on
// kitchen/delivery tickets, both cases.
//
// BYTE-IDENTITY PROOF (L18): the `*_no_source` masters are captured AFTER the
// A1 restyle but BEFORE the badge wiring, hash-recorded in
// `tool_uilib/p22/receipts/p22_l18_nosource_hash_before.txt`, then re-verified
// (same blob hash + green run) after the badge lands — see
// `p22_l18_nosource_hash_after.txt`. Absent `orderSource` renders byte-identically.
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
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';

import '../helpers/app_localizations_test_helper.dart';
import '../helpers/test_helpers.dart';
import '../support/tenant_claim_fakes.dart';

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

Widget _kitchenApp(FirebaseFirestore firestore, User user) => ProviderScope(
  overrides: [
    tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(user)),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(
        id: 'kitchen-p22-g',
        role: UserRole.kitchen,
        branchId: 'branch-1',
      ),
    ),
    kitchenServiceProvider.overrideWithValue(
      KitchenService(
        firestore: firestore,
        logger: FakeLogger(),
        syncQueue: RecordingSyncQueue(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
  ],
  child: const MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizationsTestHelper.delegates,
    supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    home: KitchenDashboard(),
  ),
);

Widget _deliveryApp(FirebaseFirestore firestore, User user) => ProviderScope(
  overrides: [
    tenantIdProvider.overrideWith((ref) async => 'tenant_a'),
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(user)),
    currentUserProvider.overrideWith(
      (ref) async => const UserModel(
        id: 'delivery-p22-g',
        role: UserRole.delivery,
        branchId: 'branch-1',
      ),
    ),
    deliveryServiceProvider.overrideWithValue(
      DeliveryService(
        firestore: firestore,
        locationService: _FakeDriverLocation(firestore),
        logger: FakeLogger(),
        syncQueue: RecordingSyncQueue(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
  ],
  child: const MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizationsTestHelper.delegates,
    supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    home: DeliveryDashboard(),
  ),
);

Map<String, dynamic> _kitchenTicket({Object? orderSource}) => {
  'tenantId': 'tenant_a',
  'branchId': 'branch-1',
  'totalCents': 2500,
  'status': 'confirmed',
  'createdAt': Timestamp.now(),
  // WIRE shape, NOT the flat `{'name','quantity','priceCents'}` map — see
  // delivery_dashboard_perf7_test.dart `readyOrderDoc` for the reason.
  'items': [
    {
      'item': {'id': 'm1', 'name': 'Burger', 'priceCents': 1250},
      'quantity': 2,
    },
  ],
  'userId': 'cust-1',
  if (orderSource != null) 'orderSource': orderSource,
};

Map<String, dynamic> _deliveryTicket({Object? orderSource}) => {
  'id': 'order-g',
  'tenantId': 'tenant_a',
  'customerId': 'cust-1',
  'status': 'pickedUp',
  'totalCents': 1234,
  'branchId': 'branch-1',
  'assignedDriverId': 'delivery-p22-g',
  'createdAt': Timestamp.now(),
  'items': [
    {
      'item': {'id': 'i1', 'name': 'Burger', 'priceCents': 1234},
      'quantity': 1,
    },
  ],
  if (orderSource != null) 'orderSource': orderSource,
};

Future<FakeFirebaseFirestore> _seeded(String uid) async {
  final fs = FakeFirebaseFirestore();
  await fs.collection('users').doc(uid).set({
    'email': '$uid@test.com',
    'role': uid.startsWith('kitchen') ? 'kitchen' : 'delivery',
    'branchId': 'branch-1',
    'name': 'Golden User',
  });
  return fs;
}

Future<void> _viewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settleAndPump(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('p22 kitchen ticket — platform source present', (tester) async {
    await _viewport(tester);
    final fs = await _seeded('kitchen-p22-g');
    await fs
        .collection('orders')
        .doc('o-g')
        .set(_kitchenTicket(orderSource: 'platform:uber_eats'));
    await tester.pumpWidget(
      _kitchenApp(fs, MockUser(uid: 'kitchen-p22-g', email: 'k@g.com')),
    );
    await _settleAndPump(tester);
    await expectLater(
      find.byType(KitchenDashboard),
      matchesGoldenFile('goldens/p22_kitchen_ticket_platform.png'),
    );
  });

  testWidgets('p22 kitchen ticket — orderSource absent (L18 byte-identical)', (
    tester,
  ) async {
    await _viewport(tester);
    final fs = await _seeded('kitchen-p22-g');
    await fs.collection('orders').doc('o-g').set(_kitchenTicket());
    await tester.pumpWidget(
      _kitchenApp(fs, MockUser(uid: 'kitchen-p22-g', email: 'k@g.com')),
    );
    await _settleAndPump(tester);
    await expectLater(
      find.byType(KitchenDashboard),
      matchesGoldenFile('goldens/p22_kitchen_ticket_no_source.png'),
    );
  });

  testWidgets('p22 delivery ticket — platform source present', (tester) async {
    await _viewport(tester);
    final fs = await _seeded('delivery-p22-g');
    await fs
        .collection('orders')
        .doc('o-g')
        .set(_deliveryTicket(orderSource: 'platform:uber_eats'));
    await tester.pumpWidget(
      _deliveryApp(fs, MockUser(uid: 'delivery-p22-g', email: 'g@g.com')),
    );
    await _settleAndPump(tester);
    await expectLater(
      find.byType(DeliveryDashboard),
      matchesGoldenFile('goldens/p22_delivery_ticket_platform.png'),
    );
  });

  testWidgets('p22 delivery ticket — orderSource absent (L18 byte-identical)', (
    tester,
  ) async {
    await _viewport(tester);
    final fs = await _seeded('delivery-p22-g');
    await fs.collection('orders').doc('o-g').set(_deliveryTicket());
    await tester.pumpWidget(
      _deliveryApp(fs, MockUser(uid: 'delivery-p22-g', email: 'g@g.com')),
    );
    await _settleAndPump(tester);
    await expectLater(
      find.byType(DeliveryDashboard),
      matchesGoldenFile('goldens/p22_delivery_ticket_no_source.png'),
    );
  });
}
