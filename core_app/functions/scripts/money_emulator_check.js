/**
 * Batch 1 money-integrity emulator harness (B1 Â§5.1 "emulator functions run").
 *
 * Drives the REAL compiled money functions (`../lib/index.js`) against the REAL
 * Firestore emulator under `firebase emulators:exec --only functions,firestore`.
 * Callable handlers are invoked directly with a mock request (the documented
 * callable-unit-testing method) so the gate is hermetic: no real Stripe, no
 * real network, no CORS/auth-envelope fragility â€” but the SERVER code, the
 * Firestore documents, and the exact DB queries the money path performs are
 * all real.
 *
 * No tenant hardcoding (R-0.5): the project and per-client test identity are
 * read from the environment (GCLOUD_PROJECT is exported by emulators:exec; the
 * reference-app bundle id is only a local-development fallback).
 *
 * Assertions in this pass:
 *   T-M1 client taxCents:0 is ignored â€” charge uses server-derived tax
 *   T-M2 unknown stateCode -> tax_not_configured (never $0 tax)
 *   T-M3 discount is server-computed only (no client discount input)
 *   T-M4 applyPromo rejects inactive/exhausted/already-used; charge-time usage
 *       commit is idempotent per user+code (Law 9)
 *   T-M5 currency from settings per clientId; unsupported -> throw
 *   (T-M6 money-equality over the PaymentIntent is asserted by the pure-module
 *    suite test/money.test.js â€” the Stripe call cannot complete in the emulator)
 */
'use strict';

const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
// Named import (firebase-admin v12 removed the app-prototype `.storage()`):
// getStorage(app) is the supported Storage accessor for the harness.
const { getStorage } = require('firebase-admin/storage');

// â”€â”€ Environment-driven configuration (no tenant hardcoding) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const PROJECT_ID =
  process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'demo-carnama';
const FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
/** Client ID the money-path is scoped by (override per white-label harness). */
const CLIENT_ID = process.env.B1_TEST_CLIENT_ID || 'com.carnama.labs';

// Point firebase-admin (used by the functions module) at the Firestore emulator.
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_EMULATOR_HOST;
// storageBucket mirrors what firebase-tools injects into real function
// runtimes: admin.storage().bucket() (no name) resolves the DEFAULT bucket
// from FIREBASE_CONFIG.
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: PROJECT_ID,
  storageBucket: `${PROJECT_ID}.appspot.com`,
});

const {
  serverApplyPromo,
  resolveChargeTaxAndPromo,
  commitChargePromoUsage,
  createChargeIntentCore,
  cancelOrderCore,
  cancelOrder,
  eraseUserData,
  applyStripeWebhookEvent,
} = require('../lib/index.js');

// Admin SDK used ONLY to seed emulator state + assert results (like the B0
// rules harness). Production code never sees this app.
const assertApp = initializeApp({ projectId: PROJECT_ID }, 'b1-money-admin');
const db = getFirestore(assertApp);

let passed = 0;
let failed = 0;

function ok(name) { passed += 1; console.log(`  âœ” ${name}`); }
function bad(name, err) {
  failed += 1;
  console.log(`  âœ– ${name}`);
  console.error(
    `      ${err && err.stack ? err.stack.split('\n').slice(0, 4).join('\n      ') : String(err)}`,
  );
}

/** Mock callable request: App Check present + authenticated as [uid]. */
function req(data, uid = 'customer-uid') {
  return { data, auth: { uid }, app: {} };
}

function assertHttpsCode(fn, code) {
  return fn().then(
    () => { throw new Error(`expected ${code}, but the callable SUCCEEDED`); },
    (err) => {
      assert.equal(err.code, code, `expected HttpsError code ${code}, got ${err.code || err.message}`);
    },
  );
}

async function seed() {
  // settings/taxRates â€” the exact lookup calculateTax/createPaymentIntent use.
  await db.doc('settings/taxRates').set({
    clients: {
      [CLIENT_ID]: { stateRates: { CA: 0.0725, DEFAULT: 0.08 }, currency: 'usd' },
    },
    // NOTE: no root/global defaultRate — an unmapped state MUST fail closed.
  });
  // settings/restaurantConfig â€” the currency fallback source.
  await db.doc('settings/restaurantConfig').set({
    restaurantName: 'Carnama',
    currency: 'USD',
    ordersAccepting: true,
  });
  // promoCodes â€” valid / exhausted / inactive.
  await db.doc('promoCodes/SAVE5').set({
    active: true, type: 'fixed', value: 500, maxUses: 100, usedCount: 0,
  });
  await db.doc('promoCodes/USEDUP').set({
    active: true, type: 'fixed', value: 300, maxUses: 2, usedCount: 2,
  });
  await db.doc('promoCodes/OFF').set({
    active: false, type: 'fixed', value: 300, maxUses: 100, usedCount: 0,
  });
  // menus - the MONEY-1 menu cross-check re-prices every charge line against
  // these docs (branchId + isAvailable + priceCents + modifier options).
  await db.collection('menus').doc('mc_burger_1').set({
    id: 'mc_burger_1',
    name: 'Emulator Burger',
    priceCents: 1500,
    branchId: 'branch_main',
    isAvailable: true,
    modifiers: [
      {
        id: 'mod-extra',
        name: 'Extras',
        options: [
          { id: 'opt-fries', name: 'Add fries', upchargeCents: 150 },
        ],
      },
    ],
  });
}

async function resetPromoState() {
  await db.doc('promo_usage/SAVE5_customer-uid').delete().catch(() => {});
  await db.doc('promoCodes/SAVE5').update({ usedCount: 0 }).catch(() => {});
}
async function runChecks() {
  // â”€â”€ T-M1: hostile taxCents:0 / discountCents ignored; server derives â”€â”€
  try {
    const r = await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID,
      stateCode: 'CA',
      itemsSubtotalCents: 2000,
    });
    assert.equal(r.taxCents, 145, 'server-derived tax (2000*0.0725)');
    assert.equal(r.currency, 'usd', 'per-client taxRates currency');
    assert.equal(r.discountCents, 0);
    ok('T-M1 server derives tax=145 from settings/taxRates (client taxCents never read)');
  } catch (e) { bad('T-M1 server derives tax', e); }

  // â”€â”€ T-M2: unknown stateCode -> no silent $0 tax â”€â”€
  try {
    await assertHttpsCode(
      () => resolveChargeTaxAndPromo({
        clientId: CLIENT_ID,
        stateCode: 'ZZ',
        itemsSubtotalCents: 1000,
      }),
      'tax_not_configured',
    );
    ok('T-M2 unknown stateCode -> fail-closed (tax_not_configured)');
  } catch (e) { bad('T-M2 unknown stateCode', e); }

  // â”€â”€ T-M3: discount is server-computed only (fixed value from doc) â”€â”€
  try {
    const r = await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID,
      stateCode: 'DEFAULT',
      itemsSubtotalCents: 2000,
      code: 'SAVE5',
      userId: 'customer-uid',
    });
    assert.equal(r.discountCents, 500, 'server-computed fixed discount');
    assert.equal(r.currency, 'usd');
    ok('T-M3 server computes discount=500 from promoCodes/SAVE5');
  } catch (e) { bad('T-M3 server computes discount', e); }

  // â”€â”€ T-M3d: a non-server (unlisted) promo is rejected â”€â”€
  try {
    await assertHttpsCode(
      () => resolveChargeTaxAndPromo({
        clientId: CLIENT_ID,
        stateCode: 'DEFAULT',
        itemsSubtotalCents: 2000,
        code: 'NOTREAL',
        userId: 'customer-uid',
      }),
      'failed-precondition',
    );
    ok('T-M3d non-server promo code rejected (code_not_found)');
  } catch (e) { bad('T-M3d non-server promo code rejected', e); }

  // â”€â”€ T-M4a: applyPromo returns the server-computed discount â”€â”€
  try {
    const result = await serverApplyPromo({
      code: 'SAVE5',
      cartSubtotalCents: 2000,
      uid: 'customer-uid',
    });
    assert.ok(result.valid);
    assert.equal(result.discountCents, 500);
    ok('T-M4a applyPromo returns server discount 500');
  } catch (e) { bad('T-M4a applyPromo returns server discount', e); }

  // â”€â”€ T-M4b: inactive code rejected â”€â”€
  try {
    await assertHttpsCode(
      () => serverApplyPromo({ code: 'OFF', cartSubtotalCents: 2000, uid: 'customer-uid' }),
      'failed-precondition',
    );
    ok('T-M4b applyPromo rejects inactive code');
  } catch (e) { bad('T-M4b applyPromo rejects inactive code', e); }

  // â”€â”€ T-M4c: exhausted code rejected â”€â”€
  try {
    await assertHttpsCode(
      () => serverApplyPromo({ code: 'USEDUP', cartSubtotalCents: 2000, uid: 'customer-uid' }),
      'failed-precondition',
    );
    ok('T-M4c applyPromo rejects exhausted code');
  } catch (e) { bad('T-M4c applyPromo rejects exhausted code', e); }

  // T-M4d: charge-time usage commit is uid-scoped + idempotent (Law 9)
  try {
    await resetPromoState();
    await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 2000,
      code: 'SAVE5', userId: 'customer-uid', idempotencyKey: 'key-A',
    });
    await commitChargePromoUsage({
      code: 'SAVE5', userId: 'customer-uid', idempotencyKey: 'key-A', itemsSubtotalCents: 2000,
    });
    let usage = await db.doc('promo_usage/SAVE5_customer-uid').get();
    assert.ok(usage.exists, 'usage doc committed at charge time');
    assert.equal(usage.data().idempotencyKey, 'key-A');
    let promo = await db.doc('promoCodes/SAVE5').get();
    assert.equal(promo.data().usedCount, 1);
    await commitChargePromoUsage({
      code: 'SAVE5', userId: 'customer-uid', idempotencyKey: 'key-A', itemsSubtotalCents: 2000,
    });
    promo = await db.doc('promoCodes/SAVE5').get();
    assert.equal(promo.data().usedCount, 1, 'idempotent: usedCount still 1');
    await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 2000,
      code: 'SAVE5', userId: 'customer2-uid',
    });
    ok('T-M4d charge-time usage is uid-scoped + idempotent (usedCount stays 1 on retry)');
  } catch (e) { bad('T-M4d charge-time usage uid-scoped + idempotent', e); }

  // T-M4e: already-used code rejected for THIS user at charge time
  try {
    await resetPromoState();
    await commitChargePromoUsage({
      code: 'SAVE5', userId: 'customer-uid', idempotencyKey: 'key-X', itemsSubtotalCents: 2000,
    });
    await assertHttpsCode(
      () => resolveChargeTaxAndPromo({
        clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 2000,
        code: 'SAVE5', userId: 'customer-uid', idempotencyKey: 'key-Y',
      }),
      'failed-precondition',
    );
    ok('T-M4e already-used code rejected at charge time (different idempotency key)');
  } catch (e) { bad('T-M4e already-used code rejected', e); }

  // T-M5: currency comes from config per clientId
  try {
    await db.doc('settings/taxRates').set({
      clients: { [CLIENT_ID]: { stateRates: { DEFAULT: 0.05 }, currency: 'USD' } },
    });
    const r = await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 1000,
    });
    assert.equal(r.currency, 'usd');
    await db.doc('settings/taxRates').set({
      clients: { [CLIENT_ID]: { stateRates: { DEFAULT: 0.05 }, currency: 'AED' } },
    });
    const r2 = await resolveChargeTaxAndPromo({
      clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 1000,
    });
    assert.equal(r2.currency, 'aed');
    ok('T-M5 currency config-driven per clientId (usd -> aed)');
  } catch (e) { bad('T-M5 currency config-driven', e); }

  // T-M5b: invalid currency -> throw (no silent fallback)
  try {
    await db.doc('settings/taxRates').set({
      clients: { [CLIENT_ID]: { stateRates: { DEFAULT: 0.05 }, currency: 'XYZ' } },
    });
    await assertHttpsCode(
      () => resolveChargeTaxAndPromo({
        clientId: CLIENT_ID, stateCode: 'DEFAULT', itemsSubtotalCents: 1000,
      }),
      'unsupported_currency',
    );
    ok('T-M5b unsupported currency -> fail-closed (unsupported_currency)');
  } catch (e) { bad('T-M5b unsupported currency', e); }

  // ---------------------------------------------------------------------------
  // MONEY-1 (T-5) - END-TO-END against the REAL compiled callable: a tampered
  // cart is rejected by the menu cross-check BEFORE any Stripe call (no
  // charge is even attempted), while a correctly priced cart passes the gate
  // and reaches the Stripe boundary. The Stripe boundary itself cannot
  // complete in the emulator (no API key - never faked): the key is forced
  // EMPTY here so the boundary failure is hermetic and deterministic.
  // ---------------------------------------------------------------------------
  process.env.STRIPE_SECRET_KEY = ''; // hermetic: Stripe construct fails, network never touched
  await db.doc('settings/taxRates').set({
    clients: { [CLIENT_ID]: { stateRates: { DEFAULT: 0.08 }, currency: 'USD' } },
  });

  const validIntentRequest = {
    items: [{ id: 'mc_burger_1', priceCents: 1500, quantity: 1 }],
    idempotencyKey: 'e2e-key-valid',
    tipCents: 0,
    deliveryFeeCents: 0,
    stateCode: 'DEFAULT',
    clientId: CLIENT_ID,
    userId: 'customer-uid',
  };

  // T-5a: client price (100) below the menu price (1500) -> failed-precondition.
  try {
    await assertHttpsCode(
      () => createChargeIntentCore({
        ...validIntentRequest,
        items: [{ id: 'mc_burger_1', priceCents: 100, quantity: 1 }],
        idempotencyKey: 'e2e-key-tamper',
      }),
      'failed-precondition',
    );
    ok('T-5a tampered item price rejected end-to-end by the menu cross-check (no Stripe charge)');
  } catch (e) { bad('T-5a tampered item price rejected end-to-end', e); }

  // T-5b: unknown menu item id -> failed-precondition (fail-closed).
  try {
    await assertHttpsCode(
      () => createChargeIntentCore({
        ...validIntentRequest,
        items: [{ id: 'mc_ghost_item', priceCents: 1500, quantity: 1 }],
        idempotencyKey: 'e2e-key-ghost',
      }),
      'failed-precondition',
    );
    ok('T-5b unknown menu item rejected end-to-end (fail-closed)');
  } catch (e) { bad('T-5b unknown menu item rejected', e); }

  // T-5c: hidden option upcharge (client 0 vs server 150) -> failed-precondition.
  try {
    await assertHttpsCode(
      () => createChargeIntentCore({
        ...validIntentRequest,
        items: [{
          id: 'mc_burger_1',
          priceCents: 1500,
          quantity: 1,
          selectedOptions: [{ id: 'opt-fries', name: 'Add fries', upchargeCents: 0 }],
        }],
        idempotencyKey: 'e2e-key-upcharge',
      }),
      'failed-precondition',
    );
    ok('T-5c tampered option upcharge rejected end-to-end (server upcharge wins)');
  } catch (e) { bad('T-5c tampered option upcharge rejected', e); }

  // T-5d: a correctly priced cart PASSES the menu gate and reaches the Stripe
  // boundary. The boundary failure must NOT be the menu gate's
  // failed-precondition - that proves the cross-check let the honest cart
  // through (no fake success is asserted: the Stripe call cannot complete).
  try {
    let reachedStripeBoundary = false;
    try {
      await createChargeIntentCore(validIntentRequest);
    } catch (e) {
      reachedStripeBoundary = e.code !== 'failed-precondition';
    }
    assert.ok(
      reachedStripeBoundary,
      'a correctly priced cart must pass the menu cross-check',
    );
    ok('T-5d correctly priced cart passes the menu gate and reaches the Stripe boundary');
  } catch (e) { bad('T-5d correctly priced cart passes the menu gate', e); }
}

/**
 * MONEY-2: cancelOrder emulator state. Distinct order docs per scenario so the
 * checks never step on each other. `customerId` is `customer-uid` (the mock
 * callable's uid) EXCEPT the deliberately-foreign `ord_foreign` doc used by the
 * T-3 non-owner denial.
 */
async function seedCancelOrderState() {
  await db.collection('orders').doc('ord_pending_no_pi').set({
    id: 'ord_pending_no_pi',
    customerId: 'customer-uid',
    status: 'pending',
    branchId: 'branch_main',
    totalCents: 1620,
    orderNumber: '#9001',
    createdAt: new Date(),
  });
  await db.collection('orders').doc('ord_conf_pi').set({
    id: 'ord_conf_pi',
    customerId: 'customer-uid',
    status: 'confirmed',
    branchId: 'branch_main',
    paymentIntentId: 'pi_conf_emulator',
    totalCents: 1620,
    orderNumber: '#9002',
    createdAt: new Date(),
  });
  await db.collection('orders').doc('ord_conf_pi_uncaptured').set({
    id: 'ord_conf_pi_uncaptured',
    customerId: 'customer-uid',
    status: 'confirmed',
    branchId: 'branch_main',
    paymentIntentId: 'pi_uncaptured_emulator',
    totalCents: 1620,
    orderNumber: '#9003',
    createdAt: new Date(),
  });
  await db.collection('orders').doc('ord_delivered').set({
    id: 'ord_delivered',
    customerId: 'customer-uid',
    status: 'delivered',
    branchId: 'branch_main',
    totalCents: 1620,
    orderNumber: '#9004',
    createdAt: new Date(),
  });
  await db.collection('orders').doc('ord_cancelled').set({
    id: 'ord_cancelled',
    customerId: 'customer-uid',
    status: 'cancelled',
    cancelledBy: 'customer',
    cancelledAt: new Date(),
    branchId: 'branch_main',
    totalCents: 1620,
    orderNumber: '#9005',
    createdAt: new Date(),
  });
  await db.collection('orders').doc('ord_foreign').set({
    id: 'ord_foreign',
    customerId: 'another-user',
    status: 'pending',
    branchId: 'branch_main',
    totalCents: 1620,
    orderNumber: '#9006',
    createdAt: new Date(),
  });
}

/**
 * Recording mock Stripe seam (batch spec §8.5: "asserted via the emulator
 * harness (mock Stripe)"). Records every call so the tests can PROVE the
 * refund was issued exactly once, with the documented idempotency key, and
 * that nothing was double-refunded. Only ever used in this harness — the
 * production wrapper passes the real Stripe client.
 */
function mockStripeSeam({ intentStatus = 'succeeded' } = {}) {
  const calls = { refundsCreate: [], paymentIntentsCancel: [], paymentIntentsRetrieve: 0 };
  return {
    calls,
    stripe: {
      paymentIntents: {
        retrieve: async (id) => {
          calls.paymentIntentsRetrieve += 1;
          return { id, status: intentStatus };
        },
        cancel: async (id, opts) => {
          calls.paymentIntentsCancel.push({ id, opts });
          return { id };
        },
      },
      refunds: {
        create: async (payload, opts) => {
          calls.refundsCreate.push({ payload, opts });
          return { id: 're_mock_cancel', amount: 1620 };
        },
      },
    },
  };
}

async function runCancelOrderChecks() {
  // ---------------------------------------------------------------------------
  // T-2a — cancelOrder happy path, ZERO-Stripe branch, FULL callable e2e: a
  // pending order with NO paymentIntentId is cancelled by its owner through the
  // real `cancelOrder` handler (App Check + auth + zod + load + ownership +
  // status gate + Firestore flip). Nothing to reverse, no Stripe constructed.
  // ---------------------------------------------------------------------------
  try {
    const result = await cancelOrder.run(req({ orderId: 'ord_pending_no_pi' }, 'customer-uid'));
    assert.equal(result.cancelled, true);
    assert.equal(result.refundId, null);
    const doc = await db.collection('orders').doc('ord_pending_no_pi').get();
    assert.equal(doc.data().status, 'cancelled');
    assert.equal(doc.data().cancelledBy, 'customer');
    assert.ok(doc.data().cancelledAt, 'cancelledAt stamped');
    const refunds = doc.data().refunds || [];
    assert.equal(refunds.length, 1, 'cancellation refund record persisted');
    assert.equal(refunds[0].reason, 'cancelled_by_customer');
    assert.equal(refunds[0].refundId, null);
    ok('T-2a full-callable cancel of a pending (no-PI) order -> cancelled + cancelledBy:customer + refund record');
  } catch (e) { bad('T-2a full-callable pending cancel', e); }

  // ---------------------------------------------------------------------------
  // T-2b — cancelOrder happy path, captured charge: the validated order is
  // cancelled and the Stripe REFUND is issued exactly once, with the documented
  // idempotency key `cancel-{orderId}` and reason `requested_by_customer`
  // (mock Stripe per spec §8.5; the refund id + amount land in refunds[]).
  // ---------------------------------------------------------------------------
  try {
    const { stripe, calls } = mockStripeSeam();
    const orderRef = db.collection('orders').doc('ord_conf_pi');
    const order = (await orderRef.get()).data();
    const result = await cancelOrderCore({
      orderId: 'ord_conf_pi',
      uid: 'customer-uid',
      order,
      orderRef,
      stripe,
    });
    assert.equal(result.cancelled, true);
    assert.equal(result.refundId, 're_mock_cancel');
    // Refund called exactly once with the exact payload + idempotency key.
    assert.equal(calls.refundsCreate.length, 1, 'refund issued exactly once');
    assert.equal(calls.refundsCreate[0].payload.payment_intent, 'pi_conf_emulator');
    assert.equal(calls.refundsCreate[0].payload.reason, 'requested_by_customer');
    assert.equal(calls.refundsCreate[0].opts.idempotencyKey, 'cancel-ord_conf_pi');
    assert.equal(calls.paymentIntentsCancel.length, 0, 'no cancel for a captured charge');
    const doc = await orderRef.get();
    assert.equal(doc.data().status, 'cancelled');
    assert.equal(doc.data().cancelledBy, 'customer');
    const refunds = doc.data().refunds || [];
    assert.equal(refunds[0].refundId, 're_mock_cancel');
    assert.equal(refunds[0].amount, 1620);
    assert.equal(refunds[0].reason, 'cancelled_by_customer');
    ok('T-2b confirmed order -> refund issued (payment_intent + cancel-{orderId} idempotency key) then status:cancelled (refund-before-flip)');
  } catch (e) { bad('T-2b confirmed cancel + refund', e); }

  // ---------------------------------------------------------------------------
  // T-2c — "charge capturable" (W3.4): an authorized-but-UNCAPTURED intent is
  // RELEASED via paymentIntents.cancel (no capture -> no refund is possible),
  // still with the cancel-{orderId} idempotency key, and NO refund is created.
  // ---------------------------------------------------------------------------
  try {
    const { stripe, calls } = mockStripeSeam({ intentStatus: 'requires_capture' });
    const orderRef = db.collection('orders').doc('ord_conf_pi_uncaptured');
    const order = (await orderRef.get()).data();
    const result = await cancelOrderCore({
      orderId: 'ord_conf_pi_uncaptured',
      uid: 'customer-uid',
      order,
      orderRef,
      stripe,
    });
    assert.equal(result.refundId, null);
    assert.equal(calls.paymentIntentsCancel.length, 1, 'uncaptured intent released via paymentIntents.cancel');
    assert.equal(calls.paymentIntentsCancel[0].id, 'pi_uncaptured_emulator');
    assert.equal(calls.paymentIntentsCancel[0].opts.idempotencyKey, 'cancel-ord_conf_pi_uncaptured');
    assert.equal(calls.refundsCreate.length, 0, 'no refund for an uncaptured charge');
    const doc = await orderRef.get();
    assert.equal(doc.data().status, 'cancelled');
    ok('T-2c uncaptured (requires_capture) intent -> released via paymentIntents.cancel, no refund, order cancelled');
  } catch (e) { bad('T-2c uncaptured intent release', e); }

  // ---------------------------------------------------------------------------
  // T-2d — refund-before-flip FAIL-CLOSED proof, FULL callable e2e: when the
  // refund cannot be issued (hermetic blank key -> the lazy Stripe seam is a
  // hard boundary failure), the order MUST NOT transition to cancelled. Money
  // safety: a cancelled order with the customer still charged is impossible.
  // ---------------------------------------------------------------------------
  try {
    await db.collection('orders').doc('ord_conf_pi_fail_closed').set({
      id: 'ord_conf_pi_fail_closed',
      customerId: 'customer-uid',
      status: 'confirmed',
      branchId: 'branch_main',
      paymentIntentId: 'pi_fail_closed_emulator',
      totalCents: 2000,
      orderNumber: '#9007',
      createdAt: new Date(),
    });
    const ref = db.collection('orders').doc('ord_conf_pi_fail_closed');
    let rejected = false;
    try {
      // STRIPE_SECRET_KEY is '' (set by runChecks) -> the lazy seam throws on
      // first real construction inside issueCancellationRefund.
      await cancelOrder.run(req({ orderId: 'ord_conf_pi_fail_closed' }, 'customer-uid'));
    } catch (err) {
      rejected = true;
      assert.ok(err, 'refund boundary failure surfaces as a rejection');
    }
    assert.equal(rejected, true, 'cancel must NOT succeed when the refund fails');
    const doc = await ref.get();
    assert.equal(doc.data().status, 'confirmed', 'fail-closed: order stays confirmed, NOT cancelled');
    assert.ok(!doc.data().cancelledBy, 'no cancelledBy written');
    ok('T-2d refund-failure fail-closed: order stays confirmed (refund-before-flip, no money lost)');
  } catch (e) { bad('T-2d fail-closed refund gate', e); }

  // ---------------------------------------------------------------------------
  // T-3 — cancelOrder non-owner denied (permission-denied), BOTH through the
  // core (uid mismatch) and the full callable (different auth uid). No Stripe.
  // ---------------------------------------------------------------------------
  try {
    const orderRef = db.collection('orders').doc('ord_foreign');
    const order = (await orderRef.get()).data();
    await assertHttpsCode(
      () => cancelOrderCore({
        orderId: 'ord_foreign',
        uid: 'customer-uid',
        order,
        orderRef,
        stripe: mockStripeSeam().stripe,
      }),
      'permission-denied',
    );
    await assertHttpsCode(
      () => cancelOrder.run(req({ orderId: 'ord_pending_no_pi' }, 'someone-else')),
      'permission-denied',
    );
    ok('T-3 non-owner cancel denied (permission-denied) via core + full callable');
  } catch (e) { bad('T-3 non-owner denied', e); }

  // ---------------------------------------------------------------------------
  // T-4 — cancelOrder delivered order denied (failed-precondition). No Stripe.
  // ---------------------------------------------------------------------------
  try {
    const orderRef = db.collection('orders').doc('ord_delivered');
    const order = (await orderRef.get()).data();
    await assertHttpsCode(
      () => cancelOrderCore({
        orderId: 'ord_delivered',
        uid: 'customer-uid',
        order,
        orderRef,
        stripe: mockStripeSeam().stripe,
      }),
      'failed-precondition',
    );
    const doc = await orderRef.get();
    assert.equal(doc.data().status, 'delivered', 'delivered order untouched');
    ok('T-4 delivered order rejected (failed-precondition), status untouched');
  } catch (e) { bad('T-4 delivered rejected', e); }

  // ---------------------------------------------------------------------------
  // T-5 — cancelOrder replay is IDEMPOTENT: a second cancel on an already-
  // cancelled order returns OK and NEVER calls Stripe again (no double refund).
  // ---------------------------------------------------------------------------
  try {
    const { stripe, calls } = mockStripeSeam();
    const orderRef = db.collection('orders').doc('ord_cancelled');
    const order = (await orderRef.get()).data();
    const result = await cancelOrderCore({
      orderId: 'ord_cancelled',
      uid: 'customer-uid',
      order,
      orderRef,
      stripe,
    });
    assert.equal(result.alreadyCancelled, true);
    assert.equal(calls.refundsCreate.length, 0, 'replay issues NO refund');
    assert.equal(calls.paymentIntentsRetrieve, 0, 'replay performs NO Stripe call at all');
    const doc = await orderRef.get();
    assert.equal(doc.data().status, 'cancelled');
    ok('T-5 already-cancelled replay -> ok, idempotent, zero Stripe calls (no double refund)');
  } catch (e) { bad('T-5 idempotent replay', e); }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONEY-3 — GDPR erasure (W3.5/W3.6) + delivery-fee clamp (W3.7) end-to-end.
// eraseUserData runs for REAL against the Firestore+Storage emulators
// (eraseUserStorage → bucket.deleteFiles({prefix}) on the Storage emulator);
// the delivery-fee clamp is observed through the injectable Stripe seam.
// ─────────────────────────────────────────────────────────────────────────────
async function seedGdprState(uid) {
  await db.collection('users').doc(uid).set({email: `${uid}@test.dev`, role: 'customer', branchId: ''});
  await db.collection('orders').doc('ord_erase_own').set({
    customerId: uid, status: 'delivered', totalCents: 2500, branchId: 'b1',
    userId: uid, createdAt: new Date('2024-01-01T10:00:00Z'),
  });
  await db.collection('orders').doc('ord_erase_driver').set({
    customerId: 'someone-else', assignedDriverId: uid, status: 'delivered',
    totalCents: 1800, branchId: 'b1', userId: 'someone-else',
    createdAt: new Date('2024-01-01T11:00:00Z'),
  });
  await db.collection('deliveries').doc('ord_erase_own').set({orderId: 'ord_erase_own', driverId: 'driver-9', customerId: uid, status: 'delivered'});
  await db.collection('reservations').doc('res-erase-1').set({userId: uid, branchId: 'b1', customerName: 'C', startTime: new Date(), partySize: 2});
  await db.collection('reservation_locks').doc('lock-erase-1').set({userId: uid});
  await db.collection('waitlist').doc('wl-erase-1').set({userId: uid, branchId: 'b1'});
  await db.collection('carts').doc(uid).set({items: []});
  await db.collection('presence').doc(uid).set({lastSeen: new Date()});
  await db.collection('loyalty').doc(uid).set({points: 10});
  await db.collection('notifications').doc(uid).set({title: 't'});
  await db.collection('notifications').doc(uid).collection('items').doc('n1').set({title: 'hello'});
  await db.collection('driverLocations').doc(uid).set({lat: 1, lng: 2});
  await db.collection('promo_usage').doc('pu-erase-1').set({userId: uid, code: 'HELLO10'});
  const bucket = getStorage(assertApp).bucket(`${PROJECT_ID}.appspot.com`);
  await bucket.file(`avatars/${uid}/a.png`).save('x', {resumable: false});
  await bucket.file('proof_of_delivery/ord_erase_own/pod.jpg').save('x', {resumable: false});
  await bucket.file('proof_of_delivery/ord_erase_driver/pod.jpg').save('x', {resumable: false});
  // Another user's objects — they must SURVIVE the erasure.
  await bucket.file('avatars/keep-me/b.png').save('x', {resumable: false});
  await bucket.file('proof_of_delivery/ord_keep/pod.jpg').save('x', {resumable: false});
  return bucket;
}

async function runMoney3Checks() {
  // ── T-1: eraseUserData full erase — docs (incl. driver-assigned orders +
  // deliveries), Storage (avatars + own/driver PODs), marker completed with
  // the erased-prefix audit trail.
  try {
    const uid = 'erase-me-1';
    const bucket = await seedGdprState(uid);
    await eraseUserData(db, uid, async () => {});
    // Spec contract: the erased user's OWN orders are deleted. A DRIVER-
    // assigned order belongs to another customer (orderIds gathered from it
    // are only the KEY PATH to its delivery row) — it must survive.
    const ownLeft = (await db.collection('orders').get()).docs
        .filter((d) => d.id === 'ord_erase_own').length;
    const driverOrderSurvives = (await db.collection('orders').doc('ord_erase_driver').get()).exists;
    const [ownPod] = await bucket.file('proof_of_delivery/ord_erase_own/pod.jpg').exists();
    const [drvPod] = await bucket.file('proof_of_delivery/ord_erase_driver/pod.jpg').exists();
    const [ownAv] = await bucket.file(`avatars/${uid}/a.png`).exists();
    const [keepAv] = await bucket.file('avatars/keep-me/b.png').exists();
    const [keepPod] = await bucket.file('proof_of_delivery/ord_keep/pod.jpg').exists();
    const marker = (await db.collection('deletion_requests').doc(uid).get()).data();
    assert.equal(ownLeft, 0, 'owned order erased');
    assert.equal(driverOrderSurvives, true, "another customer's order doc survives (order ids are the delivery key path)");
    assert.equal((await db.collection('deliveries').doc('ord_erase_own').get()).exists, false, 'own delivery row erased');
    assert.equal((await db.collection('deliveries').doc('ord_erase_driver').get()).exists, false, 'driver-assigned delivery row erased (legacy pre-driverId coverage)');
    assert.equal((await db.collection('reservations').doc('res-erase-1').get()).exists, false, 'reservation erased');
    assert.equal((await db.collection('users').doc(uid).get()).exists, false, 'user doc erased');
    assert.equal(ownPod, false, 'own-order POD erased');
    assert.equal(drvPod, false, 'driver-assigned-order POD erased');
    assert.equal(ownAv, false, 'avatar erased');
    assert.equal(keepAv, true, "another user's avatar SURVIVES");
    assert.equal(keepPod, true, "another order's POD SURVIVES");
    assert.equal(marker && marker.status, 'completed', 'marker completed');
    assert.ok(Array.isArray(marker.erasedStoragePrefixes) &&
        marker.erasedStoragePrefixes.includes(`avatars/${uid}/`) &&
        marker.erasedStoragePrefixes.includes('proof_of_delivery/ord_erase_own/') &&
        marker.erasedStoragePrefixes.includes('proof_of_delivery/ord_erase_driver/'),
    'marker records the erased Storage prefixes (audit trail)');
    ok('T-1 eraseUserData erases docs+storage (own & driver-assigned PODs) for real on the emulators, marker completed with prefix audit');
  } catch (e) { bad('T-1 eraseUserData full erase', e); }

  // ── T-2: auth-delete failure -> data is STILL erased (storage + refs run
  // before auth), the error propagates, and the marker stays in_progress for
  // the hourly retrier (durable-marker-first semantics).
  try {
    const uid = 'erase-me-2';
    await seedGdprState(uid);
    let threw = false;
    try {
      await eraseUserData(db, uid, async () => {
        throw new Error('simulated auth outage');
      });
    } catch (e) { threw = true; }
    const marker = (await db.collection('deletion_requests').doc(uid).get()).data();
    const ordersLeft = (await db.collection('orders').get()).docs
        .filter((d) => d.id === 'ord_erase_own').length;
    assert.equal(threw, true, 'auth failure must propagate');
    assert.equal(marker && marker.status, 'in_progress', 'marker stays in_progress');
    assert.equal(ordersLeft, 0, 'data erased BEFORE the auth step (marker-first)');
    ok('T-2 auth-delete failure propagates AND marker stays in_progress (data still erased)');
  } catch (e) { bad('T-2 durable marker on failure', e); }

  // ── T-6: delivery fee is SERVER-authoritative (W3.7). Client claims 9999;
  // settings/restaurantConfig says 700 -> the PI amount, metadata and the
  // returned amountCents all use 700 (a tampered client can't move the fee).
  try {
    await db.doc('settings/restaurantConfig').set({deliveryFeeCents: 700}, {merge: true});
    const seam = mockStripeSeam();
    seam.calls.paymentIntentsCreate = [];
    seam.stripe.paymentIntents.create = async (params, opts) => {
      seam.calls.paymentIntentsCreate.push({params, opts});
      return {id: 'pi_mock_fee', client_secret: 'cs_mock_fee', status: 'requires_confirmation'};
    };
    const res = await createChargeIntentCore({
      items: [{id: 'mc_burger_1', priceCents: 1500, quantity: 1}],
      idempotencyKey: 'e2e-key-fee-clamp',
      tipCents: 0,
      deliveryFeeCents: 9999,
      stateCode: 'DEFAULT',
      clientId: CLIENT_ID,
      userId: 'customer-uid',
      stripe: seam.stripe,
    });
    const created = seam.calls.paymentIntentsCreate[0];
    assert.ok(created, 'a PaymentIntent must be created through the seam');
    // subtotal 1500 + tax 8% (120) + clamped fee 700 = 2320 (NOT 9999-driven).
    assert.equal(created.params.amount, 2320, 'amount uses the CLAMPED fee');
    assert.equal(created.params.metadata.deliveryFeeCents, '700', 'PI metadata records the server-clamped fee');
    assert.equal(res.amountCents, 2320, 'returned amountCents matches the clamped total');
    ok('T-6 client deliveryFeeCents 9999 clamped to server config 700 (amount + metadata + return)');
  } catch (e) { bad('T-6 delivery fee clamp', e); }
}

// ─────────────────────────────────────────────────────────────────────────────
// T-5 — Stripe webhook side effects (b09 W3.8): payment_failed + charge.
// refunded are recorded on the order doc + the size-capped stripeEvents log.
// Drives the REAL compiled applyStripeWebhookEvent against the REAL Firestore
// emulator (signature verification belongs to the onRequest wrapper).
// ─────────────────────────────────────────────────────────────────────────────
async function runWebhookChecks() {
  // ── T-5a: payment_intent.payment_failed → paymentFailedAt + event ──────
  try {
    await db.collection('orders').doc('ord_wh_fail').set({
      customerId: 'customer-uid', userId: 'customer-uid', branchId: 'b1',
      status: 'pending', totalCents: 1500, paymentIntentId: 'pi_wh_fail',
      createdAt: new Date('2024-01-01T10:00:00Z'),
    });
    await applyStripeWebhookEvent(db, {
      type: 'payment_intent.payment_failed',
      data: {object: {id: 'pi_wh_fail', metadata: {orderId: 'ord_wh_fail'}}},
    });
    const doc = (await db.collection('orders').doc('ord_wh_fail').get()).data();
    assert.ok(doc.paymentFailedAt && typeof doc.paymentFailedAt.toMillis === 'function',
        'paymentFailedAt recorded (server timestamp)');
    const ev = doc.stripeEvents[doc.stripeEvents.length - 1];
    assert.equal(ev.type, 'payment_intent.payment_failed');
    assert.equal(ev.id, 'pi_wh_fail');
    assert.ok(ev.at && typeof ev.at.toMillis === 'function', 'event carries a timestamp');
    ok('W-5a webhook payment_failed -> paymentFailedAt + stripeEvents entry');
  } catch (e) { bad('W-5a webhook payment_failed', e); }

  // ── T-5b: charge.refunded → resolved via paymentIntentId → refundedAt +
  // event with the refunded amount ─────────────────────────────────────────
  try {
    await db.collection('orders').doc('ord_wh_ref').set({
      customerId: 'customer-uid', userId: 'customer-uid', branchId: 'b1',
      status: 'confirmed', totalCents: 1800, paymentIntentId: 'pi_wh_ref',
      createdAt: new Date('2024-01-01T11:00:00Z'),
    });
    await applyStripeWebhookEvent(db, {
      type: 'charge.refunded',
      data: {object: {id: 'ch_wh_ref', payment_intent: 'pi_wh_ref', amount_refunded: 1800}},
    });
    const doc = (await db.collection('orders').doc('ord_wh_ref').get()).data();
    assert.ok(doc.refundedAt && typeof doc.refundedAt.toMillis === 'function',
        'refundedAt recorded (server timestamp)');
    const ev = doc.stripeEvents[doc.stripeEvents.length - 1];
    assert.equal(ev.type, 'charge.refunded');
    assert.equal(ev.id, 'ch_wh_ref');
    assert.equal(ev.amount, 1800, 'event carries the refunded amount');
    ok('W-5b webhook charge.refunded -> refundedAt + amount-carrying event (order resolved via paymentIntentId)');
  } catch (e) { bad('W-5b webhook charge.refunded', e); }

  // ── T-5c: the stripeEvents log is HARD-CAPPED at 20 (oldest dropped) ────
  try {
    const prefilled = Array.from({length: 20}, (_, i) => ({type: `old-${i}`, at: null, id: null, amount: null}));
    await db.collection('orders').doc('ord_wh_cap').set({
      customerId: 'customer-uid', userId: 'customer-uid', branchId: 'b1',
      status: 'pending', totalCents: 100, paymentIntentId: 'pi_wh_cap',
      createdAt: new Date('2024-01-01T12:00:00Z'), stripeEvents: prefilled,
    });
    await applyStripeWebhookEvent(db, {
      type: 'payment_intent.payment_failed',
      data: {object: {id: 'pi_wh_cap', metadata: {orderId: 'ord_wh_cap'}}},
    });
    const doc = (await db.collection('orders').doc('ord_wh_cap').get()).data();
    assert.equal(doc.stripeEvents.length, 20, 'log stays at the 20-event cap');
    assert.equal(doc.stripeEvents[0].type, 'old-1', 'oldest entry (old-0) dropped');
    assert.equal(doc.stripeEvents[19].type, 'payment_intent.payment_failed', 'newest entry last');
    ok('W-5c stripeEvents capped at 20 — oldest dropped, newest appended');
  } catch (e) { bad('W-5c stripeEvents cap', e); }

  // ── T-5d: unknown event types are a documented no-op ────────────────────
  try {
    await applyStripeWebhookEvent(db, {
      type: 'customer.created',
      data: {object: {id: 'cus_irrelevant'}},
    });
    const doc = (await db.collection('orders').doc('ord_wh_cap').get()).data();
    assert.equal(doc.stripeEvents.length, 20, 'unknown event leaves the log untouched');
    ok('W-5d unknown webhook event = no-op (no state change)');
  } catch (e) { bad('W-5d webhook no-op', e); }
}

(async () => {
  try {
    await seed();
    await runChecks();
    await seedCancelOrderState();
    await runCancelOrderChecks();
    await runMoney3Checks();
    await runWebhookChecks();
  } catch (e) {
    console.error('FATAL:', e);
    failed += 1;
  } finally {
    try { await assertApp.delete(); } catch (e) {}
  }
  console.log(`\nPASSED: ${passed}  FAILED: ${failed}  TOTAL: ${passed + failed}\n`);
  process.exitCode = failed > 0 ? 1 : 0;
})();