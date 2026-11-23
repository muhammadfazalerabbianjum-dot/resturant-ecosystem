import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PERF-8 W1 (A-1) query-scope source scan (file-reading pattern:
/// `LEDGER:PERF-2/checkout_honesty_test` + `app_config_no_pin_test.dart` —
/// the Firestore layer has no pure-Dart mirror under flutter_test, so the
/// pin reads the real production sources).
///
/// Tenancy is enforced per Firebase PROJECT (whitelabel.dart:2326-2332 emits a
/// per-project `lib/firebase_options.dart`; both entry points pass their own
/// `DefaultFirebaseOptions.currentPlatform`), so within a project every
/// data-layer query site must keep its documented scope: the customer filter
/// on the orders list, the two-doc ordinal read on the waitlist stream
/// (PERF-9 T-2 replaced the branch list-query — the rules DENY that query for
/// customers with 2+ queued users, W1-T7), the branch/user deterministic keys,
/// the bounded global catalog reads, and the order-id-keyed GPS publish with
/// its driver-uid stamp. Removing any of these constants fails THIS test — the
/// behavior itself is rules-pinned in
/// `test/rules/firestore_rules_test.js` (W1-T1..T8, T-E4, b10-T27/T28,
/// b4-T1..T3, b5-T1..T3, t2-T1..T6).
void main() {
  group('P8 W1 query-scope source scan (data layer)', () {
    test('getUserOrders stays customer-scoped (customerId filter present)', () {
      final src = File(
        'lib/features/orders/data/order_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains(".where('customerId', isEqualTo: userId)"),
        isTrue,
        reason:
            'the orders list query must keep its customerId scoping — without '
            'it the client would pull the whole orders collection and rely on '
            'rules alone (W1 bucket: SCOPED-CLIENT)',
      );
    });

    test('streamOrder stays a single-doc read by id (rules-pinned, never a '
        'collection scan)', () {
      final src = File(
        'lib/features/orders/data/order_repository.dart',
      ).readAsStringSync();
      expect(
        RegExp(
          r"\.collection\('orders'\)\s*\.doc\(orderId\)\s*\.snapshots\(\)",
        ).hasMatch(src),
        isTrue,
        reason:
            'streamOrder is the one unfiltered orders read — acceptable ONLY '
            'as an id-addressed doc snapshot (rules:382-394 enforce ownership); '
            'replacing it with a query must re-open the isolation review',
      );
    });

    test(
      'streamQueuePosition is the two-doc T-2 ordinal (no branch list query)',
      () {
        final src = File(
          'lib/features/waitlist/data/waitlist_repository.dart',
        ).readAsStringSync();
        expect(
          src.contains(".where('branchId'"),
          isFalse,
          reason:
              'PERF-9 T-2: the branch-scoped LIST query is DENIED for '
              'customers by the rules the moment another user is queued '
              '(firestore.rules:689-693; pinned by W1-T7), so the position is '
              'computed from two READABLE docs instead — re-introducing a '
              'collection scan re-opens finding B-2',
        );
        expect(
          src.contains('.collection(_metaCollection)'),
          isTrue,
          reason:
              'the ordinal is a single-doc read of '
              'branches/{bid}/waitlist_meta/meta (T-2.4) — the customer path '
              'must never fan out to a query',
        );
      },
    );

    test(
      'waitlist entry key stays deterministic branch_user (idempotent joins)',
      () {
        final src = File(
          'lib/features/waitlist/data/waitlist_repository.dart',
        ).readAsStringSync();
        expect(
          src.contains(r".doc('${branchId}_$userId')"),
          isTrue,
          reason:
              'the {branchId}_{userId} deterministic key is what makes joins '
              'idempotent and self-scoped (B4-8/B4-9)',
        );
      },
    );

    test('reservation counter keys stay branch+slot scoped', () {
      final src = File(
        'lib/features/reservations/data/reservations_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains(
          r"'${reservation.branchId}_${reservation.startTime.millisecondsSinceEpoch}'",
        ),
        isTrue,
        reason:
            'reservation_counters are keyed {branch}_{start} — the branch '
            'scope lives in the key construction (W1 bucket: SCOPED-BRANCH)',
      );
    });

    test('reservation lock keys stay branch+slot+user scoped', () {
      final src = File(
        'lib/features/reservations/data/reservations_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains(
          r"'${reservation.branchId}_${reservation.startTime.millisecondsSinceEpoch}_${reservation.userId}'",
        ),
        isTrue,
        reason:
            'reservation_locks embed the requesting user in the key — '
            'dropping it would let one user collide with another user\u2019s lock',
      );
    });

    test(
      'menu sync stays a bounded global catalog read (safety cap present)',
      () {
        final src = File(
          'lib/features/menu/data/menu_repository.dart',
        ).readAsStringSync();
        expect(
          src.contains("collection('menus').limit(kMenuMaxItemsSafetyCap)"),
          isTrue,
          reason:
              'menus is GLOBAL-BY-DESIGN (rules:198-199 public read) — the '
              'bounded read (Law 20 cap) is part of that verdict, not removable',
        );
      },
    );

    test('locations read stays bounded (kLocationQueryLimit present)', () {
      final src = File(
        'lib/features/locations/data/location_repository.dart',
      ).readAsStringSync();
      expect(src.contains("collection('locations')"), isTrue);
      expect(
        src.contains('limit(kLocationQueryLimit)'),
        isTrue,
        reason:
            'locations is a bounded curated set (B4-4) — GLOBAL-BY-DESIGN '
            'with the cap as part of the contract',
      );
    });

    test('GPS publish stays order-id keyed with the driver-uid stamp', () {
      final src = File(
        'lib/features/tracking/data/driver_location_service.dart',
      ).readAsStringSync();
      expect(
        src.contains("collection('deliveries').doc(_activeOrderId)"),
        isTrue,
        reason:
            'deliveries rows are keyed by orderId and rules-verified against '
            'the assigned driver (rules:555-571) — the write must stay '
            'doc-addressed',
      );
      expect(
        src.contains("if (_driverUid != null) 'driverId': _driverUid"),
        isTrue,
        reason:
            'the MONEY-3 driverId stamp keeps every GPS row GDPR-queryable '
            '(deliveries.where(driverId == uid)) — dropping it breaks erasure',
      );
    });

    test('cart repository stays device-local Isar (no Firestore cart write)', () {
      final src = File(
        'lib/features/cart/data/cart_repository.dart',
      ).readAsStringSync();
      expect(
        src.contains('.collection('),
        isFalse,
        reason:
            'the app-side cart is Isar-local (tenant = the app\u2019s own '
            'on-device sandbox); Firestore carts/{userId} exists for the GDPR '
            'export path — introducing a Firestore cart write here requires '
            'new rules coverage first (zero carts tests existed before W1-T1/T2)',
      );
    });

    test(
      'UI-9 (p19) L6: the platform-order isolation stays by-construction',
      () {
        // The consumer history query filters on customerId == uid (pinned
        // above); the server-side platform ingestion therefore builds a
        // document that carries `orderSource: platform:<id>` and NO customerId
        // at all — the two facts together are the isolation proof.
        final ingestion = File(
          'functions/src/platform_ingestion.ts',
        ).readAsStringSync();
        expect(
          ingestion.contains('buildOrderSource'),
          isTrue,
          reason:
              'every ingested platform order must be stamped with its '
              'platform order-source (L6)',
        );
        expect(
          RegExp('customerId').hasMatch(ingestion),
          isFalse,
          reason:
              'a platform order has no Carnama user id — stamping one would '
              'surface the platform order in that user\u2019s own history',
        );
        expect(
          RegExp("'orderSource'|orderSource:").hasMatch(ingestion),
          isTrue,
          reason: 'the persisted document field is orderSource',
        );
      },
    );
  });
}
