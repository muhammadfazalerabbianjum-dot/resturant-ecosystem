/**
 * FIX-B12 (REC-B2-1 / AUD1-01 residual) - SERVER IDEMPOTENCY CONTENT-COMPARISON.
 *
 * Defect under test (`functions/src/index.ts:1092-1101` at base): a key hit was
 * returned UNCONDITIONALLY - `return {orderId: existing.docs[0].id,
 * idempotent: true}` - with no comparison of the customer, the PaymentIntent or
 * the amount. Any caller presenting a key already in use was told "your order
 * is confirmed" and received ANOTHER ORDER'S ID (cross-user order disclosure).
 *
 * Lane: `npm test` -> `npm run build && node --test` (pure module
 * `../lib/idempotency.js` + the source structure of `../src/index.ts`) - the
 * same shape as `tax_fail_closed.test.js` (contract section 1, R-7).
 *
 * Contracts pinned (FIX_b12_server_dedupe.md section 3):
 *   T-1  identical triple (uid + paymentIntentId + totalCents) -> `replay`;
 *   T-2  THE DEFECT ROW: key hit with a DIFFERENT customer -> `conflict`
 *        `customer_mismatch` (never a foreign orderId);
 *   T-3  each field differing ALONE -> conflict naming THAT field; two fields
 *        differing -> conflict (precedence: customer -> intent -> amount);
 *   T-4  `null` / `undefined` / empty string on EITHER side -> conflict
 *        (fail-closed, law 0.5) - including a blank on BOTH sides;
 *   T-5  index.ts wires the classifier (no blind return survives);
 *   T-6  the conflict path throws `already-exists` with details
 *        `code: 'IDEMPOTENCY_CONFLICT'` (never a foreign order);
 *   T-7  the conflict path raises `logSecurityAlert`
 *        `event: 'idempotency_conflict_rejected'` (R-6 channel);
 *   T-8  REGRESSION PIN: the replay path still returns
 *        `{orderId: <doc id>, idempotent: true}` (B2's legitimate retry shape).
 *
 * RED NOTE: T-1..T-4's matrix is written BEFORE T-1's body exists (law 0.2), so
 * the loader below turns a missing `../lib/idempotency.js` into a NAMED per-row
 * failure instead of a file-level module error - the red receipt therefore
 * shows each defect row, including "different customer on the same key".
 * T-8 holds BOTH before and after the fix (it pins the legitimate path).
 *
 * MONEY SANCTUARY (law 0.4): this file only ADDS assertions; no existing test
 * is modified.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Lazy loader: red rows fail with a named reason while T-1 is unimplemented.
let classifyIdempotentReplay = null;
let loadError = null;
try {
  ({classifyIdempotentReplay} = require('../lib/idempotency.js'));
} catch (err) {
  loadError = err;
}

/** Returns the classifier under test, failing every red row by name. */
function classifier() {
  if (typeof classifyIdempotentReplay !== 'function') {
    assert.fail(
        'classifyIdempotentReplay unavailable (T-1 not implemented yet): ' +
        (loadError ? loadError.message : 'module did not export the function'),
    );
  }
  return classifyIdempotentReplay;
}

const INDEX_SRC = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'index.ts'),
    'utf8',
);

/** The createOrder idempotency block (from the Law-9 marker to its successor). */
function createOrderIdempotencyBlock() {
  const start = INDEX_SRC.indexOf('// IDEMPOTENCY (Law 9)');
  assert.notEqual(start, -1, 'createOrder idempotency block marker must exist');
  const end = INDEX_SRC.indexOf('// Verify payment succeeded', start);
  assert.notEqual(end, -1, 'idempotency block end marker not found - reslice block');
  return INDEX_SRC.slice(start, end);
}

// ---------------------------------------------------------------------------
// The baseline triple: the SAME attempt replaying its own key.
// ---------------------------------------------------------------------------
const kSame = {
  request: {uid: 'user-1', paymentIntentId: 'pi_1', totalCents: 1620},
  existing: {customerId: 'user-1', paymentIntentId: 'pi_1', totalCents: 1620},
};

/** Deep-clone helper so each row mutates only its own copy. */
const clone = (input) => JSON.parse(JSON.stringify(input));

// ---------------------------------------------------------------------------
// T-1 - identical triple -> replay (the legitimate B2 retry path).
// ---------------------------------------------------------------------------
test('T-1 identical triple (same customer, same intent, same amount) -> replay', () => {
  assert.deepEqual(classifier()(clone(kSame)), {kind: 'replay'});
});

// ---------------------------------------------------------------------------
// T-2 - THE DEFECT ROW (REC-B2-1): key hit with a DIFFERENT customer.
// The old code returned the foreign order here; it MUST conflict.
// ---------------------------------------------------------------------------
test('T-2 THE DEFECT: key hit with a DIFFERENT customer -> conflict customer_mismatch', () => {
  const input = clone(kSame);
  input.request.uid = 'user-2'; // another user presents the same key
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'customer_mismatch',
  });
});

test('T-2b key hit with a missing customerId on the stored order -> conflict customer_mismatch', () => {
  const input = clone(kSame);
  input.existing.customerId = null;
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'customer_mismatch',
  });
});

// ---------------------------------------------------------------------------
// T-3 - each field differing ALONE -> conflict naming that field.
// ---------------------------------------------------------------------------
test('T-3a paymentIntentId differs alone -> conflict payment_intent_mismatch', () => {
  const input = clone(kSame);
  input.request.paymentIntentId = 'pi_2';
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'payment_intent_mismatch',
  });
});

test('T-3b totalCents differs alone -> conflict amount_mismatch', () => {
  const input = clone(kSame);
  input.request.totalCents = 999;
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'amount_mismatch',
  });
});

test('T-3c two fields differ (customer + intent) -> conflict customer_mismatch (precedence)', () => {
  const input = clone(kSame);
  input.request.uid = 'user-2';
  input.request.paymentIntentId = 'pi_2';
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'customer_mismatch',
  });
});

test('T-3d two fields differ (intent + amount) -> conflict payment_intent_mismatch (precedence)', () => {
  const input = clone(kSame);
  input.request.paymentIntentId = 'pi_2';
  input.request.totalCents = 1;
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'payment_intent_mismatch',
  });
});

test('T-3e all three fields differ -> conflict customer_mismatch (precedence)', () => {
  const input = clone(kSame);
  input.request.uid = 'user-2';
  input.request.paymentIntentId = 'pi_2';
  input.request.totalCents = 1;
  assert.deepEqual(classifier()(input), {
    kind: 'conflict',
    reason: 'customer_mismatch',
  });
});

// ---------------------------------------------------------------------------
// T-4 - missing/blank on EITHER side -> conflict (fail-closed, law 0.5).
// ---------------------------------------------------------------------------
for (const bad of [null, undefined, '']) {
  const shown = JSON.stringify(bad);

  test(`T-4a request.uid = ${shown} -> conflict customer_mismatch`, () => {
    const input = clone(kSame);
    input.request.uid = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'customer_mismatch',
    });
  });

  test(`T-4b existing.customerId = ${shown} -> conflict customer_mismatch`, () => {
    const input = clone(kSame);
    input.existing.customerId = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'customer_mismatch',
    });
  });

  test(`T-4c BOTH uid/customerId = ${shown} -> conflict (blank never matches blank)`, () => {
    const input = clone(kSame);
    input.request.uid = bad;
    input.existing.customerId = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'customer_mismatch',
    });
  });

  test(`T-4d request.paymentIntentId = ${shown} -> conflict payment_intent_mismatch`, () => {
    const input = clone(kSame);
    input.request.paymentIntentId = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'payment_intent_mismatch',
    });
  });

  test(`T-4e existing.paymentIntentId = ${shown} -> conflict payment_intent_mismatch`, () => {
    const input = clone(kSame);
    input.existing.paymentIntentId = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'payment_intent_mismatch',
    });
  });

  test(`T-4f request.totalCents = ${shown} -> conflict amount_mismatch`, () => {
    const input = clone(kSame);
    input.request.totalCents = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'amount_mismatch',
    });
  });

  test(`T-4g existing.totalCents = ${shown} -> conflict amount_mismatch`, () => {
    const input = clone(kSame);
    input.existing.totalCents = bad;
    assert.deepEqual(classifier()(input), {
      kind: 'conflict',
      reason: 'amount_mismatch',
    });
  });
}

test('T-4h non-integer / non-numeric amount -> conflict amount_mismatch (integer cents only)', () => {
  const asString = clone(kSame);
  asString.request.totalCents = '1620';
  assert.deepEqual(classifier()(asString), {
    kind: 'conflict',
    reason: 'amount_mismatch',
  });

  const fractional = clone(kSame);
  fractional.existing.totalCents = 1620.5;
  assert.deepEqual(classifier()(fractional), {
    kind: 'conflict',
    reason: 'amount_mismatch',
  });
});

// ---------------------------------------------------------------------------
// T-5..T-8 - index.ts wiring (structural, same style as tax_fail_closed).
// ---------------------------------------------------------------------------
test('T-5 index.ts imports the classifier and the idempotency block COMPARES content (no blind return)', () => {
  assert.match(INDEX_SRC, /from '\.\/idempotency'/, 'index.ts must import ./idempotency');
  const block = createOrderIdempotencyBlock();
  assert.ok(
      block.includes('classifyIdempotentReplay'),
      'createOrder idempotency block must call classifyIdempotentReplay - a key hit without a content comparison is the REC-B2-1 defect',
  );
});

test('T-6 conflict path throws already-exists with details code IDEMPOTENCY_CONFLICT', () => {
  const block = createOrderIdempotencyBlock();
  assert.ok(
      block.includes("'already-exists'"),
      "conflict must throw HttpsError code 'already-exists' (B5 classifier: permanent, never retried)",
  );
  assert.ok(
      block.includes("'IDEMPOTENCY_CONFLICT'"),
      "conflict details must carry code 'IDEMPOTENCY_CONFLICT' (client mapping key)",
  );
  assert.ok(
      block.includes('kind === \'conflict\''),
      'the conflict branch must be distinguishable from the replay return',
  );
});

test("T-7 conflict path logs logSecurityAlert event 'idempotency_conflict_rejected'", () => {
  const block = createOrderIdempotencyBlock();
  assert.ok(
      block.includes('logSecurityAlert'),
      'a rejected key reuse must hit the R-6 security channel',
  );
  assert.ok(
      block.includes("event: 'idempotency_conflict_rejected'"),
      "security event must be named 'idempotency_conflict_rejected'",
  );
});

test('T-8 REGRESSION PIN: replay path still returns {orderId, idempotent: true}', () => {
  const block = createOrderIdempotencyBlock();
  assert.match(
      block,
      /return\s*\{\s*orderId:\s*[^,}]+,\s*idempotent:\s*true\s*\}/,
      'a legitimate same-key+same-content retry must keep the byte-identical success shape',
  );
});



