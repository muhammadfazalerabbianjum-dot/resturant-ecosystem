/**
 * P1-6 — backfill planning, as pure functions.
 *
 * The migrations themselves are thin admin-SDK wrappers; everything that decides
 * WHICH documents change lives here, so `node --test` can assert the property the
 * card actually demands: **a second run plans zero changes**, and a document that
 * already belongs to a different tenant is refused instead of overwritten.
 *
 * Two rules, both deliberate:
 *  - never guess a tenant. A document with no `tenantId` gets the target tenant;
 *    a document with a DIFFERENT `tenantId` is a conflict, reported and left
 *    alone. Silently reassigning a restaurant's data to another client is the
 *    worst bug this programme could ship.
 *  - never invent authority. `roles[]` is derived from the existing single `role`
 *    only when `roles[]` is absent; `branchIds[]` from `branchId`. Existing
 *    authority is never widened.
 */

export const DEFAULT_TENANT_ID = 'halal-boyz';

export class MigrationConflictError extends Error {
  readonly docPath: string;

  constructor(docPath: string, message: string) {
    super(`migration conflict at ${docPath}: ${message}`);
    this.name = 'MigrationConflictError';
    this.docPath = docPath;
  }
}

/** One planned document write. */
export interface PlannedWrite {
  path: string;
  data: Record<string, unknown>;
}

export interface PlanResult {
  writes: PlannedWrite[];
  /** Documents that already carry a different tenant — never written. */
  conflicts: string[];
  /** Documents already in the target shape. */
  unchanged: number;
}

export interface DocRow {
  path: string;
  data: Record<string, unknown> | undefined;
}

/**
 * v004: every document in every collection gets `tenantId`. Idempotent because a
 * document that already carries the target tenant is `unchanged`, so a second run
 * over the same input plans nothing.
 */
export function planTenancyBackfill(
    docs: readonly DocRow[],
    tenantId: string = DEFAULT_TENANT_ID,
): PlanResult {
  if (typeof tenantId !== 'string' || tenantId.trim().length === 0) {
    throw new MigrationConflictError('<tenant>', 'target tenantId must be non-empty');
  }

  const writes: PlannedWrite[] = [];
  const conflicts: string[] = [];
  let unchanged = 0;

  for (const doc of docs) {
    const data = doc.data ?? {};
    const current = data.tenantId;
    if (current === tenantId) {
      unchanged += 1;
      continue;
    }
    if (current !== undefined && current !== null && current !== '') {
      // A different tenant already claims this document: human decision required.
      conflicts.push(doc.path);
      continue;
    }
    writes.push({path: doc.path, data: {...data, tenantId}});
  }

  return {writes, conflicts, unchanged};
}

/** One settings document that moves to its tenant-prefixed name (D-038). */
export interface RenameWrite {
  from: string;
  to: string;
  data: Record<string, unknown>;
}

export interface RenamePlan {
  writes: RenameWrite[];
  conflicts: string[];
  /** Documents already in the target shape, including an already-migrated pair. */
  unchanged: number;
}

/**
 * D-038 consequence 1: the flat settings collection keeps its documents but each
 * is keyed `${tenantId}_${name}` and carries `tenantId`.
 *
 * This is a COPY, not a move, because D-038 says copy: the source document is left
 * in place, so a bad migration is recoverable by deleting the copy. A document
 * whose target already exists is `unchanged`, which is what makes a second run
 * plan zero writes even though the source is still there.
 */
export function planSettingsRename(
    docs: readonly DocRow[],
    tenantId: string = DEFAULT_TENANT_ID,
): RenamePlan {
  if (typeof tenantId !== 'string' || tenantId.trim().length === 0) {
    throw new MigrationConflictError('<tenant>', 'target tenantId must be non-empty');
  }

  const byPath = new Map<string, Record<string, unknown> | undefined>();
  for (const doc of docs) byPath.set(doc.path, doc.data);

  const writes: RenameWrite[] = [];
  const conflicts: string[] = [];
  let unchanged = 0;
  const prefix = `settings/${tenantId}_`;

  for (const doc of docs) {
    if (!doc.path.startsWith('settings/')) continue;
    const name = doc.path.slice('settings/'.length);
    // Already tenant-prefixed for THIS tenant: nothing to do. A nested path
    // (`settings/a/b`) cannot be a settings document and is ignored, not guessed.
    if (name.includes('/')) continue;
    if (`settings/${name}` === doc.path && name.startsWith(`${tenantId}_`)) {
      unchanged += 1;
      continue;
    }

    const data = doc.data ?? {};
    const current = data.tenantId;
    if (current !== undefined && current !== null && current !== '' && current !== tenantId) {
      conflicts.push(doc.path);
      continue;
    }

    const targetPath = `${prefix}${name}`;
    if (byPath.has(targetPath)) {
      const target = byPath.get(targetPath) ?? {};
      if (target.tenantId === tenantId) {
        unchanged += 1;
        continue;
      }
      conflicts.push(targetPath);
      continue;
    }

    writes.push({from: doc.path, to: targetPath, data: {...data, tenantId}});
  }

  return {writes, conflicts, unchanged};
}

/**
 * v005: staff documents gain `roles[]` and `branchIds[]`, derived from the legacy
 * single fields. Admin/owner documents without a role are skipped, not promoted.
 */
export function planRolesBackfill(docs: readonly DocRow[]): PlanResult {
  const writes: PlannedWrite[] = [];
  const conflicts: string[] = [];
  let unchanged = 0;

  for (const doc of docs) {
    const data = doc.data ?? {};
    const hasRoles = Array.isArray(data.roles);
    const hasBranches = Array.isArray(data.branchIds);
    if (hasRoles && hasBranches) {
      unchanged += 1;
      continue;
    }

    const legacyRole = data.role;
    const legacyBranch = data.branchId;

    // A present-but-unusable roles field is corruption: refuse, do not overwrite.
    if (data.roles !== undefined && data.roles !== null && !hasRoles) {
      conflicts.push(doc.path);
      continue;
    }

    if (!hasRoles && (typeof legacyRole !== 'string' || legacyRole.trim().length === 0)) {
      // No role anywhere: a customer or an empty profile. Nothing to derive.
      unchanged += 1;
      continue;
    }

    const next: Record<string, unknown> = {...data};
    if (!hasRoles) next.roles = [legacyRole];
    if (!hasBranches) {
      next.branchIds =
          typeof legacyBranch === 'string' && legacyBranch.trim().length > 0 ?
            [legacyBranch] :
            [];
    }
    writes.push({path: doc.path, data: next});
  }

  return {writes, conflicts, unchanged};
}
