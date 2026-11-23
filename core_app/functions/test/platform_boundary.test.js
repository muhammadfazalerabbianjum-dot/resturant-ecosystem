/**
 * UI-9 (p19) T-5 — the App Check / verification BOUNDARY (RED first, then green).
 *
 * Platform webhooks are server-to-server: there is no app, no attestation and
 * therefore no App Check token. The function's OWN signature verification IS
 * the trust boundary — and App Check stays enforced for app traffic (callables
 * only). This suite proves both directions:
 *   (a) behavioral — an unverified external call is rejected (401) and never
 *       persists anything;
 *   (b) source-level — the webhook/trigger blocks never call `enforceAppCheck`
 *       while every callable still does, and the signing secret is resolved
 *       from a config REF (process.env), never a literal.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const {ingestPlatformOrderRequest} = require('../lib/platform_ingestion.js');
const {uberEatsMapper} = require('../lib/platform_mappers/uberEats.js');

const INDEX_SRC = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'index.ts'),
  'utf8',
);

/** The source block of one exported unit (up to the next `export const`). */
function blockOf(exportMarker) {
  const start = INDEX_SRC.indexOf(exportMarker);
  assert.notEqual(start, -1, `${exportMarker} must exist in index.ts`);
  const rest = INDEX_SRC.slice(start);
  const next = rest.indexOf('\nexport const ');
  return next === -1 ? rest : rest.slice(0, next);
}

test('T-5 the webhook is a raw onRequest whose signature verification IS the boundary', () => {
  assert.match(INDEX_SRC, /export const ingestPlatformOrder = onRequest\(/);
  const block = blockOf('export const ingestPlatformOrder = onRequest(');
  assert.match(block, /ingestPlatformOrderRequest\(/);
  assert.match(block, /logSecurityAlert\(/, 'rejections land in the security log stream');
  assert.match(
    block,
    /resolveSigningSecret/,
    'the per-platform secret comes from the config/secret ref',
  );
  assert.match(
    block,
    /process\.env\[/,
    'the secret VALUE is read from the environment, never a literal (L4)',
  );
  assert.equal(
    block.includes('enforceAppCheck'),
    false,
    'a server-to-server webhook carries no App Check token — verification is the boundary',
  );
});

test('T-5 App Check stays enforced for app traffic (callables) — no regression', () => {
  const guards = [...INDEX_SRC.matchAll(/enforceAppCheck\(request/g)].length;
  assert.ok(guards >= 10, `expected the callable guards to remain, found ${guards}`);
  assert.equal(
    INDEX_SRC.includes("defineSecret('UBER_EATS_WEBHOOK_SECRET')"),
    false,
    'per-client webhook secrets are config refs, not deploy-time declared literals',
  );
});

test('T-5 the availability trigger is fail-safe (DLQ, never a thrown write path)', () => {
  assert.match(
    INDEX_SRC,
    /export const syncMenuAvailability = onDocumentWritten\(\s*'menus\/\{itemId\}'/,
  );
  const block = blockOf('export const syncMenuAvailability = onDocumentWritten(');
  assert.match(block, /detectAvailabilityChange\(/);
  assert.match(block, /syncAvailability\(/);
  assert.match(
    block,
    /publishDeadLetter/,
    'a platform outage must be recorded, not thrown back into the menus write path',
  );
  assert.equal(
    /process\.env\.STRIPE/.test(block),
    false,
    'the availability path is not a money path',
  );
});

test('T-5 behavioral: an unverified external call is rejected and persists nothing', async () => {
  const rawBody = fs.readFileSync(
    path.join(__dirname, 'fixtures', 'platform', 'uber_eats_orders_notification.json'),
    'utf8',
  );
  const persisted = [];
  const logs = [];
  const result = await ingestPlatformOrderRequest(
    {
      isPlatformEnabled: () => true,
      mapperFor: () => uberEatsMapper,
      resolveSigningSecret: async () => 'the-real-secret',
      fetchOrderDetails: async () => null,
      findOrderIdByIdempotencyKey: async () => null,
      loadMenuDocs: async () => [],
      persistOrder: async (id, doc) => {
        persisted.push({id, doc});
      },
      callPlatform: async () => ({status: 200}),
      publishDeadLetter: async () => {},
      newOrderId: () => 'nope',
      log: (event) => logs.push(event),
    },
    {
      platformId: 'uber_eats',
      rawBody,
      // A stale/replayed signature from another body — the classic forgery.
      signatureHeader: crypto
        .createHmac('sha256', 'the-real-secret')
        .update('{"a":1}')
        .digest('hex'),
      storeId: 'STORE-HB-01',
      payload: JSON.parse(rawBody),
    },
  );
  assert.equal(result.httpStatus, 401);
  assert.equal(persisted.length, 0);
  assert.equal(logs.at(-1).event, 'platform_webhook_rejected');
});
