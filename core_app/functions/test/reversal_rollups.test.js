/**
 * P1-3 — reversal + rollups, one file for both halves of the card, as the card
 * requires. The two claims under test:
 *
 *   R-*  a reversal is a NEW row; the original is byte-identical afterwards
 *   U-*  a rollup equals a from-scratch rebuild from the same ledger rows
 *
 *   R-1 the reversal row mirrors the original with the opposite sign
 *   R-2 a missing original is refused and nothing is written
 *   R-3 the original row is byte-identical after the reversal
 *   R-4 replaying the same reversal appends nothing
 *   R-5 a non-sale or zero row cannot be reversed
 *   U-1 the rollup equals a from-scratch rebuild (the card's assertion)
 *   U-2 sales count, refunds are separate, channels are grouped
 *   U-3 an empty day is all zeros, and version only moves forward
 *   U-4 unusable ids and rows fail closed
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  LEDGER_COLLECTION,
  LedgerValidationError,
  appendReversal,
  buildReversalRow,
  buildSaleRow,
  reversalDocId,
} = require('../lib/ledger.js');

const {
  ROLLUP_COLLECTION,
  RollupValidationError,
  computeRollup,
  rebuildDailyRollup,
  rollupDocId,
} = require('../lib/rollups.js');

/** Fake Firestore: commit-time apply, real snapshot.data(). */
function fakeStore(seed = {}) {
  const docs = new Map(Object.entries(seed));

  const store = {
    collection(name) {
      return {doc: (id) => ({id, path: `${name}/${id}`})};
    },
    async runTransaction(fn) {
      const staged = [];
      const tx = {
        async get(ref) {
          const value = docs.get(ref.path);
          return {
            exists: value !== undefined,
            data: () => (value === undefined ? undefined : {...value}),
          };
        },
        set(ref, data) {
          staged.push([ref.path, data]);
        },
      };
      const result = await fn(tx);
      for (const [path, data] of staged) docs.set(path, data);
      return result;
    },
  };

  return {store, docs};
}

function saleRow(overrides = {}) {
  return buildSaleRow({
    orderId: 'order-1',
    orderNumber: 'HB-1',
    branchId: 'branch-1',
    customerId: 'user-1',
    paymentIntentId: 'pi_1',
    totalCents: 4200,
    taxCents: 200,
    tipCents: 300,
    discountCents: 100,
    deliveryFeeCents: 500,
    currency: 'cad',
    channel: 'web',
    createdAt: 'TS',
    ...overrides,
  });
}

test('R-1: the reversal mirrors the original with the opposite sign', () => {
  const original = saleRow();
  const row = buildReversalRow({
    originalRowId: 'sale_order-1',
    original,
    reason: 'customer complaint',
    actorUid: 'staff-1',
    createdAt: 'TS2',
  });

  assert.equal(row.id, reversalDocId('sale_order-1'));
  assert.equal(row.kind, 'reversal');
  assert.equal(row.status, 'reversed');
  assert.equal(row.reversalOf, 'sale_order-1');
  assert.equal(row.reversalReason, 'customer complaint');
  assert.equal(row.totalCents, -4200);
  assert.equal(row.taxCents, -200);
  assert.equal(row.tipCents, -300);
  assert.equal(row.discountCents, -100);
  assert.equal(row.deliveryFeeCents, -500);
  assert.equal(row.orderId, original.orderId);
  assert.equal(row.branchId, original.branchId);
  assert.equal(row.channel, original.channel);
  assert.equal(row.currency, original.currency);
  assert.equal(row.actorUid, 'staff-1');
});

test('R-2: a missing original is refused and nothing is written', async () => {
  const {store, docs} = fakeStore();
  const row = buildReversalRow({
    originalRowId: 'sale_order-1',
    original: saleRow(),
    reason: 'duplicate charge',
  });

  await assert.rejects(
      () => appendReversal(store, {id: 'sale_order-1', path: 'transactions/sale_order-1'}, row),
      (err) => err instanceof LedgerValidationError && err.field === 'original');

  assert.equal(docs.size, 0);
});

test('R-3: the original is byte-identical after the reversal', async () => {
  const original = saleRow();
  const {store, docs} = fakeStore({[`${LEDGER_COLLECTION}/sale_order-1`]: original});
  const before = JSON.stringify(docs.get('transactions/sale_order-1'));

  const result = await appendReversal(
      store,
      {id: 'sale_order-1', path: 'transactions/sale_order-1'},
      buildReversalRow({
        originalRowId: 'sale_order-1',
        original,
        reason: 'wrong item',
      }),
  );

  assert.equal(result, 'appended');
  assert.equal(JSON.stringify(docs.get('transactions/sale_order-1')), before,
      'the sale row must not change by a single byte');
  assert.equal(docs.get('transactions/rev_sale_order-1').totalCents, -4200);
  assert.equal(docs.size, 2, 'one sale + one reversal, nothing else');
});

test('R-4: replaying the same reversal appends nothing', async () => {
  const original = saleRow();
  const {store, docs} = fakeStore({[`${LEDGER_COLLECTION}/sale_order-1`]: original});
  const row = buildReversalRow({
    originalRowId: 'sale_order-1', original, reason: 'wrong item',
  });

  assert.equal(
      await appendReversal(store, {id: 'sale_order-1', path: 'transactions/sale_order-1'}, row),
      'appended');
  assert.equal(
      await appendReversal(store, {id: 'sale_order-1', path: 'transactions/sale_order-1'}, row),
      'kept');

  assert.equal(docs.size, 2, 'a retried reversal must not double the refund');
  assert.equal(docs.get('transactions/sale_order-1'), original);
});

test('R-5: a non-sale or zero row cannot be reversed', () => {
  for (const original of [
    {kind: 'reversal', totalCents: -100},
    {kind: 'sale', totalCents: 0},
    {kind: 'sale', totalCents: 'free'},
  ]) {
    assert.throws(
        () => buildReversalRow({
          originalRowId: 'sale_order-1', original, reason: 'x',
        }),
        (err) => err instanceof LedgerValidationError);
  }
  assert.throws(
      () => buildReversalRow({
        originalRowId: 'sale_order-1', original: saleRow(), reason: '   ',
      }),
      (err) => err instanceof LedgerValidationError && err.field === 'reason');
});

test('U-1: the rollup equals a from-scratch rebuild (card assertion)', async () => {
  const rows = [
    saleRow({orderId: 'o1', totalCents: 4200, channel: 'web'}),
    saleRow({orderId: 'o2', totalCents: 1800, channel: 'counter'}),
    saleRow({orderId: 'o3', totalCents: 1200, channel: 'web'}),
    buildReversalRow({
      originalRowId: 'sale_o2',
      original: saleRow({orderId: 'o2', totalCents: 1800, channel: 'counter'}),
      reason: 'refund',
    }),
  ];

  const {store, docs} = fakeStore({
    // The cache starts deliberately WRONG: a stale, hand-poisoned document.
    [`${ROLLUP_COLLECTION}/branch-1_20261110`]: {
      id: 'branch-1_20261110',
      revenueByChannel: {web: 999999},
      ordersCount: 42,
      avgTicketCents: 999999,
      refundsCents: 0,
      version: 7,
    },
  });

  const result = await rebuildDailyRollup(store, 'branch-1', '20261110', rows, 'TS');

  const stored = docs.get('daily_rollups/branch-1_20261110');
  const fromScratch = computeRollup(rows);

  assert.deepEqual(
      {
        revenueByChannel: stored.revenueByChannel,
        ordersCount: stored.ordersCount,
        avgTicketCents: stored.avgTicketCents,
        refundsCents: stored.refundsCents,
      },
      fromScratch,
      'the cache must equal a rebuild from the ledger, whatever it held before');
  assert.deepEqual(
      {
        revenueByChannel: result.revenueByChannel,
        ordersCount: result.ordersCount,
        avgTicketCents: result.avgTicketCents,
        refundsCents: result.refundsCents,
      },
      fromScratch);
  assert.equal(stored.version, 8, 'compare-and-set moves the version forward');
});

test('U-2: sales count, refunds are separate, channels are grouped', () => {
  const rows = [
    saleRow({orderId: 'o1', totalCents: 4200, channel: 'web'}),
    saleRow({orderId: 'o2', totalCents: 1800, channel: 'counter'}),
    buildReversalRow({
      originalRowId: 'sale_o2',
      original: saleRow({orderId: 'o2', totalCents: 1800, channel: 'counter'}),
      reason: 'refund',
    }),
    saleRow({orderId: 'o3', totalCents: 600, channel: undefined}),
  ];

  const totals = computeRollup(rows);

  assert.equal(totals.ordersCount, 3, 'a reversal never erases a sale from the count');
  assert.equal(totals.refundsCents, 1800);
  assert.deepEqual(totals.revenueByChannel, {
    web: 4200,
    counter: 0,
    unknown: 600,
  });
  assert.equal(totals.avgTicketCents, Math.round((4200 + 1800 + 600) / 3));
});

test('U-3: an empty day is all zeros and the version only moves forward', async () => {
  assert.deepEqual(computeRollup([]), {
    revenueByChannel: {},
    ordersCount: 0,
    avgTicketCents: 0,
    refundsCents: 0,
  });

  const {store, docs} = fakeStore();
  const first = await rebuildDailyRollup(store, 'branch-1', '20261110', []);
  const second = await rebuildDailyRollup(store, 'branch-1', '20261110', []);

  assert.equal(first.version, 1);
  assert.equal(second.version, 2);
  assert.equal(docs.get('daily_rollups/branch-1_20261110').ordersCount, 0);
});

test('U-4: unusable ids and rows fail closed', () => {
  assert.equal(rollupDocId('branch-1', '20261110'), 'branch-1_20261110');

  for (const [branchId, day] of [
    ['', '20261110'],
    ['branch-1', '2026-11-10'],
    ['branch-1', 20261110],
  ]) {
    assert.throws(
        () => rollupDocId(branchId, day),
        (err) => err instanceof RollupValidationError);
  }

  assert.throws(
      () => computeRollup([{kind: 'refund', totalCents: 100}]),
      (err) => err instanceof RollupValidationError && err.field === 'kind');
  assert.throws(
      () => computeRollup([{kind: 'sale', totalCents: 10.5}]),
      (err) => err instanceof RollupValidationError && err.field === 'totalCents');
});
