/**
 * RULES-2 (b11) T-4 migration emulator harness.
 *
 * Drives the REAL compiled migration
 * (`../lib/migrations/v003__seed_settings_owner_info.js`) against the REAL
 * Firestore + Auth emulators under `firebase emulators:exec --only
 * firestore,auth` (core_app/package.json `test:migrations` — same wiring
 * as the B1 money check in scripts/money_emulator_check.js).
 *
 * Assertions:
 *   T-4a  migrate() fails CLOSED when no owner-claim user exists
 *   T-4b  seeds settings/ownerInfo { ownerEmail, updatedAt }
 *   T-4c  second run is an idempotent no-op (doc.exists guard)
 *   T-4d  refuses to seed from a user WITHOUT the role=owner claim
 *   T-4e  recovers once the claim is restored (rerun-safe)
 */
'use strict';

const assert = require('node:assert/strict');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');

// Environment-driven configuration (no tenant hardcoding — B1 convention):
// GCLOUD_PROJECT is exported by emulators:exec; ports mirror firebase.json.
const PROJECT_ID =
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT_ID ||
  'demo-carnama';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: PROJECT_ID,
  storageBucket: `${PROJECT_ID}.appspot.com`,
});

// Initialize the DEFAULT app BEFORE loading the migration module (its
// module-scope `admin.firestore()` / `admin.auth()` bind to the default
// app).
initializeApp({projectId: PROJECT_ID});

const {migrate} = require(
    '../lib/migrations/v003__seed_settings_owner_info.js',
);

const db = getFirestore();
const auth = getAuth();

const OWNER_EMAIL = 'admin@carnama.com';
const OWNER_INFO = db.collection('settings').doc('ownerInfo');

// Assertion names (kept short to honor the 80-col lint budget).
const T4A = 'T-4a: fail-closed without the owner-claim user (v002 first)';
const T4B = 'T-4b: seeds settings/ownerInfo {ownerEmail, updatedAt}';
const T4C = 'T-4c: second run is an idempotent no-op (doc.exists guard)';
const T4D = 'T-4d: refuses a user without the role=owner claim';
const T4E = 'T-4e: recovers after the claim is restored (rerun-safe)';

let passed = 0;
let failed = 0;

function ok(name) {
  passed += 1;
  console.log(`  \u2714 ${name}`);
}
function bad(name, err) {
  failed += 1;
  console.log(`  \u2716 ${name}`);
  const stack = (err && err.stack) || '';
  console.error(`      ${stack.split('\n').slice(0, 4).join('\n      ')}`);
}

async function resetOwnerInfo() {
  await OWNER_INFO.delete().catch(() => {});
}

/** Provision the owner-claim user as v002 does (setup, not an assertion). */
async function provisionOwnerClaimUser() {
  let uid;
  try {
    uid = (await auth.getUserByEmail(OWNER_EMAIL)).uid;
  } catch {
    uid = (
      await auth.createUser({email: OWNER_EMAIL, password: 'AdminPass123'})
    ).uid;
  }
  await auth.setCustomUserClaims(uid, {role: 'owner'});
  return uid;
}

(async () => {
  console.log(`\nRULES-2 v003 migration check (project: ${PROJECT_ID})`);

  // T-4a — fail-closed when the owner user does not exist (fresh emulator).
  try {
    await resetOwnerInfo();
    let rejected = false;
    try {
      await migrate();
    } catch (err) {
      rejected = true;
      assert.match(String(err && err.message), /v002/);
    }
    assert.equal(
        rejected, true, 'migrate() should reject without the owner user');
    ok(T4A);
  } catch (err) {
    bad(T4A, err);
  }

  // Setup for T-4b/c: provision the owner-claim user.
  await provisionOwnerClaimUser();

  // T-4b — seeds settings/ownerInfo from the owner-claim user.
  try {
    await migrate();
    const doc = await OWNER_INFO.get();
    assert.equal(doc.exists, true, 'ownerInfo should exist after migrate()');
    assert.equal(doc.data().ownerEmail, OWNER_EMAIL);
    assert.ok(doc.data().updatedAt, 'updatedAt should be a timestamp');
    ok(T4B);
  } catch (err) {
    bad(T4B, err);
  }

  // T-4c — idempotent: a second run is a no-op (doc.exists guard).
  try {
    const before = (await OWNER_INFO.get()).data();
    await migrate();
    const after = (await OWNER_INFO.get()).data();
    assert.equal(after.ownerEmail, before.ownerEmail);
    assert.equal(after.updatedAt.toMillis(), before.updatedAt.toMillis());
    ok(T4C);
  } catch (err) {
    bad(T4C, err);
  }

  // T-4d — fail-closed when the user lost the owner claim (doc removed first,
  // because an existing doc short-circuits before the claim check).
  try {
    await resetOwnerInfo();
    const uid = (await auth.getUserByEmail(OWNER_EMAIL)).uid;
    await auth.setCustomUserClaims(uid, {});
    let rejected = false;
    try {
      await migrate();
    } catch (err) {
      rejected = true;
      assert.match(String(err && err.message), /role=owner/);
    }
    assert.equal(
        rejected, true, 'migrate() should refuse a non-owner claim');
    ok(T4D);
  } catch (err) {
    bad(T4D, err);
  }

  // T-4e — recovers once the claim is restored (rerun-safe bootstrap).
  try {
    const uid = (await auth.getUserByEmail(OWNER_EMAIL)).uid;
    await auth.setCustomUserClaims(uid, {role: 'owner'});
    await migrate();
    const doc = await OWNER_INFO.get();
    assert.equal(doc.exists, true);
    assert.equal(doc.data().ownerEmail, OWNER_EMAIL);
    ok(T4E);
  } catch (err) {
    bad(T4E, err);
  }

  console.log('──────────────────────────────────────────────');
  console.log(
      `  PASSED: ${passed}  FAILED: ${failed}  TOTAL: ${passed + failed}`);
  if (failed > 0) {
    process.exitCode = 1;
  }
})();
