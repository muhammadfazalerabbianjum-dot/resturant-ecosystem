/**
 * FIX-B4 TAX-1 (AUD1-04 + AUD1-05) - fail-closed guard REACHABLE in BOTH
 * server paths, exactly ONE tax implementation, one rounding contract.
 *
 * Lane: `npm test` -> `npm run build && node --test` (pure module
 * `../lib/payment.js` + the source structure of `../src/index.ts`). There is no
 * emulator/Jest lane for `functions/` (FIX_b4_tax_rounding.md section 1), so
 * the callable is asserted STRUCTURALLY: it must delegate to the same pure
 * functions the charge path calls, so a guard proven here is reachable there.
 *
 * Contracts pinned by FIX_b4_tax_rounding.md section 3:
 *   T-1  `calculateTax` delegates to extractClientTaxConfig + computeTaxCents;
 *        no second rate-resolution and no second default-rate literal survives.
 *   T-2  unknown clientId / missing rate for the state / rate outside [0,1]
 *        FAIL CLOSED in both paths (explicit error, never a silent default).
 *   T-3  integer-cent tax rounding is HALF AWAY FROM ZERO (Dart `.round()`);
 *        `Math.round` (half toward +Infinity) is banned for tax in JS.
 *
 * MONEY SANCTUARY (section 0.7): this file only ADDS assertions; no existing
 * tax/money test is modified.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  MoneyComputationError,
  extractClientTaxConfig,
  computeTaxCents,
  roundHalfAwayFromZero,
} = require('../lib/payment.js');

const INDEX_SRC = fs.readFileSync(path.join(__dirname, '..', 'src', 'index.ts'), 'utf8');
const PAYMENT_SRC = fs.readFileSync(path.join(__dirname, '..', 'src', 'payment.ts'), 'utf8');

/** The `calculateTax` callable body (from its export to the next export). */
function calculateTaxBlock() {
  const start = INDEX_SRC.indexOf('export const calculateTax');
  assert.notEqual(start, -1, 'calculateTax callable must exist in index.ts');
  const end = INDEX_SRC.indexOf('export const screenPaymentFraud');
  assert.notEqual(end, -1, 'next export marker not found - reslice block');
  return INDEX_SRC.slice(start, end);
}

/** The `computeTaxCents` body in payment.ts (the single implementation). */
function computeTaxCentsBody() {
  const start = PAYMENT_SRC.indexOf('export function computeTaxCents');
  assert.notEqual(start, -1, 'computeTaxCents must exist in payment.ts');
  const end = PAYMENT_SRC.indexOf('// Items subtotal', start);
  assert.notEqual(end, -1, 'computeTaxCents section end marker not found');
  return PAYMENT_SRC.slice(start, end);
}


// ---------------------------------------------------------------------------
// T-1 - ONE implementation: the callable delegates to the charge path's pure
// functions. RED at base: `calculateTax` had its own rate resolution
// (hardcoded CA/NY/TX/FL table + `?? 0.05`) and its own `Math.round` tax.
// ---------------------------------------------------------------------------
test('T-1 calculateTax delegates to extractClientTaxConfig + computeTaxCents', () => {
  const block = calculateTaxBlock();
  assert.match(
    block,
    /extractClientTaxConfig\(/,
    'callable must resolve its tax config through the shared helper',
  );
  assert.match(
    block,
    /computeTaxCents\(/,
    'callable must compute its tax through the shared implementation',
  );
});

test('T-1 no second rate-resolution or rounding rule survives in calculateTax', () => {
  const block = calculateTaxBlock();
  // No second rounding rule.
  assert.doesNotMatch(
    block,
    /Math\.round\(/,
    'calculateTax must not round tax itself (T-3: Math.round rounds halves toward +Infinity)',
  );
  // No second rate lookup / default-rate literal (the unreachable-guard bug).
  assert.doesNotMatch(block, /\[stateCode\]/, 'second state-code rate lookup present');
  assert.doesNotMatch(block, /\?\?\s*0\.05/, 'silent 5% default literal present');
  assert.doesNotMatch(block, /CA:\s*0\.0725/, 'hardcoded offline rate table present');
  assert.doesNotMatch(block, /subtotalCents \* rate/, 'second tax product present');
});

// ---------------------------------------------------------------------------
// T-2 - the guard is REACHABLE in both paths. RED at base: `rate` could never
// be `undefined` (`?? 0.05`), so the documented fail-closed guard was dead
// code and an unconfigured tenant was silently taxed 5% (AUD1-04).
// ---------------------------------------------------------------------------
test('T-2 unknown clientId fails closed (charge path) - never a silent default', () => {
  const doc = {
    defaultRate: 0.05,
    clients: {'com.example.app': {stateRates: {CA: 0.0725}}},
  };
  // The tenant below has NO row in settings/taxRates.clients.
  const config = extractClientTaxConfig(doc, 'com.unknown.app');
  assert.throws(
    () => computeTaxCents(config, 10000, 'CA'),
    (err) => {
      assert.ok(err instanceof MoneyComputationError, `wrong error type: ${err}`);
      assert.equal(err.code, 'tax_not_configured');
      assert.match(err.message, /client/i, 'error must name the unknown client');
      return true;
    },
    'unknown clientId must fail closed (RED at base: returned 500 = silent 5%)',
  );
});

test('T-2 missing rate for the state fails closed (no configured default)', () => {
  const config = extractClientTaxConfig(
    {clients: {'com.example.app': {stateRates: {CA: 0.0725}}}},
    'com.example.app',
  );
  assert.throws(
    () => computeTaxCents(config, 10000, 'ZZ'),
    (err) => err instanceof MoneyComputationError && err.code === 'tax_not_configured',
  );
});

test('T-2 rate outside [0,1] fails closed (rate too high)', () => {
  const config = extractClientTaxConfig(
    {clients: {'com.example.app': {stateRates: {CA: 1.5}, defaultRate: 0.05}}},
    'com.example.app',
  );
  assert.throws(
    () => computeTaxCents(config, 10000, 'CA'),
    (err) => {
      assert.ok(err instanceof MoneyComputationError, `wrong error type: ${err}`);
      assert.equal(err.code, 'tax_not_configured');
      return true;
    },
    'a 150% rate must be rejected (RED at base: returned 15000)',
  );
});

test('T-2 rate outside [0,1] fails closed (negative rate must not fall back)', () => {
  const config = extractClientTaxConfig(
    {clients: {'com.example.app': {stateRates: {CA: -0.5}, defaultRate: 0.05}}},
    'com.example.app',
  );
  assert.throws(
    () => computeTaxCents(config, 10000, 'CA'),
    (err) => {
      assert.ok(err instanceof MoneyComputationError, `wrong error type: ${err}`);
      assert.equal(err.code, 'tax_not_configured');
      return true;
    },
    'a negative state rate must error, not silently use the default (RED at base: silent 500)',
  );
});

test('T-2 the callable maps the shared guard to an explicit HttpsError', () => {
  const block = calculateTaxBlock();
  assert.match(
    block,
    /error instanceof MoneyComputationError/,
    'callable must surface MoneyComputationError explicitly (not a bare internal error)',
  );
  assert.match(
    block,
    /new HttpsError\('failed-precondition'/,
    'callable must fail closed with failed-precondition',
  );
});

test('T-2 the fail-closed guard is reachable in BOTH paths (shared resolver)', () => {
  // Charge path: the pure functions above. Callable path: structural proof that
  // the callable's only rate resolution / rounding IS those same functions.
  const block = calculateTaxBlock();
  const rateResolutionCount = (block.match(/computeTaxCents\(/g) || []).length;
  assert.equal(rateResolutionCount, 1, 'callable must call the shared resolver exactly once');
  assert.doesNotMatch(block, /defaultRate/, 'callable must not carry its own default rate');
});

// ---------------------------------------------------------------------------
// T-3 - one rounding contract, both languages: HALF AWAY FROM ZERO (matches
// Dart `num.round()`). RED at base: `Math.round(-3.5) === -3` while Dart
// `(-3.5).round() === -4` (AUD1-05).
// ---------------------------------------------------------------------------
test('T-3 roundHalfAwayFromZero matches Dart .round() on the AUD-1 table', () => {
  assert.equal(typeof roundHalfAwayFromZero, 'function', 'pinned helper must be exported');
  assert.equal(roundHalfAwayFromZero(-3.5), -4, 'Dart (-3.5).round() == -4; Math.round gives -3');
  assert.equal(roundHalfAwayFromZero(3.5), 4);
  assert.equal(roundHalfAwayFromZero(-2.5), -3, 'Dart (-2.5).round() == -3; Math.round gives -2');
  assert.equal(roundHalfAwayFromZero(2.5), 3);
  assert.equal(roundHalfAwayFromZero(-0.5), -1, 'Dart (-0.5).round() == -1; Math.round gives -0');
  assert.equal(roundHalfAwayFromZero(0.5), 1);
  assert.equal(roundHalfAwayFromZero(-0.35000000000000003), 0);
  assert.equal(roundHalfAwayFromZero(0.35000000000000003), 0);
  assert.equal(roundHalfAwayFromZero(-499.5), -500);
  assert.equal(roundHalfAwayFromZero(499.5), 500);
  assert.equal(roundHalfAwayFromZero(0), 0);
  assert.equal(roundHalfAwayFromZero(-0.25), 0, '-0 must normalize to 0');
});

test('T-3 the single implementation rounds through the pinned helper (not Math.round)', () => {
  const body = computeTaxCentsBody();
  assert.match(
    body,
    /roundHalfAwayFromZero\(/,
    'computeTaxCents must round through roundHalfAwayFromZero',
  );
  assert.doesNotMatch(
    body,
    /Math\.round\(/,
    'Math.round is banned for tax (half toward +Infinity != Dart .round())',
  );
});

test('T-3 positive charge outcomes are unchanged (money sanctuary)', () => {
  // Positive products are identical under both rules - these pins must never move.
  const config = extractClientTaxConfig(
    {clients: {'com.example.app': {stateRates: {CA: 0.0725, NY: 0.08, OR: 0, TX: 0.0625}}}},
    'com.example.app',
  );
  assert.equal(computeTaxCents(config, 2000, 'CA').taxCents, 145);
  assert.equal(computeTaxCents(config, 999, 'CA').taxCents, 72);
  assert.equal(computeTaxCents(config, 999, 'TX').taxCents, 62);
  assert.equal(computeTaxCents(config, 50, 'TX').taxCents, 3);
  assert.equal(computeTaxCents(config, 1250, 'ny').taxCents, 100);
  assert.equal(computeTaxCents(config, 2000, 'OR').taxCents, 0);
});

