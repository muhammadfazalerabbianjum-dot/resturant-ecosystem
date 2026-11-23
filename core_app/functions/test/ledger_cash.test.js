/**
 * P2-1 / D-059 — the CASH sale row. Written RED first (repo law): every case
 * below fails against today's `buildSaleRow`, which requires a PaymentIntent.
 *
 *   C-1 a cash row names how it was paid and carries no PaymentIntent
 *   C-2 a cash row without its required cash facts fails closed, naming the field
 *   C-3 a card row is byte-compatible with today (schemaVersion 1, intent required)
 *   C-4 a row that is neither card nor cash fails closed
 *   C-5 a reversal of a cash row mirrors it and carries no intent
 *   C-6 the row's items snapshot is immutable data, not a reference
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  LedgerValidationError,
  buildSaleRow,
  buildReversalRow,
  ledgerDocId,
} = require('../lib/ledger.js');

/** The canonical cash row: everything the counter must supply. */
function cashInput(overrides = {}) {
  return {
    orderId: 'order_cash_1',
    orderNumber: 'C-1001',
    branchId: 'branch_1',
    customerId: '', // D-059/Q1: a walk-in has no customer account
    staffId: 'staff_uid_1',
    paymentMethod: 'cash',
    totalCents: 1250,
    taxCents: 144,
    taxRate: 0.13,
    items: [
      {name: 'Shawarma', unitPriceCents: 1106, quantity: 1},
    ],
    amountTenderedCents: 2000,
    changeCents: 750,
    channel: 'counter',
    currency: 'cad',
    ...overrides,
  };
}

test('C-1 a cash row names how it was paid and carries no PaymentIntent', () => {
  const row = buildSaleRow(cashInput());

  assert.equal(row.id, ledgerDocId('order_cash_1'));
  assert.equal(row.schemaVersion, 2, 'cash needs the v2 shape');
  assert.equal(row.kind, 'sale');
  assert.equal(row.paymentMethod, 'cash');
  assert.equal(row.paymentIntentId, null, 'a cash sale has no processor reference');
  assert.equal(row.staffId, 'staff_uid_1');
  assert.equal(row.customerId, '');
  assert.equal(row.totalCents, 1250);
  assert.equal(row.taxCents, 144);
  assert.equal(row.taxRate, 0.13);
  assert.equal(row.amountTenderedCents, 2000);
  assert.equal(row.changeCents, 750);
  assert.equal(row.channel, 'counter');
  assert.equal(row.items.length, 1);
  assert.equal(row.items[0].name, 'Shawarma');
});

test('C-2 a cash row without its cash facts fails closed, naming the field', () => {
  for (const field of [
    'staffId',
    'items',
    'taxRate',
    'amountTenderedCents',
    'changeCents',
  ]) {
    const input = cashInput();
    delete input[field];
    assert.throws(
      () => buildSaleRow(input),
      (err) => err instanceof LedgerValidationError && err.field === field,
      `missing ${field} must be rejected naming ${field}`,
    );
  }
});

test('C-3 a card row is byte-identical to v1, and an intent is still required', () => {
  const row = buildSaleRow({
    orderId: 'order_card_1',
    customerId: 'customer_1',
    paymentIntentId: 'pi_123',
    totalCents: 500,
  });
  assert.equal(row.schemaVersion, 1);
  assert.equal(row.paymentIntentId, 'pi_123');
  // NOT 'card': `ledger.test.js` L-9 pins the v1 key set exactly, so a card row
  // must not gain a field it never had. The intent IS the card marker; cash is
  // the only shape that needs to say how it was paid.
  assert.equal(Object.hasOwn(row, 'paymentMethod'), false);

  assert.throws(
    () =>
      buildSaleRow({
        orderId: 'order_card_2',
        customerId: 'customer_1',
        totalCents: 500,
      }),
    (err) => err instanceof LedgerValidationError && err.field === 'paymentIntentId',
  );
});

test('C-4 a row that is neither card nor cash fails closed', () => {
  // A card-shaped row with no intent: rejected on the intent field.
  assert.throws(
    () =>
      buildSaleRow({
        orderId: 'order_neither_1',
        customerId: 'customer_1',
        totalCents: 500,
      }),
    (err) => err instanceof LedgerValidationError && err.field === 'paymentIntentId',
  );

  // An unknown payment method is named, never silently treated as cash.
  assert.throws(
    () => buildSaleRow(cashInput({paymentMethod: 'voucher'})),
    (err) => err instanceof LedgerValidationError && err.field === 'paymentMethod',
  );
});

test('C-5 a reversal of a cash row mirrors it and carries no intent', () => {
  const sale = buildSaleRow(cashInput());
  const reversal = buildReversalRow({
    originalRowId: sale.id,
    original: sale,
    reason: 'wrong order',
    actorUid: 'manager_uid',
  });

  assert.equal(reversal.kind, 'reversal');
  assert.equal(reversal.reversalOf, sale.id);
  assert.equal(reversal.paymentMethod, 'cash');
  assert.equal(reversal.staffId, 'staff_uid_1', 'the operator stays on the record');
  assert.equal(reversal.paymentIntentId, null);
  assert.equal(reversal.totalCents, -1250);
  assert.equal(reversal.taxCents, -144);
});

test('C-6 the items snapshot is copied, never referenced', () => {
  const input = cashInput();
  const row = buildSaleRow(input);
  input.items[0].name = 'MUTATED AFTER THE SALE';

  assert.equal(row.items[0].name, 'Shawarma');
  assert.notEqual(row.items, input.items, 'the row must not alias the caller array');
});
