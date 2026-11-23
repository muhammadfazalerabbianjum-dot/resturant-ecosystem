/**
 * P2-1 — the cash callables' WIRING, read off the shipped source.
 *
 * The builders are proven in `cash_sale.test.js`; this file proves the things a
 * refactor silently drops and no unit test would notice:
 *
 *   K-1 both callables enforce App Check and require an authenticated caller
 *   K-2 taking cash needs `payment.take`, reversing needs `payment.reverse`
 *   K-3 the tenant comes from the CLAIM, never from the payload
 *   K-4 no client-supplied money or identity is trusted
 *   K-5 the order and its sale row commit together, in one transaction
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');

const SOURCE = readFileSync(join(__dirname, '..', 'src', 'index.ts'), 'utf8');

/** The body of one callable, from its declaration to the next top-level export. */
function callableBody(name) {
  const start = SOURCE.indexOf(`export const ${name} = onCall(`);
  assert.notEqual(start, -1, `expected ${name} to exist`);
  const next = SOURCE.indexOf('\nexport ', start + 10);
  return SOURCE.slice(start, next === -1 ? undefined : next);
}

test('K-1 both callables enforce App Check and auth before anything else', () => {
  for (const name of ['createCashOrder', 'voidCashSale']) {
    const body = callableBody(name);
    const appCheckAt = body.indexOf(`enforceAppCheck(request, '${name}')`);
    const authAt = body.indexOf("if (!request.auth)");
    const gateAt = body.indexOf('assertCapability(');
    assert.notEqual(appCheckAt, -1, `${name} must enforce App Check`);
    assert.notEqual(authAt, -1, `${name} must require auth`);
    assert.ok(appCheckAt < authAt && authAt < gateAt, `${name}: App Check, then auth, then the gate`);
  }
});

test('K-2 taking cash needs payment.take; reversing needs payment.reverse', () => {
  assert.match(callableBody('createCashOrder'), /assertCapability\(request\.auth, 'payment\.take'\)/);
  assert.match(callableBody('voidCashSale'), /assertCapability\(request\.auth, 'payment\.reverse'\)/);
});

test('K-3 the tenant comes from the verified claim, never the payload', () => {
  for (const name of ['createCashOrder', 'voidCashSale']) {
    const body = callableBody(name);
    assert.match(
        body,
        /tenantId: requireTenantClaim\(request\.auth\.token\)/,
        `${name} must derive the tenant from the token`,
    );
  }
  // The schema deliberately has no tenant field to smuggle.
  const schemaStart = SOURCE.indexOf('export const createCashOrderSchema = z.object({');
  const schemaEnd = SOURCE.indexOf('});', schemaStart);
  assert.equal(
      /tenantId|totalCents|taxCents|branchId|customerId/.test(
          SOURCE.slice(schemaStart, schemaEnd),
      ),
      false,
      'the payload must not accept a tenant, total, tax, branch or customer',
  );
});

test('K-4 no client-supplied money is trusted', () => {
  // The core derives subtotal, tax and total from menus + settings. A read of
  // `payload.totalCents` / `payload.taxCents` would be the break.
  const core = SOURCE.slice(
      SOURCE.indexOf('export async function createCashOrderCore('),
      SOURCE.indexOf('export const createCashOrder = onCall('),
  );
  assert.equal(/payload\.(totalCents|taxCents|taxRate|subtotalCents|itemsSubtotalCents)/.test(core), false);
  assert.match(core, /verifyMenuPricing\(/, 'lines are re-priced from the menu');
  assert.match(core, /resolveChargeTaxAndPromo\(/, 'tax comes from the charge seam');
  assert.match(core, /commitOrderWithLedger\(/, 'order + row commit together');
});

test('K-5 a void commits the reversal and the order patch in one transaction', () => {
  const core = SOURCE.slice(
      SOURCE.indexOf('export async function voidCashSaleCore('),
      SOURCE.indexOf('export const voidCashSale = onCall('),
  );
  assert.match(core, /commitVoidWithReversal\(/);
  assert.match(core, /orderData\.tenantId !== input\.tenantId/, 'cross-tenant is refused');
  assert.match(core, /sale_\$\{input\.orderId\}/, 'the reversal addresses the sale row');
});
