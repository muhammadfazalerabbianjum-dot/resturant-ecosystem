/**
 * seed_demo_data.js — DEMO-ONLY Firestore/Auth emulator seed (Phase 0).
 *
 * TARGET: the local Firebase EMULATOR SUITE ONLY (never a real project):
 *   - requires FIRESTORE_EMULATOR_HOST      (default 127.0.0.1:8080)
 *   - requires FIREBASE_AUTH_EMULATOR_HOST  (default 127.0.0.1:9099)
 *   - project id from GCLOUD_PROJECT        (default resturants-8547d)
 * No service-account files are ever read; with the emulator env vars set the
 * Admin SDK cannot reach production (fail-closed by construction).
 *
 * PRECONDITION (fail-closed, Rule 5): migrations v001/v002/v003 must have run
 * (branches/branch_main, admin@carnama.com with role=owner claim,
 * settings/ownerInfo) — otherwise this script exits 1 and seeds nothing.
 *
 * Field shapes below are taken from the MODELS (Rule 0 — inspect before seeding):
 *   - admin/domain/menu_item_model.dart:11-23: id, branchId (null = global),
 *     name, priceCents (int), description, imageUrl (String, '' -> null at
 *     read time), category, modifiers (List<Map>), isAvailable, tags,
 *     quantityRemaining (int?)
 *   - menu/domain/menu_modifier_model.dart:57-82: MenuModifier {id, name,
 *     isRequired, allowMultiple, options: ModifierOption {id, name,
 *     upchargeCents, isDefault}}
 *   - packages/core user_model.dart:41-62: id, email, name, ..., tier,
 *     role, branchId, isOnline, assignedOrderIds, createdAt
 *   - functions/src/migrations/v001__seed_branches.ts:37-45: branch doc shape
 *
 * Usage (from core_app/, emulator running):
 *   node tool/seed_demo_data.js
 */
'use strict';

// firebase-admin is installed under core_app/functions/node_modules (the only
// place the repo pins it) — extend this script's resolution path explicitly
// instead of duplicating the dependency.
const path = require('path');
module.paths.push(path.join(__dirname, '..', 'functions', 'node_modules'));

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// ── Emulator-only configuration (fail-closed) ──────────────────────────────
const FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.DEMO_PROJECT_ID || 'resturants-8547d';

process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_EMULATOR_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = FIREBASE_AUTH_EMULATOR_HOST;

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();
const auth = getAuth();

const OWNER_EMAIL = 'admin@carnama.com';
const DEMO_CLIENT_ID = 'labs.carnama.halalboys'; // halal_boyz bundleId (client_config.json:10)

// ── Demo staff accounts (credentials recorded in docs/DEMO_PHASE0_LOG.md) ──
const STAFF = [
  { email: 'kitchen@carnama.com', password: 'KitchenPass123', displayName: 'Halal Boyz Kitchen', role: 'kitchen', branchId: 'branch_main' },
  { email: 'delivery@carnama.com', password: 'DeliveryPass123', displayName: 'Halal Boyz Driver', role: 'delivery', branchId: 'branch_main' },
  { email: 'customer@carnama.com', password: 'CustomerPass123', displayName: 'Demo Customer', role: 'customer', branchId: '' },
];

// ── Branches (v001 shape + isMainBranch used by merged_menu_provider:46) ───
const BRANCHES = [
  {
    id: 'branch_main',
    name: 'Halal Boyz — Main',
    address: 'Downtown Food Court, Level 2',
    latitude: 25.2048,
    longitude: 55.2708,
    deliveryRadiusMiles: 5.0,
    isDefault: true,
    isMainBranch: true,
  },
  {
    id: 'branch_downtown',
    name: 'Halal Boyz — Riverside',
    address: '12 Riverside Walk',
    latitude: 25.2102,
    longitude: 55.2829,
    deliveryRadiusMiles: 3.5,
    isDefault: false,
    isMainBranch: false,
  },
];

// ── Modifier groups (menu_modifier_model.dart shape) ────────────────────────
const SIZE_GROUP = {
  id: 'mod_size',
  name: 'Size',
  isRequired: true, // required single-choice
  allowMultiple: false,
  options: [
    { id: 'size_small', name: 'Small', upchargeCents: 0, isDefault: true },
    { id: 'size_large', name: 'Large', upchargeCents: 150, isDefault: false },
  ],
};
const EXTRAS_GROUP = {
  id: 'mod_extras',
  name: 'Extras',
  isRequired: false, // optional multi-select
  allowMultiple: true,
  options: [
    { id: 'extra_cheese', name: 'Extra cheese', upchargeCents: 100, isDefault: true },
    { id: 'extra_sauce', name: 'Garlic sauce', upchargeCents: 75, isDefault: false },
    { id: 'extra_jalapeno', name: 'Jalapeños', upchargeCents: 50, isDefault: false },
  ],
};


// ── Menu items (13 items, 4 categories, 2 branches, every attribute set) ───
// imageUrl: '' (placeholder/empty — operator uploads later via admin screens).
const MENU_ITEMS = [
  // — Burgers @ branch_main —
  {
    id: 'demo_smash_burger', branchId: 'branch_main', name: 'Classic Smash Burger',
    description: 'Smashed halal beef patty, American cheese, house sauce, pickles, toasted potato bun.',
    priceCents: 1099, category: 'Burgers', imageUrl: '', tags: ['Best Seller', 'Halal'],
    isAvailable: true, quantityRemaining: null, modifiers: [SIZE_GROUP],
  },
  {
    id: 'demo_double_smash', branchId: 'branch_main', name: 'Double Smash Burger',
    description: 'Two smashed halal beef patties, double cheese, caramelised onions, burger sauce.',
    priceCents: 1599, category: 'Burgers', imageUrl: '', tags: ['Beef', 'Best Seller'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  {
    id: 'demo_crispy_chicken_burger', branchId: 'branch_main', name: 'Crispy Chicken Burger',
    description: 'Buttermilk-fried halal chicken thigh, spicy mayo, slaw, brioche bun.',
    priceCents: 1249, category: 'Burgers', imageUrl: '', tags: ['Chicken', 'Spicy'],
    isAvailable: true, quantityRemaining: 12, modifiers: [],
  },
  {
    id: 'demo_mushroom_swiss', branchId: 'branch_main', name: 'Mushroom Swiss Burger',
    description: 'Halal beef patty, sautéed mushrooms, Swiss cheese, truffle aioli.',
    priceCents: 1399, category: 'Burgers', imageUrl: '', tags: ['Premium'],
    isAvailable: false, quantityRemaining: null, modifiers: [],
  },
  // — Wraps & Gyros @ branch_main —
  {
    id: 'demo_chicken_overload_wrap', branchId: 'branch_main', name: 'Chicken Overload Wrap',
    description: 'Grilled halal chicken, garlic toum, fries inside, pickles, lavash wrap.',
    priceCents: 1199, category: 'Wraps & Gyros', imageUrl: '', tags: ['Best Seller', 'Halal'],
    isAvailable: true, quantityRemaining: null, modifiers: [EXTRAS_GROUP],
  },
  {
    id: 'demo_beef_gyro', branchId: 'branch_main', name: 'Beef Gyro',
    description: 'Shaved seasoned halal beef, tzatziki, tomato, onion, warm pita.',
    priceCents: 1299, category: 'Wraps & Gyros', imageUrl: '', tags: ['Classic', 'Halal'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  {
    id: 'demo_falafel_wrap', branchId: 'branch_main', name: 'Falafel Wrap',
    description: 'Crispy falafel, hummus, tabbouleh, pickled turnip, sesame lavash.',
    priceCents: 999, category: 'Wraps & Gyros', imageUrl: '', tags: ['Vegan'],
    isAvailable: true, quantityRemaining: 8, modifiers: [],
  },
  // — Sides @ branch_main —
  {
    id: 'demo_truffle_fries', branchId: 'branch_main', name: 'Truffle Parmesan Fries',
    description: 'Shoestring fries, white truffle oil, parsley, fresh parmesan.',
    priceCents: 749, category: 'Sides', imageUrl: '', tags: ['Premium'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  {
    id: 'demo_loaded_fries', branchId: 'branch_main', name: 'Loaded Halal Fries',
    description: 'Fries, halal beef chilli, nacho cheese, jalapeños, scallions.',
    priceCents: 899, category: 'Sides', imageUrl: '', tags: ['Sharing'],
    isAvailable: true, quantityRemaining: 0, modifiers: [],
  },
  // — Drinks @ branch_downtown —
  {
    id: 'demo_mango_lassi', branchId: 'branch_downtown', name: 'Mango Lassi',
    description: 'Sweet mango, yogurt, cardamom, served over ice.',
    priceCents: 549, category: 'Drinks', imageUrl: '', tags: ['Cold', 'Sweet'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  {
    id: 'demo_mint_lemonade', branchId: 'branch_downtown', name: 'Mint Lemonade',
    description: 'Fresh-squeezed lemonade, crushed mint, sparkling water.',
    priceCents: 449, category: 'Drinks', imageUrl: '', tags: ['Cold', 'Vegan'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  // — Desserts @ branch_downtown —
  {
    id: 'demo_lava_cake', branchId: 'branch_downtown', name: 'Molten Lava Cake',
    description: 'Warm chocolate cake, gooey centre, vanilla bean ice cream.',
    priceCents: 899, category: 'Desserts', imageUrl: '', tags: ['Sweet'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
  {
    id: 'demo_baklava', branchId: 'branch_downtown', name: 'Pistachio Baklava',
    description: 'Layered filo, honey syrup, crushed pistachio.',
    priceCents: 649, category: 'Desserts', imageUrl: '', tags: ['Sweet', 'Nuts'],
    isAvailable: true, quantityRemaining: null, modifiers: [],
  },
];

// ── Feature flags (settings/featureFlags — bool map, public read) ──────────
const FEATURE_FLAGS = {
  smartReorder: true,
  promoCode: true,
  deliveryEnabled: true,
  deliveryTracking: true,
  loyaltyPoints: true,
  liveTracking: true,
  reservations: true,
  waitlist: true,
  referrals: true,
  tourMode: true,
  // App Check STRICT stays OFF for the demo (relaxed OR mode, rules:30-35).
  strongAppCheck: false,
};

// ── Checkout config the charge path re-reads (server-authoritative) ────────
// settings/taxRates.clients[clientId] — index.ts resolveChargeTaxAndPromo.
// settings/restaurantConfig — deliveryFeeCents clamp (index.ts:905-914).
const TAX_RATES = {
  clients: {
    [DEMO_CLIENT_ID]: { stateRates: { CA: 0.0725, DEFAULT: 0.08 }, currency: 'usd' },
  },
};
const RESTAURANT_CONFIG = {
  restaurantName: 'Halal Boyz',
  currency: 'USD',
  ordersAccepting: true,
  deliveryFeeCents: 299,
};


let okCount = 0;
let failCount = 0;
function ok(msg) { okCount += 1; console.log(`  ✔ ${msg}`); }
function fail(msg, err) {
  failCount += 1;
  console.error(`  ✖ ${msg}${err ? ` — ${err.message ?? err}` : ''}`);
}

async function assertPreconditions() {
  // Fail-closed: never seed onto a backend whose owner bootstrap is absent.
  const ownerInfo = await db.collection('settings').doc('ownerInfo').get();
  if (!ownerInfo.exists) {
    throw new Error('settings/ownerInfo missing — run migrations v002 then v003 first (fail-closed).');
  }
  if (ownerInfo.data().ownerEmail !== OWNER_EMAIL) {
    throw new Error(`settings/ownerInfo.ownerEmail is '${ownerInfo.data().ownerEmail}', expected '${OWNER_EMAIL}'.`);
  }
  let owner;
  try {
    owner = await auth.getUserByEmail(OWNER_EMAIL);
  } catch {
    throw new Error(`${OWNER_EMAIL} has no Auth account — run migration v002 first (fail-closed).`);
  }
  if (owner.customClaims?.role !== 'owner') {
    throw new Error(`${OWNER_EMAIL} lacks the role=owner claim — run migration v002 first (fail-closed).`);
  }
  ok(`preconditions: ownerInfo + owner claim present for ${OWNER_EMAIL} (uid ${owner.uid})`);
}

async function seedBranches() {
  for (const b of BRANCHES) {
    const { id, ...data } = b;
    await db.collection('branches').doc(id).set({ ...data, createdAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  const snap = await db.collection('branches').get();
  if (snap.size < 2) throw new Error(`expected >=2 branches after seed, found ${snap.size}`);
  ok(`branches: ${BRANCHES.map((b) => b.id).join(', ')} (${snap.size} total)`);
}

async function seedStaff() {
  for (const s of STAFF) {
    let user;
    try {
      user = await auth.getUserByEmail(s.email); // idempotent re-run
    } catch {
      user = await auth.createUser({ email: s.email, password: s.password, displayName: s.displayName });
    }
    await auth.setCustomUserClaims(user.uid, { role: s.role });
    await db.collection('users').doc(user.uid).set({
      id: user.uid,
      email: s.email,
      name: s.displayName,
      role: s.role, // userRole() reads THIS field (firestore.rules:54-59)
      tier: 'starter',
      loyaltyPoints: 0,
      isOnline: false,
      assignedOrderIds: [],
      branchId: s.branchId,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    ok(`staff: ${s.email} (role=${s.role}, uid=${user.uid}) — auth user + claim + users doc`);
  }
}

async function seedMenus() {
  const batch = db.batch();
  for (const item of MENU_ITEMS) {
    const { id, ...data } = item;
    batch.set(db.collection('menus').doc(id), data, { merge: true });
  }
  await batch.commit();
  const snap = await db.collection('menus').where('branchId', 'in', BRANCHES.map((b) => b.id)).get();
  if (snap.size < MENU_ITEMS.length) {
    throw new Error(`expected ${MENU_ITEMS.length} seeded menu items, read back ${snap.size}`);
  }
  const unavailable = MENU_ITEMS.filter((m) => !m.isAvailable).length;
  const soldOut = MENU_ITEMS.filter((m) => m.quantityRemaining === 0).length;
  const withModifiers = MENU_ITEMS.filter((m) => m.modifiers.length > 0).length;
  const categories = new Set(MENU_ITEMS.map((m) => m.category));
  ok(`menus: ${snap.size} items | categories=${categories.size} | modifierGroupItems=${withModifiers} | unavailable=${unavailable} | soldOut=${soldOut}`);
}

async function seedFlagsAndCheckoutConfig() {
  await db.collection('settings').doc('featureFlags').set(FEATURE_FLAGS);
  await db.collection('settings').doc('taxRates').set(TAX_RATES, { merge: true });
  await db.collection('settings').doc('restaurantConfig').set(RESTAURANT_CONFIG, { merge: true });
  ok(`settings: featureFlags (${Object.keys(FEATURE_FLAGS).length} bool flags), taxRates.clients[${DEMO_CLIENT_ID}], restaurantConfig`);
}

async function main() {
  console.log(`[seed_demo_data] target: Firestore emulator ${FIRESTORE_EMULATOR_HOST} | Auth emulator ${FIREBASE_AUTH_EMULATOR_HOST} | project ${PROJECT_ID}`);
  console.log('[seed_demo_data] this script NEVER touches a real Firebase project (emulator env vars only).');
  await assertPreconditions();
  await seedBranches();
  await seedStaff();
  await seedMenus();
  await seedFlagsAndCheckoutConfig();
  if (failCount > 0) {
    throw new Error(`${failCount} seed step(s) failed`);
  }
  console.log(`[seed_demo_data] DONE — ${okCount} steps ok, ${failCount} failed.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('[seed_demo_data] FAILED:', err.message ?? err);
    process.exit(1);
  });

