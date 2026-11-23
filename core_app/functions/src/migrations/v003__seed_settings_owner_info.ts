// / Law 31 (Schema Versioning)
// /
// / v003: Seeds `settings/ownerInfo { ownerEmail, updatedAt }` from the
// / owner-claim user.
// /
// / WHY (01-P1-C): `isOwner()` (firestore.rules:47-52) requires
// / `settings/ownerInfo.ownerEmail` to equal the caller's auth-token email.
// / Without this document EVERY owner-gated write/upload fails out-of-the-box
// / on a fresh backend. v002 provisions the owner-claim user this migration
// / reads — run v002 FIRST, then v003 (runbook Step 8 order).
// /
// / Idempotent — an existing `settings/ownerInfo` doc is authoritative and is
// / never silently overwritten (doc.exists guard, v002 pattern).
// /
// / TODO_DEPLOY: emulator/bootstrap seed only, NOT part of the deployed
// / function entry — never imported by index.ts (grep gate: `v003` in
// / index.ts = 0).

import * as admin from 'firebase-admin';

const db = admin.firestore();
const auth = admin.auth();

const OWNER_EMAIL = 'admin@carnama.com';

export const migrate = async (): Promise<void> => {
  // ── Idempotent fast path (v002 pattern) ──────────────────────────────────
  // An existing ownerInfo doc wins: this migration bootstraps a FRESH
  // backend; it never mutates operator-managed state on re-runs.
  const ownerInfoRef = db.collection('settings').doc('ownerInfo');
  const existing = await ownerInfoRef.get();
  if (existing.exists) {
    console.log('[v003] settings/ownerInfo already exists — skipping.');
    return;
  }

  // ── Resolve the owner-claim user provisioned by v002 (fail-closed) ───────
  // Never guess an owner: seed only from an account that verifiably holds
  // the role=owner claim, otherwise isOwner() would grant ownership to an
  // unprovisioned email.
  let owner: admin.auth.UserRecord;
  try {
    owner = await auth.getUserByEmail(OWNER_EMAIL);
  } catch {
    throw new Error(
        '[v003] No user account for admin@carnama.com — run v002__seed_admin_user ' +
        'first (fail-closed: refusing to seed ownerInfo from an unprovisioned user).',
    );
  }
  if (owner.customClaims?.role !== 'owner') {
    throw new Error(
        '[v003] admin@carnama.com holds no role=owner custom claim — run ' +
        'v002__seed_admin_user first (fail-closed: refusing to seed from a non-owner).',
    );
  }

  await ownerInfoRef.set({
    ownerEmail: OWNER_EMAIL,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`[v003] Seeded settings/ownerInfo { ownerEmail: ${OWNER_EMAIL} }.`);
};

// ── Standalone execution (runbook Step 8) ──────────────────────────────────
// The runbook runs this file directly (`node lib/migrations/v003__...js`).
// Without this guard the module would load and silently exit — a fake
// success. Direct execution runs the migration and exits non-zero on
// failure.
if (require.main === module) {
  migrate()
      .then(() => {
        console.log('[v003] Migration complete.');
        process.exit(0);
      })
      .catch((err: unknown) => {
        console.error('[v003] Migration FAILED:', err);
        process.exit(1);
      });
}
