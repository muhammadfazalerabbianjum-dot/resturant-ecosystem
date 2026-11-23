// / Law 31 (Fireway Schema Versioning)
// /
// / Fireway runs sequential migration scripts against Firestore, preventing
// / schema drift between app versions. Each migration is idempotent and
// / tagged with a version prefix so it runs exactly once per environment.
// /
// / Run manually: npx fireway migrate --project demo-carnama
// / In CI:        npx fireway migrate --require ts-node/register
// /               (see carnama_ci.yml for integration)
// /
// / TODO_DEPLOY: this is a dev/bootstrap SEED, NOT part of the deployed
// / function entry. It lives in src/migrations only so `tsc` type-checks it;
// / `lib/index.js` never imports it, so it ships nowhere. Run it explicitly
// / per environment via fireway.

import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * v001__seed_branches.ts
 * WHY: Ensures every environment starts with at least one branch document.
 * Without this, the app cannot route menu items or assign staff to branches.
 */
export const migrate = async () => {
  const branchesRef = db.collection('branches');

  const existing = await branchesRef.limit(1).get();
  if (!existing.empty) {
    console.log('[v001] Branches collection already seeded — skipping.');
    return;
  }

  const batch = db.batch();

  const mainBranch = branchesRef.doc('branch_main');
  batch.set(mainBranch, {
    name: 'Main Branch',
    address: 'Downtown Food Court, Level 2',
    latitude: 25.2048,
    longitude: 55.2708,
    deliveryRadiusMiles: 5.0,
    isDefault: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  console.log('[v001] Seeded main branch document.');
};
