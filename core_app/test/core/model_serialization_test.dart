import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/auth/user_model.dart';
import 'package:labs/features/admin/domain/branch_model.dart';
import 'package:labs/features/admin/domain/menu_item_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';

void main() {
  // ── UserModel extensions ───────────────────────────────────────────
  group('UserModel extended fields', () {
    test('isOnline defaults to false', () {
      const u = UserModel(id: 'u1');
      expect(u.isOnline, false);
    });

    test('displayName serialises', () {
      const u = UserModel(id: 'u2', displayName: 'Alice');
      expect(u.toJson()['displayName'], 'Alice');
    });

    test('assignedOrderIds round-trips JSON', () {
      final u = UserModel.fromJson({
        'id': 'u3',
        'assignedOrderIds': ['o1', 'o2'],
      });
      expect(u.assignedOrderIds, ['o1', 'o2']);
    });

    test('createdAt writes to JSON', () {
      final now = DateTime(2024, 1, 15);
      final u = UserModel(id: 'u4', createdAt: now);
      expect(u.toJson()['createdAt'], isNotNull);
    });
  });

  // ── OrderModel extended fields ────────────────────────────────────
  group('OrderModel extended fields', () {
    test('assignedDriverId round-trips', () {
      final o = OrderModel.fromJson({
        'id': 'o1',
        'customerId': 'cust1',
        'status': 'ready',
        'totalCents': 1200,
        'assignedDriverId': 'drv1',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(o.assignedDriverId, 'drv1');
    });

    test('extended statuses parse correctly', () {
      for (final s in ['confirmed', 'preparing', 'pickedUp', 'cancelled']) {
        final status = OrderStatus.fromString(s);
        expect(status.name, s);
      }
    });

    test('updatedAt is optional', () {
      final o = OrderModel(
        id: 'o2',
        customerId: 'u1',
        status: OrderStatus.pending,
        totalCents: 0,
        createdAt: DateTime.now(),
      );
      expect(o.updatedAt, isNull);
    });

    test('customerLocation is omitted when null in toJson', () {
      final o = OrderModel(
        id: 'o3',
        customerId: 'u1',
        status: OrderStatus.pending,
        totalCents: 0,
        createdAt: DateTime.now(),
      );
      expect(o.toJson().containsKey('customerLocation'), isFalse);
    });
  });

  // ── BranchModel ───────────────────────────────────────────────────
  group('BranchModel', () {
    test('fromJson round-trips all fields', () {
      final b = BranchModel.fromJson({
        'id': 'b1',
        'name': 'NYC Branch',
        'address': '123 5th Ave',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'deliveryRadiusMiles': 3.5,
        'isDefault': true,
      });
      expect(b.id, 'b1');
      expect(b.name, 'NYC Branch');
      expect(b.deliveryRadiusMiles, 3.5);
      expect(b.isDefault, true);
    });

    test('toJson includes all required fields', () {
      const b = BranchModel(
        id: 'b2',
        name: 'LA Branch',
        address: '456 Sunset Blvd',
        latitude: 34.0522,
        longitude: -118.2437,
        deliveryRadiusMiles: 5.0,
        isDefault: false,
      );
      final j = b.toJson();
      expect(j['name'], 'LA Branch');
      expect(j['deliveryRadiusMiles'], 5.0);
      expect(j['isDefault'], false);
    });

    test('isDefault defaults to false', () {
      final b = BranchModel.fromJson({
        'id': 'b3',
        'name': 'B',
        'address': 'A',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'deliveryRadiusMiles': 2.0,
      });
      expect(b.isDefault, false);
    });
  });

  // ── MenuItemModel ─────────────────────────────────────────────────
  group('MenuItemModel', () {
    test('global item has null branchId', () {
      final m = MenuItemModel.fromJson({
        'id': 'mi1',
        'name': 'Burger',
        'priceCents': 1299,
        'description': 'Tasty',
        'imageUrl': '',
        'modifiers': [],
        'isAvailable': true,
      });
      expect(m.branchId, isNull);
    });

    test('branch override has branchId set', () {
      final m = MenuItemModel.fromJson({
        'id': 'mi2',
        'name': 'Burger (Spicy)',
        'priceCents': 1499,
        'description': 'Hot',
        'imageUrl': '',
        'modifiers': [],
        'isAvailable': true,
        'branchId': 'b1',
      });
      expect(m.branchId, 'b1');
    });

    test('isAvailable defaults to true', () {
      final m = MenuItemModel.fromJson({
        'id': 'mi3',
        'name': 'Pizza',
        'priceCents': 1000,
        'description': '',
        'imageUrl': '',
        'modifiers': [],
      });
      expect(m.isAvailable, true);
    });

    test('toJson serialises correctly', () {
      const m = MenuItemModel(
        id: 'mi4',
        name: 'Salad',
        priceCents: 850,
        description: 'Fresh',
        imageUrl: 'https://example.com/img.jpg',
        modifiers: [
          {'name': 'Dressing', 'price': 1.0},
        ],
        isAvailable: true,
        branchId: 'b2',
      );
      final j = m.toJson();
      expect(j['name'], 'Salad');
      expect(j['branchId'], 'b2');
      expect(j['priceCents'], 850);
    });
  });

  // ── Law 23/24: Roundtrip Invariants ─────────────────────────────────────
  // Every @freezed model MUST survive a full encode → decode cycle without loss.
  group('UserModel – Roundtrip Invariants (Law 23/24)', () {
    test('full populated model survives toJson → fromJson', () {
      final original = UserModel(
        id: 'u99',
        email: 'chef@carnama.com',
        name: 'Chef Ali',
        displayName: 'Chef Ali',
        phone: '+971501234567',
        loyaltyPoints: 250,
        tier: 'gold',
        role: UserRole.kitchen,
        branchId: 'branch_01',
        isOnline: true,
        assignedOrderIds: ['ord_1', 'ord_2'],
        createdAt: DateTime.utc(2024, 6, 1),
      );
      final roundtripped = UserModel.fromJson(original.toJson());
      expect(roundtripped, original);
    });

    test('null optional fields survive roundtrip', () {
      const original = UserModel(id: 'u100');
      final roundtripped = UserModel.fromJson(original.toJson());
      expect(roundtripped, original);
    });

    test('all UserRoles roundtrip via JSON', () {
      for (final role in UserRole.values) {
        final u = UserModel(id: 'urole', role: role);
        final rt = UserModel.fromJson(u.toJson());
        expect(rt.role, role);
      }
    });
  });

  group('OrderModel – Roundtrip Invariants (Law 23/24)', () {
    test('full populated model survives toJson → fromJson', () {
      final original = OrderModel(
        id: 'ord_99',
        customerId: 'u99',
        status: OrderStatus.preparing,
        totalCents: 4500,
        createdAt: DateTime.utc(2024, 6, 1),
        updatedAt: DateTime.utc(2024, 6, 1, 12),
        branchId: 'branch_01',
        assignedDriverId: 'drv_01',
        customerLat: 25.2048,
        customerLng: 55.2708,
      );
      final roundtripped = OrderModel.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.customerId, original.customerId);
      expect(roundtripped.status, original.status);
      expect(roundtripped.totalCents, original.totalCents);
      expect(roundtripped.branchId, original.branchId);
      expect(roundtripped.customerLat, original.customerLat);
    });

    test('all OrderStatuses roundtrip via name', () {
      for (final status in OrderStatus.values) {
        final parsed = OrderStatus.fromString(status.name);
        expect(parsed, status);
      }
    });

    test('OrderStatus.fromString is case-insensitive', () {
      expect(OrderStatus.fromString('PREPARING'), OrderStatus.preparing);
      expect(OrderStatus.fromString('Picked_Up'), OrderStatus.pickedUp);
      expect(OrderStatus.fromString('CANCELLED'), OrderStatus.cancelled);
    });

    test('Unknown status falls back to pending', () {
      expect(OrderStatus.fromString('garbage_value'), OrderStatus.pending);
    });
  });

  // ── Timestamp Edge Cases (Laws 23, 24) ──────────────────────────────────
  group('Timestamp serialisation edge cases (Laws 23, 24)', () {
    test('createdAt: null on UserModel returns null, no crash', () {
      expect(() => UserModel.fromJson({'id': 'u_null_ts'}), returnsNormally);
      final u = UserModel.fromJson({'id': 'u_null_ts'});
      expect(
        u.createdAt,
        isNull,
        reason: 'Missing createdAt must be null, not crash',
      );
    });

    test('createdAt as ISO-8601 String is parsed to DateTime correctly', () {
      const iso = '2024-03-15T10:30:00.000Z';
      final u = UserModel.fromJson({'id': 'u_iso', 'createdAt': iso});
      expect(u.createdAt, isA<DateTime>());
      expect(u.createdAt!.year, 2024);
      expect(u.createdAt!.month, 3);
      expect(u.createdAt!.day, 15);
    });

    test(
      'createdAt preserves UTC timezone — no silent timezone conversion',
      () {
        final utcTime = DateTime.utc(2024, 6, 1, 12, 0, 0);
        final u = UserModel(id: 'u_utc', createdAt: utcTime);
        final json = u.toJson();
        final rebuilt = UserModel.fromJson(json);
        expect(
          rebuilt.createdAt!.isUtc,
          isTrue,
          reason: 'UTC DateTime must survive toJson/fromJson without shifting',
        );
        expect(
          rebuilt.createdAt!.hour,
          12,
          reason: 'Hour must not shift during serialisation',
        );
      },
    );

    test('createdAt as wrong-type int — graceful fallback to null', () {
      // Some legacy Firestore documents may have stored Unix timestamps as ints
      expect(
        () => UserModel.fromJson({'id': 'u_int_ts', 'createdAt': 1715000000}),
        returnsNormally,
        reason: 'Wrong-type int for createdAt must not throw',
      );
    });

    test(
      'OrderModel.updatedAt as null — optional field stays null, no crash',
      () {
        final o = OrderModel.fromJson({
          'id': 'o_null_update',
          'customerId': 'u1',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': null,
        });
        expect(o.updatedAt, isNull);
      },
    );

    test('OrderModel.createdAt round-trips with millisecond precision', () {
      final precise = DateTime.utc(2024, 5, 30, 14, 7, 19, 123);
      final o = OrderModel(
        id: 'o_precise',
        customerId: 'u1',
        createdAt: precise,
        status: OrderStatus.pending,
        totalCents: 0,
      );
      final json = o.toJson();
      final rebuilt = OrderModel.fromJson(json);
      expect(
        rebuilt.createdAt.millisecondsSinceEpoch,
        precise.millisecondsSinceEpoch,
        reason: 'Millisecond precision must be preserved in roundtrip',
      );
    });
  });
}
