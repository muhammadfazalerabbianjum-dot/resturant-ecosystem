# Cloud Functions Specification
## Carnama Restaurant — Firebase Cloud Functions

These functions require a **Firebase Blaze (pay-as-you-go) plan** and are deployed via `firebase deploy --only functions`.

---

## Function 1: `cleanupStalePresence`

**Trigger:** `functions.pubsub.schedule('every 5 minutes')`
**Purpose:** Deletes presence documents where `lastSeen < now - 5 minutes`.

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const cleanupStalePresence = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 5 * 60 * 1000);
    const stale = await db.collection('presence')
      .where('lastSeen', '<', cutoff)
      .get();
    const batch = db.batch();
    stale.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Cleaned up ${stale.size} stale presence documents`);
  });
```

---

## Function 2: `checkDuplicateUser`

**Trigger:** `functions.https.onCall` (callable)
**Purpose:** Validates email + phone uniqueness before new user registration.

```typescript
export const checkDuplicateUser = functions.https.onCall(
  async ({ email, phone }: { email: string; phone: string }) => {
    const db = admin.firestore();
    const normalEmail = email.trim().toLowerCase();
    const normalPhone = phone.replace(/\s+/g, '');

    const byEmail = await db.collection('users')
      .where('email', '==', normalEmail).limit(1).get();
    if (!byEmail.empty) {
      throw new functions.https.HttpsError(
        'already-exists', 'Email already registered.');
    }

    const byPhone = await db.collection('users')
      .where('phone', '==', normalPhone).limit(1).get();
    if (!byPhone.empty) {
      throw new functions.https.HttpsError(
        'already-exists', 'Phone number already registered.');
    }

    return { unique: true };
  }
);
```

---

## Function 3: `sendOrderNotification` (Optional)

**Trigger:** `functions.firestore.document('orders/{orderId}').onUpdate`
**Purpose:** Send push notifications on order status changes via FCM topics.

```typescript
export const sendOrderNotification = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    const messaging = admin.messaging();
    const branchId = after.branchId;

    if (after.status === 'ready') {
      // Notify delivery drivers for this branch
      await messaging.send({
        topic: `branch_${branchId}_delivery`,
        notification: {
          title: 'Order Ready',
          body: `Order #${context.params.orderId.substring(0, 8)} is ready for pickup!`,
        },
      });
    }

    if (after.status === 'delivered') {
      // Notify the customer
      const customerToken = (await admin.firestore()
        .collection('users').doc(after.customerId).get()).data()?.pushToken;
      if (customerToken) {
        await messaging.send({
          token: customerToken,
          notification: {
            title: 'Order Delivered!',
            body: 'Your Carnama order has been delivered. Enjoy!',
          },
        });
      }
    }
  });
```

---

## Deployment

```bash
cd functions
npm install
firebase deploy --only functions
```

## Index Requirements (already in firestore.indexes.json)
- `orders`: branchId ASC + status ASC + createdAt DESC
- `orders`: branchId ASC + assignedDriverId ASC + createdAt DESC
- `presence`: branchId ASC + isOnline ASC + lastSeen DESC
- `menus`: branchId ASC + isAvailable ASC
