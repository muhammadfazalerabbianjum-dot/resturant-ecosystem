/**
 * BACKEND-2 (W7.4, 06-P1-4): staff authorization for privileged callables,
 * extracted into a pure module (no firebase-admin import) so `node --test`
 * can exercise the decision logic against the compiled `../lib/access.js` —
 * mirroring the ddos.ts / payment.ts pattern.
 *
 * The role vocabulary mirrors the client's `UserRole` enum
 * (packages/core/lib/data/models/user_model.dart: owner, manager, kitchen,
 * delivery, customer — documented as "Roles that can be assigned to staff
 * users", serialized as `object.name`). The `syncUserRoleClaims` Firestore
 * trigger (index.ts §8) denormalizes `users/{uid}.role` into the JWT custom
 * claim `role`, so a verified ID token carries exactly these literals.
 */

import {isStaleClaims} from './claims';
import {canAny, type Capability} from './permissions';

export type StaffRole = 'owner' | 'manager' | 'kitchen' | 'delivery';

/** The JWT `role` claim values that authorize staff-only callables. */
export const STAFF_ROLES: readonly StaffRole[] = [
  'owner',
  'manager',
  'kitchen',
  'delivery',
];

/** Result of the fail-closed staff gate (assertStaffRole). */
export interface StaffCheckResult {
  ok: boolean;
  /** The verified staff role (null when rejected). */
  role: StaffRole | null;
  /** Machine-readable rejection reason (null when ok). */
  reason:
    | 'missing_auth_context'
    | 'missing_role_claim'
    | 'role_not_staff'
    | null;
}

/**
 * Minimal shape of the v2 onCall auth context the gate needs. Structural:
 * the production wrapper passes `request.auth` unchanged.
 */
export interface StaffAuthContext {
  uid?: string;
  /** The decoded ID token claims. Kept `unknown` so this pure module compiles
   *  without firebase-admin's `DecodedIdToken` type (also a weak-type guard:
   *  the claim is parsed defensively, never trusted structurally). */
  token?: unknown;
}

/**
 * BACKEND-2 (W7.4/T-3): fail-closed staff gate for `dispatchToFleet`.
 * The caller must be authenticated AND carry a verified `role` custom claim
 * inside the STAFF_ROLES allowlist. A missing auth context, a missing or
 * non-string claim, or the 'customer' role (any other literal) is rejected
 * with the exact reason — the onCall wrapper maps every !ok result to
 * `permission-denied`. A client-supplied role field is NEVER trusted: the
 * only source is the server-side claim minted by syncUserRoleClaims.
 */
export function assertStaffRole(
    auth: StaffAuthContext | null | undefined,
): StaffCheckResult {
  if (!auth || typeof auth !== 'object') {
    return {ok: false, role: null, reason: 'missing_auth_context'};
  }
  const role =
    auth.token && typeof auth.token === 'object' && 'role' in auth.token ?
      (auth.token as Record<string, unknown>).role :
      undefined;
  if (typeof role !== 'string' || role.length === 0) {
    return {ok: false, role: null, reason: 'missing_role_claim'};
  }
  if (!(STAFF_ROLES as readonly string[]).includes(role)) {
    return {ok: false, role: null, reason: 'role_not_staff'};
  }
  return {ok: true, role: role as StaffRole, reason: null};
}

/** Result of the Phase 1 capability gate (assertCapability). */
export interface CapabilityCheckResult {
  ok: boolean;
  /** The capability that was demanded (echoed for the caller's error message). */
  capability: Capability;
  /** The roles the caller actually presented (empty when the claim was absent). */
  roles: readonly string[];
  /** Machine-readable rejection reason (null when ok). */
  reason:
    | 'missing_auth_context'
    | 'missing_role_claim'
    | 'capability_not_granted'
    | 'stale_claims'
    | null;
}

/**
 * Optional freshness requirement (P1-5): the `claimsVersion` the caller's
 * users document currently carries. When supplied, a token minted before the
 * last privilege change is rejected even though its roles still look valid.
 */
export interface CapabilityFreshness {
  claimsVersion: number;
}

/**
 * Phase 1 (P1-1): capability gate for staff handlers — the single place a
 * server action asks "may this caller do this?".
 *
 * Reads the `roles` claim (a set, per handoff §2.1: one person may be counter
 * AND floor) and falls back to the legacy single `role` claim so both claim
 * shapes authorise during the migration. Anything else — no auth context, no
 * string roles, an unknown role, a capability nobody holds — is rejected with
 * a named reason; the onCall wrapper maps every !ok to `permission-denied`.
 * A role sent in the request payload is never consulted.
 */
export function assertCapability(
    auth: StaffAuthContext | null | undefined,
    capability: Capability,
    freshness?: CapabilityFreshness,
): CapabilityCheckResult {
  if (!auth || typeof auth !== 'object') {
    return {ok: false, capability, roles: [], reason: 'missing_auth_context'};
  }
  const claims =
    auth.token && typeof auth.token === 'object' ?
      (auth.token as Record<string, unknown>) :
      null;
  const roles: string[] = Array.isArray(claims?.roles) ?
    (claims?.roles as unknown[]).filter((r): r is string => typeof r === 'string') :
    [];
  const legacyRole = claims?.role;
  if (roles.length === 0 && typeof legacyRole === 'string' && legacyRole.length > 0) {
    roles.push(legacyRole);
  }
  if (roles.length === 0) {
    return {ok: false, capability, roles, reason: 'missing_role_claim'};
  }
  if (!canAny(roles, capability)) {
    return {ok: false, capability, roles, reason: 'capability_not_granted'};
  }
  // A granted capability is still refused by a token minted before the caller's
  // privileges last changed: revocation stops new tokens, this stops the old one.
  if (freshness && isStaleClaims(claims, freshness.claimsVersion)) {
    return {ok: false, capability, roles, reason: 'stale_claims'};
  }
  return {ok: true, capability, roles, reason: null};
}

/**
 * The onCall error code a failed capability gate must become, or null when the
 * gate passed. Kept separate from the handler so the mapping is testable
 * without firebase-admin: every denial is `permission-denied` (never
 * `unauthenticated`, which would tell an anonymous caller their guess was a
 * permissions problem rather than a session problem).
 */
export function capabilityDenialCode(
    result: CapabilityCheckResult,
): 'permission-denied' | null {
  return result.ok ? null : 'permission-denied';
}
