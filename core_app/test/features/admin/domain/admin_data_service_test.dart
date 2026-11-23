import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:core/core.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import '../../../support/tenant_claim_fakes.dart';
import 'package:labs/features/menu/data/menu_repository.dart'
    show kMenuMaxItemsSafetyCap;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('AdminDataService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AdminDataService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AdminDataService(
        firestore: fakeFirestore,
        logger: LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
        tenantClaim: _FixedTenantClaim(),
      );
    });

    group('getOverviewStats', () {
      test('returns zero stats when no orders exist', () async {
        final stats = await service.getOverviewStats();
        expect(stats.todayOrders, 0);
        expect(stats.todayRevenue, 0);
        expect(stats.activeOrders, 0);
      });

      test('calculates correct stats from orders', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'totalCents': 2500,
          'status': 'delivered',
          'createdAt': Timestamp.now(),
        });
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'totalCents': 1500,
          'status': 'preparing',
          'createdAt': Timestamp.now(),
        });
        await fakeFirestore.collection('orders').doc('o3').set({
          'tenantId': 'tenant_a',
          'totalCents': 3000,
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

        final stats = await service.getOverviewStats();
        expect(stats.todayOrders, 3);
        expect(stats.todayRevenue, 7000); // 2500 + 1500 + 3000
        expect(stats.activeOrders, 2); // preparing + pending
      });

      test('ignores cancelled orders in active count', () async {
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'totalCents': 1000,
          'status': 'cancelled',
          'createdAt': Timestamp.now(),
        });
        final stats = await service.getOverviewStats();
        expect(stats.activeOrders, 0);
      });
    });

    group('loadOrders', () {
      test('returns empty page when no orders', () async {
        final page = await service.loadOrders();
        expect(page.items, isEmpty);
        expect(page.lastDoc, isNull);
      });

      test('loads orders with pagination cursor', () async {
        for (var i = 0; i < 3; i++) {
          await fakeFirestore.collection('orders').doc('o$i').set({
            'tenantId': 'tenant_a',
            'totalCents': 1000 * (i + 1),
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, i)),
          });
        }
        final page = await service.loadOrders();
        expect(page.items.length, 3);
        expect(page.lastDoc, isNotNull);
      });

      test('loads page 2 after page 1 cursor', () async {
        for (var i = 0; i < 5; i++) {
          await fakeFirestore.collection('orders').doc('o$i').set({
            'tenantId': 'tenant_a',
            'totalCents': 1000 * (i + 1),
            'status': 'delivered',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0, i)),
          });
        }
        // Page 1: the NEWEST 2 orders.
        final page1 = await service.loadOrders(limit: 2);
        expect(page1.items.length, 2);
        expect(page1.lastDoc, isNotNull); // P5-05: cursor is now returned
        // PERF-2: this is REAL cursor behavior, not a contract assertion. The
        // service chains `startAfterDocument` BEFORE `.limit()` (equivalent on
        // the real SDK, and the only order fake_cloud_firestore honors), so a
        // dropped cursor — the classic "Load More re-fetches page 1" bug —
        // fails the disjointness assertion below instead of passing silently.
        final page2 = await service.loadOrders(
          startAfter: page1.lastDoc,
          limit: 2,
        );
        expect(page2.items.length, 2);
        expect(
          page2.items
              .map((o) => o.id)
              .toSet()
              .intersection(page1.items.map((o) => o.id).toSet()),
          isEmpty,
          reason: 'page 2 must EXCLUDE page 1 (no re-fetch of the first page)',
        );
        // Page 3 is the short, final slice: the collection is exhausted.
        final page3 = await service.loadOrders(
          startAfter: page2.lastDoc,
          limit: 2,
        );
        expect(page3.items.length, 1);
        expect(
          {
            ...page1.items.map((o) => o.id),
            ...page2.items.map((o) => o.id),
            ...page3.items.map((o) => o.id),
          },
          {'o0', 'o1', 'o2', 'o3', 'o4'},
          reason: 'walking the cursor must visit every order exactly once',
        );
      });
    });

    group('loadUsers', () {
      test('returns empty page when no users', () async {
        final page = await service.loadUsers();
        expect(page.items, isEmpty);
        expect(page.lastDoc, isNull);
      });

      test('loads users with pagination cursor', () async {
        for (var i = 0; i < 3; i++) {
          await fakeFirestore.collection('users').doc('u$i').set({
            'email': 'user$i@test.com',
            'name': 'User $i',
            'role': 'customer',
            'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 9, 0, i)),
          });
        }
        final page = await service.loadUsers();
        expect(page.items.length, 3);
        expect(page.lastDoc, isNotNull);
      });

      test('walking the users cursor visits every user exactly once', () async {
        for (var i = 0; i < 3; i++) {
          await fakeFirestore.collection('users').doc('u$i').set({
            'email': 'user$i@test.com',
            'name': 'User $i',
            'role': 'customer',
          });
        }
        final page1 = await service.loadUsers(limit: 2);
        expect(page1.items.length, 2);
        final page2 = await service.loadUsers(
          startAfter: page1.lastDoc,
          limit: 2,
        );
        expect(page2.items.length, 1);
        expect(
          page2.items
              .map((u) => u.id)
              .toSet()
              .intersection(page1.items.map((u) => u.id).toSet()),
          isEmpty,
          reason: 'page 2 must EXCLUDE page 1 (no re-fetch of the first page)',
        );
        expect(
          {...page1.items.map((u) => u.id), ...page2.items.map((u) => u.id)},
          {'u0', 'u1', 'u2'},
        );
      });
    });

    group('updateUserRole', () {
      test('updates role correctly', () async {
        await fakeFirestore.collection('users').doc('u1').set({
          'email': 'test@test.com',
          'role': 'customer',
        });
        await service.updateUserRole('u1', UserRole.kitchen);
        final doc = await fakeFirestore.collection('users').doc('u1').get();
        expect(doc.data()!['role'], 'kitchen');
      });
    });

    group('updateUserBranch', () {
      test('updates branch correctly', () async {
        await fakeFirestore.collection('users').doc('u1').set({
          'email': 'test@test.com',
          'role': 'customer',
        });
        await service.updateUserBranch('u1', 'branch_1');
        final doc = await fakeFirestore.collection('users').doc('u1').get();
        expect(doc.data()!['branchId'], 'branch_1');
      });
    });

    group('loadBranches', () {
      test('returns empty list when no branches', () async {
        final branches = await service.loadBranches();
        expect(branches, isEmpty);
      });
    });

    group('saveBranch', () {
      test('creates new branch stamped with the caller tenant', () async {
        await service.saveBranch({
          'name': 'Test Branch',
          'address': '123 Test St',
        });
        final branches = await service.loadBranches();
        expect(branches, hasLength(1));
        // tenantOkCreate() compares this key to the claim: a create without it is
        // denied once branches is scoped, which is the bug this covers.
        final raw = await fakeFirestore.collection('branches').get();
        expect(raw.docs.single.data()['tenantId'], 'tenant_a');
      });
    });

    group('deleteBranch', () {
      test('soft deletes branch with no pending orders', () async {
        await fakeFirestore.collection('branches').doc('b1').set({
          'name': 'Test Branch',
          'isActive': true,
        });
        final result = await service.deleteBranch('b1');
        expect(result, true);
        final doc = await fakeFirestore.collection('branches').doc('b1').get();
        expect(doc.data()!['isActive'], false);
      });
    });

    group('loadGlobalMenu', () {
      test('stream emits menu items', () async {
        await fakeFirestore.collection('menus').doc('m1').set({
          'name': 'Burger',
          'priceCents': 999,
          'isAvailable': true,
        });
        final items = await service.streamGlobalMenu().first;
        expect(items, hasLength(1));
      });
    });

    group('toggleMenuItemAvailability', () {
      test('toggles availability', () async {
        await fakeFirestore.collection('menus').doc('m1').set({
          'name': 'Burger',
          'priceCents': 999,
          'isAvailable': true,
        });
        await service.toggleMenuItemAvailability('m1', false);
        final doc = await fakeFirestore.collection('menus').doc('m1').get();
        expect(doc.data()!['isAvailable'], false);
      });
    });

    group('deleteMenuItem', () {
      test('deletes menu item', () async {
        await fakeFirestore.collection('menus').doc('m1').set({
          'name': 'Burger',
          'priceCents': 999,
        });
        await service.deleteMenuItem('m1');
        final doc = await fakeFirestore.collection('menus').doc('m1').get();
        expect(doc.exists, false);
      });
    });

    group('AdminOverviewStats', () {
      test('constructs correctly', () {
        const stats = AdminOverviewStats(
          todayOrders: 5,
          todayRevenue: 10000,
          activeOrders: 3,
        );
        expect(stats.todayOrders, 5);
        expect(stats.todayRevenue, 10000);
        expect(stats.activeOrders, 3);
      });
    });

    group('streamOrdersByBranch — W8.7 window + cap (T-2)', () {
      test(
        'caps the live history stream at kManagerOrdersHistoryCap (200)',
        () async {
          const overCap = kManagerOrdersHistoryCap + 20;
          for (var i = 0; i < overCap; i++) {
            await fakeFirestore.collection('orders').doc('hist-o$i').set({
              'tenantId': 'tenant_a',
              'branchId': 'branch-1',
              'status': 'delivered',
              'totalCents': 1000,
              'createdAt': Timestamp.fromDate(
                DateTime.now().subtract(Duration(minutes: i + 1)),
              ),
            });
          }

          final orders = await service.streamOrdersByBranch('branch-1').first;

          expect(
            orders.length,
            kManagerOrdersHistoryCap,
            reason: 'W8.7: the manager history stream must be hard-capped',
          );
          // Newest-first preserved: the cap keeps the NEWEST 200 docs.
          expect(orders.first.id, 'hist-o0');
        },
      );

      test('24 h window drops orders older than the window', () async {
        final now = DateTime.now();
        for (var i = 0; i < 3; i++) {
          await fakeFirestore.collection('orders').doc('fresh-o$i').set({
            'tenantId': 'tenant_a',
            'branchId': 'branch-1',
            'status': 'delivered',
            'totalCents': 1000,
            'createdAt': Timestamp.fromDate(
              now.subtract(Duration(minutes: i + 1)),
            ),
          });
        }
        await fakeFirestore.collection('orders').doc('stale-o1').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch-1',
          'status': 'delivered',
          'totalCents': 1000,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 25)),
          ),
        });

        final orders = await service.streamOrdersByBranch('branch-1').first;

        expect(
          orders.every((o) => o.id != 'stale-o1'),
          isTrue,
          reason: 'W8.7: the 24 h window must exclude older history',
        );
        expect(orders.length, 3);
      });

      test('orders are newest-first (descending createdAt)', () async {
        final now = DateTime.now();
        await fakeFirestore.collection('orders').doc('newest').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch-1',
          'status': 'delivered',
          'totalCents': 1000,
          'createdAt': Timestamp.fromDate(now),
        });
        await fakeFirestore.collection('orders').doc('older').set({
          'tenantId': 'tenant_a',
          'branchId': 'branch-1',
          'status': 'delivered',
          'totalCents': 1000,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 5)),
          ),
        });

        final orders = await service.streamOrdersByBranch('branch-1').first;
        expect(orders.first.id, 'newest');
        expect(orders.last.id, 'older');
      });
    });

    group('streamGlobalMenu — W8.7 cap (T-2)', () {
      test(
        'caps the owner global menu stream at kMenuMaxItemsSafetyCap (500)',
        () async {
          const overCap = kMenuMaxItemsSafetyCap + 10;
          for (var i = 0; i < overCap; i++) {
            await fakeFirestore.collection('menus').doc('m$i').set({
              'name': 'Item $i',
              'priceCents': 999,
              'isAvailable': true,
            });
          }

          final items = await service.streamGlobalMenu().first;

          expect(
            items.length,
            kMenuMaxItemsSafetyCap,
            reason: 'W8.7: the owner global menu stream must be hard-capped',
          );
        },
      );
    });
  });
  group('D-057 — the tenant constraint is in the QUERY, not left to rules', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AdminDataService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AdminDataService(
        firestore: fakeFirestore,
        logger: LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
        tenantClaim: const FixedTenantClaim(),
      );
    });

    test("another tenant's orders are invisible to the overview", () async {
      await fakeFirestore.collection('orders').doc('other_1').set({
        'tenantId': 'tenant_b',
        'totalCents': 9999,
        'status': 'confirmed',
        'createdAt': Timestamp.now(),
      });

      final stats = await service.getOverviewStats();
      final page = await service.loadOrders();

      expect(stats.todayOrders, 0);
      expect(stats.todayRevenue, 0);
      expect(page.items, isEmpty);
    });

    test(
      'a session without the claim fails loudly, never reads zero',
      () async {
        final claimless = AdminDataService(
          firestore: fakeFirestore,
          logger: LoggerService(
            testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
          ),
          tenantClaim: const FixedTenantClaim(null),
        );

        await expectLater(
          claimless.getOverviewStats(),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
