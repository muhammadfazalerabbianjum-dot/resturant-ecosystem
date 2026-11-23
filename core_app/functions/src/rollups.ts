/**
 * P1-3 — daily rollups. A rollup is a CACHE: `daily_rollups/{branchId}_{day}`
 * can always be recomputed from the append-only ledger (handoff §8.1 A11,
 * §9.3). Nothing downstream may treat it as the source of truth, and no code in
 * this module ever reads a rollup to decide what the ledger contains.
 *
 * The computation is pure so the "rollup == from-scratch rebuild" assertion is
 * literal: `computeRollup` is what both the incremental path and a full rebuild
 * call, over the same rows.
 */

export const ROLLUP_COLLECTION = 'daily_rollups';
export const ROLLUP_SCHEMA_VERSION = 1;
export const UNKNOWN_CHANNEL = 'unknown';

export class RollupValidationError extends Error {
  readonly field: string;

  constructor(field: string, message: string) {
    super(`rollup: ${field} ${message}`);
    this.name = 'RollupValidationError';
    this.field = field;
  }
}

export interface RollupTotals {
  revenueByChannel: Record<string, number>;
  ordersCount: number;
  avgTicketCents: number;
  refundsCents: number;
}

function requireDay(day: unknown): string {
  if (typeof day !== 'string' || !/^\d{8}$/.test(day)) {
    throw new RollupValidationError('day', 'must be yyyyMMdd');
  }
  return day;
}

/** One rollup document per branch-day — the id is derived, never stored twice. */
export function rollupDocId(branchId: unknown, day: unknown): string {
  if (typeof branchId !== 'string' || branchId.trim().length === 0) {
    throw new RollupValidationError('branchId', 'must be a non-empty string');
  }
  return `${branchId}_${requireDay(day)}`;
}

/**
 * Sums one branch-day's rows. Sales add; reversals subtract from revenue and
 * are reported separately as refunds, so a reversed sale never disappears from
 * the count of what was sold.
 */
export function computeRollup(
    rows: readonly Record<string, unknown>[],
): RollupTotals {
  const revenueByChannel: Record<string, number> = {};
  let ordersCount = 0;
  let grossCents = 0;
  let refundsCents = 0;

  for (const row of rows) {
    const channel =
      typeof row.channel === 'string' && row.channel.length > 0 ?
        row.channel :
        UNKNOWN_CHANNEL;

    if (row.kind === 'sale') {
      const cents = centsOf(row.totalCents, 'totalCents');
      ordersCount += 1;
      grossCents += cents;
      revenueByChannel[channel] = (revenueByChannel[channel] ?? 0) + cents;
      continue;
    }

    if (row.kind === 'reversal') {
      const cents = Math.abs(centsOf(row.totalCents, 'totalCents'));
      refundsCents += cents;
      revenueByChannel[channel] = (revenueByChannel[channel] ?? 0) - cents;
      continue;
    }

    throw new RollupValidationError('kind', 'must be sale or reversal');
  }

  return {
    revenueByChannel,
    ordersCount,
    avgTicketCents: ordersCount === 0 ? 0 : Math.round(grossCents / ordersCount),
    refundsCents,
  };
}

function centsOf(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new RollupValidationError(field, 'must be an integer number of cents');
  }
  return value;
}

/** The structural subset of Firestore this module needs (see ledger.ts). */
export interface RollupDocRef {
  readonly id: string;
}

export interface RollupSnapshot {
  readonly exists: boolean;
  data?(): Record<string, unknown> | undefined;
}

export interface RollupTransaction {
  get(ref: RollupDocRef): Promise<RollupSnapshot>;
  set(ref: RollupDocRef, data: Record<string, unknown>): void;
}

export interface RollupStore {
  collection(name: string): {doc(id: string): RollupDocRef};
  runTransaction<T>(update: (tx: RollupTransaction) => Promise<T>): Promise<T>;
}

export interface RebuildResult extends RollupTotals {
  id: string;
  version: number;
}

/**
 * Recomputes one branch-day from `rows` (which the caller read from the ledger)
 * and compare-and-sets the cache document on `version`. A rollup document is
 * always a pure function of the ledger rows passed here; the stored version is
 * bookkeeping for readers, never an input to the sums.
 */
export async function rebuildDailyRollup(
    store: RollupStore,
    branchId: unknown,
    day: unknown,
    rows: readonly Record<string, unknown>[],
    updatedAt?: unknown,
): Promise<RebuildResult> {
  const id = rollupDocId(branchId, day);
  const totals = computeRollup(rows);

  return store.runTransaction(async (tx) => {
    const ref = store.collection(ROLLUP_COLLECTION).doc(id);
    const existing = await tx.get(ref);
    const previous = existing.exists ? existing.data?.() ?? {} : {};
    const version = Number.isInteger(previous.version) ?
      (previous.version as number) + 1 :
      1;

    const doc: Record<string, unknown> = {
      id,
      schemaVersion: ROLLUP_SCHEMA_VERSION,
      branchId,
      day,
      ...totals,
      version,
    };
    if (updatedAt !== undefined) doc.updatedAt = updatedAt;

    tx.set(ref, doc);
    return {...totals, id, version};
  });
}
