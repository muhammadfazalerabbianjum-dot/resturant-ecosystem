/**
 * P1-2 — ledger unit lane. The emulator lane (gate d) proves the same shape
 * against real Firestore; this file proves the decisions without a network.
 *
 *   L-1 a sale row is shaped from server-derived amounts, with a derived id
 *   L-2 a missing or non-integer amount fails closed (no row, no guess)
 *   L-3 optional components default to 0; a negative component is rejected
 *   L-4 one commit writes the order and exactly one row
 *   L-5 the same order committed twice still has exactly one row
 *   L-6 an existing row is never overwritten (append-only)
 *   L-7 a failing transaction applies NOTHING — no untrailered order
 *   L-8 the append/keep decision is total
 *   L-9 unknown input keys cannot smuggle fields into the row
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  LEDGER_COLLECTION,
  LEDGER_SCHEMA_VERSION,
  LedgerValidationError,
  buildSaleRow,
  commitOrderWithLedger,
  commitSaleForOrder,
  decideLedgerWrite,
  ledgerDocId,
} = require('../lib/ledger.js');

/** Fake store with Firestore's apply-on-commit semantics. */
function fakeStore(seed = {}) {
  const docs = new Map(Object.entries(seed));
  const calls = {transactions: 0};

  const store = {
    collection(name) {
      assert.equal(name, LEDGER_COLLECTION, 'ledger writes only to transactions');
      return {doc: (id) => ({id, path: `${name}/${id}`})};
    },
    async runTransaction(fn) {
      const staged = [];
      const tx = {
        async get(ref) {
          return {exists: docs.has(ref.path)};
        },
        set(ref, data) {
          staged.push([ref.path, data]);
        },
      };
      const result = await fn(tx); // a throw here leaves `staged` unapplied
      // Firestore validates every write at commit time, after the callback has
      // returned. Reproduce that ordering so a poison value proves the whole
      // transaction (order included) is discarded rather than half-applied.
      for (const [, data] of staged) {
        for (const value of Object.values(data)) {
          if (typeof value === 'function') {
            throw new TypeError('Cannot use a function as a Firestore value');
          }
        }
      }
      for (const [path, data] of staged) docs.set(path, data);
      calls.transactions += 1;
      return result;
    },
  };

  return {store, docs, calls};
}

const baseInput = {
  orderId: 'order-1',
  orderNumber: 'HB-1001',
  branchId: 'branch-1',
  customerId: 'user-1',
  paymentIntentId: 'pi_123',
  totalCents: 4200,
  taxCents: 200,
  tipCents: 300,
  discountCents: 100,
  deliveryFeeCents: 500,
  createdAt: 'SERVER_TS',
};

test('L-1: a sale row is shaped from server-derived amounts', () => {
  const row = buildSaleRow(baseInput);

  assert.equal(row.id, 'sale_order-1');
  assert.equal(row.id, ledgerDocId('order-1'));
  assert.equal(row.schemaVersion, LEDGER_SCHEMA_VERSION);
  assert.equal(row.kind, 'sale');
  assert.equal(row.orderId, 'order-1');
  assert.equal(row.orderNumber, 'HB-1001');
  assert.equal(row.branchId, 'branch-1');
  assert.equal(row.customerId, 'user-1');
  assert.equal(row.paymentIntentId, 'pi_123');
  assert.equal(row.totalCents, 4200);
  assert.equal(row.taxCents, 200);
  assert.equal(row.tipCents, 300);
  assert.equal(row.discountCents, 100);
  assert.equal(row.deliveryFeeCents, 500);
  assert.equal(row.createdAt, 'SERVER_TS');
});

test('L-2: an unusable amount fails closed and names the field', () => {
  for (const bad of [undefined, null, '4200', 42.5, -1, NaN]) {
    assert.throws(
      () => buildSaleRow({...baseInput, totalCents: bad}),
      (err) => err instanceof LedgerValidationError && err.field === 'totalCents',
      `totalCents=${String(bad)} must be rejected`);
  }
  assert.throws(
    () => buildSaleRow({...baseInput, paymentIntentId: '   '}),
    (err) => err instanceof LedgerValidationError && err.field === 'paymentIntentId');
  assert.throws(
    () => buildSaleRow({...baseInput, orderId: ''}),
    (err) => err instanceof LedgerValidationError && err.field === 'orderId');
});

test('L-3: optional components default to 0 and reject negatives', () => {
  const bare = buildSaleRow({
    orderId: 'o', customerId: 'c', paymentIntentId: 'pi', totalCents: 0,
  });
  assert.equal(bare.taxCents, 0);
  assert.equal(bare.tipCents, 0);
  assert.equal(bare.discountCents, 0);
  assert.equal(bare.deliveryFeeCents, 0);
  assert.equal(bare.orderNumber, null);
  assert.equal(bare.branchId, null);

  assert.throws(
    () => buildSaleRow({...baseInput, tipCents: -5}),
    (err) => err instanceof LedgerValidationError && err.field === 'tipCents');
});

test('L-4: one commit writes the order and exactly one row', async () => {
  const {store, docs, calls} = fakeStore();
  const orderRef = {id: 'order-1', path: 'orders/order-1'};
  const row = buildSaleRow(baseInput);

  const result = await commitOrderWithLedger(store, orderRef, {id: 'order-1'}, row);

  assert.equal(result, 'appended');
  assert.equal(calls.transactions, 1, 'one Firestore transaction');
  assert.deepEqual(docs.get('orders/order-1'), {id: 'order-1'});
  assert.equal(docs.size, 2);

  const rows = [...docs.keys()].filter((p) => p.startsWith(`${LEDGER_COLLECTION}/`));
  assert.deepEqual(rows, ['transactions/sale_order-1']);
  assert.equal(docs.get('transactions/sale_order-1').totalCents, 4200);
});

test('L-5: the same order committed twice has exactly one row', async () => {
  const {store, docs} = fakeStore();
  const orderRef = {id: 'order-1', path: 'orders/order-1'};
  const row = buildSaleRow(baseInput);

  assert.equal(await commitOrderWithLedger(store, orderRef, {v: 1}, row), 'appended');
  assert.equal(await commitOrderWithLedger(store, orderRef, {v: 2}, row), 'kept');

  const rows = [...docs.keys()].filter((p) => p.startsWith(`${LEDGER_COLLECTION}/`));
  assert.equal(rows.length, 1, 'a retry must not add a second money row');
  assert.equal(docs.get('transactions/sale_order-1').totalCents, 4200);
  assert.equal(docs.get('orders/order-1').v, 2, 'the order write is still idempotent');
});

test('L-6: an existing row is never overwritten', async () => {
  const original = {...buildSaleRow(baseInput), totalCents: 9999};
  const {store, docs} = fakeStore({'transactions/sale_order-1': original});

  const result = await commitOrderWithLedger(
      store,
      {id: 'order-1', path: 'orders/order-1'},
      {id: 'order-1'},
      buildSaleRow(baseInput),
  );

  assert.equal(result, 'kept');
  assert.equal(docs.get('transactions/sale_order-1'), original,
      'append-only: the stored row object is untouched');
});

test('L-7: a failing transaction applies nothing', async () => {
  const {store, docs} = fakeStore();
  const orderRef = {id: 'order-2', path: 'orders/order-2'};
  const poison = {id: 'sale_order-2', bad: () => undefined};

  await assert.rejects(
      () => commitOrderWithLedger(store, orderRef, {id: 'order-2'}, poison));

  assert.equal(docs.size, 0,
      'no order and no row: an untrailered order must be impossible');
});

test('L-8: append/keep is total', () => {
  assert.equal(decideLedgerWrite(false), 'append');
  assert.equal(decideLedgerWrite(true), 'keep');
});

test('L-10: commitSaleForOrder derives the row from the order + intent', async () => {
  const {store, docs} = fakeStore();
  const orderDoc = {
    id: 'order-9',
    orderNumber: 'HB-9',
    branchId: 'branch-9',
    customerId: 'user-9',
    totalCents: 4200,
    taxCents: 200,
    tipCents: 0,
    discountCents: 0,
    deliveryFeeCents: 0,
  };

  const result = await commitSaleForOrder(
      store,
      {id: 'order-9', path: 'orders/order-9'},
      orderDoc,
      {id: 'pi_9', amount: 4200, currency: 'cad'},
      'TS',
  );

  assert.equal(result, 'appended');
  const row = docs.get('transactions/sale_order-9');
  assert.equal(row.totalCents, orderDoc.totalCents);
  assert.equal(row.currency, 'cad', 'currency comes from the charged intent');
  assert.equal(row.branchId, 'branch-9');
  assert.equal(row.customerId, 'user-9');
  assert.equal(row.orderNumber, 'HB-9');
});

test('L-9: unknown input keys cannot reach the row', () => {
  const row = buildSaleRow({...baseInput, totalCents: 100, status: 'paid', extra: 'x'});
  assert.equal(Object.hasOwn(row, 'status'), false);
  assert.equal(Object.hasOwn(row, 'extra'), false);
  assert.deepEqual(
      Object.keys(row).sort(),
      [
        'branchId', 'createdAt', 'customerId', 'deliveryFeeCents',
        'discountCents', 'id', 'kind', 'orderId', 'orderNumber',
        'paymentIntentId', 'schemaVersion', 'taxCents', 'tipCents', 'totalCents',
      ],
  );
});
