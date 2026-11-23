/**
 * C-9 / D-059 — the ledger and the data subject.
 *
 * Written RED first: `ledger_privacy` did not exist, and before it the erasure
 * set (`collectUserDocs`) never reached `transactions` at all, so a DSAR left
 * every sale row pointing at the person who asked to be forgotten.
 *
 *   A-1 an erasure anonymises the caller's rows: identifiers null, amounts kept
 *   A-2 rows belonging to someone else are never touched
 *   A-3 a row that was never personal (no identifier field) is left alone
 *   A-4 anonymisation is idempotent — a second pass writes nothing
 *   A-5 the Art.15/20 export includes the caller's own rows, bounded
 *   A-6 a row whose identifiers are already null is not re-stamped
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  IDENTIFIER_FIELDS,
  buildAnonymisationPatch,
  anonymiseLedgerRows,
  collectLedgerRows,
} = require('../lib/ledger_privacy.js');

/** Minimal Firestore-shaped fake: where/limit/get + batch(). */
function fakeDb(seed) {
  const rows = new Map(seed.map((row) => [row.id, {...row}]));
  const writes = [];

  const query = (collectionName, filters = [], cap = Infinity) => ({
    where(field, op, value) {
      assert.equal(op, '==', 'only equality is used');
      return query(collectionName, [...filters, [field, value]], cap);
    },
    limit(n) {
      return query(collectionName, filters, n);
    },
    async get() {
      assert.equal(collectionName, 'transactions');
      const matched = [...rows.values()]
        .filter((row) => filters.every(([field, value]) => row[field] === value))
        .slice(0, cap)
        .map((row) => ({
          id: row.id,
          ref: {id: row.id},
          data: () => ({...row}),
        }));
      return {docs: matched};
    },
  });

  return {
    rows,
    writes,
    db: {
      collection: (name) => query(name),
      batch: () => ({
        update(ref, patch) {
          writes.push({id: ref.id, patch});
        },
        async commit() {
          for (const {id, patch} of writes) {
            rows.set(id, {...rows.get(id), ...patch});
          }
        },
      }),
    },
  };
}

const AT = new Date('2026-11-15T12:00:00Z');

const saleRow = (id, overrides = {}) => ({
  id,
  kind: 'sale',
  schemaVersion: 2,
  orderId: `order_${id}`,
  customerId: '',
  staffId: 'staff_uid',
  paymentMethod: 'cash',
  totalCents: 1250,
  taxCents: 144,
  ...overrides,
});

test('A-1 an erasure anonymises the caller\'s rows and keeps the money', async () => {
  const {db, rows} = fakeDb([
    saleRow('sale_1', {customerId: 'user_1', staffId: 'user_1'}),
  ]);

  const count = await anonymiseLedgerRows(db, 'user_1', AT);
  const row = rows.get('sale_1');

  assert.equal(count, 1);
  assert.equal(row.customerId, null);
  assert.equal(row.staffId, null);
  assert.ok(row.anonymisedAt, 'the row records when it was anonymised');
  assert.equal(row.totalCents, 1250, 'the taxable amount is untouched');
  assert.equal(row.taxCents, 144);
  assert.equal(row.orderId, 'order_sale_1');
  assert.equal(row.paymentMethod, 'cash');
  assert.deepEqual(Object.keys(row).sort(), [
    'anonymisedAt', 'customerId', 'id', 'kind', 'orderId', 'paymentMethod',
    'schemaVersion', 'staffId', 'taxCents', 'totalCents',
  ]);
});

test('A-2 another person\'s rows are never touched', async () => {
  const {db, rows} = fakeDb([
    saleRow('sale_mine', {customerId: 'user_1'}),
    saleRow('sale_theirs', {customerId: 'user_2', staffId: 'user_2'}),
  ]);

  await anonymiseLedgerRows(db, 'user_1', AT);

  assert.equal(rows.get('sale_theirs').customerId, 'user_2');
  assert.equal(rows.get('sale_theirs').anonymisedAt, undefined);
});

test('A-3 a row with no identifier for this user is left alone', async () => {
  const {db, writes} = fakeDb([saleRow('sale_walkin', {customerId: '', staffId: 'someone_else'})]);

  const count = await anonymiseLedgerRows(db, 'user_1', AT);

  assert.equal(count, 0);
  assert.equal(writes.length, 0);
});

test('A-4 anonymisation is idempotent — a second pass writes nothing', async () => {
  const {db, rows} = fakeDb([saleRow('sale_1', {customerId: 'user_1'})]);

  await anonymiseLedgerRows(db, 'user_1', AT);
  const stamped = rows.get('sale_1').anonymisedAt;

  const second = await anonymiseLedgerRows(db, 'user_1', new Date('2026-11-16T00:00:00Z'));

  assert.equal(second, 0, 'nothing left to do the second time');
  assert.equal(rows.get('sale_1').anonymisedAt, stamped, 'the first stamp is kept');
});

test('A-5 the export includes the caller\'s own rows, bounded', async () => {
  const {db} = fakeDb([
    saleRow('sale_1', {customerId: 'user_1'}),
    saleRow('sale_2', {customerId: 'user_1'}),
    saleRow('sale_3', {customerId: 'user_2'}),
  ]);

  const rows = await collectLedgerRows(db, 'user_1', 2);

  assert.equal(rows.length, 2);
  assert.ok(rows.every((r) => r.customerId === 'user_1'));
});

test('A-6 the patch only mentions fields the row actually has', () => {
  const cardRow = {id: 'sale_card', totalCents: 500, customerId: 'user_1'};
  const patch = buildAnonymisationPatch(cardRow, AT);

  assert.deepEqual(Object.keys(patch).sort(), ['anonymisedAt', 'customerId']);
  assert.equal(patch.customerId, null);
  assert.equal(Object.hasOwn(patch, 'staffId'), false, 'a card row has no staffId');

  const alreadyDone = {id: 'sale_done', customerId: null, anonymisedAt: AT};
  assert.deepEqual(buildAnonymisationPatch(alreadyDone, AT), {});
  assert.deepEqual(IDENTIFIER_FIELDS, ['customerId', 'staffId', 'actorUid']);
});
