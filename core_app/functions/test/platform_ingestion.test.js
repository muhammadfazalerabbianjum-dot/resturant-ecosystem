/**
 * UI-9 (p19) T-2 — platform order ingestion suite (RED first, then green).
 *
 * Runs against the COMPILED pure modules (`../lib/platform_ingestion.js`,
 * `../lib/platform_mappers/*.js`) and the EXISTING money-authority module
 * (`../lib/payment.js`) — the `money.test.js` / `idempotency_conflict.test.js`
 * pattern: no Firestore, no Stripe, no firebase-functions import. The real
 * ports (Admin SDK, secret resolver, outbound HTTP) are injected as fakes.
 *
 * What this pins (spec T-2 acceptance):
 *   - unknown/disabled platform ⇒ inert (no processing, no persist)
 *   - bad signature ⇒ 4xx + security-class log, NEVER a persist
 *   - valid payload ⇒ draft persisted + platform ack, prices re-derived by the
 *     EXISTING `verifyMenuPricing` path (platform totals never trusted, 0.10)
 *   - replay ⇒ no-op (L2: idempotency key = `platform:orderId`, namespaced)
 *   - out-of-stock / price-mismatch / unknown item ⇒ fulfillment-issue deny
 *   - malformed ⇒ DLQ, never a persist
 *   - L6: the persisted document carries NO customerId (consumer history is
 *     `customerId == uid`, so a platform order can never surface in a client
 *     app user's own list) and no customer PII at all
 *   - L5: every fixture has provenance in `fixtures/platform/PROVENANCE.md`
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const {
  PLATFORM_IDS,
  isPlatformId,
  buildPlatformIdempotencyKey,
  buildOrderSource,
  parseMinorUnitsStrict,
  verifyHmacSignature,
  describeShape,
  selectEnabledPlatforms,
  ingestPlatformOrderRequest,
} = require('../lib/platform_ingestion.js');
const {uberEatsMapper} = require('../lib/platform_mappers/uberEats.js');
const {deliveryHeroMapper} = require('../lib/platform_mappers/deliveryHero.js');

const FIXTURES = path.join(__dirname, 'fixtures', 'platform');
const readJson = (name) =>
  JSON.parse(fs.readFileSync(path.join(FIXTURES, name), 'utf8'));
const SECRET = 'p19-uber-webhook-secret';
const hmac = (secret, body) =>
  crypto.createHmac('sha256', secret).update(body).digest('hex');

/** Menu docs in the exact shape the existing money path consumes. */
const MENU = {
  mc_burger_1: {
    exists: true,
    data: {
      id: 'mc_burger_1',
      name: 'Burger',
      priceCents: 2450,
      branchId: 'carnama-branch-1',
      isAvailable: true,
      modifiers: [
        {
          id: 'm1',
          options: [
            {id: 'opt_cheese', name: 'Extra cheese', upchargeCents: 200},
          ],
        },
      ],
    },
  },
  mc_fries_1: {
    exists: true,
    data: {
      id: 'mc_fries_1',
      name: 'Fries',
      priceCents: 900,
      branchId: 'carnama-branch-1',
      isAvailable: true,
      modifiers: [],
    },
  },
};

function makeDeps(overrides = {}) {
  const calls = {
    persisted: [],
    platformCalls: [],
    deadLetters: [],
    logs: [],
    detailsFetches: [],
  };
  const base = {
    isPlatformEnabled: (id) => id === 'uber_eats' || id === 'delivery_hero',
    mapperFor: (id) =>
      id === 'uber_eats' ? uberEatsMapper :
        id === 'delivery_hero' ? deliveryHeroMapper : null,
    resolveSigningSecret: async () => SECRET,
    fetchOrderDetails: async (platformId, orderId) => {
      calls.detailsFetches.push([platformId, orderId]);
      return readJson('uber_eats_order_details.json');
    },
    findOrderIdByIdempotencyKey: async () => null,
    loadMenuDocs: async (ids) =>
      ids.map((id) => MENU[id] ?? {exists: false, data: null}),
    persistOrder: async (documentId, document) => {
      calls.persisted.push({documentId, document});
    },
    callPlatform: async (request) => {
      calls.platformCalls.push(request);
      return {status: 200};
    },
    publishDeadLetter: async (entry) => {
      calls.deadLetters.push(entry);
    },
    newOrderId: () => 'order-1',
    log: (event) => {
      calls.logs.push(event);
    },
  };
  return {deps: {...base, ...overrides}, calls};
}

function uberRequest(overrides = {}) {
  const rawBody = fs.readFileSync(
    path.join(FIXTURES, 'uber_eats_orders_notification.json'),
    'utf8',
  );
  return {
    platformId: 'uber_eats',
    rawBody,
    signatureHeader: hmac(SECRET, rawBody),
    storeId: 'STORE-HB-01',
    payload: JSON.parse(rawBody),
    ...overrides,
  };
}

function dhRequest(overrides = {}) {
  const rawBody = fs.readFileSync(
    path.join(FIXTURES, 'delivery_hero_order_push.json'),
    'utf8',
  );
  return {
    platformId: 'delivery_hero',
    rawBody,
    signatureHeader: hmac(SECRET, rawBody),
    storeId: 'carnama-branch-1',
    payload: JSON.parse(rawBody),
    ...overrides,
  };
}

// ── T-1 vocabulary / L2 key / L6 source / money parsing ─────────────────────
test('T-1 platform vocabulary mirrors the core adapter catalog', () => {
  assert.deepEqual([...PLATFORM_IDS].sort(), ['delivery_hero', 'uber_eats']);
  assert.equal(isPlatformId('uber_eats'), true);
  assert.equal(isPlatformId('delivery_hero'), true);
  assert.equal(isPlatformId('doordash'), false);
  assert.equal(isPlatformId(7), false);
  assert.equal(isPlatformId(null), false);
});

test('L2 idempotency key is namespaced per platform (no collisions)', () => {
  assert.equal(
    buildPlatformIdempotencyKey('uber_eats', 'ORDER123'),
    'uber_eats:ORDER123',
  );
  assert.equal(
    buildPlatformIdempotencyKey('delivery_hero', 'ORDER123'),
    'delivery_hero:ORDER123',
  );
  assert.notEqual(
    buildPlatformIdempotencyKey('uber_eats', 'ORDER123'),
    buildPlatformIdempotencyKey('delivery_hero', 'ORDER123'),
  );
});

test('L6 order-source vocabulary: platform:<id>', () => {
  assert.equal(buildOrderSource('uber_eats'), 'platform:uber_eats');
  assert.equal(buildOrderSource('delivery_hero'), 'platform:delivery_hero');
});

test('money: integer minor units only — a decimal float is never money', () => {
  assert.equal(parseMinorUnitsStrict(2450), 2450);
  assert.equal(parseMinorUnitsStrict('24.50'), 2450);
  assert.equal(parseMinorUnitsStrict('9.00'), 900);
  assert.equal(parseMinorUnitsStrict('0.05'), 5);
  assert.equal(parseMinorUnitsStrict('60'), 6000);
  assert.equal(parseMinorUnitsStrict(24.5), null, 'float must fail closed');
  assert.equal(parseMinorUnitsStrict('24.505'), null, '3 decimals unsupported');
  assert.equal(parseMinorUnitsStrict('24.5'), null, '2-decimal exact only');
  assert.equal(parseMinorUnitsStrict(''), null);
  assert.equal(parseMinorUnitsStrict(-1), null);
  assert.equal(parseMinorUnitsStrict(null), null);
  assert.equal(parseMinorUnitsStrict({}), null);
});

test('fail-closed webhook signature verification (timing-safe hex compare)', () => {
  const body = '{"a":1}';
  const good = hmac(SECRET, body);
  assert.deepEqual(
    verifyHmacSignature({secret: SECRET, rawBody: body, signature: good}),
    {verified: true, reason: null},
  );
  assert.deepEqual(
    verifyHmacSignature({
      secret: SECRET,
      rawBody: body,
      signature: good.toUpperCase(),
    }),
    {verified: true, reason: null},
    'hex case must not matter',
  );
  const reason = (input) => verifyHmacSignature(input).reason;
  assert.equal(reason({secret: '', rawBody: body, signature: good}), 'missing_secret');
  assert.equal(reason({secret: null, rawBody: body, signature: good}), 'missing_secret');
  assert.equal(
    reason({secret: SECRET, rawBody: body, signature: undefined}),
    'missing_signature',
  );
  assert.equal(
    reason({secret: SECRET, rawBody: body, signature: '   '}),
    'missing_signature',
  );
  assert.equal(
    reason({secret: SECRET, rawBody: body, signature: 'zz-not-hex'}),
    'malformed_signature',
  );
  assert.equal(
    reason({secret: SECRET, rawBody: body, signature: 'ab'}),
    'malformed_signature',
  );
  assert.equal(
    reason({secret: SECRET, rawBody: body, signature: hmac('other', body)}),
    'signature_mismatch',
  );
  assert.equal(
    reason({secret: SECRET, rawBody: undefined, signature: good}),
    'malformed_signature',
    'no raw body ⇒ nothing was signed',
  );
});

test('describeShape redacts: shape only, never values', () => {
  const shape = describeShape({
    order_id: 'DH-1',
    customer: {name: 'A', phone: '+971'},
    products: [1, 2],
  });
  assert.deepEqual(shape.keys, ['order_id', 'customer', 'products']);
  assert.equal(shape.lineCount, 2);
  const text = JSON.stringify(shape);
  assert.equal(text.includes('DH-1'), false);
  assert.equal(text.includes('+971'), false);
  assert.equal(shape.truncated, false);
  assert.deepEqual(describeShape('nope'), {keys: [], lineCount: 0, truncated: false});
  const big = describeShape({products: new Array(60).fill({id: 'x'})});
  assert.equal(big.truncated, true, 'the audit record caps the line count');
});

// ── L3 config gate: the server-side selector mirrors the Dart validator ─────
test('L3 selectEnabledPlatforms mirrors the validated config vocabulary', () => {
  const cases = readJson('delivery_platforms_config.json');
  assert.deepEqual(
    selectEnabledPlatforms(cases.valid.deliveryPlatforms).enabled,
    ['uber_eats'],
  );
  assert.deepEqual(
    selectEnabledPlatforms(cases.disabled.deliveryPlatforms).enabled,
    [],
    'disabled = inert',
  );
  for (const name of [
    'unknown_id',
    'missing_store_when_enabled',
    'secret_literal',
    'duplicate_id',
  ]) {
    const result = selectEnabledPlatforms(cases[name].deliveryPlatforms);
    assert.deepEqual(result.enabled, [], `${name} must yield NO enabled platform`);
    assert.ok(result.rejected.length > 0, `${name} must be rejected, not dropped`);
  }
  assert.deepEqual(selectEnabledPlatforms(cases.absent.deliveryPlatforms).enabled, []);
  assert.deepEqual(selectEnabledPlatforms(null).enabled, []);
  assert.deepEqual(selectEnabledPlatforms(cases.not_a_list.deliveryPlatforms).enabled, []);
});

// ── T-2 orchestration: inert / verification / mapping / re-derivation ───────
test('T-2 unknown platform id ⇒ inert 404, nothing processed', async () => {
  const {deps, calls} = makeDeps();
  const result = await ingestPlatformOrderRequest(deps, uberRequest({platformId: 'doordash'}));
  assert.equal(result.httpStatus, 404);
  assert.equal(result.body.status, 'inert');
  assert.equal(result.body.reason, 'unknown_platform');
  assert.equal(calls.persisted.length, 0);
  assert.equal(calls.platformCalls.length, 0);
});

test('T-2 disabled platform ⇒ inert 403 (config-gated, L3)', async () => {
  const {deps, calls} = makeDeps({isPlatformEnabled: () => false});
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 403);
  assert.equal(result.body.status, 'inert');
  assert.equal(result.body.reason, 'platform_disabled');
  assert.equal(calls.persisted.length, 0);
});

test('T-2 bad signature ⇒ 401 + security-class log, NEVER a persist', async () => {
  const {deps, calls} = makeDeps();
  const result = await ingestPlatformOrderRequest(
    deps,
    uberRequest({signatureHeader: hmac('attacker', 'x')}),
  );
  assert.equal(result.httpStatus, 401);
  assert.equal(result.body.status, 'rejected');
  assert.equal(result.body.reason, 'signature_signature_mismatch');
  assert.equal(calls.persisted.length, 0);
  assert.equal(calls.platformCalls.length, 0);
  const logged = calls.logs.at(-1);
  assert.equal(logged.event, 'platform_webhook_rejected');
  assert.equal(logged.platformId, 'uber_eats');
  assert.equal(logged.reason, 'signature_mismatch');
});

test('T-2 missing signature header ⇒ 401 (never a trust shortcut)', async () => {
  const {deps, calls} = makeDeps();
  const result = await ingestPlatformOrderRequest(
    deps,
    uberRequest({signatureHeader: undefined}),
  );
  assert.equal(result.httpStatus, 401);
  assert.equal(calls.logs.at(-1).reason, 'missing_signature');
});

test('T-2 missing signing secret ⇒ 401 (unconfigured platform never accepts)', async () => {
  const {deps, calls} = makeDeps({resolveSigningSecret: async () => null});
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 401);
  assert.equal(calls.logs.at(-1).reason, 'missing_secret');
  assert.equal(calls.persisted.length, 0);
});

test('T-2 Uber happy path: notification → details → re-derive → persist → ack', async () => {
  const {deps, calls} = makeDeps();
  const result = await ingestPlatformOrderRequest(deps, uberRequest());

  assert.equal(result.httpStatus, 200);
  assert.equal(result.body.status, 'accepted');
  assert.equal(result.body.orderId, 'order-1');
  assert.deepEqual(calls.detailsFetches, [['uber_eats', 'ORDER123']]);
  assert.equal(calls.persisted.length, 1);

  const {documentId, document} = calls.persisted[0];
  assert.equal(documentId, 'order-1');
  assert.equal(document.orderSource, 'platform:uber_eats');
  assert.equal(document.idempotencyKey, 'uber_eats:ORDER123');
  assert.equal(document.platformId, 'uber_eats');
  assert.equal(document.platformStoreId, 'STORE-HB-01');
  assert.equal(document.platformOrderId, 'ORDER123');
  assert.equal(document.status, 'confirmed');
  // branchId comes from the VERIFIED menu context, never the platform payload.
  assert.equal(document.branchId, 'carnama-branch-1');
  // 2 × (2450 + 200) + 1 × 900 = 6200 — OUR menu prices, not the platform's.
  assert.equal(document.itemsSubtotalCents, 6200);
  assert.equal(document.totalCents, 6200);
  assert.equal(document.platformClaimedTotalCents, 6000, 'reference only');
  assert.equal(document.items.length, 2);

  // L6: the consumer order-history filter is `customerId == uid` ⇒ a platform
  // order must carry NO customerId at all, and no customer PII either.
  assert.equal('customerId' in document, false);
  for (const key of Object.keys(document)) {
    assert.equal(
      /customer|address|phone|email|name/i.test(key),
      false,
      `persisted document must not carry customer PII (${key})`,
    );
  }

  assert.equal(calls.platformCalls.length, 1);
  const ack = calls.platformCalls[0];
  assert.equal(ack.method, 'POST');
  assert.ok(ack.path.includes('ORDER123'), `ack path must target the order: ${ack.path}`);
  assert.equal(ack.body.accepted, true);
  assert.equal(calls.deadLetters.length, 0);
});

test('L2 replay ⇒ no-op: no second order, no second ack', async () => {
  const {deps, calls} = makeDeps({
    findOrderIdByIdempotencyKey: async (key) => {
      assert.equal(key, 'uber_eats:ORDER123');
      return 'order-existing';
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 200);
  assert.equal(result.body.status, 'replayed');
  assert.equal(result.body.orderId, 'order-existing');
  assert.equal(calls.persisted.length, 0);
  assert.equal(calls.platformCalls.length, 0);
});

test('T-2 DeliveryHero happy path maps the documented push directly (no details fetch)', async () => {
  const {deps, calls} = makeDeps();
  const result = await ingestPlatformOrderRequest(deps, dhRequest());
  assert.equal(result.httpStatus, 200);
  assert.equal(result.body.status, 'accepted');
  assert.equal(calls.detailsFetches.length, 0);
  const {document} = calls.persisted[0];
  assert.equal(document.idempotencyKey, 'delivery_hero:DH-556677');
  assert.equal(document.orderSource, 'platform:delivery_hero');
  assert.equal(document.itemsSubtotalCents, 6200);
  assert.equal(document.platformClaimedTotalCents, 6000);
  assert.equal(calls.platformCalls[0].body.accepted, true);
});

// ── T-2 fail-closed money: mismatch ⇒ fulfillment-issue deny, no persist ────
test('T-2 platform price BELOW our menu price ⇒ deny (never persisted)', async () => {
  const {deps, calls} = makeDeps({
    fetchOrderDetails: async () => {
      const details = readJson('uber_eats_order_details.json');
      details.cart.items[0].price.unit_price.amount = 2000; // platform claim
      return details;
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 200);
  assert.equal(result.body.status, 'rejected');
  assert.equal(result.body.fulfillmentIssue, true);
  assert.equal(
    result.body.reason,
    'Item "mc_burger_1" price does not match the current menu price',
  );
  assert.equal(calls.persisted.length, 0, 'L6: never persisted with an unverifiable price');
  assert.equal(calls.platformCalls.length, 1);
  assert.equal(calls.platformCalls[0].body.accepted, false);
  assert.equal(calls.logs.at(-1).event, 'platform_order_denied');
});

test('T-2 out-of-stock (isAvailable:false) ⇒ fulfillment-issue deny', async () => {
  const {deps, calls} = makeDeps({
    loadMenuDocs: async (ids) =>
      ids.map((id) => {
        const doc = MENU[id];
        return id === 'mc_fries_1' ?
          {exists: true, data: {...doc.data, isAvailable: false}} :
          doc;
      }),
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.body.status, 'rejected');
  assert.equal(result.body.fulfillmentIssue, true);
  assert.match(result.body.reason, /unavailable/);
  assert.equal(calls.persisted.length, 0);
});

test('T-2 unknown menu item ⇒ fulfillment-issue deny', async () => {
  const {deps, calls} = makeDeps({
    loadMenuDocs: async (ids) => ids.map(() => ({exists: false, data: null})),
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.body.status, 'rejected');
  assert.equal(result.body.fulfillmentIssue, true);
  assert.equal(calls.persisted.length, 0);
});

test('T-2 malformed payload ⇒ DLQ + 400 (never a persist, redacted shape only)', async () => {
  const {deps, calls} = makeDeps();
  const rawBody = fs.readFileSync(
    path.join(FIXTURES, 'malformed_order_push.json'),
    'utf8',
  );
  const result = await ingestPlatformOrderRequest(deps, {
    platformId: 'delivery_hero',
    rawBody,
    signatureHeader: hmac(SECRET, rawBody),
    storeId: 'carnama-branch-1',
    payload: JSON.parse(rawBody),
  });
  assert.equal(result.httpStatus, 400);
  assert.equal(result.body.status, 'queued');
  assert.equal(result.body.deadLetter, true);
  assert.equal(calls.persisted.length, 0);
  assert.equal(calls.platformCalls.length, 0);
  assert.equal(calls.deadLetters.length, 1);
  const entry = calls.deadLetters[0];
  assert.equal(entry.source, 'platform_ingestion');
  assert.equal(entry.platformId, 'delivery_hero');
  assert.equal(entry.sourceKey, 'delivery_hero:DH-MALFORMED-1');
  assert.equal(entry.reason, 'malformed_payload');
  assert.ok(entry.payloadShape, 'the DLQ record carries a redacted shape');
  assert.equal(JSON.stringify(entry).includes('not-an-array'), false);
});

test('T-2 an unparsable currency claim ⇒ DLQ (no fabricated money)', async () => {
  const {deps, calls} = makeDeps();
  const payload = readJson('delivery_hero_order_push.json');
  payload.products[0].unit_price = '24.5';
  const rawBody = JSON.stringify(payload);
  const result = await ingestPlatformOrderRequest(deps, {
    platformId: 'delivery_hero',
    rawBody,
    signatureHeader: hmac(SECRET, rawBody),
    storeId: 'carnama-branch-1',
    payload,
  });
  assert.equal(result.httpStatus, 400);
  assert.equal(calls.deadLetters.at(-1).reason, 'price_unparseable');
  assert.equal(calls.persisted.length, 0);
});

test('T-2 an unexpected port failure ⇒ DLQ + 500 (no partial order, no ack)', async () => {
  const {deps, calls} = makeDeps({
    persistOrder: async () => {
      throw new Error('firestore unavailable');
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 500);
  assert.equal(result.body.status, 'queued');
  assert.equal(result.body.deadLetter, true);
  assert.equal(calls.platformCalls.length, 0, 'no ack when the order is not durable');
  assert.equal(calls.deadLetters.length, 1);
  assert.equal(calls.deadLetters[0].reason, 'unhandled_error');
  assert.ok(
    JSON.stringify(calls.deadLetters[0]).includes('firestore unavailable'),
    'the DLQ record keeps the error text for the operator',
  );
});

test('T-2 a missing details document ⇒ DLQ (no draft from a notification alone)', async () => {
  const {deps, calls} = makeDeps({fetchOrderDetails: async () => null});
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 400);
  assert.equal(calls.deadLetters.at(-1).reason, 'details_required');
  assert.equal(calls.persisted.length, 0);
});

test('T-2 details for a DIFFERENT order id ⇒ DLQ (never cross-order)', async () => {
  const {deps, calls} = makeDeps({
    fetchOrderDetails: async () => {
      const details = readJson('uber_eats_order_details.json');
      details.id = 'ORDER-OTHER';
      return details;
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 400);
  assert.equal(calls.deadLetters.at(-1).reason, 'order_id_mismatch');
  assert.equal(calls.persisted.length, 0);
});

test('T-2 a details fetch that throws ⇒ DLQ + 500 (retry, never a silent drop)', async () => {
  const {deps, calls} = makeDeps({
    fetchOrderDetails: async () => {
      throw new Error('uber api 503');
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(result.httpStatus, 500);
  assert.equal(calls.deadLetters.length, 1);
  assert.equal(calls.persisted.length, 0);
});

test('T-2 a failing platform callback keeps the durable order (L2 retry = replay)', async () => {
  const {deps, calls} = makeDeps({
    callPlatform: async () => {
      throw new Error('callback timeout');
    },
  });
  const result = await ingestPlatformOrderRequest(deps, uberRequest());
  assert.equal(calls.persisted.length, 1, 'the order is durable BEFORE the ack');
  assert.equal(result.httpStatus, 500);
  assert.equal(result.body.deadLetter, true);
  assert.equal(calls.deadLetters.at(-1).reason, 'unhandled_error');
});

// ── L5 fixture provenance: every fixture names its documented source ────────
test('L5 every fixture is listed in PROVENANCE.md with a source + status', () => {
  const provenance = fs.readFileSync(
    path.join(FIXTURES, 'PROVENANCE.md'),
    'utf8',
  );
  const files = fs.readdirSync(FIXTURES).filter((name) => name.endsWith('.json'));
  assert.ok(files.length >= 5, `expected the documented fixtures, got ${files}`);
  for (const file of files) {
    assert.ok(provenance.includes(file), `${file} must be listed in PROVENANCE.md`);
    const row = provenance.split('\n').find((line) => line.includes(file));
    assert.match(row, /\|/, `${file} row must be a table row`);
    assert.match(row, /UNVERIFIED|synthetic/, `${file} must be labeled (L5)`);
    JSON.parse(fs.readFileSync(path.join(FIXTURES, file), 'utf8'));
  }
});


