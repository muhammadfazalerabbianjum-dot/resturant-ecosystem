// / v004__tenancy_backfill — P1-6.
// /
// / ONE shared Firebase project serves every client, separated by `tenantId`
// / (handoff §7.1, owner ruling A1). Every existing document predates that field,
// / so every existing document gets it.
// /
// / DRY RUN IS THE DEFAULT. Nothing is written unless MIGRATION_APPLY=true.
// / Conflicts (a document already carrying a DIFFERENT tenantId) are reported and
// / skipped — never reassigned. Re-running is safe and a no-op: the planner only
// / emits a write when the value is absent, so the second run plans zero.
// /
// / Run manually: npx fireway migrate --project <project>
// /               MIGRATION_APPLY=true npx fireway migrate --project <project>
// /
// / DEPLOY ORDERING (D-032, Q-004): this must run BEFORE the P1-5 trigger and the
// / P1-4 rules, or staff lose claims and clients lose their own reads.

import * as admin from 'firebase-admin';

import {
  DEFAULT_TENANT_ID,
  planSettingsRename,
  planTenancyBackfill,
  type DocRow,
} from './plans';

/** Every top-level collection in firestore.rules, plus the collections the
 *  server writes (`transactions`, `daily_rollups`, `order_events`). */
export const TENANCY_COLLECTIONS: readonly string[] = [
  'admins',
  'analyticsEvents',
  'audit_log',
  'audit_logs',
  'branches',
  'carts',
  'daily_rollups',
  'deletion_requests',
  'deliveries',
  'driverLocations',
  'locations',
  'loyalty',
  'menus',
  'notification_queue',
  'notifications',
  'order_events',
  'orders',
  'presence',
  'promoCodes',
  'promo_usage',
  'promotions',
  'proof_of_delivery',
  'reservation_counters',
  'reservation_locks',
  'reservations',
  'settings',
  'transactions',
  'users',
  'waitlist',
  'waitlist_counters',
];

/** Reports the plan; writes only when explicitly told to. */
export async function applyTenancyBackfill(
    db: admin.firestore.Firestore,
    options: {apply: boolean; tenantId?: string},
): Promise<{
  applied: number;
  planned: number;
  conflicts: string[];
  unchanged: number;
}> {
  const tenantId = options.tenantId ?? DEFAULT_TENANT_ID;
  let applied = 0;
  let planned = 0;
  let unchanged = 0;
  const conflicts: string[] = [];

  for (const collection of TENANCY_COLLECTIONS) {
    const snap = await db.collection(collection).get();
    const rows: DocRow[] = snap.docs.map((doc) => ({path: doc.ref.path, data: doc.data()}));
    const plan = planTenancyBackfill(rows, tenantId);

    planned += plan.writes.length;
    unchanged += plan.unchanged;
    conflicts.push(...plan.conflicts);

    if (!options.apply || plan.writes.length === 0) continue;

    // Firestore caps a batch at 500 writes.
    for (let i = 0; i < plan.writes.length; i += 400) {
      const batch = db.batch();
      for (const write of plan.writes.slice(i, i + 400)) {
        batch.set(db.doc(write.path), {tenantId: write.data.tenantId}, {merge: true});
      }
      await batch.commit();
      applied += plan.writes.slice(i, i + 400).length;
    }
  }

  console.log(
      `[v004] tenant=${tenantId} apply=${options.apply} planned=${planned} ` +
      `applied=${applied} unchanged=${unchanged} conflicts=${conflicts.length}`,
  );
  for (const conflict of conflicts) {
    console.error(`[v004] CONFLICT (left untouched): ${conflict}`);
  }

  return {applied, planned, conflicts, unchanged};
}

/**
 * D-038 consequence 1: settings documents become `${tenantId}_${name}`.
 *
 * Same contract as the backfill: dry run by default, a second run plans zero,
 * and a document claimed by another tenant is reported and left alone. The source
 * document is copied, not deleted, so the migration is reversible by hand.
 */
export async function applySettingsRename(
    db: admin.firestore.Firestore,
    options: {apply: boolean; tenantId?: string},
): Promise<{applied: number; planned: number; conflicts: string[]; unchanged: number}> {
  const tenantId = options.tenantId ?? DEFAULT_TENANT_ID;
  const snap = await db.collection('settings').get();
  const rows: DocRow[] = snap.docs.map((doc) => ({path: doc.ref.path, data: doc.data()}));
  const plan = planSettingsRename(rows, tenantId);

  let applied = 0;
  if (options.apply && plan.writes.length > 0) {
    for (let i = 0; i < plan.writes.length; i += 400) {
      const batch = db.batch();
      for (const write of plan.writes.slice(i, i + 400)) {
        batch.set(db.doc(write.to), write.data, {merge: true});
      }
      await batch.commit();
      applied += plan.writes.slice(i, i + 400).length;
    }
  }

  console.log(
      `[v004/settings] tenant=${tenantId} apply=${options.apply} ` +
      `planned=${plan.writes.length} applied=${applied} ` +
      `unchanged=${plan.unchanged} conflicts=${plan.conflicts.length}`,
  );
  for (const conflict of plan.conflicts) {
    console.error(`[v004/settings] CONFLICT (left untouched): ${conflict}`);
  }

  return {
    applied,
    planned: plan.writes.length,
    conflicts: plan.conflicts,
    unchanged: plan.unchanged,
  };
}

export const migrate = async () => {
  const db = admin.firestore();
  const options = {
    apply: process.env.MIGRATION_APPLY === 'true',
    tenantId: process.env.MIGRATION_TENANT_ID,
  };
  const backfill = await applyTenancyBackfill(db, options);
  // Ordering (D-041 applied to configuration): the field backfill runs first so a
  // copied settings document is never created without its tenantId.
  const settings = await applySettingsRename(db, options);
  return {backfill, settings};
};
