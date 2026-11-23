#!/usr/bin/env node
// Gate (d) second half — P1-2 emulator proof for the ledger.
//
// The unit lane proves the decisions; this proves them against a real Firestore
// transaction, as the owner's ruling requires:
//
//   (i)   order + exactly ONE `transactions` row commit together;
//   (ii)  committing the same order again adds no second row;
//   (iii) a poisoned row aborts the WHOLE transaction — no untrailered order;
//   (iv)  the row's money equals the order's money (one source of truth).
//
// Runs inside `firebase emulators:exec` (via tool/rules_probe.mjs), so
// FIRESTORE_EMULATOR_HOST is set and the admin SDK needs no credentials.
// Admin SDK writes bypass rules by design; the client-denial half of the proof
// is the REST checks in rules_probe.mjs.

import {createRequire} from 'node:module';

const require = createRequire(new URL('../core_app/functions/package.json', import.meta.url));

const admin = require('firebase-admin');
const {
  buildSaleRow,
  commitOrderWithLedger,
} = require('./lib/ledger.js'); // createRequire is anchored at functions/package.json

const project =
  process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? 'demo-carnama-gate';
const stamp = `${Date.now()}`;

/** @type {number} */
let failures = 0;

function check(ok, label, detail = '') {
  console.log(`ledger-probe: ${ok ? 'ok  ' : 'FAIL'} ${label}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures += 1;
}

export async function runLedgerProbe() {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: project});
  }
  const db = admin.firestore();

  const orderId = `probe-order-${stamp}`;
  const orderRef = db.collection('orders').doc(orderId);
  const storedOrder = {id: orderId, customerId: 'probe-user', totalCents: 4200};
  const row = buildSaleRow({
    orderId,
    orderNumber: 'PROBE-1',
    branchId: 'probe-branch',
    customerId: 'probe-user',
    paymentIntentId: `pi_probe_${stamp}`,
    totalCents: 4200,
    taxCents: 200,
    tipCents: 300,
    deliveryFeeCents: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // (i) order + one row, one transaction
  const first = await commitOrderWithLedger(db, orderRef, storedOrder, row);
  const orderSnap = await orderRef.get();
  const rowsAfterFirst = await db
      .collection('transactions')
      .where('orderId', '==', orderId)
      .get();
  check(first === 'appended', '(i) first commit appends', `returned ${first}`);
  check(orderSnap.exists, '(i) order document exists');
  check(rowsAfterFirst.size === 1, '(i) exactly one ledger row', `rows=${rowsAfterFirst.size}`);

  const written = rowsAfterFirst.docs[0]?.data() ?? {};
  check(
      written.totalCents === 4200 && written.totalCents === storedOrder.totalCents,
      '(iv) row money equals order money',
      `row=${written.totalCents} order=${storedOrder.totalCents}`,
  );

  // (ii) replay adds nothing
  const second = await commitOrderWithLedger(db, orderRef, {...storedOrder, replay: true}, row);
  const rowsAfterSecond = await db
      .collection('transactions')
      .where('orderId', '==', orderId)
      .get();
  const replaySnap = await orderRef.get();
  check(second === 'kept', '(ii) replay keeps the existing row', `returned ${second}`);
  check(rowsAfterSecond.size === 1, '(ii) still exactly one row', `rows=${rowsAfterSecond.size}`);
  check(
      rowsAfterSecond.docs[0]?.data().totalCents === 4200,
      '(ii) the stored row is untouched',
  );
  check(replaySnap.data()?.replay === true, '(ii) the order write still lands');

  // (iii) a poisoned row rolls back the order too
  const poisonOrderId = `probe-poison-${stamp}`;
  const poisonRef = db.collection('orders').doc(poisonOrderId);
  let rolledBack = false;
  try {
    await commitOrderWithLedger(
        db,
        poisonRef,
        {id: poisonOrderId, customerId: 'probe-user'},
        {id: `sale_${poisonOrderId}`, bad: () => undefined},
    );
  } catch {
    rolledBack = true;
  }
  const poisonOrderSnap = await poisonRef.get();
  const poisonRowSnap = await db.collection('transactions').doc(`sale_${poisonOrderId}`).get();
  check(rolledBack, '(iii) poisoned row throws');
  check(!poisonOrderSnap.exists, '(iii) order was NOT written');
  check(!poisonRowSnap.exists, '(iii) row was NOT written');

  // Cleanup (emulator is ephemeral, but leave it tidy for a second run).
  await Promise.all([
    orderRef.delete(),
    ...rowsAfterSecond.docs.map((d) => d.ref.delete()),
  ]);

  return failures;
}

// Direct invocation (node tool/ledger_probe.mjs) is supported for debugging.
if (import.meta.url === `file://${process.argv[1]?.replace(/\\/g, '/')}`) {
  const failed = await runLedgerProbe();
  process.exit(failed > 0 ? 1 : 0);
}
