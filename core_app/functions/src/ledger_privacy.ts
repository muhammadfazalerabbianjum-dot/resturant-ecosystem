/**
 * C-9 / D-059 — the ledger meets the data subject.
 *
 * The erasure set (`collectUserDocs`) has never included `transactions`: a
 * ledger row is the taxable record of a sale, so it cannot be deleted. Until now
 * that also meant it kept `customerId` forever, and a DSAR could not reach it at
 * all — a compliance hole that cash rows (which add `staffId`) would have doubled.
 *
 * The ruling is retention + anonymisation: the identifiers are set to `null`,
 * `anonymisedAt` is stamped, and every amount, id and snapshot stays exactly as
 * written. Two properties matter and both are tested: the erasure never touches
 * another person's row, and a second pass writes nothing.
 *
 * No runtime import of firebase-admin, by the same reasoning as `ledger.ts`: the
 * shapes below are the small structural subset used here, so this file runs in
 * the `node --test` lane with a fake store and still accepts the real SDK.
 */

export const LEDGER_PRIVACY_COLLECTION = 'transactions';

/** Every field on a ledger row that can identify a person (D-059). */
export const IDENTIFIER_FIELDS = ['customerId', 'staffId', 'actorUid'] as const;

/**
 * How many rows one identifier may anonymise / export per pass. Bounded like
 * every other read cap in this codebase; a user past the cap is finished by the
 * next run of the hourly retrier (the marker stays `in_progress` until the whole
 * erasure succeeds, so nothing is silently half-done).
 */
export const K_LEDGER_PRIVACY_CAP = 500;

export interface PrivacyDocRef {
  readonly id: string;
}

export interface PrivacySnapshot {
  readonly docs: Array<{
    id: string;
    ref: unknown;
    data(): Record<string, unknown>;
  }>;
}

export interface PrivacyQuery {
  where(field: string, op: '==', value: unknown): PrivacyQuery;
  limit(n: number): PrivacyQuery;
  get(): Promise<PrivacySnapshot>;
}

export interface PrivacyBatch {
  update(ref: unknown, patch: Record<string, unknown>): void;
  commit(): Promise<void>;
}

export interface PrivacyStore {
  collection(name: string): PrivacyQuery;
  batch(): PrivacyBatch;
}

/**
 * The patch for one row: `{}` when the row is already anonymised or names nobody,
 * otherwise the identifier fields the row ACTUALLY has (never inventing a
 * `staffId` on a card row) plus the stamp.
 */
export function buildAnonymisationPatch(
    row: Record<string, unknown>,
    at: unknown,
): Record<string, unknown> {
  // `Object.hasOwn` needs lib es2022; this project targets older, so the
  // prototype call is the portable form (same semantics).
  const hasOwn = (key: string): boolean =>
    Object.prototype.hasOwnProperty.call(row, key);
  if (hasOwn('anonymisedAt') && row.anonymisedAt !== null) {
    return {};
  }
  const patch: Record<string, unknown> = {};
  for (const field of IDENTIFIER_FIELDS) {
    const value = row[field];
    if (hasOwn(field) && value !== null && value !== '') {
      patch[field] = null;
    }
  }
  if (Object.keys(patch).length === 0) return {};
  patch.anonymisedAt = at;
  return patch;
}

/**
 * Anonymises every row that names `uid` as customer, operator or actor. Returns
 * how many rows were changed, so a caller (and the erasure marker) can tell a
 * no-op from a real pass.
 */
export async function anonymiseLedgerRows(
    store: PrivacyStore,
    uid: string,
    at: unknown,
): Promise<number> {
  if (typeof uid !== 'string' || uid.length === 0) return 0;

  const seen = new Set<string>();
  const patches: Array<{ref: unknown; patch: Record<string, unknown>}> = [];

  for (const field of IDENTIFIER_FIELDS) {
    const snapshot = await store
        .collection(LEDGER_PRIVACY_COLLECTION)
        .where(field, '==', uid)
        .limit(K_LEDGER_PRIVACY_CAP)
        .get();

    for (const doc of snapshot.docs) {
      if (seen.has(doc.id)) continue; // a row may name the uid twice
      seen.add(doc.id);
      const patch = buildAnonymisationPatch(doc.data(), at);
      if (Object.keys(patch).length > 0) patches.push({ref: doc.ref, patch});
    }
  }

  if (patches.length === 0) return 0;
  const batch = store.batch();
  for (const {ref, patch} of patches) batch.update(ref, patch);
  await batch.commit();
  return patches.length;
}

/**
 * The caller's OWN ledger rows for the Art.15/20 export — the mirror of the
 * erasure. Bounded, and only by `customerId`: a staff member's export is their
 * purchases, not every sale they ever rang up.
 */
export async function collectLedgerRows(
    store: PrivacyStore,
    uid: string,
    cap: number = K_LEDGER_PRIVACY_CAP,
): Promise<Array<Record<string, unknown>>> {
  if (typeof uid !== 'string' || uid.length === 0) return [];
  const snapshot = await store
      .collection(LEDGER_PRIVACY_COLLECTION)
      .where('customerId', '==', uid)
      .limit(cap)
      .get();
  return snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
}
