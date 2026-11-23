// / v005__roles_backfill — P1-6.
// /
// / Authority becomes a SET (handoff §8.2, §8.3): `users.roles[]` and
// / `users.branchIds[]` are the truth, and `role`/`branchId` stay as derived
// / legacy fields so older clients keep working.
// /
// / Derivation only, never invention: an existing single `role` becomes a
// / one-element `roles[]`; a missing role leaves the document alone. A present but
// / malformed `roles` field is a conflict and is not overwritten.
// /
// / DRY RUN IS THE DEFAULT (MIGRATION_APPLY=true to write), and a second run plans
// / zero writes.

import * as admin from 'firebase-admin';

import {planRolesBackfill, type DocRow} from './plans';

export async function applyRolesBackfill(
    db: admin.firestore.Firestore,
    options: {apply: boolean},
): Promise<{applied: number; planned: number; conflicts: string[]; unchanged: number}> {
  const snap = await db.collection('users').get();
  const rows: DocRow[] = snap.docs.map((doc) => ({path: doc.ref.path, data: doc.data()}));
  const plan = planRolesBackfill(rows);

  let applied = 0;
  if (options.apply && plan.writes.length > 0) {
    for (let i = 0; i < plan.writes.length; i += 400) {
      const batch = db.batch();
      for (const write of plan.writes.slice(i, i + 400)) {
        const {roles, branchIds} = write.data;
        batch.set(db.doc(write.path), {roles, branchIds}, {merge: true});
      }
      await batch.commit();
      applied += Math.min(400, plan.writes.length - i);
    }
  }

  console.log(
      `[v005] apply=${options.apply} planned=${plan.writes.length} ` +
      `applied=${applied} unchanged=${plan.unchanged} conflicts=${plan.conflicts.length}`,
  );
  for (const conflict of plan.conflicts) {
    console.error(`[v005] CONFLICT (left untouched): ${conflict}`);
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
  return applyRolesBackfill(db, {apply: process.env.MIGRATION_APPLY === 'true'});
};
