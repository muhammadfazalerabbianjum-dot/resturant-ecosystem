/**
 * Firestore Security Rules Test Harness — Carnama Constitution (Law 30)
 *
 * TDD-first (Law 2): These tests must FAIL against the current firestore.rules
 * and PASS after the verified fixes are applied.
 *
 * Run with: firebase emulators:exec "node core_app/test/rules/firestore_rules_test.js"
 */
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

// ── Load the rules file ────────────────────────────────────────────────
// T-1 (p29): RULES_PATH env var lets the SAME battery run against
// staging.firestore.rules (Law-18 parity check). Default = prod rules.
const RULES_PATH = process.env.RULES_PATH
  ? path.resolve(process.env.RULES_PATH)
  : path.join(__dirname, '..', '..', 'firestore.rules');
const rules = fs.readFileSync(RULES_PATH, 'utf8');

// ── Test environment ───────────────────────────────────────────────────
let testEnv;

// Helper: create an authenticated app context with a custom token
// B6-5: `options.appId` / `options.appCheckToken` let tests exercise the
// `isAppVerified()` OR-gap (relaxed) and the AND (strict) states.
function authedApp(uid, email, role, branchId, options = {}) {
  const { appId, appCheckToken, tenantId = 'tenant_a' } = {
    appId: true, appCheckToken: true, ...options,
  };
  const token = {
    sub: uid,
    email,
    firebase: {
      sign_in_provider: 'password',
    },
  };
  if (appId) token.app_id = 'test-app-id';
  if (appCheckToken) token.firebase.app_check_token = 'test-app-check-token';
  if (tenantId) token.tenantId = tenantId;
  if (role) token.role = role;
  if (branchId) token.branchId = branchId;
  return testEnv.authenticatedContext(uid, token);
}

// Helper: anonymous app context
function anonApp() {
  return testEnv.authenticatedContext('anon-user', {
    sub: 'anon-user',
    firebase: { sign_in_provider: 'anonymous' },
  });
}

// Helper: unauthenticated app context
function unauthedApp() {
  return testEnv.unauthenticatedContext();
}

// ── Seed data ──────────────────────────────────────────────────────────
async function seed() {
  // Use withSecurityRulesDisabled to seed data bypassing rules (Admin SDK equivalent)
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    // settings/tenant_a_ownerInfo — required for isOwner()
    await admin.firestore().doc('settings/tenant_a_ownerInfo').set({
      ownerEmail: 'owner@carnama.com',
    });
    // D-038: isOwner() resolves THIS tenant's owner document. The login helper
    // stamps tenant_a by default, so that is the document the owner tests need.
    await admin.firestore().doc('settings/tenant_a_ownerInfo').set({
      ownerEmail: 'owner@carnama.com',
      tenantId: 'tenant_a',
    });

    // settings/featureFlags — public
    await admin.firestore().doc('settings/featureFlags').set({
      liveTracking: true,
      reservations: true,
    });

    // users — owner, manager, kitchen, delivery, customer
    await admin.firestore().doc('users/owner-uid').set({
      email: 'owner@carnama.com',
      role: 'owner',
      branchId: '',
    });
    await admin.firestore().doc('users/manager-uid').set({
      email: 'manager@carnama.com',
      role: 'manager',
      branchId: 'branch-1',
    });
    await admin.firestore().doc('users/kitchen-uid').set({
      email: 'kitchen@carnama.com',
      role: 'kitchen',
      branchId: 'branch-1',
    });
    await admin.firestore().doc('users/driver-uid').set({
      email: 'driver@carnama.com',
      role: 'delivery',
      branchId: 'branch-1',
    });
    await admin.firestore().doc('users/customer-uid').set({
      email: 'customer@carnama.com',
      role: 'customer',
      branchId: '',
    });
    // Separate customer for T21 (not mutated by T7's role change)
    await admin.firestore().doc('users/customer2-uid').set({
      email: 'customer2@carnama.com',
      role: 'customer',
      branchId: '',
    });

    // menus — one item in branch-1
    await admin.firestore().doc('menus/item-1').set({
      name: 'Burger',
      priceCents: 1000,
      branchId: 'branch-1',
    });

    // orders — confirmed order in branch-1 assigned to driver-uid
    await admin.firestore().doc('orders/order-1').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'confirmed',
      totalCents: 2500,
      assignedDriverId: 'driver-uid',
      items: [],
      createdAt: new Date(),
    });

    // orders — ready order in branch-1 assigned to driver-uid
    await admin.firestore().doc('orders/order-2').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'ready',
      totalCents: 3000,
      assignedDriverId: 'driver-uid',
      items: [],
      createdAt: new Date(),
    });

    // reservation_locks — customer-uid's lock + another user's lock
    await admin.firestore().doc('reservation_locks/lock-1').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      slot: '2026-08-21T19:00:00',
      expiresAt: new Date(),
    });
    await admin.firestore().doc('reservation_locks/other-lock').set({
        tenantId: 'tenant_a',
      userId: 'other-user-uid',
      slot: '2026-08-21T20:00:00',
      expiresAt: new Date(),
    });

    // reservations — one owned by customer-uid (GDPR own-read via userId key).
    // NOTE: distinct id from T22/T23 (they create reservations/res-1 and res-2
    // through the rules engine, which must remain CREATE operations).
    await admin.firestore().doc('reservations/seed-res-1').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      branchId: 'branch-1',
      customerName: 'Test',
      customerPhone: '123',
      startTime: new Date(),
      partySize: 2,
    });

    // promoCodes — one code
    await admin.firestore().doc('promoCodes/SAVE10').set({
      code: 'SAVE10',
      discountCents: 1000,
    });

    // waitlist — one owned by customer-uid + one for another user
    // (B8-6: enables the GDPR own-list verification path)
    await admin.firestore().doc('waitlist/wl-1').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      branchId: 'branch-1',
      partySize: 2,
      createdAt: new Date(),
    });
    await admin.firestore().doc('waitlist/wl-other').set({
        tenantId: 'tenant_a',
      userId: 'other-user-uid',
      branchId: 'branch-1',
      partySize: 2,
      createdAt: new Date(),
    });

    // promo_usage — one owned by customer-uid + one for another user
    await admin.firestore().doc('promo_usage/pu-1').set({
      userId: 'customer-uid',
      code: 'SAVE10',
    });
    await admin.firestore().doc('promo_usage/pu-other').set({
      userId: 'other-user-uid',
      code: 'SAVE10',
    });

    // ── b10 RULES-1 seeds: loyalty (CF shape) + presence ────────────────────
    // loyalty writer = Admin-SDK CF (functions/src/index.ts:1449-1458):
    // {userId, totalPoints, updatedAt}.
    await admin.firestore().doc('loyalty/customer-uid').set({
      userId: 'customer-uid',
      totalPoints: 120,
      updatedAt: new Date(),
    });
    // presence writer = presence_service.dart:37-49:
    // {isOnline, lastSeen, branchId, role}.
    await admin.firestore().doc('presence/manager-uid').set({
      isOnline: true,
      lastSeen: new Date(),
      branchId: 'branch-1',
      role: 'manager',
    });

    // ── B0 seeds (P0-1/P0-2/P0-3 producer collections) ─────────────────────
    // reservation_counters/{branch}_{start} — exactly what
    // reservations_repository.dart:18-22/51-55 writes (merge-set `{booked: int}`).
    await admin.firestore().doc('reservation_counters/branch-1_1700000000000').set({
        tenantId: 'tenant_a',
      booked: 4,
    });
    // waitlist_counters/{branchId} — exactly what waitlist_repository.dart:49-52/80-87
    // writes (merge-set `{count: int, updatedAt: timestamp}`).
    await admin.firestore().doc('waitlist_counters/branch-1').set({
        tenantId: 'tenant_a',
      count: 2,
      updatedAt: new Date(),
    });
    // locations/{id} — readable shape per location_model.dart/LatLngParse.
    await admin.firestore().doc('locations/branch-1').set({
      name: 'Branch 1',
      address: '1 Main St',
      openHours: '9am - 10pm',
      lat: 24.86,
      lng: 67.0,
    });
    // settings/tenant_a_restaurantConfig + settings/tenant_a_defaultOperatingHours — the config
    // family (restaurant_config_service.dart:7-20, operating_hours_screen.dart:33).
    await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
      restaurantName: 'Carnama',
      currency: 'USD',
      pointsPerDollar: 10,
      ordersAccepting: true,
    });
    await admin.firestore().doc('settings/tenant_a_defaultOperatingHours').set({
      monday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      tuesday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      wednesday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      thursday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      friday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      saturday: { isOpen: true, openTime: '10:00', closeTime: '23:00' },
      sunday: { isOpen: true, openTime: '10:00', closeTime: '21:00' },
      holidayModeEnabled: false,
    });

    // settings/tenant_a_restaurantConfig + defaultOperatingHours — the config family.
    // ── B3 P4 seeds: demo collections (notifications / notification_queue / audit_logs)
    await admin.firestore().doc('notifications/customer-uid').set({
      lastNotificationAt: new Date(),
    });
    await admin.firestore().doc('notifications/customer-uid/items/i1').set({
      title: 'Welcome',
      isRead: false,
      createdAt: new Date(),
    });
    await admin.firestore().doc('notification_queue/q1').set({
      targetUid: 'customer-uid',
      title: 'Your order is ready',
      createdAt: new Date(),
    });
    await admin.firestore().doc('audit_logs/a1').set({
      tenantId: 'tenant_a',
      action: 'MENU_MODIFY',
      actorUid: 'owner-uid',
      timestamp: new Date(),
    });
  });
}

// ── Test matrix ────────────────────────────────────────────────────────
async function runTests() {
  let passed = 0;
  let failed = 0;
  const results = [];

  function record(name, ok, detail) {
    if (ok) {
      passed++;
      results.push(`  ✅ ${name}`);
    } else {
      failed++;
      results.push(`  ❌ ${name} — ${detail}`);
    }
  }

  // ── T1: Unauthenticated read of users/abc → DENY ────────────────────
  try {
    const db = unauthedApp().firestore();
    await assertFails(db.doc('users/abc').get());
    record('T1: Unauthenticated read users/abc → DENY', true);
  } catch (e) {
    record('T1: Unauthenticated read users/abc → DENY', false, e.message);
  }

  // ── T2: Unauthenticated read of menus/x → ALLOW (public guest mode) ──
  try {
    const db = unauthedApp().firestore();
    await assertSucceeds(db.doc('menus/x').get());
    record('T2: Unauthenticated read menus/x → ALLOW', true);
  } catch (e) {
    record('T2: Unauthenticated read menus/x → ALLOW', false, e.message);
  }

  // ── T3: Unauthenticated write of menus/x → DENY ─────────────────────
  try {
    const db = unauthedApp().firestore();
    await assertFails(db.doc('menus/x').set({ name: 'Hack', priceCents: 0 }));
    record('T3: Unauthenticated write menus/x → DENY', true);
  } catch (e) {
    record('T3: Unauthenticated write menus/x → DENY', false, e.message);
  }

  // ── T4: Self-register with role:'owner' + e2e email → DENY (C-1) ────
  try {
    const db = authedApp('new-owner', 'e2e_foo@example.com', 'owner').firestore();
    await assertFails(db.doc('users/new-owner').set({
      email: 'e2e_foo@example.com',
      role: 'owner',
    }));
    record('T4: Self-register role:owner + e2e email → DENY', true);
  } catch (e) {
    record('T4: Self-register role:owner + e2e email → DENY', false, e.message);
  }

  // ── T5: Self-register with role:'customer' → ALLOW (C-1) ────────────
  try {
    const db = authedApp('new-customer', 'new@example.com', 'customer').firestore();
    await assertSucceeds(db.doc('users/new-customer').set({
      email: 'new@example.com',
      role: 'customer',
    }));
    record('T5: Self-register role:customer → ALLOW', true);
  } catch (e) {
    record('T5: Self-register role:customer → ALLOW', false, e.message);
  }

  // ── T6: User updates own role → DENY (anti-self-demotion) ───────────
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('users/customer-uid').update({ role: 'owner' }));
    record('T6: User updates own role → DENY', true);
  } catch (e) {
    record('T6: User updates own role → DENY', false, e.message);
  }

  // ── T7: Owner updates another user's role to manager → ALLOW ────────
  // B8-4: this case no longer mutates the shared seed (`customer-uid`). It
  // creates a FRESH document, exercises the role change, then deletes it so no
  // later test observes the mutated role.
  const t7Target = 'users/t7-target-uid';
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(
      db.doc(t7Target).set({ email: 't7@example.com', role: 'customer' }),
    );
    await assertSucceeds(db.doc(t7Target).update({ role: 'manager' }));
    record('T7: owner updates a FRESH user role → ALLOW', true);
  } catch (e) {
    record('T7: owner updates a FRESH user role → ALLOW', false, e.message);
  } finally {
    await testEnv.withSecurityRulesDisabled((admin) =>
      admin.firestore().doc(t7Target).delete(),
    );
  }

  // ── T8: Kitchen writes order {status:'ready'} on own-branch confirmed → ALLOW (C-2)
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/order-1').update({ status: 'ready' }));
    record('T8: Kitchen status:ready on confirmed → ALLOW', true);
  } catch (e) {
    record('T8: Kitchen status:ready on confirmed → ALLOW', false, e.message);
  }

  // ── T9: Kitchen writes order {status:'ready', totalCents:0} → DENY (C-2 field lock)
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('orders/order-1').update({ status: 'ready', totalCents: 0 }));
    record('T9: Kitchen status:ready + totalCents:0 → DENY', true);
  } catch (e) {
    record('T9: Kitchen status:ready + totalCents:0 → DENY', false, e.message);
  }

  // ── T10: Assigned driver writes order {status:'pickedUp'} → ALLOW (C-2 + camelCase)
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/order-2').update({ status: 'pickedUp' }));
    record('T10: Driver status:pickedUp → ALLOW', true);
  } catch (e) {
    record('T10: Driver status:pickedUp → ALLOW', false, e.message);
  }

  // ── T11: Assigned driver writes order {status:'pickedUp', items:[...]} → DENY (C-2 field lock)
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    // Use a DIFFERENT items value so the diff registers (items:[] == existing items:[])
    await assertFails(db.doc('orders/order-2').update({
      status: 'pickedUp',
      items: [{ id: 'hack', name: 'Hacked', priceCents: 0, quantity: 1 }],
    }));
    record('T11: Driver status:pickedUp + items changed → DENY', true);
  } catch (e) {
    record('T11: Driver status:pickedUp + items changed → DENY', false, e.message);
  }

  // ── P2-1 (D-061): the OWNER branch is key-locked too. Before this, owner was
  // the one role on `orders` with no `affectedKeys().hasOnly(...)`, so an
  // owner-claimed client could rewrite an order's money after the ledger's
  // immutable sale_ row had stated it. These three assertions are the
  // behavioural half of `test/rules/order_update_payload_contract_test.dart`.
  //
  // They run on a DEDICATED probe order: an earlier draft reused `orders/
  // order-2`, and moving its status broke `t78-CTL1` (the deliveries control
  // reads the order it names), which is exactly the kind of coupling a rules
  // battery must not have.
  const ownProbe = 'orders/p2-01-owner-probe';
  await testEnv.withSecurityRulesDisabled((admin) =>
    admin.firestore().doc(ownProbe).set({
      tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'confirmed',
      totalCents: 2500,
      items: [],
      createdAt: new Date(),
    }),
  );

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', 'branch-1').firestore();
    await assertSucceeds(db.doc(ownProbe).update({ status: 'preparing' }));
    record('OWN1: Owner status-only update → ALLOW', true);
  } catch (e) {
    record('OWN1: Owner status-only update → ALLOW', false, e.message);
  }

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', 'branch-1').firestore();
    await assertFails(db.doc(ownProbe).update({ totalCents: 1 }));
    record('OWN2: Owner rewrites totalCents → DENY', true);
  } catch (e) {
    record('OWN2: Owner rewrites totalCents → DENY', false, e.message);
  }

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', 'branch-1').firestore();
    await assertFails(db.doc(ownProbe).update({
      status: 'ready',
      paymentMethod: 'cash',
      changeCents: 0,
    }));
    record('OWN3: Owner writes paymentMethod/changeCents → DENY', true);
  } catch (e) {
    record('OWN3: Owner writes paymentMethod/changeCents → DENY', false, e.message);
  }

  await testEnv.withSecurityRulesDisabled((admin) =>
    admin.firestore().doc(ownProbe).delete(),
  );

  // ── T12: An unassigned non-driver writes deliveries/{orderId} → DENY (W-1)
  // B8-4: the old test targeted a NON-EXISTENT order (`deliveries/unassigned-order`),
  // which rules deny simply because the `get(orders/...)` doc is absent — it
  // proved nothing about the assigned-driver ownership rule. This version seeds
  // an order that EXISTS but has NO `assignedDriverId`, then asserts a driver
  // write is DENIED by the ownership rule, not by a missing document.
  const t12Order = 't12-unassigned-order';
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc(`orders/${t12Order}`).set({
        customerId: 'customer-uid',
        branchId: 'branch-1',
        status: 'confirmed',
        totalCents: 1000,
        items: [],
      });
    });
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc(`deliveries/${t12Order}`).set({
      lat: 1.0, lng: 2.0, heading: 0, speed: 0, timestamp: new Date(),
    }));
    record('T12: unassigned driver writes deliveries of existing-but-unassigned order → DENY', true);
  } catch (e) {
    record('T12: unassigned driver writes deliveries of existing-but-unassigned order → DENY', false, e.message);
  } finally {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc(`orders/${t12Order}`).delete();
    });
  }

  // ── T13: Assigned driver writes deliveries/{orderId} valid shape → ALLOW (W-1)
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('deliveries/order-1').set({
      lat: 1.0, lng: 2.0, heading: 90, speed: 5.5, timestamp: new Date(),
    }));
    record('T13: Assigned driver writes deliveries valid → ALLOW', true);
  } catch (e) {
    record('T13: Assigned driver writes deliveries valid → ALLOW', false, e.message);
  }

  // ── T14: Assigned driver writes deliveries/{orderId} with extra field → DENY (W-1 shape lock)
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('deliveries/order-1').set({
      lat: 1.0, lng: 2.0, heading: 90, speed: 5.5, timestamp: new Date(), extra: 'hack',
    }));
    record('T14: Assigned driver writes deliveries extra field → DENY', true);
  } catch (e) {
    record('T14: Assigned driver writes deliveries extra field → DENY', false, e.message);
  }

  // ── Card 8 (D-047): deliveries and proof_of_delivery inherit the ORDER's
  // tenant. The delivery document cannot carry a tenantId (the driver's GPS
  // ping is hasOnly-shaped and replaces the document), so the only durable
  // tenant link is the order both rules already read.
  {
    const foreignOrder = 'c8-foreign-order';
    const ownOrder = 'c8-own-order';
    const foreignPod = 'c8-foreign-pod';
    const ownPod = 'c8-own-pod';
    try {
      await testEnv.withSecurityRulesDisabled(async (admin) => {
        await admin.firestore().doc(`orders/${foreignOrder}`).set({
          tenantId: 'tenant_b', customerId: 'other-customer', branchId: 'branch-b',
          status: 'confirmed', totalCents: 100, items: [],
          assignedDriverId: 'driver-b',
        });
        await admin.firestore().doc(`orders/${ownOrder}`).set({
          tenantId: 'tenant_a', customerId: 'customer-uid', branchId: 'branch-1',
          status: 'confirmed', totalCents: 100, items: [],
          assignedDriverId: 'driver-uid',
        });
        await admin.firestore().doc(`deliveries/${foreignOrder}`).set({
          lat: 1.0, lng: 2.0, driverId: 'driver-b',
        });
        await admin.firestore().doc(`deliveries/${ownOrder}`).set({
          lat: 1.0, lng: 2.0, driverId: 'driver-uid',
        });
        await admin.firestore().doc(`proof_of_delivery/${foreignPod}`).set({
          orderId: foreignOrder, driverId: 'driver-b',
        });
        await admin.firestore().doc(`proof_of_delivery/${ownPod}`).set({
          orderId: ownOrder, driverId: 'driver-uid',
        });
      });

      const ownerA = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
      await assertFails(ownerA.doc(`deliveries/${foreignOrder}`).get());
      record('c8-T1: owner reads a delivery whose order belongs to another tenant → DENY', true);
    } catch (e) {
      record('c8-T1: owner reads a delivery whose order belongs to another tenant → DENY', false, e.message);
    }

    try {
      const ownerA = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
      await assertSucceeds(ownerA.doc(`deliveries/${ownOrder}`).get());
      record('c8-T2: owner reads a delivery of its own tenant → ALLOW (control)', true);
    } catch (e) {
      record('c8-T2: owner reads a delivery of its own tenant → ALLOW (control)', false, e.message);
    }

    try {
      const ownerA = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
      await assertFails(ownerA.doc(`proof_of_delivery/${foreignPod}`).get());
      record('c8-T3: owner reads proof for another tenant order → DENY', true);
    } catch (e) {
      record('c8-T3: owner reads proof for another tenant order → DENY', false, e.message);
    }

    try {
      const ownerA = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
      await assertSucceeds(ownerA.doc(`proof_of_delivery/${ownPod}`).get());
      record('c8-T4: owner reads proof for its own tenant order → ALLOW (control)', true);
    } catch (e) {
      record('c8-T4: owner reads proof for its own tenant order → ALLOW (control)', false, e.message);
    }

    try {
      const driverA = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
      await assertFails(driverA.doc(`deliveries/${foreignOrder}`).set({
        lat: 3.0, lng: 4.0, heading: 0, speed: 0, timestamp: new Date(),
      }));
      record('c8-T5: driver writes a delivery whose order belongs to another tenant → DENY', true);
    } catch (e) {
      record('c8-T5: driver writes a delivery whose order belongs to another tenant → DENY', false, e.message);
    }

    try {
      const driverA = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
      await assertSucceeds(driverA.doc(`deliveries/${ownOrder}`).set({
        lat: 3.0, lng: 4.0, heading: 0, speed: 0, timestamp: new Date(),
      }));
      record('c8-T6: assigned driver writes its own tenant delivery → ALLOW (control)', true);
    } catch (e) {
      record('c8-T6: assigned driver writes its own tenant delivery → ALLOW (control)', false, e.message);
    }

    try {
      const driverA = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
      await assertFails(driverA.doc(`proof_of_delivery/${foreignPod}`).update({
        note: 'x',
      }));
      record('c8-T7: driver updates proof for another tenant order → DENY', true);
    } catch (e) {
      record('c8-T7: driver updates proof for another tenant order → DENY', false, e.message);
    }

    try {
      await testEnv.withSecurityRulesDisabled(async (admin) => {
        await admin.firestore().doc(`orders/${foreignOrder}`).delete();
        await admin.firestore().doc(`orders/${ownOrder}`).delete();
        await admin.firestore().doc(`deliveries/${foreignOrder}`).delete();
        await admin.firestore().doc(`deliveries/${ownOrder}`).delete();
        await admin.firestore().doc(`proof_of_delivery/${foreignPod}`).delete();
        await admin.firestore().doc(`proof_of_delivery/${ownPod}`).delete();
      });
      record('c8-T8: fixture cleanup → no residue for later assertions', true);
    } catch (e) {
      record('c8-T8: fixture cleanup → no residue for later assertions', false, e.message);
    }
  }

  // ── T15: Manager updates menus/x.branchId on own-branch item → DENY (C-3 immutability)
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertFails(db.doc('menus/item-1').update({ branchId: 'branch-2' }));
    record('T15: Manager updates menus branchId → DENY', true);
  } catch (e) {
    record('T15: Manager updates menus branchId → DENY', false, e.message);
  }

  // ── T16: Manager updates menus/x.priceCents on own-branch item → ALLOW (C-3)
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('menus/item-1').update({ priceCents: 1200 }));
    record('T16: Manager updates menus priceCents → ALLOW', true);
  } catch (e) {
    record('T16: Manager updates menus priceCents → ALLOW', false, e.message);
  }

  // ── T17: Manager writes menus/x with priceCents:-5 → DENY (C-3 validation)
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertFails(db.doc('menus/item-1').update({ priceCents: -5 }));
    record('T17: Manager writes menus priceCents:-5 → DENY', true);
  } catch (e) {
    record('T17: Manager writes menus priceCents:-5 → DENY', false, e.message);
  }

  // ── p61 (P6-1, D-051/D-052): dietary FACTS follow the menus write lane;
  // the halal CLAIM is owner-only. Fixtures are admin-written so these cases
  // measure the write lane rather than fixture setup.
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      for (const id of ['p61-item-a', 'p61-item-b', 'p61-item-c', 'p61-item-d']) {
        await admin.firestore().doc('menus/' + id).set({
          name: 'P61 ' + id,
          priceCents: 1500,
          branchId: 'branch-1',
          tenantId: 'tenant_a',
        });
      }
    });
  } catch (e) {
    record('p61 fixture seed → ok', false, e.message);
  }

  // p61-T1: manager sets a dietary fact on an own-branch item → ALLOW
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('menus/p61-item-a').update({ dietary: ['vegan'] }));
    record('p61-T1: manager sets dietary → ALLOW', true);
  } catch (e) {
    record('p61-T1: manager sets dietary → ALLOW', false, e.message);
  }

  // p61-T2: MANAGER sets the halal certification claim → DENY (owner-only)
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertFails(db.doc('menus/p61-item-b').update({ halalCertified: true }));
    record('p61-T2: manager sets halalCertified → DENY', true);
  } catch (e) {
    record('p61-T2: manager sets halalCertified → DENY', false, e.message);
  }

  // p61-T3: OWNER sets the same claim → ALLOW (the allow control: a lockdown
  // that denied the owner too would pass T2 and fail here)
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('menus/p61-item-c').update({
      halalCertified: true,
      halalCertBody: 'test-body',
      halalCertExpiresAt: new Date(Date.now() + 86400000),
    }));
    record('p61-T3: owner sets halalCertified → ALLOW', true);
  } catch (e) {
    record('p61-T3: owner sets halalCertified → ALLOW', false, e.message);
  }

  // p61-T4: manager sets cross-contamination notes → ALLOW
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('menus/p61-item-d').update({ allergenNotes: 'shared fryer' }));
    record('p61-T4: manager sets allergenNotes → ALLOW', true);
  } catch (e) {
    record('p61-T4: manager sets allergenNotes → ALLOW', false, e.message);
  }

  // p61-T5: a customer does not write menu metadata at all → DENY
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer', '').firestore();
    await assertFails(db.doc('menus/p61-item-a').update({ dietary: ['vegan'] }));
    record('p61-T5: customer sets dietary → DENY', true);
  } catch (e) {
    record('p61-T5: customer sets dietary → DENY', false, e.message);
  }

  // ── T18: Anonymous user writes analyticsEvents/x → DENY (W-5) ───────
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('analyticsEvents/event-1').set({ name: 'click' }));
    record('T18: Anonymous writes analyticsEvents → DENY', true);
  } catch (e) {
    record('T18: Anonymous writes analyticsEvents → DENY', false, e.message);
  }

  // ── T19: Anonymous user reads settings/tenant_a_ownerInfo → DENY (W-5) ───────
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('settings/tenant_a_ownerInfo').get());
    record('T19: Anonymous reads settings/tenant_a_ownerInfo → DENY', true);
  } catch (e) {
    record('T19: Anonymous reads settings/tenant_a_ownerInfo → DENY', false, e.message);
  }

  // ── T20: Authenticated non-owner reads settings/featureFlags → ALLOW (W-5 public flag)
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('settings/featureFlags').get());
    record('T20: Non-owner reads settings/featureFlags → ALLOW', true);
  } catch (e) {
    record('T20: Non-owner reads settings/featureFlags → ALLOW', false, e.message);
  }

  // ── T21: Customer reads another user's reservation_locks/x → DENY (W-4) ──
  try {
    // Use customer2-uid (NOT mutated by T7) — other-lock belongs to other-user-uid
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservation_locks/other-lock').get());
    record('T21: Customer reads other reservation_locks → DENY', true);
  } catch (e) {
    record('T21: Customer reads other reservation_locks → DENY', false, e.message);
  }

  // ── T22: Customer creates reservation with status:'confirmed' → DENY (W-2) ──
  // NOTE: App's real payload uses userId/branchId/customerName/customerPhone/startTime/partySize.
  // Adding a 'status' field violates the hasOnly shape lock.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservations/res-1').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      branchId: 'branch-1',
      customerName: 'Test',
      customerPhone: '123',
      startTime: new Date(),
      partySize: 2,
      status: 'confirmed',
    }));
    record('T22: Customer creates reservation with status:confirmed → DENY', true);
  } catch (e) {
    record('T22: Customer creates reservation with status:confirmed → DENY', false, e.message);
  }

  // ── T23: Customer creates reservation with real payload → ALLOW (W-2) ──
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservations/res-2').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      branchId: 'branch-1',
      customerName: 'Test',
      customerPhone: '123',
      startTime: new Date(),
      partySize: 2,
    }));
    record('T23: Customer creates reservation real payload → ALLOW', true);
  } catch (e) {
    record('T23: Customer creates reservation real payload → ALLOW', false, e.message);
  }

  // ── T24: Manager writes promoCodes/x → DENY (W-3 owner-only) ────────
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertFails(db.doc('promoCodes/HACK').set({ code: 'HACK', discountCents: 5000 }));
    record('T24: Manager writes promoCodes → DENY', true);
  } catch (e) {
    record('T24: Manager writes promoCodes → DENY', false, e.message);
  }

  // ── T25: Owner writes promoCodes/x → ALLOW (W-3) ────────────────────
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('promoCodes/NEW10').set({ code: 'NEW10', discountCents: 1000 }));
    record('T25: Owner writes promoCodes → ALLOW', true);
  } catch (e) {
    record('T25: Owner writes promoCodes → ALLOW', false, e.message);
  }

// ── T26: Customer reads OWN reservation_locks → ALLOW (GDPR own-read) ──
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservation_locks/lock-1').get());
    record('T26: Customer reads own reservation_locks → ALLOW', true);
  } catch (e) {
    record('T26: Customer reads own reservation_locks → ALLOW', false, e.message);
  }

  // ── T27: Customer reads OWN reservation (userId key) → ALLOW ──────────────
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservations/seed-res-1').get());
    record('T27: Customer reads own reservation (userId key) → ALLOW', true);
  } catch (e) {
    record('T27: Customer reads own reservation (userId key) → ALLOW', false, e.message);
  }

  // ── T28: Customer creates OWN deletion_requests marker → ALLOW ──────────
  // The durable GDPR marker (gdpr_service.dart + deleteUserData) is
  // self-scoped — the user records their own erasure request.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('deletion_requests/customer-uid').set({
      status: 'in_progress',
      requestedAt: new Date(),
    }));
    record('T28: Customer creates own deletion_requests → ALLOW', true);
  } catch (e) {
    record('T28: Customer creates own deletion_requests → ALLOW', false, e.message);
  }

  // ── T29: Customer reads ANOTHER user's deletion_requests → DENY ────────
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('deletion_requests/customer-uid').get());
    record('T29: Customer reads other deletion_requests → DENY', true);
  } catch (e) {
    record('T29: Customer reads other deletion_requests → DENY', false, e.message);
  }

  // ── T30: Customer deletes deletion_requests/own → DENY (audit proof) ──
  // The marker is the audit proof of erasure + the retrier's worklist; it is
  // intentionally immutable from the client.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('deletion_requests/customer-uid').delete());
    record('T30: Customer deletes own deletion_requests → DENY', true);
  } catch (e) {
    record('T30: Customer deletes own deletion_requests → DENY', false, e.message);
  }

  // ── T31-T37: App Check OR-gap / strict-mode (B6-5) ───────────────────
  // `loyalty/{userId}` self-write is the minimal non-public write gated by
  // `isAppVerified()`, so it is the cleanest probe for the flag behavior.
  async function setStrongAppCheck(value) {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/featureFlags').set({
        liveTracking: true,
        reservations: true,
        strongAppCheck: value,
      });
    });
  }

  // T31: app_id only in RELAXED mode → ALLOW (OR accepts either).
  try {
    await setStrongAppCheck(false);
    const db = authedApp('t31-uid', 't31@example.com', 'customer', '', { appId: true, appCheckToken: false }).firestore();
    await assertSucceeds(db.doc('loyalty/t31-uid').set({ userId: 't31-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T31: relaxed + app_id only → ALLOW', true);
  } catch (e) {
    record('T31: relaxed + app_id only → ALLOW', false, e.message);
  }

  // T32: token-only in RELAXED mode → ALLOW (OR accepts either).
  try {
    await setStrongAppCheck(false);
    const db = authedApp('t32-uid', 't32@example.com', 'customer', '', { appId: false, appCheckToken: true }).firestore();
    await assertSucceeds(db.doc('loyalty/t32-uid').set({ userId: 't32-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T32: relaxed + token only → ALLOW', true);
  } catch (e) {
    record('T32: relaxed + token only → ALLOW', false, e.message);
  }

  // T33: NEITHER in RELAXED mode → DENY (must have at least one proof).
  try {
    await setStrongAppCheck(false);
    const db = authedApp('t33-uid', 't33@example.com', 'customer', '', { appId: false, appCheckToken: false }).firestore();
    await assertFails(db.doc('loyalty/t33-uid').set({ userId: 't33-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T33: relaxed + neither → DENY', true);
  } catch (e) {
    record('T33: relaxed + neither → DENY', false, e.message);
  }

  // T34: BOTH in STRICT mode → ALLOW.
  try {
    await setStrongAppCheck(true);
    const db = authedApp('t34-uid', 't34@example.com', 'customer').firestore();
    await assertSucceeds(db.doc('loyalty/t34-uid').set({ userId: 't34-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T34: strict + both → ALLOW', true);
  } catch (e) {
    record('T34: strict + both → ALLOW', false, e.message);
  }

  // T35: app_id ONLY in STRICT mode → DENY (OR-gap closed under strict).
  try {
    await setStrongAppCheck(true);
    const db = authedApp('t35-uid', 't35@example.com', 'customer', '', { appId: true, appCheckToken: false }).firestore();
    await assertFails(db.doc('loyalty/t35-uid').set({ userId: 't35-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T35: strict + app_id only → DENY', true);
  } catch (e) {
    record('T35: strict + app_id only → DENY', false, e.message);
  }

  // T36: token ONLY in STRICT mode → DENY (OR-gap closed under strict).
  try {
    await setStrongAppCheck(true);
    const db = authedApp('t36-uid', 't36@example.com', 'customer', '', { appId: false, appCheckToken: true }).firestore();
    await assertFails(db.doc('loyalty/t36-uid').set({ userId: 't36-uid', totalPoints: 10, updatedAt: new Date() }));
    record('T36: strict + token only → DENY', true);
  } catch (e) {
    record('T36: strict + token only → DENY', false, e.message);
  }

  // T37: restore RELAXED (flag back to false) for any subsequent runs.
  try {
    await setStrongAppCheck(false);
    const db = authedApp('t37-uid', 't37@example.com', 'customer').firestore();
    await assertSucceeds(db.doc('loyalty/t37-uid').set({ userId: 't37-uid', totalPoints: 5, updatedAt: new Date() }));
    record('T37: relaxed restored after strict → ALLOW', true);
  } catch (e) {
    record('T37: relaxed restored after strict → ALLOW', false, e.message);
  }

  // ── T38-T41: B8-6 GDPR own-list verification (B0 demo-erasure query path) ──
  // A non-admin can LIST their OWN documents in the 4 B0-queried collections
  // with `where('userId', '==', auth.uid)` — the erasure query becomes a CI
  // guaranteed rule path (potato3 T0-7 was served by the collections' existing
  // own-read/own-create; this turns the proof into a regression gate).
  async function ownListAllowed(collection, label) {
    try {
      const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
      await assertSucceeds(db.collection(collection).where('userId', '==', 'customer-uid').get());
      record(`B8-6: ${label} own-list (where userId == uid) → ALLOW`, true);
    } catch (e) {
      record(`B8-6: ${label} own-list (where userId == uid) → ALLOW`, false, e.message);
    }
  }

  // Cross-user list must be DENIED: another user cannot read customer-uid's docs.
  async function crossUserListDenied(collection, label) {
    try {
      const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
      await assertFails(db.collection(collection).where('userId', '==', 'customer-uid').get());
      record(`B8-6: ${label} cross-user list → DENY`, true);
    } catch (e) {
      record(`B8-6: ${label} cross-user list → DENY`, false, e.message);
    }
  }

  await ownListAllowed('reservations', 'reservations');
  await ownListAllowed('reservation_locks', 'reservation_locks');
  await ownListAllowed('waitlist', 'waitlist');
  await ownListAllowed('promo_usage', 'promo_usage');
  await crossUserListDenied('reservations', 'reservations');
  await crossUserListDenied('waitlist', 'waitlist');

  // ── B0: T-E0 reservation_counters (P0-1) ─────────────────────────────
  // REPRO of the booking dead-path: reservations_repository.dart:18-22/51-55
  // writes reservation_counters/{branch}_{start} INSIDE a transaction. Without
  // a match block these writes (and the transaction.get at :32) are DENIED by
  // default → requestSlot returns false → booking always fails.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservation_counters/branch-1_1710000000000').set({ booked: 2 }));
    await assertSucceeds(db.doc('reservation_counters/branch-1_1710000000000').update({ booked: 3 }));
    record('T-E0: customer creates + updates reservation_counters → ALLOW', true);
  } catch (e) {
    record('T-E0: customer creates + updates reservation_counters → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservation_counters/branch-1_1700000000000').get());
    record('T-E0: customer reads counter (booking txn read path) → ALLOW', true);
  } catch (e) {
    record('T-E0: customer reads counter (booking txn read path) → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservation_counters/branch-1_1710000000000').update({ booked: 2, userId: 'customer-uid' }));
    record('T-E0: counter extra-key shape rejected → DENY', true);
  } catch (e) {
    record('T-E0: counter extra-key shape rejected → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservation_counters/branch-1_1710000000000').update({ booked: -1 }));
    record('T-E0: counter negative booked → DENY', true);
  } catch (e) {
    record('T-E0: counter negative booked → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservation_counters/branch-1_1710000000000').delete());
    record('T-E0: counter delete → DENY', true);
  } catch (e) {
    record('T-E0: counter delete → DENY', false, e.message);
  }
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('reservation_counters/branch-1_1710000000001').set({ booked: 1 }));
    record('T-E0: anonymous counter write → DENY', true);
  } catch (e) {
    record('T-E0: anonymous counter write → DENY', false, e.message);
  }

  // ── B0: T-E1 waitlist_counters (P0-1) ────────────────────────────────
  // REPRO of the waitlist dead-path: waitlist_repository.dart:49-52/80-87 writes
  // waitlist_counters/{branchId} inside a transaction (counter.get at :63).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('waitlist_counters/branch-2').set({ count: 1, updatedAt: new Date() }));
    await assertSucceeds(db.doc('waitlist_counters/branch-2').update({ count: 2, updatedAt: new Date() }));
    record('T-E1: customer creates + updates waitlist_counters → ALLOW', true);
  } catch (e) {
    record('T-E1: customer creates + updates waitlist_counters → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('waitlist_counters/branch-1').get());
    record('T-E1: customer reads counter (join txn read path) → ALLOW', true);
  } catch (e) {
    record('T-E1: customer reads counter (join txn read path) → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('waitlist_counters/branch-2').update({ count: 3, malicious: true }));
    record('T-E1: waitlist counter extra-key shape rejected → DENY', true);
  } catch (e) {
    record('T-E1: waitlist counter extra-key shape rejected → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('waitlist_counters/branch-2').update({ count: -1, updatedAt: new Date() }));
    record('T-E1: waitlist counter negative count → DENY', true);
  } catch (e) {
    record('T-E1: waitlist counter negative count → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('waitlist_counters/branch-2').delete());
    record('T-E1: waitlist counter delete → DENY', true);
  } catch (e) {
    record('T-E1: waitlist counter delete → DENY', false, e.message);
  }
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('waitlist_counters/branch-3').set({ count: 1, updatedAt: new Date() }));
    record('T-E1: anonymous waitlist counter write → DENY', true);
  } catch (e) {
    record('T-E1: anonymous waitlist counter write → DENY', false, e.message);
  }

  // ── B0: T-E2 locations (P0-2) ────────────────────────────────────────
  // REPRO of the Locations-screen dead-path: location_repository.dart:26-31 reads
  // .collection('locations') with no match block → denied by default.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.collection('locations').limit(50).get());
    record('T-E2: signed-in user reads locations → ALLOW', true);
  } catch (e) {
    record('T-E2: signed-in user reads locations → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('locations/hack-loc').set({ name: 'Hack', lat: 1.0, lng: 2.0 }));
    record('T-E2: customer writes locations → DENY', true);
  } catch (e) {
    record('T-E2: customer writes locations → DENY', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('locations/owner-loc').set({
      name: 'Owner Loc', address: 'A St', openHours: '9-5', lat: 24.1, lng: 67.1,
    }));
    record('T-E2: owner writes location (valid shape) → ALLOW', true);
  } catch (e) {
    record('T-E2: owner writes location (valid shape) → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('locations/manager-loc').set({
      name: 'Manager Loc', branchId: 'branch-1', coordinates: [67.1, 24.1],
    }));
    record('T-E2: same-branch manager writes location (coordinates/list) → ALLOW', true);
  } catch (e) {
    record('T-E2: same-branch manager writes location (coordinates/list) → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertFails(db.doc('locations/wrong-branch').set({
      name: 'X', branchId: 'branch-9', lat: 0.0, lng: 0.0,
    }));
    record('T-E2: other-branch manager writes location → DENY', true);
  } catch (e) {
    record('T-E2: other-branch manager writes location → DENY', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('locations/geo-less').set({ name: 'NoGeo' }));
    record('T-E2: location without geometry → DENY', true);
  } catch (e) {
    record('T-E2: location without geometry → DENY', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('locations/owner-loc').delete());
    record('T-E2: owner deletes location → ALLOW', true);
  } catch (e) {
    record('T-E2: owner deletes location → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('locations/branch-1').delete());
    record('T-E2: customer deletes location → DENY', true);
  } catch (e) {
    record('T-E2: customer deletes location → DENY', false, e.message);
  }

  // ── B0: T-E3 settings/tenant_a_restaurantConfig + defaultOperatingHours (P0-3) ─────
  // REPRO of the config dead-path: restaurantConfigProvider streams
  // settings/tenant_a_restaurantConfig for customers (home/cart/checkout) and
  // saveRestaurantConfig/patchRestaurantConfig/panic switch write it.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_restaurantConfig').get());
    record('T-E3: signed-in user reads settings/tenant_a_restaurantConfig → ALLOW', true);
  } catch (e) {
    record('T-E3: signed-in user reads settings/tenant_a_restaurantConfig → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_restaurantConfig').set({ restaurantName: 'Hacked' }));
    record('T-E3: customer writes settings/tenant_a_restaurantConfig → DENY', true);
  } catch (e) {
    record('T-E3: customer writes settings/tenant_a_restaurantConfig → DENY', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_restaurantConfig').set({
      restaurantName: 'Carnama',
      tagline: 'Test',
      contactEmail: 'owner@carnama.com',
      contactPhone: '123',
      address: '1 Main St',
      currency: 'USD',
      defaultLanguage: 'en',
      logoUrl: null,
      heroImageUrl: null,
      primaryColorHex: null,
      secondaryColorHex: null,
      appStoreName: null,
      appDescription: null,
      termsUrl: null,
      privacyUrl: null,
      allergenDisclaimerEnabled: false,
      socialLinks: {},
      loyaltyProgramName: 'Rewards',
      pointsPerDollar: 10,
      redemptionThresholdPoints: 500,
      goldThresholdPoints: 2000,
      redemptionValueCents: 500,
      signupBonusPoints: 0,
      notificationTone: 'casual',
      notificationOptIn: 'after_first_order',
      minimumOrderCents: 0,
      tipEnabled: true,
      serviceChargePercent: 0,
      estimatedPrepTimeMinutes: 20,
      deliveryFeeType: 'flat',
      deliveryFeeCents: 299,
      freeDeliveryThresholdCents: 3000,
      operatingHours: {},
      ordersAccepting: true,
    }));
    record('T-E3: owner writes settings/tenant_a_restaurantConfig → ALLOW', true);
  } catch (e) {
    record('T-E3: owner writes settings/tenant_a_restaurantConfig → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('settings/tenant_a_restaurantConfig').update({ pointsPerDollar: -5 }));
    record('T-E3: invalid config shape (negative int) → DENY', true);
  } catch (e) {
    record('T-E3: invalid config shape (negative int) → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_restaurantConfig').delete());
    record('T-E3: delete settings/tenant_a_restaurantConfig → DENY', true);
  } catch (e) {
    record('T-E3: delete settings/tenant_a_restaurantConfig → DENY', false, e.message);
  }
  // regression: non-featureFlags settings docs stay owner-only.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_ownerInfo').get());
    record('T-E3: regression — settings/tenant_a_ownerInfo still owner-only → DENY', true);
  } catch (e) {
    record('T-E3: regression — settings/tenant_a_ownerInfo still owner-only → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_defaultOperatingHours').get());
    record('T-E3: signed-in user reads settings/tenant_a_defaultOperatingHours → ALLOW', true);
  } catch (e) {
    record('T-E3: signed-in user reads settings/tenant_a_defaultOperatingHours → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_defaultOperatingHours').set({
      monday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      tuesday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      wednesday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      thursday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      friday: { isOpen: true, openTime: '09:00', closeTime: '22:00' },
      saturday: { isOpen: true, openTime: '10:00', closeTime: '23:00' },
      sunday: { isOpen: true, openTime: '10:00', closeTime: '21:00' },
      holidayModeEnabled: false,
    }));
    record('T-E3: owner writes settings/tenant_a_defaultOperatingHours → ALLOW', true);
  } catch (e) {
    record('T-E3: owner writes settings/tenant_a_defaultOperatingHours → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_defaultOperatingHours').set({
      monday: { isOpen: true }, holidayModeEnabled: false,
    }));
    record('T-E3: customer writes settings/tenant_a_defaultOperatingHours → DENY', true);
  } catch (e) {
    record('T-E3: customer writes settings/tenant_a_defaultOperatingHours → DENY', false, e.message);
  }

  // ── Card 7 (D-038): tenant-keyed settings docs ───────────────────────
  // The client reads `settings/${tenantId}_restaurantConfig` after 7b, so the
  // generic block must grant the tenant's own read or the app is denied at
  // runtime. Nothing else in the battery evaluated a prefixed settings path.
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
      restaurantName: 'Own Tenant',
      tenantId: 'tenant_a',
    });
    await admin.firestore().doc('settings/tenant_b_restaurantConfig').set({
      restaurantName: 'Other Tenant',
      tenantId: 'tenant_b',
    });
  });
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_restaurantConfig').get());
    record('T-E5: tenant reads its own prefixed settings doc → ALLOW', true);
  } catch (e) {
    record('T-E5: tenant reads its own prefixed settings doc → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_b_restaurantConfig').get());
    record('T-E5: tenant reads another tenant prefix → DENY', true);
  } catch (e) {
    record('T-E5: tenant reads another tenant prefix → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_restaurantConfig').set({
      restaurantName: 'Hijacked',
    }));
    record('T-E5: customer writes a prefixed settings doc → DENY', true);
  } catch (e) {
    record('T-E5: customer writes a prefixed settings doc → DENY', false, e.message);
  }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('settings/tenant_b_restaurantConfig').set({
      restaurantName: 'Cross-tenant write',
    }));
    record('T-E5: owner writes another tenant prefix → DENY', true);
  } catch (e) {
    record('T-E5: owner writes another tenant prefix → DENY', false, e.message);
  }

  // ── B0: T-E4 orders/reservations regression (no scope change) ─────────
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/order-1').get());
    record('T-E4: customer reads own order → ALLOW', true);
  } catch (e) {
    record('T-E4: customer reads own order → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/order-1').get());
    record('T-E4: other customer reads order → DENY', true);
  } catch (e) {
    record('T-E4: other customer reads order → DENY', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('reservations/res-3').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      branchId: 'branch-1',
      customerName: 'Test',
      customerPhone: '123',
      startTime: new Date(),
      partySize: 2,
    }));
    record('T-E4: customer creates reservation with real payload → ALLOW', true);
  } catch (e) {
    record('T-E4: customer creates reservation with real payload → ALLOW', false, e.message);
  }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservations/res-4').set({
        tenantId: 'tenant_a',
      userId: 'customer-uid',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      customerName: 'Test',
      customerPhone: '123',
      startTime: new Date(),
      partySize: 2,
    }));
    record('T-E4: reservation create with customerId key → DENY (hasOnly)', true);
  } catch (e) {
    record('T-E4: reservation create with customerId key → DENY (hasOnly)', false, e.message);
  }

  // ── B3 P4 (finding 6.3): demo collections rules — notifications / notification_queue / audit_logs ──
  // notifications: read/write SELF-only (+ items subcollection mirror).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('notifications/customer-uid').get());
    record('T-D1: customer reads OWN notification doc → ALLOW', true);
  } catch (e) { record('T-D1: customer reads OWN notification doc → ALLOW', false, e.message); }
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('notifications/customer-uid').get());
    record('T-D2: other customer reads notification doc → DENY', true);
  } catch (e) { record('T-D2: other customer reads notification doc → DENY', false, e.message); }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('notifications/customer-uid/items/i1').get());
    record('T-D3: customer reads OWN notification item → ALLOW', true);
  } catch (e) { record('T-D3: customer reads OWN notification item → ALLOW', false, e.message); }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('notifications/other-user/items/x').set({ title: 'spam', isRead: false }));
    record('T-D4: customer writes ANOTHER user notification item → DENY', true);
  } catch (e) { record('T-D4: customer writes ANOTHER user notification item → DENY', false, e.message); }
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('notifications/customer-uid').get());
    record('T-D5: anonymous reads notifications → DENY', true);
  } catch (e) { record('T-D5: anonymous reads notifications → DENY', false, e.message); }

  // notification_queue: owner/manager read; owner-gated write (demo daemon).
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('notification_queue/q1').get());
    record('T-D6: manager reads notification_queue → ALLOW', true);
  } catch (e) { record('T-D6: manager reads notification_queue → ALLOW', false, e.message); }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('notification_queue/q1').get());
    record('T-D7: customer reads notification_queue → DENY', true);
  } catch (e) { record('T-D7: customer reads notification_queue → DENY', false, e.message); }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('notification_queue/q2').set({ targetUid: 'customer-uid', title: 'Hi', createdAt: new Date() }));
    record('T-D8: owner writes notification_queue → ALLOW (owner-gated demo)', true);
  } catch (e) { record('T-D8: owner writes notification_queue → ALLOW (owner-gated demo)', false, e.message); }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('notification_queue/q1').update({ title: 'spam' }));
    record('T-D9: customer writes notification_queue → DENY', true);
  } catch (e) { record('T-D9: customer writes notification_queue → DENY', false, e.message); }

  // audit_logs: owner read; write denied even for owner (server/Admin SDK only).
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('audit_logs/a1').get());
    record('T-D10: owner reads audit_logs → ALLOW', true);
  } catch (e) { record('T-D10: owner reads audit_logs → ALLOW', false, e.message); }
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('audit_logs/a2').set({ action: 'X', actorUid: 'owner-uid' }));
    record('T-D11: owner writes audit_logs → DENY (write false)', true);
  } catch (e) { record('T-D11: owner writes audit_logs → DENY (write false)', false, e.message); }
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('audit_logs/a1').get());
    record('T-D12: customer reads audit_logs → DENY', true);
  } catch (e) { record('T-D12: customer reads audit_logs → DENY', false, e.message); }

  // ── B5: T-P1..T-P4 Panic Switch DB enforcement ────────────────────────
  // T-P1: order create DENIED when ordersAccepting == false
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
        restaurantName: 'Carnama',
        currency: 'USD',
        pointsPerDollar: 10,
        ordersAccepting: false,
      });
    });
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/panic-order-1').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      totalCents: 1500,
      status: 'pending',
    }));
    record('T-P1: order create DENIED when ordersAccepting == false', true);
  } catch (e) {
    record('T-P1: order create DENIED when ordersAccepting == false', false, e.message);
  }

  // T-P2: order create ALLOWED when ordersAccepting == true
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
        restaurantName: 'Carnama',
        currency: 'USD',
        pointsPerDollar: 10,
        ordersAccepting: true,
      });
    });
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/panic-order-2').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      totalCents: 1500,
      status: 'pending',
    }));
    record('T-P2: order create ALLOWED when ordersAccepting == true', true);
  } catch (e) {
    record('T-P2: order create ALLOWED when ordersAccepting == true', false, e.message);
  }

  // T-P3: order create ALLOWED when config doc MISSING (default-open)
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_restaurantConfig').delete();
    });
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/panic-order-3').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      totalCents: 1500,
      status: 'pending',
    }));
    record('T-P3: order create ALLOWED when config doc missing (default-open)', true);
  } catch (e) {
    record('T-P3: order create ALLOWED when config doc missing (default-open)', false, e.message);
  } finally {
    // Restore seed config for any subsequent tests
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
        restaurantName: 'Carnama',
        currency: 'USD',
        pointsPerDollar: 10,
        ordersAccepting: true,
      });
    });
  }

  // T-P4: regression — existing order read+update scoping unchanged
  try {
    const custDb = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(custDb.doc('orders/panic-order-2').get());
    record('T-P4: customer reads own order after B5 rule change → ALLOW (regression)', true);
  } catch (e) {
    record('T-P4: customer reads own order after B5 rule change → ALLOW (regression)', false, e.message);
  }

  // ══ b10 RULES-1: shape locks + App Check + read-scoping (P-1..P-7) ═══════
  // Local seeds for this block (fresh docs — never mutate shared seeds).
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('users/driver2-uid').set({
        email: 'driver2@carnama.com', role: 'delivery', branchId: 'branch-1',
      });
      await admin.firestore().doc('orders/claim-order-1').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'ready',
        totalCents: 1200, items: [], createdAt: new Date(),
      }); // NO assignedDriverId — unassigned claim target
      await admin.firestore().doc('orders/claim-order-2').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'ready',
        assignedDriverId: 'driver-uid', totalCents: 1300, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/pod-order-1').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'pickedUp',
        assignedDriverId: 'driver-uid', totalCents: 1400, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/pod-order-2').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'pickedUp',
        assignedDriverId: 'driver-uid', totalCents: 1500, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/pod-order-3').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'pickedUp',
        assignedDriverId: 'driver-uid', totalCents: 1600, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/kitchen-order-1').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'confirmed',
        totalCents: 1700, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/kitchen-order-2').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'confirmed',
        totalCents: 1750, items: [], createdAt: new Date(),
      });
      await admin.firestore().doc('orders/kitchen-order-3').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'confirmed',
        totalCents: 1780, items: [], createdAt: new Date(),
      });
    });
    record('b10-seed: local block seeds written', true);
  } catch (e) { record('b10-seed: local block seeds written', false, e.message); }

  // ── b10-T1 (P-1): driver CLAIMS unassigned ready order via the real
  // assignToMe payload {assignedDriverId: self, status:'pickedUp', updatedAt}
  // (delivery_service.dart:107-111) → ALLOW.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/claim-order-1').update({
      assignedDriverId: 'driver-uid', status: 'pickedUp', updatedAt: new Date(),
    }));
    record('b10-T1: driver claims unassigned order (real claim payload) → ALLOW', true);
  } catch (e) { record('b10-T1: driver claims unassigned order (real claim payload) → ALLOW', false, e.message); }

  // ── b10-T2 (P-1): a second driver cannot claim an order already assigned.
  try {
    const db = authedApp('driver2-uid', 'driver2@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('orders/claim-order-2').update({
      assignedDriverId: 'driver2-uid', status: 'pickedUp', updatedAt: new Date(),
    }));
    record('b10-T2: driver2 claims order assigned to driver-uid → DENY', true);
  } catch (e) { record('b10-T2: driver2 claims order assigned to driver-uid → DENY', false, e.message); }

  // ── b10-T3 (P-1): assigned driver may RESTATE own assignment.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/claim-order-2').update({
      assignedDriverId: 'driver-uid', status: 'pickedUp', updatedAt: new Date(),
    }));
    record('b10-T3: assigned driver restates own assignment → ALLOW', true);
  } catch (e) { record('b10-T3: assigned driver restates own assignment → ALLOW', false, e.message); }

  // ── b10-T4 (P-1): assigned driver cannot reassign to someone else.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('orders/claim-order-2').update({
      assignedDriverId: 'driver2-uid', status: 'delivered', updatedAt: new Date(),
    }));
    record('b10-T4: driver reassigns own order to driver2 → DENY', true);
  } catch (e) { record('b10-T4: driver reassigns own order to driver2 → DENY', false, e.message); }

  // ── b10-T5 (P-1): POD upload with the real shape
  // (proof_of_delivery_service.dart:57-64) → ALLOW.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/pod-order-1').update({
      status: 'delivered',
      updatedAt: new Date(),
      proofOfDelivery: {
        url: 'https://storage.googleapis.com/bucket/pod/pod-order-1.jpg',
        uploadedBy: 'driver-uid',
      },
    }));
    record('b10-T5: driver uploads POD on own pickedUp order → ALLOW', true);
  } catch (e) { record('b10-T5: driver uploads POD on own pickedUp order → ALLOW', false, e.message); }

  // ── b10-T6 (P-1): POD.uploadedBy must be the writer.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('orders/pod-order-2').update({
      status: 'delivered',
      updatedAt: new Date(),
      proofOfDelivery: { url: 'https://x.test/pod.jpg', uploadedBy: 'driver2-uid' },
    }));
    record('b10-T6: POD uploadedBy != writer → DENY', true);
  } catch (e) { record('b10-T6: POD uploadedBy != writer → DENY', false, e.message); }

  // ── b10-T7 (P-1): POD.url must be a string.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('orders/pod-order-3').update({
      status: 'delivered',
      updatedAt: new Date(),
      proofOfDelivery: { uploadedBy: 'driver-uid' },
    }));
    record('b10-T7: POD without url string → DENY', true);
  } catch (e) { record('b10-T7: POD without url string → DENY', false, e.message); }

  // ── b10-T8 (P-2): the NEW branch-scoped myOrders composite query
  // (branchId == && assignedDriverId == && status IN && orderBy createdAt)
  // is permitted by the delivery read clause.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    const snap = await db.collection('orders')
      .where('branchId', '==', 'branch-1')
      .where('assignedDriverId', '==', 'driver-uid')
      .where('status', 'in', ['ready', 'pickedUp'])
      .orderBy('createdAt')
      .get();
    if (snap.size > 0) {
      record('b10-T8: myOrders composite list query → ALLOW (' + snap.size + ' docs)', true);
    } else {
      record('b10-T8: myOrders composite list query → ALLOW', false, 'query returned 0 docs');
    }
  } catch (e) { record('b10-T8: myOrders composite list query → ALLOW', false, e.message); }

  // ── b10-T9 (P-3): kitchen READS a ready own-branch order → ALLOW.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/order-1').get());
    record('b10-T9: kitchen reads ready order → ALLOW', true);
  } catch (e) { record('b10-T9: kitchen reads ready order → ALLOW', false, e.message); }

  // ── b10-T9b (P-3): kitchen still CANNOT read pickedUp orders.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('orders/claim-order-2').get());
    record('b10-T9b: kitchen reads pickedUp order → DENY', true);
  } catch (e) { record('b10-T9b: kitchen reads pickedUp order → DENY', false, e.message); }

  // ── b10-T10 (P-1): kitchen update carrying the REAL updatedAt field → ALLOW.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/kitchen-order-1').update({
      status: 'preparing', updatedAt: new Date(),
    }));
    record('b10-T10: kitchen update {status, updatedAt} → ALLOW', true);
  } catch (e) { record('b10-T10: kitchen update {status, updatedAt} → ALLOW', false, e.message); }

  // ── b10-T11 (P-1): kitchen update with a rogue key → DENY.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('orders/kitchen-order-2').update({
      status: 'preparing', updatedAt: new Date(), totalCents: 1,
    }));
    record('b10-T11: kitchen update with rogue key → DENY', true);
  } catch (e) { record('b10-T11: kitchen update with rogue key → DENY', false, e.message); }

  // ── b10-T12 (P-1): manager update {status, updatedAt} → ALLOW.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/kitchen-order-3').update({
      status: 'ready', updatedAt: new Date(),
    }));
    record('b10-T12: manager update {status, updatedAt} → ALLOW', true);
  } catch (e) { record('b10-T12: manager update {status, updatedAt} → ALLOW', false, e.message); }

  // ── b10-T13 (P-7): customer reads promoCodes → DENY (callable-CF-only).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('promoCodes/SAVE10').get());
    record('b10-T13: customer reads promoCodes → DENY', true);
  } catch (e) { record('b10-T13: customer reads promoCodes → DENY', false, e.message); }

  // ── b10-T14 (P-7): manager reads promoCodes → ALLOW.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('promoCodes/SAVE10').get());
    record('b10-T14: manager reads promoCodes → ALLOW', true);
  } catch (e) { record('b10-T14: manager reads promoCodes → ALLOW', false, e.message); }

  // ── b10-T15 (P-5): analyticsEvents real payload (telemetry_service
  // .dart:28-32) → ALLOW (8 property keys ≤ 10).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.collection('analyticsEvents').doc().set({
      event: 'screen_view',
      properties: { a: '1', b: '2', c: '3', d: '4', e: '5', f: '6', g: '7', h: '8' },
      timestamp: new Date(),
    }));
    record('b10-T15: analytics real payload (8 props) → ALLOW', true);
  } catch (e) { record('b10-T15: analytics real payload (8 props) → ALLOW', false, e.message); }

  // ── b10-T16 (P-5): 11 property keys → DENY (abuse cap).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.collection('analyticsEvents').doc().set({
      event: 'spam',
      properties: { a: '1', b: '2', c: '3', d: '4', e: '5', f: '6', g: '7', h: '8', i: '9', j: '10', k: '11' },
      timestamp: new Date(),
    }));
    record('b10-T16: analytics 11 property keys → DENY', true);
  } catch (e) { record('b10-T16: analytics 11 property keys → DENY', false, e.message); }

  // ── b10-T17 (P-5): 10-key properties AT the cap → ALLOW (boundary).
  // NOTE: a per-VALUE length cap is not expressible in the rules language
  // (no higher-order functions; `.filter(v => …)` does not compile) — value
  // abuse is bounded by the key cap + Firestore's 1 MiB doc limit (see the
  // analyticsEvents rule comment).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.collection('analyticsEvents').doc().set({
      event: 'cap_boundary',
      properties: { a: '1', b: '2', c: '3', d: '4', e: '5', f: '6', g: '7', h: '8', i: '9', j: '10' },
      timestamp: new Date(),
    }));
    record('b10-T17: analytics exactly 10 property keys → ALLOW', true);
  } catch (e) { record('b10-T17: analytics exactly 10 property keys → ALLOW', false, e.message); }

  // ── b10-T18 (P-5): anonymous analytics READ → DENY.
  try {
    const db = anonApp().firestore();
    await assertFails(db.doc('analyticsEvents/event-1').get());
    record('b10-T18: anonymous reads analyticsEvents → DENY', true);
  } catch (e) { record('b10-T18: anonymous reads analyticsEvents → DENY', false, e.message); }

  // ── b10-T19 (P-6/P-4): owner reads presence → ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('presence/manager-uid').get());
    record('b10-T19: owner reads presence → ALLOW', true);
  } catch (e) { record('b10-T19: owner reads presence → ALLOW', false, e.message); }

  // ── b10-T20 (P-6): same-branch kitchen reads presence → ALLOW.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('presence/manager-uid').get());
    record('b10-T20: same-branch kitchen reads presence → ALLOW', true);
  } catch (e) { record('b10-T20: same-branch kitchen reads presence → ALLOW', false, e.message); }

  // ── b10-T21 (P-4): customer reads presence → DENY.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('presence/manager-uid').get());
    record('b10-T21: customer reads presence → DENY', true);
  } catch (e) { record('b10-T21: customer reads presence → DENY', false, e.message); }

  // ── b10-T22 (P-4): kitchen writes own presence with the REAL payload
  // (presence_service.dart:37-49) → ALLOW.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('presence/kitchen-uid').set({
      isOnline: true, lastSeen: new Date(), branchId: 'branch-1', role: 'kitchen',
    }));
    record('b10-T22: kitchen writes own presence (real payload) → ALLOW', true);
  } catch (e) { record('b10-T22: kitchen writes own presence (real payload) → ALLOW', false, e.message); }

  // ── b10-T23 (P-4): presence role escalation → DENY.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('presence/kitchen-uid').set({
      isOnline: true, lastSeen: new Date(), branchId: 'branch-1', role: 'owner',
    }));
    record('b10-T23: presence role escalation → DENY', true);
  } catch (e) { record('b10-T23: presence role escalation → DENY', false, e.message); }

  // ── b10-T24 (P-4): presence with an extra key → DENY.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('presence/kitchen-uid').set({
      isOnline: true, lastSeen: new Date(), branchId: 'branch-1', role: 'kitchen', hack: 1,
    }));
    record('b10-T24: presence extra key → DENY', true);
  } catch (e) { record('b10-T24: presence extra key → DENY', false, e.message); }

  // ── b10-T25 (P-4): presence missing isOnline → DENY.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('presence/kitchen-uid-2').set({
      lastSeen: new Date(), branchId: 'branch-1', role: 'kitchen',
    }));
    record('b10-T25: presence missing isOnline → DENY', true);
  } catch (e) { record('b10-T25: presence missing isOnline → DENY', false, e.message); }

  // ── b10-T26 (P-4): cross-user presence write → DENY.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertFails(db.doc('presence/manager-uid').set({
      isOnline: false, lastSeen: new Date(), branchId: 'branch-1', role: 'manager',
    }));
    record('b10-T26: cross-user presence write → DENY', true);
  } catch (e) { record('b10-T26: cross-user presence write → DENY', false, e.message); }

  // ── b10-T27 (P-4): customer reads own loyalty → ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('loyalty/customer-uid').get());
    record('b10-T27: customer reads own loyalty → ALLOW', true);
  } catch (e) { record('b10-T27: customer reads own loyalty → ALLOW', false, e.message); }

  // ── b10-T28 (P-4): another customer reads loyalty → DENY.
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('loyalty/customer-uid').get());
    record('b10-T28: other customer reads loyalty → DENY', true);
  } catch (e) { record('b10-T28: other customer reads loyalty → DENY', false, e.message); }

  // ── b10-T29 (P-4): loyalty update with CF shape → ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('loyalty/customer-uid').update({
      totalPoints: 130, updatedAt: new Date(),
    }));
    record('b10-T29: loyalty update CF shape → ALLOW', true);
  } catch (e) { record('b10-T29: loyalty update CF shape → ALLOW', false, e.message); }

  // ── b10-T30 (P-4): legacy {points} payload → DENY (shape lock).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('loyalty/customer-uid').set({ points: 50 }));
    record('b10-T30: loyalty legacy points payload → DENY', true);
  } catch (e) { record('b10-T30: loyalty legacy points payload → DENY', false, e.message); }

  // ── b10-T31 (P-4): loyalty tier must be a string when present.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('loyalty/customer-uid').set({
      userId: 'customer-uid', totalPoints: 5, updatedAt: new Date(), tier: 99,
    }));
    record('b10-T31: loyalty non-string tier → DENY', true);
  } catch (e) { record('b10-T31: loyalty non-string tier → DENY', false, e.message); }

  // ── b10-T32 (P-4): negative totalPoints → DENY.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('loyalty/customer-uid').set({
      userId: 'customer-uid', totalPoints: -1, updatedAt: new Date(),
    }));
    record('b10-T32: loyalty negative totalPoints → DENY', true);
  } catch (e) { record('b10-T32: loyalty negative totalPoints → DENY', false, e.message); }

  // ── b10-T33 (P-4): loyalty delete → DENY (points are server-owned).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('loyalty/customer-uid').delete());
    record('b10-T33: customer deletes own loyalty → DENY', true);
  } catch (e) { record('b10-T33: customer deletes own loyalty → DENY', false, e.message); }

  // ── b10-T34 (P-6): authed user with NO App Check proofs can no longer
  // write P-6 surfaces (delta vs baseline, which only required auth).
  try {
    const db = authedApp('t-noproof-uid', 'noproof@example.com', 'customer', '', { appId: false, appCheckToken: false }).firestore();
    await assertFails(db.collection('waitlist').doc('t-noproof-uid').set({
      userId: 't-noproof-uid', branchId: 'branch-1', partySize: 2,
    }));
    record('b10-T34: no-proof authed user waitlist create → DENY (P-6 delta)', true);
  } catch (e) { record('b10-T34: no-proof authed user waitlist create → DENY (P-6 delta)', false, e.message); }

  // ── b10-T35 (P-6): App-verified user CAN still write waitlist (no false
  // positive from the added isAppVerified gate).
  try {
    const db = authedApp('t-wl-uid', 'wl@example.com', 'customer').firestore();
    await assertSucceeds(db.collection('waitlist').doc('t-wl-uid').set({
      userId: 't-wl-uid', branchId: 'branch-1', partySize: 2,
    }));
    record('b10-T35: app-verified waitlist create → ALLOW (no regression)', true);
  } catch (e) { record('b10-T35: app-verified waitlist create → ALLOW (no regression)', false, e.message); }

  // ── QUEUE-1 (b12): T-2 offline replay legality ──────────────────────────
  // checkout_screen now enqueues a SEPARATE rules-legal payload
  // (buildOfflineOrderPayload): status 'pending' + offlineQueued + queuedAt
  // (ISO). Order create rules (firestore.rules:395-402) require
  // status == 'pending'; a 'confirmed' replay is rules-DENIED forever and rots
  // in the DLQ. q-T1 proves the EXACT replayed payload is legal; q-T2 locks
  // the money-authority invariant (never replay an unpaid intent as confirmed).
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_restaurantConfig').set({
        restaurantName: 'Carnama',
        currency: 'USD',
        pointsPerDollar: 10,
        ordersAccepting: true,
      });
    });
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/queue1-order-1').set({
        tenantId: 'tenant_a',
      id: 'queue1-order-1',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'pending',
      totalCents: 1500,
      taxCents: 100,
      discountCents: 50,
      tipCents: 200,
      deliveryFeeCents: 300,
      orderNumber: 'Q-1',
      createdAt: '2026-01-01T00:00:00.000',
      offlineQueued: true,
      queuedAt: '2026-01-01T00:00:00.000',
    }));
    record('q-T1: offline replay payload (status pending + offlineQueued + queuedAt) → ALLOW', true);
  } catch (e) { record('q-T1: offline replay payload (status pending + offlineQueued + queuedAt) → ALLOW', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-2').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'confirmed',
      totalCents: 1500,
    }));
    record('q-T2: confirmed offline replay → DENY (never enqueue confirmed)', true);
  } catch (e) { record('q-T2: confirmed offline replay → DENY (never enqueue confirmed)', false, e.message); }

  // ── p26 T-4 (D-P26-4(a)): the CREATE-rule key shape lock ────────────────
  // The orders create rule now carries
  //   request.resource.data.keys().hasOnly([<the 18 keys a client create may
  //   name>])
  // — on create there is no `resource`, so the FULL candidate key set is the
  // affected-key equivalent of the update-time
  // `diff(resource.data).affectedKeys()` idiom used further down this file.
  // q-T3/q-T4 are the new DENY directions (pre-hardening both were ALLOWED);
  // q-T5 is the exact replayed payload and must stay ALLOW; q-T6..q-T11 are the
  // per-clause negatives of the surviving field clauses. The Dart half of this
  // contract — rule text read off disk + payload subset check — is
  // test/rules/order_create_payload_contract_test.dart.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-3').set({
        tenantId: 'tenant_a',
      id: 'queue1-order-3',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'pending',
      totalCents: 1500,
      orderSource: 'platform:uber_eats',
    }));
    record('q-T3: forged orderSource on create → DENY (server-owned key)', true);
  } catch (e) { record('q-T3: forged orderSource on create → DENY (server-owned key)', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-4').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'pending',
      totalCents: 1500,
      rogueKey: 'anything',
    }));
    record('q-T4: unknown rogue key on create → DENY (allowlist, not denylist)', true);
  } catch (e) { record('q-T4: unknown rogue key on create → DENY (allowlist, not denylist)', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/queue1-order-5').set({
        tenantId: 'tenant_a',
      id: 'queue1-order-5',
      customerId: 'customer-uid',
      status: 'pending',
      totalCents: 1500,
      taxCents: 100,
      discountCents: 50,
      tipCents: 200,
      deliveryFeeCents: 300,
      orderNumber: 'Q-2',
      createdAt: '2026-01-01T00:00:00.000',
      updatedAt: new Date(),
      items: [],
      branchId: 'branch-1',
      assignedDriverId: null,
      customerLat: null,
      customerLng: null,
      offlineQueued: true,
      queuedAt: '2026-01-01T00:00:00.000',
    }));
    record('q-T5: EXACT replayed payload (18 keys, no orderSource) → ALLOW', true);
  } catch (e) { record('q-T5: EXACT replayed payload (18 keys, no orderSource) → ALLOW', false, e.message); }

  // q-T6..q-T11: one negative per surviving create clause.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-6').set({
        tenantId: 'tenant_a',
      branchId: 'branch-1', status: 'pending', totalCents: 1500,
    }));
    record('q-T6: create WITHOUT customerId → DENY', true);
  } catch (e) { record('q-T6: create WITHOUT customerId → DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-7').set({
        tenantId: 'tenant_a',
      customerId: 'someone-else', branchId: 'branch-1', status: 'pending', totalCents: 1500,
    }));
    record('q-T7: create with another user\'s customerId → DENY', true);
  } catch (e) { record('q-T7: create with another user\'s customerId → DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-8').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid', branchId: '', status: 'pending', totalCents: 1500,
    }));
    record('q-T8: create with EMPTY branchId → DENY', true);
  } catch (e) { record('q-T8: create with EMPTY branchId → DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-9').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid', branchId: 7, status: 'pending', totalCents: 1500,
    }));
    record('q-T9: create with NON-STRING branchId → DENY', true);
  } catch (e) { record('q-T9: create with NON-STRING branchId → DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-10').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid', branchId: 'branch-1', status: 'pending', totalCents: -1,
    }));
    record('q-T10: create with NEGATIVE totalCents → DENY', true);
  } catch (e) { record('q-T10: create with NEGATIVE totalCents → DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/queue1-order-11').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid', branchId: 'branch-1', status: 'pending', totalCents: '1500',
    }));
    record('q-T11: create with NON-INT totalCents → DENY', true);
  } catch (e) { record('q-T11: create with NON-INT totalCents → DENY', false, e.message); }

  // ── RULES-2 (b11): T-5 isOwner() true/false by ownerEmail doc presence ──
  // isOwner() (firestore.rules:47-52) = authenticated ∧ ¬anonymous ∧
  // exists(settings/tenant_a_ownerInfo) ∧ ownerInfo.ownerEmail == token.email.
  // T5a: claim email == seeded ownerInfo.ownerEmail → owner-gated write
  // ALLOWED. T5b: ownerInfo doc DELETED → DENIED (doc presence is mandatory —
  // the fresh-backend bootstrap gap, 01-P1-C, closed by v003). T5c: doc
  // present but token email ≠ ownerEmail → DENIED. State restored after T5b.
  try {
    const db = authedApp('owner-claim-uid', 'owner@carnama.com').firestore();
    await assertSucceeds(db.doc('settings/featureFlags').set({ liveTracking: true, reservations: true }));
    record('b11-T5a: token email == ownerInfo.ownerEmail → owner-gated write ALLOW', true);
  } catch (e) { record('b11-T5a: token email == ownerInfo.ownerEmail → owner-gated write ALLOW', false, e.message); }
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      // D-038: isOwner() reads the TENANT document, so that is the one whose
      // absence must be proven here; the legacy path is no longer consulted.
      await admin.firestore().doc('settings/tenant_a_ownerInfo').delete();
    });
    const db = authedApp('owner-claim-uid', 'owner@carnama.com').firestore();
    await assertFails(db.doc('settings/featureFlags').set({ liveTracking: true }));
    record('b11-T5b: settings/tenant_a_ownerInfo ABSENT → owner-gated write DENY (isOwner fail-closed)', true);
  } catch (e) { record('b11-T5b: settings/tenant_a_ownerInfo ABSENT → owner-gated write DENY (isOwner fail-closed)', false, e.message); }
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_ownerInfo').set({
        ownerEmail: 'owner@carnama.com',
        tenantId: 'tenant_a',
      });
    });
    const db = authedApp('impostor-uid', 'impostor@example.com').firestore();
    await assertFails(db.doc('settings/featureFlags').set({ liveTracking: true }));
    record('b11-T5c: token email != ownerInfo.ownerEmail → owner-gated write DENY', true);
  } catch (e) { record('b11-T5c: token email != ownerInfo.ownerEmail → owner-gated write DENY', false, e.message); }

  // ── p29-T1 (PC1 proof): isOwner() fail-closed on branches/{id} writes
  // (firestore.rules:258 = isAppVerified() && isOwner()). doc-present +
  // matching auth-token email → ALLOW; doc-absent → DENY (exists() false);
  // doc-present + mismatched email → DENY. State restored after T1b so the
  // rest of the battery sees the seeded ownerInfo.
  try {
    const db = authedApp('owner-p29-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('branches/p29-present').set({ name: 'P29', address: 'x', lat: 0, lng: 0 }));
    record('p29-T1a: ownerInfo present + matching token email → branches write ALLOW', true);
  } catch (e) { record('p29-T1a: ownerInfo present + matching token email → branches write ALLOW', false, e.message); }
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_ownerInfo').delete();
    });
    const db = authedApp('owner-p29-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertFails(db.doc('branches/p29-absent').set({ name: 'P29', address: 'x', lat: 0, lng: 0 }));
    record('p29-T1b: ownerInfo ABSENT → branches write DENY (fail-closed)', true);
  } catch (e) { record('p29-T1b: ownerInfo ABSENT → branches write DENY (fail-closed)', false, e.message); }
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('settings/tenant_a_ownerInfo').set({ ownerEmail: 'owner@carnama.com' });
    });
    const db = authedApp('owner-p29-other-uid', 'other@example.com', 'owner', '').firestore();
    await assertFails(db.doc('branches/p29-mismatch').set({ name: 'P29', address: 'x', lat: 0, lng: 0 }));
    record('p29-T1c: ownerInfo present + MISMATCHED token email → branches write DENY', true);
  } catch (e) { record('p29-T1c: ownerInfo present + MISMATCHED token email → branches write DENY', false, e.message); }

// STAFF-QUEUE (b14 / W5.4): T-3 — staff update REPLAYS are rules-legal.

  // The QUEUE-1 auto-triggers replay a pending staff 'update' op as a
  // merge-set of {id, status[, assignedDriverId / proofOfDelivery], updatedAt}
  // onto orders/{id}. These cases prove that EXACT replayed shape (matching
  // REAL stored docs, WHICH CARRY THEIR OWN `id` FIELD — createOrder
  // index.ts:1155; the QUEUE-1 offline create replay persists it) passes
  // the updated W4.1 staff clauses WITHOUT the `id` polluting affectedKeys()
  // — every b14 doc seeds `id` EQUAL TOthe doc id, so the merged id is
  // UNCHANGED and never appears in diff(...).affectedKeys()).hasOnly. A doc
  // seeded WITHOUT id would add id as a NEW key and FAIL — proving why the
  // queue payload can only replay against CF-shaped order docs.

  // b14-T1: kitchen status-update replay ({id, status, updatedAt} +
  // merge) — kitchen-uid, confirmed -> preparing, same-branch — ALLOW.

  // b14-T2: manager status-update replay — manager-uid, confirmed -> ready,
  // same-branch — ALLOW (manager clause has status-only shape guard).

  // b14-T3: delivery CLAIM replay ({id, status:'pickedUp',
  // assignedDriverId:self, updatedAt}) — driver-uid claims an UNASSIGNED
  // ready order — ALLOW (claim branch:firestore.rules:442-445).

  // b14-T4: proof-of-delivery replay ({id, status:'delivered',
  // proofOfDelivery{url, uploadedBy:self, capturedAt}, updatedAt}) —
  // driver-uid on own pickedUp order — ALLOW (own-order branch + POD guard).

  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('orders/b14-kitchen').set({
        tenantId: 'tenant_a',
        id: 'b14-kitchen',
        customerId: 'customer-uid',
        branchId: 'branch-1',
        status: 'confirmed',
        totalCents: 2000,
        items: [],
        createdAt: new Date(),
      });
      await admin.firestore().doc('orders/b14-manager').set({
        tenantId: 'tenant_a',
        id: 'b14-manager',
        customerId: 'customer-uid',
        branchId: 'branch-1',
        status: 'confirmed',
        totalCents: 2200,
        items: [],
        createdAt: new Date(),
      });
      await admin.firestore().doc('orders/b14-claim').set({
        tenantId: 'tenant_a',
        id: 'b14-claim',
        customerId: 'customer-uid',
        branchId: 'branch-1',
        status: 'ready',
        totalCents: 2400,
        items: [],
        createdAt: new Date(),
      });
      await admin.firestore().doc('orders/b14-pod').set({
        tenantId: 'tenant_a',
        id: 'b14-pod',
        customerId: 'customer-uid',
        branchId: 'branch-1',
        status: 'pickedUp',
        assignedDriverId: 'driver-uid',
        totalCents: 2600,
        items: [],
        createdAt: new Date(),
      });
    });
  } catch (e) { record('b14 seed FAILED', false, e.message); }

  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/b14-kitchen').update({
      id: 'b14-kitchen',
      status: 'preparing',
      updatedAt: new Date(),
    }));
    record('b14-T1: kitchen status-update replay ({id,status,updatedAt}) -> ALLOW', true);
  } catch (e) { record('b14-T1: kitchen status-update replay ({id,status,updatedAt}) -> ALLOW', false, e.message); }

  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/b14-manager').update({
      id: 'b14-manager',
      status: 'ready',
      updatedAt: new Date(),
    }));
    record('b14-T2: manager status-update replay ({id,status,updatedAt}) -> ALLOW', true);
  } catch (e) { record('b14-T2: manager status-update replay ({id,status,updatedAt}) -> ALLOW', false, e.message); }

  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/b14-claim').update({
      id: 'b14-claim',
      status: 'pickedUp',
      assignedDriverId: 'driver-uid',
      updatedAt: new Date(),
    }));
    record('b14-T3: delivery claim replay ({id,status,pickedUp,assignedDriverId:self,updatedAt}) -> ALLOW', true);
  } catch (e) { record('b14-T3: delivery claim replay ({id,status,pickedUp,assignedDriverId:self,updatedAt}) -> ALLOW', false, e.message); }

  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('orders/b14-pod').update({
      id: 'b14-pod',
      status: 'delivered',
      updatedAt: new Date(),
      proofOfDelivery: {
        url: 'https://storage.example/pod.jpg',
        uploadedBy: 'driver-uid',
        capturedAt: '2026-01-01T00:00:00.000',
      },
    }));
    record('b14-T4: proof-of-delivery replay ({id,status,delivered,pod{url,self,iso}},updatedAt}) -> ALLOW', true);
  } catch (e) { record('b14-T4: proof-of-delivery replay ({id,status,delivered,pod{url,self,iso}},updatedAt}) -> ALLOW', false, e.message); }

  // == b22 (STATE-2 / W8.7): capped/bounded provider queries remain provable.
  // The rules gained NO query constraints (request.query is unused), so the
  // orderBy+limit shapes the client now runs must stay ALLOW for the roles
  // that already read these collections. Case names use ASCII arrows to keep
  // this session's edit channel byte-safe.

  // b22-T1: manager bounded history query (branchId == + 24h createdAt window
  // + orderBy createdAt desc + limit 200) -> ALLOW.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    const snap = await db.collection('orders')
      .where('branchId', '==', 'branch-1')
      .where('createdAt', '>=', new Date(Date.now() - 24 * 60 * 60 * 1000))
      .orderBy('createdAt', 'desc')
      .limit(200)
      .get();
    if (snap.size > 0) {
      record('b22-T1: manager 24h history query (+orderBy desc +limit 200) -> ALLOW (' + snap.size + ' docs)', true);
    } else {
      record('b22-T1: manager 24h history query (+orderBy desc +limit 200) -> ALLOW', false, 'query returned 0 docs');
    }
  } catch (e) { record('b22-T1: manager 24h history query (+orderBy desc +limit 200) -> ALLOW', false, e.message); }

  // b22-T2: kitchen bounded FIFO query (branchId == + status IN
  // [confirmed, preparing] + orderBy createdAt + limit 200) -> ALLOW.
  try {
    const db = authedApp('kitchen-uid', 'kitchen@carnama.com', 'kitchen', 'branch-1').firestore();
    const snap = await db.collection('orders')
      .where('branchId', '==', 'branch-1')
      .where('status', 'in', ['confirmed', 'preparing'])
      .orderBy('createdAt')
      .limit(200)
      .get();
    if (snap.size > 0) {
      record('b22-T2: kitchen FIFO query (status IN +orderBy createdAt +limit 200) -> ALLOW (' + snap.size + ' docs)', true);
    } else {
      record('b22-T2: kitchen FIFO query (status IN +orderBy createdAt +limit 200) -> ALLOW', false, 'query returned 0 docs');
    }
  } catch (e) { record('b22-T2: kitchen FIFO query (status IN +orderBy createdAt +limit 200) -> ALLOW', false, e.message); }

  // b22-T3: driver bounded myOrders query (branchId == + assignedDriverId ==
  // + status IN [ready, pickedUp] + orderBy createdAt + limit 100) -> ALLOW.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    const snap = await db.collection('orders')
      .where('branchId', '==', 'branch-1')
      .where('assignedDriverId', '==', 'driver-uid')
      .where('status', 'in', ['ready', 'pickedUp'])
      .orderBy('createdAt')
      .limit(100)
      .get();
    if (snap.size > 0) {
      record('b22-T3: driver bounded myOrders query (+limit 100) -> ALLOW (' + snap.size + ' docs)', true);
    } else {
      record('b22-T3: driver bounded myOrders query (+limit 100) -> ALLOW', false, 'query returned 0 docs');
    }
  } catch (e) { record('b22-T3: driver bounded myOrders query (+limit 100) -> ALLOW', false, e.message); }

  // b22-T4: capped menu streams (public read rule) - the merged/global menu
  // queries (branchId == null + limit 500) remain provable for customers.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    const snap = await db.collection('menus')
      .where('branchId', '==', null)
      .limit(500)
      .get();
    record('b22-T4: global menu null-branch query (+limit 500) -> ALLOW (' + snap.size + ' docs)', true);
  } catch (e) { record('b22-T4: global menu null-branch query (+limit 500) -> ALLOW', false, e.message); }

  // ── PERF-6b: settings/tenant_a_taxRates (owner-managed per-client tax table) ─────
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_taxRates').set({
      clients: {
        'labs.carnama.halalboys': {
          stateRates: { NY: 0.08 },
          defaultRate: 0.05,
        },
      },
    }));
    record('p6b-T1: owner writes valid taxRates -> ALLOW', true);
  } catch (e) { record('p6b-T1: owner writes valid taxRates -> ALLOW', false, e.message); }

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('settings/tenant_a_taxRates').set({ clients: {}, bogus: 1 }));
    record('p6b-T2: unknown top-level key -> DENY', true);
  } catch (e) { record('p6b-T2: unknown top-level key -> DENY', false, e.message); }

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('settings/tenant_a_taxRates').set({ clients: 'nope' }));
    record('p6b-T3: non-map clients -> DENY', true);
  } catch (e) { record('p6b-T3: non-map clients -> DENY', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('settings/tenant_a_taxRates').set({
      clients: { x: { stateRates: { NY: 0.08 }, defaultRate: 0.05 } },
    }));
    record('p6b-T4: non-owner write -> DENY', true);
  } catch (e) { record('p6b-T4: non-owner write -> DENY', false, e.message); }

  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('settings/tenant_a_taxRates').delete());
    record('p6b-T5: delete -> DENY (even owner)', true);
  } catch (e) { record('p6b-T5: delete -> DENY (even owner)', false, e.message); }

  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('settings/tenant_a_taxRates').get());
    record('p6b-T6: authenticated read -> ALLOW', true);
  } catch (e) { record('p6b-T6: authenticated read -> ALLOW', false, e.message); }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── P8 W1 (A-1): TENANT/USER ISOLATION PINS ────────────────────────────────
  // Tenancy is enforced at the PROJECT layer (whitelabel.dart:1205-1211 emits a
  // per-project lib/firebase_options.dart; main.dart:46 passes the shell's OWN
  // DefaultFirebaseOptions) — so cross-TENANT isolation cannot be exercised
  // inside one emulator project. WITHIN a project, isolation is uid/branch.
  // Orders cross-user denial already pinned by T-E4, loyalty by b10-T27/T28 —
  // not restated here (ledger rule). These pins cover the UNPINNED surfaces:
  // carts (zero prior coverage), reservations cross-user, deliveries
  // cross-customer, and the waitlist list-query semantics that
  // streamQueuePosition (waitlist_repository.dart:102-121) computes from.
  // ═══════════════════════════════════════════════════════════════════════════

  // Group seed (admin, rules-bypassed): a carts doc + another user's reservation.
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc('carts/customer-uid').set({
      items: [],
      updatedAt: new Date(),
    });
    await admin.firestore().doc('reservations/w1-res-other').set({
        tenantId: 'tenant_a',
      userId: 'customer2-uid',
      branchId: 'branch-1',
      customerName: 'Other Customer',
      customerPhone: '456',
      startTime: new Date(),
      partySize: 4,
    });
  });

  // W1-T1: customer reads OWN carts doc → ALLOW (uid-keyed surface, rules:578-581).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('carts/customer-uid').get());
    record('W1-T1: customer reads own carts doc → ALLOW', true);
  } catch (e) { record('W1-T1: customer reads own carts doc → ALLOW', false, e.message); }

  // W1-T2: ANOTHER customer reads that carts doc → DENY (uid != doc key).
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('carts/customer-uid').get());
    record('W1-T2: other customer reads carts/customer-uid → DENY', true);
  } catch (e) { record('W1-T2: other customer reads carts/customer-uid → DENY', false, e.message); }

  // W1-T3: customer reads ANOTHER user's reservation → DENY (rules:556-558
  // — customer clause requires resource.data.userId == request.auth.uid).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('reservations/w1-res-other').get());
    record("W1-T3: customer reads another user's reservation → DENY", true);
  } catch (e) { record("W1-T3: customer reads another user's reservation → DENY", false, e.message); }

  // W1-T4 (control): manager blanket-reads the SAME reservation → ALLOW —
  // proves W1-T3's denial is ownership-clause-driven, not a broken read path.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('reservations/w1-res-other').get());
    record('W1-T4: manager reads the same reservation → ALLOW (control)', true);
  } catch (e) { record('W1-T4: manager reads the same reservation → ALLOW (control)', false, e.message); }

  // W1-T5: customer2 reads the GPS doc of customer-uid's order → DENY
  // (rules:611-612 — customer clause resolves orders/{orderId}.customerId).
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('deliveries/order-1').get());
    record("W1-T5: customer2 reads another order's deliveries doc → DENY", true);
  } catch (e) { record("W1-T5: customer2 reads another order's deliveries doc → DENY", false, e.message); }

  // W1-T6 (control): the order's OWN customer reads the GPS doc → ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('deliveries/order-1').get());
    record('W1-T6: own customer reads deliveries/order-1 → ALLOW (control)', true);
  } catch (e) { record('W1-T6: own customer reads deliveries/order-1 → ALLOW (control)', false, e.message); }

  // W1-T7: a customer's branch-only waitlist LIST-QUERY is DENIED whenever the
  // candidate set contains another user's entry. Rules v2 evaluates list
  // queries per candidate document and fails the WHOLE query (rules:691-693 —
  // customer clause requires resource.data.userId == auth.uid; wl-other and
  // t-wl-uid are branch-1 candidates owned by other users). Production
  // semantics = permission-denied; the emulator additionally surfaces an
  // evaluation error on the unconstrained userId field. Either way, the
  // customer-facing streamQueuePosition (waitlist_repository.dart:102-121),
  // which computes position from exactly this branch snapshot, CANNOT work
  // for customers as written — recorded as finding W1-A2 (fail-closed, no
  // data leak; fix is a product decision). PERF-9 T-2 RESOLVED this finding: the
  // customer path is now the two-doc ordinal (own waitlist doc +
  // branches/{bid}/waitlist_meta), pinned by t2-T1..T6 below, and
  // streamQueuePosition was rewritten to match (no list query remains).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.collection('waitlist').where('branchId', '==', 'branch-1').get());
    record('W1-T7: customer branch-only waitlist query denied (others queued) → DENY', true);
  } catch (e) { record('W1-T7: customer branch-only waitlist query denied (others queued) → DENY', false, e.message); }

  // W1-T8 (control): a manager runs the SAME branch-only query → ALLOW
  // (staff blanket read clause) — proves W1-T7's denial is the per-doc
  // ownership clause, not a malformed query.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.collection('waitlist').where('branchId', '==', 'branch-1').get());
    record('W1-T8: manager branch-only waitlist query → ALLOW (control)', true);
  } catch (e) { record('W1-T8: manager branch-only waitlist query → ALLOW (control)', false, e.message); }

  // ======================================================================
  // PERF-9 W2: T-4/B-4 (orders cancel ownership), T-5/B-5 (carts
  // isAppVerified), T-2 (branches/{bid}/waitlist_meta ordinal + the exact
  // W1-T7 scenario -> a PASSING read + a correct ordinal).
  // ======================================================================

  // Seeds: (a) two PENDING orders owned by two different customers, (b) the
  // branch ordinal doc exactly as joinWaitlist writes it
  // (waitlist_repository.dart:118-121 -> {nextTicket, nowServing}).
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc('orders/p9-cancel-own').set({
        tenantId: 'tenant_a',
      customerId: 'customer-uid',
      branchId: 'branch-1',
      status: 'pending',
      totalCents: 2500,
      items: [],
      createdAt: new Date(),
    });
    await admin.firestore().doc('orders/p9-cancel-other').set({
        tenantId: 'tenant_a',
      customerId: 'other-user-uid',
      branchId: 'branch-1',
      status: 'pending',
      totalCents: 1500,
      items: [],
      createdAt: new Date(),
    });
    await admin.firestore()
      .doc('branches/branch-1/waitlist_meta/meta')
      .set({ nextTicket: 3, nowServing: 0 });
  });

  // -- T-4 (B-4): the demo-mode cancel path. order_repository.dart:58-70
  // writes {status:'cancelled', updatedAt} STRAIGHT to orders/{id} when
  // kDemoMode. Pre-fix the update block carried NO customer clause, so a
  // customer's own cancel was DENIED (fail-closed) and nothing pinned that a
  // stranger could not cancel someone else's order.

  // b4-T1: the order's OWN customer sends the real demo payload -> ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('orders/p9-cancel-own').update({
      status: 'cancelled',
      updatedAt: new Date(),
    }));
    record('b4-T1: own customer cancels own order (demo payload) -> ALLOW', true);
  } catch (e) { record('b4-T1: own customer cancels own order (demo payload) -> ALLOW', false, e.message); }

  // b4-T2: a DIFFERENT customer sends the SAME payload at that order -> DENY
  // (the pin that dies if the ownership half of the clause is dropped).
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/p9-cancel-other').update({
      status: 'cancelled',
      updatedAt: new Date(),
    }));
    record("b4-T2: other customer cancels someone else's order -> DENY", true);
  } catch (e) { record("b4-T2: other customer cancels someone else's order -> DENY", false, e.message); }

  // b4-T3: the own customer tries to rewrite the money field -> DENY (the
  // clause is shape-locked to ['status','updatedAt']).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('orders/p9-cancel-own').update({
      status: 'cancelled',
      totalCents: 0,
      updatedAt: new Date(),
    }));
    record('b4-T3: customer cancel + totalCents rewrite -> DENY', true);
  } catch (e) { record('b4-T3: customer cancel + totalCents rewrite -> DENY', false, e.message); }

// -- T-5 (B-5): carts gains isAppVerified() (uniformity with the b10 P-6
  // sweep; carts is a customer-facing personal-data surface -- the GDPR
  // export reads carts/{uid}, data_export_service.dart:119 -- and was the
  // only such surface without the App Check clause).

  // b5-T1 (control): app-verified customer reads + writes OWN cart -> ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('carts/customer-uid').get());
    await assertSucceeds(db.doc('carts/customer-uid').set({ items: [], updatedAt: new Date() }));
    record('b5-T1: app-verified customer reads+writes own cart -> ALLOW', true);
  } catch (e) { record('b5-T1: app-verified customer reads+writes own cart -> ALLOW', false, e.message); }

  // b5-T2: a cart WITHOUT App Check evidence (no app_id, no
  // app_check_token) -> DENY on read AND write. NOTE the FRESH uid: the
  // emulator caches one auth token per uid for the rules unit-testing
  // harness, so re-using an identity that already sent evidence in this run
  // makes assertFails(...get()) FLIP GREEN (observed: it passed while the
  // rules were still un-gated). A uid that never carries evidence cannot hit
  // that cache; the write is a CREATE, so the create-clause gate is pinned.
  try {
    const db = authedApp('p9-nocart-uid', 'nocart@carnama.com', 'customer', '',
      { appId: false, appCheckToken: false }).firestore();
    await assertFails(db.doc('carts/p9-nocart-uid').get());
    await assertFails(db.doc('carts/p9-nocart-uid').set({ items: [], updatedAt: new Date() }));
    record('b5-T2: cart without App Check evidence (read+write) -> DENY', true);
  } catch (e) { record('b5-T2: cart without App Check evidence (read+write) -> DENY', false, e.message); }

  // b5-T3: the App Check TOKEN alone (no app_id) still writes under the
  // RELAXED policy — `isAppVerified()` is `hasAppId() || hasAppCheckToken()`
  // while settings/featureFlags carries no strongAppCheck. This is the pin
  // that dies if the `hasAppCheckToken()` disjunct is deleted (mutating
  // isAppVerified() to `hasAppId()` alone flips b5-T3 to DENY), measured on
  // the emulator: app_id-only AND app_check_token-only both ALLOW, only the
  // COMBINED absence (b5-T2) gates.
  try {
    const db = authedApp('p9-aconly-uid', 'aconly@carnama.com', 'customer', '',
      { appId: false, appCheckToken: true }).firestore();
    await assertSucceeds(db.doc('carts/p9-aconly-uid').set({ items: [], updatedAt: new Date() }));
    record('b5-T3: cart write with app_check_token only (relaxed OR) -> ALLOW', true);
  } catch (e) { record('b5-T3: cart write with app_check_token only (relaxed OR) -> ALLOW', false, e.message); }

  // -- T-2: the take-a-ticket ordinal. Customer position =
  // myTicket - nowServing - 1, computed LOCALLY from two READABLE docs (the
  // guest's OWN waitlist doc + branches/{bid}/waitlist_meta). This block runs
  // the exact W1-T7 scenario (wl-1 AND wl-other queued on branch-1): the old
  // branch LIST query stays DENIED (W1-T7 above) and the two-doc path PASSES.

  // t2-T1: customer reads OWN guest doc (wl-1) -> ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('waitlist/wl-1').get());
    record('t2-T1: customer reads own waitlist doc (2+ queued) -> ALLOW', true);
  } catch (e) { record('t2-T1: customer reads own waitlist doc (2+ queued) -> ALLOW', false, e.message); }

  // t2-T2: the same customer reads the branch ordinal doc -> ALLOW (pre-fix
  // this surface had no rule at all -> permission denied).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('branches/branch-1/waitlist_meta/meta').get());
    record('t2-T2: customer reads branches/{bid}/waitlist_meta -> ALLOW', true);
  } catch (e) { record('t2-T2: customer reads branches/{bid}/waitlist_meta -> ALLOW', false, e.message); }

  // t2-T3: the JOIN transaction writes the ordinal doc ({nextTicket,
  // nowServing}) from the customer's own client -> ALLOW.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('branches/branch-1/waitlist_meta/meta')
      .set({ nextTicket: 4, nowServing: 0 }));
    record('t2-T3: customer join transaction writes waitlist_meta -> ALLOW', true);
  } catch (e) { record('t2-T3: customer join transaction writes waitlist_meta -> ALLOW', false, e.message); }

  // t2-T4: shape lock -- an extra key, or a negative ordinal -> DENY.
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertFails(db.doc('branches/branch-1/waitlist_meta/meta')
      .set({ nextTicket: 4, nowServing: 0, hostile: true }));
    await assertFails(db.doc('branches/branch-1/waitlist_meta/meta')
      .set({ nextTicket: 4, nowServing: -5 }));
    record('t2-T4: waitlist_meta shape violation -> DENY', true);
  } catch (e) { record('t2-T4: waitlist_meta shape violation -> DENY', false, e.message); }

  // t2-T5 (control): the STAFF serve path advances the ordinal -> ALLOW.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('branches/branch-1/waitlist_meta/meta')
      .set({ nextTicket: 4, nowServing: 1 }));
    record('t2-T5: staff serve advances waitlist_meta -> ALLOW (control)', true);
  } catch (e) { record('t2-T5: staff serve advances waitlist_meta -> ALLOW (control)', false, e.message); }

  // t2-T6: unauthenticated read of the ordinal doc -> DENY (no public leak).
  try {
    const db = unauthedApp().firestore();
    await assertFails(db.doc('branches/branch-1/waitlist_meta/meta').get());
    record('t2-T6: unauthenticated waitlist_meta read -> DENY', true);
  } catch (e) { record('t2-T6: unauthenticated waitlist_meta read -> DENY', false, e.message); }


  // ── PERF-9 coordinator closure: menu_overrides overlay lane (T-3) ────
  // W1's T-3 merges branches/{bid}/menu_overrides/{itemId} over the global
  // item. The lane previously had NO rules clause => denied for every
  // reader, silently inert at runtime (fail-soft menu, dead overrides).
  // Postures mirror /menus: public read; owner ∥ branch-scoped manager
  // writes, shape-locked by isValidMenuOverride.

  // mo-T1: unauthenticated read of an overlay doc -> ALLOW (public, mirrors
  // unauthenticated menus browsing).
  try {
    await assertSucceeds(
      unauthedApp().firestore().doc('branches/branch-1/menu_overrides/item-1').get());
    record('mo-T1: unauthenticated menu_overrides read -> ALLOW (mirrors menus)', true);
  } catch (e) { record('mo-T1: unauthenticated menu_overrides read -> ALLOW (mirrors menus)', false, e.message); }

  // mo-T2: app-verified customer reads the overlay -> ALLOW (the T-3 lane
  // merged_menu_provider serves the effective price/availability from).
  try {
    const db = authedApp('customer-uid', 'customer@carnama.com', 'customer').firestore();
    await assertSucceeds(db.doc('branches/branch-1/menu_overrides/item-1').get());
    record('mo-T2: app-verified customer menu_overrides read -> ALLOW', true);
  } catch (e) { record('mo-T2: app-verified customer menu_overrides read -> ALLOW', false, e.message); }

  // mo-T3: owner creates a valid partial overlay -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertSucceeds(db.doc('branches/branch-1/menu_overrides/item-1')
      .set({ priceCents: 1500 }));
    record('mo-T3: owner creates valid menu_overrides doc -> ALLOW', true);
  } catch (e) { record('mo-T3: owner creates valid menu_overrides doc -> ALLOW', false, e.message); }

  // mo-T4: branch-1 manager creates a valid partial overlay -> ALLOW.
  try {
    const db = authedApp('manager-uid', 'manager@carnama.com', 'manager', 'branch-1').firestore();
    await assertSucceeds(db.doc('branches/branch-1/menu_overrides/item-1')
      .set({ isAvailable: false }));
    record('mo-T4: branch-1 manager creates valid overlay -> ALLOW', true);
  } catch (e) { record('mo-T4: branch-1 manager creates valid overlay -> ALLOW', false, e.message); }

  // mo-T5 (control): plain customer write -> DENY.
  try {
    const db = authedApp('customer2-uid', 'customer2@carnama.com', 'customer').firestore();
    await assertFails(db.doc('branches/branch-1/menu_overrides/item-2').set({ priceCents: 1 }));
    record('mo-T5: customer menu_overrides write -> DENY', true);
  } catch (e) { record('mo-T5: customer menu_overrides write -> DENY', false, e.message); }

  // mo-T6 (control): hostile shape (priceCents as string) by owner -> DENY
  // (the shape lock; a hostile doc must never reach the overlay merger).
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner').firestore();
    await assertFails(db.doc('branches/branch-1/menu_overrides/item-2')
      .set({ priceCents: 'free' }));
    record('mo-T6: hostile overlay shape (priceCents string) -> DENY', true);
  } catch (e) { record('mo-T6: hostile overlay shape (priceCents string) -> DENY', false, e.message); }

  // ══ t78 (PERF-10 T-7): App-Check posture sweep — the remaining carts-class
  // surfaces. PERF-9 T-5 fixed carts (b5-T1..T3); this block pins the write
  // surfaces the b10 P-6 "App Check on every surface" sweep missed:
  // deliveries, driverLocations, proof_of_delivery, branches (+ branch config),
  // promotions, promoCodes, settings/featureFlags, notification_queue, admins.
  // RED pins use a context with NEITHER app_id NOR app_check_token: in relaxed
  // mode (strongAppCheckEnabled() == false) isAppVerified() is an OR, so the
  // flagless context must be DENIED once the clause carries isAppVerified().
  // Pre-fix these writes are ALLOWED (suite goes RED); post-fix they are
  // DENIED. Controls use the default (both flags) context and must stay ALLOW.
  const t78NoFlags = { appId: false, appCheckToken: false };

  // t78-AC1 (red->green): flagless driver writes deliveries/{orderId} -> DENY.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1', t78NoFlags).firestore();
    await assertFails(db.doc('deliveries/order-2').set({
      lat: 1.0, lng: 2.0, heading: 0, speed: 0, timestamp: new Date(),
    }));
    record('t78-AC1: flagless driver writes deliveries -> DENY', true);
  } catch (e) { record('t78-AC1: flagless driver writes deliveries -> DENY', false, e.message); }

  // t78-CTL1 (control): flagged driver writes deliveries/order-2 -> ALLOW.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('deliveries/order-2').set({
      lat: 1.0, lng: 2.0, heading: 0, speed: 0, timestamp: new Date(),
    }));
    record('t78-CTL1: flagged driver writes deliveries -> ALLOW', true);
  } catch (e) { record('t78-CTL1: flagged driver writes deliveries -> ALLOW', false, e.message); }

  // t78-AC2 (red->green): flagless driver creates driverLocations/self -> DENY.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1', t78NoFlags).firestore();
    await assertFails(db.doc('driverLocations/driver-uid').set({ lat: 1.0, lng: 2.0 }));
    record('t78-AC2: flagless driver creates driverLocations/self -> DENY', true);
  } catch (e) { record('t78-AC2: flagless driver creates driverLocations/self -> DENY', false, e.message); }

  // t78-CTL2 (control): flagged driver creates driverLocations/self -> ALLOW
  // (the legacy self-write lane is preserved, now App-Check gated).
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('driverLocations/driver-uid').set({ lat: 1.0, lng: 2.0 }));
    record('t78-CTL2: flagged driver creates driverLocations/self -> ALLOW', true);
  } catch (e) { record('t78-CTL2: flagged driver creates driverLocations/self -> ALLOW', false, e.message); }

  // t78-CTL2b (control): flagged driver CANNOT write ANOTHER driver's
  // driverLocations doc (self-only is retained through the refactor).
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('driverLocations/driver2-uid').set({ lat: 1.0, lng: 2.0 }));
    record('t78-CTL2b: driver writes other driverLocations doc -> DENY', true);
  } catch (e) { record('t78-CTL2b: driver writes other driverLocations doc -> DENY', false, e.message); }

  // t78-AC2b (red->green): flagless driver DELETES own driverLocations -> DENY
  // (the old `allow write` included delete; erasure is Admin-SDK only).
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1', t78NoFlags).firestore();
    await assertFails(db.doc('driverLocations/driver-uid').delete());
    record('t78-AC2b: flagless driver deletes own driverLocations -> DENY', true);
  } catch (e) { record('t78-AC2b: flagless driver deletes own driverLocations -> DENY', false, e.message); }

  // t78-AC4 (red->green): flagless driver creates proof_of_delivery -> DENY.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1', t78NoFlags).firestore();
    await assertFails(db.doc('proof_of_delivery/pod-t78').set({
      driverId: 'driver-uid', orderId: 'order-2', url: 'https://example.com/p.jpg',
    }));
    record('t78-AC4: flagless driver creates proof_of_delivery -> DENY', true);
  } catch (e) { record('t78-AC4: flagless driver creates proof_of_delivery -> DENY', false, e.message); }

  // t78-CTL3 (control): flagged driver creates proof_of_delivery -> ALLOW.
  try {
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertSucceeds(db.doc('proof_of_delivery/pod-t78c').set({
      driverId: 'driver-uid', orderId: 'order-2', url: 'https://example.com/p.jpg',
    }));
    record('t78-CTL3: flagged driver creates proof_of_delivery -> ALLOW', true);
  } catch (e) { record('t78-CTL3: flagged driver creates proof_of_delivery -> ALLOW', false, e.message); }

  // t78-NEG1 (control): the POD ASSIGNMENT gate is retained — a driver with a
  // valid App Check posture still cannot create POD for an order NOT assigned
  // to them (seeded unassigned order t78-unassigned).
  try {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('orders/t78-unassigned').set({
        tenantId: 'tenant_a',
        customerId: 'customer-uid', branchId: 'branch-1', status: 'ready',
        totalCents: 1000, items: [],
      });
    });
    const db = authedApp('driver-uid', 'driver@carnama.com', 'delivery', 'branch-1').firestore();
    await assertFails(db.doc('proof_of_delivery/pod-t78-neg').set({
      driverId: 'driver-uid', orderId: 't78-unassigned', url: 'https://example.com/p.jpg',
    }));
    record('t78-NEG1: POD create for unassigned order -> DENY', true);
  } catch (e) {
    record('t78-NEG1: POD create for unassigned order -> DENY', false, e.message);
  } finally {
    await testEnv.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc('orders/t78-unassigned').delete();
    });
  }

  // t78-AC5 (red->green): flagless owner creates branches/{id} -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('branches/branch-t78ac5').set({ name: 'X', latitude: 1, longitude: 2 }));
    record('t78-AC5: flagless owner creates branches doc -> DENY', true);
  } catch (e) { record('t78-AC5: flagless owner creates branches doc -> DENY', false, e.message); }

  // t78-CTL4 (control): flagged owner creates branches/{id} -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('branches/branch-t78ctl4').set({ name: 'X', latitude: 1, longitude: 2 }));
    record('t78-CTL4: flagged owner creates branches doc -> ALLOW', true);
  } catch (e) { record('t78-CTL4: flagged owner creates branches doc -> ALLOW', false, e.message); }

  // t78-AC6 (red->green): flagless owner writes branches/{id}/config -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('branches/branch-t78ctl4/config/hours').set({ open: '9:00' }));
    record('t78-AC6: flagless owner writes branch config -> DENY', true);
  } catch (e) { record('t78-AC6: flagless owner writes branch config -> DENY', false, e.message); }

  // t78-CTL5 (control): flagged owner writes branches/{id}/config -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('branches/branch-t78ctl4/config/hours').set({ open: '9:00' }));
    record('t78-CTL5: flagged owner writes branch config -> ALLOW', true);
  } catch (e) { record('t78-CTL5: flagged owner writes branch config -> ALLOW', false, e.message); }

  // t78-AC7 (red->green): flagless owner creates promotions -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('promotions/t78ac7').set({ title: 'X' }));
    record('t78-AC7: flagless owner creates promotions -> DENY', true);
  } catch (e) { record('t78-AC7: flagless owner creates promotions -> DENY', false, e.message); }

  // t78-CTL6 (control): flagged owner creates promotions -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('promotions/t78ctl6').set({ title: 'X' }));
    record('t78-CTL6: flagged owner creates promotions -> ALLOW', true);
  } catch (e) { record('t78-CTL6: flagged owner creates promotions -> ALLOW', false, e.message); }

  // t78-AC8 (red->green): flagless owner creates promoCodes -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('promoCodes/T78AC8').set({ code: 'T78AC8', discountCents: 100 }));
    record('t78-AC8: flagless owner creates promoCodes -> DENY', true);
  } catch (e) { record('t78-AC8: flagless owner creates promoCodes -> DENY', false, e.message); }

  // t78-CTL7 (control): flagged owner creates promoCodes -> ALLOW (T25 posture).
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('promoCodes/T78CTL7').set({ code: 'T78CTL7', discountCents: 100 }));
    record('t78-CTL7: flagged owner creates promoCodes -> ALLOW', true);
  } catch (e) { record('t78-CTL7: flagged owner creates promoCodes -> ALLOW', false, e.message); }

  // t78-AC9 (red->green): flagless owner updates settings/featureFlags -> DENY
  // (the flag doc that controls strict App Check must itself be App-Check gated).
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('settings/featureFlags').set({ liveTracking: false }, { merge: true }));
    record('t78-AC9: flagless owner updates settings/featureFlags -> DENY', true);
  } catch (e) { record('t78-AC9: flagless owner updates settings/featureFlags -> DENY', false, e.message); }

  // t78-CTL8 (control): flagged owner updates settings/featureFlags -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('settings/featureFlags').set({ liveTracking: true }, { merge: true }));
    record('t78-CTL8: flagged owner updates settings/featureFlags -> ALLOW', true);
  } catch (e) { record('t78-CTL8: flagged owner updates settings/featureFlags -> ALLOW', false, e.message); }

  // t78-AC10 (red->green): flagless owner creates notification_queue -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('notification_queue/t78ac10').set({ title: 'X' }));
    record('t78-AC10: flagless owner creates notification_queue -> DENY', true);
  } catch (e) { record('t78-AC10: flagless owner creates notification_queue -> DENY', false, e.message); }

  // t78-CTL9 (control): flagged owner creates notification_queue -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('notification_queue/t78ctl9').set({ title: 'X' }));
    record('t78-CTL9: flagged owner creates notification_queue -> ALLOW', true);
  } catch (e) { record('t78-CTL9: flagged owner creates notification_queue -> ALLOW', false, e.message); }

  // t78-AC11 (red->green): flagless owner writes admins -> DENY.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '', t78NoFlags).firestore();
    await assertFails(db.doc('admins/t78ac11').set({ note: 'X', tenantId: 'tenant_a' }));
    record('t78-AC11: flagless owner writes admins -> DENY', true);
  } catch (e) { record('t78-AC11: flagless owner writes admins -> DENY', false, e.message); }

  // t78-CTL10 (control): flagged owner writes admins -> ALLOW.
  try {
    const db = authedApp('owner-uid', 'owner@carnama.com', 'owner', '').firestore();
    await assertSucceeds(db.doc('admins/t78ctl10').set({ note: 'X', tenantId: 'tenant_a' }));
    record('t78-CTL10: flagged owner writes admins -> ALLOW', true);
  } catch (e) { record('t78-CTL10: flagged owner writes admins -> ALLOW', false, e.message); }

  // ── Summary ──────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════════════════');
  console.log('  FIRESTORE RULES TEST RESULTS');
  console.log('══════════════════════════════════════════════════════');
  results.forEach((r) => console.log(r));
  console.log('──────────────────────────────────────────────────────');
  console.log(`  PASSED: ${passed}  FAILED: ${failed}  TOTAL: ${passed + failed}`);
  console.log('══════════════════════════════════════════════════════\n');

  if (failed > 0) {
    process.exitCode = 1;
  }
}

// ── Main ───────────────────────────────────────────────────────────────
(async () => {
  try {
    // The emulator's port is chosen by the runner (tool/rules_harness.mjs) and
    // exported here; the 8080 fallback keeps a manual `npm run test:rules` working.
    const emulator = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
    const [emulatorHost, emulatorPort] = emulator.split(':');
    testEnv = await initializeTestEnvironment({
      projectId: 'demo-carnama',
      firestore: {
        host: emulatorHost,
        port: Number(emulatorPort),
        rules,
      },
    });

    await seed();
    await runTests();
  } catch (e) {
    console.error('FATAL:', e);
    process.exitCode = 1;
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
    }
  }
})();
