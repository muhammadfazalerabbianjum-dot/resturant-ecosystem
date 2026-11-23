// GENERATED FILE — DO NOT EDIT BY HAND.
// Generator: tool/gen_tenant_isolation_tests.dart
// Sources:   firestore.rules (top-level collections) + test/security/tenant_isolation_cases.json
// Regenerate: cd core_app && dart run tool/gen_tenant_isolation_tests.dart
//
// P0-8: this suite is the machine that will prove tenant isolation. It is
// complete by construction — gate (i) fails when a rules collection has no case
// row. Today 0 of 28 collections are PENDING-TENANCY and skip WITH A
// REASON; flipping a registry row to ACTIVE turns the same three tests into
// real assertions against the emulator: tenant A is denied READ and WRITE on
// tenant B's seeded document, and (when the registry says so) ALLOWED to read
// its own. The allow case is the control that stops a rules typo that denies
// everything from scoring as "tenants are isolated".

@Tags(['needs-emulator'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'tenant_isolation_support.dart';

/// Collections with a real (non-skipped) case today.
const int kActiveCases = 28;

/// Collections whose case skips because tenancy does not exist yet.
const int kPendingCases = 0;

const int kTotalCases = 28;

const List<String> kPendingCollections = <String>[];

void main() {
  // No bootstrap here: `flutter test --tags gate_fast` still LOADS this file
  // (and runs its main) while filtering every test out, so connecting eagerly
  // would make an unrelated gate fail for want of an emulator. The first
  // assertion that actually runs connects instead.
  group('P0-8 cross-tenant isolation (generated)', () {
    test('STATUS — pending collections are named, never silent', () {
      // Loud on purpose: the numbers and the list land in the test log, so a
      // green suite cannot be mistaken for proven tenancy.
      // stderr (not print): analyzer forbids print even in tests, and a silent
      // pending list would defeat the point of the scaffold.
      stderr.writeln(
        'TENANT ISOLATION: $kActiveCases active / $kPendingCases '
        '$kPendingTenancy / $kTotalCases collections',
      );
      if (kPendingCases > 0) {
        stderr.writeln(
          'NO cross-tenant denial is proven yet for: ${kPendingCollections.join(", ")}',
        );
      }
      expect(kActiveCases + kPendingCases, kTotalCases);
      expect(kPendingCollections.length, kPendingCases);
    });

    crossTenantCase(
      collection: 'admins',
      status: 'ACTIVE',
      why:
          'D-038 (card 7): the roster is tenant state. The row uses the owner principal (a customer token is denied by role, which would prove nothing about tenant scope) and asserts that owner A is denied tenant B\'s rows while still reading its own.',
      readPath: 'admins/{id}',
      writePath: 'admins/{id}',
      readDocId: 'iso_b_admins',
      writeDocId: 'iso_b_admins_write',
      allowDocId: 'iso_allow_admins',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
      principal: 'owner-a',
    );

    crossTenantCase(
      collection: 'analyticsEvents',
      status: 'ACTIVE',
      why:
          'ACTIVE: analytics read/writes are tenant-scoped. No allow control: read is owner/manager only, and the suite has no admin principal.',
      readPath: 'analyticsEvents/{id}',
      writePath: 'analyticsEvents/{id}',
      readDocId: 'iso_b_analyticsEvents',
      writeDocId: 'iso_bw_analyticsEvents',
      allowDocId: '',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'none',
      sameTenantWhy:
          'Read is owner/manager only; the suite has no admin principal for tenant A.',
    );

    crossTenantCase(
      collection: 'audit_log',
      status: 'ACTIVE',
      why:
          'D-038 (card 7): the audit log is tenant state, readable by the owner only. Probed with the owner principal: tenant A\'s owner reads its own entries and is denied tenant B\'s; writes are denied to everyone (Admin SDK only).',
      readPath: 'audit_log/{id}',
      writePath: 'audit_log/{id}',
      readDocId: 'iso_b_audit_log',
      writeDocId: 'iso_b_audit_log_write',
      allowDocId: 'iso_allow_audit_log',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
      principal: 'owner-a',
    );

    crossTenantCase(
      collection: 'audit_logs',
      status: 'ACTIVE',
      why:
          'D-038 (card 7): same contract as audit_log — owner-readable within the tenant, never writable from a client.',
      readPath: 'audit_logs/{id}',
      writePath: 'audit_logs/{id}',
      readDocId: 'iso_b_audit_logs',
      writeDocId: 'iso_b_audit_logs_write',
      allowDocId: 'iso_allow_audit_logs',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
      principal: 'owner-a',
    );

    crossTenantCase(
      collection: 'branches',
      status: 'ACTIVE',
      why:
          'ACTIVE: a branch is read only inside the caller\'s tenant (guest boot included) and written by the tenant owner; tenant A still reads its own branch.',
      readPath: 'branches/{id}',
      writePath: 'branches/{id}',
      readDocId: 'iso_b_branches',
      writeDocId: 'iso_bw_branches',
      allowDocId: 'iso_a_branches',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'Public branch read survives tenancy: a guest of the same tenant still needs it to open the app.',
    );

    crossTenantCase(
      collection: 'carts',
      status: 'ACTIVE',
      why:
          'ACTIVE: a cart is self-keyed and tenant-scoped; tenant A reads its own cart.',
      readPath: 'carts/{id}',
      writePath: 'carts/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'carts/{uid} is self-read; tenant A reads its own cart by uid.',
    );

    crossTenantCase(
      collection: 'deletion_requests',
      status: 'ACTIVE',
      why: 'ACTIVE: an erasure marker is self-keyed and tenant-scoped.',
      readPath: 'deletion_requests/{id}',
      writePath: 'deletion_requests/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'deletion_requests/{uid} is self-read; tenant A reads its own erasure marker.',
    );

    crossTenantCase(
      collection: 'deliveries',
      status: 'ACTIVE',
      why:
          'D-047 (card 8): the delivery document cannot carry a tenantId — the driver GPS ping is hasOnly-shaped and replaces the document — so the rule scopes it through the ORDER it belongs to (the same document it already reads for assignedDriverId). Reads are asserted with the owner principal; the write denial happens by ROLE first, which is stated here rather than counted as tenant proof.',
      readPath: 'deliveries/{id}',
      writePath: 'deliveries/{id}',
      readDocId: 'iso_b_deliveries',
      writeDocId: 'iso_b_deliveries_write',
      allowDocId: 'iso_allow_deliveries',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
      principal: 'owner-a',
    );

    crossTenantCase(
      collection: 'driverLocations',
      status: 'ACTIVE',
      why:
          'ACTIVE: a driver location is self-keyed (driverId == uid) and tenant-scoped.',
      readPath: 'driverLocations/{id}',
      writePath: 'driverLocations/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'driverLocations/{driverId} is self-read for the driver; tenant A reads its own location doc.',
    );

    crossTenantCase(
      collection: 'locations',
      status: 'ACTIVE',
      why:
          'ACTIVE: locations read and writes are tenant-scoped; tenant A reads its own location doc.',
      readPath: 'locations/{id}',
      writePath: 'locations/{id}',
      readDocId: 'iso_b_locations',
      writeDocId: 'iso_bw_locations',
      allowDocId: 'iso_a_locations',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'locations is app-verified read for any signed-in user.',
    );

    crossTenantCase(
      collection: 'loyalty',
      status: 'ACTIVE',
      why: 'ACTIVE: a loyalty ledger is self-keyed and tenant-scoped.',
      readPath: 'loyalty/{id}',
      writePath: 'loyalty/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'loyalty/{uid} is self-read.',
    );

    crossTenantCase(
      collection: 'menus',
      status: 'ACTIVE',
      why:
          'ACTIVE: menus read is tenantOk() and the probe seeds both tenants at registry ids, so a leak and a lockdown both fail.',
      readPath: 'menus/{id}',
      writePath: 'menus/{id}',
      readDocId: 'iso_b_menus',
      writeDocId: 'iso_bw_menus',
      allowDocId: 'iso_a_menus',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'The guest-boot menu read is the path design 1 puts at risk; this is the primary positive control.',
    );

    crossTenantCase(
      collection: 'notification_queue',
      status: 'ACTIVE',
      why:
          'ACTIVE: owner/manager readability and owner writes, tenant-scoped. No allow control by design (queue writes are owner-only).',
      readPath: 'notification_queue/{id}',
      writePath: 'notification_queue/{id}',
      readDocId: 'iso_b_notification_queue',
      writeDocId: 'iso_bw_notification_queue',
      allowDocId: '',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'none',
      sameTenantWhy:
          'Owner/manager only; no tenant-scoped principal for tenant A in the suite.',
    );

    crossTenantCase(
      collection: 'notifications',
      status: 'ACTIVE',
      why:
          'ACTIVE: a mailbox is self-keyed and tenant-scoped; its items subcollection carries the same clauses.',
      readPath: 'notifications/{id}',
      writePath: 'notifications/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'notifications/{uid} is self-read (own mailbox).',
    );

    crossTenantCase(
      collection: 'orders',
      status: 'ACTIVE',
      why:
          'ACTIVE: order read, create and update are tenant-scoped. The create case is two-sided (D-039): a tenant-A create must succeed and the same body stamped with tenant B must be denied.',
      readPath: 'orders/{id}',
      writePath: 'orders/{id}',
      readDocId: 'iso_b_orders',
      writeDocId: 'iso_bw_orders',
      allowDocId: 'iso_a_orders',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson:
          '{"branchId":"iso_branch","createdAt":"2026-01-01T00:00:00.000","customerId":"{uid}","deliveryFeeCents":0,"discountCents":0,"id":"iso_create_orders_a","items":[],"offlineQueued":true,"orderNumber":"ISO-1","queuedAt":"2026-01-01T00:00:00.000","status":"pending","taxCents":100,"tipCents":0,"totalCents":1500,"updatedAt":"2026-01-01T00:00:00.000"}',
      createDocId: 'iso_create_orders_a',
      sameTenant: 'allow',
      sameTenantWhy:
          'An order is readable by its own customer (customerId == uid).',
    );

    crossTenantCase(
      collection: 'presence',
      status: 'ACTIVE',
      why:
          'ACTIVE: presence is staff-only and tenant-scoped. No allow control: a customer cannot read presence.',
      readPath: 'presence/{id}',
      writePath: 'presence/{id}',
      readDocId: 'iso_b_presence',
      writeDocId: 'iso_bw_presence',
      allowDocId: '',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'none',
      sameTenantWhy:
          'Staff read only (owner, or manager/kitchen/delivery scoped to a branch).',
    );

    crossTenantCase(
      collection: 'promoCodes',
      status: 'ACTIVE',
      why:
          'ACTIVE: owner/manager readability and owner writes, tenant-scoped. No allow control by design (no tenant-scoped readable principal below owner/manager).',
      readPath: 'promoCodes/{id}',
      writePath: 'promoCodes/{id}',
      readDocId: 'iso_b_promoCodes',
      writeDocId: 'iso_bw_promoCodes',
      allowDocId: '',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'none',
      sameTenantWhy:
          'Read is owner/manager only by design (customers validate through the callable).',
    );

    crossTenantCase(
      collection: 'promo_usage',
      status: 'ACTIVE',
      why: 'ACTIVE: promo usage is self-read by userId and tenant-scoped.',
      readPath: 'promo_usage/{id}',
      writePath: 'promo_usage/{id}',
      readDocId: 'iso_b_promo_usage',
      writeDocId: 'iso_bw_promo_usage',
      allowDocId: 'iso_a_promo_usage',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'promo_usage is self-read by userId.',
    );

    crossTenantCase(
      collection: 'promotions',
      status: 'ACTIVE',
      why:
          'ACTIVE: promotions read is tenantOk() and the probe seeds both tenants; tenant A still reads its own banner.',
      readPath: 'promotions/{id}',
      writePath: 'promotions/{id}',
      readDocId: 'iso_b_promotions',
      writeDocId: 'iso_bw_promotions',
      allowDocId: 'iso_a_promotions',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'Public promotions read survives tenancy.',
    );

    crossTenantCase(
      collection: 'proof_of_delivery',
      status: 'ACTIVE',
      why:
          'D-047 (card 8): proof is scoped through the order named in its orderId field. Owner reads carry the tenant-scoped assertions; writes are driver-only, so the write denial is by role before tenancy is consulted.',
      readPath: 'proof_of_delivery/{id}',
      writePath: 'proof_of_delivery/{id}',
      readDocId: 'iso_b_proof',
      writeDocId: 'iso_b_proof_write',
      allowDocId: 'iso_allow_proof',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
      principal: 'owner-a',
    );

    crossTenantCase(
      collection: 'reservation_counters',
      status: 'ACTIVE',
      why:
          'ACTIVE: a counter is readable to the tenant and tenant-scoped on read, create and update; delete stays denied outright.',
      readPath: 'reservation_counters/{id}',
      writePath: 'reservation_counters/{id}',
      readDocId: 'iso_b_reservation_counters',
      writeDocId: 'iso_bw_reservation_counters',
      allowDocId: 'iso_a_reservation_counters',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'Booking counters are read inside the reservation transaction by any app-verified user.',
    );

    crossTenantCase(
      collection: 'reservation_locks',
      status: 'ACTIVE',
      why: 'ACTIVE: a lock is readable by its holder and tenant-scoped.',
      readPath: 'reservation_locks/{id}',
      writePath: 'reservation_locks/{id}',
      readDocId: 'iso_b_reservation_locks',
      writeDocId: 'iso_bw_reservation_locks',
      allowDocId: 'iso_a_reservation_locks',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'A lock is readable by the user who holds it.',
    );

    crossTenantCase(
      collection: 'reservations',
      status: 'ACTIVE',
      why:
          'ACTIVE: reservation read, create, update and delete are tenant-scoped. The create case is two-sided (D-039): a tenant-A booking must succeed and the same body stamped tenant B must be denied.',
      readPath: 'reservations/{id}',
      writePath: 'reservations/{id}',
      readDocId: 'iso_b_reservations',
      writeDocId: 'iso_bw_reservations',
      allowDocId: 'iso_a_reservations',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson:
          '{"branchId":"iso_branch","customerName":"ISO Guest","customerPhone":"5550000","notes":"","partySize":2,"startTime":"2026-01-01T18:00:00.000Z","userId":"{uid}"}',
      createDocId: 'iso_create_reservations_a',
      sameTenant: 'allow',
      sameTenantWhy:
          'A reservation is readable by the user who made it (userId == uid).',
    );

    crossTenantCase(
      collection: 'settings',
      status: 'ACTIVE',
      why:
          'D-038 (card 7): settings documents are keyed by tenant and name (tenantId_name), so the rule can require the document id to start with the caller tenant. The three literal rows the 5a parser registered (restaurantConfig, taxRates, defaultOperatingHours) are gone: those blocks no longer exist separately, this one block covers them.',
      readPath: 'settings/{id}',
      writePath: 'settings/{id}',
      readDocId: 'tenant_b_iso_settings',
      writeDocId: 'tenant_b_iso_bw_settings',
      allowDocId: 'tenant_a_iso_settings',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: '',
    );

    crossTenantCase(
      collection: 'transactions',
      status: 'ACTIVE',
      why:
          'ACTIVE: the ledger read is owner-only AND tenant-scoped. No allow control: no tenant-scoped principal can read it.',
      readPath: 'transactions/{id}',
      writePath: 'transactions/{id}',
      readDocId: 'iso_b_transactions',
      writeDocId: 'iso_bw_transactions',
      allowDocId: '',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'none',
      sameTenantWhy:
          'The ledger is owner-only read and server-only write; a tenant-scoped tenant A principal cannot read it.',
    );

    crossTenantCase(
      collection: 'users',
      status: 'ACTIVE',
      why:
          'ACTIVE: a user document is readable by its owner and tenant-scoped; tenant A reads its own profile.',
      readPath: 'users/{id}',
      writePath: 'users/{id}',
      readDocId: '{uid_b}',
      writeDocId: '{uid_b}',
      allowDocId: '{uid}',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy: 'users/{uid} is self-read.',
    );

    crossTenantCase(
      collection: 'waitlist',
      status: 'ACTIVE',
      why:
          'ACTIVE: a waitlist entry is readable by the queued user and tenant-scoped.',
      readPath: 'waitlist/{id}',
      writePath: 'waitlist/{id}',
      readDocId: 'iso_b_waitlist',
      writeDocId: 'iso_bw_waitlist',
      allowDocId: 'iso_a_waitlist',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'A waitlist entry is readable by the user queued (userId == uid).',
    );

    crossTenantCase(
      collection: 'waitlist_counters',
      status: 'ACTIVE',
      why:
          'ACTIVE: a counter is readable to the tenant and tenant-scoped on read, create and update; delete stays denied outright.',
      readPath: 'waitlist_counters/{id}',
      writePath: 'waitlist_counters/{id}',
      readDocId: 'iso_b_waitlist_counters',
      writeDocId: 'iso_bw_waitlist_counters',
      allowDocId: 'iso_a_waitlist_counters',
      parentDocId: '',
      allowParentDocId: '',
      createBodyJson: '',
      createDocId: '',
      sameTenant: 'allow',
      sameTenantWhy:
          'Waitlist counters are read inside joinWaitlist by any app-verified user.',
    );
  });
}
