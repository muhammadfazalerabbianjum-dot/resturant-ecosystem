# 🔐 Firestore Security Rules Audit — Carnama Constitution Compliance
> **Audit Date:** 2026-08-20 · **Target:** `core_app/firestore.rules` (274 lines) · **Constitution:** v2.0

---

## ⚠️ AUDIT SCOPE CORRECTION (Prompt vs. Reality)

The audit prompt assumed the app uses these collections:

| Prompt Claim | ACTUAL Reality (verified in code) |
|---|---|
| `settings/taxRates/{clientId}` | **DOES NOT EXIST.** Tax is computed server-side via the `calculateTax` Cloud Function (`packages/core/lib/src/tax/tax_service.dart`). No `taxRates` path in rules, no `taxRates` string in any Dart file. |
| `orders` scoped via `clientId` field | **INCORRECT.** `OrderModel` uses `customerId` + `branchId` (`core_app/lib/features/orders/domain/order_model.dart`). Zero occurrences of `clientId` in the codebase. |
| Menu items "client-scoped" | Scoped by **`branchId`**, not clientId. |
| `cart` per user | CONFIRMED — `carts/{userId}` keyed by uid. |

This audit audits the rules against the **real** model, not the prompt's fiction.

---

## STEP 1 — RAW RULES CONTENT (Audited File)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── App Check enforcement (Law 12 — Security by Least Privilege) ─
    function isAppVerified() {
      return request.auth != null &&
        (request.auth.token.app_id != null ||
         request.auth.token.firebase.app_check_token != null);
    }

    // ── Auth helpers ─────────────────────────────────────────────────
    function isAuthenticated() {
      return request.auth != null;
    }

    function isAnonymous() {
      return isAuthenticated() &&
        request.auth.token.firebase.sign_in_provider == 'anonymous';
    }

    function isOwner() {
      return isAuthenticated() &&
        !isAnonymous() &&
        exists(/databases/$(database)/documents/settings/ownerInfo) &&
        get(/databases/$(database)/documents/settings/ownerInfo).data.ownerEmail == request.auth.token.email;
    }

    function userRole() {
      return (isAuthenticated() && !isAnonymous() &&
              exists(/databases/$(database)/documents/users/$(request.auth.uid)))
             ? get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role
             : 'none';
    }

    function userBranch() {
      return (isAuthenticated() && !isAnonymous() &&
              exists(/databases/$(database)/documents/users/$(request.auth.uid)))
             ? get(/databases/$(database)/documents/users/$(request.auth.uid)).data.branchId
             : 'none';
    }

    // ── PUBLIC READS (browsing requires no login — guest mode support) ──
    match /menus/{itemId} {
      allow read: if true; // Public: menu browsing is unauthenticated
      allow create, update, delete: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (isOwner() ||
         (userRole() == 'manager' &&
          (request.resource.data.branchId == userBranch() ||
           resource.data.branchId == userBranch())));
    }

    match /branches/{branchId} {
      allow read: if true; // Public: branch info is unauthenticated
      allow write: if isOwner();

      match /config/{configDoc} {
        allow read: if true; // Public: operating hours needed on checkout
        allow write: if isOwner();
      }
    }

    match /promotions/{promoId} {
      allow read: if true; // Public: promo banners visible to guests
      allow write: if isOwner();
    }

    match /settings/{doc} {
      // settings/featureFlags is public so the app can gate features before login
      allow read: if doc == 'featureFlags' || isAuthenticated();
      allow write: if isOwner();
    }

    // ── AUTHENTICATED-ONLY ────────────────────────────────────────────

    match /admins/{doc} {
      allow read, write: if isOwner();
    }

    match /loyalty/{userId} {
      allow read, write: if isAppVerified() && isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
    }

    // ── users ─────────────────────────────────────────────────────────
    match /users/{userId} {
      allow read: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (request.auth.uid == userId || userRole() in ['owner', 'manager']);

      allow write: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (request.auth.uid == userId ||
         userRole() == 'owner' ||
         (userRole() == 'manager' &&
          resource.data.branchId == userBranch() &&
          (!request.resource.data.keys().hasAny(['role']) ||
           request.resource.data.role in ['kitchen', 'delivery', 'customer']))) &&

        // ANTI-SELF-DEMOTION: Authenticated user CANNOT change their own role field under ANY circumstances
        (resource == null ? 
           (!request.resource.data.keys().hasAny(['role']) || request.resource.data.role == 'customer' || request.resource.data.email.matches('.*e2e_.*@example\\.com') || request.resource.data.email.matches('.*e2e_.*@carnama\\.com')) 
           : 
           (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) || request.auth.uid != userId)
        ) &&

        // THE OWNER CANNOT BE DEMOTED by anyone except via a full owner replacement
        (resource == null || !('email' in resource.data) ||
         !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
         request.resource.data.role == resource.data.role ||
         !(exists(/databases/$(database)/documents/settings/ownerInfo) &&
           get(/databases/$(database)/documents/settings/ownerInfo).data.ownerEmail == resource.data.email) ||
         isOwner()) &&

        // Only owners can write branchId (Law 12)
        (resource == null ? 
           (request.resource.data.email.matches('.*e2e_.*@carnama\\.com') || !request.resource.data.keys().hasAny(['branchId']) || request.resource.data.branchId == '')
           :
           (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) || isOwner())
        );
    }

    // ── orders ────────────────────────────────────────────────────────
    match /orders/{orderId} {
      allow read: if isAppVerified() && isAuthenticated() && !isAnonymous() && (
        userRole() == 'owner' ||
        (userRole() == 'manager' && resource.data.branchId == userBranch()) ||
        (userRole() == 'kitchen' &&
          resource.data.branchId == userBranch() &&
          resource.data.status in ['confirmed', 'preparing']) ||
        (userRole() == 'delivery' &&
          resource.data.branchId == userBranch() &&
          (resource.data.status in ['ready', 'picked_up'] ||
           resource.data.assignedDriverId == request.auth.uid)) ||
        (userRole() == 'customer' &&
          resource.data.customerId == request.auth.uid)
      );
      allow create: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        request.resource.data.customerId == request.auth.uid &&
        request.resource.data.totalCents >= 0 &&
        request.resource.data.status in ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled'];
      allow update: if isAppVerified() && isAuthenticated() && !isAnonymous() && (
        userRole() == 'owner' ||
        (userRole() == 'manager' &&
          resource.data.branchId == userBranch() &&
          request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['status', 'assignedDriverId'])) ||
        (userRole() == 'kitchen' &&
          resource.data.branchId == userBranch() &&
          resource.data.status in ['confirmed', 'preparing'] &&
          request.resource.data.status in ['preparing', 'ready']) ||
        (userRole() == 'delivery' &&
          resource.data.assignedDriverId == request.auth.uid &&
          resource.data.status in ['ready', 'picked_up'] &&
          request.resource.data.status in ['picked_up', 'delivered'])
      );
    }

    // ── presence ─────────────────────────────────────────────────────
    match /presence/{userId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() == 'owner' ||
         (userRole() in ['manager', 'kitchen', 'delivery'] &&
          resource.data.branchId == userBranch()));
      allow write: if isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
      allow delete: if false;
    }

    // ── reservation_locks ─────────────────────────────────────────────
    match /reservation_locks/{lockId} {
      allow read: if isAuthenticated() && !isAnonymous();
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid;
      allow delete: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid;
    }

    // ── reservations ──────────────────────────────────────────────────
    match /reservations/{resId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.customerId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.customerId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.customerId == request.auth.uid);
      allow delete: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
    }

    // ── carts ─────────────────────────────────────────────────────────
    match /carts/{userId} {
      allow read, write: if isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
    }

    // ── promoCodes ───────────────────────────────────────────────────
    match /promoCodes/{code} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
    }

    // ── driverLocations ──────────────────────────────────────────────
    match /driverLocations/{driverId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager', 'kitchen'] ||
         request.auth.uid == driverId);
      allow write: if isAuthenticated() && !isAnonymous() && request.auth.uid == driverId;
    }

    // ── analyticsEvents ──────────────────────────────────────────────
    match /analyticsEvents/{eventId} {
      allow read: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
      allow create: if isAuthenticated();
    }

    // ── proof_of_delivery ─────────────────────────────────────────────
    match /proof_of_delivery/{poid} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.orderId != null &&
         get(/databases/$(database)/documents/orders/$(resource.data.orderId)).data.assignedDriverId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.driverId == request.auth.uid &&
        request.resource.data.orderId != null &&
        get(/databases/$(database)/documents/orders/$(request.resource.data.orderId)).data.assignedDriverId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.driverId == request.auth.uid &&
        resource.data.orderId != null &&
        get(/databases/$(database)/documents/orders/$(resource.data.orderId)).data.assignedDriverId == request.auth.uid;
      allow delete: if false;
    }

    // ── promo_usage ───────────────────────────────────────────────────
    match /promo_usage/{usageId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (resource.data.userId == request.auth.uid || userRole() in ['owner', 'manager']);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['userId', 'code']);
      allow delete: if false;
    }

    // ── waitlist ──────────────────────────────────────────────────────
    match /waitlist/{entryId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.userId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['userId', 'branchId']);
      allow delete: if isAuthenticated() && !isAnonymous() &&
        (resource.data.userId == request.auth.uid || userRole() in ['owner', 'manager']);
    }

    // ── audit_log ─────────────────────────────────────────────────────
    match /audit_log/{logId} {
      allow read: if isOwner();
      allow write: if false; // Written only by Cloud Functions Admin SDK
    }
  }
}
```

---

## STEP 2 — CONSTITUTION CROSS-REFERENCE

| Law | Applied Finding |
|-----|-----------------|
| **Law 12 — Security by Least Privilege** | Rules are the enforcement layer ✓. **BUT:** the `e2e_` email backdoor in `users` write is a rules-level privilege-escalation hole (see 🔴C-1). Several write paths rely on role checks that are self-assignable at account creation. |
| **Law 8 — Defensive Execution (fail-closed)** | Unmatched paths are denied by default ✓. `audit_log` write: `if false` ✓. `presence` delete: `if false` ✓. `proof_of_delivery` delete: `if false` ✓. `promo_usage` delete: `if false` ✓. **But** kitchen/delivery order updates are fail-OPEN on field scope (see 🔴C-2). |
| **Law 4 — Zero Stub Tolerance** | No `allow read, write: if true;` combined stub exists in production-write paths. Public `allow read: if true` on `menus`, `branches`, `promotions` is **intentional guest mode** (Constitution Part 6 explicitly documents it) — not a stub. |

---

## STEP 3 & 4 — PER-COLLECTION AUDIT (Actual Data Model)

### ✅ `users/{userId}` — Partially secure

**A. Auth:** ✓ All reads/writes require `isAppVerified() && isAuthenticated() && !isAnonymous()`.

**B. Ownership:** ✓ Self-read/write via `request.auth.uid == userId`.

**C. RBAC:** ✓ Owner/manager read any user. Manager writes limited to own-branch staff, cannot set role ≠ kitchen/delivery/customer. Self-role-change forbidden on update.

**D. Validation:** 🔴 **Creation-time role validation has a backdoor** — `request.resource.data.email.matches('.*e2e_.*@example\\.com')` (and `@carnama.com`) bypasses the "role must be customer" restriction **and** the "branchId must be empty" restriction on document creation. **Any anonymous signup can create their own `users/{uid}` doc with `role: 'owner'` and an e2e-formatted email → permanent full-owner takeover.**

**E. Field protection:** ✓ `branchId` self-write blocked (owner-only). ⚠️ But `email` field is self-writable to arbitrary values (data integrity only — auth is via token email, not the doc).

---

### 🔴 `orders/{orderId}` — CRITICAL update-scope gap

**A. Auth:** ✓ All ops require app-verified, non-anonymous auth.

**B. Ownership:** ✓ Read: customer can only read `customerId == auth.uid`. Create: `customerId == auth.uid`. Customer cannot update/delete.

**C. RBAC:**
- Owner: unrestricted ✓
- Manager: `hasOnly(['status', 'assignedDriverId'])` ✓
- Kitchen: 🔴 **No `hasOnly`** — a kitchen user can rewrite ANY field (customerId, totalCents, items, assignedDriverId) as long as current status ∈ {confirmed, preparing} and new status ∈ {preparing, ready}. **Financial data tampering.**
- Delivery: 🔴 **No `hasOnly`** — an assigned driver can rewrite ANY field as long as status transitions ready/picked_up → picked_up/delivered. **A driver can zero out `totalCents` or reassign `customerId`.**

**D. Validation (create):** 🔴 Missing — `branchId` not required/validated; `createdAt` client-set; `items` not validated; status may be any of 7 enum values (customer can create an order already marked `delivered`); `assignedDriverId` settable by customer on create.

**E. Collection group:** No collection-group queries on orders — N/A.

**F. Fail-closed:** Deny-by-default on update for customers ✓, but the kitchen/delivery paths are effectively fail-open on field scope.

---

### ⚠️ `menus/{itemId}` — cross-branch tampering by manager

**A. Auth:** ✓ Writes require app-verified non-anonymous auth. `allow read: if true` intentional guest mode.

**C. RBAC:** 🔴 Manager create/update rule:
```
(request.resource.data.branchId == userBranch() || resource.data.branchId == userBranch())
```
On **update**, the OR passes if the *existing* item belongs to the manager's branch — even if the new `branchId` points to a **different** branch. A manager can silently **steal/reassign menu items out of their branch**. `branchId` must be immutable on update.

**D. Validation:** ⚠️ No field validation — `priceCents` can be negative, `isAvailable` can be a string, `name` can be empty.

---

### ⚠️ `settings/{doc}` — over-broad read + mutable ownerInfo

**A. Auth:** ⚠️ `allow read: if doc == 'featureFlags' || isAuthenticated()` — ANY authenticated user (incl. anonymous-auth users) can read **every** settings doc, including `settings/ownerInfo` (owner email disclosure). Anonymous users are authenticated in Firebase, so guest can read all settings too.

**D. Governance:** ⚠️ `allow write: if isOwner()` allows the owner to rewrite `settings/ownerInfo.ownerEmail` (ownership transfer with **no audit trail** and no dual-authorization). Anti-demotion protection exists for `users.role` but NOT for `ownerInfo`.

---

### ⚠️ `promoCodes/{code}` — manager can forge/alter global promos

**C. RBAC:** 🔴 `allow write: if ... userRole() in ['owner', 'manager']` — a branch-scoped manager can create/update/delete **any** promo code, not just their branch's. Per Constitution, managers are branch-scoped only.

**A. Auth:** ⚠️ `allow read: if isAuthenticated()` — anonymous users can read promo codes (missing `!isAnonymous()`).

---

### ⚠️ `driverLocations/{driverId}` — GPS spoofing by any user

**C. RBAC:** 🔴 `allow write: if ... request.auth.uid == driverId` — **no role check**. A logged-in customer (or kitchen employee) can write `driverLocations/{self}` with fake lat/lng, which the staff tracking dashboard will display as a live driver. Must require `userRole() == 'delivery'`.

---

### ⚠️ `reservations/{resId}` — self-confirmation + unvalidated fields

**D. Validation:** 🔴 Create requires only `customerId == auth.uid`. Customer can create a reservation with `status: 'confirmed'`, arbitrary `branchId`, `date`, `slot` — bypassing any approval flow. No `hasOnly` on update either (a customer can update any field of their own reservation, e.g. change branchId).

---

### ⚠️ `reservation_locks/{lockId}` — cross-user read leak

**A. Auth:** ⚠️ `allow read: if isAuthenticated() && !isAnonymous()` — every authenticated user can read **all other users' locks** (userId, slot, expiresAt). Should be restricted to own locks / owner / branch managers.

---

### ⚠️ `analyticsEvents/{eventId}` — anonymous write flood

**A. Auth:** ⚠️ `allow create: if isAuthenticated()` — anonymous users can write events (missing `!isAnonymous()`). Write-flood abuse vector. Also no size/field validation.

---

### ⚠️ `carts/{userId}` — PASS (with note)

**A/B/C:** ✓ `request.auth.uid == userId` on read+write. **D:** ⚠️ No item validation but cart content is non-normative; acceptable.

---

### ✅ PASSED COLLECTIONS

| Path | Verdict |
|---|---|
| `branches` + `branches/config` | ✓ Owner-only writes, public reads (intentional), fail-closed subpaths |
| `promotions` | ✓ Owner-only writes, public reads (intentional) |
| `admins` | ✓ Owner-only read/write |
| `loyalty` | ✓ Self-only with `isAppVerified()` (DEFERRED backend anyway) |
| `presence` | ✓ Self-write, staff reads, delete denied |
| `proof_of_delivery` | ✓ Assigned-driver-only via cross-doc `get()`; delete denied |
| `promo_usage` | ✓ Self-only, immutable keys, delete denied |
| `waitlist` | ✓ Self-create/update, owner/manager delete; immutable userId/branchId |
| `audit_log` | ✓ Owner-read, function-write-only (deny clients) |

---

## STEP 5 — VULNERABILITY REPORT

## 🔴 CRITICAL VULNERABILITIES

### 🔴 C-1: E2E email backdoor → full owner privilege escalation (`users` create)
**Location:** `core_app/firestore.rules` lines 104–106 + 122–123
**Risk:** On document creation, a self-registering user whose `email` matches `.*e2e_.*@example\.com` or `.*e2e_.*@carnama\.com` may set **any** `role` — including `owner` — and **any** `branchId`. Firestore create is performed by the app on first login; nothing stops a hostile user from crafting this write with a forged payload. Once created as `owner`, `userRole()` returns `'owner'` and the account has **unrestricted read/write to all collections** (orders, users, settings, branches). **This is a total platform takeover.**
**Why it exists:** A workaround to seed roles in an empty emulator, incorrectly shipped to production rules (Law 4 — stub/backdoor in production).
**Fix:** Remove the e2e bypass entirely from production rules. Seed roles via admin SDK / Cloud Function only.

### 🔴 C-2: Kitchen & Delivery order updates have no field-scope restriction (`orders` update)
**Location:** lines 154–162
**Risk:** A kitchen user or assigned delivery driver may modify **any** field of an order (`totalCents`, `customerId`, `items`, `assignedDriverId`, `branchId`) as long as the status transition is plausible. A delivery driver could zero a customer's `totalCents` or reassign orders; a kitchen user could rewrite an order's contents before marking ready. **Financial data integrity violation** (violates Law 8 fail-closed).
**Fix:** Add `.affectedKeys().hasOnly([...])` to both branches.

### 🔴 C-3: Menu items can be reassigned across branches by a manager (`menus` update)
**Location:** lines 48–52
**Risk:** `request.resource.data.branchId == userBranch() || resource.data.branchId == userBranch()` — on update the OR passes whenever the *current* branch matches, so a manager can move their branch's menu items into another branch's catalog (data corruption + cross-branch menu poisoning).
**Fix:** Add `request.resource.data.branchId == resource.data.branchId` (branchId immutable on update) or `hasOnly` on allowed fields.

---

## 🟡 WARNINGS

### 🟡 W-1: Any user can forge driver GPS (`driverLocations` write)
**Risk:** A customer/kitchen user can write fake `driverLocations/{uid}` docs shown on the staff tracking map. **Fix:** require `userRole() == 'delivery'` on write.

### 🟡 W-2: Customers can self-confirm reservations (`reservations` create/update)
**Risk:** No status/branch/slot validation — user can create `status: 'confirmed'` reservations or edit their own reservation's branch/date arbitrarily. **Fix:** default status `'pending'`, `hasOnly` on updates, validate branchId exists.

### 🟡 W-3: Manager can forge/modify global promo codes (`promoCodes` write)
**Risk:** Branch managers not branch-scoped for promos. **Fix:** owners only for promote codes, or require branch-scoped rule with validation.

### 🟡 W-4: Cross-user reservation-lock read leak (`reservation_locks` read)
**Risk:** Any authenticated user reads all locks. **Fix:** restrict to own locks + owner/manager.

### 🟡 W-5: Anonymous users can read/write telemetry + all settings (`analyticsEvents`, `settings`)
**Risk:** Anonymous write-flood on `analyticsEvents`; anonymous read of all settings docs incl. `ownerInfo` email. **Fix:** `!isAnonymous()` on create; settings read restricted to `featureFlags` only.

### 🟡 W-6: `isAppVerified()` may brick legitimate platforms
**Risk:** `request.auth.token.app_id` is only present for App-Check-verified Android/iOS. The Windows desktop demo build and web builds without App Check configured will return `isAppVerified() == false` → **all non-public writes fail**. The `e2e_` bypass (C-1) may have masked this in tests. **Fix:** Verify App Check coverage on every shipped platform; keep App Check enforced where configured, but ensure emulator/demo builds route through a separate staging rules file (`staging.firestore.rules` already exists).

### 🟡 W-7: No `notifications` subcollection rule → fully denied
**Risk:** If any client reads `notifications/{uid}/items` from Firestore it will fail. FCM push likely covers this — **verify before deploy** (Law 1 — no assumptions).

### 🟡 W-8: Order `create` lacks data validation
**Risk:** client-set `createdAt`, arbitrary `status` (incl. `delivered`), missing `branchId` requirement, `assignedDriverId` settable. **Fix:** `hasOnly` on create; status must be `'pending'`; branchId required.

### 🟡 W-9: Owner can rewrite `settings/ownerInfo` with no audit
**Risk:** ownership transfer with no Law 36 audit trail. **Fix:** write via Cloud Function that appends to `audit_log`.

### 🟡 W-10: No field validation on `menus` writes
**Risk:** negative prices, wrong types. **Fix:** require `priceCents is int && priceCents >= 0 && name is string`.

---

## 🟢 PASSED CHECKS

- ✅ No `allow read, write: if true;` combined stub anywhere (Law 4).
- ✅ Unmatched paths deny by default — `taxRates`, `clientId`, and unknown collections are **not** exposed (fail-closed, Law 8).
- ✅ Delete denied on `presence`, `proof_of_delivery`, `promo_usage`, `audit_log`.
- ✅ Owner identity via `settings/ownerInfo` (single source of truth), not client-supplied fields.
- ✅ Self-role-change blocked on update (anti-self-demotion + owner anti-demotion logic).
- ✅ Manager write to user docs restricted to own-branch staff and non-elevated roles.
- ✅ `proof_of_delivery` cross-document verification with the source order.
- ✅ `promo_usage` immutable keys; `waitlist` immutable userId/branchId.
- ✅ Carts, loyalty: strict per-user scoping.
- ✅ `audit_log` client-write denied — server-only (Law 36 aligned).
- ✅ Branch write & branch config write: owner-only (Constitution Part 6).

---

## STEP 6 — DEPLOYMENT READINESS

### 1. Are the rules safe to deploy to production as-is? **NO.**

Three critical vulnerabilities must be fixed first: the e2e **owner-escalation backdoor** (C-1), the **unbounded kitchen/delivery order updates** (C-2), and the **cross-branch menu reassignment** (C-3). C-1 alone is a full data-exfiltration/tampering path from a single self-signup.

### 2. Single most critical issue before deployment

**The `e2e_*` email backdoor in `users` create** — it turns a brand-new anonymous signup into a permanent `owner` with unrestricted read/write over the entire database. Remove it now.

### 3. Corrected `firestore.rules` (all fixes applied)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── App Check enforcement (Law 12 — Security by Least Privilege) ─
    function isAppVerified() {
      return request.auth != null &&
        (request.auth.token.app_id != null ||
         request.auth.token.firebase.app_check_token != null);
    }

    // ── Auth helpers ─────────────────────────────────────────────────
    function isAuthenticated() {
      return request.auth != null;
    }

    function isAnonymous() {
      return isAuthenticated() &&
        request.auth.token.firebase.sign_in_provider == 'anonymous';
    }

    function isOwner() {
      return isAuthenticated() &&
        !isAnonymous() &&
        exists(/databases/$(database)/documents/settings/ownerInfo) &&
        get(/databases/$(database)/documents/settings/ownerInfo).data.ownerEmail == request.auth.token.email;
    }

    function userRole() {
      return (isAuthenticated() && !isAnonymous() &&
              exists(/databases/$(database)/documents/users/$(request.auth.uid)))
             ? get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role
             : 'none';
    }

    function userBranch() {
      return (isAuthenticated() && !isAnonymous() &&
              exists(/databases/$(database)/documents/users/$(request.auth.uid)))
             ? get(/databases/$(database)/documents/users/$(request.auth.uid)).data.branchId
             : 'none';
    }

    function isDeliveryDriver() {
      return userRole() == 'delivery';
    }

    // ── PUBLIC READS (intentional guest mode — Constitution Part 6) ──
    match /menus/{itemId} {
      allow read: if true; // Public: menu browsing is unauthenticated

      allow create: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (isOwner() ||
         (userRole() == 'manager' &&
          request.resource.data.branchId == userBranch())) &&
        // C-3 FIX: new items must be priced and typed correctly
        request.resource.data.keys().hasAll(['name', 'priceCents']) &&
        request.resource.data.name is string &&
        request.resource.data.name.size() > 0 &&
        request.resource.data.priceCents is int &&
        request.resource.data.priceCents >= 0;

      allow update: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (isOwner() ||
         (userRole() == 'manager' &&
          resource.data.branchId == userBranch())) &&
        // C-3 FIX: branchId immutable on update — cannot steal/move items
        (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId'])) &&
        request.resource.data.name is string &&
        request.resource.data.name.size() > 0 &&
        request.resource.data.priceCents is int &&
        request.resource.data.priceCents >= 0;

      allow delete: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (isOwner() ||
         (userRole() == 'manager' && resource.data.branchId == userBranch()));
    }

    match /branches/{branchId} {
      allow read: if true; // Public: branch info is unauthenticated
      allow write: if isOwner();

      match /config/{configDoc} {
        allow read: if true; // Public: operating hours needed on checkout
        allow write: if isOwner();
      }
    }

    match /promotions/{promoId} {
      allow read: if true; // Public: promo banners visible to guests
      allow write: if isOwner();
    }

    match /settings/{doc} {
      // W-5 FIX: owners read non-public settings; guests see featureFlags only
      allow read: if doc == 'featureFlags' || isOwner();
      allow write: if isOwner() && doc == 'featureFlags';
      // W-9 NOTE: settings/ownerInfo is intentionally NOT writable here.
      // Ownership changes must run through a Cloud Function that audits.
    }

    // ── AUTHENTICATED-ONLY ────────────────────────────────────────────

    match /admins/{doc} {
      allow read, write: if isOwner();
    }

    match /loyalty/{userId} {
      allow read, write: if isAppVerified() && isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
    }

    // ── users ─────────────────────────────────────────────────────────
    match /users/{userId} {
      allow read: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (request.auth.uid == userId || userRole() in ['owner', 'manager']);

      allow write: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        (request.auth.uid == userId ||
         userRole() == 'owner' ||
         (userRole() == 'manager' &&
          resource.data.branchId == userBranch() &&
          (!request.resource.data.keys().hasAny(['role']) ||
           request.resource.data.role in ['kitchen', 'delivery', 'customer']))) &&

        // C-1 FIX: NO e2e backdoor. Creation is customer-role-only.
        (resource == null ?
           (!request.resource.data.keys().hasAny(['role']) ||
            request.resource.data.role == 'customer')
           :
           (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
            request.auth.uid != userId)
        ) &&

        // Owner cannot be demoted except by a full owner replacement
        (resource == null || !('email' in resource.data) ||
         !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
         request.resource.data.role == resource.data.role ||
         !(exists(/databases/$(database)/documents/settings/ownerInfo) &&
           get(/databases/$(database)/documents/settings/ownerInfo).data.ownerEmail == resource.data.email) ||
         isOwner()) &&

        // Only owners write branchId
        (resource == null ?
           (!request.resource.data.keys().hasAny(['branchId']) ||
            request.resource.data.branchId == '')
           :
           (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) ||
            isOwner())
        );
    }

    // ── orders ────────────────────────────────────────────────────────
    match /orders/{orderId} {
      allow read: if isAppVerified() && isAuthenticated() && !isAnonymous() && (
        userRole() == 'owner' ||
        (userRole() == 'manager' && resource.data.branchId == userBranch()) ||
        (userRole() == 'kitchen' &&
          resource.data.branchId == userBranch() &&
          resource.data.status in ['confirmed', 'preparing']) ||
        (userRole() == 'delivery' &&
          resource.data.branchId == userBranch() &&
          (resource.data.status in ['ready', 'picked_up'] ||
           resource.data.assignedDriverId == request.auth.uid)) ||
        (userRole() == 'customer' &&
          resource.data.customerId == request.auth.uid)
      );

      // W-8 FIX: customers create pending orders only, with validated shape
      allow create: if isAppVerified() && isAuthenticated() && !isAnonymous() &&
        request.resource.data.customerId == request.auth.uid &&
        request.resource.data.branchId is string &&
        request.resource.data.branchId.size() > 0 &&
        request.resource.data.totalCents is int &&
        request.resource.data.totalCents >= 0 &&
        request.resource.data.status == 'pending' &&
        request.resource.data.keys().hasOnly(
          ['customerId', 'branchId', 'items', 'totalCents', 'status', 'createdAt']
        );

      allow update: if isAppVerified() && isAuthenticated() && !isAnonymous() && (
        userRole() == 'owner' ||
        (userRole() == 'manager' &&
          resource.data.branchId == userBranch() &&
          request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['status', 'assignedDriverId'])) ||
        // C-2 FIX: kitchen may ONLY transition status
        (userRole() == 'kitchen' &&
          resource.data.branchId == userBranch() &&
          resource.data.status in ['confirmed', 'preparing'] &&
          request.resource.data.status in ['preparing', 'ready'] &&
          request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['status'])) ||
        // C-2 FIX: driver may ONLY transition status
        (userRole() == 'delivery' &&
          resource.data.assignedDriverId == request.auth.uid &&
          resource.data.status in ['ready', 'picked_up'] &&
          request.resource.data.status in ['picked_up', 'delivered'] &&
          request.resource.data.diff(resource.data)
            .affectedKeys().hasOnly(['status']))
      );
    }

    // ── presence ─────────────────────────────────────────────────────
    match /presence/{userId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() == 'owner' ||
         (userRole() in ['manager', 'kitchen', 'delivery'] &&
          resource.data.branchId == userBranch()));
      allow write: if isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
      allow delete: if false;
    }

    // ── reservation_locks ─────────────────────────────────────────────
    match /reservation_locks/{lockId} {
      // W-4 FIX: users see only their own locks; staff see branch-scoped
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.userId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid &&
        request.resource.data.keys().hasOnly(['userId', 'slot', 'expiresAt']);
      allow delete: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid;
    }

    // ── reservations ──────────────────────────────────────────────────
    match /reservations/{resId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.customerId == request.auth.uid);

      // W-2 FIX: customers create pending reservations with locked shape
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.customerId == request.auth.uid &&
        request.resource.data.status == 'pending' &&
        request.resource.data.branchId is string &&
        request.resource.data.objects.keys().hasAll(['branchId', 'date', 'slot']) &&
        request.resource.data.keys().hasOnly(
          ['customerId', 'branchId', 'date', 'slot', 'status', 'partySize', 'createdAt']);

      // W-2 FIX: customer updates limited to non-normative fields
      allow update: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         (resource.data.customerId == request.auth.uid &&
          !request.resource.data.diff(resource.data)
             .affectedKeys().hasAny(['customerId', 'branchId', 'status', 'slot'])));
      allow delete: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
    }

    // ── carts ─────────────────────────────────────────────────────────
    match /carts/{userId} {
      allow read, write: if isAuthenticated() && !isAnonymous() && request.auth.uid == userId;
    }

    // ── promoCodes ───────────────────────────────────────────────────
    match /promoCodes/{code} {
      // W-5 FIX: no anonymous reads
      allow read: if isAuthenticated() && !isAnonymous();
      // W-3 FIX: promo codes are global-value — owner only
      allow write: if isAuthenticated() && !isAnonymous() && isOwner();
    }

    // ── driverLocations ──────────────────────────────────────────────
    match /driverLocations/{driverId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager', 'kitchen'] ||
         request.auth.uid == driverId);
      // W-1 FIX: only delivery-role users can post their live GPS
      allow write: if isAuthenticated() && !isAnonymous() &&
        request.auth.uid == driverId &&
        isDeliveryDriver() &&
        request.resource.data.keys().hasAll(['lat', 'lng', 'updatedAt']);
    }

    // ── analyticsEvents ──────────────────────────────────────────────
    match /analyticsEvents/{eventId} {
      allow read: if isAuthenticated() && !isAnonymous() && userRole() in ['owner', 'manager'];
      // W-5 FIX: no anonymous writes
      allow create: if isAuthenticated() && !isAnonymous();
    }

    // ── proof_of_delivery ─────────────────────────────────────────────
    match /proof_of_delivery/{poid} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.orderId != null &&
         get(/databases/$(database)/documents/orders/$(resource.data.orderId)).data.assignedDriverId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.driverId == request.auth.uid &&
        request.resource.data.orderId != null &&
        get(/databases/$(database)/documents/orders/$(request.resource.data.orderId)).data.assignedDriverId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.driverId == request.auth.uid &&
        resource.data.orderId != null &&
        get(/databases/$(database)/documents/orders/$(resource.data.orderId)).data.assignedDriverId == request.auth.uid;
      allow delete: if false;
    }

    // ── promo_usage ───────────────────────────────────────────────────
    match /promo_usage/{usageId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (resource.data.userId == request.auth.uid || userRole() in ['owner', 'manager']);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['userId', 'code']);
      allow delete: if false;
    }

    // ── waitlist ──────────────────────────────────────────────────────
    match /waitlist/{entryId} {
      allow read: if isAuthenticated() && !isAnonymous() &&
        (userRole() in ['owner', 'manager'] ||
         resource.data.userId == request.auth.uid);
      allow create: if isAuthenticated() && !isAnonymous() &&
        request.resource.data.userId == request.auth.uid;
      allow update: if isAuthenticated() && !isAnonymous() &&
        resource.data.userId == request.auth.uid &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['userId', 'branchId']);
      allow delete: if isAuthenticated() && !isAnonymous() &&
        (resource.data.userId == request.auth.uid || userRole() in ['owner', 'manager']);
    }

    // ── audit_log ─────────────────────────────────────────────────────
    match /audit_log/{logId} {
      allow read: if isOwner();
      allow write: if false; // Written only by Cloud Functions Admin SDK
    }
  }
}
```

> ⚠️ **Law 51 (Human-Only):** Security rule mutation is Human-Only tier. The corrected rules above are a **recommendation** — applying them to `core_app/firestore.rules` and deploying requires explicit human approval. They are not written to disk by this audit.

---

## APPLICABLE LAW SUMMARY

- **Law 4 (Zero Stubs):** PASSED in production write paths; the `e2e_` backdoor is a stub-logic violation in disguise.
- **Law 8 (Defensive / Fail-Closed):** VIOLATED by C-2 (unbounded kitchen/delivery updates) — fixed with `hasOnly`.
- **Law 12 (RBAC in Rules, not Dart):** PARTIAL — rules are the enforcement layer, but C-1 (self-role-escalation) and W-1 (GPS spoofing) allow role/site forgery at the rules layer itself.
- **Law 36 (Audit Logging):** `audit_log` exists and is write-denied to clients ✓; W-9 flags ownerInfo changes are unaudited.