@Tags(['gate_fast'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';

/// P2-1 — the orders UPDATE rule's key contract, against the writes the app
/// actually makes.
///
/// Why this file: landing the cash ledger made the order document's money
/// fields load-bearing (a `sale_` row states the total; the order states it
/// too). Reading `firestore.rules` while doing that found the OWNER branch of
/// `allow update` on `orders` was the only clause WITHOUT a
/// `diff(resource.data).affectedKeys().hasOnly([...])` lock — every other role
/// had one. An owner-claimed client could therefore rewrite `totalCents` or
/// `paymentMethod` on an order whose immutable ledger row says otherwise.
///
/// The inventory that justifies the fix (every client write to `orders` in
/// `core_app/lib` + `packages/core/lib`, 2026-11-15):
///
///   | writer                                      | keys affected                       |
///   |---------------------------------------------|-------------------------------------|
///   | `order_repository.dart:61` (demo cancel)    | status, updatedAt                   |
///   | `kitchen_service.dart:131`                  | status, updatedAt                   |
///   | `delivery_service.dart:157` (markDelivered) | status, updatedAt                   |
///   | `delivery_service.dart:206` (claim)         | assignedDriverId, status, updatedAt |
///   | `proof_of_delivery_service.dart:131`        | proofOfDelivery, status             |
///
/// `id` appears in the queued payloads but is not an affected key: every order
/// doc carries its own `id`, so the merge writes the same value and Firestore
/// excludes it from the diff (`delivery_service.dart:245`–`250` states this).
void main() {
  const ruleFiles = ['firestore.rules', 'staging.firestore.rules'];
  const roles = ['owner', 'manager', 'kitchen', 'customer', 'delivery'];

  /// Keys no CLIENT role may ever change: the server owns money. The admin SDK
  /// bypasses rules, so `createCashOrder` / `voidCashSale` are unaffected.
  const moneyKeys = [
    'totalCents',
    'taxCents',
    'itemsSubtotalCents',
    'changeCents',
    'amountTenderedCents',
    'discountCents',
    'tipCents',
    'deliveryFeeCents',
    'taxRate',
    'items',
    'paymentMethod',
    'paymentIntentId',
    'idempotencyKey',
    'customerId',
    'tenantId',
    'channel',
    'voidReason',
    'voidedBy',
    'voidedAt',
  ];

  /// Every legitimate affected key, across all roles.
  const legitimate = {
    'status',
    'assignedDriverId',
    'updatedAt',
    'proofOfDelivery',
  };

  String ordersBlock(String path) {
    final rules = File(path).readAsStringSync();
    final start = rules.indexOf('match /orders/{orderId} {');
    expect(start, isNot(-1), reason: '$path: orders rule not found');
    final end = rules.indexOf('match /presence/', start);
    expect(
      end,
      isNot(-1),
      reason: '$path: presence rule not found after orders',
    );
    return rules.substring(start, end);
  }

  /// The `allow update:` expression, comments stripped so a doc comment quoting
  /// the `hasOnly` idiom cannot be mistaken for a real lock.
  String updateClause(String path) {
    final block = ordersBlock(path);
    final start = block.indexOf('allow update: if');
    expect(start, isNot(-1), reason: '$path: orders allow update not found');
    final end = block.indexOf('\n      );', start);
    expect(
      end,
      isNot(-1),
      reason: '$path: orders allow update is unterminated',
    );
    return block
        .substring(start, end)
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }

  /// The text of one role's branch inside the update clause.
  String roleBranch(String clause, String role) {
    final marker = "userRole() == '$role'";
    final start = clause.indexOf(marker);
    expect(start, isNot(-1), reason: 'no branch for $role');
    final next = clause.indexOf('userRole() ==', start + marker.length);
    return clause.substring(start, next == -1 ? clause.length : next);
  }

  Set<String> affectedKeys(String text) {
    final keys = <String>{};
    var index = text.indexOf('affectedKeys().hasOnly(');
    while (index != -1) {
      final open = text.indexOf('[', index);
      final close = text.indexOf(']', open);
      expect(open, isNot(-1), reason: 'hasOnly without a list');
      expect(close, isNot(-1), reason: 'unterminated hasOnly list');
      keys.addAll(
        RegExp(
          "'([A-Za-z0-9_]+)'",
        ).allMatches(text.substring(open + 1, close)).map((m) => m.group(1)!),
      );
      index = text.indexOf('affectedKeys().hasOnly(', index + 1);
    }
    return keys;
  }

  for (final path in ruleFiles) {
    group('$path — orders update', () {
      test('every role branch carries a key allowlist (owner included)', () {
        final clause = updateClause(path);
        final unlocked = roles
            .where((role) => affectedKeys(roleBranch(clause, role)).isEmpty)
            .toList();
        // RED before the fix: ['owner'] — the one branch with no lock.
        expect(
          unlocked,
          isEmpty,
          reason: 'roles with no hasOnly lock: $unlocked',
        );
      });

      test('no role may change a money or provenance key', () {
        final clause = updateClause(path);
        for (final role in roles) {
          final granted = affectedKeys(roleBranch(clause, role));
          expect(
            granted.intersection(moneyKeys.toSet()),
            isEmpty,
            reason: '$path: $role may not write a money/provenance key',
          );
        }
      });

      test('no role is granted a key the app never writes', () {
        final clause = updateClause(path);
        for (final role in roles) {
          final extra = affectedKeys(
            roleBranch(clause, role),
          ).difference(legitimate);
          expect(extra, isEmpty, reason: '$path: $role is granted $extra');
        }
      });

      test('the union still covers every legitimate client write', () {
        final clause = updateClause(path);
        final union = <String>{};
        for (final role in roles) {
          union.addAll(affectedKeys(roleBranch(clause, role)));
        }
        expect(
          union.containsAll(legitimate),
          isTrue,
          reason: '$path: union $union',
        );
      });

      test('the production payloads stay inside some branch', () {
        final clause = updateClause(path);
        final lists = roles
            .map((r) => affectedKeys(roleBranch(clause, r)))
            .toList();
        // `id` is excluded: it is unchanged by the merge, so it is not an
        // affected key at rule-evaluation time (see the header).
        bool covered(Map<String, dynamic> payload) {
          final keys = payload.keys.where((k) => k != 'id').toSet();
          return lists.any((l) => keys.difference(l).isEmpty);
        }

        final kitchen = buildKitchenStatusUpdatePayload('order_1', 'preparing');
        expect(covered(kitchen), isTrue, reason: 'kitchen: $kitchen');

        final claim = buildDeliveryClaimPayload('order_2', 'driver_uid');
        expect(covered(claim), isTrue, reason: 'claim: $claim');

        final delivered = buildDeliveryStatusUpdatePayload(
          'order_3',
          'delivered',
        );
        expect(covered(delivered), isTrue, reason: 'delivered: $delivered');
      });
    });
  }
}
