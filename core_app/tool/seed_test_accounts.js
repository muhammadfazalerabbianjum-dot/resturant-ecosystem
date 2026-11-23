/**
 * CARNAMA TEST ACCOUNT SEEDER
 * Run once via: node tool/seed_test_accounts.js
 *
 * Creates Firebase Auth accounts + Firestore user documents for:
 *   admin@carnama.com   → role: owner
 *   kitchen@carnama.com → role: kitchen
 *   driver@carnama.com  → role: delivery
 *
 * Requires: npm install firebase-admin (run inside tool/ or project root)
 * Uses your local service account credentials via GOOGLE_APPLICATION_CREDENTIALS
 * Or set the projectId below and run: firebase use resturants-8547d first.
 */

const admin = require('firebase-admin');

// PERF-6c: the service-account key is OPERATOR-HELD — never hardcode a
// machine-specific absolute path again (the previous require('<repo>/')
// crashed on every other machine). Resolution order (fail-closed):
//   1. GOOGLE_APPLICATION_CREDENTIALS env var -> cert from that key file
//   2. ADC (applicationDefault), e.g. `gcloud auth application-default login`
//      or the emulator env vars for the local loop
//   3. Neither -> abort with instructions instead of a require() crash.
let credential;
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  // eslint-disable-next-line global-require -- path is operator-provided
  const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  credential = admin.credential.cert(serviceAccount);
} else if (
  process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  process.env.FIRESTORE_EMULATOR_HOST
) {
  // Local emulator loop: ADC placeholder is never contacted.
  credential = admin.credential.applicationDefault();
} else {
  console.error(
    'No credentials resolved. Set GOOGLE_APPLICATION_CREDENTIALS to a ' +
      'service-account key file, run `gcloud auth application-default ' +
      'login` (ADC), or set the emulator env vars for the local loop.',
  );
  process.exit(1);
}

admin.initializeApp({
  credential,
  projectId: 'resturants-8547d',
});

const auth = admin.auth();
const db = admin.firestore();

const testAccounts = [
  {
    email: 'admin@carnama.com',
    password: 'password123',
    role: 'owner',
    name: 'Carnama Admin',
    branchId: 'branch_main',
  },
  {
    email: 'kitchen@carnama.com',
    password: 'password123',
    role: 'kitchen',
    name: 'Carnama Chef',
    branchId: 'branch_main',
  },
  {
    email: 'manager@carnama.com',
    password: 'password123',
    role: 'manager',
    name: 'Carnama Manager',
    branchId: 'branch_main',
  },
  {
    email: 'driver@carnama.com',
    password: 'password123',
    role: 'delivery',
    name: 'Carnama Driver',
    branchId: 'branch_main',
  },
];

async function seedAccounts() {
  console.log('🚀 Carnama Test Account Seeder');
  console.log('================================');

  for (const account of testAccounts) {
    try {
      // 1. Create or get existing Firebase Auth user
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(account.email);
        console.log(`⏭️  Auth user already exists: ${account.email}`);
      } catch (e) {
        userRecord = await auth.createUser({
          email: account.email,
          password: account.password,
          displayName: account.name,
        });
        console.log(`✅ Created Auth user: ${account.email} (uid: ${userRecord.uid})`);
      }

      // 2. Write Firestore user document with role
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: account.email,
        name: account.name,
        role: account.role,
        branchId: account.branchId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`📝 Firestore user doc written: ${account.email} → role: ${account.role}`);
    } catch (err) {
      console.error(`❌ Failed to seed ${account.email}:`, err.message);
    }
  }

  // 3. Ensure a default branch document exists
  await db.collection('branches').doc('branch_main').set({
    name: 'Carnama Main Branch',
    address: '123 Demo Street, Riyadh',
    coordinates: new admin.firestore.GeoPoint(24.7136, 46.6753),
    deliveryRadiusMiles: 50000, // WHY: Unlimited radius for demo — any tester worldwide can place an order
    isDefault: true,            // WHY: Enables auto-selection on first app launch (merged_menu_provider fallback)
    isActive: true,
  }, { merge: true });
  console.log('\n🏢 Default branch "branch_main" ensured with 50000mi radius.');

  // 4. Seed system settings (CRITICAL for isOwner() and feature flags)
  await db.collection('settings').doc('ownerInfo').set({
    ownerEmail: 'admin@carnama.com',
  }, { merge: true });
  console.log('⚙️  settings/ownerInfo seeded.');

  await db.collection('settings').doc('featureFlags').set({
    enableLoyalty: true,
    enableReservations: true,
    enableDeliveryTracking: true,
    smartReorder: true,
    promoCode: true,
    waitlist: true,
    referrals: true,
  }, { merge: true });
  console.log('⚙️  settings/featureFlags seeded.');

  // 5. Seed an active promo code for the robot to test
  await db.collection('promoCodes').doc('WELCOME20').set({
    code: 'WELCOME20',
    type: 'percent',
    value: 20,
    active: true,
    maxUses: 1000,
    usedCount: 0,
  }, { merge: true });
  console.log('🏷️  Promo code WELCOME20 seeded.');

  // 6. Seed a sample promotions banner
  await db.collection('promotions').doc('banner1').set({
    imageUrl: 'https://via.placeholder.com/600x300.png?text=PROMO+20%25+OFF',
    isActive: true,
  }, { merge: true });
  console.log('🖼️  Promotions banner seeded.');

  console.log('\n✅ All test accounts and seed data ready!');
  console.log('You can now run: flutter test integration_test/golden_a_z_flow_test.dart');
  process.exit(0);
}

seedAccounts();
