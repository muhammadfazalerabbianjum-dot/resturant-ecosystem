/**
 * FIX-B12 (REC-B2-1 / AUD1-01 residual) - SERVER IDEMPOTENCY CONTENT-COMPARISON.
 *
 * Pure decision function for a key hit in `createOrder`
 * (`index.ts` idempotency block). The defect at base: a key hit was returned
 * unconditionally - no customer, PaymentIntent or amount comparison - so any
 * caller presenting a key already in use received ANOTHER ORDER'S ID.
 *
 * Contract (FIX_b12_server_dedupe.md section 3, T-1):
 *  - same uid + same paymentIntentId + same amount -> `{kind: 'replay'}`;
 *  - ANY difference -> `{kind: 'conflict', reason}` naming the field;
 *  - missing/blank/non-integer on EITHER side -> conflict (FAIL CLOSED, law
 *    0.5: doubt never resolves to "return success").
 *
 * No I/O, no Firestore, no Stripe - unit-testable in the `node --test` lane
 * (test/idempotency_conflict.test.js). Money sanctuary (law 0.4): this module
 * only CLASSIFIES; it never computes or mutates an amount.
 */

/** The requesting caller (server-derived: auth uid + request payload). */
export interface IdempotencyRequestSide {
  uid: unknown;
  paymentIntentId: unknown;
  totalCents: unknown;
}

/** The stored order document found by `where('idempotencyKey', '==', key)`. */
export interface IdempotencyExistingSide {
  customerId: unknown;
  paymentIntentId: unknown;
  totalCents: unknown;
}

/** Which field's mismatch rejected the key hit. */
export type IdempotencyConflictReason =
  | 'customer_mismatch'
  | 'payment_intent_mismatch'
  | 'amount_mismatch';

/** `replay` = the same attempt's own key; `conflict` = never return it. */
export type IdempotencyReplayDecision =
  | {kind: 'replay'}
  | {kind: 'conflict'; reason: IdempotencyConflictReason};

/** Non-blank string (after trim) - blank on EITHER side fails closed. */
function isNonBlankString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/** Integer-cent equality: both sides must be integers (Stripe minor units). */
function sameAmountCents(a: unknown, b: unknown): boolean {
  return (
    typeof a === 'number' &&
    Number.isSafeInteger(a) &&
    typeof b === 'number' &&
    Number.isSafeInteger(b) &&
    a === b
  );
}

/**
 * Classify an idempotency-key hit for `createOrder` (Law 9 + FIX-B12).
 *
 * Comparison order (pinned by test): customer -> PaymentIntent -> amount; the
 * FIRST mismatching field names the `reason`. Returns `replay` only when all
 * three fields are present, non-blank/integer and equal - anything else is a
 * `conflict`, which the caller MUST translate into a rejection (never into
 * returning the found order).
 */
export function classifyIdempotentReplay(input: {
  request: IdempotencyRequestSide;
  existing: IdempotencyExistingSide;
}): IdempotencyReplayDecision {
  const {request, existing} = input;

  // 1. Customer: the stored order's owner must be THIS caller.
  if (
    !isNonBlankString(request.uid) ||
    !isNonBlankString(existing.customerId) ||
    request.uid.trim() !== existing.customerId.trim()
  ) {
    return {kind: 'conflict', reason: 'customer_mismatch'};
  }

  // 2. PaymentIntent: the retry must present the SAME charge.
  if (
    !isNonBlankString(request.paymentIntentId) ||
    !isNonBlankString(existing.paymentIntentId) ||
    request.paymentIntentId.trim() !== existing.paymentIntentId.trim()
  ) {
    return {kind: 'conflict', reason: 'payment_intent_mismatch'};
  }

  // 3. Amount: the claimed total must equal the stored (charged) total.
  if (!sameAmountCents(request.totalCents, existing.totalCents)) {
    return {kind: 'conflict', reason: 'amount_mismatch'};
  }

  return {kind: 'replay'};
}
