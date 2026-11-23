/**
 * Batch 1 money-integrity tests (B1 spec Â§3.3 T-M1..T-M6).
 *
 * Runs against the compiled pure module `../lib/payment.js` (mirrors the
 * ddos.test.js pattern). Every behaviour the batch must prove is asserted
 * directly against the SERVER-side decision logic â€” no mocks, no stubs:
 *   T-M1 hostile taxCents override is ignored (server derives tax)
 *   T-M2 unknown stateCode -> failed-precondition (never $0 tax)
 *   T-M3 discountCents > subtotal / non-server promo rejected; server-computed
 *       discount only
 *   T-M4 applyPromo rejects inactive / exhausted / outside-window / already-used;
 *       idempotent per user+code (charge-time commit + retry)
 *   T-M5 currency from config per clientId; valid charged in that currency;
 *       invalid -> throw (no silent USD fallback)
 *   T-M6 money-equality still enforced in createOrder (belt-and-suspenders
 *       via verifyOrderCharge)
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MoneyComputationError,
  PromoInvalidError,
  SUPPORTED_CURRENCY_CODES,
  resolveCurrency,
  isSupportedCurrencyCode,
  extractClientTaxConfig,
  computeTaxCents,
  computeItemsSubtotalCents,
  computeAmountCents,
  normalizePromoCode,
  isPromoInWindow,
  computePromoDiscountCents,
  evaluatePromoUse,
  planPromoUsage,
  promoReasonMessage,
  verifyOrderCharge,
  buildChargeIntentMetadata,
  toFiniteIntOrNull,
  verifyMenuPricing,
  extractMenuPricingInput,
  formatOrderNumber,
  createPaymentIntentSchema,
  applyPromoSchema,
  inspectRefundedCharges,
  buildRefundRecord,
  decideOrderCancellation,
  validateDeliveryFee,
} = require('../lib/payment.js');

const supportsZeroDecimalCode = ['aed', 'sar'].includes;

/** Build a timestamp-like object the pure module accepts (toMillis). */
const ts = (epocH) => ({ toMillis: () => epocH });
// ---------------------------------------------------------------------------
// T-M1 â€” client taxCents override is IGNORED; server derives tax from
// settings/taxRates.clients[clientId].stateRates (the exact calculateTax
// lookup). A hostile `taxCents:0` must not change the charge.
// ---------------------------------------------------------------------------
test('T-M1 client taxCents:0 is ignored â€” server derives the tax', () => {
  const config = extractClientTaxConfig(
    { clients: { 'com.example.app': { stateRates: { CA: 0.0725 } } } },
    'com.example.app',
  );
  assert.deepEqual(config.stateRates, { CA: 0.0725 });
  const derived = computeTaxCents(config, 2000, 'CA');
  assert.equal(derived.taxCents, 145); // Math.round(2000 * 0.0725)

  // A hostile request body may still smuggle taxCents â€” the shared schema
  // STRIPS it (non-strict zod), so the parsed value can never reach the
  // computation. Prove the parsed charge inputs only carry server fields.
  const parsed = createPaymentIntentSchema.parse({
    items: [{ id: 'menu-burger-1', priceCents: 2000, quantity: 1 }],
    idempotencyKey: 'key-1',
    stateCode: 'CA',
    clientId: 'com.example.app',
    taxCents: 0, // hostile override — must be dropped
    discountCents: 9999999, // hostile override — must be dropped
  });
  assert.equal('taxCents' in parsed, false);
  assert.equal('discountCents' in parsed, false);
  assert.equal(parsed.stateCode, 'CA');

  // And the amount uses the server-derived 145, never the hostile 0.
  const amount = computeAmountCents({
    subtotalCents: computeItemsSubtotalCents(parsed.items),
    taxCents: derived.taxCents,
    discountCents: 0,
    tipCents: 0,
    deliveryFeeCents: 0,
  });
  assert.equal(amount, 2145);
});

test('T-M2 unknown stateCode throws MoneyComputationError â€” never $0 tax', () => {
  const config = extractClientTaxConfig(
    { clients: { 'com.example.app': { stateRates: { CA: 0.0725 } } } },
    'com.example.app',
  );
  // No stateRate for 'ZZ' and no configured defaultRate -> FAIL-CLOSED.
  assert.throws(() => computeTaxCents(config, 10000, 'ZZ'), (err) => {
    assert.ok(err instanceof MoneyComputationError);
    assert.equal(err.code, 'tax_not_configured');
    return true;
  });

  // Explicitly-configured positive default is honoured (client_config.json
  // defaultRate: 0.0 means "unset", so 0 is NOT a fallback).
  const withDefault = extractClientTaxConfig(
    { defaultRate: 0.0, clients: { 'com.example.app': { stateRates: { CA: 0.0725 } } } },
    'com.example.app',
  );
  assert.equal(withDefault.defaultRate, undefined); // 0.0 treated as unset
  assert.throws(() => computeTaxCents(withDefault, 100, 'ZZ'), MoneyComputationError);
});

test('T-M2b a state code is normalised case-insensitively (uppercased server-side)', () => {
  const config = extractClientTaxConfig(
    { clients: { 'com.example.app': { stateRates: { NY: 0.08 } } } },
    'com.example.app',
  );
  const derived = computeTaxCents(config, 1250, 'ny');
  assert.equal(derived.taxCents, 100); // Math.round(1250 * 0.08)
});
// ---------------------------------------------------------------------------
// T-M3 â€” discount is SERVER-computed only. A client discount value > subtotal
// or a non-server promo is rejected; the discount never exceeds subtotal.
// ---------------------------------------------------------------------------
test('T-M3a fixed discount is server-computed and clamped to the subtotal', () => {
  const discount = computePromoDiscountCents(
    { active: true, type: 'fixed', value: 9000, maxUses: 100, usedCount: 0 },
    5000,
  );
  assert.equal(discount, 5000); // clamped: cannot exceed the items subtotal
});

test('T-M3b percent discount uses integer math (multiply BEFORE divide) and clamps', () => {
  // 10% of 3333 = 333.3 -> floor(33330/100) = 333 (never float drift / round-up)
  const discount = computePromoDiscountCents(
    { active: true, type: 'percent', value: 10, maxUses: 100, usedCount: 0 },
    3333,
  );
  assert.equal(discount, 333);
  // 200% of subtotal clamps to the whole subtotal â€” never a negative total.
  const over = computePromoDiscountCents(
    { active: true, type: 'percent', value: 200, maxUses: 100, usedCount: 0 },
    1000,
  );
  assert.equal(over, 1000);
});

test('T-M3c a malformed / hostile promo doc yields no discount (rejected)', () => {
  // Negative value, wrong type, missing value -> server refuses.
  assert.equal(
    computePromoDiscountCents({ active: true, type: 'fixed', value: -500 }, 1000),
    null,
  );
  assert.equal(
    computePromoDiscountCents({ active: true, type: 'weird' }, 1000),
    null,
  );
  assert.equal(
    computePromoDiscountCents(null, 1000),
    null,
  );
});

test('T-M3d a non-server (unlisted) promo code is rejected â€” code_not_found', () => {
  const shortCode = normalizePromoCode('NOPE');
  assert.equal(shortCode, 'NOPE');
  const result = evaluatePromoUse({
    code: shortCode,
    promo: null, // promoCodes/NOPE does not exist
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: 1_700_000_000_000,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.reason, 'code_not_found');
});

// ---------------------------------------------------------------------------
// T-M4 â€” applyPromo evaluation: inactive / exhausted / outside-window /
// already-used rejected; idempotent per user+code at charge time.
// ---------------------------------------------------------------------------
const ACTIVE_PROMO = { active: true, type: 'fixed', value: 500, maxUses: 100, usedCount: 0 };
const NOW = 1_700_000_000_000;

test('T-M4a active in-window promo computes the server discount', () => {
  const result = evaluatePromoUse({
    code: 'SAVE5',
    promo: { ...ACTIVE_PROMO, startAt: ts(NOW - 1000), endAt: ts(NOW + 1000) },
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.deepEqual(result, { ok: true, discountCents: 500, promoCode: 'SAVE5' });
});

test('T-M4b inactive code is rejected (not_active)', () => {
  const result = evaluatePromoUse({
    code: 'OFF',
    promo: { active: false, type: 'fixed', value: 500, maxUses: 100, usedCount: 0 },
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.reason, 'not_active');
});

test('T-M4c exhausted code is rejected (exhausted)', () => {
  const result = evaluatePromoUse({
    code: 'USEDUP',
    promo: { active: true, type: 'fixed', value: 500, maxUses: 5, usedCount: 5 },
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.reason, 'exhausted');
});

test('T-M4d outside the active window is rejected (outside_window)', () => {
  const future = evaluatePromoUse({
    code: 'EARLY',
    promo: { ...ACTIVE_PROMO, startAt: ts(NOW + 999_999_999) },
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.equal(future.ok, false);
  if (!future.ok) assert.equal(future.reason, 'outside_window');

  const past = evaluatePromoUse({
    code: 'LATE',
    promo: { ...ACTIVE_PROMO, endAt: ts(NOW - 1) },
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.equal(past.ok, false);
  if (!past.ok) assert.equal(past.reason, 'outside_window');
});

test('T-M4e a code already used by THIS user is rejected (already_used)', () => {
  const result = evaluatePromoUse({
    code: 'ONCE',
    promo: ACTIVE_PROMO,
    usageExists: true,
    cartSubtotalCents: 2000,
    nowMs: NOW,
  });
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.reason, 'already_used');
});
test('T-M4f charge-time retry with the SAME idempotency key is idempotent (Law 9)', () => {
  // First charge commits usage under idempotencyKey 'key-abc'.
  const first = planPromoUsage({
    code: 'SAVE5',
    promo: ACTIVE_PROMO,
    usageExists: false,
    cartSubtotalCents: 2000,
    nowMs: NOW,
    idempotencyKey: 'key-abc',
  });
  assert.deepEqual(first, { status: 'commit', discountCents: 500 });

  // Retry (network timeout) with the SAME key + the usage doc now present:
  // the promo still applies WITHOUT a second write/decrement.
  const retry = evaluatePromoUse({
    code: 'SAVE5',
    promo: { ...ACTIVE_PROMO, usedCount: 1 },
    usageExists: true,
    cartSubtotalCents: 2000,
    nowMs: NOW,
    idempotencyKey: 'key-abc',
    usageIdempotencyKey: 'key-abc',
  });
  assert.deepEqual(retry, { ok: true, discountCents: 500, promoCode: 'SAVE5' });

  // A DIFFERENT charge attempt for the same user+code stays rejected.
  const differentKey = planPromoUsage({
    code: 'SAVE5',
    promo: { ...ACTIVE_PROMO, usedCount: 1 },
    usageExists: true,
    cartSubtotalCents: 2000,
    nowMs: NOW,
    idempotencyKey: 'key-xyz',
    usageIdempotencyKey: 'key-abc',
  });
  assert.deepEqual(differentKey, { status: 'rejected', rejectReason: 'already_used' });
});

test('T-M4g applyPromo schema rejects an oversized subtotal (hostile)', () => {
  const parsed = applyPromoSchema.safeParse({ code: 'SAVE5', cartSubtotalCents: 10_000_001 });
  assert.equal(parsed.success, false);
});

// ---------------------------------------------------------------------------
// T-M5 â€” currency comes from config per clientId; valid charged in that
// currency; invalid -> throw (no silent fallback to a default currency).
// ---------------------------------------------------------------------------
test('T-M5a allowlisted currencies resolve to lowercase Stripe code', () => {
  for (const [raw, lowercase] of [
    ['USD', 'usd'],
    ['usd', 'usd'],
    ['EUR', 'eur'],
  ]) {
    assert.equal(resolveCurrency(raw), lowercase);
  }
});

test('T-M5b missing / unsupported currency throws, never a silent fallback', () => {
  for (const bad of [undefined, null, '', 'ZZZ', 'XXX', 42, true]) {
    assert.throws(() => resolveCurrency(bad), MoneyComputationError);
  }
  // The canonical allowlist never contains lowercase (typ0 safety net).
  for (const code of SUPPORTED_CURRENCY_CODES) {
    assert.equal(code, code.toUpperCase());
  }
});

// ---------------------------------------------------------------------------
// T-M6 - money-equality enforced in createOrder (belt-and-suspenders):
// claimed total AND tax/discount must match the charged PaymentIntent.
// MONEY-1 extends the gate: stored items subtotal / tip / deliveryFee must
// match the server-stamped metadata, the status must be allowlisted, and the
// total must be internally consistent with the server re-derivation.
// ---------------------------------------------------------------------------

/** Valid base input; individual tests override single fields to tamper. */
const validCharge = (over = {}) => ({
  claimedTotalCents: 2145,
  orderTaxCents: 145,
  orderDiscountCents: 0,
  chargedAmountCents: 2145,
  chargedTaxCents: '145', // Stripe metadata is a string map
  chargedDiscountCents: '0',
  orderItems: [{ id: 'menu-burger-1', priceCents: 2000, quantity: 1 }],
  chargedItemsSubtotalCents: '2000',
  orderTipCents: 0,
  chargedTipCents: '0',
  orderDeliveryFeeCents: 0,
  chargedDeliveryFeeCents: '0',
  // BACKEND-2 (W7.4/T-4): creator binding — the charge's server-side stamp
  // and the order's creator must agree.
  chargedCreatedBy: 'user-1',
  orderCreatedBy: 'user-1',
  orderStatus: 'confirmed',
  ...over,
});

test('T-M6a matching order vs PaymentIntent passes', () => {
  assert.deepEqual(verifyOrderCharge(validCharge()), { ok: true });
});

// ---------------------------------------------------------------------------
// BACKEND-2 (W7.4/T-4, 06-P1-2) — creator binding: metadata.createdBy is
// stamped server-side from the authenticated caller and re-checked at
// confirmation. A stolen paymentIntentId can never confirm another user's
// order, and a pre-stamp intent fails closed.
// ---------------------------------------------------------------------------
test('T-CR1 buildChargeIntentMetadata stamps createdBy server-side', () => {
  const md = buildChargeIntentMetadata({
    userId: 'user-1',
    createdBy: 'user-1',
    orderId: 'ord-1',
    taxCents: 145,
    discountCents: 0,
    itemsSubtotalCents: 2000,
    tipCents: 0,
    deliveryFeeCents: 0,
    currency: 'usd',
    branchId: 'branch-9',
  });
  assert.equal(md.createdBy, 'user-1');
  assert.equal(md.userId, 'user-1');
  assert.equal(md.orderId, 'ord-1');
  assert.equal(md.taxCents, '145'); // Stripe metadata is a string map
  assert.equal(md.branchId, 'branch-9');
});

test('T-CR2 buildChargeIntentMetadata omits absent branch, zeroes orderId', () => {
  const md = buildChargeIntentMetadata({
    userId: 'user-1',
    createdBy: 'user-1',
    taxCents: 0,
    discountCents: 0,
    itemsSubtotalCents: 500,
    tipCents: 0,
    deliveryFeeCents: 0,
    currency: 'usd',
  });
  assert.equal(md.orderId, '');
  assert.equal(Object.prototype.hasOwnProperty.call(md, 'branchId'), false);
});

test('T-CR3 creator mismatch between order and charge is rejected', () => {
  const result = verifyOrderCharge(validCharge({
    orderCreatedBy: 'user-2', // someone else's order, this user's charge
  }));
  assert.equal(result.ok, false);
  assert.match(result.reason ?? '', /creator/i);
});

test('T-CR4 a PaymentIntent without the createdBy stamp fails closed', () => {
  const result = verifyOrderCharge(validCharge({ chargedCreatedBy: undefined }));
  assert.equal(result.ok, false);
  assert.match(result.reason ?? '', /creator/i);
});


test('T-M6a2 a fully loaded order (tip + deliveryFee) passes', () => {
  // 2000 items + 145 tax + 500 tip + 300 deliveryFee = 2945.
  assert.deepEqual(verifyOrderCharge(validCharge({
    claimedTotalCents: 2945,
    chargedAmountCents: 2945,
    orderTipCents: 500,
    chargedTipCents: '500',
    orderDeliveryFeeCents: 300,
    chargedDeliveryFeeCents: '300',
  })), { ok: true });
});

test('T-M6b a tampered order total is REJECTED', () => {
  const result = verifyOrderCharge(validCharge({ claimedTotalCents: 2146 })); // +1 cent
  assert.equal(result.ok, false);
});

test('T-M6c a tampered stored tax is REJECTED (belts-and-suspenders)', () => {
  const result = verifyOrderCharge(validCharge({ orderTaxCents: 0 })); // under-records tax
  assert.equal(result.ok, false);
});

test('T-M6d a tampered stored discount is REJECTED (belts-and-suspenders)', () => {
  const result = verifyOrderCharge(validCharge({ orderDiscountCents: 9999 })); // over-records
  assert.equal(result.ok, false);
});

test('T-M6e non-numeric / missing metadata is REJECTED (fail-closed)', () => {
  for (const metadata of [{}, { taxCents: 'n/a' }, null]) {
    const result = verifyOrderCharge(validCharge({
      chargedTaxCents: metadata && metadata.taxCents,
    }));
    assert.equal(result.ok, false);
  }
});

// MONEY-1 (W3.1a) additions - the extended stored-order gate:
test('T-M6g stored items below the charged metadata subtotal are REJECTED', () => {
  // The $1-for-a-$50-item attack: the stored items list cannot be re-priced
  // by the client - its subtotal must equal the server-stamped metadata.
  const result = verifyOrderCharge(validCharge({
    orderItems: [{ id: 'menu-burger-1', priceCents: 100, quantity: 1 }],
  }));
  assert.equal(result.ok, false);
  assert.match(result.reason, /Stored order items do not match/);
});

test('T-M6h a tampered stored tip is REJECTED', () => {
  const result = verifyOrderCharge(validCharge({ orderTipCents: 999 }));
  assert.equal(result.ok, false);
});

test('T-M6i a tampered stored delivery fee is REJECTED', () => {
  const result = verifyOrderCharge(validCharge({ orderDeliveryFeeCents: 999 }));
  assert.equal(result.ok, false);
});

test('T-M6j the client-sent status must be in the confirmation allowlist', () => {
  for (const status of ['delivered', 'pending', 'preparing', 'cancelled', '', undefined, null]) {
    const result = verifyOrderCharge(validCharge({ orderStatus: status }));
    assert.equal(result.ok, false, `status ${String(status)} must be rejected`);
  }
  assert.equal(verifyOrderCharge(validCharge({ orderStatus: 'confirmed' })).ok, true);
});

test('T-M6k the stored total must be internally consistent (server re-derivation)', () => {
  // Every single-field equality holds, but the parts do not add up to the
  // claimed total: 2001 + 145 - 0 + 0 + 0 != 2145 -> rejected.
  const result = verifyOrderCharge(validCharge({
    orderItems: [{ id: 'menu-burger-1', priceCents: 2001, quantity: 1 }],
    chargedItemsSubtotalCents: '2001',
  }));
  assert.equal(result.ok, false);
  assert.match(result.reason, /not internally consistent/);
});

test('T-M6f toFiniteIntOrNull handles numeric strings (Stripe metadata)', () => {
  assert.equal(toFiniteIntOrNull('145'), 145);
  assert.equal(toFiniteIntOrNull(145), 145);
  assert.equal(toFiniteIntOrNull('abc'), null);
  assert.equal(toFiniteIntOrNull(undefined), null);
});

// ---------------------------------------------------------------------------
// MONEY-1 (W3.1b) - menu cross-check: the SERVER re-prices every line from
// the `menus` collection. Client prices are CLAIMS; a mismatch fails closed
// BEFORE any Stripe call. Pure-module coverage (the emulator harness covers
// the DB-wired callable end-to-end in T-5).
// ---------------------------------------------------------------------------
const menuBurger = {
  id: 'menu-burger-1',
  name: 'Double Smashburger',
  priceCents: 2000,
  branchId: 'branch_main',
  isAvailable: true,
  modifiers: [
    {
      id: 'mod-extra',
      name: 'Extras',
      options: [
        { id: 'opt-fries', name: 'Add fries', upchargeCents: 150, isDefault: false },
      ],
    },
  ],
};

const menuDoc = (data, exists = true) => ({ exists, data: exists ? data : null });

test('T-MC1 the charge schema REQUIRES a menu item id and option ids', () => {
  const noItemId = createPaymentIntentSchema.safeParse({
    items: [{ priceCents: 2000, quantity: 1 }],
    idempotencyKey: 'key-1',
    stateCode: 'CA',
    clientId: 'com.example.app',
  });
  assert.equal(noItemId.success, false, 'an item without a menu id must not parse');

  const noOptionId = createPaymentIntentSchema.safeParse({
    items: [{
      id: 'menu-burger-1',
      priceCents: 2000,
      selectedOptions: [{ upchargeCents: 150 }],
    }],
    idempotencyKey: 'key-1',
    stateCode: 'CA',
    clientId: 'com.example.app',
  });
  assert.equal(noOptionId.success, false, 'an option without an id must not parse');

  const ok = createPaymentIntentSchema.safeParse({
    items: [{
      id: 'menu-burger-1',
      priceCents: 2000,
      quantity: 1,
      selectedOptions: [{ id: 'opt-fries', name: 'Add fries', upchargeCents: 150 }],
    }],
    idempotencyKey: 'key-1',
    stateCode: 'CA',
    clientId: 'com.example.app',
  });
  assert.equal(ok.success, true);
});

test('T-MC2 a correctly priced cart is verified with server-canonical lines', () => {
  const items = [{
    id: 'menu-burger-1',
    priceCents: 2000,
    quantity: 2,
    selectedOptions: [{ id: 'opt-fries', upchargeCents: 150 }],
  }];
  const result = verifyMenuPricing(items, [menuDoc(menuBurger)]);
  assert.equal(result.ok, true);
  assert.equal(result.itemsSubtotalCents, (2000 + 150) * 2);
  assert.equal(result.branchId, 'branch_main');
  const canonical = result.canonicalItems[0];
  assert.equal(canonical.item.priceCents, 2000); // SERVER price, not client's
  assert.equal(canonical.item.name, 'Double Smashburger'); // from the menu doc
  assert.equal(canonical.selectedOptions[0].upchargeCents, 150); // SERVER upcharge
  assert.equal(canonical.selectedOptions[0].name, 'Add fries');
  assert.equal(canonical.quantity, 2);
});

test('T-MC3 a client price below the menu price is REJECTED (T-1)', () => {
  const items = [{ id: 'menu-burger-1', priceCents: 100, quantity: 1 }];
  const result = verifyMenuPricing(items, [menuDoc(menuBurger)]);
  assert.equal(result.ok, false);
  assert.match(result.reason, /does not match the current menu price/);
});

test('T-MC4 unknown / disabled / invalid menu docs are REJECTED', () => {
  const items = [{ id: 'menu-burger-1', priceCents: 2000, quantity: 1 }];
  assert.match(
    verifyMenuPricing(items, [menuDoc(menuBurger, false)]).reason,
    /does not exist/,
  );
  assert.match(
    verifyMenuPricing(items, [menuDoc({ ...menuBurger, isAvailable: false })]).reason,
    /unavailable/,
  );
  assert.match(
    verifyMenuPricing(items, [menuDoc({ ...menuBurger, branchId: '' })]).reason,
    /not associated with a branch/,
  );
  assert.match(
    verifyMenuPricing(items, [menuDoc({ ...menuBurger, priceCents: 'free' })]).reason,
    /no valid server price/,
  );
});

test('T-MC5 an unknown option id or a tampered upcharge is REJECTED', () => {
  const unknownOption = [{
    id: 'menu-burger-1',
    priceCents: 2000,
    quantity: 1,
    selectedOptions: [{ id: 'opt-caviar', upchargeCents: 150 }],
  }];
  assert.match(
    verifyMenuPricing(unknownOption, [menuDoc(menuBurger)]).reason,
    /is not offered by menu item/,
  );

  // Client hides the upcharge (0 instead of 150) -> claimed != server price.
  const underpriced = [{
    id: 'menu-burger-1',
    priceCents: 2000,
    quantity: 1,
    selectedOptions: [{ id: 'opt-fries', upchargeCents: 0 }],
  }];
  assert.match(
    verifyMenuPricing(underpriced, [menuDoc(menuBurger)]).reason,
    /does not match the current menu price/,
  );
});

test('T-MC6 a multi-branch order is REJECTED (branch context must be single)', () => {
  const items = [
    { id: 'menu-burger-1', priceCents: 2000, quantity: 1 },
    { id: 'menu-pizza-1', priceCents: 2000, quantity: 1 },
  ];
  const docs = [
    menuDoc(menuBurger),
    menuDoc({ ...menuBurger, id: 'menu-pizza-1', branchId: 'branch_other' }),
  ];
  assert.match(verifyMenuPricing(items, docs).reason, /different branches/);
});

test('T-MC7 extractMenuPricingInput normalises nested lines; malformed fails', () => {
  // The shape `OrderModel.toJson()` produces (nested CartItemModel JSON):
  const nested = [{
    item: { id: 'menu-burger-1', priceCents: 2000 },
    quantity: 2,
    selectedOptions: [{ id: 'opt-fries', name: 'Add fries', upchargeCents: 150 }],
  }];
  assert.deepEqual(extractMenuPricingInput(nested), [{
    id: 'menu-burger-1',
    quantity: 2,
    priceCents: 2000,
    selectedOptions: [{ id: 'opt-fries', upchargeCents: 150 }],
  }]);

  // Fail-closed shapes: no id anywhere, non-array input, malformed options.
  assert.equal(extractMenuPricingInput([{ item: { priceCents: 1 } }]), null);
  assert.equal(extractMenuPricingInput('nope'), null);
  assert.equal(extractMenuPricingInput([{ id: 'x', selectedOptions: 'nope' }]), null);
  assert.equal(extractMenuPricingInput([{ id: 'x', selectedOptions: [{}] }]), null);
  assert.equal(extractMenuPricingInput([{ id: 'x', selectedOptions: [null] }]), null);
});

test('T-MC8 computeItemsSubtotalCents prices the nested stored shape (never 0)', () => {
  const nested = [{
    item: { id: 'menu-burger-1', priceCents: 2000 },
    quantity: 2,
    selectedOptions: [{ upchargeCents: 150 }],
  }];
  assert.equal(computeItemsSubtotalCents(nested), (2000 + 150) * 2);
  // Flat charge shape still priced identically.
  assert.equal(computeItemsSubtotalCents([{ id: 'x', priceCents: 500, quantity: 1 }]), 500);
});

test('T-MC9 server order numbers match the client OrderNumberService format', () => {
  assert.equal(formatOrderNumber(1), '#0001');
  assert.equal(formatOrderNumber(42), '#0042');
  assert.equal(formatOrderNumber(12345), '#12345');
  assert.throws(() => formatOrderNumber(-1), MoneyComputationError);
  assert.throws(() => formatOrderNumber(1.5), MoneyComputationError);
});

// ---------------------------------------------------------------------------
// MONEY-2 (batch T-1): refund-replay guard — a refunded PaymentIntent charge
// MUST be detected so createOrder can fail closed (a refund does NOT change the
// PI `status`, so the status check alone is not enough). The Stripe `charges`
// payload is plain JSON in these tests (unit); the emulator + RELEASE-2 smoke
// cover the live boundary.
// ---------------------------------------------------------------------------

test('MONEY-2 T-1 inspectRefundedCharges detects `refunded: true` charges', () => {
  const result = inspectRefundedCharges([{
    id: 'ch_1',
    refunded: true,
    amount_refunded: 2500,
    refunds: { data: [{ id: 're_1', amount: 2500 }] },
  }]);
  assert.equal(result.hasRefundedCharge, true);
  assert.equal(result.refundedAmountCents, 2500);
  assert.match(result.reason, /refunded/i);
});

test('MONEY-2 T-1 inspectRefundedCharges detects partial refunds (amount_refunded > 0)', () => {
  const result = inspectRefundedCharges([{
    id: 'ch_1',
    refunded: false,
    amount_refunded: 500,
    refunds: null,
  }]);
  assert.equal(result.hasRefundedCharge, true);
  assert.equal(result.refundedAmountCents, 500);
});

test('MONEY-2 T-1 inspectRefundedCharges detects a non-empty refunds list', () => {
  const result = inspectRefundedCharges([{
    id: 'ch_1',
    refunded: false,
    amount_refunded: 0,
    refunds: { data: [{ id: 're_1', amount: 1200 }] },
  }]);
  assert.equal(result.hasRefundedCharge, true);
  assert.equal(result.refundedAmountCents, 1200);
});

test('MONEY-2 T-1 inspectRefundedCharges passes a fully paid (unrefunded) charge', () => {
  const clean = inspectRefundedCharges([{
    id: 'ch_1',
    refunded: false,
    amount_refunded: 0,
    refunds: null,
  }]);
  assert.equal(clean.hasRefundedCharge, false);
  assert.equal(clean.refundedAmountCents, null);
  assert.equal(clean.reason, null);
  // Empty / malformed lists are also NOT a refund (nothing to reject on).
  assert.equal(inspectRefundedCharges([]).hasRefundedCharge, false);
  assert.equal(inspectRefundedCharges('not-a-list').hasRefundedCharge, false);
  assert.equal(inspectRefundedCharges([null, 42]).hasRefundedCharge, false);
});

test('MONEY-2 T-1 buildRefundRecord persists the minimal documented schema', () => {
  const at = new Date('2026-09-01T00:00:00.000Z');
  const record = buildRefundRecord({
    amountCents: 2500,
    reason: 'already_refunded_replay_guard',
    at,
  });
  assert.deepEqual(record, { amount: 2500, reason: 'already_refunded_replay_guard', at, refundId: null });
  // A present refundId is kept; empty/missing is normalized to null.
  const withRefund = buildRefundRecord({ amountCents: 900, reason: 'cancelled_by_customer', at, refundId: 're_123' });
  assert.equal(withRefund.refundId, 're_123');
  assert.equal(buildRefundRecord({ amountCents: null, reason: 'cancelled_by_customer', at, refundId: '' }).refundId, null);
  assert.equal(buildRefundRecord({ amountCents: null, reason: 'x', at }).amount, null);
});

// ---------------------------------------------------------------------------
// MONEY-2 (batch "cancelOrder unit cases"): the pure cancellation-state gate
// shared by the cancelOrder callable. pending/confirmed -> cancel;
// cancelled -> already_cancelled (idempotent OK, no double refund); everything
// else (delivered/preparing/ready/…/missing) -> reject.
// ---------------------------------------------------------------------------

test('MONEY-2 cancelOrder gate: pending and confirmed cancel, cancelled replays OK', () => {
  assert.deepEqual(decideOrderCancellation('pending'), { action: 'cancel', status: 'pending' });
  assert.deepEqual(decideOrderCancellation('confirmed'), { action: 'cancel', status: 'confirmed' });
  assert.deepEqual(decideOrderCancellation('cancelled'), { action: 'already_cancelled' });
});

test('MONEY-2 cancelOrder gate: delivered/preparing/unset statuses are rejected', () => {
  assert.deepEqual(decideOrderCancellation('delivered'), { action: 'reject', status: 'delivered' });
  assert.deepEqual(decideOrderCancellation('preparing'), { action: 'reject', status: 'preparing' });
  assert.deepEqual(decideOrderCancellation('ready'), { action: 'reject', status: 'ready' });
  assert.deepEqual(decideOrderCancellation('pickedUp'), { action: 'reject', status: 'pickedUp' });
  assert.equal(decideOrderCancellation(undefined).action, 'reject');
  assert.equal(decideOrderCancellation(null).action, 'reject');
  assert.equal(decideOrderCancellation('').action, 'reject');
});

// ---------------------------------------------------------------------------
// MONEY-3 (batch T-6): server-authoritative delivery fee — a differing client
// claim is clamped to the server config value (a hostile client can neither
// raise nor lower the fee).
// ---------------------------------------------------------------------------

test('MONEY-3 T-6 validateDeliveryFee clamps a tampered fee to the server value', () => {
  // Client claims 500, server says 299 -> clamp to 299 (charged amount).
  assert.deepEqual(validateDeliveryFee(500, 299), { deliveryFeeCents: 299, clamped: true });
  // Client claims 100, server says 299 -> clamp UP to 299.
  assert.deepEqual(validateDeliveryFee(100, 299), { deliveryFeeCents: 299, clamped: true });
});

test('MONEY-3 T-6 validateDeliveryFee passes an exact-match fee unchanged', () => {
  assert.deepEqual(validateDeliveryFee(299, 299), { deliveryFeeCents: 299, clamped: false });
});

test('MONEY-3 T-6 validateDeliveryFee: no server fee -> client claim used as-is', () => {
  // A config doc without deliveryFeeCents (legacy backend) -> nothing to clamp to.
  assert.deepEqual(validateDeliveryFee(500, undefined), { deliveryFeeCents: 500, clamped: false });
  assert.deepEqual(validateDeliveryFee(0, null), { deliveryFeeCents: 0, clamped: false });
  assert.deepEqual(validateDeliveryFee(0, 'nope'), { deliveryFeeCents: 0, clamped: false });
});

test('MONEY-3 T-6 validateDeliveryFee sanitizes malformed inputs (never negative)', () => {
  assert.deepEqual(validateDeliveryFee(-50, 299), { deliveryFeeCents: 299, clamped: true });
  assert.deepEqual(validateDeliveryFee('boom', 299), { deliveryFeeCents: 299, clamped: true });
  assert.deepEqual(validateDeliveryFee(undefined, 299), { deliveryFeeCents: 299, clamped: true });
});

// ---------------------------------------------------------------------------
// PERF-10 T-8 mutant-kill pins (tool_archive/perf2_cited/tool_perf2/t78_mutants/manifest.json).
// These four boundaries were UNTESTED by the suites above — the mutants
// M-TS01 / M-TS02 / M-TS07 / M-TS13 survived a green run. Each test below
// FAILS with its mutant applied (see tool_perf2/t78_logs/t78_mutants/*.out.log).
// ---------------------------------------------------------------------------

// KILLS M-TS01 (`stateRate >= 0` -> `stateRate > 0`): a configured 0%
// state rate is a VALID rate — a tax-free jurisdiction must not be
// reclassified as `tax_not_configured` (fail-closed would then reject
// every legitimate order in that state).
test('MONEY-4 a configured 0% state rate is valid (tax-free, no throw)', () => {
  const config = extractClientTaxConfig(
    { clients: { 'com.example.app': { stateRates: { OR: 0 } } } },
    'com.example.app',
  );
  const derived = computeTaxCents(config, 2000, 'OR');
  assert.equal(derived.rate, 0);
  assert.equal(derived.taxCents, 0);
  // 0% tax means the customer pays the full subtotal — not a $0 charge and
  // not a failed-precondition.
  assert.equal(
    computeAmountCents({
      subtotalCents: 2000,
      taxCents: derived.taxCents,
      discountCents: 0,
      tipCents: 0,
      deliveryFeeCents: 0,
    }),
    2000,
  );
});

// KILLS M-TS02 (`input.taxCents -` -> `input.taxCents +`): the server-derived
// promo discount must be SUBTRACTED. A sign flip over-charges every customer
// by exactly the discount.
test('MONEY-4 computeAmountCents SUBTRACTS the server discount', () => {
  assert.equal(
    computeAmountCents({
      subtotalCents: 3000,
      taxCents: 217,
      discountCents: 300,
      tipCents: 0,
      deliveryFeeCents: 0,
    }),
    2917, // 3000 + 217 - 300
  );
  // ...and the discount is still bounded below zero (never a negative charge).
  assert.equal(
    computeAmountCents({
      subtotalCents: 100,
      taxCents: 0,
      discountCents: 500,
      tipCents: 0,
      deliveryFeeCents: 0,
    }),
    0,
  );
});

// KILLS M-TS13 (`serverFeeCents >= 0 ?` -> `serverFeeCents > 0 ?`): a
// server-configured FREE delivery (fee exactly 0) is a clamp TARGET, so a
// hostile client claim of 500 must be forced to 0 — never charged.
test('MONEY-4 validateDeliveryFee clamps to a server fee of exactly 0', () => {
  assert.deepEqual(validateDeliveryFee(500, 0), {
    deliveryFeeCents: 0,
    clamped: true,
  });
  assert.deepEqual(validateDeliveryFee(0, 0), {
    deliveryFeeCents: 0,
    clamped: false,
  });
});

// KILLS M-TS07 (`chargeCreator === null || chargeCreator.length === 0 ||` ->
// `false ||`): the creator stamp must be NON-EMPTY. An empty stamp cannot
// prove creatorship, so the pair fails closed instead of confirming.
test('MONEY-4 an unstamped (empty) charge creator fails closed', () => {
  const result = verifyOrderCharge(
    validCharge({ chargedCreatedBy: '', orderCreatedBy: '' }),
  );
  assert.equal(result.ok, false);
  assert.match(result.reason, /creator/);
});
