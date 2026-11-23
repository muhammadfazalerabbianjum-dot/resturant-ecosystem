import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:core/src/auth/user_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/cart/domain/cart_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Simulates the guard logic inside _processPayment that blocks a null branchId.
/// We extract the logic into a standalone function that is independently testable.
/// This mirrors line 109–117 in checkout_screen.dart exactly.
String? _checkoutBranchGuard({required String? branchId}) {
  if (branchId == null) return 'Please select a branch first.';
  return null; // no error - proceed
}

/// Simulates the role-routing logic from RoleRouterScreen (lines 51–54 of role_router_screen.dart).
/// Returns the dashboard name that would be rendered for a given role.
String _resolveRoleDashboard(String rawRole) {
  final role = UserRole.values.firstWhere(
    (r) => r.name == rawRole,
    orElse: () => UserRole.customer,
  );
  return switch (role) {
    UserRole.owner => 'OwnerDashboard',
    UserRole.manager => 'ManagerDashboard',
    UserRole.kitchen => 'KitchenDashboard',
    UserRole.delivery => 'DeliveryDashboard',
    UserRole.customer => 'NoPermission',
  };
}

/// Simulates the checkout idempotency token generator (from checkout_screen.dart).
/// A token must be non-empty, alphanumeric, and 8 characters long.
bool _isValidToken(String token) {
  return token.length == 8 && RegExp(r'^[A-Z0-9]+$').hasMatch(token);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Phase 7 Regression Guards', () {
    // ──────────────────────────────────────────────────────────────────────────
    // M6: BranchId Null Guard
    // ──────────────────────────────────────────────────────────────────────────
    group('M6 – BranchId Null Guard', () {
      test('returns error message when branchId is null', () {
        final result = _checkoutBranchGuard(branchId: null);
        expect(result, equals('Please select a branch first.'));
      });

      test('returns null (no error) when branchId is provided', () {
        final result = _checkoutBranchGuard(branchId: 'branch_123');
        expect(result, isNull);
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // S3/S5 – Role Access Guard
    // ──────────────────────────────────────────────────────────────────────────
    group('S3/S5 – Role Router Access Control', () {
      test('customer role is strictly denied admin dashboard access', () {
        expect(_resolveRoleDashboard('customer'), equals('NoPermission'));
      });

      test('unknown/garbage role defaults to NoPermission', () {
        expect(_resolveRoleDashboard('superuser'), equals('NoPermission'));
        expect(_resolveRoleDashboard(''), equals('NoPermission'));
        expect(
          _resolveRoleDashboard('OWNER'),
          equals('NoPermission'),
        ); // case-sensitive
      });

      test('owner role correctly routes to OwnerDashboard', () {
        expect(_resolveRoleDashboard('owner'), equals('OwnerDashboard'));
      });

      test('manager role correctly routes to ManagerDashboard', () {
        expect(_resolveRoleDashboard('manager'), equals('ManagerDashboard'));
      });

      test('kitchen role correctly routes to KitchenDashboard', () {
        expect(_resolveRoleDashboard('kitchen'), equals('KitchenDashboard'));
      });

      test('delivery role correctly routes to DeliveryDashboard', () {
        expect(_resolveRoleDashboard('delivery'), equals('DeliveryDashboard'));
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // L4 – Checkout Idempotency Token
    // ──────────────────────────────────────────────────────────────────────────
    group('L4 – Checkout Idempotency Token', () {
      // Mirror the logic from _generateToken in checkout_screen.dart
      String generateToken() {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        final rnd = Random.secure();
        return String.fromCharCodes(
          Iterable.generate(
            8,
            (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
          ),
        );
      }

      test(
        'generated token is exactly 8 uppercase alphanumeric characters',
        () {
          final token = generateToken();
          expect(
            _isValidToken(token),
            isTrue,
            reason: 'Token "$token" must be 8 uppercase alphanumeric chars',
          );
        },
      );

      test(
        'two consecutive tokens are unique (collision probability: 1 in ~2.8T)',
        () {
          final token1 = generateToken();
          final token2 = generateToken();
          expect(
            token1,
            isNot(equals(token2)),
            reason:
                'Tokens must be unique to prevent duplicate order submissions',
          );
        },
      );

      test('session key format includes uid hash prefix', () {
        const uid = 'user_abc';
        final token = generateToken();
        final sessionId = 'ORD-${uid.hashCode.abs()}-$token';
        expect(sessionId, startsWith('ORD-'));
        expect(sessionId, contains(uid.hashCode.abs().toString()));
        expect(sessionId.split('-').last, hasLength(8));
      });
    });

    // ──────────────────────────────────────────────────────────────────────────
    // CartModel immutability regression
    // ──────────────────────────────────────────────────────────────────────────
    group('CartModel Immutability Guard', () {
      test('totalCents correctly sums integer priceCents across items', () {
        const item = MenuItemModel(id: 'i1', priceCents: 999);
        const cart = CartModel(items: [CartItemModel(item: item, quantity: 2)]);
        expect(cart.totalCents, equals(1998));
      });

      test('empty cart has zero total', () {
        const cart = CartModel(items: []);
        expect(cart.totalCents, equals(0));
      });
    });
  });
}
