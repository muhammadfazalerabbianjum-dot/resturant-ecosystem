#!/usr/bin/env node
/**
 * Halal Boyz demo-content seeder for production project `demo-tenant`.
 *
 * Seeds the minimum content the customer app renders: one main branch, a
 * global menu, hero promotions, and locations. Idempotent: existing documents
 * are reported and skipped (create-only), so re-runs never clobber data.
 *
 * Auth (no secrets in this file):
 *  1. refreshes the local `firebase-tools` login token (reads the CLI's
 *     client id/secret from the installed package at runtime), then
 *  2. mints a short-lived token for the project's appspot service account
 *     (roles/editor — Firestore admin writes bypass security rules).
 *
 * Usage: node seed_demo_data.js [--verify-only]
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');

const PROJECT = 'demo-tenant';
const SA = `${PROJECT}@appspot.gserviceaccount.com`;
const DB = `projects/${PROJECT}/databases/(default)/documents`;

function req(url, { method = 'GET', headers = {}, body = null } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const r = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers: { 'Content-Type': 'application/json', ...headers },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let json = null;
          try { json = JSON.parse(data); } catch (_) { /* raw */ }
          resolve({ status: res.statusCode, json, raw: data });
        });
      },
    );
    r.on('error', reject);
    if (body) r.write(typeof body === 'string' ? body : JSON.stringify(body));
    r.end();
  });
}

function findFirebaseToolsLib() {
  const cands = [
    process.env.FIREBASE_TOOLS_LIB,
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools', 'lib', 'api.js'),
    path.join(process.env.ProgramFiles || '', 'npm', 'node_modules', 'firebase-tools', 'lib', 'api.js'),
  ].filter(Boolean);
  const hit = cands.find((p) => fs.existsSync(p));
  if (!hit) throw new Error('firebase-tools lib/api.js not found (set FIREBASE_TOOLS_LIB)');
  return hit;
}

async function userAccessToken() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const api = require(findFirebaseToolsLib());
  const tok = await req('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: api.clientId(),
      client_secret: api.clientSecret(),
      refresh_token: cfg.tokens.refresh_token,
    }).toString(),
  });
  if (tok.status !== 200 || !tok.json.access_token) {
    throw new Error(`firebase-tools token refresh failed: ${tok.status} ${tok.raw}`);
  }
  return tok.json.access_token;
}

async function serviceAccountToken(userToken) {
  const r = await req(
    `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SA}:generateAccessToken`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${userToken}` },
      body: {
        lifetime: '1800s',
        delegates: [],
        scope: ['https://www.googleapis.com/auth/datastore'],
      },
    },
  );
  // Response key is camelCase `accessToken`. Never echo the body: on
  // unexpected shapes it would print a live token into logs/receipts.
  const token = r.json && (r.json.accessToken || r.json.access_token);
  if (r.status !== 200 || !token) {
    throw new Error(
      `generateAccessToken failed: HTTP ${r.status} keys=${r.json ? Object.keys(r.json).join(',') : 'non-json'}`,
    );
  }
  return token;
}

const v = {
  s: (x) => ({ stringValue: x }),
  i: (x) => ({ integerValue: String(x) }),
  b: (x) => ({ booleanValue: x }),
  d: (x) => ({ doubleValue: x }),
  a: (xs) => ({ arrayValue: { values: xs.map((x) => ({ stringValue: x })) } }),
};

const IMG = (id) => `https://images.unsplash.com/${id}?q=80&w=800&auto=format&fit=crop`;
// Proven-good ids (already rendered in committed Carnama screenshots).
const PROVEN = {
  burger: IMG('photo-1568901346375-23c9450c58cd'),
  chicken: IMG('photo-1626082927389-6cd097cdc6ec'),
  steak: IMG('photo-1544025162-d76694265947'),
  fries: IMG('photo-1576107232684-1279f3908594'),
  pizza: IMG('photo-1574071318508-1cdbab80d002'),
  pizza2: IMG('photo-1565299624946-b28f40a0ae38'),
  matcha: IMG('photo-1536256263959-770b48d82b0a'),
  cake: IMG('photo-1606313564200-e75d5e30476c'),
};

function menuDoc(id, name, description, priceCents, category, imageUrl, tags) {
  return { id, fields: {
    name: v.s(name), description: v.s(description), priceCents: v.i(priceCents),
    category: v.s(category), imageUrl: v.s(imageUrl), isAvailable: v.b(true),
    tags: v.a(tags),
    // Explicit null: `where('branchId', isNull: true)` matches ONLY docs that
    // carry an explicit null — absent fields never match the global menu query
    // (verified live against production, 2026-10-06).
    branchId: { nullValue: 'NULL_VALUE' },
  } };
}

const MENU = [
  menuDoc('hzb_smash_burger', 'Double Smash Burger', 'Two halal beef patties, american cheese, house sauce, toasted brioche bun.', 1399, 'Burgers', PROVEN.burger, ['Best Seller', 'Beef']),
  menuDoc('hzb_crispy_chicken', 'Crispy Chicken Burger', 'Buttermilk-brined halal chicken thigh, spicy mayo, pickles, brioche.', 1249, 'Burgers', PROVEN.chicken, ['Spicy', 'Chicken']),
  menuDoc('hzb_kebab_wrap', 'Lamb Kebab Wrap', 'Charcoal-grilled lamb kofta, garlic sauce, sumac onions, warm flatbread.', 1199, 'Wraps', PROVEN.steak, ['Halal', 'Lamb']),
  menuDoc('hzb_shawarma_wrap', 'Chicken Shawarma Wrap', 'Slow-roasted shawarma chicken, tahini, pickled turnips, pita.', 1099, 'Wraps', PROVEN.chicken, ['Classic', 'Chicken']),
  menuDoc('hzb_kofta_plate', 'Beef Kofta Plate', 'Grilled kofta skewers, saffron rice, salad, house chili sauce.', 1699, 'Plates', PROVEN.steak, ['Halal', 'Beef']),
  menuDoc('hzb_grilled_plate', 'Grilled Chicken Plate', 'Marinated chicken thigh, turmeric rice, grilled vegetables.', 1549, 'Plates', PROVEN.chicken, ['High Protein', 'Chicken']),
  menuDoc('hzb_loaded_fries', 'Loaded Fries', 'Crispy fries piled with cheese sauce, jalapenos and scallions.', 799, 'Sides', PROVEN.fries, ['Comfort', 'Snack']),
  menuDoc('hzb_hummus_pita', 'Hummus & Pita', 'Silky chickpea hummus, olive oil, warm pita triangles.', 649, 'Sides', PROVEN.pizza, ['Vegetarian', 'Mezze']),
  menuDoc('hzb_onion_rings', 'Onion Rings', 'Crisp battered onion rings with smoky dip.', 549, 'Sides', PROVEN.fries, ['Crispy', 'Snack']),
  menuDoc('hzb_mango_shake', 'Mango Lava Shake', 'Alphonso mango blended with vanilla ice cream, thick and cold.', 699, 'Drinks', PROVEN.matcha, ['Cold', 'Sweet']),
  menuDoc('hzb_mint_lemonade', 'Mint Lemonade', 'Fresh lemon, mint and a whisper of date syrup over ice.', 449, 'Drinks', PROVEN.matcha, ['Cold', 'Refresher']),
  menuDoc('hzb_baklava', 'Baklava Duo', 'Two pieces of pistachio baklava in honey syrup.', 599, 'Desserts', PROVEN.cake, ['Sweet', 'Pastry']),
  menuDoc('hzb_lava_cake', 'Chocolate Lava Cake', 'Warm molten chocolate cake with a gooey center.', 649, 'Desserts', PROVEN.cake, ['Sweet', 'Chocolate']),
];

const PROMOS = [
  ['promo_first_order', '50% Off Your First Order', 'Use code HZB50 at checkout', 'primary', 10, PROVEN.steak],
  ['promo_free_delivery', 'Free Delivery Over $25', 'Downtown & Midtown, every day', 'secondary', 8, PROVEN.pizza2],
  ['promo_family_feast', 'Family Feast — $39.99', 'Feeds four: wraps, plates and fries', 'tertiary', 6, PROVEN.burger],
  ['promo_student_tuesdays', 'Student Tuesdays — 20% Off', 'Show your student ID', 'primary', 4, PROVEN.chicken],
];

const LOCATIONS = [
  ['hzb_loc_downtown', 'Halal Boyz — Downtown', '123 Main St, New York, NY', '11:00 AM – 1:00 AM', 40.7128, -74.0060],
  ['hzb_loc_midtown', 'Halal Boyz — Midtown', '55 W 46th St, New York, NY', '11:30 AM – 12:00 AM', 40.7580, -73.9855],
  ['hzb_loc_brooklyn', 'Halal Boyz — Brooklyn', '88 Atlantic Ave, Brooklyn, NY', '12:00 PM – 2:00 AM', 40.6850, -73.9760],
];

async function createDoc(token, coll, id, fields) {
  const url = `https://firestore.googleapis.com/v1/${DB}/${coll}?documentId=${id}`;
  const r = await req(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { fields },
  });
  if (r.status === 200) return 'created';
  if (r.status === 409) {
    // Idempotent repair for docs seeded before the explicit-branchId-null fix:
    // patch branchId to explicit null so the customer app's global menu query
    // (where('branchId', isNull: true)) can see them.
    if (!('branchId' in fields)) return 'exists (skipped)';
    const p = await req(
      `https://firestore.googleapis.com/v1/${DB}/${coll}/${id}?updateMask.fieldPaths=branchId`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
        body: { fields: { branchId: fields.branchId } },
      },
    );
    if (p.status === 200) return 'exists (branchId repaired to null)';
    throw new Error(`repair ${coll}/${id} failed ${p.status}: ${p.raw}`);
  }
  throw new Error(`create ${coll}/${id} failed ${r.status}: ${r.raw}`);
}

async function countDocs(token, coll) {
  const r = await req(`https://firestore.googleapis.com/v1/${DB}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: { structuredQuery: { from: [{ collectionId: coll }], limit: 100 } },
  });
  if (r.status !== 200) throw new Error(`runQuery ${coll} failed ${r.status}: ${r.raw}`);
  return (r.json || []).filter((x) => x.document).length;
}

async function main() {
  const verifyOnly = process.argv.includes('--verify-only');
  const userTok = await userAccessToken();
  const saTok = await serviceAccountToken(userTok);
  console.log('auth OK (firebase-tools refresh -> appspot SA token)');

  if (!verifyOnly) {
    console.log('[branches]', await createDoc(saTok, 'branches', 'hzb_main', {
      name: v.s('Halal Boyz — Downtown'), isMainBranch: v.b(true), isDefault: v.b(true),
      address: v.s('123 Main St, New York, NY'),
    }));
    console.log('[menus]');
    for (const d of MENU) console.log('  ', d.id, '->', await createDoc(saTok, 'menus', d.id, d.fields));
    console.log('[promotions]');
    for (const [id, title, subtitle, bg, prio, img] of PROMOS) {
      console.log('  ', id, '->', await createDoc(saTok, 'promotions', id, {
        title: v.s(title), subtitle: v.s(subtitle), imageUrl: v.s(img),
        backgroundColor: v.s(bg), isActive: v.b(true), priority: v.i(prio),
        createdAt: v.s(new Date().toISOString()),
      }));
    }
    console.log('[locations]');
    for (const [id, name, address, openHours, lat, lng] of LOCATIONS) {
      console.log('  ', id, '->', await createDoc(saTok, 'locations', id, {
        name: v.s(name), address: v.s(address), openHours: v.s(openHours),
        lat: v.d(lat), lng: v.d(lng),
      }));
    }
  }

  console.log('[verify counts]');
  for (const c of ['branches', 'menus', 'promotions', 'locations']) {
    console.log(`  ${c}: ${await countDocs(saTok, c)}`);
  }
}

main().catch((e) => { console.error('SEED FAILED:', e.message); process.exit(1); });
