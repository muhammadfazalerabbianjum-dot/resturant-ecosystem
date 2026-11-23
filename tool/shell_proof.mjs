#!/usr/bin/env node
// P2-1a proof harness — firestore+auth emulators, a seeded tenant, free ports.
//
// WHY a harness and not hand-typed commands: the proof has to be repeatable and
// its numbers have to come from the run that produced them. Ports are picked by
// the OS (gate (d) learned this the hard way: 8080 and 8090 are held by unrelated
// software on this machine), the seeded tenant is fixed, and the same script
// prints the exact strings the browser step needs.
//
// Tenancy model being exercised (D-035): a menu row is readable only when the
// caller's `tenantId` CLAIM equals the row's `tenantId`. So the seed writes TWO
// rows for `tenant_shell` and ONE row for `tenant_other`; a correct shell shows
// exactly two.
//
// Usage:
//   node tool/shell_proof.mjs up     # start, seed, write .shell-proof.json, stay alive
//   node tool/shell_proof.mjs down   # stop whatever `up` started (by recorded pid)
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const CORE = join(ROOT, 'core_app');
const CONFIG = join(CORE, 'firebase.json');
const TEMP_CONFIG = join(CORE, '.shell-firebase.json');
const PROOF = join(ROOT, '.shell-proof.json');

const PROJECT = 'demo-carnama';
const TENANT = 'tenant_shell';
const OTHER_TENANT = 'tenant_other';
const EMAIL = 'counter@shell.test';
const PASSWORD = 'shellpass123';
const AUTH_KEY = 'fake-api-key'; // the emulator accepts any key

function freePort() {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolvePort(port));
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(url, label, timeoutMs = 120000) {
  const started = Date.now();
  for (;;) {
    try {
      const res = await fetch(url);
      if (res.status < 500) return;
    } catch (_) {
      /* not up yet */
    }
    if (Date.now() - started > timeoutMs) {
      throw new Error(`${label} did not answer within ${timeoutMs} ms (${url})`);
    }
    await sleep(500);
  }
}

async function seed(firestorePort, authPort) {
  const authBase = `http://127.0.0.1:${authPort}/identitytoolkit.googleapis.com/v1`;
  // 1. Create the counter user (email/password).
  const signUp = await fetch(`${authBase}/accounts:signUp?key=${AUTH_KEY}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: EMAIL,
      password: PASSWORD,
      returnSecureToken: true,
    }),
  });
  if (!signUp.ok) {
    throw new Error(`auth signUp failed: ${signUp.status} ${await signUp.text()}`);
  }
  const account = await signUp.json();

  // 2. Give it the tenant claim. The emulator honours the Admin SDK's own
  //    `customAttributes` field when called with the owner bearer.
  const update = await fetch(`${authBase}/accounts:update?key=${AUTH_KEY}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer owner',
    },
    body: JSON.stringify({
      localId: account.localId,
      customAttributes: JSON.stringify({ tenantId: TENANT }),
    }),
  });
  if (!update.ok) {
    throw new Error(
      `auth setCustomUserClaims failed: ${update.status} ${await update.text()}`,
    );
  }

  // 3. Seed the menu: two rows for this tenant, one decoy for another.
  const docsBase =
    `http://127.0.0.1:${firestorePort}/v1/projects/${PROJECT}` +
    '/databases/(default)/documents/menus';
  const rows = [
    { id: 'proof_1', name: 'Proof Shawarma', priceCents: 1250, tenant: TENANT },
    { id: 'proof_2', name: 'Proof Falafel', priceCents: 900, tenant: TENANT },
    {
      id: 'proof_other',
      name: 'Other Tenant Burger',
      priceCents: 5000,
      tenant: OTHER_TENANT,
    },
  ];
  for (const row of rows) {
    const res = await fetch(`${docsBase}?documentId=${row.id}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer owner', // rules bypass: this is seed data
      },
      body: JSON.stringify({
        fields: {
          name: { stringValue: row.name },
          priceCents: { integerValue: String(row.priceCents) },
          tenantId: { stringValue: row.tenant },
          isAvailable: { booleanValue: true },
        },
      }),
    });
    if (!res.ok) {
      throw new Error(`seed ${row.id} failed: ${res.status} ${await res.text()}`);
    }
  }

  // 4. Prove the claim is really on the token the app will get, not just on the
  //    user record: sign in and decode it.
  const signIn = await fetch(
    `${authBase}/accounts:signInWithPassword?key=${AUTH_KEY}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: EMAIL, password: PASSWORD, returnSecureToken: true }),
    },
  );
  if (!signIn.ok) {
    throw new Error(`auth signIn failed: ${signIn.status} ${await signIn.text()}`);
  }
  const session = await signIn.json();
  const payload = JSON.parse(
    Buffer.from(session.idToken.split('.')[1], 'base64url').toString('utf8'),
  );
  if (payload.tenantId !== TENANT) {
    throw new Error(
      `claim missing from the issued token: expected tenantId=${TENANT}, ` +
        `token payload = ${JSON.stringify(payload)}`,
    );
  }

  return {
    localId: account.localId,
    tokenTenantId: payload.tenantId,
    seededRows: rows.length,
    ownTenantRows: rows.filter((r) => r.tenant === TENANT).length,
  };
}

async function up() {
  const base = JSON.parse(readFileSync(CONFIG, 'utf8'));
  const firestorePort = await freePort();
  const authPort = await freePort();
  const httpPort = await freePort();

  writeFileSync(
    TEMP_CONFIG,
    JSON.stringify(
      {
        ...base,
        emulators: {
          ...base.emulators,
          firestore: { port: firestorePort, host: '127.0.0.1' },
          auth: { port: authPort, host: '127.0.0.1' },
          ui: { enabled: false },
        },
      },
      null,
      2,
    ),
  );

  const child = spawn(
    'firebase',
    [
      'emulators:start',
      '--only',
      'firestore,auth',
      '--project',
      PROJECT,
      '--config',
      '.shell-firebase.json',
    ],
    { cwd: CORE, shell: process.platform === 'win32', stdio: 'ignore' },
  );

  writeFileSync(
    PROOF,
    JSON.stringify({ pid: child.pid, firestorePort, authPort, httpPort }, null, 2),
  );

  await waitFor(`http://127.0.0.1:${firestorePort}/`, 'firestore emulator');
  await waitFor(`http://127.0.0.1:${authPort}/`, 'auth emulator');

  const seeded = await seed(firestorePort, authPort);
  const summary = {
    ...seeded,
    firestorePort,
    authPort,
    httpPort,
    project: PROJECT,
    tenant: TENANT,
    email: EMAIL,
    password: PASSWORD,
    pid: child.pid,
  };
  console.log(JSON.stringify(summary, null, 2));

  // Stay alive: the emulators are this process's children and the browser step
  // needs them running.
  const keep = setInterval(() => {}, 1 << 30);
  const stop = () => {
    clearInterval(keep);
    try {
      child.kill();
    } catch (_) {}
    if (existsSync(TEMP_CONFIG)) rmSync(TEMP_CONFIG);
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

// `verify` — the same two facts the browser must show, asked of the emulators
// from the OUTSIDE, with the app user's own ID token:
//   1. a tenant-constrained query returns exactly this tenant's rows
//   2. the SAME query without the constraint is DENIED (Firestore rules are not
//      filters — `allow read: if tenantOk()` tests `resource.data`, so an
//      unconstrained list cannot be proven safe).
// WHY outside the browser: this is the assertion the checkpoint cites, and it
// must not depend on a tab being visible or a canvas being painted.
async function verify() {
  if (!existsSync(PROOF)) throw new Error('run `up` first (no .shell-proof.json)');
  const { firestorePort, authPort } = JSON.parse(readFileSync(PROOF, 'utf8'));
  const authBase = `http://127.0.0.1:${authPort}/identitytoolkit.googleapis.com/v1`;
  const signIn = await fetch(`${authBase}/accounts:signInWithPassword?key=${AUTH_KEY}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD, returnSecureToken: true }),
  });
  if (!signIn.ok) throw new Error(`auth signIn failed: ${signIn.status} ${await signIn.text()}`);
  const { idToken } = await signIn.json();
  const claim = JSON.parse(Buffer.from(idToken.split('.')[1], 'base64url').toString('utf8'));

  const runQuery = async (structuredQuery) => {
    const res = await fetch(
      `http://127.0.0.1:${firestorePort}/v1/projects/${PROJECT}` +
        '/databases/(default)/documents:runQuery',
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${idToken}` },
        body: JSON.stringify({ structuredQuery }),
      },
    );
    const text = await res.text();
    if (!res.ok) return { status: res.status, error: text.slice(0, 300) };
    // A denied query comes back 200 with an `error` element per result row.
    // The REST body is a JSON ARRAY of result objects (or one object holding an
    // error); parse it, never split it — a pretty-printed body would break.
    const parsed = JSON.parse(text);
    const rows = Array.isArray(parsed) ? parsed : [parsed];
    const failure = rows.find((r) => r.error);
    if (failure) return { status: res.status, error: failure.error.message };
    const names = rows
      .filter((r) => r.document)
      .map((r) => r.document.fields?.name?.stringValue);
    return { status: res.status, count: names.length, names };
  };

  const constrained = await runQuery({
    from: [{ collectionId: 'menus' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'tenantId' },
        op: 'EQUAL',
        value: { stringValue: TENANT },
      },
    },
    limit: 20,
  });
  const unconstrained = await runQuery({
    from: [{ collectionId: 'menus' }],
    limit: 20,
  });

  const summary = {
    claimTenant: claim.tenantId ?? null,
    constrained,
    unconstrainedDenied: Boolean(unconstrained.error),
    unconstrainedError: unconstrained.error ?? null,
  };
  console.log(JSON.stringify(summary, null, 2));

  const ok =
    summary.claimTenant === TENANT &&
    constrained.count === 2 &&
    constrained.names.includes('Proof Shawarma') &&
    constrained.names.includes('Proof Falafel') &&
    !constrained.names.includes('Other Tenant Burger') &&
    summary.unconstrainedDenied;
  if (!ok) throw new Error('verify FAILED — see the JSON above');
  console.log('verify OK');
}

function down() {
  if (!existsSync(PROOF)) {
    console.log('nothing to stop (no .shell-proof.json)');
    return;
  }
  const { pid } = JSON.parse(readFileSync(PROOF, 'utf8'));
  // Stop only the pid this script recorded — never a name pattern.
  spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { shell: false });
  if (existsSync(TEMP_CONFIG)) rmSync(TEMP_CONFIG);
  rmSync(PROOF);
  console.log(`stopped emulator pid ${pid}`);
}

const command = process.argv[2] ?? 'up';
if (command === 'up') {
  await up();
} else if (command === 'down') {
  down();
} else if (command === 'verify') {
  await verify();
} else {
  console.error(`unknown command: ${command} (use up|verify|down)`);
  process.exit(2);
}
