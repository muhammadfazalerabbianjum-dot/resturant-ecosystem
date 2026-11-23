// UI-12 (p22) phase A — kitchen adoption (A1 ticket cards, A2 status actions,
// A3 empty/loading, L18 source badge, L19 operator density ceiling).
// Written RED before the wiring (p22 Section 3 phase A).
//
// L17 SANCTUARY: this file asserts PRESENTATION only. The status write goes
// through `kitchenService.updateOrderStatus` — pinned by the queue payload
// shape (two keys) in p22_order_source_seam_test.dart plus the phase's
// git-diff proof. L16: the family stream provider is read, never re-created.
import 'dart:async';
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
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

final _kitchenUser = MockUser(uid: 'kitchen-p22-1', email: 'k22@test.com');

Widget _harness(
  FirebaseFirestore firestore, {
  User? authUser,
  Stream<List<OrderModel>>? ordersOverride,
}) {
  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    kitchenServiceProvider.overrideWithValue(
      KitchenService(
        firestore: firestore,
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
          id: 'kitchen-p22-1',
          role: UserRole.kitchen,
          branchId: 'branch-1',
        ),
      ),
    );
  }
  if (ordersOverride != null) {
    overrides.add(
      kitchenOrdersProvider.overrideWith((ref, key) => ordersOverride),
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
  );
}

Future<void> _seedUser(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('kitchen-p22-1').set({
    'email': 'k22@test.com',
    'role': 'kitchen',
    'branchId': 'branch-1',
    'name': 'Test Chef',
  });
}

Map<String, dynamic> _ticketDoc({Object? orderSource}) => {
  'tenantId': 'tenant_a',
  'branchId': 'branch-1',
  'totalCents': 2500,
  'status': 'confirmed',
  'createdAt': Timestamp.now(),
  // WIRE shape, NOT the flat `{'name','quantity','priceCents'}` map: the flat
  // map does not parse, so the orders stream errors out and every ticket
  // assertion silently finds nothing.
  'items': [
    {
      'item': {'id': 'm1', 'name': 'Burger', 'priceCents': 1250},
      'quantity': 2,
    },
  ],
  'userId': 'cust-1',
  if (orderSource != null) 'orderSource': orderSource,
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
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

  testWidgets('L18 platform ticket carries the source badge (A1 + A2)', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore
        .collection('orders')
        .doc('o-platform')
        .set(_ticketDoc(orderSource: 'platform:uber_eats'));
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _kitchenUser));
    await _settle(tester);

    // L18: labelled from OrderSource.platformOf(...).
    expect(find.text('uber_eats'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('uber_eats'),
        matching: find.byType(BrandBadge),
      ),
      findsOneWidget,
    );
    // A1: the ticket is a BrandCard, no raw Card/ListTile/Chip primitives.
    expect(find.byType(BrandCard), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Chip), findsNothing);
    // A2: the status action is a library button, not a raw FilledButton.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Start Preparing'), findsOneWidget);
  });

  testWidgets('L18 absent orderSource renders NO source badge', (tester) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore.collection('orders').doc('o-app').set(_ticketDoc());
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _kitchenUser));
    await _settle(tester);

    expect(find.text('uber_eats'), findsNothing);
    // The status badge still renders (it is not the source badge).
    expect(find.byType(BrandBadge), findsOneWidget);
    expect(find.byType(BrandCard), findsOneWidget);
  });

  testWidgets('L19 every ticket action clears 48x48 dp', (tester) async {
    await _seedUser(fakeFirestore);
    await fakeFirestore
        .collection('orders')
        .doc('o1')
        .set(_ticketDoc(orderSource: 'platform:uber_eats'));
    await fakeFirestore.collection('orders').doc('o2').set(_ticketDoc());
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _kitchenUser));
    await _settle(tester);

    final handle = tester.ensureSemantics();
    try {
      final buttons = tester.widgetList<BrandButton>(find.byType(BrandButton));
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        final size = tester.getSize(find.byWidget(button));
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'L19: no ticket action below 48 dp high',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(48.0),
          reason: 'L19: no ticket action below 48 dp wide',
        );
      }
      // A2/L14: the semantics label survives the restyle (W9).
      expect(find.bySemanticsLabel('Start Preparing'), findsWidgets);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('A3 ticket list loading shows skeletons, not a spinner', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    final controller = StreamController<List<OrderModel>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _harness(
        fakeFirestore,
        authUser: _kitchenUser,
        ordersOverride: controller.stream,
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

  testWidgets('A3 empty ticket list renders the EmptyStateWidget', (
    tester,
  ) async {
    await _seedUser(fakeFirestore);
    await tester.pumpWidget(_harness(fakeFirestore, authUser: _kitchenUser));
    await _settle(tester);

    expect(find.byType(EmptyStateWidget), findsOneWidget);
    // Wording unchanged (L14) — the shape suite pins this string too.
    expect(find.text('No active orders'), findsOneWidget);
  });
}
