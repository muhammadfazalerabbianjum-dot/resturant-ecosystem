/**
 * P1-5 — the JWT custom-claim shape, derived from `users/{uid}`.
 *
 * Handoff §8.2 (claims grow to `tenantId`, `roles[]`, `branchIds[]`) and §8.3
 * (`roles`/`branchIds` are authority, `role`/`branchId` are derived legacy
 * fields). The token is the only thing a rules block or a callable can read
 * without another Firestore lookup, so the claim document and the user document
 * must be built by ONE function — `buildUserClaims` — or they drift.
 *
 * Privilege change is a security event: a promoted user must not keep an old
 * token's authority, and a demoted user must lose it immediately. So every plan
 * carries `revoke`: true when the privilege-bearing fields changed, and the
 * trigger then calls `revokeRefreshTokens`. A token minted before that change
 * also carries an older `claimsVersion`, which `isStaleClaims` rejects even if it
 * has not yet expired (a revoked refresh token stops NEW tokens; this stops the
 * one already in flight).
 *
 * Pure module (no firebase-admin) so `node --test` exercises the compiled
 * `../lib/claims.js`, mirroring permissions.ts / access.ts.
 */

import {ROLES, type Role} from './permissions';

export const CLAIMS_SCHEMA_VERSION = 1;

/** The `users/{uid}` fields that carry authority (everything else is cosmetic). */
export interface UserPrivilegeDoc {
  tenantId?: unknown;
  roles?: unknown;
  branchIds?: unknown;
  role?: unknown;
  claimsVersion?: unknown;
}

/** The custom claims this project mints. Legacy `role` stays for old code. */
export interface UserClaims {
  schemaVersion: number;
  tenantId: string;
  roles: Role[];
  branchIds: string[];
  claimsVersion: number;
  role?: Role;
}

export class ClaimsValidationError extends Error {
  readonly field: string;

  constructor(field: string, message: string) {
    super(`claims: ${field} ${message}`);
    this.name = 'ClaimsValidationError';
    this.field = field;
  }
}

function stringList(value: unknown, field: string): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) {
    throw new ClaimsValidationError(field, 'must be an array of strings');
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== 'string' || item.trim().length === 0) {
      throw new ClaimsValidationError(field, 'must contain only non-empty strings');
    }
    if (!out.includes(item)) out.push(item);
  }
  return out;
}

/**
 * Shapes the claims for one user document. Throws rather than minting a token
 * with a guessed tenant: a user without `tenantId` is a backfill bug, and a
 * claim is not the place to paper over it.
 */
export function buildUserClaims(doc: UserPrivilegeDoc): UserClaims {
  if (!doc || typeof doc !== 'object') {
    throw new ClaimsValidationError('doc', 'must be a user document');
  }
  const tenantId = doc.tenantId;
  if (typeof tenantId !== 'string' || tenantId.trim().length === 0) {
    throw new ClaimsValidationError('tenantId', 'must be a non-empty string');
  }

  const declared = stringList(doc.roles, 'roles');
  const legacy = typeof doc.role === 'string' && doc.role.length > 0 ? [doc.role] : [];
  const raw = declared.length > 0 ? declared : legacy;
  if (raw.length === 0) {
    throw new ClaimsValidationError('roles', 'must name at least one role');
  }

  const roles: Role[] = [];
  for (const role of raw) {
    if (!(ROLES as readonly string[]).includes(role)) {
      // Fail closed: an unknown role in the document is data corruption or an
      // attempt to smuggle an authority the table has never heard of.
      throw new ClaimsValidationError('roles', `contains unknown role "${role}"`);
    }
    if (!roles.includes(role as Role)) roles.push(role as Role);
  }

  const branchIds = stringList(doc.branchIds, 'branchIds').sort();

  const version = doc.claimsVersion;
  if (version !== undefined && version !== null &&
      (!Number.isInteger(version) || (version as number) < 1)) {
    throw new ClaimsValidationError('claimsVersion', 'must be a positive integer');
  }

  const claims: UserClaims = {
    schemaVersion: CLAIMS_SCHEMA_VERSION,
    tenantId,
    roles,
    branchIds,
    claimsVersion: (version as number | undefined) ?? 1,
  };
  // Legacy single-role claim: only when it is unambiguous, never a guess.
  if (roles.length === 1) claims.role = roles[0];
  return claims;
}

/** The authority-bearing subset, order-independent — what a change is judged on. */
export function claimsFingerprint(claims: UserClaims | null): string {
  if (!claims) return 'none';
  return JSON.stringify([
    claims.tenantId,
    [...claims.roles].sort(),
    [...claims.branchIds].sort(),
  ]);
}

function claimsOrNull(doc: UserPrivilegeDoc | undefined | null): UserClaims | null {
  if (!doc) return null;
  try {
    return buildUserClaims(doc);
  } catch {
    return null;
  }
}

export interface ClaimSyncPlan {
  /** Claims to write, or null when the user must lose every claim. */
  claims: UserClaims | null;
  /** True when authority changed and refresh tokens must be revoked. */
  revoke: boolean;
}

/**
 * Decides what the `users/{uid}` trigger should do. A privilege change bumps
 * `claimsVersion` so tokens minted before it are stale; a non-authority edit
 * (name, phone, locale) neither bumps it nor revokes anything, so signing every
 * staff member out on a profile edit is impossible.
 */
export function planClaimSync(
    before: UserPrivilegeDoc | undefined | null,
    after: UserPrivilegeDoc | undefined | null,
): ClaimSyncPlan {
  const next = claimsOrNull(after);
  const previous = claimsOrNull(before);
  if (!next) {
    return {claims: null, revoke: previous !== null};
  }

  const changed = claimsFingerprint(previous) !== claimsFingerprint(next);
  if (!changed) return {claims: next, revoke: false};

  return {
    claims: {...next, claimsVersion: (previous?.claimsVersion ?? 0) + 1},
    revoke: true,
  };
}

/**
 * True when a presented token was minted before the user's current privileges.
 * Missing or non-integer versions are stale: an old token has no version at all.
 */
export function isStaleClaims(token: unknown, expectedVersion: number): boolean {
  const claims = token && typeof token === 'object' ?
    (token as Record<string, unknown>) :
    null;
  const version = claims?.claimsVersion;
  return !Number.isInteger(version) || (version as number) < expectedVersion;
}
