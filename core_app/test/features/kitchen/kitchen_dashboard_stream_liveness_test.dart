import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/orders/domain/order_model.dart';

import '../../helpers/app_localizations_test_helper.dart';
import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

/// COV-1 — STATE-2 family pattern for the KITCHEN dashboard (the batch-spec
/// gap "dashboard stream subscription").
///
/// Companion to the admin-territory single-subscription suite: that one proves
/// rebuilds/tab switches never re-subscribe; THIS one proves the LIVENESS
/// half of the same family contract — the ONE subscription per
/// (branchId, statuses) key stays attached and pushes NEW documents into the
/// UI while the dashboard is mounted, with no rebuild and no tab switch. A
/// one-shot `get()` would render the first snapshot and then go stale; only a
/// live provider-owned stream passes.

/// W8.5 counting wrapper: delegates to a REAL [KitchenService] (real
/// Firestore data flows through) while recording every [streamOrders] call
/// PER FAMILY KEY.
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

final _mockKitchenUser = MockUser(
  uid: 'kitchen-test-1',
  email: 'kitchen@test.com',
);

Map<String, dynamic> _confirmedOrderDoc(String id) => {
  'tenantId': 'tenant_a',
  'branchId': 'branch-1',
  'totalCents': 2500,
  'status': 'confirmed',
  'createdAt': Timestamp.now(),
  // Shape proven parseable by kitchen_service_test.dart (CartItemModel
  // requires a nested 'item' map; an empty list parses cleanly).
  'items': [],
  'userId': 'cust-$id',
  'userName': 'C',
  'userPhone': '+1234567890',
};

Widget _buildTestWidget({required _CountingKitchenService kitchenService}) {
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
            builder: (_, __) => const KitchenDashboard(),
          ),
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'COV-1 STATE-2: the live kitchen stream delivers new orders without a rebuild',
    (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore
          .collection('orders')
          .doc('o1')
          .set(_confirmedOrderDoc('o1'));
      final kitchenService = _CountingKitchenService(
        KitchenService(
          firestore: fakeFirestore,
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          tenantClaim: const FixedTenantClaim(),
        ),
      );

      await tester.pumpWidget(_buildTestWidget(kitchenService: kitchenService));
      // Repo-proven pattern: multiple short pumps let the fake-Firestore
      // snapshot resolve into the data state.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // First snapshot rendered on the Preparing tab.
      expect(find.text('#O1'), findsOneWidget);
      expect(find.text('#O2'), findsNothing);
      expect(
        kitchenService.streamOrdersCalls['branch-1|confirmed,preparing'],
        1,
        reason: 'exactly ONE subscription for the family key so far',
      );

      // A new order lands in Firestore WHILE the dashboard is mounted: the
      // SAME live subscription must deliver it — no tab switch, no rebuild.
      await fakeFirestore
          .collection('orders')
          .doc('o2')
          .set(_confirmedOrderDoc('o2'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text('#O2'),
        findsOneWidget,
        reason:
            'STATE-2 liveness: the provider-owned stream pushed the new '
            'document into the list',
      );
      expect(find.text('#O1'), findsOneWidget);
      expect(
        kitchenService.streamOrdersCalls['branch-1|confirmed,preparing'],
        1,
        reason:
            'one subscription served BOTH snapshots — live push, not '
            're-subscription',
      );
    },
  );

  testWidgets(
    'COV-1 STATE-2: an order edited out of the tab statuses leaves the list live',
    (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore
          .collection('orders')
          .doc('o1')
          .set(_confirmedOrderDoc('o1'));
      final kitchenService = _CountingKitchenService(
        KitchenService(
          firestore: fakeFirestore,
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          tenantClaim: const FixedTenantClaim(),
        ),
      );

      await tester.pumpWidget(_buildTestWidget(kitchenService: kitchenService));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('#O1'), findsOneWidget);

      // The order moves on to `ready` — it leaves the Preparing tab query.
      await fakeFirestore
          .collection('orders')
          .doc('o1')
          .set(_confirmedOrderDoc('o1')..['status'] = 'ready');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text('#O1'),
        findsNothing,
        reason:
            'the live stream reflects the departure — a stale one-shot '
            'snapshot would keep rendering it',
      );
    },
  );
}
