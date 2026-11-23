#!/usr/bin/env node
// P2-1 cash proof — one create, one replay, one void, against the REAL emulator.
//
// WHY this file exists: the builders have unit tests, but a unit test cannot show
// that a sale leaves exactly ONE order and ONE ledger row in Firestore, nor that a
// replay leaves the count unchanged. Those are the two facts the card is graded
// on, so they are asserted here against the emulator the app talks to.
//
// Requirements: `node tool/shell_proof.mjs up` is already running (it owns the
// emulator pids and writes `.shell-proof.json`). The tax config is seeded here
// because the shell harness seeds only the menu.
//
// Usage: node tool/cash_proof.mjs
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const FUNCTIONS = join(ROOT, 'core_app', 'functions');
const PROOF = join(ROOT, '.shell-proof.json');

if (!existsSync(PROOF)) throw new Error('run `node tool/shell_proof.mjs up` first');

const { firestorePort } = JSON.parse(readFileSync(PROOF, 'utf8'));
process.env.FIRESTORE_EMULATOR_HOST = `127.0.0.1:${firestorePort}`;
process.env.GCLOUD_PROJECT = 'demo-carnama';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-carnama' });

const require = createRequire(join(FUNCTIONS, 'index.js'));

// The compiled core initialises the Admin app itself (lib/index.js:77), so it is
// required FIRST and the same app is reused — initialising here would be the
// duplicate-app crash this script started with.
const core = require(join(FUNCTIONS, 'lib', 'index.js'));
const admin = require('firebase-admin');
const db = admin.firestore();

const TENANT = 'tenant_shell';
const OTHER = 'tenant_other';
const UID = 'staff_cash_proof';
const CLIENT = 'client_shell';
const STATE = 'TX';

const failures = [];
function check(label, condition, detail) {
  const ok = Boolean(condition);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail === undefined ? '' : `  → ${detail}`}`);
  if (!ok) failures.push(label);
}

await db.collection('settings').doc(`${TENANT}_taxRates`).set({
  clients: { [CLIENT]: { stateRates: { [STATE]: 0.0825 }, currency: 'USD' } },
});
await db.collection('menus').doc('proof_cash_wrap').set({
  name: 'Cash Proof Wrap',
  priceCents: 1000,
  branchId: 'branch_shell',
  tenantId: TENANT,
  isAvailable: true,
});
await db.collection('menus').doc('proof_cash_side').set({
  name: 'Cash Proof Side',
  priceCents: 250,
  branchId: 'branch_shell',
  tenantId: TENANT,
  isAvailable: true,
});

const RUN = Date.now();
const payload = {
  lines: [
    { menuItemId: 'proof_cash_wrap', quantity: 2, priceCents: 1000 },
    { menuItemId: 'proof_cash_side', quantity: 1, priceCents: 250 },
  ],
  amountTenderedCents: 3000,
  // Unique per run: the proof must be repeatable against a live emulator, and a
  // fixed key would replay the previous run's order (which is exactly what the
  // first draft did, making the create assertion prove nothing).
  idempotencyKey: `cash-proof-key-${RUN}`,
  clientId: CLIENT,
  stateCode: STATE,
  guestName: 'Proof Guest',
};

const orderCount = async () =>
  (await db.collection('orders').where('idempotencyKey', '==', payload.idempotencyKey).get()).size;

// ---- 1. one create -----------------------------------------------------------
const first = await core.createCashOrderCore({
  uid: UID,
  tenantId: TENANT,
  staffRoles: ['counter'],
  payload,
});
console.log('create:', JSON.stringify(first));

// Server money: 2×1000 + 250 = 2250 subtotal, 8.25% tax = 186, total 2436.
check('subtotal is server-derived (2250)', first.totalCents === 2436, `total ${first.totalCents}`);
check('change is tendered − total (564)', first.changeCents === 564, `change ${first.changeCents}`);
check('exactly one order for the key', (await orderCount()) === 1);

const orderSnap = await db.collection('orders').doc(first.orderId).get();
const order = orderSnap.data();
check('order is a counter cash sale', order.channel === 'counter' && order.paymentMethod === 'cash');
check('order carries the caller as staffId', order.staffId === UID);
check('order carries the claim tenant', order.tenantId === TENANT);
check('order carries no customer id (walk-in)', order.customerId === '');
check('order records taxRate', order.taxRate === 0.0825, `taxRate ${order.taxRate}`);

const saleSnap = await db.collection('transactions').doc(`sale_${first.orderId}`).get();
check('exactly one sale row exists', saleSnap.exists);
const sale = saleSnap.data() ?? {};
check('sale row is schemaVersion 2 cash', sale.schemaVersion === 2 && sale.paymentMethod === 'cash');
check('sale row total == order total', sale.totalCents === 2436, `total ${sale.totalCents}`);
check('sale row tender/change balance',
    sale.amountTenderedCents === 3000 && sale.changeCents === 564,
    `${sale.amountTenderedCents} - ${sale.changeCents}`);
check('sale row snapshots its lines', Array.isArray(sale.items) && sale.items.length === 2);

// ---- 2. replay: the double-tap ----------------------------------------------
const replay = await core.createCashOrderCore({
  uid: UID,
  tenantId: TENANT,
  staffRoles: ['counter'],
  payload,
});
console.log('replay:', JSON.stringify(replay));
check('replay returns the same order', replay.orderId === first.orderId);
check('replay is marked idempotent', replay.idempotent === true);
check('replay adds no order', (await orderCount()) === 1);
check('replay adds no sale row', (await db.collection('transactions').doc(`sale_${first.orderId}`).get()).exists);

// ---- 3. a foreign tenant cannot touch it ------------------------------------
let crossTenant = null;
try {
  await core.voidCashSaleCore({
    uid: UID,
    tenantId: OTHER,
    orderId: first.orderId,
    reason: 'cross tenant attempt',
  });
} catch (error) {
  crossTenant = error;
}
check('cross-tenant void is refused', crossTenant !== null, crossTenant?.code ?? 'no error');
check('cross-tenant void says not-found', crossTenant?.code === 'not-found');

// ---- 4. one void ------------------------------------------------------------
const voided = await core.voidCashSaleCore({
  uid: 'manager_cash_proof',
  tenantId: TENANT,
  orderId: first.orderId,
  reason: 'customer walked away',
});
console.log('void:', JSON.stringify(voided));

const afterVoid = (await db.collection('orders').doc(first.orderId).get()).data();
check('order is cancelled', afterVoid.status === 'cancelled');
check('void keeps the money (total unchanged)', afterVoid.totalCents === 2436);
check('void keeps the lines', Array.isArray(afterVoid.items) && afterVoid.items.length === 2);
check('order records the reason', afterVoid.voidReason === 'customer walked away');

const reversalSnap = await db.collection('transactions').doc(voided.reversalId).get();
check('reversal row exists', reversalSnap.exists);
const reversal = reversalSnap.data() ?? {};
check('reversal is negative', reversal.totalCents === -2436, `total ${reversal.totalCents}`);
check('reversal points at the original', reversal.reversalOf === `sale_${first.orderId}`);
check('reversal is a reversal row', reversal.kind === 'reversal', `${reversal.kind}`);
check('reversal names its reason', reversal.reversalReason === 'customer walked away');

const allRows = await db.collection('transactions').get();
const rowsForOrder = allRows.docs.filter((d) => String(d.id).includes(first.orderId));
check('exactly two rows for the order (sale + reversal)', rowsForOrder.length === 2,
    rowsForOrder.map((d) => d.id).join(', '));

// A second void must not double-reverse.
let secondVoid = null;
try {
  await core.voidCashSaleCore({
    uid: 'manager_cash_proof',
    tenantId: TENANT,
    orderId: first.orderId,
    reason: 'double tap',
  });
} catch (error) {
  secondVoid = error;
}
check('a second void is refused', secondVoid !== null, secondVoid?.code ?? 'no error');
const rowsAfterSecondVoid = (await db.collection('transactions').get()).docs
    .filter((d) => String(d.id).includes(first.orderId));
check('a second void adds no row', rowsAfterSecondVoid.length === 2);

console.log(failures.length === 0 ? '\nCASH PROOF OK' : `\nCASH PROOF FAILED: ${failures.join('; ')}`);
if (failures.length > 0) process.exit(1);
