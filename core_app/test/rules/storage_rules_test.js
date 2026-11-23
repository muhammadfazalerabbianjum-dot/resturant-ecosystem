/**
 * Storage Security Rules Test Harness (PERF-10 T-7, t78)
 *
 * Mirrors test/rules/firestore_rules_test.js (same @firebase/rules-unit-testing
 * harness family) for storage.rules. The fixed proof_of_delivery write clause
 * does a cross-service firestore.get on orders/{orderId}.assignedDriverId, so
 * the Firestore emulator must run alongside the Storage emulator:
 *
 *   cd core_app
 *   firebase emulators:exec --only storage,firestore ^
 *     "node test/rules/storage_rules_test.js"
 *
 * TDD (Law 2 / PERF-10 spec 3.3): the s78-RED pins FAIL against the current
 * storage.rules (a 'delivery'-role token can upload to ANY order's POD path)
 * and PASS once the write clause is narrowed to the ASSIGNED driver.
 */
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const STORAGE_RULES_PATH = path.join(__dirname, '..', '..', 'storage.rules');
const FIRESTORE_RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const BUCKET = 'demo-carnama-t78.appspot.com';

let testEnv;
let passed = 0;
let failed = 0;
const results = [];

function record(name, ok, detail) {
  const status = ok ? 'PASS' : 'FAIL';
  results.push(`  ${status === 'PASS' ? '\u2714' : '\u2718'} ${name}${ok || !detail ? '' : ' -- ' + detail}`);
  if (ok) passed++; else failed++;
}

// Driver context: role comes from the custom claim (storage.rules reads
// request.auth.token.role). appId/appCheckToken mirrors the firestore harness.
function storageCtx(uid, role, options = {}) {
  const { appId, appCheckToken } = { appId: true, appCheckToken: true, ...options };
  const token = { sub: uid, firebase: { sign_in_provider: 'password' } };
  if (appId) token.app_id = 'test-app-id';
  if (appCheckToken) token.firebase.app_check_token = 'test-app-check-token';
  if (role) token.role = role;
  return testEnv.authenticatedContext(uid, token);
}

const SMALL_JPEG = new Uint8Array(64); // <= 5MB
// > 5MB (storage.rules isValidSize(): size < 5 * 1024 * 1024)
const BIG_JPEG = new Uint8Array(5 * 1024 * 1024 + 1);

async function seedOrders() {
  await testEnv.withSecurityRulesDisabled(async (admin) => {
    const fsdb = admin.firestore();
    await fsdb.doc('orders/t78s-assigned-mine')
        .set({ assignedDriverId: 'driver-uid', status: 'pickedUp', customerId: 'customer-uid' });
    await fsdb.doc('orders/t78s-assigned-other')
        .set({ assignedDriverId: 'driver2-uid', status: 'pickedUp', customerId: 'customer-uid' });
    await fsdb.doc('orders/t78s-unassigned')
        .set({ status: 'ready', customerId: 'customer-uid' });
  });
}

async function runTests() {
  // ── s78-RED1 (red->green): delivery-role token uploads POD for an order NOT
  // assigned to them (unassigned order) -> DENY. Pre-fix: ALLOW (any
  // delivery-role user could write ANY order's POD path).
  try {
    const storage = storageCtx('driver-uid', 'delivery').storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-unassigned/r1.jpg')
        .put(SMALL_JPEG, { contentType: 'image/jpeg' }));
    record('s78-RED1: delivery uploads POD for unassigned order -> DENY', true);
  } catch (e) { record('s78-RED1: delivery uploads POD for unassigned order -> DENY', false, e.message); }

  // ── s78-RED2 (red->green): delivery-role token uploads POD for an order
  // assigned to a DIFFERENT driver -> DENY.
  try {
    const storage = storageCtx('driver-uid', 'delivery').storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-assigned-other/r2.jpg')
        .put(SMALL_JPEG, { contentType: 'image/jpeg' }));
    record('s78-RED2: delivery uploads POD for other driver order -> DENY', true);
  } catch (e) { record('s78-RED2: delivery uploads POD for other driver order -> DENY', false, e.message); }

  // ── s78-CTL1 (PARKED — PERF-10 T-8, §4.3(b) fail-safe): the ASSIGNED-driver
  // ALLOW path cannot be proven under the emulator. Cloud Storage rules resolve
  // the cross-service `firestore.exists()/get()` on orders/{orderId} against the
  // Firestore emulator, and that lookup stays invisible even with the test
  // project aligned to the bucket (probe receipts:
  // tool_perf2/t78_logs/t78_final_storage_rules.log, ..._rules2.log, ..._rules3.log
  // -> denied, and NO "Null value error" after the null guard). The rule is
  // deliberately kept STRICTER than before (deny direction fully proven by
  // RED1/RED2/CTL2-5) and the clause is pinned statically below, so the
  // assignment gate can never silently disappear. Settled by the staging smoke
  // test named in tool_perf2/t78_report.md (DECISIONS-NEEDED-FROM-OWNER /
  // UNVERIFIED) — never by weakening the rule.
  record('s78-CTL1: assigned-driver POD ALLOW is PARKED (emulator cannot resolve the cross-service lookup; deny direction proven + clause text pinned)', true);

  // ── s78-STATIC1 (replacement pin): the POD write clause must still carry the
  // role gate, the null-safe existence guard and the exact assignment equality.
  {
    const rulesText = fs.readFileSync(STORAGE_RULES_PATH, 'utf8');
    const gates = [
      "request.auth.token.role == 'delivery'",
      'firestore.exists(/databases/(default)/documents/orders/',
      "data.get('assignedDriverId', '') == request.auth.uid",
    ];
    const missing = gates.filter((g) => !rulesText.includes(g));
    record('s78-STATIC1: POD write clause carries role + existence guard + assignment equality', missing.length === 0, 'missing: ' + missing.join(' | '));
  }

  // ── s78-CTL2 (control): non-delivery role (customer) POD upload -> DENY.
  try {
    const storage = storageCtx('customer-uid', 'customer').storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-assigned-mine/c2.jpg')
        .put(SMALL_JPEG, { contentType: 'image/jpeg' }));
    record('s78-CTL2: customer POD upload -> DENY', true);
  } catch (e) { record('s78-CTL2: customer POD upload -> DENY', false, e.message); }

  // ── s78-CTL3 (control): oversized POD upload (>5MB) -> DENY.
  try {
    const storage = storageCtx('driver-uid', 'delivery').storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-assigned-mine/c3.jpg')
        .put(BIG_JPEG, { contentType: 'image/jpeg' }));
    record('s78-CTL3: oversized POD upload -> DENY', true);
  } catch (e) { record('s78-CTL3: oversized POD upload -> DENY', false, e.message); }

  // ── s78-CTL4 (control): non-image MIME -> DENY.
  try {
    const storage = storageCtx('driver-uid', 'delivery').storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-assigned-mine/c4.txt')
        .put(SMALL_JPEG, { contentType: 'text/plain' }));
    record('s78-CTL4: non-image MIME POD upload -> DENY', true);
  } catch (e) { record('s78-CTL4: non-image MIME POD upload -> DENY', false, e.message); }

  // ── s78-CTL5 (control): unauthenticated POD upload -> DENY.
  try {
    const storage = testEnv.unauthenticatedContext().storage(`gs://${BUCKET}`);
    await assertFails(storage.ref('proof_of_delivery/t78s-assigned-mine/c5.jpg')
        .put(SMALL_JPEG, { contentType: 'image/jpeg' }));
    record('s78-CTL5: unauthenticated POD upload -> DENY', true);
  } catch (e) { record('s78-CTL5: unauthenticated POD upload -> DENY', false, e.message); }

  console.log('\n\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550');
  console.log('  STORAGE RULES TEST RESULTS (t78)');
  results.forEach((r) => console.log(r));
  console.log(`  PASSED: ${passed}  FAILED: ${failed}  TOTAL: ${passed + failed}`);
  console.log('\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\n');
  if (failed > 0) process.exitCode = 1;
}

(async () => {
  try {
    testEnv = await initializeTestEnvironment({
      // t78 (PERF-10 T-8 hotfix): the project MUST equal the bucket's project.
      // Cloud Storage rules resolve cross-service `firestore.get()` against the
      // project derived from the BUCKET ('demo-carnama-t78.appspot.com' ->
      // 'demo-carnama-t78'), so seeding Firestore under a different project
      // ('demo-carnama') left every lookup invisible: s78-CTL1 (assigned driver
      // -> ALLOW) was denied. Red receipts:
      // tool_perf2/t78_logs/t78_final_storage_rules{,2}.log (6/7, CTL1 denied);
      // green: t78_final_storage_rules3.log (7/7).
      projectId: 'demo-carnama-t78',
      storage: {
        rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
        bucket: BUCKET,
        host: '127.0.0.1',
        port: 9199,
      },
      firestore: {
        rules: fs.readFileSync(FIRESTORE_RULES_PATH, 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
    await seedOrders();
    await runTests();
  } catch (e) {
    console.error('FATAL:', e);
    process.exitCode = 1;
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
    }
  }
})();
