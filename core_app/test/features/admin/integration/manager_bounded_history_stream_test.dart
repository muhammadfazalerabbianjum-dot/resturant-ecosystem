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
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';

import '../../../helpers/app_localizations_test_helper.dart';
import '../../../helpers/test_helpers.dart';
import '../../../support/tenant_claim_fakes.dart';

/// COV-5 (WHITE_LABEL_b07_cov5.md acceptance #2): Manager dashboard
/// INTEGRATION — the capped branch history stream (STATE-2 / W8.7: 24 h
/// window + newest-first + kManagerOrdersHistoryCap) proven through the
/// PRODUCTION widget + branchOrdersProvider + the real AdminDataService over
/// a real FakeFirebaseFirestore: bound enforcement at the widget layer, live
/// updates without a reset, and the W8.5 fail-visible error branch.

final mockManagerUser = MockUser(
  uid: 'manager-test-1',
  email: 'manager@test.com',
);

/// Real [AdminDataService] whose history stream fails the way a Firestore
/// outage fails (unavailable). Only the stream source is injected; the
/// widget/provider path under test is fully real. Same failure-injection
/// idiom as the owner harness's _DeniedAdminService.
class _FailingHistoryAdminService extends AdminDataService {
  _FailingHistoryAdminService({
    required super.firestore,
    required super.logger,
  });

  @override
  Stream<List<OrderModel>> streamOrdersByBranch(
    String branchId, {
    Duration window = kManagerOrdersHistoryWindow,
  }) {
    return Stream<List<OrderModel>>.error(
      FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
        message: 'simulated stream outage',
      ),
    );
  }
}

Widget buildTestWidget({
  required FirebaseFirestore firestore,
  AdminDataService? adminServiceOverride,
}) {
  final adminService =
      adminServiceOverride ??
      AdminDataService(
        firestore: firestore,
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      );

  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith(
        (ref) => Stream<User?>.value(mockManagerUser),
      ),
      adminDataServiceProvider.overrideWithValue(adminService),
      // W2.9: resolve the manager role + branch directly (fallback auth
      // repository returns null user data).
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(
          id: 'manager-test-1',
          role: UserRole.manager,
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

/// Seeds one order doc the way the manager history query consumes it.
Future<void> seedOrder(
  FakeFirebaseFirestore firestore, {
  required String orderId,
  required String branchId,
  required DateTime createdAt,
  int totalCents = 1000,
  String status = 'delivered',
}) async {
  await firestore.collection('orders').doc(orderId).set({
    'tenantId': 'tenant_a',
    'branchId': branchId,
    'status': status,
    'totalCents': totalCents,
    'createdAt': Timestamp.fromDate(createdAt),
    'items': <Object>[],
  });
}

/// The rendered item count of the manager order list. The list builds rows
/// lazily, so the delegate is the observable truth — but ListView.separated
/// materializes `2 * itemCount - 1` children (items + separators), hence the
/// conversion.
int _listChildCount(WidgetTester tester) {
  final delegate =
      tester.widget<ListView>(find.byType(ListView)).childrenDelegate
          as SliverChildBuilderDelegate;
  final childCount = delegate.childCount ?? -1;
  return (childCount + 1) ~/ 2;
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

  group('COV-5 manager dashboard — capped history stream (STATE-2)', () {
    testWidgets(
      '1. the live history list is hard-bounded: cap 200 + 24 h window + branch scoping, newest-first',
      (tester) async {
        final now = DateTime.now();
        // 210 in-window orders for branch-1 (h-o0 = newest).
        for (var i = 0; i < 210; i++) {
          await seedOrder(
            fakeFirestore,
            orderId: 'h-o$i',
            branchId: 'branch-1',
            createdAt: now.subtract(Duration(minutes: i + 1)),
          );
        }
        // 5 stale (25 h old) branch-1 orders — dropped by the 24 h window.
        for (var i = 0; i < 5; i++) {
          await seedOrder(
            fakeFirestore,
            orderId: 's-o$i',
            branchId: 'branch-1',
            createdAt: now.subtract(
              const Duration(hours: 25) + Duration(minutes: i),
            ),
          );
        }
        // 3 fresh orders for ANOTHER branch — must never leak in.
        for (var i = 0; i < 3; i++) {
          await seedOrder(
            fakeFirestore,
            orderId: 'b2-o$i',
            branchId: 'branch-2',
            createdAt: now.subtract(Duration(minutes: i + 1)),
          );
        }

        await tester.pumpWidget(buildTestWidget(firestore: fakeFirestore));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final listFinder = find.byType(ListView);
        expect(listFinder, findsOneWidget);
        // W8.7/STATE-2: the ENTIRE branch history must never stream in —
        // exactly the capped 200 render.
        expect(_listChildCount(tester), kManagerOrdersHistoryCap);
        // Newest-first: the freshest order heads the list.
        expect(find.text('#H-O0'), findsOneWidget);

        // Scroll the capped list to its bottom: the last doc is the 200th
        // newest (ids stay <= 8 chars so safeOrderToken never truncates).
        await tester.drag(find.byType(ListView), const Offset(0, -30000));
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -30000));
        await tester.pump();
        expect(find.text('#H-O199'), findsOneWidget);
        // Beyond the cap / window / branch: absent from the tree entirely.
        expect(find.text('#H-O200'), findsNothing);
        expect(find.text('#S-O0'), findsNothing);
        expect(find.text('#B2-O0'), findsNothing);
      },
    );

    testWidgets(
      '2. a live order added mid-mount appends without resetting the list',
      (tester) async {
        final now = DateTime.now();
        await seedOrder(
          fakeFirestore,
          orderId: 'live-a',
          branchId: 'branch-1',
          createdAt: now.subtract(const Duration(minutes: 1)),
        );
        await seedOrder(
          fakeFirestore,
          orderId: 'live-b',
          branchId: 'branch-1',
          createdAt: now.subtract(const Duration(minutes: 2)),
        );

        await tester.pumpWidget(buildTestWidget(firestore: fakeFirestore));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(_listChildCount(tester), 2);
        expect(find.text('#LIVE-A'), findsOneWidget);
        expect(find.text('#LIVE-B'), findsOneWidget);

        // A NEW order lands in Firestore while the dashboard is mounted.
        await seedOrder(
          fakeFirestore,
          orderId: 'live-c',
          branchId: 'branch-1',
          createdAt: now,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The family provider kept the subscription: 3 rows now, and the
        // PREVIOUS rows are still rendered (no spinner/empty reset).
        expect(_listChildCount(tester), 3);
        expect(find.text('#LIVE-A'), findsOneWidget);
        expect(find.text('#LIVE-B'), findsOneWidget);
        expect(find.text('#LIVE-C'), findsOneWidget);
      },
    );

    testWidgets(
      '3. a failed history stream surfaces the mapped error (W8.5 fail-visible, not a silent empty list)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            firestore: fakeFirestore,
            adminServiceOverride: _FailingHistoryAdminService(
              firestore: fakeFirestore,
              logger: FakeLogger(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text(
            'Service is temporarily unavailable. Please check your connection.',
          ),
          findsOneWidget,
        );
        // No order rows rendered on the error branch.
        expect(find.text('#H-O0'), findsNothing);
      },
    );
  });
}
