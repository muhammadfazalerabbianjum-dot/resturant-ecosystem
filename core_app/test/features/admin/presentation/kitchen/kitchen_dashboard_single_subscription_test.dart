import 'dart:async';

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
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// W8.5 (T-1/T-4) counting wrapper: delegates to a real [KitchenService]
/// (so real Firestore data flows through) while recording every [streamOrders]
/// call PER FAMILY KEY. The test asserts the provider subscribes EXACTLY ONCE
/// per key across pumps and rebuilds.
class _CountingKitchenService implements KitchenService {
  final KitchenService _inner;
  final Map<String, int> streamOrdersCalls = {};

  _CountingKitchenService(this._inner);

  @override
  Stream<List<OrderModel>> streamOrders(
    String branchId,
    List<String> statuses,
  ) {
    final key = '$branchId|${statuses.join(',')}';
    streamOrdersCalls[key] = (streamOrdersCalls[key] ?? 0) + 1;
    return _inner.streamOrders(branchId, statuses);
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) {
    return _inner.updateOrderStatus(orderId, newStatus);
  }
}

class _RebuildDriver extends StatefulWidget {
  const _RebuildDriver({super.key, required this.child});
  final Widget child;
  @override
  State<_RebuildDriver> createState() => _RebuildDriverState();
}

class _RebuildDriverState extends State<_RebuildDriver> {
  void rebuild() => setState(() {});
  @override
  Widget build(BuildContext context) => widget.child;
}

final _mockKitchenUser = MockUser(
  uid: 'kitchen-test-1',
  email: 'kitchen@test.com',
);

Widget _buildTestWidget({
  required _CountingKitchenService kitchenService,
  GlobalKey<_RebuildDriverState>? driverKey,
}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateProvider.overrideWith(
        (ref) => Stream<User?>.value(_mockKitchenUser),
      ),
      kitchenServiceProvider.overrideWithValue(kitchenService),
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
            builder: (_, __) =>
                _RebuildDriver(key: driverKey, child: const KitchenDashboard()),
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('KitchenDashboard — W8.5 family stream providers (T-1 / T-4)', () {
    testWidgets(
      'T-1: ONE subscription per family key across pumps and rebuilds',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        final kitchenService = _CountingKitchenService(
          KitchenService(
            firestore: fakeFirestore,
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
            tenantClaim: const FixedTenantClaim(),
          ),
        );
        final driverKey = GlobalKey<_RebuildDriverState>();

        await tester.pumpWidget(
          _buildTestWidget(
            kitchenService: kitchenService,
            driverKey: driverKey,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initial build: only the Preparing tab is mounted → exactly ONE
        // subscription for its key, NONE for the Ready tab yet.
        expect(kitchenService.streamOrdersCalls, {
          'branch-1|confirmed,preparing': 1,
        });

        // Force parent rebuilds while staying on the tab: the provider (not
        // build) owns the subscription → no new calls. The pre-conversion
        // build-built stream re-subscribed on every one of these rebuilds.
        for (var i = 0; i < 5; i++) {
          driverKey.currentState!.rebuild();
          await tester.pump();
        }
        expect(
          kitchenService.streamOrdersCalls,
          {'branch-1|confirmed,preparing': 1},
          reason: 'W8.5: rebuilds must NOT re-subscribe the stream',
        );

        // Switch to the Ready tab -> its key subscribes exactly once.
        await tester.tap(find.byIcon(Icons.check_circle_outline));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          kitchenService.streamOrdersCalls['branch-1|ready'],
          1,
          reason: 'the second family key subscribes exactly once',
        );
        expect(
          kitchenService.streamOrdersCalls['branch-1|confirmed,preparing'],
          1,
          reason: 'the first key must not have re-subscribed',
        );
      },
    );
    testWidgets(
      'T-4: data persists across rebuilds — no waiting reset / spinner flash',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch-1',
          'totalCents': 2500,
          'status': 'confirmed',
          'createdAt': Timestamp.now(),
          // Shape proven parseable by kitchen_service_test (CartItemModel
          // requires a nested 'item' map; an empty list parses cleanly).
          'items': [],
          'userId': 'cust-1',
          'userName': 'C1',
          'userPhone': '+1234567890',
        });
        final kitchenService = _CountingKitchenService(
          KitchenService(
            firestore: fakeFirestore,
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
            tenantClaim: const FixedTenantClaim(),
          ),
        );
        final driverKey = GlobalKey<_RebuildDriverState>();

        await tester.pumpWidget(
          _buildTestWidget(
            kitchenService: kitchenService,
            driverKey: driverKey,
          ),
        );
        await tester.pump();
        // Repo-proven pattern (kitchen_dashboard_test.dart): multiple short
        // pumps let the fake-Firestore snapshot resolve into the data state.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Data is rendered (the list is on screen, not the loading spinner).
        expect(find.byType(ListView), findsOneWidget);

        // Rebuild → the SAME AsyncValue is watched: no waiting reset, the
        // list stays on screen. Pre-conversion, every rebuild re-created the
        // stream and the snapshot reset to `waiting` (spinner flash).
        for (var i = 0; i < 3; i++) {
          driverKey.currentState!.rebuild();
          await tester.pump();
        }
        expect(find.byType(ListView), findsOneWidget);
        expect(
          kitchenService.streamOrdersCalls['branch-1|confirmed,preparing'],
          1,
          reason: 'no re-subscription across rebuilds',
        );
      },
    );
  });
}
