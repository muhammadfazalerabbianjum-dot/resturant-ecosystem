/**
 * P1-2 — the ledger. Append-only `transactions` rows, written in the SAME
 * Firestore transaction as the order change that caused them (handoff §8.1 A6,
 * §9.3; owner ruling D-021…D-026 of 2026-11-09).
 *
 * Invariants this module exists to protect:
 *  - money is never computed here. Every amount is copied from a value the
 *    server already derived (the charged PaymentIntent amount, the verified
 *    order document). This module only shapes and validates.
 *  - exactly one row per order: the row id is derived from the order id, so a
 *    retry with the same idempotency key hits the same document.
 *  - append-only: an existing row is never rewritten (`decideLedgerWrite`).
 *    Reversals (P1-3) are new rows with their own ids, never edits.
 *  - all-or-nothing: the order write and the row write happen inside one
 *    `runTransaction`, so a rejected row cannot leave an untrailered order.
 *
 * No runtime import of firebase-admin: the store/tx/ref shapes below are the
 * small structural subset this module uses, which keeps the whole file testable
 * in the `node --test` lane with a fake store, and still accepts the real
 * admin SDK objects at the call site.
 */

export const LEDGER_COLLECTION = 'transactions';
/** Card rows. Byte-compatible with every row ever written. */
export const LEDGER_SCHEMA_VERSION = 1;
/**
 * P2-1 / D-059 — cash rows. A cash sale has no PaymentIntent and no customer
 * account, so it must say HOW it was paid and who took it. Bumping the version
 * (rather than adding optional keys to v1) is what keeps a card row identical
 * to what every existing reader already understands.
 */
export const LEDGER_SCHEMA_VERSION_CASH = 2;
export type LedgerEntryKind = 'sale' | 'reversal';
/** How the money arrived. `card` is implicit (the intent proves it). */
export type LedgerPaymentMethod = 'card' | 'cash';

/** What `createOrder` knows at the moment the order document is built. */
export interface SaleLedgerInput {
  orderId: unknown;
  orderNumber?: unknown;
  branchId?: unknown;
  customerId: unknown;
  paymentIntentId?: unknown;
  totalCents: unknown;
  taxCents?: unknown;
  tipCents?: unknown;
  discountCents?: unknown;
  deliveryFeeCents?: unknown;
  currency?: unknown;
  channel?: unknown;
  createdAt?: unknown;
  // ── cash-only facts (D-059). Omitted ⇒ a card row, exactly as before. ──
  paymentMethod?: unknown;
  staffId?: unknown;
  /** Immutable snapshot: the row is the only record that money moved. */
  items?: unknown;
  /** The rate the tax was computed at, so the row can be audited later. */
  taxRate?: unknown;
  amountTenderedCents?: unknown;
  changeCents?: unknown;
}

/** A validation failure names the field so a caller can never guess silently. */
export class LedgerValidationError extends Error {
  readonly field: string;

  constructor(field: string, message: string) {
    super(`ledger: ${field} ${message}`);
    this.name = 'LedgerValidationError';
    this.field = field;
  }
}

/** Deterministic: the same order always addresses the same row. */
export function ledgerDocId(orderId: string): string {
  return `sale_${orderId}`;
}

/** `append` writes a new row; `keep` leaves the existing row untouched. */
export function decideLedgerWrite(exists: boolean): 'append' | 'keep' {
  return exists ? 'keep' : 'append';
}

function requireNonEmptyString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new LedgerValidationError(field, 'must be a non-empty string');
  }
  return value;
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function requireCents(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw new LedgerValidationError(
        field, 'must be a non-negative integer number of cents');
  }
  return value;
}

function optionalCents(value: unknown, field: string): number {
  return value === undefined || value === null ? 0 : requireCents(value, field);
}

/**
 * Shapes one sale row from server-derived values. Throws
 * `LedgerValidationError` rather than writing a partial or guessed row: a
 * missing amount is a bug, and an order without a truthful row must not commit.
 */
/** A whole-number, non-negative cents value that may not exceed `max`. */
function requireCentsWithin(value: unknown, field: string, max: number): number {
  const cents = requireCents(value, field);
  if (cents > max) {
    throw new LedgerValidationError(field, `must not exceed ${max}`);
  }
  return cents;
}

/** A deep, frozen-by-copy snapshot of what was sold (never the caller's array). */
function requireItemsSnapshot(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value) || value.length === 0) {
    throw new LedgerValidationError('items', 'must be a non-empty array');
  }
  return value.map((raw, index) => {
    if (raw === null || typeof raw !== 'object') {
      throw new LedgerValidationError(`items[${index}]`, 'must be an object');
    }
    const item = raw as Record<string, unknown>;
    const name = requireNonEmptyString(item.name, `items[${index}].name`);
    const unitPriceCents =
        requireCents(item.unitPriceCents, `items[${index}].unitPriceCents`);
    const quantity = item.quantity === undefined ? 1 : item.quantity;
    if (typeof quantity !== 'number' || !Number.isInteger(quantity) || quantity < 1) {
      throw new LedgerValidationError(
          `items[${index}].quantity`, 'must be a positive integer');
    }
    return {name, unitPriceCents, quantity};
  });
}

function requireTaxRate(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new LedgerValidationError('taxRate', 'must be a number between 0 and 1');
  }
  return value;
}

/**
 * Card rows are unchanged (v1). Cash rows are the v2 shape (D-059):
 * `paymentIntentId: null` because there is no processor reference, an empty
 * `customerId` because a walk-in has no account, `staffId` because a person must
 * be on the record, and an immutable items/tax snapshot because the row is the
 * only evidence that money moved.
 */
export function buildSaleRow(input: SaleLedgerInput): Record<string, unknown> {
  const orderId = requireNonEmptyString(input.orderId, 'orderId');

  const paymentMethod: LedgerPaymentMethod =
      input.paymentMethod === undefined || input.paymentMethod === null ?
        'card' :
        requireNonEmptyString(input.paymentMethod, 'paymentMethod') as LedgerPaymentMethod;
  if (paymentMethod !== 'card' && paymentMethod !== 'cash') {
    throw new LedgerValidationError(
        'paymentMethod', 'must be \'card\' or \'cash\'');
  }
  const isCash = paymentMethod === 'cash';

  // A walk-in has no account: empty is legal for cash ONLY, and empty is the
  // shape `OrderModel` already declares (`@Default('') String customerId`).
  const customerId = isCash ?
    optionalString(input.customerId) ?? '' :
    requireNonEmptyString(input.customerId, 'customerId');
  const paymentIntentId = isCash ?
    null :
    requireNonEmptyString(input.paymentIntentId, 'paymentIntentId');

  const row: Record<string, unknown> = {
    id: ledgerDocId(orderId),
    schemaVersion: isCash ? LEDGER_SCHEMA_VERSION_CASH : LEDGER_SCHEMA_VERSION,
    kind: 'sale' satisfies LedgerEntryKind,
    orderId,
    orderNumber: optionalString(input.orderNumber),
    branchId: optionalString(input.branchId),
    customerId,
    paymentIntentId,
    totalCents: requireCents(input.totalCents, 'totalCents'),
    taxCents: optionalCents(input.taxCents, 'taxCents'),
    tipCents: optionalCents(input.tipCents, 'tipCents'),
    discountCents: optionalCents(input.discountCents, 'discountCents'),
    deliveryFeeCents: optionalCents(input.deliveryFeeCents, 'deliveryFeeCents'),
  };

  const currency = optionalString(input.currency);
  if (currency !== null) row.currency = currency;

  const channel = optionalString(input.channel);
  if (channel !== null) row.channel = channel;

  if (input.createdAt !== undefined) row.createdAt = input.createdAt;

  if (isCash) {
    const totalCents = requireCents(input.totalCents, 'totalCents');
    row.paymentMethod = paymentMethod;
    row.staffId = requireNonEmptyString(input.staffId, 'staffId');
    row.items = requireItemsSnapshot(input.items);
    row.taxRate = requireTaxRate(input.taxRate);
    row.amountTenderedCents =
        requireCents(input.amountTenderedCents, 'amountTenderedCents');
    const changeCents = requireCentsWithin(
        input.changeCents, 'changeCents', row.amountTenderedCents as number);
    // The change is arithmetic, not an opinion: tendered - total.
    if (changeCents !== (row.amountTenderedCents as number) - totalCents) {
      throw new LedgerValidationError(
          'changeCents', 'must equal amountTenderedCents - totalCents');
    }
    row.changeCents = changeCents;
  }

  return row;
}

/** Minimal structural Firestore shapes — real SDK objects satisfy these. */
export interface LedgerDocRef {
  readonly id: string;
}

export interface LedgerSnapshot {
  readonly exists: boolean;
  /** Present on the real SDK; the rollup rebuild needs the stored bytes. */
  data?(): Record<string, unknown> | undefined;
}

export interface LedgerTransaction {
  get(ref: LedgerDocRef): Promise<LedgerSnapshot>;
  set(ref: LedgerDocRef, data: Record<string, unknown>): void;
  /** Merge-update: the ONLY way to patch a document without erasing its other fields. */
  update(ref: LedgerDocRef, data: Record<string, unknown>): void;
}

export interface LedgerCollection {
  doc(id: string): LedgerDocRef;
}

export interface LedgerStore {
  collection(name: string): LedgerCollection;
  runTransaction<T>(update: (tx: LedgerTransaction) => Promise<T>): Promise<T>;
}

/**
 * The `createOrder` entry point: every row field except the payment facts comes
 * from the order document being written, so the row cannot disagree with it.
 * The amount and currency come from the PaymentIntent the server actually
 * charged — never from the client payload.
 */
export async function commitSaleForOrder(
    store: LedgerStore,
    orderRef: LedgerDocRef,
    orderDoc: Record<string, unknown>,
    paymentIntent: {id: unknown; amount: unknown; currency?: unknown},
    createdAt: unknown,
): Promise<'appended' | 'kept'> {
  const row = buildSaleRow({
    orderId: orderDoc.id,
    orderNumber: orderDoc.orderNumber,
    branchId: orderDoc.branchId,
    customerId: orderDoc.customerId,
    paymentIntentId: paymentIntent.id,
    totalCents: paymentIntent.amount,
    taxCents: orderDoc.taxCents,
    tipCents: orderDoc.tipCents,
    discountCents: orderDoc.discountCents,
    deliveryFeeCents: orderDoc.deliveryFeeCents,
    currency: paymentIntent.currency,
    createdAt,
  });
  return commitOrderWithLedger(store, orderRef, orderDoc, row);
}

export const REVERSAL_PREFIX = 'rev_';

/** Deterministic too: one reversal per original row, same id every retry. */
export function reversalDocId(originalRowId: string): string {
  return `${REVERSAL_PREFIX}${originalRowId}`;
}

/** Everything a reversal needs is read from the original row, not supplied. */
export interface ReversalLedgerInput {
  originalRowId: unknown;
  original: Record<string, unknown>;
  reason: unknown;
  actorUid?: unknown;
  createdAt?: unknown;
}

function requireReversibleSale(original: Record<string, unknown>): number {
  if (original.kind !== 'sale') {
    throw new LedgerValidationError('original', 'must be a sale row');
  }
  const totalCents = requireCents(original.totalCents, 'original.totalCents');
  if (totalCents === 0) {
    throw new LedgerValidationError('original.totalCents', 'must be positive to reverse');
  }
  return totalCents;
}

/**
 * Shapes the reversal row: a NEW row whose amounts mirror the original with the
 * opposite sign. The original is never touched — this is what makes
 * "byte-identical afterwards" structural rather than a promise.
 */
export function buildReversalRow(
    input: ReversalLedgerInput,
): Record<string, unknown> {
  const originalRowId = requireNonEmptyString(input.originalRowId, 'originalRowId');
  const reason = requireNonEmptyString(input.reason, 'reason');
  const original = input.original;
  const totalCents = requireReversibleSale(original);

  const row: Record<string, unknown> = {
    id: reversalDocId(originalRowId),
    schemaVersion: LEDGER_SCHEMA_VERSION,
    kind: 'reversal' satisfies LedgerEntryKind,
    status: 'reversed',
    reversalOf: originalRowId,
    reversalReason: reason,
    orderId: original.orderId,
    orderNumber: original.orderNumber ?? null,
    branchId: original.branchId ?? null,
    customerId: original.customerId ?? null,
    channel: original.channel ?? null,
    currency: original.currency ?? null,
    paymentIntentId: original.paymentIntentId ?? null,
    // D-059: a reversal of a cash sale must still say a person took/voided it.
    // `paymentMethod` is copied only when the original had one, so a card
    // reversal keeps its historical key set exactly.
    ...(original.paymentMethod === undefined || original.paymentMethod === null ?
      {} : {paymentMethod: original.paymentMethod}),
    ...(original.staffId === undefined || original.staffId === null ?
      {} : {staffId: original.staffId}),
    ...(Array.isArray(original.items) ? {items: original.items} : {}),
    ...(typeof original.taxRate === 'number' ? {taxRate: original.taxRate} : {}),
    totalCents: -totalCents,
    taxCents: -optionalCents(original.taxCents, 'original.taxCents'),
    tipCents: -optionalCents(original.tipCents, 'original.tipCents'),
    discountCents: -optionalCents(original.discountCents, 'original.discountCents'),
    deliveryFeeCents:
        -optionalCents(original.deliveryFeeCents, 'original.deliveryFeeCents'),
  };

  const actorUid = optionalString(input.actorUid);
  if (actorUid !== null) row.actorUid = actorUid;
  if (input.createdAt !== undefined) row.createdAt = input.createdAt;

  return row;
}

/**
 * Appends the reversal row, refusing to run against an original that does not
 * exist. The original is only READ: no write statement mentions it, so a
 * reversal can never alter the sale it corrects.
 */
export async function appendReversal(
    store: LedgerStore,
    originalRef: LedgerDocRef,
    reversalRow: Record<string, unknown>,
): Promise<'appended' | 'kept'> {
  const rowId = requireNonEmptyString(reversalRow.id, 'row.id');

  return store.runTransaction(async (tx) => {
    const original = await tx.get(originalRef);
    if (!original.exists) {
      throw new LedgerValidationError('original', 'does not exist');
    }

    const reversalRef = store.collection(LEDGER_COLLECTION).doc(rowId);
    const existing = await tx.get(reversalRef);
    if (decideLedgerWrite(existing.exists) === 'keep') return 'kept';

    tx.set(reversalRef, reversalRow);
    return 'appended';
  });
}

/**
 * Commits a VOID: the reversal row and the cancelled order in ONE transaction.
 *
 * WHY one: `appendReversal` alone would leave a reversed sale on a live order if
 * the process died between the two writes — the counter would show a ticket the
 * ledger says was refunded. Both writes or neither.
 *
 * The original row is only READ (append-only), and the reversal id is
 * deterministic, so a retried void keeps the first reversal and rewrites the same
 * order patch (idempotent).
 */
export async function commitVoidWithReversal(
    store: LedgerStore,
    originalRef: LedgerDocRef,
    reversalRow: Record<string, unknown>,
    orderRef: LedgerDocRef,
    orderPatch: Record<string, unknown>,
): Promise<'appended' | 'kept'> {
  const rowId = requireNonEmptyString(reversalRow.id, 'row.id');

  return store.runTransaction(async (tx) => {
    const original = await tx.get(originalRef);
    if (!original.exists) {
      throw new LedgerValidationError('original', 'does not exist');
    }

    const reversalRef = store.collection(LEDGER_COLLECTION).doc(rowId);
    const existing = await tx.get(reversalRef);
    const decision = decideLedgerWrite(existing.exists);

    if (decision === 'append') tx.set(reversalRef, reversalRow);
    // UPDATE, not set: a void must not erase the order's own fields (items,
    // totals, provenance). `set` would replace the whole document.
    tx.update(orderRef, orderPatch);
    return decision === 'append' ? 'appended' : 'kept';
  });
}

/**
 * Writes the order document and (on first sight of this order) its single sale
 * row inside one Firestore transaction. Returns whether the row was appended or
 * an existing one was kept untouched.
 *
 * Reads happen before writes, as Firestore transactions require.
 */
export async function commitOrderWithLedger(
    store: LedgerStore,
    orderRef: LedgerDocRef,
    orderDoc: Record<string, unknown>,
    ledgerRow: Record<string, unknown>,
): Promise<'appended' | 'kept'> {
  const rowId = requireNonEmptyString(ledgerRow.id, 'row.id');

  return store.runTransaction(async (tx) => {
    const ledgerRef = store.collection(LEDGER_COLLECTION).doc(rowId);
    const existing = await tx.get(ledgerRef);
    const decision = decideLedgerWrite(existing.exists);

    tx.set(orderRef, orderDoc);
    if (decision === 'keep') return 'kept';

    tx.set(ledgerRef, ledgerRow);
    return 'appended';
  });
}
