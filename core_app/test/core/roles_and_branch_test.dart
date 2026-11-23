import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/auth/user_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';

void main() {
  group('UserModel roles', () {
    test('defaults to customer role', () {
      const user = UserModel(id: 'u1');
      expect(user.role, UserRole.customer);
    });

    test('parses kitchen role from JSON', () {
      final user = UserModel.fromJson({'id': 'u2', 'role': 'kitchen'});
      expect(user.role, UserRole.kitchen);
    });

    test('parses owner role from JSON', () {
      final user = UserModel.fromJson({'id': 'u3', 'role': 'owner'});
      expect(user.role, UserRole.owner);
    });

    test('unknown role string defaults to customer', () {
      final user = UserModel.fromJson({'id': 'u4', 'role': 'unknown'});
      expect(user.role, UserRole.customer);
    });

    test('missing role field defaults to customer', () {
      final user = UserModel.fromJson({'id': 'u5'});
      expect(user.role, UserRole.customer);
    });

    test('serializes role correctly to JSON', () {
      const user = UserModel(id: 'u6', role: UserRole.manager);
      expect(user.toJson()['role'], 'manager');
    });

    test('branchId is read from JSON', () {
      final user = UserModel.fromJson({'id': 'u7', 'branchId': 'branch_a'});
      expect(user.branchId, 'branch_a');
    });

    test('username is read from JSON', () {
      final user = UserModel.fromJson({'id': 'u8', 'username': 'john_doe'});
      expect(user.username, 'john_doe');
    });

    test('phoneNumber is read from JSON', () {
      final user = UserModel.fromJson({
        'id': 'u9',
        'phoneNumber': '+1234567890',
      });
      expect(user.phoneNumber, '+1234567890');
    });
  });

  group('OrderModel branchId', () {
    test('order without branchId has null branchId', () {
      final order = OrderModel(
        id: 'o1',
        customerId: 'u1',
        status: OrderStatus.pending,
        totalCents: 1000,
        createdAt: DateTime.now(),
      );
      expect(order.branchId, isNull);
    });

    test('order stores branchId in JSON', () {
      final order = OrderModel(
        id: 'o2',
        customerId: 'u2',
        status: OrderStatus.pending,
        totalCents: 2000,
        createdAt: DateTime.now(),
        branchId: 'branch_nyc',
      );
      expect(order.toJson()['branchId'], 'branch_nyc');
    });

    test('order reads branchId from JSON', () {
      final order = OrderModel.fromJson({
        'id': 'o3',
        'customerId': 'u3',
        'status': 'cooking',
        'totalCents': 3200,
        'branchId': 'branch_la',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(order.branchId, 'branch_la');
    });

    test('order without branchId in JSON has no key in serialized output', () {
      final order = OrderModel(
        id: 'o4',
        customerId: 'u4',
        status: OrderStatus.pending,
        totalCents: 0,
        createdAt: DateTime.now(),
      );
      expect(order.toJson()['branchId'], isNull);
    });
  });
}
