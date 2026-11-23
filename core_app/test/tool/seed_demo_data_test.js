/**
 * seed_demo_data_test.js — Rule 9 test for tool/seed_demo_data.js.
 *
 * Runs against the RUNNING Firebase emulator (same conventions as the money /
 * gdpr / migration harnesses: env-driven project, ok/bad counters, exit code).
 * It is a REAL test: every assertion reads back seeded state from the emulator
 * and fails (exit 1) when the seed is missing or violates the model contracts
 * (Rule 0 sources cited inline).
 *
 * Run (from core_app/, emulator running, AFTER node tool/seed_demo_data.js):
 *   node test/tool/seed_demo_data_test.js
 */
'use strict';

const path = require('path');
module.paths.push(path.join(__dirname, '..', '..', 'functions', 'node_modules'));

const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID =
  process.env.GCLOUD_PROJECT || process.env.DEMO_PROJECT_ID || 'resturants-8547d';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();
const auth = getAuth();

let passed = 0;
let failed = 0;
function ok(name) { passed += 1; console.log(`  ✔ ${name}`); }
function bad(name, err) {
  failed += 1;
  console.error(`  ✖ ${name}${err ? ` — ${err.message ?? err}` : ''}`);
}

async function check(name, fn) {
  try { await fn(); ok(name); } catch (e) { bad(name, e); }
}

async function run() {
  console.log(`[seed_demo_data_test] project ${PROJECT_ID} @ ${process.env.FIRESTORE_EMULATOR_HOST}`);

  // ── Branches (v001 shape; merged_menu_provider.dart:46-56 read path) ────
  await check('branches: >=2 branches, branch_main isDefault+isMainBranch with geo', async () => {
    const snap = await db.collection('branches').get();
    assert.ok(snap.size >= 2, `expected >=2 branches, got ${snap.size}`);
    const main = snap.docs.find((d) => d.id === 'branch_main');
    assert.ok(main, 'branch_main missing');
    const m = main.data();
    assert.equal(m.isDefault, true);
    assert.equal(m.isMainBranch, true);
    assert.equal(typeof m.name, 'string');
    assert.ok(m.name.length > 0);
    assert.equal(typeof m.latitude, 'number');
    assert.equal(typeof m.longitude, 'number');
    assert.equal(typeof m.deliveryRadiusMiles, 'number');
    assert.ok(snap.docs.some((d) => d.id === 'branch_downtown'), 'branch_downtown missing');
  });

  // ── Menus (admin/domain/menu_item_model.dart:11-23 contract) ─────────────
  const menus = await db.collection('menus').get();
  await check('menus: >=12 items, >=3 categories, >=2 branches represented', () => {
    assert.ok(menus.size >= 12, `expected >=12 menu items, got ${menus.size}`);
    const categories = new Set(menus.docs.map((d) => d.data().category));
    assert.ok(categories.size >= 3, `expected >=3 categories, got ${categories.size}`);
    const branchIds = new Set(menus.docs.map((d) => d.data().branchId));
    assert.ok(branchIds.size >= 2, `expected >=2 branchIds, got ${branchIds.size}`);
  });

  await check('menus: EVERY item carries every model attribute with the right type', () => {
    for (const d of menus.docs) {
      const it = d.data();
      const where = `menus/${d.id}`;
      assert.equal(typeof it.name, 'string', `${where}.name`);
      assert.ok(it.name.length > 0, `${where}.name empty`);
      assert.equal(typeof it.description, 'string', `${where}.description`);
      assert.ok(it.description.length > 0, `${where}.description empty`);
      assert.ok(Number.isInteger(it.priceCents), `${where}.priceCents must be an integer`);
      assert.ok(it.priceCents >= 0, `${where}.priceCents negative`);
      assert.equal(typeof it.category, 'string', `${where}.category`);
      assert.ok(it.category.length > 0, `${where}.category empty`);
      assert.ok(it.imageUrl === '' || typeof it.imageUrl === 'string', `${where}.imageUrl`);
      assert.ok(Array.isArray(it.tags), `${where}.tags must be a list`);
      assert.equal(typeof it.isAvailable, 'boolean', `${where}.isAvailable must be bool`);
      assert.ok(
        it.quantityRemaining === null || it.quantityRemaining === undefined ||
        Number.isInteger(it.quantityRemaining),
        `${where}.quantityRemaining must be int|null`,
      );
      assert.equal(typeof it.branchId, 'string', `${where}.branchId`);
      assert.ok(it.branchId.length > 0, `${where}.branchId empty`);
      assert.ok(Array.isArray(it.modifiers), `${where}.modifiers must be a list`);
    }
  });

  await check('menus: modifier groups — required single-choice (Size, isDefault Small) + optional multi-select (Extras, one isDefault)', () => {
    const withMods = menus.docs.filter((d) => (d.data().modifiers || []).length > 0);
    assert.ok(withMods.length >= 2, `expected >=2 items with modifier groups, got ${withMods.length}`);
    for (const d of withMods) {
      for (const g of d.data().modifiers) {
        assert.equal(typeof g.id, 'string', 'group id');
        assert.equal(typeof g.name, 'string', 'group name');
        assert.equal(typeof g.isRequired, 'boolean', 'group isRequired');
        assert.equal(typeof g.allowMultiple, 'boolean', 'group allowMultiple');
        assert.ok(Array.isArray(g.options) && g.options.length >= 2, 'group options');
        for (const o of g.options) {
          assert.equal(typeof o.id, 'string');
          assert.equal(typeof o.name, 'string');
          assert.ok(Number.isInteger(o.upchargeCents), 'upchargeCents int');
          assert.equal(typeof o.isDefault, 'boolean');
        }
        const defaults = g.options.filter((o) => o.isDefault);
        assert.equal(defaults.length, 1, `group ${g.id} must have exactly one isDefault`);
      }
    }
    // Required single-choice: Size — Small default (0), Large upcharge (150).
    const burger = menus.docs.find((d) => d.id === 'demo_smash_burger');
    assert.ok(burger, 'demo_smash_burger missing');
    const size = burger.data().modifiers.find((g) => g.name === 'Size');
    assert.ok(size, 'Size group missing on demo_smash_burger');
    assert.equal(size.isRequired, true, 'Size must be required');
    assert.equal(size.allowMultiple, false, 'Size must be single-choice');
    const small = size.options.find((o) => o.name === 'Small');
    const large = size.options.find((o) => o.name === 'Large');
    assert.equal(small.upchargeCents, 0, 'Small +0');
    assert.equal(small.isDefault, true, 'isDefault on Small');
    assert.ok(large.upchargeCents > 0, 'Large carries an upcharge');
    // Optional multi-select: Extras — exactly one default option.
    const wrap = menus.docs.find((d) => d.id === 'demo_chicken_overload_wrap');
    assert.ok(wrap, 'demo_chicken_overload_wrap missing');
    const extras = wrap.data().modifiers.find((g) => g.name === 'Extras');
    assert.ok(extras, 'Extras group missing on demo_chicken_overload_wrap');
    assert.equal(extras.isRequired, false, 'Extras must be optional');
    assert.equal(extras.allowMultiple, true, 'Extras must be multi-select');
    assert.equal(extras.options.filter((o) => o.isDefault).length, 1, 'Extras: one isDefault option');
  });

  await check('menus: one isAvailable:false item and one quantityRemaining:0 item', () => {
    const unavailable = menus.docs.filter((d) => d.data().isAvailable === false);
    assert.ok(unavailable.length >= 1, 'no isAvailable:false item');
    const soldOut = menus.docs.filter((d) => d.data().quantityRemaining === 0);
    assert.ok(soldOut.length >= 1, 'no quantityRemaining:0 item');
  });

  // ── Staff accounts (auth user + claim + users doc per user_model.dart) ───
  const STAFF = [
    { email: 'admin@carnama.com', role: 'owner', branchId: '' },
    { email: 'kitchen@carnama.com', role: 'kitchen', branchId: 'branch_main' },
    { email: 'delivery@carnama.com', role: 'delivery', branchId: 'branch_main' },
    { email: 'customer@carnama.com', role: 'customer', branchId: '' },
  ];
  for (const s of STAFF) {
    await check(`staff: ${s.email} — auth user exists with role=${s.role} claim + users doc`, async () => {
      const u = await auth.getUserByEmail(s.email);
      assert.equal(u.customClaims?.role, s.role, 'claim role');
      const doc = await db.collection('users').doc(u.uid).get();
      assert.ok(doc.exists, 'users doc missing');
      const d = doc.data();
      assert.equal(d.role, s.role, 'users doc role (userRole() reads this, rules:54-59)');
      assert.equal(d.email, s.email);
      assert.equal(d.branchId ?? '', s.branchId, 'users doc branchId');
      assert.equal(d.id, u.uid);
      assert.ok(Array.isArray(d.assignedOrderIds ?? []), 'assignedOrderIds list');
      assert.equal(typeof d.loyaltyPoints, 'number');
    });
  }

  // ── settings/featureFlags — bool map, public read (rules:273-279) ────────
  await check('settings/featureFlags: exists, all values are bools, smartReorder/promoCode/deliveryEnabled true', async () => {
    const doc = await db.collection('settings').doc('featureFlags').get();
    assert.ok(doc.exists, 'featureFlags doc missing');
    const flags = doc.data();
    assert.ok(Object.keys(flags).length > 0, 'flags map empty');
    for (const [k, v] of Object.entries(flags)) {
      assert.equal(typeof v, 'boolean', `flag ${k} must be bool (got ${typeof v})`);
    }
    assert.equal(flags.smartReorder, true);
    assert.equal(flags.promoCode, true);
    assert.equal(flags.deliveryEnabled, true);
  });

  // ── Checkout config the charge path re-reads (index.ts:905-925) ──────────
  await check('settings/taxRates + settings/restaurantConfig present for the charge re-derivation', async () => {
    const tax = await db.collection('settings').doc('taxRates').get();
    assert.ok(tax.exists, 'taxRates missing');
    const client = tax.data().clients?.['labs.carnama.halalboys'];
    assert.ok(client, 'taxRates.clients[labs.carnama.halalboys] missing');
    assert.equal(typeof client.stateRates.DEFAULT, 'number');
    assert.equal(typeof client.currency, 'string');
    const cfg = await db.collection('settings').doc('restaurantConfig').get();
    assert.ok(cfg.exists, 'restaurantConfig missing');
    assert.equal(typeof cfg.data().deliveryFeeCents, 'number');
    assert.equal(cfg.data().currency, 'USD');
  });

  // ── settings/ownerInfo (v003; isOwner() rules:47-52) ──────────────────────
  await check('settings/ownerInfo.ownerEmail == admin@carnama.com (v003 ran)', async () => {
    const doc = await db.collection('settings').doc('ownerInfo').get();
    assert.ok(doc.exists, 'ownerInfo missing');
    assert.equal(doc.data().ownerEmail, 'admin@carnama.com');
  });



  console.log(`\n[seed_demo_data_test] PASSED: ${passed}  FAILED: ${failed}`);
  if (failed > 0) process.exit(1);
  process.exit(0);
}

run().catch((e) => {
  console.error('[seed_demo_data_test] FATAL:', e);
  process.exit(1);
});
