@Tags(['gate_fast'])
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/domain/order_offline_payload.dart';

/// p26 T-4 (D-P26-4(a)) — the orders CREATE rule's key contract versus the ONLY
/// client-side order-create path the app owns.
///
/// Written RED before the hardening lands (Law 2). Three facts make this file
/// the contract rather than a comment:
///
///  1. The rule text is read OFF DISK (`firestore.rules` /
///     `staging.firestore.rules`), so a rule edit that drops the shape lock or
///     a key resurfaces here instead of silently shipping.
///  2. On CREATE there is no `resource`: the affected-key equivalent of the
///     update-time `diff(resource.data).affectedKeys().hasOnly([...])` idiom is
///     the FULL candidate key set, i.e.
///     `request.resource.data.keys().hasOnly([...])`. Both rule files carry it.
///  3. The payload under test is built by the production generator and then
///     mutated exactly like the production replayer
///     (`sync_queue.dart:313-321`): `data['updatedAt'] = FieldValue
///     .serverTimestamp()` before `set(collection, id, data, merge: true)`.
///     A subset check against the allowlist is therefore a statement about the
///     real write, not about a hand-copied fixture.
///
/// Emulator-level proof (ALLOW for the exact payload, DENY for a forged tag)
/// lives in `test/rules/firestore_rules_test.js` (cases `q-T1`, `q-T3`..`q-T9`).
void main() {
  final ordersCreate = <String, String>{};
  final allowlists = <String, List<String>>{};

  setUpAll(() {
    for (final path in const ['firestore.rules', 'staging.firestore.rules']) {
      final rules = File(path).readAsStringSync();
      final clause = _ordersCreateClause(rules, path);
      ordersCreate[path] = clause;
      allowlists[path] = _shapeAllowlist(clause, path);
    }
  });

  group('p26 T-4 — orders create rule shape lock (both rule files)', () {
    test('firestore.rules and staging.firestore.rules carry the SAME '
        'allowlist (Law 18 parity)', () {
      expect(
        allowlists['staging.firestore.rules'],
        orderedEquals(allowlists['firestore.rules']!),
        reason:
            'Law 18: staging is a production clone. A key admitted in one rule '
            'file and not the other is exactly the silent parity drift the '
            'create-rule hardening would otherwise introduce.',
      );
    });

    test('the allowlist excludes the server-owned orderSource key', () {
      for (final entry in allowlists.entries) {
        expect(
          entry.value,
          isNot(contains('orderSource')),
          reason:
              '${entry.key}: `orderSource` is written only by the admin-SDK '
              'platform ingest (p19 L18, `orderSource: platform:<id>`) — admin '
              'writes bypass rules, so no client create has a legitimate '
              'reason to name it. Excluding it from the allowlist makes a '
              'forged platform tag a DENY (harness case q-T3).',
        );
      }
    });

    test('the allowlist excludes unknown rogue keys by construction', () {
      for (final entry in allowlists.entries) {
        expect(
          entry.value,
          isNot(contains('rogueKey')),
          reason: '${entry.key}: hasOnly is an allowlist, never a denylist',
        );
      }
    });

    test('the PRODUCTION create clause keeps every field clause the payload '
        'relies on', () {
      // The citations are verified against the rule TEXT, not remembered — a
      // reworded or dropped clause fails here rather than in production.
      const clauses = <String, String>{
        'ordersAccepting gate': 'isOrdersAccepting()',
        'customer owns the order':
            'request.resource.data.customerId == request.auth.uid',
        'branchId is a string': 'request.resource.data.branchId is string',
        'branchId is non-empty': 'request.resource.data.branchId.size() > 0',
        'totalCents is an int': 'request.resource.data.totalCents is int',
        'totalCents is non-negative': 'request.resource.data.totalCents >= 0',
        'status is pending': "request.resource.data.status == 'pending'",
      };
      final create = ordersCreate['firestore.rules']!;
      for (final clause in clauses.entries) {
        expect(
          create,
          contains(clause.value),
          reason:
              'firestore.rules: the create rule must keep the '
              '${clause.key} clause — the payload asserted below depends on it '
              'and its emulator negative case lives in '
              'firestore_rules_test.js (q-T2, q-T6..q-T11, T-P1..T-P3).',
        );
      }
    });

    test('staging carries the T-4 clauses AND the full production gates '
        '(p29 T-1 Law-18 byte-parity flip)', () {
      final staging = ordersCreate['staging.firestore.rules']!;

      // The two clauses T-4 owns in staging: ownership + the new shape lock.
      expect(
        staging,
        contains('request.resource.data.customerId == request.auth.uid'),
        reason: 'staging: the create rule keeps the caller-owns-the-order gate',
      );
      expect(
        staging,
        contains('request.resource.data.keys().hasOnly(['),
        reason: 'staging: the create rule carries the T-4 shape lock',
      );

      // p29 T-1 FLIP — executed exactly as the comment above instructed at
      // HEAD ("when staging is aligned to production, FLIP these two
      // assertions and cite the change"). staging.firestore.rules is now a
      // byte-identical mirror of production (Law 18), so the create clause
      // carries the App Check / non-anonymous gate, the isOrdersAccepting()
      // switch and the branchId/totalCents/status shape clauses. RED before
      // the flip: g_suite_core_app.txt (-1, "Expected: not contains
      // 'isOrdersAccepting()'"); GREEN after parity.
      expect(staging, contains('isOrdersAccepting()'));
      expect(staging, contains('request.resource.data.status'));
    });
  });

  group('p26 T-4 — the replay payload is legal by construction', () {
    final order = OrderModel(
      id: 'ord-contract',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: OrderStatus.confirmed,
      totalCents: 1500,
      taxCents: 100,
      discountCents: 50,
      tipCents: 200,
      deliveryFeeCents: 300,
      orderNumber: 'C-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    test('every key the replayer writes is in the allowlist (no false '
        'positive)', () {
      final payload = _replayPayload(order);
      final allowed = allowlists['firestore.rules']!.toSet();
      final extra = payload.keys.where((k) => !allowed.contains(k)).toList();

      expect(
        extra,
        isEmpty,
        reason:
            'the offline replay would be DENIED (and dead-lettered, Law 15) by '
            'the hardened create rule. Allowlist: ${allowed.toList()..sort()}',
      );
      // The replayer stamps updatedAt (sync_queue.dart:315); assert the key is
      // really present so the check above is not vacuous.
      expect(payload.containsKey('updatedAt'), isTrue);
    });

    test('the payload carries NO orderSource key at all', () {
      final payload = _replayPayload(order);

      expect(
        payload.containsKey('orderSource'),
        isFalse,
        reason:
            'p22 handoff (WHITE_LABEL_p22_staff.md:71): once the create rule is '
            'hardened with hasOnly, the offline create payload must drop the '
            'then-forbidden `orderSource: null` key. Dropping (not nulling) is '
            'required because a null value still occupies a key slot in the '
            'candidate document — and a forged tag is then impossible rather '
            'than merely ignored.',
      );
    });

    test('the payload satisfies the surviving shape clauses', () {
      final payload = _replayPayload(order);

      expect(payload['customerId'], isA<String>());
      expect((payload['customerId'] as String).isNotEmpty, isTrue);
      expect(payload['branchId'], isA<String>());
      expect((payload['branchId'] as String).isNotEmpty, isTrue);
      expect(payload['totalCents'], isA<int>());
      expect((payload['totalCents'] as int) >= 0, isTrue);
      expect(payload['status'], 'pending');
    });

    test('the allowlist names tenantId and the payload carries it (D-039)', () {
      final payload = _replayPayload(order);
      expect(
        allowlists['firestore.rules'],
        contains('tenantId'),
        reason:
            'a create that carries tenantId while the allowlist omits it is '
            'denied by the shape lock, not by tenancy',
      );
      expect(payload['tenantId'], 'tenant_a');
    });

    test('a forged platform tag is outside the allowlist (the rule, not '
        'convention, is the gate)', () {
      final payload = _replayPayload(order);
      final forged = {...payload, 'orderSource': 'platform:uber_eats'};
      final allowed = allowlists['firestore.rules']!.toSet();

      expect(
        forged.keys.where((k) => !allowed.contains(k)).toList(),
        ['orderSource'],
        reason:
            'a client that bypasses the generator and writes the tag itself '
            'must be outside the allowlist — emulator negative case q-T3.',
      );
    });
  });
}

/// The `allow create:` clause of `match /orders/{orderId}` (up to the following
/// `allow update:`), i.e. everything a create write must satisfy.
String _ordersCreateClause(String rules, String path) {
  final matchIdx = rules.indexOf('match /orders/{orderId}');
  expect(
    matchIdx,
    greaterThan(-1),
    reason: '$path: the orders collection rule block is missing',
  );
  final createIdx = rules.indexOf('allow create:', matchIdx);
  final updateIdx = rules.indexOf('allow update:', matchIdx);
  expect(
    createIdx,
    greaterThan(matchIdx),
    reason: '$path: the orders create rule is missing',
  );
  expect(
    updateIdx,
    greaterThan(createIdx),
    reason: '$path: expected the orders `allow update:` clause after create',
  );
  return rules.substring(createIdx, updateIdx);
}

/// The `request.resource.data.keys().hasOnly([...])` allowlist as written in the
/// rule file. Absence is a hard failure: that is the T-4 deliverable.
List<String> _shapeAllowlist(String createClause, String path) {
  final match = RegExp(
    r'keys\(\)\.hasOnly\(\[(.*?)\]\)',
    dotAll: true,
  ).firstMatch(createClause);
  expect(
    match,
    isNotNull,
    reason:
        '$path: the orders create rule must carry '
        '`request.resource.data.keys().hasOnly([...])` (D-P26-4(a)) — on create '
        'there is no `resource`, so the full candidate key set is the '
        'affected-key equivalent.',
  );
  return RegExp(
    r"'([^']+)'",
  ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toList();
}

/// The exact client write the offline replayer performs.
Map<String, dynamic> _replayPayload(OrderModel order) {
  final payload = buildOfflineOrderPayload(
    order,
    tenantId: 'tenant_a',
    queuedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  );
  // sync_queue.dart:315 — processQueue stamps updatedAt before the merge-set.
  payload['updatedAt'] = FieldValue.serverTimestamp();
  return payload;
}
