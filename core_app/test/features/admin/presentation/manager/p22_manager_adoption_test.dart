// UI-12 (p22) phase B1 — manager dashboard adoption (B1: `SectionHeader` +
// `StatTile` + `BrandCard` rows, display-only). Written RED before the wiring.
//
// L16/L17 SANCTUARY: `branchOrdersProvider` (the W8.5/W8.7 bounded branch
// stream), its 24 h window and its hard cap are NOT touched — this phase swaps
// row chrome only. The lazy-capped list contract is pinned here from the UI
// side (exactly ONE lazy `ListView`, `2 * itemCount - 1` children) because
// `manager_bounded_history_stream_test.dart` owns the behavioural half and
// reads that delegate directly.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/l10n/status_role_labels.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_token.dart';
import 'package:labs/l10n/app_localizations_en.dart';

import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

final _managerUser = MockUser(uid: 'manager-p22-1', email: 'm22@test.com');

/// Minimal manager harness: real [AdminDataService] over a fake Firestore (the
/// `manager_dashboard_test.dart` convention) so the bounded stream provider
/// itself is exercised, with an optional stream override for the loading pin.
Widget _harness(
  FirebaseFirestore firestore, {
  User? authUser,
  Stream<List<OrderModel>>? ordersOverride,
}) {
  final overrides = <Override>[
    firestoreProvider.overrideWithValue(firestore),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(authUser)),
    adminDataServiceProvider.overrideWithValue(
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      ),
    ),
  ];
  if (authUser != null) {
    overrides.add(
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'manager-p22-1',
          role: UserRole.manager,
          branchId: 'branch-1',
        ),
      ),
    );
  }
  if (ordersOverride != null) {
    overrides.add(
      branchOrdersProvider.overrideWith((ref, key) => ordersOverride),
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
            builder: (_, __) => const ManagerDashboard(),
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

Future<void> _seedManagerUser(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('manager-p22-1').set({
    'email': 'm22@test.com',
    'role': 'manager',
    'branchId': 'branch-1',
    'name': 'Test Manager',
  });
}

Future<void> _seedOrder(
  FirebaseFirestore firestore, {
  required String orderId,
  int totalCents = 1234,
  String status = 'pending',
}) async {
  await firestore.collection('orders').doc(orderId).set({
    'tenantId': 'tenant_a',
    'branchId': 'branch-1',
    'totalCents': totalCents,
    'status': status,
    'createdAt': Timestamp.now(),
    'items': <Object>[],
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The bounded manager list builds rows lazily, so the delegate is the
/// observable truth (`manager_bounded_history_stream_test.dart`).
SliverChildBuilderDelegate _delegate(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).childrenDelegate
        as SliverChildBuilderDelegate;

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

  testWidgets('B1: SectionHeader + StatTile + BrandCard rows replace ListTiles', (
    tester,
  ) async {
    await _seedManagerUser(fakeFirestore);
    await _seedOrder(fakeFirestore, orderId: 'o1', totalCents: 1234);
    await _seedOrder(
      fakeFirestore,
      orderId: 'o2',
      totalCents: 5678,
      status: 'ready',
    );

    await tester.pumpWidget(_harness(fakeFirestore, authUser: _managerUser));
    await _settle(tester);

    // B1 header + metric tile.
    expect(find.byType(SectionHeader), findsOneWidget);
    expect(find.byType(StatTile), findsOneWidget);
    expect(tester.widget<StatTile>(find.byType(StatTile)).value, '2');

    // B1 rows: frozen card chrome, no raw ListTile left.
    expect(find.byType(BrandCard), findsNWidgets(2));
    expect(find.byType(ListTile), findsNothing);

    // Display-only: the token text is untouched (uppercased by safeOrderToken).
    expect(find.text('#O1'), findsOneWidget);
    expect(find.text('#O2'), findsOneWidget);
  });

  testWidgets('B1: the bounded lazy list delegate is unchanged', (
    tester,
  ) async {
    await _seedManagerUser(fakeFirestore);
    await _seedOrder(fakeFirestore, orderId: 'o1');
    await _seedOrder(fakeFirestore, orderId: 'o2');

    await tester.pumpWidget(_harness(fakeFirestore, authUser: _managerUser));
    await _settle(tester);

    // Exactly ONE scrollable list, still lazy (separated => 2 * n - 1).
    expect(find.byType(ListView), findsOneWidget);
    expect(_delegate(tester).childCount, 3);
  });

  testWidgets('B1: rows keep the W9 order semantics label', (tester) async {
    await _seedManagerUser(fakeFirestore);
    await _seedOrder(fakeFirestore, orderId: 'o1', totalCents: 1234);

    await tester.pumpWidget(_harness(fakeFirestore, authUser: _managerUser));
    await _settle(tester);

    final loc = AppLocalizationsEn();
    final expected = loc.orderSemanticsLabel(
      safeOrderToken('o1'),
      orderStatusLabel(loc, OrderStatus.pending),
      formatAmount(1234, 'USD'),
    );
    final handle = tester.ensureSemantics();
    try {
      // The row's composed label is merged with the child texts by the
      // framework, so match it as a substring of the node label.
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expected))),
        findsWidgets,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('B1: the loading branch stays the documented empty list', (
    tester,
  ) async {
    await _seedManagerUser(fakeFirestore);
    final pending = StreamController<List<OrderModel>>();

    await tester.pumpWidget(
      _harness(
        fakeFirestore,
        authUser: _managerUser,
        ordersOverride: pending.stream,
      ),
    );
    await _settle(tester);

    // W8.5 preservation: no spinner while the bounded stream is still pending.
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SkeletonLoader), findsNothing);
    expect(tester.widget<StatTile>(find.byType(StatTile)).value, '0');

    addTearDown(pending.close);
  });
}
