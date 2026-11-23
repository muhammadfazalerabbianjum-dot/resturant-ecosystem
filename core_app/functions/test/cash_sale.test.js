/**
 * P2-1 — the cash sale, pure core. Written RED first.
 *
 *   S-1 a sale builds an order + its ledger input from server-derived money
 *   S-2 the total is subtotal + tax, never a client number
 *   S-3 change is tendered - total, and short tender fails closed
 *   S-4 a walk-in carries no customer, and the staff member is on both docs
 *   S-5 the ledger snapshot keeps names and unit prices, not references
 *   S-6 a void builds a reversal from the SALE row and cancels the order
 *   S-7 a card sale cannot be voided through the cash path
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {buildCashSale, buildCashVoid, CashSaleError} = require('../lib/cash_sale.js');
const {buildSaleRow} = require('../lib/ledger.js');

const NOW = new Date('2026-11-15T18:30:00Z');

function saleInput(overrides = {}) {
  return {
    orderId: 'order_cash_7',
    orderNumber: 'C-1007',
    tenantId: 'tenant_shell',
    branchId: 'branch_1',
    staffId: 'staff_uid_1',
    staffRoles: ['owner'],
    itemsSubtotalCents: 1106,
    taxCents: 144,
    taxRate: 0.13,
    currency: 'cad',
    canonicalItems: [
      {item: {id: 'menu_1', name: 'Shawarma', priceCents: 1106}, quantity: 1, selectedOptions: []},
    ],
    amountTenderedCents: 2000,
    now: NOW,
    ...overrides,
  };
}

test('S-1 a sale builds an order and its ledger input from server-derived money', () => {
  const {order, ledgerInput} = buildCashSale(saleInput());

  assert.equal(order.id, 'order_cash_7');
  assert.equal(order.status, 'confirmed', 'paid at the counter: the kitchen can start');
  assert.equal(order.channel, 'counter');
  assert.equal(order.paymentMethod, 'cash');
  assert.equal(order.totalCents, 1250);
  assert.equal(order.taxCents, 144);
  assert.equal(order.itemsSubtotalCents, 1106, 'named as the ledger names it');
  assert.equal(order.tenantId, 'tenant_shell');
  assert.equal(order.branchId, 'branch_1');
  assert.equal(order.staffId, 'staff_uid_1');
  assert.deepEqual(order.staffRoles, ['owner']);
  assert.equal(order.createdAt, NOW);
  assert.equal(order.updatedAt, NOW);

  // The ledger input must be buildable by the v2 row builder as-is.
  const row = buildSaleRow(ledgerInput);
  assert.equal(row.schemaVersion, 2);
  assert.equal(row.paymentMethod, 'cash');
  assert.equal(row.totalCents, 1250);
  assert.equal(row.changeCents, 750);
});

test('S-2 the total is subtotal + tax and unstorable inputs fail closed', () => {
  const {order} = buildCashSale(saleInput());
  assert.equal(order.totalCents, order.itemsSubtotalCents + order.taxCents);

  for (const [field, value] of [
    ['itemsSubtotalCents', -1],
    ['taxCents', 12.5],
    ['taxRate', 1.5],
  ]) {
    assert.throws(
      () => buildCashSale(saleInput({[field]: value})),
      (err) => err instanceof CashSaleError && err.field === field,
      `${field}=${value} must be rejected`,
    );
  }
});

test('S-3 change is tendered - total, and short tender fails closed', () => {
  const {order, ledgerInput} = buildCashSale(saleInput({amountTenderedCents: 1250}));
  assert.equal(order.changeCents, 0);
  assert.equal(ledgerInput.changeCents, 0);

  assert.throws(
    () => buildCashSale(saleInput({amountTenderedCents: 1200})),
    (err) => err instanceof CashSaleError && err.field === 'amountTenderedCents',
  );
});

test('S-4 a walk-in carries no customer; the staff member is on both documents', () => {
  const {order, ledgerInput} = buildCashSale(saleInput());
  assert.equal(order.customerId, '');
  assert.equal(ledgerInput.customerId, '');
  assert.equal(ledgerInput.staffId, 'staff_uid_1');
  assert.equal(order.staffId, 'staff_uid_1');
});

test('S-5 the ledger snapshot keeps names and unit prices, not references', () => {
  const input = saleInput();
  const {ledgerInput} = buildCashSale(input);

  assert.deepEqual(ledgerInput.items, [
    {name: 'Shawarma', unitPriceCents: 1106, quantity: 1},
  ]);

  input.canonicalItems[0].item.name = 'MUTATED';
  assert.equal(buildCashSale(input).ledgerInput.items[0].name, 'MUTATED');
  assert.equal(ledgerInput.items[0].name, 'Shawarma', 'the earlier snapshot is its own copy');
});

test('S-6 a void cancels the order and reverses the sale row', () => {
  const {order, ledgerInput} = buildCashSale(saleInput());
  const saleRow = buildSaleRow(ledgerInput);

  const {orderPatch, reversalRow} = buildCashVoid({
    order,
    saleRow,
    reason: 'wrong item rung up',
    actorUid: 'manager_uid_2',
    now: NOW,
  });

  assert.equal(orderPatch.status, 'cancelled');
  assert.equal(orderPatch.voidReason, 'wrong item rung up');
  assert.equal(orderPatch.voidedBy, 'manager_uid_2');
  assert.equal(reversalRow.kind, 'reversal');
  assert.equal(reversalRow.reversalOf, saleRow.id);
  assert.equal(reversalRow.totalCents, -1250);
  assert.equal(reversalRow.paymentMethod, 'cash');
});

test('S-8 a void commits the reversal and the cancelled order in ONE transaction', async () => {
  const {order, ledgerInput} = buildCashSale(saleInput());
  const saleRow = buildSaleRow(ledgerInput);
  const {orderPatch, reversalRow} = buildCashVoid({
    order,
    saleRow,
    reason: 'customer walked away',
    actorUid: 'manager_uid_2',
    now: NOW,
  });

  const {commitVoidWithReversal} = require('../lib/ledger.js');
  const staged = [];
  const store = {
    collection: () => ({
      doc: (id) => ({id, path: `transactions/${id}`}),
    }),
    async runTransaction(fn) {
      const tx = {
        async get(ref) {
          // The sale row exists; the reversal does not yet (first void).
          const isSale = ref.path.startsWith('transactions/sale_');
          return {
            exists: isSale,
            data: () => (isSale ? saleRow : order),
          };
        },
        set(ref, data) {
          staged.push([ref.path, data]);
        },
        update(ref, patch) {
          staged.push([ref.path, patch]);
        },
      };
      return fn(tx);
    },
  };

  const result = await commitVoidWithReversal(
      store,
      {id: saleRow.id, path: `transactions/${saleRow.id}`},
      reversalRow,
      {id: 'order_cash_7', path: 'orders/order_cash_7'},
      orderPatch,
  );

  assert.equal(result, 'appended');
  assert.equal(staged.length, 2, 'exactly two writes: the reversal and the order');
  assert.deepEqual(staged.map(([p]) => p).sort(), [
    'orders/order_cash_7',
    `transactions/${reversalRow.id}`,
  ]);
});

test('S-7 a card sale cannot be voided through the cash path', () => {
  const cardRow = buildSaleRow({
    orderId: 'order_card_1',
    customerId: 'customer_1',
    paymentIntentId: 'pi_1',
    totalCents: 500,
  });

  assert.throws(
    () =>
      buildCashVoid({
        order: {id: 'order_card_1', paymentMethod: 'card'},
        saleRow: cardRow,
        reason: 'x',
        actorUid: 'u',
        now: NOW,
      }),
    (err) => err instanceof CashSaleError && err.field === 'paymentMethod',
    'a card refund belongs to the Stripe path, not to a cash void',
  );

  // A void without a reason is refused too: the ledger reversal needs one.
  const {order, ledgerInput} = buildCashSale(saleInput());
  assert.throws(
    () =>
      buildCashVoid({
        order,
        saleRow: buildSaleRow(ledgerInput),
        reason: '   ',
        actorUid: 'u',
        now: NOW,
      }),
    (err) => err instanceof CashSaleError && err.field === 'reason',
  );
});
