/**
 * UI-9 (p19) T-4 — runbook self-verification (the RUNBOOK_DEPLOY precedent:
 * §0 evidence table + §1 self-verifying grep, names are load-bearing).
 *
 * A runbook whose referenced names drift away from the code is worse than no
 * runbook; this suite fails the moment the operator document and the shipped
 * implementation disagree about a platform, a config key, an env var or a
 * documented source URL.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const P19 = path.resolve(__dirname, '..', '..', '..', 'tool_uilib', 'p19');
const RUNBOOK = path.join(P19, 'RUNBOOK_DELIVERY_PLATFORMS.md');

const read = () => fs.readFileSync(RUNBOOK, 'utf8');

test('T-4 the runbook exists with the RUNBOOK_DEPLOY-style self-verifying sections', () => {
  assert.ok(fs.existsSync(RUNBOOK), `missing runbook: ${RUNBOOK}`);
  const text = read();
  for (const marker of [
    '# RUNBOOK_DELIVERY_PLATFORMS.md',
    '## 0. EVIDENCE TABLE',
    '## 1. SELF-VERIFYING GREP',
    '## 2. PER-PLATFORM CREDENTIAL ACQUISITION',
    '## 3. GO-LIVE CHECKLIST',
    '## 4. TEST PLAN',
    '## 5. CLIENT ENABLEMENT',
    '## 6. SOURCES',
  ]) {
    assert.ok(text.includes(marker), `runbook must keep the marker: ${marker}`);
  }
  assert.equal(/REPLACE_ME|TODO|TBD|FIXME/.test(text), false, 'no placeholders in a runbook');
});

test('T-4 every platform section cites its fetched source (L5 provenance)', () => {
  const text = read();
  for (const url of [
    'developer.uber.com/docs/eats/guides/order_integration',
    'developers.deliveryhero.com/documentation/pos.html',
    'developer.talabat.com',
  ]) {
    assert.ok(text.includes(url), `runbook must cite ${url}`);
  }
  assert.ok(text.includes('orders.notification'), 'Uber webhook name must be exact');
  assert.ok(text.includes('Catalog Import'), 'DH Catalog Import API must be named');
  assert.ok(/PGP/.test(text), 'the DH PGP credential step must be documented');
  assert.ok(
    text.includes('The integration might get disabled by Delivery Hero'),
    'the DH SLA clause must be quoted, not paraphrased',
  );
  assert.ok(
    /maintenance agreement/i.test(text),
    'the DH post-production maintenance agreement must be called out',
  );
});

test('T-4 the config keys documented are exactly the shipped schema', () => {
  const text = read();
  for (const key of ['deliveryPlatforms', 'id', 'enabled', 'credentialRef', 'storeId']) {
    assert.ok(text.includes(key), `runbook must document the config key: ${key}`);
  }
  for (const ref of ['UBER_EATS_WEBHOOK_SECRET', 'DELIVERY_HERO_WEBHOOK_SECRET']) {
    assert.ok(text.includes(ref), `runbook must name the secret ref: ${ref}`);
  }
  assert.ok(
    text.includes('settings/restaurantConfig'),
    'the server-side config doc the function reads must be named',
  );
});

test('T-4 the Uber sandbox test plan follows the documented flow', () => {
  const text = read();
  assert.ok(/test store/i.test(text), 'test store step');
  assert.ok(/test order/i.test(text), 'test order step');
  assert.ok(/accept/i.test(text) && /deny/i.test(text), 'accept/deny step');
  assert.ok(/webhook/i.test(text), 'webhook step');
});
