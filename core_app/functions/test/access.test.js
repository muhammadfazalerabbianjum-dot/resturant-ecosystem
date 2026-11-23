/**
 * BACKEND-2 (W7.4/T-3, 06-P1-4) — staff gate for dispatchToFleet.
 *
 * Runs against the compiled pure module `../lib/access.js` (mirrors the
 * money.test.js / ddos.test.js pattern). Every behaviour the batch must
 * prove is asserted directly against the SERVER-side decision logic —
 * no mocks, no stubs:
 *   T-S1 every STAFF_ROLES literal passes the gate
 *   T-S2 the 'customer' role is rejected (role_not_staff)
 *   T-S3 a missing/empty role claim is rejected (missing_role_claim)
 *   T-S4 an unauthenticated call is rejected (missing_auth_context)
 *   T-S5 an invented role literal can never pass (fail-closed allowlist)
 *   T-S6 STAFF_ROLES mirrors the client UserRole staff members exactly
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {STAFF_ROLES, assertStaffRole} = require('../lib/access.js');

const staffAuth = (role) => ({uid: 'staff-1', token: {role}});

test('T-S1 every staff role passes the gate', () => {
  for (const role of STAFF_ROLES) {
    const result = assertStaffRole(staffAuth(role));
    assert.deepEqual(result, {ok: true, role, reason: null});
  }
});

test('T-S2 the customer role is rejected (role_not_staff)', () => {
  const result = assertStaffRole(staffAuth('customer'));
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'role_not_staff');
  assert.equal(result.role, null);
});

test('T-S3 a missing or empty role claim is rejected (missing_role_claim)', () => {
  assert.equal(
    assertStaffRole({uid: 'u', token: {}}).reason,
    'missing_role_claim',
  );
  assert.equal(
    assertStaffRole({uid: 'u', token: {role: ''}}).reason,
    'missing_role_claim',
  );
  assert.equal(
    assertStaffRole({uid: 'u', token: {role: 42}}).reason,
    'missing_role_claim',
  );
});

test('T-S4 an unauthenticated call is rejected (missing_auth_context)', () => {
  assert.equal(assertStaffRole(null).reason, 'missing_auth_context');
  assert.equal(assertStaffRole(undefined).reason, 'missing_auth_context');
});

test('T-S5 an invented role literal can never pass (fail-closed allowlist)', () => {
  for (const role of ['admin', 'superuser', 'staff', 'OWNER', 'owner ']) {
    assert.equal(assertStaffRole(staffAuth(role)).ok, false, role);
  }
});

test('T-S6 STAFF_ROLES mirrors the client UserRole staff members exactly', () => {
  assert.deepEqual([...STAFF_ROLES], ['owner', 'manager', 'kitchen', 'delivery']);
});
