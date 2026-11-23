import 'package:cloud_firestore/cloud_firestore.dart';

/// Constitution Law 30 — Comprehensive Emulator Test Data Seeder
///
/// Pre-populates the local Firebase Emulator with a deterministic, full
/// schema of test data covering every Firestore collection.
///
/// Rules:
/// - Every document matches the exact schema defined in the Constitution (Part 5).
/// - All IDs are deterministic strings so tests can reference them reliably.
/// - Call seedAllTestData() in setUpAll of integration/wiring tests.
/// - Call clearAllTestData() in tearDownAll for idempotency.
///
/// Usage:
///   setUpAll(() async {
///     await setupFirebaseEmulators();
///     await seedAllTestData();
///   });
///   tearDownAll(clearAllTestData);

const kTestBranchId = 'branch_test_01';
const kTestMenuItemId = 'menu_item_pizza_01';
const kTestCustomerUid = 'customer_uid_test_001';
const kTestManagerUid = 'manager_uid_test_002';
const kTestDriverUid = 'driver_uid_test_003';
const kTestKitchenUid = 'kitchen_uid_test_004';
const kTestOrderId = 'order_test_001';
const kTestReservationId = 'reservation_test_001';
const kTestPromoId = 'promo_test_001';

final _db = FirebaseFirestore.instance;

Future<void> seedAllTestData() async {
  await Future.wait([
    _seedSettings(),
    _seedBranches(),
    _seedUsers(),
    _seedMenuItems(),
    _seedOrders(),
    _seedCarts(),
    _seedReservations(),
    _seedPromotions(),
    _seedLoyalty(),
  ]);
}

Future<void> clearAllTestData() async {
  final collections = [
    'settings',
    'branches',
    'users',
    'menus',
    'orders',
    'carts',
    'reservations',
    'promotions',
    'loyalty',
    'driverLocations',
    'analyticsEvents',
  ];
  await Future.wait(collections.map((c) => _deleteCollection(c)));
}

// ── Settings ────────────────────────────────────────────────────────────────
Future<void> _seedSettings() async {
  await _db.collection('settings').doc('ownerInfo').set({
    'ownerEmail': 'admin@carnama.com',
  });
  await _db.collection('settings').doc('featureFlags').set({
    'liveTracking': true,
    'stripe': false, // disabled in test environment
    'reservations': true,
    'promos': true,
    'loyaltyPoints': true,
    'driverTracking': true,
    'maintenanceMode': false,
  });
}

// ── Branches ────────────────────────────────────────────────────────────────
Future<void> _seedBranches() async {
  await _db.collection('branches').doc(kTestBranchId).set({
    'name': 'Test Branch Downtown',
    'address': '1 Constitution Street, Test City',
    'coordinates': const GeoPoint(25.2048, 55.2708),
    'deliveryRadiusMiles': 5.0,
    'isDefault': true,
    'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
  });
}

// ── Users (all roles) ────────────────────────────────────────────────────────
Future<void> _seedUsers() async {
  final batch = _db.batch();

  batch.set(_db.collection('users').doc(kTestCustomerUid), {
    'id': kTestCustomerUid,
    'email': 'customer@carnama.com',
    'displayName': 'Test Customer',
    'role': 'customer',
    'loyaltyPoints': 150,
    'isOnline': false,
    'assignedOrderIds': [],
    'createdAt': DateTime.utc(2024, 1, 2).toIso8601String(),
  });

  batch.set(_db.collection('users').doc(kTestManagerUid), {
    'id': kTestManagerUid,
    'email': 'manager@carnama.com',
    'displayName': 'Test Manager',
    'role': 'manager',
    'branchId': kTestBranchId,
    'loyaltyPoints': 0,
    'isOnline': true,
    'assignedOrderIds': [],
    'createdAt': DateTime.utc(2024, 1, 2).toIso8601String(),
  });

  batch.set(_db.collection('users').doc(kTestDriverUid), {
    'id': kTestDriverUid,
    'email': 'driver@carnama.com',
    'displayName': 'Test Driver',
    'role': 'delivery',
    'branchId': kTestBranchId,
    'loyaltyPoints': 0,
    'isOnline': false,
    'assignedOrderIds': [kTestOrderId],
    'createdAt': DateTime.utc(2024, 1, 3).toIso8601String(),
  });

  batch.set(_db.collection('users').doc(kTestKitchenUid), {
    'id': kTestKitchenUid,
    'email': 'kitchen@carnama.com',
    'displayName': 'Test Kitchen',
    'role': 'kitchen',
    'branchId': kTestBranchId,
    'loyaltyPoints': 0,
    'isOnline': true,
    'assignedOrderIds': [],
    'createdAt': DateTime.utc(2024, 1, 4).toIso8601String(),
  });

  await batch.commit();
}

// ── Menu Items ───────────────────────────────────────────────────────────────
Future<void> _seedMenuItems() async {
  final batch = _db.batch();

  batch.set(_db.collection('menus').doc(kTestMenuItemId), {
    'id': kTestMenuItemId,
    'name': 'Margherita Pizza',
    'priceCents': 1299,
    'description': 'Classic tomato and mozzarella',
    'imageUrl': 'https://example.com/pizza.jpg',
    'isAvailable': true,
    'tags': ['Popular', 'Vegetarian'],
    'modifiers': [
      {'name': 'Extra Cheese', 'priceCents': 200},
      {'name': 'Thin Crust', 'priceCents': 0},
    ],
    'branchId': null, // global item
    'createdAt': DateTime.utc(2024, 1, 5).toIso8601String(),
  });

  batch.set(_db.collection('menus').doc('menu_item_unavail_01'), {
    'id': 'menu_item_unavail_01',
    'name': 'Sold Out Burger',
    'priceCents': 999,
    'description': 'Currently unavailable',
    'imageUrl': '',
    'isAvailable': false, // for empty-state / unavailable tests
    'tags': [],
    'modifiers': [],
    'branchId': kTestBranchId,
    'createdAt': DateTime.utc(2024, 1, 5).toIso8601String(),
  });

  await batch.commit();
}

// ── Orders ───────────────────────────────────────────────────────────────────
Future<void> _seedOrders() async {
  await _db.collection('orders').doc(kTestOrderId).set({
    'id': kTestOrderId,
    'customerId': kTestCustomerUid,
    'branchId': kTestBranchId,
    'status': 'preparing',
    'totalCents': 1299,
    'assignedDriverId': kTestDriverUid,
    'items': [
      {
        'menuItemId': kTestMenuItemId,
        'name': 'Margherita Pizza',
        'quantity': 1,
        'priceCents': 1299,
        'modifiers': [],
      },
    ],
    'customerLat': 25.2048,
    'customerLng': 55.2708,
    'createdAt': DateTime.utc(2024, 6, 1, 10).toIso8601String(),
    'updatedAt': DateTime.utc(2024, 6, 1, 10, 5).toIso8601String(),
  });
}

// ── Carts ────────────────────────────────────────────────────────────────────
Future<void> _seedCarts() async {
  await _db.collection('carts').doc(kTestCustomerUid).set({
    'items': [
      {
        'menuItemId': kTestMenuItemId,
        'name': 'Margherita Pizza',
        'quantity': 2,
        'priceCents': 1299,
        'modifiers': [],
      },
    ],
  });
}

// ── Reservations ─────────────────────────────────────────────────────────────
Future<void> _seedReservations() async {
  await _db.collection('reservations').doc(kTestReservationId).set({
    'id': kTestReservationId,
    'customerId': kTestCustomerUid,
    'branchId': kTestBranchId,
    'date': '2024-06-15',
    'slot': '19:00',
    'status': 'confirmed',
    'partySize': 4,
    'createdAt': DateTime.utc(2024, 6, 1).toIso8601String(),
  });
}

// ── Promotions ───────────────────────────────────────────────────────────────
Future<void> _seedPromotions() async {
  await _db.collection('promotions').doc(kTestPromoId).set({
    'id': kTestPromoId,
    'imageUrl': 'https://example.com/promo.jpg',
    'actionUrl': '/menu',
    'isActive': true,
    'priority': 1,
    'createdAt': DateTime.utc(2024, 6, 1).toIso8601String(),
  });
}

// ── Loyalty ──────────────────────────────────────────────────────────────────
Future<void> _seedLoyalty() async {
  await _db.collection('loyalty').doc(kTestCustomerUid).set({
    'totalPoints': 150,
    'tier': 'bronze',
    'lastUpdated': DateTime.utc(2024, 6, 1).toIso8601String(),
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────
Future<void> _deleteCollection(String collectionPath) async {
  final snap = await _db.collection(collectionPath).limit(500).get();
  if (snap.docs.isEmpty) return;
  final batch = _db.batch();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
