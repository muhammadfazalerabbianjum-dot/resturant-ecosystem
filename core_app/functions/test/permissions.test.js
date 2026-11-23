/**
 * P1-1 — the capability table (handoff §9.2).
 *
 * The expected matrix below is written out INDEPENDENTLY of the table in
 * `src/permissions.ts`: a matrix generated from the table would pass even if the
 * table were wrong. Changing a grant therefore requires changing this file too,
 * which is the point.
 *
 *   M-1 the full role × capability cartesian product matches the spec
 *   M-2 a waiter-only user holds no money authority
 *   M-3 a counter user may take money but may not refund or reverse it
 *   M-4 kitchen holds ticket capabilities and no money capability
 *   M-5 customer holds nothing server-side
 *   M-6 unknown roles and unknown capabilities fail closed
 *   M-7 every declared capability is granted to at least one role
 *   M-8 canAny honours multi-role callers and ignores junk
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {ROLES, CAPABILITIES, can, canAny, grantsFor} = require('../lib/permissions.js');

const EXPECTED = {
  owner: [...CAPABILITIES],
  manager: [
    'order.create', 'order.add_items', 'order.transition', 'order.set_item_ready',
    'order.flag_delay', 'order.cancel', 'payment.take', 'payment.refund',
    'payment.reverse', 'table.open', 'table.close', 'shift.clock', 'report.read',
    'menu.manage', 'fleet.dispatch',
  ],
  counter: [
    'order.create', 'order.add_items', 'order.transition', 'payment.take',
    'table.open', 'table.close', 'shift.clock',
  ],
  waiter: [
    'order.create', 'order.add_items', 'order.transition', 'table.open',
    'table.close', 'shift.clock',
  ],
  kitchen: ['order.transition', 'order.set_item_ready', 'order.flag_delay'],
  delivery: ['order.transition', 'fleet.dispatch'],
  customer: [],
};

test('M-1 the full role × capability matrix matches the spec', () => {
  for (const role of ROLES) {
    for (const capability of CAPABILITIES) {
      assert.equal(
          can(role, capability),
          EXPECTED[role].includes(capability),
          `${role} × ${capability}`,
      );
    }
  }
});

test('M-2 a waiter-only user holds no money authority', () => {
  for (const capability of ['payment.take', 'payment.refund', 'payment.reverse']) {
    assert.equal(can('waiter', capability), false, capability);
  }
});

test('M-3 the counter takes money but may not refund or reverse it', () => {
  assert.equal(can('counter', 'payment.take'), true);
  assert.equal(can('counter', 'payment.refund'), false);
  assert.equal(can('counter', 'payment.reverse'), false);
});

test('M-4 kitchen holds ticket capabilities and no money capability', () => {
  assert.equal(can('kitchen', 'order.set_item_ready'), true);
  assert.equal(can('kitchen', 'order.flag_delay'), true);
  assert.equal(can('kitchen', 'payment.take'), false);
  assert.equal(can('kitchen', 'payment.refund'), false);
});

test('M-5 customer holds nothing server-side', () => {
  assert.deepEqual(EXPECTED.customer, []);
  for (const capability of CAPABILITIES) {
    assert.equal(can('customer', capability), false, capability);
  }
});

test('M-6 unknown roles and unknown capabilities fail closed', () => {
  assert.equal(can('superadmin', 'payment.take'), false);
  assert.equal(can('OWNER', 'payment.take'), false); // exact literals only
  assert.equal(can('owner', 'payment.mint'), false);
  assert.deepEqual(grantsFor('superadmin'), []);
});

test('M-7 every declared capability is granted to at least one role', () => {
  for (const capability of CAPABILITIES) {
    const holders = ROLES.filter((role) => can(role, capability));
    assert.ok(holders.length > 0, `${capability} granted to nobody`);
  }
});

test('M-8 canAny honours multi-role callers and ignores junk', () => {
  assert.equal(canAny(['waiter'], 'payment.take'), false);
  assert.equal(canAny(['waiter', 'counter'], 'payment.take'), true);
  assert.equal(canAny(['waiter', 'counter'], 'payment.refund'), false);
  assert.equal(canAny(['kitchen', 'waiter'], 'order.create'), true);

  for (const junk of [null, undefined, 'counter', 42, {}, [], [7, null], [null]]) {
    assert.equal(canAny(junk, 'payment.take'), false, JSON.stringify(junk));
  }
  // Junk beside a real role is ignored, not fatal: the valid role still counts.
  assert.equal(canAny(['counter', 7], 'payment.take'), true);
});
