/**
 * UI-9 (p19) T-3 — menu availability sync suite (RED first, then green).
 *
 * Consumes the compiled `../lib/platform_availability.js` + the fixture
 * response envelopes in `fixtures/platform/platform_http_responses.json` via an
 * injected client seam (the real `fetch` lives in `index.ts` only).
 *
 * What this pins (spec T-3 acceptance):
 *   - dish availability changes are detected from the EXISTING menu writes
 *   - each enabled platform gets its documented catalog payload (Uber Menu API
 *     `suspension_info`, DeliveryHero Catalog Import `availability`)
 *   - platform unavailable ⇒ retry/DLQ — the app's own availability write is
 *     never blocked and the caller never sees a throw (fail-safe)
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  detectAvailabilityChange,
  planAvailabilityPushes,
  classifyPushOutcome,
  syncAvailability,
} = require('../lib/platform_availability.js');
const {uberEatsMapper} = require('../lib/platform_mappers/uberEats.js');
const {deliveryHeroMapper} = require('../lib/platform_mappers/deliveryHero.js');

const RESPONSES = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, 'fixtures', 'platform', 'platform_http_responses.json'),
    'utf8',
  ),
);

const CHANGE = {
  menuItemId: 'mc_fries_1',
  branchId: 'carnama-branch-1',
  isAvailable: false,
};

function targets() {
  return [
    {platformId: 'uber_eats', storeId: 'STORE-HB-01', mapper: uberEatsMapper},
    {
      platformId: 'delivery_hero',
      storeId: 'carnama-branch-1',
      mapper: deliveryHeroMapper,
    },
  ];
}

function makeDeps(overrides = {}) {
  const calls = {platformCalls: [], deadLetters: [], logs: []};
  const base = {
    attempt: 0,
    maxAttempts: 3,
    targets: async () => targets(),
    callPlatform: async (request) => {
      calls.platformCalls.push(request);
      return {status: RESPONSES.accepted.status};
    },
    publishDeadLetter: async (entry) => {
      calls.deadLetters.push(entry);
    },
    log: (event) => {
      calls.logs.push(event);
    },
  };
  return {deps: {...base, ...overrides}, calls};
}


// ── change detection (the existing menus/{itemId} write) ────────────────────
test('T-3 availability change detection is strictly-when-present', () => {
  assert.deepEqual(
    detectAvailabilityChange({isAvailable: true}, {isAvailable: false}),
    {isAvailable: false},
  );
  assert.deepEqual(
    detectAvailabilityChange({isAvailable: false}, {isAvailable: true}),
    {isAvailable: true},
  );
  assert.equal(detectAvailabilityChange({isAvailable: true}, {isAvailable: true}), null);
  assert.equal(detectAvailabilityChange({isAvailable: true}, {isAvailable: 1}), null);
  assert.equal(detectAvailabilityChange({}, {isAvailable: true}), null, 'no field = no change');
  assert.deepEqual(detectAvailabilityChange(null, {isAvailable: false}), {
    isAvailable: false,
  });
  assert.equal(
    detectAvailabilityChange(null, {isAvailable: true}),
    null,
    'a newly published AVAILABLE item needs no suspension push',
  );
  assert.equal(detectAvailabilityChange('nope', 'nope'), null);
  assert.equal(detectAvailabilityChange(null, null), null);
});

// ── documented catalog payload shapes per platform ──────────────────────────
test('T-3 Uber Menu API payload suspends/restores with suspension_info', () => {
  const {requests, skipped} = planAvailabilityPushes({
    change: CHANGE,
    targets: targets(),
  });
  assert.deepEqual(skipped, []);
  assert.equal(requests.length, 2);
  const uber = requests.find((r) => r.platformId === 'uber_eats').request;
  assert.equal(uber.method, 'PUT');
  assert.match(uber.url, /stores\/STORE-HB-01\/menus/);
  assert.deepEqual(uber.body.menus[0].items[0], {
    id: 'mc_fries_1',
    suspension_info: {suspend_until: 0},
  });

  const restored = planAvailabilityPushes({
    change: {...CHANGE, isAvailable: true},
    targets: targets(),
  });
  const uberRestore = restored.requests.find(
    (r) => r.platformId === 'uber_eats',
  ).request;
  assert.equal(
    uberRestore.body.menus[0].items[0].suspension_info,
    null,
    'null clears the documented suspension',
  );
});

test('T-3 DeliveryHero Catalog Import payload carries per-item availability', () => {
  const {requests} = planAvailabilityPushes({change: CHANGE, targets: targets()});
  const dh = requests.find((r) => r.platformId === 'delivery_hero').request;
  assert.equal(dh.method, 'POST');
  assert.match(dh.url, /stores\/carnama-branch-1\/catalog/);
  assert.deepEqual(dh.body.items, [
    {id: 'mc_fries_1', availability: {available: false}},
  ]);
});

test('T-3 invalid targets are skipped, never pushed blind', () => {
  const {requests, skipped} = planAvailabilityPushes({
    change: CHANGE,
    targets: [
      {platformId: 'uber_eats', storeId: '', mapper: uberEatsMapper},
      {platformId: 'doordash', storeId: 'x', mapper: uberEatsMapper},
    ],
  });
  assert.deepEqual(requests, []);
  assert.equal(skipped.length, 2);
  assert.equal(skipped[0].reason, 'missing_store_id');
  assert.equal(skipped[1].reason, 'unknown_platform');
  assert.deepEqual(planAvailabilityPushes({change: CHANGE, targets: []}), {
    requests: [],
    skipped: [],
  });
});

// ── outcome classification (retry vs permanent) ─────────────────────────────
test('T-3 push outcomes classify retry vs dead-letter', () => {
  assert.equal(classifyPushOutcome(200, 0, 3).action, 'ok');
  assert.equal(classifyPushOutcome(204, 0, 3).action, 'ok');
  assert.equal(classifyPushOutcome(503, 0, 3).action, 'retry');
  assert.equal(classifyPushOutcome(503, 2, 3).action, 'dead_letter');
  assert.equal(classifyPushOutcome(429, 0, 3).action, 'retry');
  assert.equal(classifyPushOutcome(409, 0, 3).action, 'dead_letter');
  assert.equal(classifyPushOutcome(400, 0, 3).action, 'dead_letter');
  assert.equal(classifyPushOutcome(0, 0, 3).action, 'retry', 'network error = retry');
  assert.equal(classifyPushOutcome(0, 3, 3).action, 'dead_letter');
});

// ── orchestration: fail-safe, never blocks the app's own write ──────────────
test('T-3 all platforms accepted ⇒ pushed, no DLQ', async () => {
  const {deps, calls} = makeDeps();
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary.pushed, ['uber_eats', 'delivery_hero']);
  assert.deepEqual(summary.retried, []);
  assert.deepEqual(summary.deadLettered, []);
  assert.deepEqual(summary.skipped, []);
  assert.equal(calls.platformCalls.length, 2);
  assert.equal(calls.deadLetters.length, 0);
});

test('T-3 platform unavailable ⇒ retry, and the caller still never throws', async () => {
  const {deps, calls} = makeDeps({
    callPlatform: async () => ({status: RESPONSES.unavailable.status}),
  });
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary.retried, ['uber_eats', 'delivery_hero']);
  assert.deepEqual(summary.pushed, []);
  assert.equal(calls.deadLetters.length, 0, 'a retryable failure is not a DLQ entry yet');
  assert.equal(summary.failed, false);
});

test('T-3 retries exhausted ⇒ DLQ entry per platform (never an app-blocking throw)', async () => {
  const {deps, calls} = makeDeps({
    attempt: 3,
    callPlatform: async () => ({status: RESPONSES.unavailable.status}),
  });
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary.deadLettered, ['uber_eats', 'delivery_hero']);
  assert.equal(calls.deadLetters.length, 2);
  const entry = calls.deadLetters[0];
  assert.equal(entry.source, 'platform_availability');
  assert.equal(entry.platformId, 'uber_eats');
  assert.equal(entry.sourceKey, 'mc_fries_1');
  assert.equal(entry.reason, 'attempts_exhausted');
  assert.deepEqual(entry.payloadShape, {keys: ['id'], lineCount: 1, truncated: false});
});

test('T-3 a permanent platform rejection (409) goes straight to the DLQ', async () => {
  const {deps, calls} = makeDeps({
    callPlatform: async () => ({status: RESPONSES.conflict.status}),
  });
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary.deadLettered, ['uber_eats', 'delivery_hero']);
  assert.equal(calls.deadLetters[0].reason, 'platform_rejected_409');
});

test('T-3 a throwing client is swallowed into the DLQ (the menus write already committed)', async () => {
  const {deps, calls} = makeDeps({
    callPlatform: async () => {
      throw new Error('ECONNRESET');
    },
  });
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary.retried, ['uber_eats', 'delivery_hero']);
  assert.equal(summary.failed, false);

  const hard = await syncAvailability(
    {...deps, attempt: 3, callPlatform: async () => {
      throw new Error('ECONNRESET');
    }},
    CHANGE,
  );
  assert.deepEqual(hard.deadLettered, ['uber_eats', 'delivery_hero']);
  assert.equal(hard.failed, false);
  assert.ok(
    JSON.stringify(calls.logs).includes('platform_availability_push_failed'),
    'every failure is logged for the operator',
  );
});

test('T-3 no enabled platform ⇒ nothing pushed and nothing dead-lettered (inert)', async () => {
  const {deps, calls} = makeDeps({targets: async () => []});
  const summary = await syncAvailability(deps, CHANGE);
  assert.deepEqual(summary, {
    pushed: [],
    retried: [],
    deadLettered: [],
    skipped: [],
    failed: false,
  });
  assert.equal(calls.platformCalls.length, 0);
  assert.equal(calls.deadLetters.length, 0);
});

