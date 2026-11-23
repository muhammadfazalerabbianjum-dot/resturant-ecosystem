const admin = require('firebase-admin');
const serviceAccount = require('<repo>/resturants-8547d-firebase-adminsdk-fbsvc-ce60b264b3.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'resturants-8547d',
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function seedManager() {
  try {
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail('manager@carnama.com');
    } catch (e) {
      userRecord = await auth.createUser({
        email: 'manager@carnama.com',
        password: 'password123',
        displayName: 'Carnama Manager',
      });
    }

    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: 'manager@carnama.com',
      name: 'Carnama Manager',
      role: 'manager',
      branchId: 'branch_main',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log('✅ Created manager@carnama.com');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

seedManager();
