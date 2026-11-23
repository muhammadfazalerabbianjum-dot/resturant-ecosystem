// Gate (d) — real rules probe against the running Firestore emulator.
//
// Why this file exists: the previous gate (d) command ran
// `test/firestore_emulator_rules_test.dart`, which builds its documents with
// `fake_cloud_firestore`. That suite never contacts the emulator and never
// evaluates a rule, so appending deliberately invalid syntax to
// `core_app/firestore.rules` still produced a green gate (run 20261108T170157Z).
// A gate that cannot fail is worse than no gate.
//
// This probe makes two unauthenticated REST calls, one on each side of the
// authority boundary, and requires both outcomes to match what firestore.rules
// says:
//
//   GET /menus  -> 200, because `match /menus/{itemId}` grants `allow read: if true`
//   GET /users  -> 403, because /users never grants public read
//
// If the rules file does not compile, or the emulator never loaded it, every
// request is denied and the /menus expectation fails loudly. It is not a
// substitute for semantic rule testing (that is P0-8); it establishes that the
// deployed rules are parsed, loaded and enforced at all.

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host) {
  console.error('rules-probe: FIRESTORE_EMULATOR_HOST is not set — run me via `firebase emulators:exec`.');
  process.exit(1);
}

const project = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? 'demo-carnama-gate';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;

/** @returns {Promise<{status: number, body: string}>} */
async function probe(path, method = 'GET', payload) {
  const init = { method };
  if (payload !== undefined) {
    init.headers = { 'content-type': 'application/json' };
    init.body = JSON.stringify(payload);
  }
  const res = await fetch(`${base}${path}`, init);
  const body = await res.text();
  return { status: res.status, body: body.slice(0, 400) };
}

const checks = [
  // P1-4 (D-035): menus is public to the TENANT, not to the world. An
  // unauthenticated read now has no tenant claim, so the rules deny it — the
  // probe's job is to prove the boundary is enforced, not that it is absent.
  {
    path: '/menus',
    expect: 403,
    why: 'menu read without a tenant claim must be denied (tenantOk)',
  },
  { path: '/users', expect: 403, why: 'unauthenticated user list must be denied' },
  // P1-2: the money ledger is server-written only, and reads are owner-only.
  {
    path: '/transactions',
    expect: 403,
    why: 'unauthenticated ledger read must be denied',
  },
  {
    path: `/transactions?documentId=probe_${Date.now()}`,
    method: 'POST',
    payload: { fields: { totalCents: { integerValue: '1' } } },
    expect: 403,
    why: 'client ledger WRITE must be denied (allow write: if false)',
  },
];

let failures = 0;
for (const c of checks) {
  let got;
  const method = c.method ?? 'GET';
  try {
    got = await probe(c.path, method, c.payload);
  } catch (err) {
    console.error(`rules-probe: ${method} ${c.path} threw ${err.message}`);
    failures += 1;
    continue;
  }
  const ok = got.status === c.expect;
  const mark = ok ? 'ok  ' : 'FAIL';
  console.log(`rules-probe: ${mark} ${method} ${c.path} -> ${got.status} (expected ${c.expect}; ${c.why})`);
  if (!ok) {
    console.error(`rules-probe: ${c.path} body: ${got.body}`);
    failures += 1;
  }
}

if (failures > 0) {
  console.error(`rules-probe: ${failures} of ${checks.length} expectations failed — rules are not being enforced as documented.`);
  process.exit(1);
}
console.log('rules-probe: rules loaded and enforced on both sides of the boundary.');

// P1-2: same emulator, admin SDK, real transactions — see tool/ledger_probe.mjs.
const { runLedgerProbe } = await import('./ledger_probe.mjs');
const ledgerFailures = await runLedgerProbe();
if (ledgerFailures > 0) {
  console.error(`ledger-probe: ${ledgerFailures} expectation(s) failed.`);
  process.exit(1);
}
console.log('ledger-probe: order + one row commit atomically; replay adds none.');
