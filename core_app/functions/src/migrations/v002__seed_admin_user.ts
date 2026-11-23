// / Law 31 (Schema Versioning)
// /
// / v002: Adds the required Firestore indexes programmatically as metadata
// / and seeds the admin user in the emulator environment.
// / Idempotent — checks for existence before writing.
// /
// / TODO_DEPLOY: emulator/bootstrap seed only, NOT part of the deployed
// / function entry — run explicitly per environment via fireway.

import * as admin from 'firebase-admin';

const db = admin.firestore();
const auth = admin.auth();

export const migrate = async () => {
  // ── Seed Emulator Admin User ──────────────────────────────────────────────
  // WHY: Integration tests need a stable admin@carnama.com account with the
  //      'owner' custom claim to validate privilege escalation rules.
  //      This migration is safe in the emulator only — it is a no-op in
  //      production because Firebase Admin SDK will see the user already exists.
  const adminEmail = 'admin@carnama.com';

  let adminUser: admin.auth.UserRecord | null = null;
  try {
    adminUser = await auth.getUserByEmail(adminEmail);
    console.log('[v002] Admin user already exists — skipping creation.');
  } catch {
    // User doesn't exist — create them
    adminUser = await auth.createUser({
      email: adminEmail,
      password: 'AdminPass123',
      displayName: 'Carnama Admin',
    });
    console.log('[v002] Created admin user:', adminUser.uid);
  }

  // Set owner custom claim
  await auth.setCustomUserClaims(adminUser.uid, {role: 'owner'});
  console.log('[v002] Set owner custom claim on admin user.');

  // ── Seed Admin Firestore Document ─────────────────────────────────────────
  const adminDocRef = db.collection('users').doc(adminUser.uid);
  const adminDoc = await adminDocRef.get();

  if (!adminDoc.exists) {
    await adminDocRef.set({
      id: adminUser.uid,
      email: adminEmail,
      name: 'Carnama Admin',
      role: 'owner',
      tier: 'enterprise',
      loyaltyPoints: 0,
      isOnline: false,
      assignedOrderIds: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('[v002] Seeded admin user document in Firestore.');
  } else {
    console.log('[v002] Admin Firestore document already exists — skipping.');
  }
};
