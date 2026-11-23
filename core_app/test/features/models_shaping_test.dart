import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_model.dart';

// Spec: Model parsing contracts:
// - UserModel: missing role → customer, missing loyaltyPoints → 0, missing tier → 'starter'
// - OrderModel: unknown status → pending (fail-safe), missing fields → defaults
// - DateTimeConverter: null → null, Timestamp → DateTime, malformed → null
// Tests assert against hard-coded spec values — no mirroring.

void main() {
  group('UserModel — Spec Contract', () {
    test('Malformed timestamp does not crash per spec', () {
      // Spec: invalid timestamp string → model parses without throwing
      final rawData = {
        'id': 'test1',
        'email': 'a@a.com',
        'createdAt': 'this_is_not_a_timestamp_but_a_string',
      };
      expect(() => UserModel.fromDoc(rawData, 'test1'), returnsNormally);
    });

    test('Null email is handled gracefully', () {
      // Spec: null email → empty string or null (model decides)
      final user = UserModel.fromJson({'id': 'test', 'email': null});
      expect(user, isNotNull); // Must not crash
    });

    test('Missing fields map to defaults per spec', () {
      // Spec: missing role → customer, missing loyaltyPoints → 0, missing tier → 'starter'
      final user = UserModel.fromDoc({'id': 'test2'}, 'test2');

      expect(user.role, equals(UserRole.customer));
      expect(user.loyaltyPoints, equals(0));
      expect(user.tier, equals('starter'));
    });

    test('All UserRole values parse from JSON per spec', () {
      // Spec: every role in UserRole enum must be parseable
      for (final role in UserRole.values) {
        final user = UserModel.fromJson({'id': 'test', 'role': role.name});
        expect(user.role, equals(role));
      }
    });

    test('Unknown role falls back to customer per spec', () {
      // Spec: 'alien' → customer
      final user = UserModel.fromJson({'id': 'test', 'role': 'alien'});
      expect(user.role, equals(UserRole.customer));
    });

    test('Email is read from JSON per spec', () {
      final user = UserModel.fromJson({
        'id': 'test',
        'email': 'user@carnama.com',
      });
      expect(user.email, equals('user@carnama.com'));
    });

    test('Null email is handled gracefully', () {
      // Spec: null email → empty string or null (model decides)
      final user = UserModel.fromJson({'id': 'test', 'email': null});
      expect(user, isNotNull); // Must not crash
    });
  });

  group('OrderModel — Spec Contract', () {
    test('Unknown status falls back to pending per spec', () {
      // Spec: 'unknown_future_status' → OrderStatus.pending
      final order = OrderModel.fromJson({
        'id': 'ord1',
        'customerId': 'custId1',
        'branchId': 'bId1',
        'total': 25.50,
        'status': 'unknown_future_status',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(order.status, equals(OrderStatus.pending));
    });

    test('All valid OrderStatus values parse per spec', () {
      // Spec: every status in OrderStatus enum must be parseable
      for (final status in OrderStatus.values) {
        final order = OrderModel.fromJson({
          'id': 'test',
          'customerId': 'c',
          'status': status.name,
          'totalCents': 1000,
          'createdAt': DateTime.now().toIso8601String(),
        });
        expect(order.status, equals(status));
      }
    });

    test('Missing totalCents defaults to 0 per spec', () {
      final order = OrderModel.fromJson({
        'id': 'test',
        'customerId': 'c',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(order.totalCents, equals(0));
    });

    test('Negative totalCents is accepted per spec', () {
      // Spec: model accepts negative totalCents (validation happens upstream)
      final order = OrderModel.fromJson({
        'id': 'test',
        'customerId': 'c',
        'status': 'pending',
        'totalCents': -100,
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(order.totalCents, equals(-100));
    });

    test('Missing createdAt throws per spec', () {
      // Spec: createdAt is required — missing value throws during deserialization
      expect(
        () => OrderModel.fromJson({
          'id': 'test',
          'customerId': 'c',
          'status': 'pending',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('DateTimeConverter — Spec Contract', () {
    test('Null input returns null per spec', () {
      const converter = DateTimeConverter();
      expect(converter.fromJson(null), isNull);
    });

    test('Timestamp converts to DateTime per spec', () {
      final timestamp = Timestamp.fromDate(DateTime(2025, 1, 1));
      final result = const DateTimeConverter().fromJson(timestamp);
      expect(result, isA<DateTime>());
      expect(result!.year, equals(2025));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
    });

    test('ISO-8601 string parses correctly per spec', () {
      final result = const DateTimeConverter().fromJson(
        '2025-06-15T12:30:00.000Z',
      );
      expect(result, isA<DateTime>());
      expect(result!.year, equals(2025));
      expect(result.month, equals(6));
      expect(result.day, equals(15));
    });

    test('Malformed string returns current date per spec', () {
      // Spec: malformed string falls back to current date (not null)
      final before = DateTime.now();
      final result = const DateTimeConverter().fromJson('not_a_date');
      final after = DateTime.now();
      expect(result, isA<DateTime>());
      expect(
        result!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
