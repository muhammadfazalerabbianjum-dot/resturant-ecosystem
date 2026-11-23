/**
 * P1-1 — the server capability gate (`assertCapability` / `capabilityDenialCode`)
 * and its Phase 1 acceptance case: a waiter-only caller is denied `payment.take`
 * by the server, with the error code the onCall wrapper would throw.
 *
 *   G-1 waiter-only is denied payment.take → permission-denied
 *   G-2 multi-role caller is admitted for a capability one of their roles holds
 *   G-3 the legacy single `role` claim still authorises during migration
 *   G-4 an empty/absent role claim is rejected (missing_role_claim)
 *   G-5 no auth context is rejected (missing_auth_context)
 *   G-6 non-string entries in roles[] are ignored, not trusted
 *   G-7 a role echoed in the request payload is never consulted
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {assertCapability, capabilityDenialCode} = require('../lib/access.js');

const auth = (token) => ({uid: 'staff-1', token});

test('G-1 waiter-only is denied payment.take → permission-denied', () => {
  const result = assertCapability(auth({roles: ['waiter']}), 'payment.take');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'capability_not_granted');
  assert.deepEqual(result.roles, ['waiter']);
  assert.equal(capabilityDenialCode(result), 'permission-denied');

  // The same caller keeps the capabilities their role does hold.
  const allowed = assertCapability(auth({roles: ['waiter']}), 'table.open');
  assert.equal(allowed.ok, true);
  assert.equal(capabilityDenialCode(allowed), null);
});

test('G-2 multi-role caller is admitted where any role grants', () => {
  const token = {roles: ['waiter', 'counter']};
  assert.equal(assertCapability(auth(token), 'payment.take').ok, true);
  assert.equal(assertCapability(auth(token), 'payment.refund').ok, false);
});

test('G-3 the legacy single role claim still authorises during migration', () => {
  const result = assertCapability(auth({role: 'manager'}), 'payment.refund');
  assert.equal(result.ok, true);
  assert.deepEqual(result.roles, ['manager']);
});

test('G-4 an empty or absent role claim is rejected (missing_role_claim)', () => {
  for (const token of [{}, {roles: []}, {roles: [], role: ''}, {role: 7}]) {
    const result = assertCapability(auth(token), 'payment.take');
    assert.equal(result.ok, false, JSON.stringify(token));
    assert.equal(result.reason, 'missing_role_claim');
    assert.equal(capabilityDenialCode(result), 'permission-denied');
  }
});

test('G-5 no auth context is rejected (missing_auth_context)', () => {
  for (const absent of [null, undefined]) {
    const result = assertCapability(absent, 'payment.take');
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'missing_auth_context');
  }
});

test('G-6 non-string entries in roles[] are ignored, not trusted', () => {
  const result = assertCapability(auth({roles: [1, null, {role: 'owner'}, 'waiter']}), 'payment.take');
  assert.equal(result.ok, false);
  assert.deepEqual(result.roles, ['waiter']);
});

test('G-7 a role echoed in the request payload is never consulted', () => {
  const request = {auth: {uid: 'u', token: {roles: ['waiter']}}, data: {role: 'owner'}};
  const result = assertCapability(request.auth, 'payment.take');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'capability_not_granted');
});
