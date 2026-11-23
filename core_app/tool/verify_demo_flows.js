/**
 * verify_demo_flows.js — Phase 0 flow verification against the RUNNING emulator.
 *
 * Layers (all against 127.0.0.1 emulators, project resturants-8547d):
 *   L1 LOGIN — real Auth-emulator sign-in for every seeded account (firebase JS
 *      SDK); asserts the ID token carries the `role` custom claim.
 *   L2 GUEST+CART — real Firestore SDK under the DEPLOYED rules: guest menu /
 *      branches / featureFlags reads (public), customer cart write on own uid,
 *      DENIED read of another uid's cart.
 *   L3 ROLE GATES — @firebase/rules-unit-testing contexts on the RUNNING
 *      emulator (harness B6-5 claim shape: app_id + app_check_token, i.e. the
 *      production App-Check-attested client claims) driving the REAL staff
 *      order lifecycle, dashboard reads/writes and menu-manager writes.
 *   L4 MONEY+GDPR — the REAL compiled functions (functions/lib/index.js):
 *      server re-pricing with modifier upcharges (tamper rejected), the Stripe
 *      boundary (fail-closed, no STRIPE_SECRET_KEY in the emulator), and a real
 *      GDPR erasure (eraseUserData) for a throwaway account.
 *
 * Screen-level flows are proven separately by targeted flutter tests (see
 * docs/DEMO_PHASE0_LOG.md for the mapping).
 *
 * Run (from core_app/, emulator running, seed applied):
 *   node tool/verify_demo_flows.js
 */
'use strict';

const path = require('path');
const assert = require('node:assert/strict');

// firebase-admin lives only in functions/node_modules (see seed_demo_data.js).
module.paths.push(path.join(__dirname, '..', 'functions', 'node_modules'));

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.DEMO_PROJECT_ID || 'resturants-8547d';
const AUTH_URL = 'http://127.0.0.1:9099';
const FS_HOST = '127.0.0.1';
const FS_PORT = 8080;

const ACCOUNTS = {
  owner: { email: 'admin@carnama.com', password: 'AdminPass123', role: 'owner' },
  kitchen: { email: 'kitchen@carnama.com', password: 'KitchenPass123', role: 'kitchen' },
  delivery: { email: 'delivery@carnama.com', password: 'DeliveryPass123', role: 'delivery' },
  customer: { email: 'customer@carnama.com', password: 'CustomerPass123', role: 'customer' },
};

let passed = 0;
let failed = 0;
const results = [];
function ok(flow, name) {
  passed += 1;
  results.push({ flow, name, verdict: 'PASS' });
  console.log(`  ✔ [${flow}] ${name}`);
}
function bad(flow, name, err) {
  failed += 1;
  results.push({ flow, name, verdict: 'FAIL', error: String(err && err.message ? err.message : err) });
  console.error(`  ✖ [${flow}] ${name} — ${err && err.message ? err.message : err}`);
}
async function check(flow, name, fn) {
  try { await fn(); ok(flow, name); } catch (e) { bad(flow, name, e); }
}

async function main() {
  console.log(`[verify_demo_flows] project ${PROJECT_ID} | auth ${AUTH_URL} | firestore ${FS_HOST}:${FS_PORT}`);

  // ── L1: LOGIN (real Auth emulator) ────────────────────────────────────────
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInWithEmailAndPassword, signOut } = require('firebase/auth');
  const { getFirestore, connectFirestoreEmulator, collection, getDocs, doc, getDoc, setDoc } = require('firebase/firestore');

  // Placeholder apiKey/appId: with connectAuthEmulator/connectFirestoreEmulator
  // ALL traffic goes to the local emulators; the values are never validated.
  // ARCH-1 (namespace fix): the Auth emulator resolves the request's project
  // from the documented `demo-<projectId>` apiKey convention — a static
  // 'demo-api-key' silently binds every JS-SDK auth request to the emulator's
  // default project, which breaks the GCLOUD_PROJECT namespace override (the
  // halal shell's project). Derive the key from PROJECT_ID so the driver
  // signs in against exactly the project it was pointed at.
  const app = initializeApp({ projectId: PROJECT_ID, apiKey: 'demo-' + PROJECT_ID, appId: 'demo-app-id' });
  const auth = getAuth(app);
  connectAuthEmulator(auth, AUTH_URL, { disableWarnings: true });
  const fsDb = getFirestore(app);
  connectFirestoreEmulator(fsDb, FS_HOST, FS_PORT);

  const uids = {};
  for (const [key, acc] of Object.entries(ACCOUNTS)) {
    await check('login', `sign-in ${acc.email} (expect role=${acc.role} claim)`, async () => {
      const cred = await signInWithEmailAndPassword(auth, acc.email, acc.password);
      const token = await cred.user.getIdToken();
      assert.ok(token && token.length > 20, 'no ID token');
      const claims = (await cred.user.getIdTokenResult()).claims;
      assert.equal(claims.role, acc.role, `claim role=${claims.role}`);
      uids[key] = cred.user.uid;
      await signOut(auth);
    });
  }
  console.log(`  (uids: owner=${uids.owner} kitchen=${uids.kitchen} delivery=${uids.delivery} customer=${uids.customer})`);

  // ── L2: GUEST + CART (real SDK, real rules) ──────────────────────────────
  await check('menu-browse', 'guest (signed-out) menu browse — public read', async () => {
    const snap = await getDocs(collection(fsDb, 'menus'));
    assert.ok(snap.size >= 12, `expected >=12 menus, got ${snap.size}`);
  });
  await check('splash/config', 'guest reads settings/featureFlags (public, pre-login gating)', async () => {
    const snap = await getDoc(doc(fsDb, 'settings', 'featureFlags'));
    assert.ok(snap.exists, 'featureFlags missing');
    assert.equal(snap.data().smartReorder, true);
    assert.equal(snap.data().promoCode, true);
    assert.equal(snap.data().deliveryEnabled, true);
  });
  await check('splash/config', 'guest reads branches (public branch picker)', async () => {
    const snap = await getDocs(collection(fsDb, 'branches'));
    assert.ok(snap.size >= 2, `expected >=2 branches, got ${snap.size}`);
  });
  await check('cart', 'customer cart write + read own uid (with modifier selections)', async () => {
    await signInWithEmailAndPassword(auth, ACCOUNTS.customer.email, ACCOUNTS.customer.password);
    await setDoc(doc(fsDb, 'carts', uids.customer), {
      items: [{
        id: 'demo_smash_burger',
        name: 'Classic Smash Burger',
        priceCents: 1099,
        quantity: 1,
        selectedOptions: [{ id: 'size_large', name: 'Large', upchargeCents: 150 }],
      }],
      branchId: 'branch_main',
      updatedAt: new Date(),
    });
    const snap = await getDoc(doc(fsDb, 'carts', uids.customer));
    assert.ok(snap.exists, 'cart doc not readable after write');
    assert.equal(snap.data().items[0].selectedOptions[0].upchargeCents, 150);
    await signOut(auth);
  });
  await check('role-gates', 'customer cart read of ANOTHER uid denied (carts rule)', async () => {
    await signInWithEmailAndPassword(auth, ACCOUNTS.customer.email, ACCOUNTS.customer.password);
    let denied = false;
    try {
      await getDoc(doc(fsDb, 'carts', uids.kitchen));
    } catch (e) {
      denied = String(e.code || e.message).includes('permission');
    }
    await signOut(auth);
    assert.ok(denied, 'expected permission-denied on foreign cart');
  });


  // ── L3: ROLE GATES (rules-unit-testing on the RUNNING emulator) ─────────
  const fs = require('fs');
  const { initializeTestEnvironment, assertFails, assertSucceeds } =
    require('@firebase/rules-unit-testing');
  const adminAppMod = require('firebase-admin/app');
  const adminFsMod = require('firebase-admin/firestore');
  adminAppMod.initializeApp({ projectId: PROJECT_ID }, 'flow-admin');
  const adminDb = adminFsMod.getFirestore(adminAppMod.getApp('flow-admin'));

  const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: FS_HOST, port: FS_PORT },
  });
  // Post-init sanity: rules-unit-testing must NOT have wiped the demo seed.
  const menuCount = (await adminDb.collection('menus').get()).size;
  assert.ok(menuCount >= 12, `seed wiped by test env init (menus=${menuCount})`);

  // Harness B6-5 claim shape — what an App-Check-attested production client's
  // token carries (relaxed OR mode requires app_id OR app_check_token).
  function staffCtx(uid, email, role, branchId) {
    const token = {
      sub: uid,
      email,
      firebase: { sign_in_provider: 'password', app_check_token: 'demo-app-check' },
      app_id: 'demo-app-id',
    };
    if (role) token.role = role;
    if (branchId) token.branchId = branchId;
    return testEnv.authenticatedContext(uid, token);
  }

  const customerDb = staffCtx(uids.customer, ACCOUNTS.customer.email, 'customer', '').firestore();
  const kitchenDb = staffCtx(uids.kitchen, ACCOUNTS.kitchen.email, 'kitchen', 'branch_main').firestore();
  const deliveryDb = staffCtx(uids.delivery, ACCOUNTS.delivery.email, 'delivery', 'branch_main').firestore();
  const ownerDb = staffCtx(uids.owner, ACCOUNTS.owner.email, 'owner', '').firestore();

  // Re-run safe: remove flow artifacts from previous runs before exercising
  // the create paths (a second set() is an UPDATE and would hit the update
  // rules instead of the create rules).
  await adminDb.collection('orders').doc('demo_flow_pending').delete().catch(() => {});
  await adminDb.collection('orders').doc('demo_flow_confirmed').delete().catch(() => {});
  await adminDb.collection('menus').doc('demo_flow_special').delete().catch(() => {});

  // Customer places an order (checkout flow under real rules).
  await check('checkout-ui', 'customer order create (pending, own customerId) ALLOW', async () => {
    await assertSucceeds(customerDb.collection('orders').doc('demo_flow_pending').set({
      customerId: uids.customer,
      branchId: 'branch_main',
      totalCents: 1348,
      status: 'pending',
      items: [{ id: 'demo_smash_burger', priceCents: 1099, quantity: 1 }],
      createdAt: new Date(),
    }));
  });

  // Post-payment "confirmed" order (server/Admin-SDK state, as after a charge).
  await adminDb.collection('orders').doc('demo_flow_confirmed').set({
    customerId: uids.customer,
    branchId: 'branch_main',
    totalCents: 1249,
    status: 'confirmed',
    items: [{ id: 'demo_smash_burger', priceCents: 1249, quantity: 1 }],
    createdAt: new Date(),
  });

  await check('role-gates', 'kitchen CANNOT read a pending (not-yet-confirmed) order', async () => {
    await assertFails(kitchenDb.collection('orders').doc('demo_flow_pending').get());
  });
  await check('role-gates', 'kitchen reads confirmed own-branch order ALLOW (kitchen dashboard)', async () => {
    await assertSucceeds(kitchenDb.collection('orders').doc('demo_flow_confirmed').get());
  });
  await check('role-gates', 'kitchen status confirmed→preparing {status,updatedAt} ALLOW', async () => {
    await assertSucceeds(kitchenDb.collection('orders').doc('demo_flow_confirmed').update({
      status: 'preparing',
      updatedAt: new Date(),
    }));
  });
  await check('role-gates', 'kitchen writing totalCents DENIED (fixed-shape ops write)', async () => {
    await assertFails(kitchenDb.collection('orders').doc('demo_flow_confirmed').update({
      status: 'preparing',
      totalCents: 1,
      updatedAt: new Date(),
    }));
  });
  await check('role-gates', 'kitchen menu item create DENIED', async () => {
    await assertFails(kitchenDb.collection('menus').doc('demo_kitchen_item').set({ name: 'x', priceCents: 1, branchId: 'branch_main' }));
  });
  await check('role-gates', 'kitchen preparing→ready {status,updatedAt} ALLOW', async () => {
    await assertSucceeds(kitchenDb.collection('orders').doc('demo_flow_confirmed').update({
      status: 'ready',
      updatedAt: new Date(),
    }));
  });
  await check('role-gates', 'delivery claims unassigned ready order → pickedUp ALLOW', async () => {
    await assertSucceeds(deliveryDb.collection('orders').doc('demo_flow_confirmed').update({
      assignedDriverId: uids.delivery,
      status: 'pickedUp',
      updatedAt: new Date(),
    }));
  });
  await check('role-gates', 'delivery menu item create DENIED', async () => {
    await assertFails(deliveryDb.collection('menus').doc('demo_driver_item').set({ name: 'x', priceCents: 1, branchId: 'branch_main' }));
  });
  await check('owner-dashboard', 'owner reads ANY order ALLOW', async () => {
    await assertSucceeds(ownerDb.collection('orders').doc('demo_flow_pending').get());
  });
  await check('owner-dashboard', 'owner reads ANY user ALLOW', async () => {
    await assertSucceeds(ownerDb.collection('users').doc(uids.kitchen).get());
  });
  await check('role-gates', 'customer reads ANOTHER user DENIED', async () => {
    await assertFails(customerDb.collection('users').doc(uids.kitchen).get());
  });
  await check('owner-dashboard', 'owner assigns staff branch (users.branchId write) ALLOW', async () => {
    await assertSucceeds(ownerDb.collection('users').doc(uids.delivery).update({ branchId: 'branch_main' }));
  });
  await check('admin-menu-manager', 'owner menu item create ALLOW', async () => {
    await assertSucceeds(ownerDb.collection('menus').doc('demo_flow_special').set({
      name: 'Demo Special', description: 'Owner-created via admin menu manager flow',
      priceCents: 499, category: 'Sides', imageUrl: '', tags: ['Demo'],
      isAvailable: true, quantityRemaining: null, modifiers: [], branchId: 'branch_main',
    }));
  });
  await check('admin-menu-manager', 'owner featureFlags write ALLOW (TierFlagManagerScreen path)', async () => {
    await assertSucceeds(ownerDb.collection('settings').doc('featureFlags').update({ tourMode: true }));
  });
  await check('gdpr', 'customer creates own deletion_requests marker ALLOW (GDPR screen)', async () => {
    await assertSucceeds(customerDb.collection('deletion_requests').doc(uids.customer).set({
      requestedAt: new Date(), status: 'requested',
    }));
  });



  // ── L4: MONEY PATH + STRIPE BOUNDARY + GDPR ERASURE (real functions) ────
  // Same wiring as functions/scripts/money_emulator_check.js:36-51: the env
  // vars must exist BEFORE the compiled module initializes its admin app.
  process.env.GCLOUD_PROJECT = PROJECT_ID;
  process.env.FIREBASE_CONFIG = JSON.stringify({
    projectId: PROJECT_ID,
    storageBucket: `${PROJECT_ID}.appspot.com`,
  });
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
  // GDPR erasure deletes user files via admin.storage() — must target the
  // Storage emulator, never real GCS.
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
  const functions = require('../functions/lib/index.js');

  await check('cart', 'server re-prices cart lines INCL. modifier upcharges; tampered total DENIED', async () => {
    // Client claims priceCents 999 but the menu doc (1099) + selected Large
    // upcharge (150) re-derive 1249 — the charge must fail closed BEFORE Stripe.
    let code = '';
    try {
      await functions.createChargeIntentCore({
        items: [{
          id: 'demo_smash_burger',
          priceCents: 999,
          quantity: 1,
          selectedOptions: [{ id: 'size_large', upchargeCents: 150 }],
        }],
        idempotencyKey: 'demo-flow-tamper',
        tipCents: 0,
        deliveryFeeCents: 299,
        stateCode: 'DEFAULT',
        clientId: 'labs.carnama.halalboys',
        userId: uids.customer,
      });
    } catch (e) {
      code = e.code || '';
    }
    assert.equal(code, 'failed-precondition', `expected failed-precondition, got '${code}'`);
  });

  await check('checkout-ui', 'Stripe boundary: honest fail-closed stop (no STRIPE_SECRET_KEY in emulator)', async () => {
    // Correct client price (1099 base + 150 Large upcharge = 1249): the server
    // accepts the pricing, derives tax/fee, then hits the Stripe seam — with
    // no key configured the charge CANNOT silently succeed (Rule 5).
    let stripeError = null;
    try {
      await functions.createChargeIntentCore({
        items: [{
          id: 'demo_smash_burger',
          // payment.ts:811-820: priceCents = BASE unit price (1099); the
          // server adds the Large upcharge (150) on top -> 1249.
          priceCents: 1099,
          quantity: 1,
          selectedOptions: [{ id: 'size_large', upchargeCents: 150 }],
        }],
        idempotencyKey: 'demo-flow-stripe',
        tipCents: 0,
        deliveryFeeCents: 299,
        stateCode: 'DEFAULT',
        clientId: 'labs.carnama.halalboys',
        userId: uids.customer,
      });
    } catch (e) {
      stripeError = e;
    }
    assert.ok(stripeError, 'expected the Stripe boundary to fail, got success');
    const msg = String(stripeError.message || stripeError);
    assert.match(msg, /api[_ ]?key|authenticator|stripe/i, `unexpected error: ${msg}`);
    console.log(`        (Stripe boundary error: ${msg.slice(0, 90)})`);
  });

  await check('gdpr', 'GDPR erasure (eraseUserData) removes docs + auth user for a throwaway account', async () => {
    const adminAuth = require('firebase-admin/auth');
    // 1. Throwaway auth user + seeded user-owned docs.
    let uid;
    try {
      uid = (await adminAuth.getAuth().createUser({
        email: 'e2e_gdpr@carnama.com', password: 'E2eGdpr123!', displayName: 'GDPR Throwaway',
      })).uid;
    } catch {
      uid = (await adminAuth.getAuth().getUserByEmail('e2e_gdpr@carnama.com')).uid;
    }
    await adminDb.collection('users').doc(uid).set({ id: uid, email: 'e2e_gdpr@carnama.com', role: 'customer', loyaltyPoints: 5 });
    await adminDb.collection('carts').doc(uid).set({ items: [{ id: 'demo_baklava', quantity: 1 }] });
    // 2. Real erasure via the production function (collectUserDocs covers
    //    carts/{uid} index.ts:334 + users/{uid} index.ts:340) + real auth delete.
    await functions.eraseUserData(adminDb, uid, async (u) => {
      await adminAuth.getAuth().deleteUser(u);
    });
    // 3. Verify: docs gone, marker retained (audit proof, rules delete:false),
    //    auth account gone.
    assert.ok(!(await adminDb.collection('users').doc(uid).get()).exists, 'users doc should be erased');
    assert.ok(!(await adminDb.collection('carts').doc(uid).get()).exists, 'carts doc should be erased');
    const marker = await adminDb.collection('deletion_requests').doc(uid).get();
    assert.ok(marker.exists, 'deletion_requests marker must remain');
    let authGone = false;
    try { await adminAuth.getAuth().getUser(uid); } catch { authGone = true; }
    assert.ok(authGone, 'auth user should be deleted');
  });


  // ── Summary ───────────────────────────────────────────────────────────────
  console.log(`\n[verify_demo_flows] PASSED: ${passed}  FAILED: ${failed}`);
  if (failed > 0) {
    for (const r of results.filter((x) => x.verdict === 'FAIL')) {
      console.error(`  FAIL [${r.flow}] ${r.name} — ${r.error}`);
    }
    process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('[verify_demo_flows] FATAL:', e);
  process.exit(1);
});
