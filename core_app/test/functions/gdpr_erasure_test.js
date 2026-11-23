/**
 * Batch 0 (potato4 §3) — GDPR erasure, PRODUCTION Cloud Function core.
 *
 * Runs against the real Firestore emulator using the COMPILED production code
 * (core_app/functions/lib/index.js — the same module the callable and the
 * scheduled retrier export). No simulated wrappers: these are the actual
 * collectUserDocs/eraseRefs/eraseUserData/retryIncompleteErasures paths the
 * `deleteUserData` callable and `deleteUserDataRetry` scheduler invoke.
 *
 * Run with:
 *   cd core_app && firebase emulators:exec --only firestore,storage
 *     "node test/functions/gdpr_erasure_test.js"
 */
// MONEY-3: eraseUserStorage resolves the DEFAULT bucket from FIREBASE_CONFIG
// (storageBucket) — set it BEFORE requiring the functions module (which runs
// admin.initializeApp()). Mirrors what firebase-tools injects into real
// function runtimes.
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: 'demo-carnama',
  storageBucket: 'demo-carnama.appspot.com',
});
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const RULES_PATH = path.join(__dirname, '..', '..', 'firestore.rules');
const rules = fs.readFileSync(RULES_PATH, 'utf8');

// The COMPILED production module. Importing it runs admin.initializeApp(),
// which auto-connects to the Firestore emulator via FIRESTORE_EMULATOR_HOST.
const functions = require(path.join(__dirname, '..', '..', 'functions', 'lib', 'index.js'));
const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
// Named Storage accessor (firebase-admin v12 removed the app-prototype
// `.storage()`); used ONLY to seed/assert Storage objects on the emulator.
const { getStorage } = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin', 'lib', 'storage', 'index.js'));

let testEnv;
// firebase-admin's own Firestore client (the SAME SDK the CF uses), so
// serverTimestamp()/batch() behave exactly as in production.
//
// B2 NAMESPACE FIX (SOLUTION option c + b): initializeTestEnvironment() with
// projectId 'demo-carnama'; a bare `admin.firestore()` resolves to the
// DEFAULT admin project ('resturants-8547d' under this repo's .firebaserc) —
// a SEPARATE emulator namespace. Seeds/erases/asserts therefore ran in one
// namespace while testEnv.clearFirestore() (demo-carnama) cleared another, so
// earlier scenarios' residue survived into T4/T5 whole-collection checks.
// Pin the admin client to the SAME project ('demo-carnama') so seed + erase +
// assert + reset all share ONE namespace. Empirically verified during this
// batch: clearFirestore() clears exactly this namespace (named-project view
// 1 -> 0) while the default-app view is untouched.
const adminApp = admin.initializeApp({ projectId: 'demo-carnama' }, 'gdpr-test-admin');
const db = adminApp.firestore();
let passed = 0;
let failed = 0;
const failures = [];

function record(name, ok, detail) {
  if (ok) {
    passed++;
    console.log(`  \u2705 ${name}`);
  } else {
    failed++;
    failures.push(`${name} \u2014 ${detail}`);
    console.log(`  \u274c ${name} \u2014 ${detail}`);
  }
}

/** Seeds every user-scoped doc shape for the erasure set. */
async function seedUser(uid) {
  await db.collection('users').doc(uid).set({
    email: `${uid}@test.com`, role: 'customer', branchId: '',
  });
  await db.collection('orders').doc(`order-${uid}-1`).set({
    customerId: uid, branchId: 'branch-1', status: 'confirmed',
    totalCents: 2500, items: [], createdAt: new Date(),
  });
  await db.collection('reservations').doc(`res-${uid}-1`).set({
    userId: uid, branchId: 'branch-1', customerName: 'Test',
    customerPhone: '555', startTime: new Date(), partySize: 2,
  });
  await db.collection('reservation_locks').doc(`lock-${uid}-1`).set({
    userId: uid, lockedAt: new Date(), expiresAt: new Date(),
  });
  await db.collection('waitlist').doc(`wl-${uid}-1`).set({
    userId: uid, branchId: 'branch-1',
  });
  await db.collection('promo_usage').doc(`pu-${uid}-1`).set({
    userId: uid, code: 'HELLO10',
  });
  await db.collection('notifications').doc(uid).collection('items').doc('n1').set({
    title: 'hello', isRead: false,
  });
  await db.collection('carts').doc(uid).set({ items: [] });
  await db.collection('presence').doc(uid).set({ lastSeen: new Date() });
  await db.collection('loyalty').doc(uid).set({ points: 10 });
  await db.collection('driverLocations').doc(uid).set({ lat: 1, lng: 2 });
}

async function collectionIds(collection) {
  const snap = await db.collection(collection).get();
  return snap.docs.map((d) => d.id);
}

// B2 reset: testEnv.clearFirestore() alone is NOT the reset — every collection
// this test touches is additionally cleared through the SAME admin-client
// namespace (db.recursiveDelete) that seeds, erases and asserts use, so no
// scenario can observe another scenario's residue even if the emulator ever
// namespaces the two SDK paths differently again. Idempotent between the two
// mechanisms (same namespace).
const TOUCHED_COLLECTIONS = [
  'users',
  'orders',
  'reservations',
  'reservation_locks',
  'waitlist',
  'promo_usage',
  'notifications',
  'carts',
  'presence',
  'loyalty',
  'driverLocations',
  'deletion_requests',
];
async function resetFirestore() {
  await testEnv.clearFirestore();
  for (const name of TOUCHED_COLLECTIONS) {
    await db.recursiveDelete(db.collection(name));
  }
}

(async () => {
  try {
    testEnv = await initializeTestEnvironment({
      projectId: 'demo-carnama',
      firestore: { host: '127.0.0.1', port: 8080, rules },
    });

    // ── T0-3: query-key guard ─────────────────────────────────────────────
    await resetFirestore();
    // Reservations: one keyed on userId (the ONLY legal key), one on the
    // legacy/wrong customerId (must NOT be collected), one other-user.
    await db.collection('reservations').doc('res-own').set({ userId: 'u-1', branchId: 'b' });
    await db.collection('reservations').doc('res-customerid').set({ customerId: 'u-1', branchId: 'b' });
    await db.collection('reservations').doc('res-other').set({ userId: 'u-other', branchId: 'b' });
    // Locks: own + other-user.
    await db.collection('reservation_locks').doc('lock-own').set({ userId: 'u-1' });
    await db.collection('reservation_locks').doc('lock-other').set({ userId: 'u-other' });

    const refs = await functions.collectUserDocs(db, 'u-1');
    const reservationPaths = refs.map((r) => r.path).filter((p) => p.startsWith('reservations/'));
    const lockPaths = refs.map((r) => r.path).filter((p) => p.startsWith('reservation_locks/'));

    record(
      'T0-3: collectUserDocs matches userId-keyed reservation, ignores customerId-only doc',
      reservationPaths.length === 1 && reservationPaths[0] === 'reservations/res-own',
      JSON.stringify(reservationPaths),
    );
    record(
      'T0-3: collectUserDocs scopes reservation_locks to the user (never whole collection)',
      lockPaths.length === 1 && lockPaths[0] === 'reservation_locks/lock-own',
      JSON.stringify(lockPaths),
    );
    record(
      'T0-3: users/{uid} is collected LAST',
      refs.length > 0 && refs[refs.length - 1].path === 'users/u-1',
      refs.map((r) => r.path).join(','),
    );
// ── T0-2: erasure completeness (prod CF core) ─────────────────────────
    await resetFirestore();
    await seedUser('u-2');
    await db.collection('reservations').doc('res-extra').set({ userId: 'u-2', branchId: 'b' });
    await seedUser('u-someone-else'); // untouched by u-2's erasure

    const authCalls = [];
    await functions.eraseUserData(db, 'u-2', async (uid) => { authCalls.push(uid); });

    const remainingReservations = await collectionIds('reservations');
    const ownReservations = remainingReservations.filter((id) =>
      ['res-u-2-1', 'res-extra'].includes(id)
    );
    record(
      'T0-2: reservations keyed on userId are erased to zero',
      ownReservations.length === 0,
      JSON.stringify(remainingReservations),
    );
    record(
      'T0-2: reservation_locks are erased to zero',
      (await collectionIds('reservation_locks')).filter((id) => id.startsWith('lock-u-2-')).length === 0,
      JSON.stringify(await collectionIds('reservation_locks')),
    );
    const otherReservations = remainingReservations.filter(
      (id) => id && id.startsWith('res-u-someone-else-'),
    );
    record(
      'T0-2: another user\'s reservations are untouched',
      otherReservations.length === 1,
      JSON.stringify(otherReservations),
    );
    const marker = (await db.collection('deletion_requests').doc('u-2').get()).data();
    record(
      'T0-2: deletion_requests/{uid} ends in status completed',
      marker && marker.status === 'completed',
      JSON.stringify(marker),
    );
    record(
      'T0-2: marker is the audit record — it is NOT deleted',
      (await db.collection('deletion_requests').doc('u-2').get()).exists,
    );
    record(
      'T0-2: auth delete invoked exactly once with the erased uid',
      authCalls.length === 1 && authCalls[0] === 'u-2',
      JSON.stringify(authCalls),
    );
    record(
      'T0-2: orders/carts/presence/loyalty/waitlist/promo_usage/notifications/driverLocations/users all erased',
      (await collectionIds('orders')).length === 1 &&
        (await db.collection('carts').doc('u-2').get()).exists === false &&
        (await db.collection('presence').doc('u-2').get()).exists === false &&
        (await db.collection('loyalty').doc('u-2').get()).exists === false &&
        (await db.collection('waitlist').get()).docs.length === 1 &&
        (await db.collection('promo_usage').get()).docs.length === 1 &&
        (await db.collection('notifications').doc('u-2').get()).exists === false &&
        (await db.collection('notifications').doc('u-2').collection('items').get()).docs.length === 0 &&
        (await db.collection('driverLocations').doc('u-2').get()).exists === false &&
        (await db.collection('users').doc('u-2').get()).exists === false,
      `orders=${(await collectionIds('orders')).length} waitlist=${(await db.collection('waitlist').get()).docs.length} promo=${(await db.collection('promo_usage').get()).docs.length}`,
    );
// ── T0-4: marker ordering — stays `in_progress` when auth delete fails ──
    await resetFirestore();
    await seedUser('u-3');

    let threw = false;
    try {
      await functions.eraseUserData(db, 'u-3', async () => {
        throw new Error('simulated auth outage');
      });
    } catch (e) {
      threw = true;
    }
    const marker4 = (await db.collection('deletion_requests').doc('u-3').get()).data();
    record(
      'T4: auth-delete failure rejects AND marker stays in_progress',
      threw && marker4 && marker4.status === 'in_progress',
      JSON.stringify({ threw, marker: marker4 }),
    );
    record(
      'T4: user docs were STILL erased before the auth failure (durable marker-first)',
      (await db.collection('reservations').get()).docs.length === 0 &&
        (await db.collection('reservation_locks').get()).docs.length === 0,
    );

    // Idempotent second pass with a working auth delete completes it.
    await functions.eraseUserData(db, 'u-3', async () => {});
    const completed = (await db.collection('deletion_requests').doc('u-3').get()).data();
    record(
      'T6: retry after failure completes the marker (in_progress -> completed)',
      completed && completed.status === 'completed',
      JSON.stringify(completed),
    );

    // ── T0-5: chunked erase — >500 user docs ─────────────────────────────
    await resetFirestore();
    const TOTAL = 1200;
    // Seed in 400-doc batches (emulator's own 500-op write cap).
    for (let i = 0; i < TOTAL; i += 400) {
      const batch = db.batch();
      for (let j = i; j < Math.min(i + 400, TOTAL); j++) {
        batch.set(db.collection('reservations').doc(`bulk-${j}`), {
          userId: 'u-5', branchId: 'b', customerName: `C${j}`, startTime: new Date(), partySize: 1,
        });
      }
      await batch.commit();
    }
    await db.collection('reservation_locks').doc('lock-u-5').set({ userId: 'u-5' });
    await db.collection('waitlist').doc('wl-u-5').set({ userId: 'u-5' });

    const refs5 = await functions.collectUserDocs(db, 'u-5');
    const deleted5 = await functions.eraseRefs(db, refs5);
    const remaining5 = (await db.collection('reservations').where('userId', '==', 'u-5').get()).docs.length;

    record(
      'T5: collectUserDocs finds >500 docs for one user',
      refs5.length > 500,
      `refs=${refs5.length}`,
    );
    record(
      'T5: eraseRefs deletes them ALL (no 500-op batch abort)',
      deleted5 === refs5.length && remaining5 === 0,
      `deleted=${deleted5} remaining=${remaining5}`,
    );
    record(
      'T5: locks + waitlist erased too',
      (await db.collection('reservation_locks').get()).docs.length === 0 &&
        (await db.collection('waitlist').get()).docs.length === 0,
    );

    // ── T0-6: retrier completes only owed (>=1h) in_progress markers ──────
    await resetFirestore();
    // A stale erasure: in_progress + requestedAt 2h ago, data still present.
    await seedUser('stale-1');
    await db.collection('deletion_requests').doc('stale-1').set({
      status: 'in_progress',
      requestedAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    });
    // A fresh marker NOT owed yet (now) — must be left alone.
    await seedUser('fresh-1');
    await db.collection('deletion_requests').doc('fresh-1').set({
      status: 'in_progress',
      requestedAt: new Date(), // under the 1h threshold
    });

    const completedNow = await functions.retryIncompleteErasures(db, new Date(), async () => {});

    record(
      'T6: retrier completes only markers owed (>=1h)',
      completedNow.length === 1 && completedNow[0] === 'stale-1',
      JSON.stringify(completedNow),
    );
    const staleMarker = (await db.collection('deletion_requests').doc('stale-1').get()).data();
    record(
      'T6: retrier wipes stale data and marks completed',
      staleMarker.status === 'completed' &&
        (await db.collection('reservations').where('userId', '==', 'stale-1').get()).docs.length === 0 &&
        (await db.collection('reservation_locks').where('userId', '==', 'stale-1').get()).docs.length === 0,
      JSON.stringify(staleMarker),
    );
    const freshMarker = (await db.collection('deletion_requests').doc('fresh-1').get()).data();
    record(
      'T6: fresh in_progress markers are left alone',
      freshMarker.status === 'in_progress' &&
        (await db.collection('reservations').where('userId', '==', 'fresh-1').get()).docs.length === 1,
      JSON.stringify(freshMarker),
    );

    // ── deleteAuthUser: user-not-found tolerance (pure unit) ──────────────
    {
      const deletedUids = [];
      const fakeAuth = {
        deleteUser: async (uid) => {
          if (uid === 'missing-user') {
            const err = new Error('There is no user record corresponding to the provided identifier.');
            err.code = 'auth/user-not-found';
            throw err;
          }
          deletedUids.push(uid);
        },
      };
      let threw = false;
      try {
        await functions.deleteAuthUser('missing-user', fakeAuth);
      } catch (e) {
        threw = true;
      }
      record(
        'T6: deleteAuthUser treats auth/user-not-found as success (idempotent retry)',
        !threw,
      );
      await functions.deleteAuthUser('real-user', fakeAuth);
      record(
        'T6: deleteAuthUser deletes a real account exactly once',
        deletedUids.length === 1 && deletedUids[0] === 'real-user',
        JSON.stringify(deletedUids),
      );
    }

    // ── MONEY-3 (b09 W3.5): the 4 NEW stores + Storage, end-to-end ─────────
    // Own order/delivery, driver-assigned order's delivery row (legacy
    // pre-driverId coverage), analyticsEvents, audit_log user rows (settings
    // rows RETAINED), and the Storage prefixes — through the REAL
    // collectUserDocs + eraseRefs + eraseUserStorage(bucket.deleteFiles).
    await resetFirestore();
    {
      const uid = 'u-m3';
      await db.collection('users').doc(uid).set({email: `${uid}@test.dev`, role: 'customer', branchId: ''});
      await db.collection('orders').doc('order-u-m3-own').set({
        customerId: uid, status: 'delivered', totalCents: 1000, branchId: 'b',
      });
      // Another customer's order the erased user was assigned to as driver:
      // per spec the ORDER doc survives (orderIds are only the KEY PATH to its
      // delivery row); the delivery row is what gets erased.
      await db.collection('orders').doc('order-u-m3-drv').set({
        customerId: 'someone-else', assignedDriverId: uid, userId: 'someone-else',
        status: 'delivered', totalCents: 800, branchId: 'b',
      });
      await db.collection('deliveries').doc('order-u-m3-own').set({
        orderId: 'order-u-m3-own', driverId: 'driver-x', status: 'delivered',
      });
      await db.collection('deliveries').doc('order-u-m3-drv').set({
        orderId: 'order-u-m3-drv', driverId: uid, status: 'delivered',
      });
      await db.collection('analyticsEvents').doc('ev-m3-1').set({uid, event: 'screen_view'});
      await db.collection('analyticsEvents').doc('ev-m3-2').set({uid, event: 'add_to_cart'});
      await db.collection('audit_log').doc('al-m3-user').set({
        collection: 'users', documentId: uid, action: 'role_change',
      });
      await db.collection('audit_log').doc('al-m3-settings').set({
        collection: 'settings', documentId: 'restaurantConfig', action: 'update',
      });

      const bucket = getStorage(adminApp).bucket('demo-carnama.appspot.com');
      await bucket.file(`avatars/${uid}/a.png`).save('x', {resumable: false});
      await bucket.file('proof_of_delivery/order-u-m3-own/pod.jpg').save('x', {resumable: false});
      await bucket.file('proof_of_delivery/order-u-m3-drv/pod.jpg').save('x', {resumable: false});
      await bucket.file('avatars/keep-me/b.png').save('x', {resumable: false});
      await bucket.file('proof_of_delivery/order-keep/pod.jpg').save('x', {resumable: false});

      await functions.eraseUserData(db, uid, async () => {});

      const fileExists = async (p) => (await bucket.file(p).exists())[0];
      const marker = (await db.collection('deletion_requests').doc(uid).get()).data();
      record(
        'M3: own order + BOTH delivery rows erased (own + driver-assigned/legacy)',
        !(await db.collection('orders').doc('order-u-m3-own').get()).exists &&
          !(await db.collection('deliveries').doc('order-u-m3-own').get()).exists &&
          !(await db.collection('deliveries').doc('order-u-m3-drv').get()).exists,
      );
      record(
        'M3: driver-assigned order doc SURVIVES (another customer\'s record; order ids are the delivery key path)',
        (await db.collection('orders').doc('order-u-m3-drv').get()).exists,
      );
      record(
        'M3: analyticsEvents uid rows erased',
        (await db.collection('analyticsEvents').where('uid', '==', uid).get()).docs.length === 0,
      );
      record(
        'M3: audit_log user row erased AND settings row RETAINED (legal-basis audit trail)',
        !(await db.collection('audit_log').doc('al-m3-user').get()).exists &&
          (await db.collection('audit_log').doc('al-m3-settings').get()).exists,
      );
      record(
        'M3: Storage erased — avatar + own/driver PODs; other users\' objects SURVIVE',
        !(await fileExists(`avatars/${uid}/a.png`)) &&
          !(await fileExists('proof_of_delivery/order-u-m3-own/pod.jpg')) &&
          !(await fileExists('proof_of_delivery/order-u-m3-drv/pod.jpg')) &&
          (await fileExists('avatars/keep-me/b.png')) &&
          (await fileExists('proof_of_delivery/order-keep/pod.jpg')),
      );
      record(
        'M3: marker completed with erased-prefix audit trail',
        marker && marker.status === 'completed' &&
          Array.isArray(marker.erasedStoragePrefixes) &&
          marker.erasedStoragePrefixes.includes(`avatars/${uid}/`) &&
          marker.erasedStoragePrefixes.includes('proof_of_delivery/order-u-m3-own/'),
        JSON.stringify(marker),
      );
    }

    // ── UX-3 (b27 W9.10): Art.20 export — collectUserData mirrors the
    // erasure set READ-ONLY (minus deletion), covering the stores a client
    // query cannot read: promo_usage, reservation_locks, notifications items,
    // driverLocations, deliveries, analyticsEvents. ─────────────────────────
    await resetFirestore();
    {
      const uid = 'u-exp';
      await seedUser(uid);
      // Stores seedUser does not cover (export-only coverage proof):
      await db.collection('deliveries').doc(`order-${uid}-1`).set({
        orderId: `order-${uid}-1`, driverId: 'driver-x', status: 'confirmed',
      });
      await db.collection('analyticsEvents').doc('ev-exp-1').set({
        uid, event: 'screen_view',
      });
      await db.collection('audit_log').doc('al-exp-user').set({
        collection: 'users', documentId: uid, action: 'role_change',
      });
      await db.collection('audit_log').doc('al-exp-settings').set({
        collection: 'settings', documentId: 'restaurantConfig', action: 'update',
      });

      const sections = await functions.collectUserData(db, uid);

      record(
        'UX3: export mirrors the erasure set — every section present and scoped',
        Array.isArray(sections.orders) && sections.orders.length === 1 &&
          Array.isArray(sections.reservations) && sections.reservations.length === 1 &&
          Array.isArray(sections.reservationLocks) && sections.reservationLocks.length === 1 &&
          Array.isArray(sections.promoUsage) && sections.promoUsage.length === 1 &&
          Array.isArray(sections.waitlistEntries) && sections.waitlistEntries.length === 1 &&
          Array.isArray(sections.notificationItems) && sections.notificationItems.length === 1 &&
          Array.isArray(sections.deliveries) && sections.deliveries.length === 1 &&
          Array.isArray(sections.analyticsEvents) && sections.analyticsEvents.length === 1 &&
          Array.isArray(sections.auditLog) && sections.auditLog.length === 1 &&
          sections.fixedDocs && sections.fixedDocs.cart &&
          sections.fixedDocs.presence && sections.fixedDocs.loyalty &&
          sections.fixedDocs.driverLocation &&
          sections.userProfile && sections.userProfile.email === `${uid}@test.com`,
        JSON.stringify(Object.keys(sections)),
      );
      record(
        'UX3: audit export carries the user row and NOT the settings row (legal basis)',
        sections.auditLog.length === 1 && sections.auditLog[0].id === 'al-exp-user',
        JSON.stringify(sections.auditLog),
      );
      record(
        'UX3: export is READ-ONLY — no marker written, no doc deleted',
        !(await db.collection('deletion_requests').doc(uid).get()).exists &&
          (await db.collection('users').doc(uid).get()).exists &&
          (await db.collection('promo_usage').doc(`pu-${uid}-1`).get()).exists,
      );
    }
console.log('\n\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550');
    console.log(`  GDPR ERASURE (PROD CF CORE) \u2014 PASSED: ${passed}  FAILED: ${failed}`);
    console.log('\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550');
    if (failed > 0) {
      failures.forEach((f) => console.log('  \u274c', f));
      process.exitCode = 1;
    }
  } catch (e) {
    console.error('FATAL:', e);
    process.exitCode = 1;
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
    }
  }
})();