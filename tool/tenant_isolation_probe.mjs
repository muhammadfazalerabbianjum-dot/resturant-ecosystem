#!/usr/bin/env node
// Gate (j) — P1-4 cross-tenant isolation proof.
//
// Outer process (no flag): asks the OS for two free loopback ports, writes a
// sibling emulator config (same directory as core_app/firebase.json so relative
// `rules` paths still resolve), then runs this same file with `--inner` inside
// `firebase emulators:exec --only firestore,auth`.
//
// Inner process (--inner): runs with FIRESTORE_EMULATOR_HOST and
// FIREBASE_AUTH_EMULATOR_HOST exported by emulators:exec, and does three things
// the Dart suite cannot do for itself:
//
//   1. SEEDS both tenants' documents at the ids the registry names. A denial
//      proven against a path that never existed is not a proof — reading a
//      missing document is denied because there is no `resource`, whatever the
//      other tenant really holds.
//   2. MINTS the claims: two email/password users with
//      {tenantId, roles:['customer'], claimsVersion, app_id}. The Admin SDK is
//      used through `functions/package.json`'s dependency tree, exactly like
//      tool/ledger_probe.mjs — no new package.
//   3. RUNS the generated Dart suite and propagates its exit code. The suite
//      signs in as tenant A itself; this file only prepares the world.
//
// `app_id` is set as a CUSTOM claim here so `isAppVerified()` is satisfiable in
// the emulator. That is a test fixture, not evidence that a production ID token
// carries `app_id` — D-036 records that open question.

import {spawnSync} from 'node:child_process';
import {existsSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {createServer} from 'node:net';
import {createRequire} from 'node:module';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const CORE = resolve(HERE, '..', 'core_app');
const CONFIG = join(CORE, 'firebase.json');
const TEMP_CONFIG = join(CORE, '.gate-tenant-firebase.json');
const REGISTRY = join(CORE, 'test/security/tenant_isolation_cases.json');
const PROJECT = 'demo-carnama-gate';

const TENANT_A = 'tenant_a';
const TENANT_B = 'tenant_b';
const APP_ID = '1:0:android:tenant_isolation_probe';

function freePort() {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const {port} = server.address();
      server.close(() => resolvePort(port));
    });
  });
}

if (!process.argv.includes('--inner')) {
  const base = JSON.parse(readFileSync(CONFIG, 'utf8'));
  const port = await freePort();
  const authPort = await freePort();

  writeFileSync(TEMP_CONFIG, JSON.stringify({
    ...base,
    emulators: {
      ...base.emulators,
      firestore: {...(base.emulators?.firestore ?? {}), port, host: '127.0.0.1'},
      auth: {...(base.emulators?.auth ?? {}), port: authPort, host: '127.0.0.1'},
      ui: {enabled: false},
    },
  }, null, 2));

  console.log(
      `tenant-probe: firestore ${port} / auth ${authPort} (config ${TEMP_CONFIG})`);

  const res = spawnSync(
      'firebase emulators:exec --only firestore,auth ' +
        `--project ${PROJECT} --config .gate-tenant-firebase.json ` +
        '"node ../tool/tenant_isolation_probe.mjs --inner"',
      {cwd: CORE, shell: true, stdio: 'inherit', timeout: 900000},
  );

  if (existsSync(TEMP_CONFIG)) rmSync(TEMP_CONFIG);

  if (res.error) {
    console.error(`tenant-probe: could not run firebase — ${res.error.message}`);
    process.exit(1);
  }
  process.exit(res.status === null ? 1 : res.status);
}

// ── inner ────────────────────────────────────────────────────────────────
const require = createRequire(
    new URL('../core_app/functions/package.json', import.meta.url));
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp({projectId: PROJECT});
const db = admin.firestore();
const auth = admin.auth();

/** Minimal shapes so a tenant's own document is readable where a rule allows it. */
const SHAPES = {
  menus: (tenant) => ({
    tenantId: tenant, name: 'Isolation probe item', priceCents: 100,
    branchId: 'iso_branch',
  }),
  branches: (tenant) => ({tenantId: tenant, name: 'Isolation probe branch'}),
  promotions: (tenant) => ({tenantId: tenant, title: 'Isolation probe promo'}),
  locations: (tenant) => ({
    tenantId: tenant, branchId: 'iso_branch', lat: 0, lng: 0,
  }),
  users: (tenant) => ({
    tenantId: tenant, role: 'customer', email: `${tenant}@probe.local`,
    name: tenant,
  }),
  carts: (tenant) => ({tenantId: tenant, items: []}),
  orders: (tenant, ownerUid) => ({
    tenantId: tenant, customerId: ownerUid, totalCents: 100,
    branchId: 'iso_branch', status: 'pending',
  }),
  reservations: (tenant, ownerUid) => ({
    tenantId: tenant, userId: ownerUid, branchId: 'iso_branch',
    customerName: 'Isolation probe', customerPhone: '000', startTime: 0,
    partySize: 2,
  }),
  waitlist: (tenant, ownerUid) => ({
    tenantId: tenant, userId: ownerUid, branchId: 'iso_branch',
  }),
  promo_usage: (tenant, ownerUid) => ({
    tenantId: tenant, userId: ownerUid, code: 'ISO',
  }),
  reservation_locks: (tenant, ownerUid) => ({tenantId: tenant, userId: ownerUid}),
  loyalty: (tenant, ownerUid) => ({
    tenantId: tenant, userId: ownerUid, totalPoints: 0,
  }),
  deletion_requests: (tenant, ownerUid) => ({
    tenantId: tenant, userId: ownerUid, status: 'probe',
  }),
  driverLocations: (tenant, ownerUid) => ({
    tenantId: tenant, driverId: ownerUid, lat: 0, lng: 0,
  }),
  proof_of_delivery: (tenant, ownerUid, docId) => ({
    tenantId: tenant, orderId: docId, driverId: ownerUid,
  }),
  notifications: (tenant) => ({tenantId: tenant, title: 'Isolation probe'}),
  default: (tenant) => ({tenantId: tenant}),
};

function shapeFor(collection, tenant, ownerUid, docId) {
  const build = SHAPES[collection] ?? SHAPES.default;
  return build(tenant, ownerUid, docId);
}

/**
 * Card 8 (D-047): `deliveries/{orderId}` and `proof_of_delivery/*` are scoped
 * through the ORDER they reference, so a probe document without its order is
 * denied for a missing parent — a denial for the wrong reason, exactly what the
 * registry's `literal` note warns about.
 */
const ORDER_LINKED = new Set(['deliveries', 'proof_of_delivery']);

/** Substitutes the principal-keyed registry ids ({uid} / {uid_b}). */
function resolveId(value, uidA, uidB) {
  return String(value ?? '')
      .replaceAll('{uid_b}', uidB)
      .replaceAll('{uid}', uidA);
}

/**
 * Resolves a registry path template to a document path.
 *
 * `{parentId}` must be replaced before `{id}`: a nested row hangs from a seeded
 * parent document (which may itself be principal-keyed, e.g.
 * `notifications/{uid}/items/{id}`), and an unresolved placeholder would make
 * the probe seed a path no rule matches — a denial for the wrong reason.
 */
function resolvePath(template, docId, uidA, uidB, parentId) {
  return String(template)
      .replaceAll('{parentId}', resolveId(parentId, uidA, uidB))
      .replaceAll('{id}', resolveId(docId, uidA, uidB));
}

const registry = JSON.parse(readFileSync(REGISTRY, 'utf8'));
const cases = registry.cases;

async function ensureUser(email, password) {
  try {
    const existing = await auth.getUserByEmail(email);
    return existing.uid;
  } catch {
    const created = await auth.createUser({email, password});
    return created.uid;
  }
}

const uidA = await ensureUser('tenant-a@probe.local', 'probe-password-a');
const uidB = await ensureUser('tenant-b@probe.local', 'probe-password-b');
// Owner-only collections (admins, audit_log, audit_logs) cannot be probed with a
// customer token: it is denied by ROLE, so a tenancy failure inside those rules
// would still look like a pass. This is tenant A's owner.
const uidOwnerA = await ensureUser('owner-a@probe.local', 'probe-password-owner');

await auth.setCustomUserClaims(uidA, {
  tenantId: TENANT_A, roles: ['customer'], branchIds: [], claimsVersion: 1,
  app_id: APP_ID,
});
await auth.setCustomUserClaims(uidB, {
  tenantId: TENANT_B, roles: ['customer'], branchIds: [], claimsVersion: 1,
  app_id: APP_ID,
});
await auth.setCustomUserClaims(uidOwnerA, {
  tenantId: TENANT_A, roles: ['owner'], branchIds: [], claimsVersion: 1,
  app_id: APP_ID,
});

// `userRole()` reads the USER DOCUMENT, not the token: without this row the
// owner's role is 'none' and every role-gated branch (`deliveries` reads,
// `admins` reads) denies for a reason that has nothing to do with tenancy.
await db.doc(`users/${uidOwnerA}`).set({
  tenantId: TENANT_A, role: 'owner', email: 'owner-a@probe.local',
}, {merge: true});

// `isOwner()` requires settings/<tenant>_ownerInfo.ownerEmail to equal the
// caller's token email, so the owner principal is only an owner once this exists.
await db.doc(`settings/${TENANT_A}_ownerInfo`)
    .set({tenantId: TENANT_A, ownerEmail: 'owner-a@probe.local'}, {merge: true});

const subst = (id, uid) => String(id)
    .replaceAll('{uid_b}', uidB)
    .replaceAll('{uid}', uid);

let seeded = 0;
for (const [key, row] of Object.entries(cases)) {
  // A literal row names a fixed document the tenant migration must
  // create; seeding a different id would be denied for having no rule.
  if (row.literal) continue;
  if (!row.nested) {
    const writes = [
      [subst(row.readDocId, uidA), TENANT_B, uidB],
      [subst(row.writeDocId, uidA), TENANT_B, uidB],
    ];
    if (row.sameTenant === 'allow' && row.allowDocId) {
      writes.push([subst(row.allowDocId, uidA), TENANT_A, uidA]);
    }
    for (const [docId, tenant, ownerUid] of writes) {
      if (!docId) continue;
      await db.collection(key).doc(docId)
          .set(shapeFor(key, tenant, ownerUid, docId), {merge: true});
      if (ORDER_LINKED.has(key)) {
        // `deliveries` is keyed BY the order id; `proof_of_delivery` carries
        // `orderId`, which the registry's doc id doubles as. Either way the
        // rules look up `orders/<docId>`, so it must exist in the same tenant.
        await db.doc(`orders/${docId}`)
            .set(shapeFor('orders', tenant, ownerUid), {merge: true});
      }
      seeded += 1;
    }
    continue;
  }

  // Nested block: the parent document must exist too, or the child path is
  // denied because its parent is missing rather than because of tenancy.
  const [parentCollection, childName] = key.split('/');
  const parents = [[row.parentDocId, TENANT_B, uidB]];
  if (row.allowParentDocId) {
    parents.push([row.allowParentDocId, TENANT_A, uidA]);
  }
  for (const [parentId, tenant, ownerUid] of parents) {
    if (!parentId) continue;
    const id = resolveId(parentId, uidA, uidB);
    await db.doc(`${parentCollection}/${id}`)
        .set(shapeFor(parentCollection, tenant, ownerUid), {merge: true});
    seeded += 1;
  }

  const writes = [
    [row.readDocId, TENANT_B, uidB, row.parentDocId],
    [row.writeDocId, TENANT_B, uidB, row.parentDocId],
  ];
  if (row.sameTenant === 'allow' && row.allowDocId) {
    writes.push([row.allowDocId, TENANT_A, uidA, row.allowParentDocId]);
  }
  for (const [docId, tenant, ownerUid, parentId] of writes) {
    if (!docId) continue;
    const path = resolvePath(row.readPath, docId, uidA, uidB, parentId);
    await db.doc(path).set(shapeFor(childName, tenant, ownerUid), {merge: true});
    seeded += 1;
  }
}

console.log(
    `tenant-probe: seeded ${seeded} documents across ${Object.keys(cases).length} registered rule paths ` +
      `(tenant A uid ${uidA}, tenant B uid ${uidB})`);

// `flutter test`, with the suite's loopback-socket transport: firebase_core
// cannot initialise in flutter_tester (no platform channel) and the repo's
// network blocker rules out dart:io HttpClient, so the suite speaks the
// emulator's REST protocol over a Socket. See tenant_isolation_support.dart.
const suite = spawnSync(
    'flutter test test/security/tenant_isolation.generated_test.dart',
    {
      cwd: CORE,
      shell: true,
      stdio: 'inherit',
      timeout: 900000,
      env: {
        ...process.env,
        GCLOUD_PROJECT: PROJECT,
        TENANT_A_UID: uidA,
        TENANT_B_UID: uidB,
      },
    },
);

if (suite.error) {
  console.error(`tenant-probe: dart test failed to start — ${suite.error.message}`);
  process.exit(1);
}
if (suite.status !== 0) {
  console.error(
      'tenant-probe: the generated suite failed — isolation is NOT proven.');
  process.exit(suite.status === null ? 1 : suite.status);
}
console.log('tenant-probe: cross-tenant denial and same-tenant allow both hold.');
