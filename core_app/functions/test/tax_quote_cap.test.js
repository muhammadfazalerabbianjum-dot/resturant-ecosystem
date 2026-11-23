/**
 * p33 T-3 — TAX QUOTE CAP (caller-input guard on the quote path).
 *
 * `calculateTax` takes the client's subtotal as a QUOTE input
 * (`calculateTaxSchema` in src/index.ts). The charge path re-prices
 * everything server-side (src/index.ts:899-926), so a tampered subtotal can
 * never move money — but it could still produce an absurd QUOTE. The schema
 * therefore caps `subtotalCents` at 100_000_000 cents ($1M sanity cap).
 *
 * RED proof (red_t3_tax.txt): against the uncapped schema, parsing
 * 1_000_000_000 SUCCEEDED and this test failed. GREEN: rejected with a
 * clear error, while the cap boundary and normal inputs still parse.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {calculateTaxSchema} = require('../lib/index.js');

test('T-3 quote cap: an oversized subtotal (1_000_000_000) is REJECTED', () => {
  assert.throws(
    () => calculateTaxSchema.parse({
      subtotalCents: 1_000_000_000,
      stateCode: 'CA',
      clientId: 'com.example.app',
    }),
    /Too big: expected number to be <=100000000|maximum supported quote/i,
  );
});

test('T-3 quote cap: the cap boundary (100_000_000) still quotes', () => {
  const parsed = calculateTaxSchema.parse({
    subtotalCents: 100_000_000,
    stateCode: 'CA',
    clientId: 'com.example.app',
  });
  assert.equal(parsed.subtotalCents, 100_000_000);
  assert.equal(parsed.stateCode, 'CA');
});

test('T-3 quote cap: normal inputs below the cap are unchanged', () => {
  const parsed = calculateTaxSchema.parse({
    subtotalCents: 12_345,
    stateCode: 'tx',
    clientId: 'com.example.app',
  });
  assert.equal(parsed.subtotalCents, 12_345);
  assert.equal(parsed.stateCode, 'TX');
});
