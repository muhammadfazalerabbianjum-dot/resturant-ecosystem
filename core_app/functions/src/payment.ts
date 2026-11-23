/**
 * Server-authoritative money computation (Batch 1 — Money integrity + currency).
 *
 * PURE module (mirrors the `ddos.ts` test pattern): no Firestore, no Stripe,
 * no `firebase-functions` imports — every function is deterministic and
 * unit-testable. `index.ts` wires these helpers to the real Admin SDK / Stripe.
 *
 * Design law for this module:
 *  - The SERVER is the only authority for tax, discount and currency.
 *  - Fail-closed: an unconfigured state/currency/promo is an error, never a
 *    silent $0 tax, a guessed currency, or an unvalidated discount.
 *  - Integer money only. Percentages multiply BEFORE dividing (no float drift).
 */
import {z} from 'zod';

// ----------------------------------------------------------------------------
// Errors (mapped to HttpsError by index.ts)
// ----------------------------------------------------------------------------

export class MoneyComputationError extends Error {
  constructor(
    readonly code: 'tax_not_configured' | 'unsupported_currency',
    message: string,
  ) {
    super(message);
    this.name = 'MoneyComputationError';
  }
}

export class PromoInvalidError extends Error {
  constructor(
    readonly reason: PromoRejectReason,
    message: string,
  ) {
    super(message);
    this.name = 'PromoInvalidError';
  }
}

// ----------------------------------------------------------------------------
// Currency (config-driven, allowlisted, lowercase ISO-4217 for Stripe)
// ----------------------------------------------------------------------------

/**
 * Canonical UPPERCASE ISO-4217 allowlist. The canonical form is stored
 * uppercase (matching how `settings/restaurantConfig.currency` stores the
 * canonical code); Stripe requires the lowercase code, so `resolveCurrency`
 * normalises on the way out. Keeping only uppercase literals in source also
 * guarantees the hardcoded lowercase currency can never leak back into
 * functions/src (proof gate: case-sensitive grep for the old literal = 0).
 */
export const SUPPORTED_CURRENCY_CODES: readonly string[] = [
  'USD',
  'AED',
  'SAR',
  'EUR',
  'GBP',
  'CAD',
  'AUD',
];

export function isSupportedCurrencyCode(raw: unknown): boolean {
  if (typeof raw !== 'string' || raw.trim().length === 0) return false;
  const upper = raw.trim().toUpperCase();
  return (SUPPORTED_CURRENCY_CODES as readonly string[]).includes(upper);
}

/**
 * Resolves + validates a config-supplied currency code. Throws
 * MoneyComputationError (never silently falls back to a default currency) when
 * the value is missing or outside the allowlist.
 */
export function resolveCurrency(raw: unknown): string {
  if (!isSupportedCurrencyCode(raw)) {
    throw new MoneyComputationError(
        'unsupported_currency',
        'Currency not configured or unsupported for this client',
    );
  }
  return (raw as string).trim().toLowerCase();
}
// ----------------------------------------------------------------------------
// Tax — THE single server lookup, shared by the `calculateTax` callable AND
// the charge path (FIX-B4 TAX-1: one implementation):
//   settings/taxRates.clients[clientId].stateRates[stateCode]
//   -> fallback client defaultRate / doc defaultRate (must be > 0 and <= 1;
//      the doc-level fallback applies only to a KNOWN client row)
//   -> else fail-closed (NEVER $0 / never a silent guessed rate; the error
//      names the client so an unknown tenant is visible at the call site)
// ----------------------------------------------------------------------------

export interface TaxConfig {
  /**
   * Per-state rates from settings/taxRates.clients[clientId].stateRates.
   * FIX-B4 T-2: every CONFIGURED entry is kept verbatim (keys uppercased,
   * values untouched even when out of range) so `computeTaxCents` can tell
   * "mapped to an invalid rate" (throw) apart from "not mapped" (fallback) —
   * dropping the entry would silently fall back to another rate (AUD1-04).
   */
  stateRates?: Record<string, number>;
  /**
   * Explicitly configured default rate (client-scoped or doc top-level).
   * Schema convention: `0` means "no default configured" (client_config.json
   * tax.defaultRate: 0.0), so a non-positive value is treated as unset.
   */
  defaultRate?: number;
  /** Per-client currency override (settings/taxRates). */
  currency?: string;
  /** The tenant this config was extracted for — fail-closed errors name it. */
  clientId?: string;
}

export function extractClientTaxConfig(docData: unknown, clientId: string): TaxConfig {
  const clients = (docData as { clients?: Record<string, unknown> } | null)?.clients;
  const client = (clients ?? {})[clientId] as
    | { stateRates?: unknown; defaultRate?: unknown; currency?: unknown }
    | null
    | undefined;
  const root = docData as Record<string, unknown> | null | undefined;

  // FIX-B4 T-2 (AUD1-04): the doc-level default rate applies ONLY once the
  // tenant row exists. An UNKNOWN clientId gets no fallback at all — charging
  // a rate resolved from the doc for a tenant we could not identify is the
  // silent-default failure mode this fix removes; computeTaxCents raises the
  // fail-closed error (naming the client) instead.
  let defaultRate: number | undefined;
  if (
    typeof client?.defaultRate === 'number' &&
    Number.isFinite(client.defaultRate) &&
    client.defaultRate > 0
  ) {
    defaultRate = client.defaultRate;
  } else if (
    client !== null &&
    client !== undefined &&
    typeof root?.defaultRate === 'number' &&
    Number.isFinite(root.defaultRate) &&
    root.defaultRate > 0
  ) {
    defaultRate = root.defaultRate;
  }

  let currency: string | undefined;
  const clientCurrency = client?.currency;
  if (typeof clientCurrency === 'string' && clientCurrency.trim().length > 0) {
    currency = clientCurrency;
  } else {
    const rootCurrency = root?.currency;
    if (typeof rootCurrency === 'string' && rootCurrency.trim().length > 0) {
      currency = rootCurrency;
    }
  }

  const rawStateRates = client?.stateRates;
  let stateRates: Record<string, number> | undefined;
  if (rawStateRates !== null && typeof rawStateRates === 'object' &&
      !Array.isArray(rawStateRates)) {
    const cleaned: Record<string, number> = {};
    for (const [state, rate] of Object.entries(rawStateRates as Record<string, unknown>)) {
      // FIX-B4 T-2: keep every configured state — a non-numeric value is kept
      // as NaN — so an invalid CONFIGURED rate throws at resolve time instead
      // of being dropped and silently replaced by another rate. Range
      // validation lives in computeTaxCents (the single implementation).
      cleaned[state.toUpperCase()] = typeof rate === 'number' ? rate : NaN;
    }
    if (Object.keys(cleaned).length > 0) stateRates = cleaned;
  }

  return {stateRates, defaultRate, currency, clientId};
}

/**
 * FIX-B4 T-3 (AUD1-05): the pinned rounding contract for integer-cent tax —
 * HALF AWAY FROM ZERO, exactly like Dart's `num.round()` (the display-side
 * authority in `packages/core` TaxService). `Math.round` rounds halves toward
 * +Infinity (`Math.round(-3.5) === -3` while Dart `(-3.5).round() === -4`),
 * so it is BANNED for tax. Positive products are byte-identical under both
 * rules (money sanctuary §0.7); only negative halves change.
 */
export function roundHalfAwayFromZero(value: number): number {
  const rounded = Math.sign(value) * Math.round(Math.abs(value));
  return rounded === 0 ? 0 : rounded; // normalize -0 to 0
}

/**
 * Server-derived tax for a charge — THE single tax implementation (FIX-B4
 * TAX-1): the charge path (createPaymentIntent) AND the `calculateTax`
 * callable both delegate here, so the fail-closed guards below are reachable
 * in BOTH paths. An unmapped state, an out-of-range configured rate, an
 * unknown client, or a negative subtotal is a FAILED-PRECONDITION, never a
 * silent rate guess or a negative/zero tax (T-M2 / T-2).
 */
export function computeTaxCents(
    config: TaxConfig,
    subtotalCents: number,
    stateCode: string,
): { taxCents: number; rate: number } {
  const normalizedState = stateCode.toUpperCase();
  const tenant = config.clientId ?? 'unknown client';

  // FIX-B4 T-2/T-4: integer, NON-NEGATIVE subtotal only — a negative subtotal
  // fails closed instead of rounding through to a negative or zero tax.
  if (!Number.isSafeInteger(subtotalCents) || subtotalCents < 0) {
    throw new MoneyComputationError(
        'tax_not_configured',
        `Subtotal must be a non-negative integer for client: ${tenant}`,
    );
  }

  const stateRates = config.stateRates;
  let rate: number;
  if (
    stateRates !== undefined &&
    Object.prototype.hasOwnProperty.call(stateRates, normalizedState)
  ) {
    // The state IS configured: validate the configured value itself. An
    // out-of-range or non-numeric rate is an ERROR — falling back to another
    // rate here would be the unreachable-guard defect (AUD1-04).
    const stateRate = stateRates[normalizedState];
    if (
      typeof stateRate !== 'number' ||
      !Number.isFinite(stateRate) ||
      stateRate < 0 ||
      stateRate > 1
    ) {
      throw new MoneyComputationError(
          'tax_not_configured',
          `Tax rate out of range for state: ${normalizedState} (client: ${tenant})`,
      );
    }
    rate = stateRate;
  } else if (
    typeof config.defaultRate === 'number' &&
    Number.isFinite(config.defaultRate) &&
    config.defaultRate >= 0 &&
    config.defaultRate <= 1
  ) {
    rate = config.defaultRate;
  } else {
    throw new MoneyComputationError(
        'tax_not_configured',
        `Tax rate not configured for client: ${tenant}, state: ${normalizedState}`,
    );
  }

  // FIX-B4 T-3: HALF AWAY FROM ZERO via the pinned helper — byte-identical to
  // Dart num.round(); `Math.round` is banned for tax (AUD1-05).
  const taxCents = roundHalfAwayFromZero(subtotalCents * rate);
  if (!Number.isSafeInteger(taxCents) || taxCents < 0) {
    throw new MoneyComputationError(
        'tax_not_configured',
        `Tax rate not configured for state: ${normalizedState}`,
    );
  }
  return {taxCents, rate};
}

// ----------------------------------------------------------------------------
// Items subtotal — flat charge lines AND the nested stored-order shape
// (CartItemModel JSON: {item:{priceCents}, quantity, selectedOptions}). Never
// trusts a client total; every price is read field-by-field from the line.
// ----------------------------------------------------------------------------

export function computeItemsSubtotalCents(items: unknown): number {
  if (!Array.isArray(items)) return 0;
  return items.reduce((sum: number, item: unknown) => {
    const it =
        item as {
      priceCents?: unknown;
      quantity?: unknown;
      item?: {priceCents?: unknown} | null;
      selectedOptions?: unknown;
    } | null;
    const flatPrice = it?.priceCents;
    const nestedPrice = it?.item?.priceCents;
    const unitPrice =
      typeof flatPrice === 'number' && Number.isFinite(flatPrice) ? flatPrice :
      typeof nestedPrice === 'number' && Number.isFinite(nestedPrice) ? nestedPrice : 0;
    const quantity: number = typeof it?.quantity === 'number' ? it.quantity : 1;
    let upcharges = 0;
    if (Array.isArray(it?.selectedOptions)) {
      for (const opt of it.selectedOptions as unknown[]) {
        const o = opt as { upchargeCents?: unknown } | null;
        if (typeof o?.upchargeCents === 'number' && Number.isFinite(o.upchargeCents)) {
          upcharges += o.upchargeCents;
        }
      }
    }
    return sum + (unitPrice + upcharges) * quantity;
  }, 0);
}

export function computeAmountCents(input: {
  subtotalCents: number;
  taxCents: number;
  discountCents: number;
  tipCents: number;
  deliveryFeeCents: number;
}): number {
  const raw =
    input.subtotalCents +
    input.taxCents -
    input.discountCents +
    input.tipCents +
    input.deliveryFeeCents;
  if (!Number.isSafeInteger(raw)) {
    throw new MoneyComputationError('tax_not_configured', 'Charge amount is out of range');
  }
  return raw <= 0 ? 0 : raw;
}
// ----------------------------------------------------------------------------
// Promo codes — validation + discount are decided ONLY by the server
// ----------------------------------------------------------------------------

export type PromoRejectReason =
  | 'code_not_found'
  | 'not_active'
  | 'outside_window'
  | 'exhausted'
  | 'already_used';

export type PromoEvaluateResult =
  | { ok: true; discountCents: number; promoCode: string }
  | { ok: false; reason: PromoRejectReason };

export function normalizePromoCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim().toUpperCase();
  return trimmed.length > 0 ? trimmed : null;
}

function toFiniteInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) {
    const n = Number(value.trim());
    if (Number.isSafeInteger(n)) return n;
  }
  return fallback;
}

/** Firestore Timestamp, Date, epoch-ms or ISO string -> epoch ms, else null. */
export function toEpochMs(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    const t = Date.parse(value.trim());
    return Number.isFinite(t) ? t : null;
  }
  if (
    value !== null &&
    typeof value === 'object' &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    const ms = (value as { toMillis: () => unknown }).toMillis();
    return typeof ms === 'number' && Number.isFinite(ms) ? ms : null;
  }
  return null;
}

export function isPromoInWindow(promo: unknown, nowMs: number): boolean {
  if (promo === null || typeof promo !== 'object') return false;
  const p = promo as Record<string, unknown>;
  const startMs = toEpochMs(p['startAt']);
  const endMs = toEpochMs(p['endAt']);
  if (startMs !== null && nowMs < startMs) return false;
  if (endMs !== null && nowMs > endMs) return false;
  return true;
}

/**
 * Server-computed discount for a validated promo doc, clamped to the subtotal
 * so a promo can never discount more than the items cost (T-M3). Returns null
 * when the doc is malformed (negative value, wrong type) -> caller rejects.
 */
export function computePromoDiscountCents(
    promo: unknown,
    cartSubtotalCents: number,
): number | null {
  if (promo === null || typeof promo !== 'object') return null;
  const p = promo as Record<string, unknown>;
  const rawType = p['type'];
  if (rawType !== 'percent' && rawType !== 'fixed') return null; // fail-closed on unknown type
  const isPercent = rawType === 'percent';
  const value = toFiniteInt(p['value'], 0);
  if (value < 0 || value > 1_000_000) return null;
  const discount = isPercent ?
    Math.floor((Math.max(0, cartSubtotalCents) * value) / 100) :
    value;
  const clamped = Math.min(discount, Math.max(0, cartSubtotalCents));
  return Number.isSafeInteger(clamped) && clamped >= 0 ? clamped : null;
}
export interface PromoEvaluationContext {
  /** Normalised UPPERCASE code (e.g. 'SAVE10'). */
  code: string;
  /** promoCodes/{code} data, or null for a miss. */
  promo: unknown;
  /** promo_usage/{code}_{userId} already exists? */
  usageExists: boolean;
  cartSubtotalCents: number;
  nowMs: number;
  /**
   * Charge-time idempotency: when the usage doc already exists BUT was recorded
   * under the same idempotency key (a retry after a timeout), the use is
   * accepted WITHOUT a second write/incr (Law 9). A different key means the
   * user genuinely already redeemed the code -> already_used.
   */
  idempotencyKey?: string;
  /** idempotencyKey stored on the existing usage doc. */
  usageIdempotencyKey?: string;
}

export function evaluatePromoUse(ctx: PromoEvaluationContext): PromoEvaluateResult {
  const fail = (reason: PromoRejectReason): PromoEvaluateResult => ({ok: false, reason});

  if (ctx.promo === null || typeof ctx.promo !== 'object') return fail('code_not_found');
  const promo = ctx.promo as Record<string, unknown>;
  if (promo['active'] !== true) return fail('not_active');
  if (!isPromoInWindow(promo, ctx.nowMs)) return fail('outside_window');

  const maxUses = toFiniteInt(promo['maxUses'], 1);
  const usedCount = toFiniteInt(promo['usedCount'], 0);
  if (usedCount >= maxUses) return fail('exhausted');

  if (ctx.usageExists) {
    if (ctx.idempotencyKey != null && ctx.usageIdempotencyKey === ctx.idempotencyKey) {
      // Idempotent retry: usage was already committed by THIS charge attempt.
      const discount = computePromoDiscountCents(promo, ctx.cartSubtotalCents);
      if (discount === null) return fail('not_active');
      return {ok: true, discountCents: discount, promoCode: ctx.code};
    }
    return fail('already_used');
  }

  const discount = computePromoDiscountCents(promo, ctx.cartSubtotalCents);
  if (discount === null) return fail('not_active');
  return {ok: true, discountCents: discount, promoCode: ctx.code};
}

/**
 * Charge-time plan: same evaluation as the display callable, plus whether the
 * transaction must WRITE the idempotent usage doc (commit) or skip it
 * (idempotent: already recorded by an identical retry).
 */
export type PromoUsagePlan =
  | { status: 'commit'; discountCents: number }
  | { status: 'idempotent'; discountCents: number }
  | { status: 'rejected'; rejectReason: PromoRejectReason };

export function planPromoUsage(ctx: PromoEvaluationContext): PromoUsagePlan {
  const result = evaluatePromoUse(ctx);
  if (!result.ok) return {status: 'rejected', rejectReason: result.reason};
  return {
    status: ctx.usageExists ? 'idempotent' : 'commit',
    discountCents: result.discountCents,
  };
}

const PROMO_REASON_MESSAGES: Record<PromoRejectReason, string> = {
  code_not_found: 'Promo code not found',
  not_active: 'Promo code is not active',
  outside_window: 'Promo code is not valid at this time',
  exhausted: 'Promo code has been fully redeemed',
  already_used: 'Promo code has already been used',
};

export function promoReasonMessage(reason: PromoRejectReason): string {
  return PROMO_REASON_MESSAGES[reason];
}

// ----------------------------------------------------------------------------
// createOrder belt-and-suspenders (money-equality gate T-M6, extended by
// MONEY-1/W3.1a: stored items/tip/deliveryFee/status vs PaymentIntent metadata
// + full server re-derivation of the total)
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// BACKEND-2 (W7.4/T-4, 06-P1-2) — the PaymentIntent metadata bag is built by
// ONE pure builder so the creator stamp can never drift from the charge.
// ----------------------------------------------------------------------------

export interface ChargeIntentMetadataInput {
  /** Authenticated caller's uid (request.auth.uid) — legacy consumers. */
  userId: string;
  /** BACKEND-2: creator stamp — ALWAYS the authenticated caller's uid,
   *  re-checked against the confirming caller by verifyOrderCharge. */
  createdBy: string;
  orderId?: string;
  taxCents: number;
  discountCents: number;
  itemsSubtotalCents: number;
  tipCents: number;
  deliveryFeeCents: number;
  currency: string;
  /** MONEY-1 verified branch context (omitted when unpriced). */
  branchId?: string;
}

/**
 * Single builder for the Stripe PaymentIntent metadata bag. `createdBy` is
 * stamped server-side from the authenticated caller (never client input) so
 * every charge is attributable in Stripe's dashboard AND provable at
 * confirmation time (verifyOrderCharge rejects a mismatch). Money values are
 * stringified — Stripe metadata is a string map.
 */
export function buildChargeIntentMetadata(
    input: ChargeIntentMetadataInput,
): Record<string, string> {
  return {
    userId: input.userId,
    createdBy: input.createdBy,
    orderId: input.orderId ?? '',
    taxCents: String(input.taxCents),
    discountCents: String(input.discountCents),
    itemsSubtotalCents: String(input.itemsSubtotalCents),
    tipCents: String(input.tipCents),
    deliveryFeeCents: String(input.deliveryFeeCents),
    currency: input.currency,
    ...(input.branchId ? {branchId: input.branchId} : {}),
  };
}

export const CONFIRMED_ORDER_STATUS_ALLOWLIST: readonly string[] = ['confirmed'];

export interface OrderChargeVerificationInput {
  /** order.totalCents */
  claimedTotalCents: unknown;
  /** order.taxCents (stored by the client from the server charge result) */
  orderTaxCents: unknown;
  /** order.discountCents */
  orderDiscountCents: unknown;
  /** Stripe PaymentIntent amount (integer cents) */
  chargedAmountCents: unknown;
  /** PaymentIntent metadata.taxCents (server-derived at charge time) */
  chargedTaxCents: unknown;
  /** PaymentIntent metadata.discountCents */
  chargedDiscountCents: unknown;
  /**
   * MONEY-1: the EXACT items array that will be persisted (server-canonical
   * lines). Its recomputed subtotal must equal the server-stamped
   * metadata.itemsSubtotalCents — a client-invented items list can never
   * confirm an order.
   */
  orderItems: unknown;
  /** PaymentIntent metadata.itemsSubtotalCents */
  chargedItemsSubtotalCents: unknown;
  /** order.tipCents vs PaymentIntent metadata.tipCents */
  orderTipCents: unknown;
  chargedTipCents: unknown;
  /** order.deliveryFeeCents vs PaymentIntent metadata.deliveryFeeCents */
  orderDeliveryFeeCents: unknown;
  chargedDeliveryFeeCents: unknown;
  /** BACKEND-2 (W7.4): PaymentIntent metadata.createdBy — the server-side
   *  creator stamp from charge time (the authenticated caller's uid). */
  chargedCreatedBy: unknown;
  /** BACKEND-2 (W7.4): the order's effective creator (claimed customerId
   *  per the index.ts ownership guard, defaulting to the caller). Must
   *  equal chargedCreatedBy. */
  orderCreatedBy: unknown;
  /** order.status — must be in CONFIRMED_ORDER_STATUS_ALLOWLIST */
  orderStatus: unknown;
}

export interface OrderChargeVerificationResult {
  ok: boolean;
  reason?: string;
}

export function toFiniteIntOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isSafeInteger(value)) return value;
  if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) {
    const n = Number(value.trim());
    return Number.isSafeInteger(n) ? n : null;
  }
  return null;
}

export function verifyOrderCharge(
    input: OrderChargeVerificationInput,
): OrderChargeVerificationResult {
  // BACKEND-2 (W7.4/T-4): creator binding FIRST — the PaymentIntent's
  // server-side `createdBy` stamp must match the order's creator. A
  // PaymentIntent without the stamp (pre-deploy intents) cannot prove
  // creatorship and fails closed, so a stolen paymentIntentId can never
  // confirm someone else's order.
  const chargeCreator =
    typeof input.chargedCreatedBy === 'string' ? input.chargedCreatedBy : null;
  const orderCreator =
    typeof input.orderCreatedBy === 'string' ? input.orderCreatedBy : null;
  if (
    chargeCreator === null || chargeCreator.length === 0 ||
    orderCreator === null || orderCreator !== chargeCreator
  ) {
    return {
      ok: false,
      reason: 'Order creator does not match the authenticated charge creator',
    };
  }
  const claimed = toFiniteIntOrNull(input.claimedTotalCents);
  const charged = toFiniteIntOrNull(input.chargedAmountCents);
  if (claimed === null || charged === null || claimed !== charged) {
    return {
      ok: false,
      reason: 'Client order total does not match the amount charged on the PaymentIntent',
    };
  }
  const orderTax = toFiniteIntOrNull(input.orderTaxCents);
  const chargedTax = toFiniteIntOrNull(input.chargedTaxCents);
  if (orderTax === null || chargedTax === null || orderTax !== chargedTax) {
    return {
      ok: false,
      reason: 'Order tax does not match the server-computed tax',
    };
  }
  const orderDiscount = toFiniteIntOrNull(input.orderDiscountCents);
  const chargedDiscount = toFiniteIntOrNull(input.chargedDiscountCents);
  if (orderDiscount === null || chargedDiscount === null || orderDiscount !== chargedDiscount) {
    return {
      ok: false,
      reason: 'Order discount does not match the server-computed discount',
    };
  }
  // MONEY-1 (W3.1a): the recomputed subtotal of the STORED order items must
  // equal the server-stamped metadata subtotal — the stored items list is
  // verified, never trusted.
  const storedItemsSubtotal = computeItemsSubtotalCents(input.orderItems);
  const chargedItemsSubtotal = toFiniteIntOrNull(input.chargedItemsSubtotalCents);
  if (chargedItemsSubtotal === null || storedItemsSubtotal !== chargedItemsSubtotal) {
    return {
      ok: false,
      reason:
        'Stored order items do not match the server-priced subtotal charged on the PaymentIntent',
    };
  }
  const orderTip = toFiniteIntOrNull(input.orderTipCents);
  const chargedTip = toFiniteIntOrNull(input.chargedTipCents);
  if (orderTip === null || chargedTip === null || orderTip !== chargedTip) {
    return {
      ok: false,
      reason: 'Order tip does not match the server-computed tip',
    };
  }
  const orderDeliveryFee = toFiniteIntOrNull(input.orderDeliveryFeeCents);
  const chargedDeliveryFee = toFiniteIntOrNull(input.chargedDeliveryFeeCents);
  if (orderDeliveryFee === null || chargedDeliveryFee === null ||
      orderDeliveryFee !== chargedDeliveryFee) {
    return {
      ok: false,
      reason: 'Order delivery fee does not match the server-computed delivery fee',
    };
  }
  // MONEY-1 (W3.1a): status allowlist — only a confirmed order may be stored
  // against a succeeded PaymentIntent (a client cannot pre-mark 'delivered').
  if (typeof input.orderStatus !== 'string' ||
      !CONFIRMED_ORDER_STATUS_ALLOWLIST.includes(input.orderStatus)) {
    return {
      ok: false,
      reason:
        `Order status "${String(input.orderStatus)}" is not allowed at confirmation`,
    };
  }
  // MONEY-1 (W3.1a): internal consistency, server re-derived —
  // total == itemsSubtotal + tax + deliveryFee + tip - discount.
  const expectedTotal =
    storedItemsSubtotal + chargedTax - chargedDiscount + chargedTip + chargedDeliveryFee;
  if (claimed !== expectedTotal) {
    return {
      ok: false,
      reason: 'Order total is not internally consistent with the server-derived amounts',
    };
  }
  return {ok: true};
}

// ----------------------------------------------------------------------------
// MONEY-1 (W3.1b) menu cross-check — the SERVER re-prices every line from the
// `menus` collection. A client price is only ever a CLAIM: it must equal the
// server-derived price + option upcharges, or the charge fails closed BEFORE
// any money moves. Pure + deterministic: index.ts supplies plain menu doc
// snapshots (Admin SDK `getAll` — 1 read per item).
// ----------------------------------------------------------------------------

/** Server-generated order number (client OrderNumberService contract). */
export function formatOrderNumber(seq: number): string {
  if (!Number.isSafeInteger(seq) || seq < 0) {
    throw new MoneyComputationError('tax_not_configured', 'Order number out of range');
  }
  return `#${String(seq).padStart(4, '0')}`;
}

/** One flat client line the server must price (post-zod or normalized). */
export interface MenuPricingClientItem {
  /** `menus/{id}` document id. */
  id: string;
  quantity?: unknown;
  priceCents?: unknown;
  selectedOptions?: readonly {id: string; upchargeCents?: unknown}[];
}

/** Plain snapshot projection of a `menus/{id}` doc (order-aligned). */
export interface MenuDocSnapshot {
  exists: boolean;
  data: Record<string, unknown> | null;
}

export interface MenuPricingResult {
  ok: boolean;
  reason?: string;
  /** Server-derived subtotal over ALL lines (integer cents). */
  itemsSubtotalCents?: number;
  /** The single branch every priced menu doc belongs to ('' when no items). */
  branchId?: string;
  /**
   * Server-canonical nested lines (CartItemModel-compatible) built from the
   * menu docs — the ONLY items shape a verified order may persist.
   */
  canonicalItems?: unknown[];
}

function isNonNegativeSafeInt(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

/**
 * Normalises the client's STORED-order items into the flat pricing input the
 * menu cross-check verifies. Accepts the nested CartItemModel JSON the client
 * sends to createOrder (`{item:{id,...}, quantity, selectedOptions:[...]}`) or
 * the flat charge shape. Returns null when any line lacks a verifiable menu
 * item id (the caller fails closed).
 */
export function extractMenuPricingInput(
    orderItems: unknown,
): MenuPricingClientItem[] | null {
  if (!Array.isArray(orderItems)) return null;
  const lines: MenuPricingClientItem[] = [];
  for (const raw of orderItems) {
    if (raw === null || typeof raw !== 'object') return null;
    const line = raw as Record<string, unknown>;
    const nestedItem =
        (line.item ?? null) as Record<string, unknown> | null;
    const id =
      typeof line.id === 'string' && line.id.length > 0 ? line.id :
      typeof nestedItem?.id === 'string' && nestedItem.id.length > 0 ?
        nestedItem.id :
        '';
    if (id.length === 0) return null;
    const options: {id: string; upchargeCents?: unknown}[] = [];
    if (line.selectedOptions !== undefined && line.selectedOptions !== null) {
      if (!Array.isArray(line.selectedOptions)) return null;
      for (const opt of line.selectedOptions) {
        if (opt === null || typeof opt !== 'object') return null;
        const optId = (opt as Record<string, unknown>).id;
        if (typeof optId !== 'string' || optId.length === 0) return null;
        options.push({
          id: optId,
          upchargeCents: (opt as Record<string, unknown>).upchargeCents,
        });
      }
    }
    lines.push({
      id,
      quantity: line.quantity,
      priceCents:
        nestedItem && nestedItem.priceCents !== undefined ?
          nestedItem.priceCents :
          line.priceCents,
      selectedOptions: options,
    });
  }
  return lines;
}

/**
 * Re-prices every client line against its `menus/{id}` doc and derives the
 * server-canonical lines + subtotal + branch. Fails closed on: unknown item,
 * disabled item, invalid menu price, missing/inconsistent branch, unknown
 * option id, invalid upcharge, or a client-claimed price that differs from
 * the menu (T-MC1..T-MC7).
 */
export function verifyMenuPricing(
    items: readonly MenuPricingClientItem[],
    menuDocs: readonly (MenuDocSnapshot | null | undefined)[],
): MenuPricingResult {
  if (items.length !== menuDocs.length) {
    return {ok: false, reason: 'Menu lookup is not aligned with the priced items'};
  }
  let subtotal = 0;
  let branchId: string | null = null;
  const canonicalItems: unknown[] = [];
  for (let i = 0; i < items.length; i++) {
    const line = items[i];
    const snap = menuDocs[i];
    const menuDoc = snap && snap.exists ? snap.data : null;
    if (!menuDoc) {
      return {ok: false, reason: `Menu item "${line.id}" does not exist`};
    }
    if (menuDoc.isAvailable === false) {
      return {ok: false, reason: `Menu item "${line.id}" is currently unavailable`};
    }
    if (!isNonNegativeSafeInt(menuDoc.priceCents)) {
      return {ok: false, reason: `Menu item "${line.id}" has no valid server price`};
    }
    const menuPrice: number = menuDoc.priceCents;
    const menuBranch =
      typeof menuDoc.branchId === 'string' ? menuDoc.branchId.trim() : '';
    if (menuBranch.length === 0) {
      return {
        ok: false,
        reason: `Menu item "${line.id}" is not associated with a branch`,
      };
    }
    if (branchId === null) {
      branchId = menuBranch;
    } else if (branchId !== menuBranch) {
      return {ok: false, reason: 'Order spans items from different branches'};
    }

    // Index the menu doc's modifier options by id (only upcharge source).
    const optionIndex = new Map<string, Record<string, unknown>>();
    const modifiers = menuDoc.modifiers;
    if (modifiers !== undefined && modifiers !== null) {
      if (!Array.isArray(modifiers)) {
        return {ok: false, reason: `Menu item "${line.id}" has malformed modifiers`};
      }
      for (const modifier of modifiers) {
        if (modifier === null || typeof modifier !== 'object') continue;
        const options = (modifier as Record<string, unknown>).options;
        if (!Array.isArray(options)) continue;
        for (const option of options) {
          if (option === null || typeof option !== 'object') continue;
          const optionData = option as Record<string, unknown>;
          if (typeof optionData.id === 'string' && optionData.id.length > 0) {
            optionIndex.set(optionData.id, optionData);
          }
        }
      }
    }

    let serverUpchargeTotal = 0;
    let clientUpchargeTotal = 0;
    const verifiedOptions: Record<string, unknown>[] = [];
    const selected = line.selectedOptions ?? [];
    for (const option of selected) {
      const serverOption = optionIndex.get(option.id);
      if (!serverOption) {
        return {
          ok: false,
          reason:
            `Selected option "${option.id}" is not offered by menu item "${line.id}"`,
        };
      }
      const rawUpcharge = serverOption.upchargeCents;
      let optionUpcharge: number;
      if (rawUpcharge === undefined || rawUpcharge === null) {
        optionUpcharge = 0; // ModifierOption default (client model contract)
      } else if (isNonNegativeSafeInt(rawUpcharge)) {
        optionUpcharge = rawUpcharge;
      } else {
        return {
          ok: false,
          reason:
            `Menu item "${line.id}" option "${option.id}" has an invalid upcharge`,
        };
      }
      serverUpchargeTotal += optionUpcharge;
      const clientUpcharge = option.upchargeCents;
      clientUpchargeTotal +=
        typeof clientUpcharge === 'number' && Number.isFinite(clientUpcharge) ?
          clientUpcharge :
          0;
      verifiedOptions.push({
        id: option.id,
        name: typeof serverOption.name === 'string' ? serverOption.name : '',
        upchargeCents: optionUpcharge,
        isDefault: serverOption.isDefault === true,
      });
    }

    const qty = isNonNegativeSafeInt(line.quantity) && line.quantity >= 1 ?
      line.quantity :
      1;
    const clientUnit =
      (isNonNegativeSafeInt(line.priceCents) ? line.priceCents : 0) +
      clientUpchargeTotal;
    const serverUnit = menuPrice + serverUpchargeTotal;
    if (clientUnit !== serverUnit) {
      return {
        ok: false,
        reason: `Item "${line.id}" price does not match the current menu price`,
      };
    }
    subtotal += serverUnit * qty;
    canonicalItems.push({
      item: {...menuDoc, id: line.id, priceCents: menuPrice},
      quantity: qty,
      selectedOptions: verifiedOptions,
    });
  }
  if (!Number.isSafeInteger(subtotal)) {
    return {ok: false, reason: 'Order subtotal is out of range'};
  }
  return {
    ok: true,
    itemsSubtotalCents: subtotal,
    branchId: branchId ?? '',
    canonicalItems,
  };
}

// ----------------------------------------------------------------------------
// Request schemas (shared by index.ts). Deliberately NOT .strict(): a hostile
// client may still smuggle `taxCents` / `discountCents` in the JSON — they are
// STRIPPED by parse and can never influence the charge (T-M1 / T-M3).
// ----------------------------------------------------------------------------

export const createPaymentIntentSchema = z.object({
  items: z
      .array(
          z.object({
            // MONEY-1: the `menus/{id}` doc this line claims to buy — the
            // server re-prices every line against it and fails closed on a
            // mismatch (T-MC1/T-MC3), so the id is REQUIRED.
            id: z.string().min(1).max(200),
            priceCents: z.number().int().min(0).optional(),
            quantity: z.number().int().min(1).optional(),
            selectedOptions: z
                .array(z.object({
                  // Resolved against the menu doc's modifier options; the
                  // SERVER upcharge is the only one trusted for the charge.
                  id: z.string().min(1).max(200),
                  name: z.string().max(200).optional(),
                  upchargeCents: z.number().int().min(0).optional(),
                }))
                .optional(),
          }),
      )
      .max(50)
      .optional(),
  idempotencyKey: z.string().min(1).max(200),
  tipCents: z.number().int().min(0).optional(),
  deliveryFeeCents: z.number().int().min(0).optional(),
  stateCode: z.string().min(1).max(10).toUpperCase(),
  clientId: z.string().min(1).max(200),
  code: z.string().min(1).max(50).optional(),
  orderId: z.string().max(200).optional(),
});

export const applyPromoSchema = z.object({
  code: z.string().min(1).max(50),
  cartSubtotalCents: z.number().int().min(0).max(10_000_000),
  userId: z.string().max(200).optional(),
});

// ----------------------------------------------------------------------------
// MONEY-2 (W3.2 / 06-P1-1): refund-replay guard — pure detection + record shape.
//
// A Stripe PaymentIntent KEEPS `status: 'succeeded'` after a refund, so the
// createOrder status check alone would let a retrying client confirm an order
// on a refunded charge (a refunded PI looked "succeeded"). The only truthful
// signal is the PI's CHARGES: any charge with `refunded === true`, a positive
// `amount_refunded` (partial or full refund) or a non-empty `refunds` list
// means money was returned and the order MUST fail closed. Deterministic +
// unit-tested here (batch T-1).
// ----------------------------------------------------------------------------

export interface RefundChargeInspection {
  hasRefundedCharge: boolean;
  /**
   * Refunded amount in integer minor units (cents), parsed from the first
   * refunded charge (`amount_refunded`, falling back to the first refund-list
   * entry). `null` when nothing was refunded or the amount is not parseable —
   * a `null` amount is still a fail-closed rejection (the record is written
   * with amount `null` rather than a fabricated number).
   */
  refundedAmountCents: number | null;
  /** Fail-closed rejection message; non-null exactly when hasRefundedCharge. */
  reason: string | null;
}

export function inspectRefundedCharges(charges: unknown): RefundChargeInspection {
  if (!Array.isArray(charges) || charges.length === 0) {
    return {hasRefundedCharge: false, refundedAmountCents: null, reason: null};
  }
  for (const raw of charges) {
    if (raw === null || typeof raw !== 'object') continue;
    const charge = raw as {refunded?: unknown; amount_refunded?: unknown; refunds?: unknown};
    const refundsData = (charge.refunds as {data?: unknown} | null)?.data;
    const hasRefund =
      charge.refunded === true ||
      (typeof charge.amount_refunded === 'number' &&
        Number.isFinite(charge.amount_refunded) &&
        charge.amount_refunded > 0) ||
      (Array.isArray(refundsData) && refundsData.length > 0);
    if (!hasRefund) continue;
    const parsedAmount =
      typeof charge.amount_refunded === 'number' &&
      Number.isFinite(charge.amount_refunded) &&
      charge.amount_refunded > 0 ?
        charge.amount_refunded :
        Array.isArray(refundsData) && refundsData.length > 0 ?
          (refundsData[0] as {amount?: unknown} | null)?.amount :
          null;
    return {
      hasRefundedCharge: true,
      refundedAmountCents:
        typeof parsedAmount === 'number' && Number.isFinite(parsedAmount) ?
          Math.trunc(parsedAmount) :
          null,
      reason: 'PaymentIntent charge is already refunded',
    };
  }
  return {hasRefundedCharge: false, refundedAmountCents: null, reason: null};
}

// ----------------------------------------------------------------------------
// MONEY-2 (W3.2/W3.4): the minimal refund record persisted under
// `orders/{id}.refunds[]` — (amount, reason, at, refundId if available), schema
// documented in batch MONEY-2 §8.5. Built server-side by BOTH the createOrder
// replay guard and the cancelOrder callable, so the shape is shared + tested.
// ----------------------------------------------------------------------------

export interface RefundRecord {
  amount: number | null;
  reason: string;
  at: Date;
  refundId: string | null;
}

export function buildRefundRecord(input: {
  amountCents: number | null;
  reason: string;
  at: Date;
  refundId?: string | null;
}): RefundRecord {
  return {
    amount: input.amountCents,
    reason: input.reason,
    at: input.at,
    refundId:
      typeof input.refundId === 'string' && input.refundId.length > 0 ?
        input.refundId :
        null,
  };
}

// ----------------------------------------------------------------------------
// MONEY-2 (W3.4): pure cancellation-state gate shared by the cancelOrder
// callable (index.ts) and `npm test` unit cases. Allowed transitions:
// pending/confirmed -> cancelled. An already-cancelled order is an idempotent
// OK (never a double refund). Every other status (preparing/ready/pickedUp/
// delivered/missing/…) is a fail-closed rejection.
// ----------------------------------------------------------------------------

export type OrderCancellationDecision =
  | {action: 'cancel'; status: 'pending' | 'confirmed'}
  | {action: 'already_cancelled'}
  | {action: 'reject'; status: string};

export function decideOrderCancellation(status: unknown): OrderCancellationDecision {
  if (status === 'cancelled') return {action: 'already_cancelled'};
  if (status === 'pending' || status === 'confirmed') {
    return {action: 'cancel', status};
  }
  return {
    action: 'reject',
    status: typeof status === 'string' && status.length > 0 ? status : String(status),
  };
}

// ----------------------------------------------------------------------------
// MONEY-3 (W3.7 / 06-P2-9-adjacent): server-authoritative delivery fee.
// The client's `deliveryFeeCents` is only ever a CLAIM: the server re-reads
// `settings/restaurantConfig.deliveryFeeCents` and CLAMPS any differing value
// to the server price before the charge (a hostile client can neither raise
// nor lower the delivery fee). Deterministic + unit-tested (batch T-6).
// ----------------------------------------------------------------------------

export interface DeliveryFeeValidation {
  /** The fee actually charged, in integer minor units (cents). */
  deliveryFeeCents: number;
  /** True when the server config value differed from the client claim. */
  clamped: boolean;
}

export function validateDeliveryFee(
    clientFeeCents: unknown,
    serverFeeCents: unknown,
): DeliveryFeeValidation {
  const client = Math.max(0, Math.round(
      typeof clientFeeCents === 'number' && Number.isFinite(clientFeeCents) ?
        clientFeeCents :
        0,
  ));
  const server =
    typeof serverFeeCents === 'number' && Number.isFinite(serverFeeCents) &&
    serverFeeCents >= 0 ?
      Math.round(serverFeeCents) :
      null;
  // No server-configured fee -> there is nothing to clamp to; the client claim
  // is used as-is (the config doc may not carry the field yet on old backends).
  if (server === null) return {deliveryFeeCents: client, clamped: false};
  if (server === client) return {deliveryFeeCents: server, clamped: false};
  return {deliveryFeeCents: server, clamped: true};
}
