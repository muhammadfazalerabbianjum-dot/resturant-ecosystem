/**
 * P2-1 — a cash sale, shaped on the server.
 *
 * WHY this module is pure: the money rules must be provable without Firestore,
 * Stripe or a clock. `createCashOrder` (index.ts) does the I/O — it re-prices the
 * lines from `menus`, resolves tax through the SAME `resolveChargeTaxAndPromo`
 * the card path charges with, then calls `buildCashSale` here. Nothing in this
 * file reads a client number: the subtotal, tax and rate arrive already derived,
 * and the total is computed here so an order can never disagree with its row.
 *
 * The row itself is built by `ledger.buildSaleRow` (v2). This module only shapes
 * the inputs, which keeps every row guarantee in one place.
 */
import {
  buildReversalRow,
  type SaleLedgerInput,
} from './ledger';

/** A validation failure names the field, so a caller can never guess silently. */
export class CashSaleError extends Error {
  readonly field: string;

  constructor(field: string, message: string) {
    super(`cash sale: ${field} ${message}`);
    this.name = 'CashSaleError';
    this.field = field;
  }
}

export interface CashSaleInput {
  orderId: unknown;
  orderNumber?: unknown;
  tenantId: unknown;
  branchId: unknown;
  /** The authenticated staff member taking the money. */
  staffId: unknown;
  staffRoles?: unknown;
  /** Walk-in: empty by default (D-059/Q1). */
  guestName?: unknown;
  itemsSubtotalCents: unknown;
  taxCents: unknown;
  taxRate: unknown;
  currency: unknown;
  /** `verifyMenuPricing().canonicalItems` — the only items a priced order may persist. */
  canonicalItems: unknown;
  amountTenderedCents: unknown;
  now: unknown;
  channel?: unknown;
}

export interface CashSale {
  order: Record<string, unknown>;
  ledgerInput: SaleLedgerInput;
}

function requireNonEmptyString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new CashSaleError(field, 'must be a non-empty string');
  }
  return value;
}

function requireCents(value: unknown, field: string): number {
  if (typeof value !== 'number' && typeof value !== 'bigint') {
    throw new CashSaleError(field, 'must be a non-negative integer number of cents');
  }
  const cents = Number(value);
  if (!Number.isSafeInteger(cents) || cents < 0) {
    throw new CashSaleError(field, 'must be a non-negative integer number of cents');
  }
  return cents;
}

function requireRate(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new CashSaleError('taxRate', 'must be a number between 0 and 1');
  }
  return value;
}

interface SnapshotLine {
  name: string;
  unitPriceCents: number;
  quantity: number;
}

/**
 * The immutable receipt lines for the row: name, unit price INCLUDING option
 * upcharges, quantity. Built by copy so a later mutation of the canonical items
 * cannot rewrite a stored sale.
 */
function snapshotLines(canonicalItems: unknown): SnapshotLine[] {
  if (!Array.isArray(canonicalItems) || canonicalItems.length === 0) {
    throw new CashSaleError('canonicalItems', 'must be a non-empty array');
  }
  return canonicalItems.map((raw, index) => {
    if (raw === null || typeof raw !== 'object') {
      throw new CashSaleError(`canonicalItems[${index}]`, 'must be an object');
    }
    const line = raw as Record<string, unknown>;
    const item = (line.item ?? null) as Record<string, unknown> | null;
    const name = typeof item?.name === 'string' && item.name.length > 0 ?
      item.name :
      `line ${index + 1}`;
    const basePrice = typeof item?.priceCents === 'number' ? item.priceCents : 0;
    const options = Array.isArray(line.selectedOptions) ? line.selectedOptions : [];
    let upcharges = 0;
    for (const option of options) {
      const upcharge = (option as {upchargeCents?: unknown} | null)?.upchargeCents;
      if (typeof upcharge === 'number' && Number.isSafeInteger(upcharge) && upcharge > 0) {
        upcharges += upcharge;
      }
    }
    const quantity = typeof line.quantity === 'number' ? line.quantity : 1;
    if (!Number.isSafeInteger(quantity) || quantity < 1) {
      throw new CashSaleError(`canonicalItems[${index}].quantity`, 'must be a positive integer');
    }
    return {name, unitPriceCents: basePrice + upcharges, quantity};
  });
}

/**
 * Builds the order document and the ledger input for a cash sale whose money has
 * ALREADY been derived by the server.
 */
export function buildCashSale(input: CashSaleInput): CashSale {
  const orderId = requireNonEmptyString(input.orderId, 'orderId');
  const tenantId = requireNonEmptyString(input.tenantId, 'tenantId');
  const branchId = requireNonEmptyString(input.branchId, 'branchId');
  const staffId = requireNonEmptyString(input.staffId, 'staffId');
  const subtotalCents = requireCents(input.itemsSubtotalCents, 'itemsSubtotalCents');
  const taxCents = requireCents(input.taxCents, 'taxCents');
  const taxRate = requireRate(input.taxRate);
  const currency = requireNonEmptyString(input.currency, 'currency');
  const tenderedCents = requireCents(input.amountTenderedCents, 'amountTenderedCents');

  const totalCents = subtotalCents + taxCents;
  if (!Number.isSafeInteger(totalCents)) {
    throw new CashSaleError('totalCents', 'is not a safe integer');
  }
  if (tenderedCents < totalCents) {
    // Short cash is not a sale; it is a bug in the counter.
    throw new CashSaleError(
        'amountTenderedCents',
        `must be at least the total (${totalCents})`,
    );
  }
  const changeCents = tenderedCents - totalCents;

  const lines = snapshotLines(input.canonicalItems);
  const roles = Array.isArray(input.staffRoles) ?
    input.staffRoles.filter((role): role is string => typeof role === 'string') :
    [];
  const guestName = typeof input.guestName === 'string' && input.guestName.trim().length > 0 ?
    input.guestName.trim() :
    null;

  const order: Record<string, unknown> = {
    id: orderId,
    orderNumber: typeof input.orderNumber === 'string' && input.orderNumber.length > 0 ?
      input.orderNumber :
      null,
    // D-059/Q1: a walk-in has no account. Empty string is the shape OrderModel
    // already declares; the human trail is `staffId`.
    customerId: '',
    status: 'confirmed', // paid at the counter — the kitchen may start
    channel: 'counter',
    paymentMethod: 'cash',
    paymentRef: {kind: 'cash', tenderedCents, changeCents, staffUid: staffId},
    tenantId,
    branchId,
    staffId,
    items: input.canonicalItems,
    itemsSubtotalCents: subtotalCents,
    taxCents,
    taxRate,
    discountCents: 0,
    tipCents: 0,
    deliveryFeeCents: 0,
    totalCents,
    changeCents,
    createdAt: input.now,
    updatedAt: input.now,
  };
  if (roles.length > 0) order.staffRoles = roles;
  if (guestName !== null) order.guestName = guestName;

  const ledgerInput: SaleLedgerInput = {
    orderId,
    orderNumber: order.orderNumber,
    branchId,
    customerId: '',
    staffId,
    paymentMethod: 'cash',
    totalCents,
    taxCents,
    taxRate,
    items: lines,
    amountTenderedCents: tenderedCents,
    changeCents,
    currency,
    channel: 'counter',
    createdAt: input.now,
  };

  return {order, ledgerInput};
}

export interface CashVoid {
  orderPatch: Record<string, unknown>;
  reversalRow: Record<string, unknown>;
}

/**
 * Voids a cash sale: the order is cancelled and the ledger gains a reversal row.
 * A card sale is refused here on purpose — its money is undone through Stripe
 * (`cancelOrder`), and two ways to reverse one charge is how a ledger starts
 * disagreeing with a processor.
 */
export function buildCashVoid(input: {
  order: Record<string, unknown>;
  saleRow: Record<string, unknown>;
  reason: unknown;
  actorUid: unknown;
  now: unknown;
}): CashVoid {
  if (input.order.paymentMethod !== 'cash') {
    throw new CashSaleError(
        'paymentMethod',
        'must be \'cash\' — card refunds go through the Stripe path',
    );
  }
  const reason = requireNonEmptyString(input.reason, 'reason');
  const actorUid = requireNonEmptyString(input.actorUid, 'actorUid');
  // The order id is still validated — a void must name a real order — but it is
  // not written into the patch (the document keeps its own identity).
  requireNonEmptyString(input.order.id, 'order.id');
  const originalRowId = requireNonEmptyString(input.saleRow.id, 'saleRow.id');

  const reversalRow = buildReversalRow({
    originalRowId,
    original: input.saleRow,
    reason,
    actorUid,
    createdAt: input.now,
  });

  return {
    orderPatch: {
      status: 'cancelled',
      updatedAt: input.now,
      voidedAt: input.now,
      voidedBy: actorUid,
      voidReason: reason,
      // The order keeps its money fields: the reversal row is what says the
      // money came back. Rewriting the order's total would make two documents
      // disagree about the same sale. No `id` either — a patch never rewrites
      // the document's own identity.
    },
    reversalRow,
  };
}
