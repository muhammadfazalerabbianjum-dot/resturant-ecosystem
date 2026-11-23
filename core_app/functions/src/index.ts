import * as admin from 'firebase-admin';
import {DEFAULT_TENANT_ID} from './migrations/plans';
import {onCall, onRequest, HttpsError} from 'firebase-functions/v2/https';
import {logger} from 'firebase-functions';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {
  onDocumentUpdated,
  onDocumentWritten,
  onDocumentCreated,
} from 'firebase-functions/v2/firestore';
import {onMessagePublished} from 'firebase-functions/v2/pubsub';
import {defineSecret} from 'firebase-functions/params';
import {z} from 'zod';
import {
  renderNotification,
  NotificationKey,
} from './notification_copy';
import {assertCapability, capabilityDenialCode} from './access';
import {StripeProcessorAdapter} from './payments/processor_adapter';
import {classifyIdempotentReplay} from './idempotency';
import {planClaimSync} from './claims';
import {
  buildSaleRow,
  commitOrderWithLedger,
  commitSaleForOrder,
  commitVoidWithReversal,
  type LedgerStore,
} from './ledger';
import {buildCashSale, buildCashVoid, CashSaleError} from './cash_sale';
import {
  anonymiseLedgerRows,
  collectLedgerRows,
  type PrivacyStore,
} from './ledger_privacy';
import {
  DEFAULT_DDOS_ALERT_THRESHOLD,
  parseDdosAlertThreshold,
  nextDdosBucketCount,
  shouldTriggerDdosAlert,
  DdosBucketState,
} from './ddos';
import {
  createPaymentIntentSchema,
  applyPromoSchema,
  MoneyComputationError,
  computeItemsSubtotalCents,
  extractClientTaxConfig,
  computeTaxCents,
  resolveCurrency,
  normalizePromoCode,
  evaluatePromoUse,
  planPromoUsage,
  promoReasonMessage,
  computeAmountCents,
  verifyOrderCharge,
  extractMenuPricingInput,
  verifyMenuPricing,
  formatOrderNumber,
  toFiniteIntOrNull,
  MenuDocSnapshot,
  MenuPricingClientItem,
  MenuPricingResult,
  inspectRefundedCharges,
  buildRefundRecord,
  buildChargeIntentMetadata,
  decideOrderCancellation,
  validateDeliveryFee,
} from './payment';
import {
  DeliveryPlatformRow,
  PlatformConfigViolation,
  PlatformDeadLetter,
  PlatformIngestionDeps,
  PlatformMapper,
  ingestPlatformOrderRequest,
  selectEnabledPlatforms,
} from './platform_ingestion';
import {
  AvailabilityDeps,
  AvailabilityTarget,
  detectAvailabilityChange,
  syncAvailability,
} from './platform_availability';
import {uberEatsMapper} from './platform_mappers/uberEats';
import {deliveryHeroMapper} from './platform_mappers/deliveryHero';

admin.initializeApp();
const db = admin.firestore();

// ─── PERF-6d: deploy-time secret binding (fail-closed) ───────────────────────
// Declaring these SecretParams makes `firebase deploy` FAIL when
// STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET are absent from Secret Manager
// or the .env file, instead of silently deploying callables whose runtime
// `process.env` reads return undefined (previously surfacing only as
// runtime 500s on the money path). v2 injects declared secrets as env
// vars at runtime, so the `process.env.*` reads below are UNCHANGED —
// same values, now deploy-validated. No secret VALUE lives in source.
const STRIPE_SECRET_KEY_PARAM = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET_PARAM = defineSecret('STRIPE_WEBHOOK_SECRET');
void STRIPE_SECRET_KEY_PARAM;
void STRIPE_WEBHOOK_SECRET_PARAM;

/**
 * Law 12 - Hostile Client Defense: App Check Enforcement
 * Every callable function must validate the App Check token.
 * Any request without a valid token (e.g., raw Postman calls) is rejected.
 */
function enforceAppCheck(request: { app?: unknown }, fnName: string): void {
  if (!request.app) {
    throw new HttpsError(
        'unauthenticated',
        // eslint-disable-next-line max-len -- rewrapping template content would alter the message
        `App Check validation failed for ${fnName}. Requests without a valid Firebase App Check token are rejected.`,
    );
  }
}

/**
 * MONEY-1: security-class log (fail-closed bookkeeping for the money path).
 * `console.error` entries land in Cloud Logging with severity>=ERROR; the
 * `[firestore-security-alerts]` marker classifies this stream for the security
 * sink consumed by the same pipeline as `onFirestorePermissionDenied`
 * (index §9). Payload is allowlisted scalar fields only — never raw payloads.
 */
function logSecurityAlert(event: Record<string, unknown>): void {
  console.error('[firestore-security-alerts] ' + JSON.stringify({
    at: new Date().toISOString(),
    ...event,
  }));
}

/**
 * MONEY-1: server-side order number generation. Mirrors the client's
 * OrderNumberService contract exactly: an atomic transaction increments
 * `settings/orderCounter.seq` and the value is rendered zero-padded ("#0042").
 * Used by createOrder when the client payload carries no usable orderNumber.
 */
/**
 * D-046 — the server resolves a settings document through ONE helper, with the
 * tenant explicit. D-038 moved every settings document to
 * `settings/${tenantId}_${name}`; a bare `settings/name` read would silently
 * find nothing (tax and delivery fee would fall back, which is a money bug).
 *
 * The tenant comes from the record being processed when the caller has one. The
 * call sites below currently pass none because the order payload does not carry
 * a tenant yet, so they target the deployment's own tenant — the same
 * `DEFAULT_TENANT_ID` the tenancy migration backfills. That is a deliberate,
 * visible default, not an inference: when the payload gains a tenant, each call
 * site passes it and this helper is the only place that changes.
 */
function settingsDoc(name: string, tenantId: string = DEFAULT_TENANT_ID) {
  return db.collection('settings').doc(`${tenantId}_${name}`);
}

async function nextServerOrderNumber(): Promise<string> {
  const counterRef = settingsDoc('orderCounter');
  const nextNum = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const data = snap.data() as {seq?: unknown} | undefined;
    const current =
      typeof data?.seq === 'number' && Number.isSafeInteger(data.seq) && data.seq >= 0 ?
        data.seq :
        0;
    const next = current + 1;
    tx.set(counterRef, {seq: next}, {merge: true});
    return next;
  });
  return formatOrderNumber(nextNum);
}

// ----------------------------------------------------------------------------
// 1. TAX CALCULATION (Called from CheckoutScreen)
// ----------------------------------------------------------------------------
export const calculateTaxSchema = z.object({ // p33 T-3: exported for caller-input test
  subtotalCents: z.number().int().min(0, 'Subtotal must be non-negative').max(100_000_000),
  stateCode: z.string().min(1, 'stateCode is required').toUpperCase(),
  clientId: z.string().min(1, 'clientId is required'),
});

export const calculateTax = onCall(async (request) => {
  enforceAppCheck(request, 'calculateTax');
  try {
    const {subtotalCents, stateCode, clientId} = calculateTaxSchema.parse(request.data);

    // FIX-B4 TAX-1 (AUD1-04): ONE implementation — this callable delegates to
    // the same pure functions the charge path charges with
    // (extractClientTaxConfig + computeTaxCents in payment.ts). The
    // fail-closed guard proven in functions/test/tax_fail_closed.test.js is
    // therefore reachable here EXACTLY as it is at charge time; this block
    // carries no second lookup, no offline rate table and no rounding rule of
    // its own. An unknown tenant, an unmapped state or an out-of-range
    // configured rate surfaces below as FAILED_PRECONDITION — never a silent
    // rate (Law 8 / money sanctuary 0.7).
    const doc = await settingsDoc('taxRates').get();
    const config = extractClientTaxConfig(doc.data(), clientId);
    const {taxCents, rate} = computeTaxCents(config, subtotalCents, stateCode);
    return {taxCents, rate, stateCode};
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new HttpsError('invalid-argument', 'Invalid request payload', error.issues);
    }
    if (error instanceof MoneyComputationError) {
      throw new HttpsError('failed-precondition', error.message);
    }
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'Internal server error');
  }
});

// ----------------------------------------------------------------------------
// 2. FRAUD SCREENING (Pre-flight before Stripe payment)
// ----------------------------------------------------------------------------
export const screenPaymentFraud = onCall(async (request) => {
  enforceAppCheck(request, 'screenPaymentFraud');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const uid = request.auth.uid;

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const recentOrders = await db.collection('orders')
      .where('customerId', '==', uid)
      .where('createdAt', '>=', oneHourAgo)
      .get();

  if (recentOrders.size > 10) {
    await db.collection('users').doc(uid).update({flaggedForFraud: true});
    throw new HttpsError('resource-exhausted', 'Order limit exceeded. Account flagged.');
  }
  // Client checks result.data['allowed'] == true - field name must match.
  return {allowed: true};
});

// ----------------------------------------------------------------------------
// 3. FLEET DISPATCH (Deferred — DoorDash Drive / Uber Direct not deployed yet)
// TODO_DEPLOY: replace with the real fleet API call (DoorDash Drive, Uber Direct).
// Marked fallback: still requires auth + App Check and validates the order +
// provider before persisting the dispatch intent to Firestore, so the real
// integration drops in behind the same interface without client changes.
// ----------------------------------------------------------------------------
export const dispatchToFleet = onCall(async (request) => {
  enforceAppCheck(request, 'dispatchToFleet');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  // BACKEND-2 (W7.4/T-3, 06-P1-4): staff-only gate — fleet dispatch is an
  // ops action; a customer (or an account without a role claim) can never
  // trigger it. The role comes from the server-side custom claim minted by
  // syncUserRoleClaims, never from client input.
  const gate = assertCapability(request.auth, 'fleet.dispatch');
  const denial = capabilityDenialCode(gate);
  if (denial) {
    throw new HttpsError(
        denial,
        `Fleet dispatch requires the fleet.dispatch capability (${gate.reason})`,
    );
  }
  const {orderId, provider} = request.data ?? {};

  if (typeof orderId !== 'string' || orderId.length === 0) {
    throw new HttpsError('invalid-argument', 'orderId is required');
  }

  const orderRef = db.collection('orders').doc(orderId);
  const orderDoc = await orderRef.get();
  if (!orderDoc.exists) {
    throw new HttpsError('not-found', 'Order not found');
  }
  // The fleet provider may be internal, doordash, uber — validate against a
  // known-set so a caller can't inject arbitrary labels (fail-closed).
  const providerValue = provider ?? 'internal';
  if (!['internal', 'doordash', 'uber'].includes(providerValue)) {
    throw new HttpsError('invalid-argument', 'Unsupported fleet provider');
  }

  await orderRef.update({
    fleetProvider: providerValue,
    fleetStatus: 'dispatched',
    fleetDispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {dispatched: true};
});

// ----------------------------------------------------------------------------
// 4. FUNNEL TELEMETRY (Analytics event logger)
// ----------------------------------------------------------------------------
export const logFunnelEvent = onCall(async (request) => {
  enforceAppCheck(request, 'logFunnelEvent');
  const {event, properties} = request.data;
  await db.collection('analyticsEvents').add({
    event,
    properties,
    uid: request.auth?.uid ?? 'anonymous',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {logged: true};
});

// ----------------------------------------------------------------------------
// 5. GDPR DELETE (Right to be Forgotten - cascade wipe)
// ----------------------------------------------------------------------------

/**
 * Maximum document writes per Firestore commit (hard platform limit: 500).
 * Erasure commits must never exceed this, otherwise the entire deletion
 * aborts and the user's erasure silently fails.
 */
const ERASE_CHUNK_SIZE = 400;

/**
 * Collects every Firestore document reference owned by `uid` (GDPR Art.17
 * erasure set), mirroring the canonical set in the client gdpr_service.
 *
 * KEY SEMANTICS (query-key guard):
 *  - `orders`, `promo_usage`, `waitlist`, `reservation_locks` carry their own
 *    key fields; reservations are keyed by `userId` (NEVER `customerId` —
 *    reservations_repository.dart writes only userId/branchId/customerName/
 *    customerPhone/startTime/partySize/notes and firestore.rules forbids
 *    `customerId` on reservation creates).
 *  - `users/{uid}` is appended LAST so the profile record survives until every
 *    dependent document is gone.
 */
export async function collectUserDocs(
    db: admin.firestore.Firestore,
    uid: string,
): Promise<admin.firestore.DocumentReference[]> {
  const refs: admin.firestore.DocumentReference[] = [];

  // Orders DO carry `customerId` (order_repository / createOrder) — keep it.
  const orders = await db.collection('orders').where('customerId', '==', uid).get();
  const orderIds = new Set<string>();
  orders.forEach((doc) => {
    refs.push(doc.ref);
    orderIds.add(doc.id);
  });

  // MONEY-3 (W3.5/06-P0-2): deliveries — the delivery doc id IS the order id.
  // A customer's rows are erased via their order IDs (gathered BEFORE the order
  // docs are deleted below); a DRIVER's rows are covered BOTH by
  // `deliveries.where('driverId', ==, uid)` (rows stamped since MONEY-3) and by
  // the order-IDs of every order they were assigned (covers legacy pre-driverId
  // rows). Deleting a missing doc is a batch no-op, so the per-order refs are
  // safe even when a delivery was never started.
  const driverOrders = await db.collection('orders').where('assignedDriverId', '==', uid).get();
  driverOrders.forEach((doc) => orderIds.add(doc.id));
  for (const orderId of orderIds) {
    refs.push(db.collection('deliveries').doc(orderId));
  }
  const deliveryRowsByDriver =
    await db.collection('deliveries').where('driverId', '==', uid).get();
  deliveryRowsByDriver.forEach((doc) => refs.push(doc.ref));

  // MONEY-3 (W3.5): analyticsEvents — every row is uid-queryable
  // (logFunnelEvent stamps `uid`).
  const analyticsEvents =
    await db.collection('analyticsEvents').where('uid', '==', uid).get();
  analyticsEvents.forEach((doc) => refs.push(doc.ref));

  // MONEY-3 (W3.5): audit_log — erase ONLY the user's OWN rows. Rows written by
  // `auditRoleChanges` carry { collection:'users', documentId: uid }; rows
  // written by `auditSettingsChanges` carry collection 'settings' (documentId =
  // a settings doc id) and are intentionally RETAINED — legal basis: immutable
  // audit proof of configuration writes (see runErase doc comment). A settings
  // doc id can never equal a user uid, but the collection guard is the explicit
  // belt-and-suspenders.
  const auditRows = await db.collection('audit_log').where('documentId', '==', uid).get();
  auditRows.forEach((doc) => {
    if ((doc.data() as {collection?: unknown} | undefined)?.collection === 'users') {
      refs.push(doc.ref);
    }
  });

  // Reservations carry `userId` (reservations_repository.dart:61-69).
  const reservations = await db.collection('reservations').where('userId', '==', uid).get();
  reservations.forEach((doc) => refs.push(doc.ref));

  // Reservation locks hold { userId, lockedAt, expiresAt } — personal data and
  // a P0-3 gap that left stale locks behind after account deletion.
  const locks = await db.collection('reservation_locks').where('userId', '==', uid).get();
  locks.forEach((doc) => refs.push(doc.ref));

  // Waitlist entries are keyed by userId (waitlist_repository).
  const waitlist = await db.collection('waitlist').where('userId', '==', uid).get();
  waitlist.forEach((doc) => refs.push(doc.ref));

  // Promo usage records are keyed by userId.
  const promoUsage = await db.collection('promo_usage').where('userId', '==', uid).get();
  promoUsage.forEach((doc) => refs.push(doc.ref));

  // In-app notifications: subcollection + the parent doc.
  const notifications = await db.collection('notifications').doc(uid).collection('items').get();
  notifications.forEach((doc) => refs.push(doc.ref));
  refs.push(db.collection('notifications').doc(uid));

  // Fixed (deterministic) per-user docs.
  refs.push(db.collection('carts').doc(uid));
  refs.push(db.collection('presence').doc(uid));
  refs.push(db.collection('loyalty').doc(uid));
  refs.push(db.collection('driverLocations').doc(uid));

  // users/{uid} LAST — see doc comment above.
  refs.push(db.collection('users').doc(uid));

  return refs;
}

/**
 * Deletes `refs` in chunks of at most `chunkSize` (default 400), committing
 * each chunk sequentially so the total stays under Firestore's 500-write batch
 * limit. Returns the number of refs erased. Missing docs are no-ops, so erasure
 * is idempotent for retries and double-taps on Delete Account.
 */
export async function eraseRefs(
    db: admin.firestore.Firestore,
    refs: admin.firestore.DocumentReference[],
    chunkSize = ERASE_CHUNK_SIZE,
): Promise<number> {
  let deleted = 0;
  for (let i = 0; i < refs.length; i += chunkSize) {
    const chunk = refs.slice(i, i + chunkSize);
    const batch = db.batch();
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

/**
 * MONEY-3 (W3.5/06-P0-2): deletes the user's Firebase Storage objects via the
 * Admin SDK bucket. Covers (a) `avatars/{uid}/*` and (b)
 * `proof_of_delivery/{orderId}/*` for EVERY order the user owns OR was assigned
 * to as a driver (order ids gathered BEFORE the order docs are erased). The
 * erasure is idempotent (`deleteFiles` with a prefix is a no-op when the
 * prefix matches nothing). Runs under the SAME fail-closed contract as
 * eraseRefs: any failure propagates and the deletion_requests marker stays
 * `in_progress` for the scheduled retrier.
 *
 * Legal-basis note (retention): `deletion_requests/{uid}` markers and
 * `audit_log` settings rows (collection == 'settings') are intentionally NEVER
 * deleted. The marker is the durable erasure intent + audit proof (Art. 17
 * "demonstrate erasure"); the settings rows are the immutable audit trail of
 * configuration writes (Law 36) and hold no user PII. Only `audit_log` rows
 * with `collection == 'users'` (ROLE_CHANGE events carrying a uid) are erased.
 */
export async function eraseUserStorage(
    db: admin.firestore.Firestore,
    uid: string,
): Promise<string[]> {
  const bucket = admin.storage().bucket();
  const erasedPrefixes: string[] = [];
  await bucket.deleteFiles({prefix: `avatars/${uid}/`});
  erasedPrefixes.push(`avatars/${uid}/`);
  const orderSnaps = [
    ...(await db.collection('orders').where('customerId', '==', uid).get()).docs,
    ...(await db.collection('orders').where('assignedDriverId', '==', uid).get()).docs,
  ];
  const orderIds = new Set(orderSnaps.map((doc) => doc.id));
  for (const orderId of orderIds) {
    await bucket.deleteFiles({prefix: `proof_of_delivery/${orderId}/`});
    erasedPrefixes.push(`proof_of_delivery/${orderId}/`);
  }
  return erasedPrefixes;
}

/**
 * Writes / merges the GDPR erasure marker `deletion_requests/{uid}`. The marker
 * is the durable intent + audit proof of erasure and doubles as the retrier's
 * worklist, so it is intentionally NEVER deleted.
 */
function setMarker(
    db: admin.firestore.Firestore,
    uid: string,
    status: 'in_progress' | 'completed',
    extra: Record<string, unknown> = {},
): Promise<admin.firestore.WriteResult> {
  return db
      .collection('deletion_requests')
      .doc(uid)
      .set({status, ...extra}, {merge: true});
}

/**
 * Deletes the Auth account, treating an already-erased user (`user-not-found`)
 * as success so retries and a double-tap on Delete Account are harmless.
 *
 * `authNamespace` is injectable for tests (defaults to the real Admin SDK).
 */
export async function deleteAuthUser(
    uid: string,
    authNamespace?: admin.auth.Auth,
): Promise<void> {
  const auth = authNamespace ?? admin.auth();
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    const code = (error as { code?: string }).code ?? '';
    if (code === 'auth/user-not-found') return; // already erased — idempotent
    throw error;
  }
}

/**
 * Erases every user-scoped doc + the Auth account, then marks the marker
 * `completed`. The marker must ALREADY be `in_progress` when called (written by
 * [eraseUserData] on the direct path, or by the retrier's worklist on the
 * scheduled path). Any failure leaves it `in_progress` for the retrier.
 *
 * `authDeleter` is injectable for tests (defaults to the real Admin SDK call).
 */
export async function runErase(
    db: admin.firestore.Firestore,
    uid: string,
    authDeleter: (u: string) => Promise<void> = deleteAuthUser,
): Promise<void> {
  const refs = await collectUserDocs(db, uid);
  // MONEY-3 (W3.5): Storage objects are deleted FIRST (order docs still exist,
  // so proof_of_delivery/{orderId} paths resolve), then Firestore refs, then
  // the auth account. Any failure leaves the marker `in_progress` for the
  // hourly retrier (fail-closed — an incomplete erasure is never "completed").
  const erasedStoragePrefixes = await eraseUserStorage(db, uid);
  await eraseRefs(db, refs);
  // C-9 / D-059: LEDGER ROWS ARE RETAINED (they are the taxable record of a
  // sale) but ANONYMISED — `customerId`/`staffId`/`actorUid` become null, every
  // amount and id stays. Before this step nothing in the erasure reached
  // `transactions` at all. Runs BEFORE the auth delete so a failure leaves the
  // marker `in_progress` and the hourly retrier finishes it (fail closed).
  await anonymiseLedgerRows(db as unknown as PrivacyStore, uid, new Date());
  await authDeleter(uid);
  await setMarker(db, uid, 'completed', {
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    // MONEY-3 (W3.6): audit trail — exactly which Storage prefixes were
    // erased for this user (empty array = the user had no Storage objects).
    erasedStoragePrefixes,
  });
}

/**
 * Durable-marker-first erasure used by the `deleteUserData` callable:
 * the `in_progress` marker is written BEFORE any fragile step, then the erasure
 * runs, then the marker flips to `completed`. A client death mid-call leaves
 * `in_progress` → the scheduled retrier finishes the job.
 */
export async function eraseUserData(
    db: admin.firestore.Firestore,
    uid: string,
    authDeleter: (u: string) => Promise<void> = deleteAuthUser,
): Promise<void> {
  await setMarker(db, uid, 'in_progress', {
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await runErase(db, uid, authDeleter);
}

export const deleteUserData = onCall(async (request) => {
  enforceAppCheck(request, 'deleteUserData');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const uid = request.auth.uid;

  await eraseUserData(db, uid);
  // `success: true` is the contract gdpr_service.dart awaits (Art.17 flow);
  // a client that sees anything else must surface a failed erasure.
  return {success: true};
});

/**
 * Completes every erasure marker left `in_progress` for at least 1h as of
 * `now`. Per-marker failures are logged and do NOT abort the sweep; the marker
 * stays `in_progress` for the next run. Returns the uids completed this pass.
 */
export async function retryIncompleteErasures(
    db: admin.firestore.Firestore,
    now: Date,
    authDeleter: (u: string) => Promise<void> = deleteAuthUser,
): Promise<string[]> {
  const cutoff = new Date(now.getTime() - 60 * 60 * 1000); // >= 1h old
  const pending = await db
      .collection('deletion_requests')
      .where('status', '==', 'in_progress')
      .where('requestedAt', '<=', cutoff)
      .get();

  const completed: string[] = [];
  for (const doc of pending.docs) {
    const uid = doc.id;
    try {
      await runErase(db, uid, authDeleter);
      console.log(`deleteUserDataRetry completed uid=${uid}`);
      completed.push(uid);
    } catch (error) {
      console.error(`deleteUserDataRetry failed uid=${uid}`, error);
    }
  }
  return completed;
}

/**
 * Scheduled retrier (every hour): completes erasures left `in_progress` for at
 * least 1h (client died, callable timed out, auth delete failed server-side).
 * Closes the documented-but-never-implemented "server-side retry" promise.
 */
export const deleteUserDataRetry = onSchedule(
    {schedule: '0 * * * *', timeoutSeconds: 540},
    async () => {
      await retryIncompleteErasures(db, new Date());
    },
);

// ----------------------------------------------------------------------------
// 5c. EXPORT MY DATA (Art.20 Right to Data Portability — W9.10 / 06-P1-7)
//
// The Art.17 erasure set (collectUserDocs) and the Art.20 export must cover
// the SAME data. Several of those collections are rules-gated server-side (a
// client query would be DENIED), so the client export calls this READ-ONLY
// callable instead. collectUserData MIRRORS collectUserDocs query-for-query,
// minus deletion — no new erasure logic, no writes. A per-collection row cap
// keeps the payload bounded (same cap class as the client's W8.5 query caps).
// ----------------------------------------------------------------------------

/** Per-collection row cap for the Art.20 export (see collectUserData). */
export const kExportRowCap = 500;

/**
 * Read-only collection of every user-owned document, mirroring
 * `collectUserDocs` query-for-query minus deletion. Returns JSON-serializable
 * sections ({id, ...data} rows); the fixed per-user docs are grouped under
 * `fixedDocs` and the profile doc is emitted last, matching the erasure
 * ordering.
 */
export async function collectUserData(
    db: admin.firestore.Firestore,
    uid: string,
): Promise<Record<string, unknown>> {
  const toRows = (
      snap: admin.firestore.QuerySnapshot<admin.firestore.DocumentData>,
  ) => snap.docs.map((doc) => ({id: doc.id, ...doc.data()}));

  const out: Record<string, unknown> = {};

  // Orders (customerId) + the driver-assigned order ids (delivery key path).
  const orders = await db.collection('orders').where('customerId', '==', uid)
      .limit(kExportRowCap).get();
  out.orders = toRows(orders);

  // C-9 / D-059: the caller's own ledger rows are part of their data (Art.15/20).
  // Bounded by the same cap as every other section; only `customerId` selects
  // them, so a staff member's export is their purchases, not every sale they
  // ever rang up.
  out.transactions = await collectLedgerRows(
      db as unknown as PrivacyStore,
      uid,
      kExportRowCap,
  );

  const orderIds = new Set<string>(orders.docs.map((d) => d.id));
  const driverOrders = await db.collection('orders')
      .where('assignedDriverId', '==', uid).limit(kExportRowCap).get();
  driverOrders.forEach((d) => orderIds.add(d.id));

  // Deliveries: the delivery doc id IS the order id (own + driver-assigned
  // coverage) plus every row the user was stamped as driver (MONEY-3).
  const deliveries: Array<Record<string, unknown>> = [];
  for (const orderId of orderIds) {
    const doc = await db.collection('deliveries').doc(orderId).get();
    if (doc.exists) deliveries.push({id: doc.id, ...doc.data()!});
  }
  const deliveriesByDriver = await db.collection('deliveries')
      .where('driverId', '==', uid).limit(kExportRowCap).get();
  deliveries.push(...toRows(deliveriesByDriver));
  out.deliveries = deliveries;

  // MONEY-3 uid-keyed stores.
  out.analyticsEvents = toRows(await db.collection('analyticsEvents')
      .where('uid', '==', uid).limit(kExportRowCap).get());
  const auditRows = await db.collection('audit_log')
      .where('documentId', '==', uid).limit(kExportRowCap).get();
  out.auditLog = auditRows.docs
      .filter((d) => (d.data() as {collection?: unknown}).collection === 'users')
      .map((d) => ({id: d.id, ...d.data()}));

  // userId-keyed stores.
  out.reservations = toRows(
      await db.collection('reservations').where('userId', '==', uid).limit(kExportRowCap).get());
  out.reservationLocks = toRows(await db.collection('reservation_locks')
      .where('userId', '==', uid).limit(kExportRowCap).get());
  out.waitlistEntries = toRows(
      await db.collection('waitlist').where('userId', '==', uid).limit(kExportRowCap).get());
  out.promoUsage = toRows(await db.collection('promo_usage')
      .where('userId', '==', uid).limit(kExportRowCap).get());

  // In-app notifications: the subcollection items (parent doc carries no
  // personal payload beyond its id, which equals the uid — excluded on
  // purpose, mirroring its erasure semantics where only its EXISTENCE is
  // deleted).
  out.notificationItems = toRows(await db.collection('notifications')
      .doc(uid).collection('items').limit(kExportRowCap).get());

  // Fixed (deterministic) per-user docs.
  const fixed: Record<string, unknown> = {};
  const cartDoc = await db.collection('carts').doc(uid).get();
  if (cartDoc.exists) fixed.cart = {id: cartDoc.id, ...cartDoc.data()!};
  const presenceDoc = await db.collection('presence').doc(uid).get();
  if (presenceDoc.exists) fixed.presence = {id: presenceDoc.id, ...presenceDoc.data()!};
  const loyaltyDoc = await db.collection('loyalty').doc(uid).get();
  if (loyaltyDoc.exists) fixed.loyalty = {id: loyaltyDoc.id, ...loyaltyDoc.data()!};
  const driverLocationDoc = await db.collection('driverLocations').doc(uid).get();
  if (driverLocationDoc.exists) {
    fixed.driverLocation = {id: driverLocationDoc.id, ...driverLocationDoc.data()!};
  }
  out.fixedDocs = fixed;

  // The user's own profile doc LAST — mirrors collectUserDocs ordering.
  const userDoc = await db.collection('users').doc(uid).get();
  out.userProfile = userDoc.exists ? userDoc.data() : null;

  return out;
}

/**
 * Art.20 export callable (W9.10): auth + App Check enforced; NO input schema
 * by design — the callable takes no arguments (nothing for a client to
 * inject) and the uid comes ONLY from the verified ID token, never from
 * request.data. Read-only: no collection is ever written.
 */
export const exportMyData = onCall(async (request) => {
  enforceAppCheck(request, 'exportMyData');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const sections = await collectUserData(db, request.auth.uid);
  return {sections};
});

// ----------------------------------------------------------------------------
// 5b. CREATE PAYMENT INTENT (server-authoritative; Stripe idempotency Law 9)
//
// B1 MONEY INTEGRITY: tax, discount and currency are RE-DERIVED on the server
// from settings/taxRates.clients[clientId] (+ settings/restaurantConfig
// currency) and the promoCodes + promo_usage collections. Client-supplied
// taxCents / discountCents are STRIPPED by the schema and NEVER read
// (T-M1 / T-M3). Unknown state -> failed-precondition, never $0 tax (T-M2).
// ----------------------------------------------------------------------------

/**
 * DB-touching core of createPaymentIntent (exported for the emulator harness).
 * Resolves the server-authoritative tax, currency and promo discount for a
 * charge. Never reads client-supplied tax/discount.
 */
export async function resolveChargeTaxAndPromo(input: {
  clientId: string;
  stateCode: string;
  itemsSubtotalCents: number;
  code?: string | null;
  userId?: string | null;
  idempotencyKey?: string;
  nowMs?: number;
  /** P2-1: the tenant whose settings apply. Defaults to the deployment tenant. */
  tenantId?: string;
}): Promise<{ taxCents: number; taxRate: number; discountCents: number; currency: string }> {
  const nowMs = input.nowMs ?? Date.now();

  // Tax + per-client currency: settings/taxRates.clients[clientId] (the exact
  // lookup calculateTax uses, minus the offline hardcoded fallback).
  const taxDoc = await settingsDoc('taxRates', input.tenantId).get();
  const taxConfig = extractClientTaxConfig(taxDoc.data(), input.clientId);
  const {taxCents, rate} = computeTaxCents(taxConfig, input.itemsSubtotalCents, input.stateCode);

  // Currency: per-client override -> fallback settings/restaurantConfig.currency.
  let currencyRaw: unknown = taxConfig.currency;
  if (typeof currencyRaw !== 'string' || currencyRaw.trim().length === 0) {
    const rcDoc = await settingsDoc('restaurantConfig', input.tenantId).get();
    currencyRaw = (rcDoc.data() as Record<string, unknown> | undefined)?.currency;
  }
  const currency = resolveCurrency(currencyRaw);

  // Promo: the code is the ONLY client input; the discount is server-derived.
  let discountCents = 0;
  const normalized = normalizePromoCode(input.code);
  if (normalized) {
    if (!input.userId) {
      throw new HttpsError(
          'permission-denied',
          'A signed-in user is required to apply a promo code',
      );
    }
    const promoDoc = await db.collection('promoCodes').doc(normalized).get();
    const usageDoc = await db.collection('promo_usage').doc(`${normalized}_${input.userId}`).get();
    const result = evaluatePromoUse({
      code: normalized,
      promo: promoDoc.exists ? promoDoc.data() : null,
      usageExists: usageDoc.exists,
      cartSubtotalCents: input.itemsSubtotalCents,
      nowMs,
      idempotencyKey: input.idempotencyKey,
      usageIdempotencyKey: usageDoc.exists ?
        ((usageDoc.data() as Record<string, unknown>)?.idempotencyKey as string | undefined) :
        undefined,
    });
    if (!result.ok) {
      throw new HttpsError('failed-precondition', promoReasonMessage(result.reason));
    }
    discountCents = result.discountCents;
  }

  return {taxCents, taxRate: rate, discountCents, currency};
}

/** Idempotent promo_usage commit at CHARGE time (Law 9, uid-scoped). */
export async function commitChargePromoUsage(opts: {
  code: string;
  userId: string;
  idempotencyKey: string;
  itemsSubtotalCents: number;
  nowMs?: number;
}): Promise<void> {
  const nowMs = opts.nowMs ?? Date.now();
  await db.runTransaction(async (tx) => {
    const usageRef = db.collection('promo_usage').doc(`${opts.code}_${opts.userId}`);
    const usageDoc = await tx.get(usageRef);
    if (usageDoc.exists) return; // idempotent retry — usage already committed
    const promoRef = db.collection('promoCodes').doc(opts.code);
    const promoDoc = await tx.get(promoRef);
    if (!promoDoc.exists) {
      throw new HttpsError('failed-precondition', promoReasonMessage('code_not_found'));
    }
    const plan = planPromoUsage({
      code: opts.code,
      promo: promoDoc.data(),
      usageExists: false,
      cartSubtotalCents: opts.itemsSubtotalCents,
      nowMs,
      idempotencyKey: opts.idempotencyKey,
    });
    if (plan.status === 'commit') {
      tx.set(usageRef, {
        code: opts.code,
        userId: opts.userId,
        idempotencyKey: opts.idempotencyKey,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(promoRef, {usedCount: admin.firestore.FieldValue.increment(1)});
      return;
    }
    if (plan.status === 'idempotent') {
      return; // an identical retry already committed this usage
    }
    throw new HttpsError('failed-precondition', promoReasonMessage(plan.rejectReason));
  });
}

// ----------------------------------------------------------------------------
// 5a. APPLY PROMO (server-authoritative promo validation — B1)
// ----------------------------------------------------------------------------

/**
 * Plain server-side promo application (exported for the emulator harness).
 * Does the real DB reads + `evaluatePromoUse` and returns the authoritative
 * result. Throws `HttpsError('failed-precondition', ...)` on rejection.
 */
export async function serverApplyPromo(input: {
  code: string;
  cartSubtotalCents: number;
  uid: string;
}): Promise<{ valid: true; code: string; discountCents: number }> {
  const normalized = normalizePromoCode(input.code);
  if (!normalized) throw new HttpsError('invalid-argument', 'Invalid promo code');

  const promoDoc = await db.collection('promoCodes').doc(normalized).get();
  const usageDoc = await db.collection('promo_usage').doc(`${normalized}_${input.uid}`).get();

  const result = evaluatePromoUse({
    code: normalized,
    promo: promoDoc.exists ? promoDoc.data() : null,
    usageExists: usageDoc.exists,
    cartSubtotalCents: input.cartSubtotalCents,
    nowMs: Date.now(),
  });
  if (!result.ok) {
    throw new HttpsError('failed-precondition', promoReasonMessage(result.reason));
  }
  return {valid: true, code: normalized, discountCents: result.discountCents};
}

export const applyPromo = onCall(async (request) => {
  enforceAppCheck(request, 'applyPromo');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const parsed = applyPromoSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'Invalid request payload', parsed.error.issues);
  }
  const {code, cartSubtotalCents, userId} = parsed.data;
  if (userId && userId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'userId does not match authenticated user');
  }

  return serverApplyPromo({
    code,
    cartSubtotalCents,
    uid: request.auth.uid,
  });
});

/**
 * DB-touching core of createPaymentIntent (exported for the emulator harness,
 * mirroring resolveChargeTaxAndPromo). The onCall wrapper owns App Check,
 * auth and the zod schema; this function owns the money: the MONEY-1 menu
 * cross-check, the server-derived tax/promo/currency, and the Stripe intent.
 */
/**
 * Minimal Stripe surface createChargeIntentCore needs. Injectable so the
 * emulator harness can observe the server-derived money (amount + metadata)
 * without real Stripe — mirrors CancelOrderStripeSeam. The production wrapper
 * passes nothing and the real client is constructed from STRIPE_SECRET_KEY.
 */
export interface CreateChargeIntentStripeSeam {
  paymentIntents: {
    create: (
        params: Record<string, unknown>,
        opts?: {idempotencyKey?: string},
    ) => Promise<{id: string; client_secret: string; status: string}>;
  };
}

export async function createChargeIntentCore(input: {
  items: MenuPricingClientItem[];
  idempotencyKey: string;
  tipCents?: number;
  deliveryFeeCents?: number;
  stateCode: string;
  clientId: string;
  code?: string | null;
  orderId?: string;
  userId: string;
  /** BACKEND-2 (W7.4/T-4): creator stamp — ALWAYS the authenticated caller's
   *  uid (request.auth.uid). Stamped into PaymentIntent metadata.createdBy
   *  and re-checked by verifyOrderCharge / createOrder. */
  createdBy: string;
  /** Authenticated user's email (request.auth.token.email) for the Stripe-hosted
   *  receipt. Omitted when absent (anonymous users get no email receipt). */
  receiptEmail?: string;
  /** Injectable Stripe seam (emulator harness only). Production passes
   *  nothing — the real client is constructed from STRIPE_SECRET_KEY. */
  stripe?: CreateChargeIntentStripeSeam;
}): Promise<{
  clientSecret: string;
  paymentIntentId: string;
  amountCents: number;
  taxCents: number;
  discountCents: number;
  currency: string;
  taxRate: number;
}> {
  const items = input.items ?? [];
  let verifiedPricing: MenuPricingResult | null = null;

  // Re-derive the item subtotal from the FLAT line items (never the client total).
  const itemsSubtotalCents = computeItemsSubtotalCents(items);
  const cartQtySum = items.reduce((s: number, it: any) => s + (it.quantity ?? 1), 0);
  if (cartQtySum > 50) {
    throw new HttpsError('invalid-argument', 'Too many items in cart (max 50).');
  }

  // MONEY-1 (W3.1b): menu cross-check — the server re-prices every line from
  // the `menus` collection BEFORE any money moves (Admin SDK getAll: 1 read
  // per item). Unknown/disabled items, unknown option ids, or a client price
  // differing from the menu price + server upcharges fail closed here: no
  // Stripe charge, no promo usage commit (T-1 / T-MC*).
  if (items.length > 0) {
    const menuSnaps = await db.getAll(
        ...items.map((it) => db.collection('menus').doc(it.id)),
    );
    const menuDocs: MenuDocSnapshot[] = menuSnaps.map((snap) => ({
      exists: snap.exists,
      data: (snap.data() as Record<string, unknown> | undefined) ?? null,
    }));
    const pricing = verifyMenuPricing(items, menuDocs);
    if (!pricing.ok) {
      throw new HttpsError(
          'failed-precondition',
          pricing.reason ?? 'Item prices do not match the menu',
      );
    }
    verifiedPricing = pricing;
  }

  const tip = Math.max(0, Math.round(input.tipCents ?? 0));
  // MONEY-3 (W3.7): server-authoritative delivery fee — re-read from
  // settings/restaurantConfig.deliveryFeeCents and CLAMP any differing client
  // claim (a hostile client can neither raise nor lower the fee). A missing
  // config doc yields no server fee -> the claim is used unchanged.
  let deliveryFee = Math.max(0, Math.round(input.deliveryFeeCents ?? 0));
  const restaurantConfig = await settingsDoc('restaurantConfig').get();
  deliveryFee = validateDeliveryFee(
      deliveryFee,
      restaurantConfig.data()?.deliveryFeeCents,
  ).deliveryFeeCents;

  // Tax, currency and promo discount are server-derived — a hostile client
  // cannot lower tax or inflate a discount (T-M1 / T-M3).
  const {taxCents, taxRate, discountCents, currency} = await resolveChargeTaxAndPromo({
    clientId: input.clientId,
    stateCode: input.stateCode,
    itemsSubtotalCents,
    code: input.code,
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
  });

  const amountCents = computeAmountCents({
    subtotalCents: itemsSubtotalCents,
    taxCents,
    discountCents,
    tipCents: tip,
    deliveryFeeCents: deliveryFee,
  });
  if (amountCents <= 0) {
    throw new HttpsError('invalid-argument', 'Order amount must be positive');
  }

  const stripe: CreateChargeIntentStripeSeam =
      input.stripe ?? require('stripe')(process.env.STRIPE_SECRET_KEY);
  // P0-11: processor seam. The Stripe params literal that used to sit here now
  // lives verbatim in StripeProcessorAdapter.createIntent; the money decisions
  // (amount, currency, metadata) stay here, processor-independent.
  const processor = new StripeProcessorAdapter(stripe);
  const paymentIntent = await processor.createIntent({
    amountCents,
    currency,
    receiptEmail: input.receiptEmail,
    idempotencyKey: input.idempotencyKey,
    // BACKEND-2 (W7.4/T-4): ONE builder for the metadata bag — the
    // creator stamp (createdBy = the authenticated caller) can never
    // drift from the charge, and createOrder re-verifies it.
    metadata: buildChargeIntentMetadata({
      userId: input.userId,
      createdBy: input.createdBy,
      // Batch 10 FIX: the stripeWebhook resolves the order by
      // metadata.orderId — without it, payment_intent.succeeded
      // webhooks could never find the owning order.
      orderId: input.orderId,
      // B1: server-derived money provenance — createOrder re-verifies the
      // stored order's tax/discount against this (belt-and-suspenders).
      taxCents,
      discountCents,
      itemsSubtotalCents,
      tipCents: tip,
      deliveryFeeCents: deliveryFee,
      currency,
      // MONEY-1: verified branch context from the menu cross-check —
      // createOrder re-reads the SAME context (never the client's).
      ...(verifiedPricing?.branchId ? {branchId: verifiedPricing.branchId} : {}),
    }),
  });

  // Track promo_usage ONLY at charge time (uid-scoped, idempotent). A retry
  // with the SAME idempotency key is a no-op; a DIFFERENT key for the same
  // user+code is rejected earlier as already_used.
  if (input.code) {
    const normalized = normalizePromoCode(input.code);
    if (normalized) {
      await commitChargePromoUsage({
        code: normalized,
        userId: input.userId,
        idempotencyKey: input.idempotencyKey,
        itemsSubtotalCents,
      });
    }
  }

  return {
    clientSecret: paymentIntent.clientSecret,
    paymentIntentId: paymentIntent.paymentIntentId,
    amountCents,
    taxCents,
    discountCents,
    currency,
    taxRate,
  };
}

export const createPaymentIntent = onCall(async (request) => {
  enforceAppCheck(request, 'createPaymentIntent');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const parsed = createPaymentIntentSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'Invalid payment request', parsed.error.issues);
  }
  const {
    items,
    idempotencyKey,
    tipCents,
    deliveryFeeCents,
    stateCode,
    clientId,
    code,
    orderId,
  } = parsed.data;

  try {
    return await createChargeIntentCore({
      items: items ?? [],
      idempotencyKey,
      tipCents,
      deliveryFeeCents,
      stateCode,
      clientId,
      code,
      orderId,
      userId: request.auth.uid,
      // BACKEND-2 (W7.4/T-4): creator stamp — server-side from the ID token,
      // never client input.
      createdBy: request.auth.uid,
      // MONEY-3 (W3.7): the authenticated user's verified email (ID token) —
      // never a client-supplied receipt address.
      receiptEmail: request.auth.token.email,
    });
  } catch (error) {
    if (error instanceof MoneyComputationError) {
      throw new HttpsError('failed-precondition', error.message);
    }
    throw error;
  }
});

// ----------------------------------------------------------------------------
// 6. CREATE ORDER (Atomic payment verification + order creation with refund)
// ----------------------------------------------------------------------------
export const createOrder = onCall(async (request) => {
  enforceAppCheck(request, 'createOrder');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const {paymentIntentId, order, userId, idempotencyKey} = request.data as {
    paymentIntentId: string;
    order: any;
    userId: string;
    idempotencyKey?: string;
  };

  /**
   * MONEY-1 (W3.1a): fail-closed typed rejection with a security-class log.
   * Throwing the returned error inside the try keeps the compensating-refund
   * path (below) — a mismatched order NEVER keeps the customer's money.
   */
  const verificationError = (reason: string, details: Record<string, unknown>): HttpsError => {
    logSecurityAlert({
      fn: 'createOrder',
      event: 'order_verification_failed',
      reason,
      ...details,
    });
    return new HttpsError('failed-precondition', reason);
  };

  try {
    // SECURITY (Law 12): the caller must be the order's owner.
    if (order?.customerId && order.customerId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Order does not belong to this user');
    }
    if (userId && userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'userId does not match authenticated user');
    }

    // IDEMPOTENCY (Law 9): if an order with this key already exists, return it
    // - but ONLY when it is the SAME attempt (same customer, same PaymentIntent,
    // same amount). FIX-B12 (REC-B2-1): a key hit whose content differs is a
    // FOREIGN order, and returning it would confirm another customer's order to
    // this caller. Fail closed (law 0.5): reject with a security alert and an
    // `already-exists` error, never a foreign orderId.
    if (idempotencyKey) {
      const existing = await db.collection('orders')
          .where('idempotencyKey', '==', idempotencyKey)
          .limit(1)
          .get();
      if (!existing.empty) {
        const existingDoc = existing.docs[0];
        const existingData = existingDoc.data() as Record<string, unknown>;
        const decision = classifyIdempotentReplay({
          request: {
            uid: request.auth.uid,
            paymentIntentId,
            totalCents: order?.totalCents,
          },
          existing: {
            customerId: existingData.customerId,
            paymentIntentId: existingData.paymentIntentId,
            totalCents: existingData.totalCents,
          },
        });
        if (decision.kind === 'conflict') {
          logSecurityAlert({
            fn: 'createOrder',
            event: 'idempotency_conflict_rejected',
            reason: decision.reason,
            idempotencyKey,
            orderId: existingDoc.id,
            existingPaymentIntentId:
              typeof existingData.paymentIntentId === 'string' ?
                existingData.paymentIntentId :
                null,
          });
          throw new HttpsError(
              'already-exists',
              'Idempotency key was already used by a different order attempt',
              {code: 'IDEMPOTENCY_CONFLICT', reason: decision.reason},
          );
        }
        return {orderId: existingDoc.id, idempotent: true};
      }
    }

    // Verify payment succeeded
    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== 'succeeded') {
      throw new HttpsError('failed-precondition', 'Payment not confirmed');
    }

    // MONEY-2 (W3.2/06-P1-1): refund-replay guard. A refund does NOT change the
    // PaymentIntent `status` (it stays 'succeeded'), so the status check alone
    // would let a retrying client (that kept its session key) confirm an order
    // on a refunded charge. Inspect the PI's CHARGES: any refunded charge —
    // `refunded === true`, `amount_refunded > 0` (partial/full) or a non-empty
    // `refunds` list — fails closed with `already-refunded` BEFORE any further
    // processing, and a minimal refund record is persisted under
    // `orders/{id}.refunds[]` (amount, reason, at) as the durable audit trace
    // (the order never confirms). Stripe amounts are already integer minor
    // units (cents).
    const charges = await stripe.charges.list(
        {payment_intent: paymentIntentId, limit: 10},
    );
    const refundInspection = inspectRefundedCharges(charges.data);
    if (refundInspection.hasRefundedCharge) {
      const replayOrderId =
        typeof order?.id === 'string' && order.id.length > 0 ?
          order.id :
          db.collection('orders').doc().id;
      const reason = refundInspection.reason ?? 'Charge is already refunded';
      logSecurityAlert({
        fn: 'createOrder',
        event: 'already_refunded_replay_rejected',
        reason,
        paymentIntentId,
        orderId: replayOrderId,
      });
      await db.collection('orders').doc(replayOrderId)
          .set(
              {
                refunds: admin.firestore.FieldValue.arrayUnion(
                    buildRefundRecord({
                      amountCents: refundInspection.refundedAmountCents,
                      reason: 'already_refunded_replay_guard',
                      at: new Date(),
                    }),
                ),
              },
              {merge: true},
          );
      throw new HttpsError('failed-precondition', reason);
    }

    // MONEY-1 (W3.1a/c) — server-authoritative stored order. The client order
    // JSON is NEVER persisted verbatim: every priced line is re-verified
    // against the `menus` collection, the money fields are verified against
    // the PaymentIntent (charge amount + server-stamped metadata), and the
    // doc below is rebuilt from validated fields only.
    const metadata = (paymentIntent.metadata ?? {}) as Record<string, string>;

    // BACKEND-2 (W7.4/T-4): the charge's server-side creator stamp must be
    // THIS caller — a paymentIntentId minted by another user can never be
    // confirmed here (fail-closed: no stamp = no proof of creatorship).
    if (metadata.createdBy !== request.auth.uid) {
      throw verificationError(
          'Charge creator does not match the authenticated user',
          {paymentIntentId},
      );
    }

    // (1) Re-price every stored line from the menus collection (1 read/item).
    //     The client's nested CartItemModel lines (or flat lines) must name a
    //     real menu doc per line — anything else fails closed.
    const pricingInput: MenuPricingClientItem[] | null =
      extractMenuPricingInput(order?.items);
    if (!pricingInput) {
      throw verificationError('Order items are missing a verifiable menu item id', {
        paymentIntentId,
        orderId: typeof order?.id === 'string' ? order.id : null,
      });
    }
    const menuSnaps = await db.getAll(
        ...pricingInput.map((line) => db.collection('menus').doc(line.id)),
    );
    const menuDocs: MenuDocSnapshot[] = menuSnaps.map((snap) => ({
      exists: snap.exists,
      data: (snap.data() as Record<string, unknown> | undefined) ?? null,
    }));
    const pricing = verifyMenuPricing(pricingInput, menuDocs);
    if (!pricing.ok) {
      throw verificationError(pricing.reason ?? 'Order items do not match the menu', {
        paymentIntentId,
        orderId: typeof order?.id === 'string' ? order.id : null,
      });
    }

    // (2) Money-equality between the stored order and the charged intent
    //     (extended T-M6 regression gate): claimed total == charged amount,
    //     stored items subtotal == metadata, tip/deliveryFee == metadata,
    //     status allowlist, and the server re-derived total consistency.
    const verification = verifyOrderCharge({
      claimedTotalCents: order?.totalCents,
      orderTaxCents: order?.taxCents,
      orderDiscountCents: order?.discountCents,
      chargedAmountCents: paymentIntent.amount,
      chargedTaxCents: metadata.taxCents,
      chargedDiscountCents: metadata.discountCents,
      orderItems: pricing.canonicalItems,
      chargedItemsSubtotalCents: metadata.itemsSubtotalCents,
      orderTipCents: order?.tipCents,
      chargedTipCents: metadata.tipCents,
      orderDeliveryFeeCents: order?.deliveryFeeCents,
      chargedDeliveryFeeCents: metadata.deliveryFeeCents,
      // BACKEND-2 (W7.4/T-4): creator binding — the order's effective creator
      // (claimed customerId per the ownership guard above, defaulting to the
      // caller) must equal the charge's server-side createdBy stamp.
      orderCreatedBy:
        typeof order?.customerId === 'string' && order.customerId.length > 0 ?
          order.customerId :
          request.auth.uid,
      chargedCreatedBy: metadata.createdBy,
      orderStatus: order?.status,
    });
    if (!verification.ok) {
      throw verificationError(verification.reason ?? 'Order amount mismatch', {
        paymentIntentId,
        orderId: typeof order?.id === 'string' ? order.id : null,
      });
    }

    // (3) branchId is re-read from the verified menu context — a client value
    //     is only cross-checked, never persisted (fail-closed on mismatch).
    const verifiedBranchId = pricing.branchId ?? '';
    const clientBranchId =
      typeof order?.branchId === 'string' ? order.branchId.trim() : '';
    if (clientBranchId.length > 0 && clientBranchId !== verifiedBranchId) {
      throw verificationError('Order branchId does not match the verified menu branch', {
        paymentIntentId,
        orderId: typeof order?.id === 'string' ? order.id : null,
      });
    }

    // Use the client's order.id for deterministic doc ID (idempotent retries
    // write to the SAME doc - no duplicates) — but never let one customer
    // overwrite another customer's order document.
    const orderId =
      typeof order?.id === 'string' && order.id.length > 0 ?
        order.id :
        db.collection('orders').doc().id;
    const orderRef = db.collection('orders').doc(orderId);
    const existingDoc = await orderRef.get();
    if (existingDoc.exists &&
        (existingDoc.data() as Record<string, unknown> | undefined)?.customerId !==
          request.auth.uid) {
      throw new HttpsError('permission-denied', 'Order does not belong to this user');
    }

    // (4) orderNumber: keep the client's generated number; the server
    //     generates one (same atomic settings/orderCounter contract as the
    //     client's OrderNumberService) when absent or malformed.
    const trimmedClientNumber =
      typeof order?.orderNumber === 'string' ? order.orderNumber.trim() : '';
    const orderNumber =
      trimmedClientNumber.length > 0 && trimmedClientNumber.length <= 32 ?
        trimmedClientNumber :
        await nextServerOrderNumber();

    // (5) Server-built stored doc — validated fields ONLY. Nothing else from
    //     the client payload is persisted (a hostile key can no longer
    //     smuggle through a spread), and a plain set (not merge) guarantees
    //     no stale fields survive a rewrite.
    const storedOrder: Record<string, unknown> = {
      id: orderId,
      customerId: request.auth.uid,
      userId: request.auth.uid, // legacy consumers (OrderModel.tryFromDoc)
      status: order?.status, // verified against the confirmation allowlist above
      totalCents: paymentIntent.amount, // the amount the server actually charged
      taxCents: toFiniteIntOrNull(metadata.taxCents) ?? 0,
      discountCents: toFiniteIntOrNull(metadata.discountCents) ?? 0,
      tipCents: toFiniteIntOrNull(metadata.tipCents) ?? 0,
      deliveryFeeCents: toFiniteIntOrNull(metadata.deliveryFeeCents) ?? 0,
      orderNumber,
      items: pricing.canonicalItems, // server-re-priced verified lines
      branchId: verifiedBranchId,
      paymentIntentId,
      idempotencyKey: idempotencyKey ?? null,
      paymentConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    // Validated fulfillment location (NOT a money field; consumed by the
    // delivery/proof-of-delivery flow via OrderModel.customerLocation). Kept
    // only when finite and in range; dropped otherwise (spec amendment M1-A2).
    const customerLat =
      typeof order?.customerLat === 'number' && Number.isFinite(order.customerLat) &&
      Math.abs(order.customerLat) <= 90 ?
        order.customerLat :
        null;
    const customerLng =
      typeof order?.customerLng === 'number' && Number.isFinite(order.customerLng) &&
      Math.abs(order.customerLng) <= 180 ?
        order.customerLng :
        null;
    if (customerLat !== null && customerLng !== null) {
      storedOrder.customerLat = customerLat;
      storedOrder.customerLng = customerLng;
    }

    // P1-2: order + its one ledger row commit together or not at all.
    await commitSaleForOrder(db as unknown as LedgerStore, orderRef, storedOrder,
        paymentIntent, admin.firestore.FieldValue.serverTimestamp());

    return {orderId};
  } catch (error: any) {
    console.error('createOrder failed:', error);

    // Compensating action: refund if payment succeeded but order creation failed
    if (paymentIntentId) {
      // MONEY-2 (W3.2 P-2): the refund is AWAITED — never fire-and-forget — and
      // its outcome is reported through the structured `logger` at the right
      // severity with the refund id on success. A refund failure is logged at
      // ERROR but never thrown past this handler (the caller's idempotent retry
      // is the recovery path); the old `console.error` swallow is gone.
      try {
        const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
        const refund = await stripe.refunds.create({
          payment_intent: paymentIntentId,
          reason: 'order_creation_failed',
        });
        logger.info(
            'createOrder compensating refund issued',
            {paymentIntentId, refundId: refund.id},
        );
      } catch (refundError) {
        logger.error(
            'createOrder compensating refund FAILED',
            {paymentIntentId},
            refundError,
        );
      }
    }

    // MONEY-1: typed errors (verification/permission failures) keep their
    // HttpsError code so clients can distinguish tamper rejections from
    // infrastructure failures.
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'Order creation failed. Refund issued if applicable.');
  }
});

// ----------------------------------------------------------------------------
// 6b. CANCEL ORDER (callable) — W3.4 / 01-P1-B (customer cancel was double-dead:
//     no callable export AND no rules disjunct; the client has been calling
//     cancelOrder since order_repository.dart:58-83, so the server completes the
//     contract, idempotently, with the money reversed FIRST)
// ----------------------------------------------------------------------------

export const cancelOrderSchema = z.object({
  orderId: z.string().min(1).max(200),
});

export interface CancelOrderStripeSeam {
  paymentIntents: {
    retrieve: (id: string) => Promise<{status?: string}>;
    cancel: (id: string, opts: {idempotencyKey?: string}) => Promise<{id?: string}>;
  };
  refunds: {
    create: (
        payload: {payment_intent: string; reason?: string},
        opts: {idempotencyKey?: string},
    ) => Promise<{id?: string; amount?: number}>;
  };
}

/**
 * MONEY-2 (W3.4): DB-touching core of `cancelOrder` — exported for the money
 * emulator harness (mirrors the `createChargeIntentCore` pattern). Safety
 * invariant = refund-before-flip: money is reversed FIRST (when a captured
 * charge exists) and only then does the order transition to `cancelled` — a
 * failed refund NEVER leaves a cancelled order with the customer still charged
 * (fail-closed). Idempotent on re-call: an already-cancelled order is an OK
 * with no double refund. Ownership + status gates are enforced here (defense in
 * depth; the callable wrapper owns App Check/auth/zod). The Stripe seam is
 * injected so the emulator can assert refund issuance with a mock Stripe
 * (batch spec §8.5); production passes the real client.
 */
export async function cancelOrderCore(input: {
  orderId: string;
  uid: string;
  order: Record<string, unknown>;
  orderRef: admin.firestore.DocumentReference;
  stripe: CancelOrderStripeSeam;
}): Promise<{
  orderId: string;
  cancelled: true;
  alreadyCancelled?: true;
  refundId: string | null;
}> {
  const {orderId, uid, order, orderRef, stripe} = input;

  // SECURITY: only the order's owner may cancel it.
  if (order.customerId !== uid) {
    throw new HttpsError('permission-denied', 'Order does not belong to this user');
  }

  const decision = decideOrderCancellation(order.status);
  if (decision.action === 'already_cancelled') {
    // Idempotent on re-call: the first call already flipped the status; a retry
    // is an OK and MUST NOT refund again (the Stripe idempotency key would also
    // have suppressed a duplicate refund, but we skip the call entirely).
    return {orderId, cancelled: true, alreadyCancelled: true, refundId: null};
  }
  if (decision.action === 'reject') {
    logSecurityAlert({
      fn: 'cancelOrder',
      event: 'cancel_rejected',
      reason: `Order status "${decision.status}" cannot be cancelled`,
      orderId,
      uid,
    });
    throw new HttpsError(
        'failed-precondition',
        'Order cannot be cancelled in its current state',
    );
  }

  const paymentIntentId =
    typeof order.paymentIntentId === 'string' && order.paymentIntentId.length > 0 ?
      order.paymentIntentId :
      null;
  const reversal = await issueCancellationRefund({orderId, paymentIntentId, stripe});

  // Refund BEFORE status flip: this update only runs once the money was
  // reversed (or there was nothing to reverse — pending order with no charge).
  await orderRef.update({
    status: 'cancelled',
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    cancelledBy: 'customer',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    refunds: admin.firestore.FieldValue.arrayUnion(
        buildRefundRecord({
          amountCents: reversal.amountCents,
          reason: 'cancelled_by_customer',
          at: new Date(),
          refundId: reversal.id,
        }),
    ),
  });

  logSecurityAlert({
    fn: 'cancelOrder',
    event: 'order_cancelled',
    reason: 'customer cancel',
    orderId,
    uid,
    paymentIntentId: paymentIntentId ?? undefined,
    refundId: reversal.id ?? undefined,
  });

  return {orderId, cancelled: true, refundId: reversal.id};
}

/**
 * Reverses the charge for a cancellation. "Charge capturable" semantics
 * (W3.4): a succeeded (captured) intent is REFUNDED with the documented
 * `cancel-{orderId}` idempotency key; an authorized-but-uncaptured intent is
 * RELEASED via paymentIntents.cancel (no capture happened -> no refund is
 * possible or needed); any other state has no money to reverse. Returns the
 * Stripe refund id + amount (null when nothing was captured).
 */
async function issueCancellationRefund(input: {
  orderId: string;
  paymentIntentId: string | null;
  stripe: CancelOrderStripeSeam;
}): Promise<{id: string | null; amountCents: number | null}> {
  if (!input.paymentIntentId) return {id: null, amountCents: null};
  const intent = await input.stripe.paymentIntents.retrieve(input.paymentIntentId);
  if (intent.status === 'requires_capture') {
    await input.stripe.paymentIntents.cancel(
        input.paymentIntentId,
        {idempotencyKey: `cancel-${input.orderId}`},
    );
    return {id: null, amountCents: null};
  }
  if (intent.status === 'succeeded') {
    const refund = await input.stripe.refunds.create(
        {payment_intent: input.paymentIntentId, reason: 'requested_by_customer'},
        // Idempotency: retries of THIS cancel can never double-refund.
        {idempotencyKey: `cancel-${input.orderId}`},
    );
    return {
      id: typeof refund.id === 'string' ? refund.id : null,
      amountCents:
        typeof refund.amount === 'number' && Number.isFinite(refund.amount) ?
          Math.trunc(refund.amount) :
          null,
    };
  }
  return {id: null, amountCents: null};
}

export const cancelOrder = onCall(async (request) => {
  enforceAppCheck(request, 'cancelOrder');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const parsed = cancelOrderSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'orderId is required');
  }
  const {orderId} = parsed.data;

  const uid = request.auth.uid;
  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) {
    throw new HttpsError('not-found', 'Order not found');
  }
  const order = orderSnap.data() as Record<string, unknown>;

  // The real Stripe client is constructed LAZILY — only when a captured charge
  // actually needs reversing (issueCancellationRefund). Non-owner /
  // non-cancellable-state / already-cancelled replays therefore never touch
  // Stripe, and a blank server key can never mask a permission rejection with
  // a configuration error.
  const stripeSeam: CancelOrderStripeSeam = {
    paymentIntents: {
      retrieve: (pi) =>
        require('stripe')(process.env.STRIPE_SECRET_KEY).paymentIntents.retrieve(pi),
      cancel: (pi, opts) =>
        require('stripe')(process.env.STRIPE_SECRET_KEY).paymentIntents.cancel(pi, opts),
    },
    refunds: {
      create: (payload, opts) =>
        require('stripe')(process.env.STRIPE_SECRET_KEY).refunds.create(payload, opts),
    },
  };
  return cancelOrderCore({orderId, uid, order, orderRef, stripe: stripeSeam});
});

// ----------------------------------------------------------------------------
// 7. CART ABANDONMENT RECOVERY (Pub/Sub - runs every 5 minutes)
// ----------------------------------------------------------------------------
export const recoverAbandonedCarts = onSchedule('every 5 minutes', async (event) => {
  const now = Date.now();
  const min25 = new Date(now - 25 * 60 * 1000);
  const min35 = new Date(now - 35 * 60 * 1000);

  // NOTE: requires the composite index carts(updatedAt ASC, recovered ASC)
  // declared in firestore.indexes.json (Batch 10).
  const abandonedCarts = await db.collection('carts')
      .where('updatedAt', '<=', min25)
      .where('updatedAt', '>=', min35)
      .where('recovered', '==', false)
      .get();

  const messaging = admin.messaging();
  const promises = abandonedCarts.docs.map(async (doc) => {
    const {fcmToken} = doc.data();
    if (fcmToken) {
      let locale: unknown;
      try {
        // The cart doc id is the user's uid (carts/{userId}, per firestore rules);
        // the recipient's notification locale lives on that user document.
        locale = (await db.collection('users').doc(doc.id).get()).data()?.locale;
      } catch (err) {
        console.error('recoverAbandonedCarts locale lookup failed', err);
      }
      const copy = renderNotification('cartRecovery', locale ?? 'en');
      await messaging.send({
        token: fcmToken,
        notification: {title: copy.title, body: copy.body},
        data: {cartId: doc.id},
      });
    }
    await doc.ref.update({recovered: true});
  });

  await Promise.all(promises);
  console.log(`Recovered ${abandonedCarts.size} abandoned carts.`);
});

// ----------------------------------------------------------------------------
// 7. FCM PUSH ON ORDER STATUS CHANGE (Firestore trigger)
// ----------------------------------------------------------------------------
export const onOrderStatusChange = onDocumentUpdated('orders/{orderId}', async (event) => {
  const change = event.data;
  if (!change) return null;

  const before = change.before.data();
  const after = change.after.data();

  if (before.status === after.status) return null;

  // 7a. Loyalty Points injection when delivered
  // B8-2: the server writes ONLY `totalPoints` (+ `updatedAt`). Client-side tier
  // display is owned by the client calculator with its config-driven thresholds
  // (B4-6); re-implementing platform tiers here from hardcoded numeric cut-offs
  // would re-introduce the divergence this batch eliminates. Any dashboard tier
  // must be derived from a documented `settings/loyaltyConfig` doc, never from
  // inline constants.
  if (before.status !== 'delivered' && after.status === 'delivered') {
    const pointsEarned = Math.floor((after.totalCents || 0) / 100);
    if (pointsEarned > 0 && after.customerId) {
      const loyaltyRef = db.collection('loyalty').doc(after.customerId);
      await db.runTransaction(async (t) => {
        const doc = await t.get(loyaltyRef);
        const currentPts = doc.exists ? (doc.data()?.totalPoints || 0) : 0;
        const nextPts = currentPts + pointsEarned;

        if (!doc.exists) {
          t.set(loyaltyRef, {
            userId: after.customerId,
            totalPoints: nextPts,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          t.update(loyaltyRef, {
            totalPoints: nextPts,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }).catch((err) => console.error('Loyalty update failed:', err));
    }
  }

  // B8-1: order-status push copy is rendered from the localized dictionary.
  // The status keys are the single pointer into the shared copy table.
  const statusKey: Record<string, NotificationKey> = {
    preparing: 'orderPreparing',
    ready: 'orderReady',
    pickedUp: 'orderPickedUp',
    delivered: 'orderDelivered',
  };

  // The app writes camelCase 'pickedUp' (order_model.dart `_statusToJson`).
  // Normalise legacy snake_case defensively so old docs still notify.
  const normalizedStatus = after.status === 'picked_up' ? 'pickedUp' : after.status;
  const key = statusKey[normalizedStatus];
  if (!key) return null;
  if (!after.customerId) return null;

  // Fetch the customer's FCM token + notification locale
  const customerDoc = await db.collection('users').doc(after.customerId).get();
  const fcmToken = customerDoc.data()?.fcmToken;
  if (!fcmToken) return null;

  const copy = renderNotification(key, customerDoc.data()?.locale ?? 'en');
  return admin.messaging().send({
    token: fcmToken,
    notification: {title: copy.title, body: copy.body},
    data: {orderId: change.after.id, status: after.status},
  });
});

// ----------------------------------------------------------------------------
// 8. DENORMALIZE USER ROLE TO JWT CUSTOM CLAIMS (Firestore Trigger)
// ----------------------------------------------------------------------------
export const syncUserRoleClaims = onDocumentWritten('users/{uid}', async (event) => {
  const change = event.data;
  if (!change) return null;

  const after = change.after?.data();

  try {
    // P1-5: one function shapes the claims; a privilege change revokes refresh
    // tokens so an old token can never outlive a promotion or a demotion.
    const plan = planClaimSync(change.before?.data(), after);
    await admin.auth().setCustomUserClaims(event.params.uid, plan.claims);
    if (plan.revoke) await admin.auth().revokeRefreshTokens(event.params.uid);
  } catch (error) {
    if ((error as any).code !== 'auth/user-not-found') {
      console.error('Error syncing claims for', event.params.uid, error);
    }
  }
  return null;
});

// ----------------------------------------------------------------------------
// 9. SECURITY & DDOS ALERTING (M1: Audit Log Pub/Sub Sink)
// ----------------------------------------------------------------------------
export const onFirestorePermissionDenied =
    onMessagePublished('firestore-security-alerts', async (event) => {
      const payload = event.data.message.json;
      // Look for signature of permission denied logs routed via GCP Sink
      // 7 = PERMISSION_DENIED
      if (!payload || payload?.protoPayload?.status?.code !== 7) return null;

      const ip = payload.protoPayload?.requestMetadata?.callerIp || 'unknown_ip';

      // B8-3: alert threshold is read from Remote Config once per run (fail-safe
      // to the documented default, 50). The bucket counter and the decision both
      // live in the pure `ddos` module so they are unit-testable.
      const threshold = await fetchDdosAlertThreshold();

      // Track metrics in Firestore (rolling window approximation)
      const metricRef = db.collection('securityMetrics').doc('ddosCounters');

      await db.runTransaction(async (t) => {
        const doc = await t.get(metricRef);
        const now = new Date();

        const currentCount = nextDdosBucketCount(
      doc.exists ? (doc.data() as DdosBucketState) : undefined,
      now,
        );

        t.set(metricRef, {
          currentBucket: now.getMinutes().toString(),
          denyCount: currentCount,
          lastIp: ip,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        // Trigger FCM to Owner Role on reaching the DDOS threshold in a bucket.
        if (shouldTriggerDdosAlert(currentCount, threshold)) {
          const owners = await db.collection('users').where('role', '==', 'owner').get();
          const promises = owners.docs.map(async (ownerDoc): Promise<string | void> => {
            const {fcmToken, locale} = ownerDoc.data();
            if (fcmToken) {
              const copy = renderNotification('ddosAlert', locale ?? 'en', {ip});
              return admin.messaging().send({
                token: fcmToken,
                notification: {title: copy.title, body: copy.body},
              });
            }
            return;
          });
          await Promise.all(promises);
        }
      });

      return null;
    });

/**
 * B8-3: read `ddosAlertThreshold` from Firebase Remote Config. Any failure
 * (Remote Config not provisioned, emulator absent, malformed value) FAILS
 * CLOSED to the documented default — a broken config never disables alerting.
 */
async function fetchDdosAlertThreshold(): Promise<number> {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const param = template.parameters?.['ddosAlertThreshold']?.defaultValue;
    // `defaultValue` is a union: { value: string } or { useInAppDefault: bool }.
    const raw =
      param && typeof param === 'object' && 'value' in param ?
        (param as { value: string }).value :
        undefined;
    return parseDdosAlertThreshold(raw);
  } catch (err) {
    console.error('Remote Config ddosAlertThreshold unavailable; using default', err);
    return DEFAULT_DDOS_ALERT_THRESHOLD;
  }
}

// ----------------------------------------------------------------------------
// 11. STRIPE WEBHOOK (Cryptographic Payment Validation)
// ----------------------------------------------------------------------------
export const MAX_WEBHOOK_EVENTS = 20;

/**
 * MONEY-3 (W3.7 / 06-P2-2): appends a Stripe webhook event to the order's
 * `stripeEvents` log. The log is capped at MAX_WEBHOOK_EVENTS (oldest dropped)
 * and carries ONLY allowlisted scalars — never a raw Stripe payload. Read-
 * modify-write is safe here: webhook deliveries are sequential per event id and
 * the cap is a hard bound on the array size.
 */
export async function appendWebhookEvent(
    db: admin.firestore.Firestore,
    orderRef: admin.firestore.DocumentReference,
    event: {type: string; id?: string; amount?: number},
): Promise<void> {
  const snap = await orderRef.get();
  const data = snap.data() as {stripeEvents?: unknown} | undefined;
  const existing = Array.isArray(data?.stripeEvents) ?
    (data!.stripeEvents as unknown[]) :
    [];
  const next = [
    ...existing,
    {
      type: event.type,
      // Firestore forbids FieldValue transforms (serverTimestamp) INSIDE array
      // elements — a concrete Timestamp value is the only legal per-entry stamp
      // (proven by the emulator harness: the transform throws on every append).
      // Doc-level paymentFailedAt/refundedAt above remain serverTimestamp().
      at: admin.firestore.Timestamp.now(),
      id: event.id ?? null,
      amount: event.amount ?? null,
    },
  ].slice(-MAX_WEBHOOK_EVENTS);
  await orderRef.update({stripeEvents: next});
}

/**
 * MONEY-3 (W3.7): the webhook's event-application core — exported so the money
 * emulator can drive the REAL compiled handler against the REAL Firestore
 * emulator with synthetic Stripe events (signature verification is the
 * onRequest wrapper's job; this function owns the order-doc side effects).
 *
 * Handled event types (beyond the pre-existing `payment_intent.succeeded`):
 *  - `payment_intent.payment_failed` — record `paymentFailedAt` + event.
 *  - `charge.refunded` — resolve the owning order via its `paymentIntentId`
 *    and record `refundedAt` + event (amount = the refunded amount).
 * Every handled event is appended to the size-capped `stripeEvents` log.
 */
export async function applyStripeWebhookEvent(
    db: admin.firestore.Firestore,
    event: {type: string; data: {object: Record<string, any>}},
): Promise<void> {
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object;
    const orderId = paymentIntent.metadata?.orderId;
    if (orderId) {
      const orderRef = db.collection('orders').doc(orderId);
      // The PaymentIntent now carries orderId (set in createPaymentIntent),
      // so this path resolves the owning order and flags payment validation.
      await orderRef.update({
        status: 'confirmed',
        paymentValidatedAt: admin.firestore.FieldValue.serverTimestamp(),
        stripePaymentIntentId: paymentIntent.id,
      });
      await appendWebhookEvent(db, orderRef, {
        type: 'payment_intent.succeeded',
        id: paymentIntent.id,
      });
      console.log(`Order ${orderId} successfully validated via Webhook.`);
    }
    return;
  }

  if (event.type === 'payment_intent.payment_failed') {
    const paymentIntent = event.data.object;
    const orderId = paymentIntent.metadata?.orderId;
    if (orderId) {
      const orderRef = db.collection('orders').doc(orderId);
      await orderRef.update({
        paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await appendWebhookEvent(db, orderRef, {
        type: 'payment_intent.payment_failed',
        id: paymentIntent.id,
      });
      console.log(`Order ${orderId} payment_failed recorded via Webhook.`);
    }
    return;
  }

  if (event.type === 'charge.refunded') {
    const charge = event.data.object;
    const paymentIntentId = charge.payment_intent;
    if (paymentIntentId) {
      // A charge carries its PaymentIntent id; resolve the owning order.
      const snap = await db.collection('orders')
          .where('paymentIntentId', '==', paymentIntentId)
          .limit(1)
          .get();
      if (!snap.empty) {
        const orderRef = snap.docs[0].ref;
        await orderRef.update({
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await appendWebhookEvent(db, orderRef, {
          type: 'charge.refunded',
          id: charge.id,
          amount:
            typeof charge.amount_refunded === 'number' ?
              Math.trunc(charge.amount_refunded) :
              undefined,
        });
        console.log(`Order ${orderRef.id} charge.refunded recorded via Webhook.`);
      }
    }
    return;
  }

  // Unknown event types are intentionally ignored (no-op) — the webhook must
  // acknowledge every delivery to Stripe, but only known events touch state.
}

export const stripeWebhook = onRequest(async (request, response) => {
  const sig = request.headers['stripe-signature'];
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!sig || !endpointSecret) {
    response.status(400).send('Webhook Secret or Signature missing');
    return;
  }

  let event;
  try {
    // We must use the raw body to validate Stripe signatures
    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    event = stripe.webhooks.constructEvent(request.rawBody, sig, endpointSecret);
  } catch (err: any) {
    console.error('Webhook signature verification failed.', err.message);
    response.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Handle the event
  await applyStripeWebhookEvent(db, event);

  response.status(200).send({received: true});
});

// ─── UI-9 (p19): shared delivery-platform ports (T-2 / T-3) ─────────────────
/**
 * Reads the validated `deliveryPlatforms` section of the SERVER-side config
 * doc (`settings/restaurantConfig`) through the one shared selector — the
 * same fail-closed vocabulary the Dart validator and the generator mirror use
 * (pinned to the shared fixture by the platform suites).
 */
async function loadPlatformConfig(): Promise<{
  rows: DeliveryPlatformRow[]; rejected: PlatformConfigViolation[];
}> {
  const snap = await settingsDoc('restaurantConfig').get();
  const data = snap.data() as {deliveryPlatforms?: unknown} | undefined;
  const selection = selectEnabledPlatforms(data?.deliveryPlatforms ?? null);
  const raw = data?.deliveryPlatforms;
  const rows: DeliveryPlatformRow[] = [];
  if (Array.isArray(raw)) {
    for (const entry of raw) {
      if (entry === null || typeof entry !== 'object') continue;
      const row = entry as Record<string, unknown>;
      if (typeof row.id === 'string' &&
          selection.enabled.includes(row.id)) {
        rows.push({
          id: row.id,
          storeId: typeof row.storeId === 'string' ? row.storeId : '',
          credentialRef:
              typeof row.credentialRef === 'string' ? row.credentialRef : '',
        });
      }
    }
  }
  return {rows, rejected: selection.rejected};
}

/** The server-side adapter lookup (L1: one mapper per documented platform). */
function mapperForPlatform(platformId: string): PlatformMapper | null {
  if (platformId === 'uber_eats') return uberEatsMapper;
  if (platformId === 'delivery_hero') return deliveryHeroMapper;
  return null;
}

/** Records one dead-letter entry (shared queue for ingestion + availability). */
async function writePlatformDeadLetter(
    entry: PlatformDeadLetter,
): Promise<void> {
  await db.collection('platform_dead_letters').add({
    ...entry,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─── UI-9 (p19) T-2: platform order ingestion webhook ───────────────────────
// Server-to-server: there is NO App Check token on this route (Law 12 stays
// enforced on every callable) — the per-platform signature verification inside
// `ingestPlatformOrderRequest` IS the trust boundary (T-5). Fail closed:
// unverified ⇒ 401 + security-class log, a platform the config did not enable
// is inert, and every failure lands in the dead-letter queue.
export const ingestPlatformOrder = onRequest(async (request, response) => {
  const platformId = String(request.query.platform ?? '');
  const rawBody = Buffer.isBuffer(request.rawBody) ?
      request.rawBody.toString('utf8') : String(request.rawBody ?? '');
  const rawSignature = platformId === 'uber_eats' ?
      request.headers['x-uber-signature'] :
      request.headers['x-deliveryhero-signature'] ??
      request.headers['x-platform-signature'];
  const signatureHeader = Array.isArray(rawSignature) ?
      rawSignature[0] : rawSignature;
  let payload: unknown = null;
  try {
    payload = rawBody.length > 0 ? JSON.parse(rawBody) : null;
  } catch {
    payload = null; // the mapper's malformed_payload DLQ path handles it
  }
  const {rows, rejected} = await loadPlatformConfig();
  if (rejected.length > 0) {
    // L3: an invalid server-side section is inert for every platform.
    logSecurityAlert({
      fn: 'ingestPlatformOrder',
      event: 'platform_config_rejected',
      rejectedCount: rejected.length,
      firstPath: rejected[0].path,
    });
  }
  const storeId = rows.find((row) => row.id === platformId)?.storeId ?? '';
  const apiBase = platformId === 'uber_eats' ?
      process.env.UBER_EATS_API_BASE ?? 'https://api.uber.com' :
      process.env.DELIVERY_HERO_API_BASE ??
      'https://pos-integrations.deliveryhero.com';
  const deps: PlatformIngestionDeps = {
    isPlatformEnabled: (id) => rows.some((row) => row.id === id),
    mapperFor: (id) => mapperForPlatform(id),
    resolveSigningSecret: async (id) => {
      const ref = rows.find((row) => row.id === id)?.credentialRef ?? '';
      const value = ref.length > 0 ? process.env[ref] : undefined;
      return typeof value === 'string' && value.length > 0 ? value : null;
    },
    fetchOrderDetails: async (id, orderId) => {
      if (id !== 'uber_eats') return null;
      const token = process.env.UBER_EATS_SERVER_TOKEN;
      if (!token) return null;
      const res = await fetch(
          `https://api.uber.com/v2/eats/order/${encodeURIComponent(orderId)}`,
          {headers: {Authorization: `Bearer ${token}`}},
      );
      if (!res.ok) {
        throw new Error(`uber details fetch failed (${res.status})`);
      }
      return await res.json();
    },
    findOrderIdByIdempotencyKey: async (key) => {
      const snap = await db.collection('orders')
          .where('idempotencyKey', '==', key).limit(1).get();
      return snap.empty ? null : snap.docs[0].id;
    },
    loadMenuDocs: async (ids) => {
      if (ids.length === 0) return [];
      const refs = ids.map((id) => db.collection('menus').doc(id));
      const snaps = await db.getAll(...refs);
      return snaps.map((doc) => ({
        exists: doc.exists, data: doc.data() ?? null,
      }));
    },
    persistOrder: async (documentId, document) => {
      await db.collection('orders').doc(documentId).set(document);
    },
    callPlatform: async (ack) => {
      const res = await fetch(`${apiBase}${ack.path}`, {
        method: ack.method,
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(ack.body),
      });
      return {status: res.status};
    },
    publishDeadLetter: async (entry) => {
      await writePlatformDeadLetter(entry);
    },
    newOrderId: () => db.collection('orders').doc().id,
    log: (event) => {
      logger.warn('platform_ingestion', event);
    },
  };
  const result = await ingestPlatformOrderRequest(deps, {
    platformId,
    rawBody,
    signatureHeader,
    storeId,
    payload,
  });
  if (result.httpStatus >= 400) {
    // Rejections land in the security-class log stream (T-5 boundary note).
    logSecurityAlert({
      fn: 'ingestPlatformOrder',
      event: 'platform_webhook_rejected',
      platformId,
      httpStatus: result.httpStatus,
      reason: String(result.body.reason ?? result.body.status ?? 'unknown'),
    });
  }
  response.status(result.httpStatus).json(result.body);
});

// ─── UI-9 (p19) T-3: menu availability → platform catalog sync ──────────────
// Fail-safe: the app's own `menus/{itemId}` write has ALREADY committed when
// this event fires — a platform outage is RETRIED in-invocation and then
// recorded in the dead-letter queue (publishDeadLetter), never thrown back
// into the menus write path (T-5). Event-driven route: no app traffic, so
// App Check is irrelevant here as well (it stays enforced on callables).
export const syncMenuAvailability = onDocumentWritten(
    'menus/{itemId}',
    async (event) => {
      const before = event.data?.before.data() ?? null;
      const after = event.data?.after.data() ?? null;
      const change = detectAvailabilityChange(before, after);
      if (!change) return null;
      const {rows} = await loadPlatformConfig();
      const targets: AvailabilityTarget[] = rows.map((row) => ({
        platformId: row.id,
        storeId: row.storeId,
        mapper: mapperForPlatform(row.id),
      }));
      const deps: AvailabilityDeps = {
        attempt: 0,
        maxAttempts: 3,
        targets: async () => targets,
        callPlatform: async (request) => {
          const res = await fetch(request.url, {
            method: request.method,
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(request.body),
          });
          return {status: res.status};
        },
        publishDeadLetter: async (entry) => {
          await writePlatformDeadLetter(entry);
        },
        log: (platformEvent) => {
          logger.warn('platform_availability', platformEvent);
        },
      };
      const availabilityChange = {
        menuItemId: event.params.itemId,
        branchId: typeof after?.branchId === 'string' ? after.branchId : '',
        isAvailable: change.isAvailable,
      };
      // In-invocation retries: rounds 0..maxAttempts-1 while anything is left
      // in `retried`; a failure that outlives every round dead-letters via the
      // classify step — the menus write path still never sees a throw.
      let summary = await syncAvailability(deps, availabilityChange);
      let round = 1;
      while (round < deps.maxAttempts && summary.retried.length > 0) {
        deps.attempt = round;
        summary = await syncAvailability(deps, availabilityChange);
        round += 1;
      }
      logger.info('platform availability sync', {
        menuItemId: event.params.itemId,
        pushed: summary.pushed,
        retried: summary.retried,
        deadLettered: summary.deadLettered,
        skipped: summary.skipped,
      });
      return null;
    },
);

// ----------------------------------------------------------------------------
// 10. RESERVATION NOTIFICATIONS (Owner/Manager push on success)
// ----------------------------------------------------------------------------
/**
 * Format the reservation time for a push notification.
 * The app writes `startTime` (Firestore Timestamp) + `partySize` + `customerName`
 * (reservations_repository.dart) — not `date`/`slot`.
 */
function formatReservationTime(value: unknown): string {
  if (!value) return 'unknown time';
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'object' && value !== null) {
    const candidate = value as { toDate?: () => unknown };
    if (typeof candidate.toDate === 'function') {
      const d = candidate.toDate();
      if (d instanceof Date) return d.toISOString();
    }
  }
  return String(value);
}

export const onReservationCreated = onDocumentCreated('reservations/{resId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;
  const data = snapshot.data();

  // Fetch owners/managers to notify
  const staff = await db.collection('users')
      .where('role', 'in', ['owner', 'manager'])
      .get();

  const promises = staff.docs.map(async (doc) => {
    const user = doc.data();
    // Only notify managers if they belong to the same branch
    if (user.role === 'manager' && user.branchId !== data.branchId) return;

    if (user.fcmToken) {
      // B8-1: reservation push copy per staff member's locale.
      const copy = renderNotification('newReservation', user.locale ?? 'en', {
        customerName: data.customerName ?? 'A customer',
        partySize: data.partySize ?? '?',
        time: formatReservationTime(data.startTime),
      });
      return admin.messaging().send({
        token: user.fcmToken,
        notification: {title: copy.title, body: copy.body},
      });
    }
    return null;
  });

  await Promise.all(promises);
  return null;
});

// ----------------------------------------------------------------------------
// 12. IMMUTABLE AUDIT LOG (Law 36: Track Sensitive Architecture Writes)
// ----------------------------------------------------------------------------

export const auditSettingsChanges = onDocumentWritten('settings/{docId}', async (event) => {
  const change = event.data;
  if (!change) return null;
  const docId = event.params.docId;

  // Track creation, modification, or deletion
  let action = 'UPDATE';
  if (!change.before.exists) action = 'CREATE';
  if (!change.after.exists) action = 'DELETE';

  return db.collection('audit_log').add({
    collection: 'settings',
    documentId: docId,
    action,
    before: change.before.data() ?? null,
    after: change.after.data() ?? null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
});

export const auditRoleChanges = onDocumentWritten('users/{uid}', async (event) => {
  const change = event.data;
  if (!change) return null;

  const beforeRole = change.before.data()?.role;
  const afterRole = change.after.data()?.role;

  // Only audit if the specific 'role' field was mutated
  if (beforeRole !== afterRole) {
    return db.collection('audit_log').add({
      collection: 'users',
      documentId: event.params.uid,
      action: 'ROLE_CHANGE',
      beforeRole: beforeRole ?? null,
      afterRole: afterRole ?? 'none',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return null;
});

// ----------------------------------------------------------------------------
// 12. CASH AT THE COUNTER (P2-1 — D-057, D-059)
//
// A cash sale has no PaymentIntent, so `createOrder` cannot carry it (it
// retrieves the intent unconditionally). This pair is the server path the
// counter uses instead, holding the same money rules:
//   * the server re-prices every line from `menus` (never the client's price),
//   * tax and currency come from `resolveChargeTaxAndPromo` — the SAME seam the
//     card path charges with, now tenant-aware,
//   * the order and its `sale_` row commit in ONE transaction (ledger v2),
//   * authority is the capability table (`payment.take`), never a role list
//     written here, and tenancy is the verified `tenantId` claim.
// ----------------------------------------------------------------------------

const cashOrderLineSchema = z.object({
  menuItemId: z.string().min(1).max(128),
  quantity: z.number().int().min(1).max(50),
  /**
   * The unit price the counter DISPLAYED. Not trusted for money — the subtotal
   * comes from the menu — but `verifyMenuPricing` aborts when it disagrees with
   * the menu, so a stale ticket cannot be rung up at yesterday's price.
   */
  priceCents: z.number().int().min(0).max(100_000_000),
  selectedOptions: z.array(z.object({id: z.string().min(1).max(128)})).max(20).optional(),
});

export const createCashOrderSchema = z.object({
  lines: z.array(cashOrderLineSchema).min(1).max(50),
  amountTenderedCents: z.number().int().min(0).max(100_000_000),
  idempotencyKey: z.string().min(8).max(128),
  /** Tax jurisdiction + config key, exactly what the charge path takes. */
  clientId: z.string().min(1).max(128),
  stateCode: z.string().min(1).max(16),
  guestName: z.string().max(80).optional(),
  orderNumber: z.string().max(32).optional(),
});

export const voidCashSaleSchema = z.object({
  orderId: z.string().min(1).max(128),
  reason: z.string().min(3).max(200),
});

/** The verified tenant of a staff token; a token without one cannot sell. */
function requireTenantClaim(token: unknown): string {
  const tenantId = (token as Record<string, unknown> | undefined)?.tenantId;
  if (typeof tenantId !== 'string' || tenantId.trim().length === 0) {
    throw new HttpsError(
        'permission-denied',
        'This account carries no tenantId claim, so it cannot take a sale',
    );
  }
  return tenantId;
}

/** Maps the pure builders' named failures onto the callable error vocabulary. */
function cashErrorToHttps(error: unknown): HttpsError {
  if (error instanceof CashSaleError) {
    return new HttpsError('failed-precondition', error.message, {field: error.field});
  }
  if (error instanceof HttpsError) return error;
  return new HttpsError('internal', 'Internal server error');
}

/**
 * DB-touching core of `createCashOrder` (exported for the emulator harness, the
 * same pattern as `createChargeIntentCore`). Never reads a client price, a
 * client total or a client tenant.
 */
export async function createCashOrderCore(input: {
  uid: string;
  tenantId: string;
  staffRoles?: string[];
  payload: z.infer<typeof createCashOrderSchema>;
  now?: Date;
}): Promise<{
  orderId: string;
  orderNumber: string | null;
  totalCents: number;
  changeCents: number;
  idempotent: boolean;
  ledger: 'appended' | 'kept';
}> {
  const payload = input.payload;
  const now = input.now ?? new Date();

  // IDEMPOTENCY (Law 9): a double-tap on tender must not write a second sale.
  // The key is scoped to the caller: a key that belongs to someone else is a
  // conflict, never silently returned.
  const existing = await db.collection('orders')
      .where('idempotencyKey', '==', payload.idempotencyKey)
      .limit(1)
      .get();
  if (!existing.empty) {
    const doc = existing.docs[0];
    const data = doc.data() as Record<string, unknown>;
    if (data.staffId !== input.uid || data.tenantId !== input.tenantId) {
      logSecurityAlert({
        fn: 'createCashOrder',
        event: 'cash_idempotency_conflict',
        orderId: doc.id,
        idempotencyKey: payload.idempotencyKey,
      });
      throw new HttpsError(
          'already-exists',
          'Idempotency key was already used by a different sale',
          {code: 'IDEMPOTENCY_CONFLICT'},
      );
    }
    return {
      orderId: doc.id,
      orderNumber: typeof data.orderNumber === 'string' ? data.orderNumber : null,
      totalCents: Number(data.totalCents ?? 0),
      changeCents: Number(data.changeCents ?? 0),
      idempotent: true,
      ledger: 'kept',
    };
  }

  try {
    // (1) Re-price every line from the menu — the client supplies ids only.
    const pricingInput: MenuPricingClientItem[] = payload.lines.map((line) => ({
      id: line.menuItemId,
      quantity: line.quantity,
      priceCents: line.priceCents,
      selectedOptions: line.selectedOptions ?? [],
    }));
    const menuSnaps = await db.getAll(
        ...pricingInput.map((line) => db.collection('menus').doc(line.id)),
    );
    const menuDocs: MenuDocSnapshot[] = menuSnaps.map((snap) => ({
      exists: snap.exists,
      data: (snap.data() as Record<string, unknown> | undefined) ?? null,
    }));
    const pricing = verifyMenuPricing(pricingInput, menuDocs);
    if (!pricing.ok || typeof pricing.itemsSubtotalCents !== 'number') {
      throw new HttpsError(
          'failed-precondition',
          pricing.reason ?? 'Cart does not match the menu',
      );
    }
    if (!Array.isArray(pricing.canonicalItems) || pricing.canonicalItems.length === 0) {
      throw new HttpsError(
          'failed-precondition',
          'Menu items did not resolve to priced lines',
      );
    }
    const branchId = typeof pricing.branchId === 'string' ? pricing.branchId : '';
    if (branchId.length === 0) {
      throw new HttpsError(
          'failed-precondition',
          'Menu items do not resolve to a single branch',
      );
    }

    // (2) Tax + currency, server-derived, tenant-aware, no promo on a cash sale.
    const {taxCents, taxRate, currency} = await resolveChargeTaxAndPromo({
      clientId: payload.clientId,
      stateCode: payload.stateCode,
      itemsSubtotalCents: pricing.itemsSubtotalCents,
      code: null,
      tenantId: input.tenantId,
    });

    // (3) Shape the order + row, then commit them together.
    const orderId = db.collection('orders').doc().id;
    const orderNumber = payload.orderNumber ?? await nextServerOrderNumber();
    const {order, ledgerInput} = buildCashSale({
      orderId,
      orderNumber,
      tenantId: input.tenantId,
      branchId,
      staffId: input.uid,
      staffRoles: input.staffRoles,
      guestName: payload.guestName,
      itemsSubtotalCents: pricing.itemsSubtotalCents,
      taxCents,
      taxRate,
      currency,
      canonicalItems: pricing.canonicalItems,
      amountTenderedCents: payload.amountTenderedCents,
      now,
    });
    // Idempotency + provenance on the order document (the row's id derives from
    // the order id, so a replay addresses the same row).
    order.idempotencyKey = payload.idempotencyKey;
    order.paymentConfirmedAt = admin.firestore.FieldValue.serverTimestamp();

    const ledger = await commitOrderWithLedger(
        db as unknown as LedgerStore,
        db.collection('orders').doc(orderId),
        order,
        buildSaleRow(ledgerInput),
    );

    return {
      orderId,
      orderNumber: typeof order.orderNumber === 'string' ? order.orderNumber : null,
      totalCents: Number(order.totalCents),
      changeCents: Number(order.changeCents),
      idempotent: false,
      ledger,
    };
  } catch (error) {
    throw cashErrorToHttps(error);
  }
}

export const createCashOrder = onCall(async (request) => {
  enforceAppCheck(request, 'createCashOrder');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  // Authority comes from the capability table, not from a role list here.
  const gate = assertCapability(request.auth, 'payment.take');
  if (!gate.ok) {
    throw new HttpsError(
        capabilityDenialCode(gate) ?? 'permission-denied',
        `Not permitted to take payment: ${gate.reason}`,
    );
  }

  const parsed = createCashOrderSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'Invalid request payload', parsed.error.issues);
  }

  return createCashOrderCore({
    uid: request.auth.uid,
    tenantId: requireTenantClaim(request.auth.token),
    staffRoles: [...gate.roles],
    payload: parsed.data,
  });
});

/**
 * DB-touching core of `voidCashSale`: cancels the order and appends the reversal
 * row in one transaction. A card sale is refused by the builder — its money is
 * undone through Stripe, and two ways to reverse one charge is how a ledger
 * starts disagreeing with a processor.
 */
export async function voidCashSaleCore(input: {
  uid: string;
  tenantId: string;
  orderId: string;
  reason: string;
  now?: Date;
}): Promise<{orderId: string; reversalId: string; ledger: 'appended' | 'kept'}> {
  const orderRef = db.collection('orders').doc(input.orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Order not found');

  const orderData = orderSnap.data() as Record<string, unknown>;
  if (orderData.tenantId !== input.tenantId) {
    // Cross-tenant: fail closed and say nothing about the row.
    throw new HttpsError('not-found', 'Order not found');
  }
  if (orderData.status === 'cancelled') {
    throw new HttpsError('failed-precondition', 'Order is already cancelled');
  }

  const saleRef = db.collection('transactions').doc(`sale_${input.orderId}`);
  const saleSnap = await saleRef.get();
  if (!saleSnap.exists) {
    throw new HttpsError(
        'failed-precondition',
        'This order has no sale row to reverse — it was never charged',
    );
  }

  try {
    const {orderPatch, reversalRow} = buildCashVoid({
      order: {...orderData, id: input.orderId},
      saleRow: saleSnap.data() as Record<string, unknown>,
      reason: input.reason,
      actorUid: input.uid,
      now: input.now ?? new Date(),
    });
    const ledger = await commitVoidWithReversal(
        db as unknown as LedgerStore,
        saleRef,
        reversalRow,
        orderRef,
        orderPatch,
    );
    return {
      orderId: input.orderId,
      reversalId: String(reversalRow.id),
      ledger,
    };
  } catch (error) {
    throw cashErrorToHttps(error);
  }
}

export const voidCashSale = onCall(async (request) => {
  enforceAppCheck(request, 'voidCashSale');
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  // A reversal needs `payment.reverse`: counter staff take money, a manager
  // undoes it (permissions.ts, P1-1's table).
  const gate = assertCapability(request.auth, 'payment.reverse');
  if (!gate.ok) {
    throw new HttpsError(
        capabilityDenialCode(gate) ?? 'permission-denied',
        `Not permitted to reverse a payment: ${gate.reason}`,
    );
  }

  const parsed = voidCashSaleSchema.safeParse(request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'Invalid request payload', parsed.error.issues);
  }

  return voidCashSaleCore({
    uid: request.auth.uid,
    tenantId: requireTenantClaim(request.auth.token),
    orderId: parsed.data.orderId,
    reason: parsed.data.reason,
  });
});
