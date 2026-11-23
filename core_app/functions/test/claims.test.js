/**
 * P1-5 — claims. Two claims under test:
 *
 *   C-*  the token's authority is a pure function of the users document, and a
 *        privilege change is detected (so refresh tokens can be revoked)
 *   S-*  a stale claim cannot pass the capability gate after revocation
 *
 *   C-1 claims carry tenantId, roles[] and branchIds[] (the card's shape)
 *   C-2 the legacy single role still authorises; roles[] wins when both exist
 *   C-3 an unknown role, a blank tenant or a bad branch list fails closed
 *   C-4 authority changes are detected; cosmetic edits are not
 *   C-5 a privilege change bumps claimsVersion; a demotion to nobody revokes
 *   C-6 the legacy single-role claim is only minted when unambiguous
 *   S-1 a token minted before the change is refused by the gate
 *   S-2 a fresh token passes, and a missing version counts as stale
 *   S-3 the freshness check cannot rescue an ungranted capability
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CLAIMS_SCHEMA_VERSION,
  ClaimsValidationError,
  buildUserClaims,
  claimsFingerprint,
  isStaleClaims,
  planClaimSync,
} = require('../lib/claims.js');

const {assertCapability, capabilityDenialCode} = require('../lib/access.js');

const doc = {
  tenantId: 'halal-boyz',
  roles: ['counter', 'waiter'],
  branchIds: ['b2', 'b1'],
  claimsVersion: 3,
};

test('C-1: claims carry tenantId, roles[] and branchIds[]', () => {
  const claims = buildUserClaims(doc);

  assert.equal(claims.schemaVersion, CLAIMS_SCHEMA_VERSION);
  assert.equal(claims.tenantId, 'halal-boyz');
  assert.deepEqual(claims.roles, ['counter', 'waiter']);
  assert.deepEqual(claims.branchIds, ['b1', 'b2'], 'branch order is normalised');
  assert.equal(claims.claimsVersion, 3);
  assert.equal(claims.role, undefined, 'two roles is not an unambiguous legacy role');
});

test('C-2: the legacy single role still authorises', () => {
  const claims = buildUserClaims({tenantId: 't', role: 'manager'});
  assert.deepEqual(claims.roles, ['manager']);
  assert.equal(claims.role, 'manager');

  // roles[] wins when both shapes are present (the migration shape).
  const both = buildUserClaims({tenantId: 't', role: 'customer', roles: ['manager']});
  assert.deepEqual(both.roles, ['manager']);
});

test('C-3: unknown roles and unusable fields fail closed', () => {
  for (const bad of [
    {tenantId: 't', roles: ['superadmin']},
    {tenantId: '  ', roles: ['owner']},
    {tenantId: 't', roles: []},
    {tenantId: 't', roles: 'owner'},
    {tenantId: 't', roles: ['owner'], branchIds: 'b1'},
    {tenantId: 't', roles: ['owner'], branchIds: ['']},
    {tenantId: 't', roles: ['owner'], claimsVersion: 0},
  ]) {
    assert.throws(
        () => buildUserClaims(bad),
        (err) => err instanceof ClaimsValidationError,
        JSON.stringify(bad));
  }
  assert.throws(() => buildUserClaims(null), ClaimsValidationError);
});

test('C-4: authority changes are detected, cosmetic edits are not', () => {
  const same = planClaimSync(doc, {...doc, displayName: 'Sam', phone: '+1'});
  assert.equal(same.revoke, false, 'a profile edit must not sign the staff out');
  assert.equal(same.claims.claimsVersion, 3, 'and must not bump the version');

  const roleAdded = planClaimSync(doc, {...doc, roles: ['counter', 'waiter', 'manager']});
  assert.equal(roleAdded.revoke, true);

  const branchAdded = planClaimSync(doc, {...doc, branchIds: ['b1', 'b2', 'b3']});
  assert.equal(branchAdded.revoke, true);

  const movedTenant = planClaimSync(doc, {...doc, tenantId: 'other-client'});
  assert.equal(movedTenant.revoke, true);

  const reordered = planClaimSync(doc, {...doc, roles: ['waiter', 'counter']});
  assert.equal(reordered.revoke, false, 'order is not authority');
});

test('C-5: a privilege change bumps the version; losing all roles revokes', () => {
  const promotion = planClaimSync(doc, {...doc, roles: ['counter', 'waiter', 'manager']});
  assert.equal(promotion.claims.claimsVersion, 4);

  const first = planClaimSync(null, {tenantId: 't', roles: ['owner']});
  assert.equal(first.revoke, true, 'a new privileged user starts a new token epoch');
  assert.equal(first.claims.claimsVersion, 1);

  const stripped = planClaimSync(doc, {tenantId: 'halal-boyz', roles: []});
  assert.deepEqual(stripped, {claims: null, revoke: true},
      'a user with no roles must lose every claim and every session');

  const deleted = planClaimSync(doc, null);
  assert.deepEqual(deleted, {claims: null, revoke: true});
});

test('C-6: the legacy claim and the fingerprint are stable', () => {
  const one = buildUserClaims({tenantId: 't', roles: ['kitchen']});
  assert.equal(one.role, 'kitchen');
  assert.equal(
      claimsFingerprint(one),
      claimsFingerprint(buildUserClaims({tenantId: 't', roles: ['kitchen'], role: 'x'})));
  assert.equal(claimsFingerprint(null), 'none');
});

test('S-1: a token minted before the change is refused by the gate', () => {
  const stale = {roles: ['manager'], tenantId: 't', claimsVersion: 3};

  const denied = assertCapability(
      {uid: 'u1', token: stale}, 'payment.refund', {claimsVersion: 4});

  assert.equal(denied.ok, false);
  assert.equal(denied.reason, 'stale_claims');
  assert.equal(capabilityDenialCode(denied), 'permission-denied');
});

test('S-2: a fresh token passes; a token with no version is stale', () => {
  assert.equal(
      assertCapability(
          {uid: 'u1', token: {roles: ['manager'], claimsVersion: 4}},
          'payment.refund',
          {claimsVersion: 4},
      ).ok,
      true);

  assert.equal(
      isStaleClaims({roles: ['manager']}, 1),
      true,
      'pre-P1-5 tokens carry no version at all');

  // Without the freshness requirement the gate is unchanged (opt-in rollout).
  assert.equal(
      assertCapability({uid: 'u1', token: {roles: ['manager']}}, 'payment.refund').ok,
      true);
});

test('S-3: freshness cannot rescue an ungranted capability', () => {
  const denied = assertCapability(
      {uid: 'u1', token: {roles: ['waiter'], claimsVersion: 9}},
      'payment.take',
      {claimsVersion: 9},
  );
  assert.equal(denied.ok, false);
  assert.equal(denied.reason, 'capability_not_granted');
});
