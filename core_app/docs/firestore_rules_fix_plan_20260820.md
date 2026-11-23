# 🔧 Firestore Rules — Verified Fix Plan (Best Solutions)
> **Date:** 2026-08-20 · **Companion to:** `firestore_rules_audit_20260820.md` · **Every fix verified against actual app code.**

---

## VERIFICATION EVIDENCE (Read Before Implementing)

Each finding below is cross-referenced to the exact source line that proves it.

| # | Code Fact | File : Line |
|---|---|---|
| V1 | `OrderModel` enum writes **`pickedUp`** (camelCase) to Firestore via `_statusToJson(status) => status.name` | `core_app/lib/features/orders/domain/order_model.dart:34` & `:50` |
| V2 | The delivery dashboard writes `OrderStatus.pickedUp.name` → **`pickedUp`** | `core_app/lib/features/admin/domain/delivery_service.dart` (search hit `'status': OrderStatus.pickedUp.name`) |
| V3 | Driver GPS is published to **`deliveries/{orderId}`** with fields `lat/lng/heading/speed/timestamp` | `core_app/lib/features/tracking/data/driver_location_service.dart:99-105` |
| V4 | Rules contain **`match /driverLocations/{driverId}`** — a DIFFERENT collection with NO app writer → live GPS is currently DENIED (no `deliveries` match) | `core_app/firestore.rules:209` |
| V5 | User profile create always writes `role: 'customer'` — the `e2e_*` regex bypass in rules has no legitimate production path | `packages/core/lib/src/auth/auth_repository.dart:160-170` |
| V6 | Order create writes `customerId`, `branchId`, `items`, `totalCents`, `status`, `createdAt` (server timestamp) | `core_app/lib/features/orders/domain/order_model.dart:40-60` + auth repo pattern |
| V7 | Menu model uses **`priceCents`**, but `MenuRepository._syncFromFirestore` reads **`price`** (mismatch — seed data must use `priceCents`) | `core_app/lib/features/admin/domain/menu_item_model.dart` vs `core_app/lib/features/menu/data/menu_repository.dart:81` |
| V8 | Constitution: `menus.branchId` **null = global item** (visible to all branches) | `CARNAMA_CONSTITUTION.md` Part 5 |
| V9 | `settings/featureFlags` is read before login (public) — other settings should NOT be | `core_app/firestore.rules:72` + Constitution Part 5 |
| V10 | `orders` status values written by app: `pending, confirmed, preparing, ready, pickedUp, delivered, cancelled` | `order_model.dart:9-18` |

---

## 🔧 FIX C-1 — Remove the E2E Role-Escalation Backdoor

**Verified root cause:** Rules lines 104–106 and 122–123 grant any self-registering user with an `e2e_*@example.com` / `e2e_*@carnama.com` email the ability to set `role: 'owner'` and any `branchId` on `users` doc **create**. V5 proves the app itself always writes `role: 'customer'` — the bypass has zero legitimate production users.

**Best solution:** Delete the email-regex escape hatch entirely. Handle emulator seeding via the existing seed script / Admin SDK, not production rules.

```javascript
// users write — REPLACE the creation block (V5-compliant)
(resource == null ?
   (!request.resource.data.keys().hasAny(['role']) ||
    request.resource.data.role == 'customer')
   :
   (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
    request.auth.uid != userId)
) &&

// Only owners write branchId (V5-compliant)
(resource == null ?
   (!request.resource.data.keys().hasAny(['branchId']) ||
    request.resource.data.branchId == '')
   :
   (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) ||
    isOwner())
);
```

**Verification:**
```bash
# Emulator rules test must PROVE:
# 1. New user with role:'owner' on create → DENIED
# 2. New user with role:'customer' on create → ALLOWED
# 3. User updating their own role → DENIED
# 4. Owner updating another user's role → ALLOWED
```

---

## 🔧 FIX C-2 — Lock Kitchen/Delivery Order Updates + FIX STATUS NAMES (New Critical)

**Verified root cause (2 parts):**
1. **Security:** Kitchen (lines 154–157) and delivery (lines 158–162) update rules lack `.hasOnly(...)` — any field (`totalCents`, `items`, `customerId`) is writable during a status transition.
2. **Functionality (V1, V2):** The rules check `picked_up` (snake_case) but the app writes **`pickedUp`** (camelCase). Even after locking fields, `request.resource.data.status in ['picked_up', 'delivered']` would **DENY** the only status the app actually writes. Drivers could never complete delivery.

**Best solution:** Lock both roles to `hasOnly(['status'])` AND use the app's real status strings.

```javascript
// orders update — kitchen branch (C-2 fix + V1/V2 status names)
(userRole() == 'kitchen' &&
  resource.data.branchId == userBranch() &&
  resource.data.status in ['confirmed', 'preparing'] &&
  request.resource.data.status in ['preparing', 'ready'] &&
  request.resource.data.diff(resource.data)
    .affectedKeys().hasOnly(['status'])) ||

// orders update — delivery branch (C-2 fix + V1/V2 status names)
(userRole() == 'delivery' &&
  resource.data.assignedDriverId == request.auth.uid &&
  resource.data.status in ['ready', 'pickedUp'] &&
  request.resource.data.status in ['pickedUp', 'delivered'] &&
  request.resource.data.diff(resource.data)
    .affectedKeys().hasOnly(['status']))
```

Also fix the READ rule status list to match app values:
```javascript
(userRole() == 'delivery' &&
  resource.data.branchId == userBranch() &&
  (resource.data.status in ['ready', 'pickedUp'] ||
   resource.data.assignedDriverId == request.auth.uid))
```

**Verification:** Emulator test — delivery user writes `{status: 'pickedUp'}` → ALLOWED; delivery user writes `{status: 'pickedUp', totalCents: 0}` → DENIED.

---

## 🔧 FIX C-3 — Make Menu `branchId` Immutable + Validate Prices

**Verified root cause:** Rules line 51 uses `||` so an update passes if the EXISTING item is in the manager's branch, even when the new payload moves it elsewhere.

**Best solution (V8-aware):** On update, `branchId` may not change. On create, global items (`branchId == ''`) are owner-only; branch items must match the manager's branch.

```javascript
match /menus/{itemId} {
  allow read: if true;

  allow create: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
    (isOwner() ||
     (userRole() == 'manager' &&
      request.resource.data.branchId == userBranch())) &&
    request.resource.data.name is string &&
    request.resource.data.name.size() > 0 &&
    request.resource.data.priceCents is int &&
    request.resource.data.priceCents >= 0;

  allow update: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
    (isOwner() ||
     (userRole() == 'manager' && resource.data.branchId == userBranch())) &&
    !request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) &&
    request.resource.data.name is string &&
    request.resource.data.name.size() > 0 &&
    request.resource.data.priceCents is int &&
    request.resource.data.priceCents >= 0;

  allow delete: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
    (isOwner() ||
     (userRole() == 'manager' && resource.data.branchId == userBranch()));
}
```

> ⚠️ **V7 NOTE (data model drift):** `MenuRepository._syncFromFirestore` reads `data['price']` but the model field is `priceCents`. Harmonise the seed data / repository to `priceCents` before deploy, or menu pricing breaks in the client app. Flag this in the implementation prompt.

**Verification:** Emulator test — manager updates `branchId` on their item → DENIED; manager updates `priceCents` on their item → ALLOWED; negative price → DENIED.

---

## 🔧 FIX W-1 — Add `deliveries` Collection Rules (Currently Broken Feature)

**Verified root cause (V3, V4):** The live-GPS service writes `deliveries/{orderId}` (lat/lng/heading/speed/timestamp, server timestamp), but the rules only cover `driverLocations`. **Every GPS write is currently `PERMISSION_DENIED`** → customer tracking is dead. This is Law 8 fail-closed protecting you, but the feature is silently broken.

**Best solution:** Add a correct `deliveries` match keyed by orderId, scoped to the ASSIGNED driver via cross-doc read. Keep `driverLocations` for the separate fleet map feature (if still used).

```javascript
// LIVE GPS — written by the assigned driver only (V3-shaped)
match /deliveries/{orderId} {
  allow read: if isAuthenticated() && !isAnonymous() &&
    (userRole() in ['owner', 'manager', 'kitchen'] ||
     (userRole() == 'delivery' &&
      get(/databases/$(database)/documents/orders/$(orderId)).data.assignedDriverId == request.auth.uid) ||
     (userRole() == 'customer' &&
      get(/databases/$(database)/documents/orders/$(orderId)).data.customerId == request.auth.uid));

  allow create, update: if isAuthenticated() && !isAnonymous() &&
    userRole() == 'delivery' &&
    get(/databases/$(database)/documents/orders/$(orderId)).data.assignedDriverId == request.auth.uid &&
    OrderStatusIsActive(get(/databases/$(database)/documents/orders/$(orderId)).data.status) &&
    request.resource.data.keys().hasOnly(['lat', 'lng', 'heading', 'speed', 'timestamp']) &&
    request.resource.data.lat is number &&
    request.resource.data.lng is number;

  allow delete: if false;
}

// helper — only track active deliveries
function OrderStatusIsActive(status) {
  return status in ['confirmed', 'preparing', 'ready', 'pickedUp'];
}
```

**Verification:** Emulator test — customer writes `deliveries/{orderId}` → DENIED; unassigned driver writes → DENIED; assigned driver writes valid shape → ALLOWED; assigned driver writes extra field → DENIED.

---

## 🔧 FIX W-2 — Validate Reservations (Create Pending Only + Locked Updates)

**Best solution:**
```javascript
match /reservations/{resId} {
  allow read: if isAuthenticated() && !isAnonymous() &&
    (userRole() in ['owner', 'manager'] ||
     resource.data.customerId == request.auth.uid);

  allow create: if isAuthenticated() && !isAnonymous() &&
    request.resource.data.customerId == request.auth.uid &&
    request.resource.data.status == 'pending' &&
    request.resource.data.branchId is string &&
    request.resource.data.branchId.size() > 0 &&
    request.resource.data.keys().hasOnly(
      ['customerId', 'branchId', 'date', 'slot', 'status', 'partySize', 'createdAt']);

  allow update: if isAuthenticated() && !isAnonymous() &&
    (userRole() in ['owner', 'manager'] ||
     (resource.data.customerId == request.auth.uid &&
      !request.resource.data.diff(resource.data)
         .affectedKeys().hasAny(['customerId', 'branchId', 'status', 'slot'])));

  allow delete: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
}
```
> ⚠️ Confirm exact reservation fields against `reservations_repository.dart` before finalising `hasOnly` — adjust the key list to the app's real payload.

---

## 🔧 FIX W-3 — Promote Codes Owner-Only

```javascript
match /promoCodes/{code} {
  allow read: if isAuthenticated() && !isAnonymous();
  allow write: if isAuthenticated() && !isAnonymous() && isOwner();
}
```
Constitution: managers are branch-scoped; a global-value promo system is owner territory.

---

## 🔧 FIX W-4 — Lock Reservation-Lock Reads

```javascript
allow read: if isAuthenticated() && !isAnonymous() &&
  (userRole() in ['owner', 'manager'] ||
   resource.data.userId == request.auth.uid);
```

---

## 🔧 FIX W-5 — Settings + Analytics Anonymous Access

```javascript
// settings — only featureFlags is public (V9)
match /settings/{doc} {
  allow read: if doc == 'featureFlags' || isOwner();
  allow write: if isOwner() && doc == 'featureFlags';
}

// analyticsEvents — no anonymous writes
allow create: if isAuthenticated() && !isAnonymous();
```

---

## 🔧 FIX W-9 — OwnerInfo Mutable-Ownership (Best: Cloud Function)

**Best solution:** Remove direct `settings/ownerInfo` write from client rules; add an HTTPS callable `transferOwnership(newEmail)` in `functions/src/index.ts` that:
1. Verifies the caller is the current owner (`isOwner()` equivalent server-side).
2. Writes a `transfer_request` doc for dual-approval.
3. Appends to `audit_log` (Law 36) with old/new email + timestamp.

Rules side (fail-closed):
```javascript
match /settings/{doc} {
  allow read: if doc == 'featureFlags' || isOwner();
  allow write: if isOwner() && doc == 'featureFlags';
  // settings/ownerInfo: NO client write — callable transferOwnership only
}
```
Callable functions bypass client rules (Admin SDK) — no rules change needed for the function itself beyond removing the client path.

---

## 🔧 FIX W-6 — App Check Platform Verification (Deployment Gate)

`isAppVerified()` relies on `request.auth.token.app_id` (Android) / `firebase.app_check_token` (iOS). Verify before deploy:
- [ ] Android + iOS App Check enrolled in Firebase console
- [ ] Windows / Web builds EITHER enrolled in App Check OR excluded from `isAppVerified()` paths
- [ ] `staging.firestore.rules` retains the lenient version for emulator/demo runs

**Basic hygiene fix (safe everywhere):** normalize anonymous-user writes (W-5) and keep `isAppVerified()` on all non-public writes.

---

## 🔧 FIX W-10 — (Covered in C-3) Menu Field Validation
See C-3 rules above — `name`/`priceCents` validation added to create/update.

---

## ✅ POST-FIX VERIFICATION SUITE (Run Before Deploy)

```bash
# 1. Rules syntax check
firebase deploy --only firestore:rules --dry-run        # (or emulator)

# 2. Emulator rules tests (create test/rules/ directory)
firebase emulators:exec "node test/rules/run_tests.js"

# 3. Flutter analyzer + tests (ensures the collection 'deliveries' mismatch
#    and any repo refactors are caught)
cd core_app && flutter analyze && flutter test

# 4. Grep regression — no snake_case 'picked_up' left in rules
grep -rn "picked_up" core_app/firestore.rules   # expect: 0 matches

# 5. Grep regression — rules collections match app collections
#    app writes: users, orders, menus, cart, reservations, reservation_locks,
#                deliveries, promoCodes, promotions, settings, analyticsEvents,
#                proof_of_delivery, promo_usage, waitlist, audit_log, presence
grep -n "match /" core_app/firestore.rules

# 6. Payload audit — every hasOnly() key list matches the app's real write payloads
#    (verified via order_model.dart, auth_repository.dart, driver_location_service.dart)
```

---

## □ IMPLEMENTATION ORDER (Dependency-Safe)

1. **C-1** — Remove e2e backdoor (blocks privesc; no dependency).
2. **C-2** — Lock kitchen/delivery updates + fix `pickedUp` status names (blocks financial tampering AND fixes broken delivery flow).
3. **W-1** — Add `deliveries` rules (unbreaks live customer tracking).
4. **C-3** — Menu `branchId` immutability + field validation.
5. **W-2, W-3, W-4, W-5** — Reservations, promoCodes, locks, settings/analytics hardening.
6. **W-9** — Cloud Function `transferOwnership` (separate PR; rules change is just removing the ownerInfo write path).
7. **Deploy + verify** with the suite above, plus human sign-off (Law 51).