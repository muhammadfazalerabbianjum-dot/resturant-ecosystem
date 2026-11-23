# 🤖 Perfect Cline Prompt — Implement the Verified Firestore Rules Fixes

> **How to use:** Copy EVERYTHING between the `--- COPY BELOW ---` markers into a fresh Cline (or any coding-agent) chat in **ACT MODE**, then approve.
> **Reference docs:** `core_app/docs/firestore_rules_audit_20260820.md` (findings) and `core_app/docs/firestore_rules_fix_plan_20260820.md` (verified fixes). Both exist in the repo.

---

--- COPY BELOW ---

## ROLE: Firestore Security Rules Implementer (Carnama Constitution)

You are implementing the **verified** fixes from `core_app/docs/firestore_rules_fix_plan_20260820.md` (companion audit: `core_app/docs/firestore_rules_audit_20260820.md`). Every fix there is cross-referenced to actual app code. The mobile client is hostile (Law 12). Fail closed (Law 8). No stubs (Law 4). **TDD-first (Law 2): write the emulator rules tests BEFORE changing `firestore.rules`.**

**⚠️ Law 51 (Human-Only tier):** Security rule mutation requires human approval. You are authorised ONLY to implement the changes specified below. Do NOT invent additional rule changes. Report anything unexpected instead of fixing it silently.

---

### STEP 1 — Begin with Obedience + Verification

1. Read `CARNAMA_CONSTITUTION.md`, `core_app/docs/firestore_rules_audit_20260820.md`, and `core_app/docs/firestore_rules_fix_plan_20260820.md` end-to-end.
2. Read the CURRENT `core_app/firestore.rules` in full. If it differs from the version described in the audit (274 lines, rules_version 2), STOP and report the diff.
3. Confirm the following code facts are still true (these drive the fixes):
   - `order_model.dart` writes status **`pickedUp`** (camelCase) — NOT `picked_up`.
   - `driver_location_service.dart` writes GPS to **`deliveries/{orderId}`** with keys `lat, lng, heading, speed, timestamp` — NOT `driverLocations`.
   - `auth_repository.dart` `_syncUserProfile` writes role **`customer`** on user doc creation.
   - `settings/featureFlags` is the only public settings doc (Constitution Part 5).

---

### STEP 2 — TDD: Write the Emulator Rules Test Harness FIRST

Create `core_app/test/rules/firestore_rules_test.js` (Node + `@firebase/rules-unit-testing`). It must:

1. **Load** `core_app/firestore.rules` via `loadFirestoreRules`.
2. **Use the emulator** — never production (Law 30).
3. Assert the following matrix (each assertion must FAIL before your fix and PASS after):

| # | Test | Expect |
|---|------|--------|
| T1 | Unauthenticated read of `users/abc` | DENY |
| T2 | Unauthenticated read of `menus/x` | ALLOW (public guest mode) |
| T3 | Unauthenticated write of `menus/x` | DENY |
| T4 | Self-register (create `users/{uid}`) with `role:'owner'`, email `e2e_foo@example.com` | DENY (C-1) |
| T5 | Self-register with `role:'customer'` | ALLOW (C-1) |
| T6 | User updates own `role` | DENY (anti-self-demotion preserved) |
| T7 | Owner updates another user's role to `manager` | ALLOW |
| T8 | Kitchen writes order `{status:'ready'}` on own-branch `confirmed` order | ALLOW (C-2) |
| T9 | Kitchen writes order `{status:'ready', totalCents: 0}` | DENY (C-2 field lock) |
| T10 | Assigned driver writes order `{status:'pickedUp'}` | ALLOW (C-2 + camelCase fix) |
| T11 | Assigned driver writes order `{status:'pickedUp', items: []}` | DENY (C-2 field lock) |
| T12 | Unassigned driver writes `deliveries/{orderId}` | DENY (W-1) |
| T13 | Assigned driver writes `deliveries/{orderId}` with `{lat, lng, heading, speed, timestamp}` | ALLOW (W-1) |
| T14 | Assigned driver writes `deliveries/{orderId}` with an extra field | DENY (W-1 shape lock) |
| T15 | Manager updates `menus/x.branchId` on own-branch item | DENY (C-3 immutability) |
| T16 | Manager updates `menus/x.priceCents` on own-branch item | ALLOW (C-3) |
| T17 | Manager writes `menus/x` with `priceCents: -5` | DENY (C-3 validation) |
| T18 | Anonymous user writes `analyticsEvents/x` | DENY (W-5) |
| T19 | Anonymous user reads `settings/ownerInfo` | DENY (W-5) |
| T20 | Authenticated non-owner reads `settings/featureFlags` | ALLOW (W-5 public flag) |
| T21 | Customer reads another user's `reservation_locks/x` | DENY (W-4) |
| T22 | Customer creates reservation with `status:'confirmed'` | DENY (W-2) |
| T23 | Customer creates reservation with `status:'pending'` + required fields | ALLOW (W-2) |
| T24 | Manager writes `promoCodes/x` | DENY (W-3 owner-only) |
| T25 | Owner writes `promoCodes/x` | ALLOW (W-3) |

4. Run it: `firebase emulators:exec "node core_app/test/rules/firestore_rules_test.js"`. **It must be RED before the fix.**

---

### STEP 3 — Implement the Fixes (EXACTLY these, in this order)

#### Fix 1 (C-1): Remove the e2e role-escalation backdoor in `users` write

In `users/{userId}` → `allow write`:
- Replace the creation ternary:
  ```javascript
  (resource == null ? 
     (!request.resource.data.keys().hasAny(['role']) || request.resource.data.role == 'customer' || request.resource.data.email.matches('.*e2e_.*@example\\.com') || request.resource.data.email.matches('.*e2e_.*@carnama\\.com')) 
     : 
     (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) || request.auth.uid != userId)
  )
  ```
  with:
  ```javascript
  (resource == null ?
     (!request.resource.data.keys().hasAny(['role']) ||
      request.resource.data.role == 'customer')
     :
     (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']) ||
      request.auth.uid != userId)
  )
  ```
- Replace the branchId creation ternary:
  ```javascript
  (resource == null ? 
     (request.resource.data.email.matches('.*e2e_.*@carnama\\.com') || !request.resource.data.keys().hasAny(['branchId']) || request.resource.data.branchId == '')
     :
     (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) || isOwner())
  )
  ```
  with:
  ```javascript
  (resource == null ?
     (!request.resource.data.keys().hasAny(['branchId']) ||
      request.resource.data.branchId == '')
     :
     (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['branchId']) ||
      isOwner())
  )
  ```

#### Fix 2 (C-2): Lock kitchen/delivery order updates AND use `pickedUp`

In `orders/{orderId}`:
- `allow create`: require `branchId is string && branchId.size() > 0`, `totalCents is int && totalCents >= 0`, and `status == 'pending'` (replace the 7-value whitelist).
- `allow update` kitchen branch — add `.hasOnly(['status'])`:
  ```javascript
  (userRole() == 'kitchen' &&
    resource.data.branchId == userBranch() &&
    resource.data.status in ['confirmed', 'preparing'] &&
    request.resource.data.status in ['preparing', 'ready'] &&
    request.resource.data.diff(resource.data)
      .affectedKeys().hasOnly(['status']))
  ```
- `allow update` delivery branch — **change `picked_up` → `pickedUp`** and add `.hasOnly(['status'])`:
  ```javascript
  (userRole() == 'delivery' &&
    resource.data.assignedDriverId == request.auth.uid &&
    resource.data.status in ['ready', 'pickedUp'] &&
    request.resource.data.status in ['pickedUp', 'delivered'] &&
    request.resource.data.diff(resource.data)
      .affectedKeys().hasOnly(['status']))
  ```
- `allow read` — change the delivery status list `['ready', 'picked_up']` → `['ready', 'pickedUp']`.

#### Fix 3 (W-1): Add the MISSING `deliveries` collection rules

The app writes to `deliveries/{orderId}` (`driver_location_service.dart`) but there is NO match block — every GPS write is DENIED today. Add (do NOT remove `driverLocations`):
```javascript
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
    get(/databases/$(database)/documents/orders/$(orderId)).data.status in ['confirmed', 'preparing', 'ready', 'pickedUp'] &&
    request.resource.data.keys().hasOnly(['lat', 'lng', 'heading', 'speed', 'timestamp']) &&
    request.resource.data.lat is number &&
    request.resource.data.lng is number;

  allow delete: if false;
}
```

#### Fix 4 (C-3): Menu `branchId` immutability + field validation

Replace the `menus/{itemId}` block with:
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

#### Fix 5 (W-2..W-5): Collection hardening

- `reservations/{resId}` create → require `status == 'pending'`, `branchId is string && branchId.size() > 0`, and `keys().hasOnly(['customerId','branchId','date','slot','status','partySize','createdAt'])`. `update` → customers may not change `customerId, branchId, status, slot`.
- `reservation_locks/{lockId}` read → add `(userRole() in ['owner','manager'] || resource.data.userId == request.auth.uid)`.
- `promoCodes/{code}` → read: add `!isAnonymous()`; write: `isOwner()` ONLY (managers lose global promo write).
- `settings/{doc}` read → `doc == 'featureFlags' || isOwner()`; write → `isOwner() && doc == 'featureFlags'` (removes direct `ownerInfo` client write — W-9).
- `analyticsEvents/{eventId}` create → `isAuthenticated() && !isAnonymous()`.

> ⚠️ Before finalising the `reservations` `hasOnly` list, read `core_app/lib/features/reservations/data/reservations_repository.dart` and adjust the key list to the app's REAL write payload. If fields differ, report the exact list and use it.

---

### STEP 4 — Verify (Law 30, Law 10)

1. `firebase emulators:exec "node core_app/test/rules/firestore_rules_test.js"` → **ALL 25 tests GREEN**.
2. `cd core_app && flutter analyze` → **0 warnings**.
3. `cd core_app && flutter test` → **100% green**.
4. Regression grep:
   - `grep -rn "picked_up" core_app/firestore.rules` → **0 matches**.
   - `grep -rn "e2e_.*@example" core_app/firestore.rules` → **0 matches**.
5. Confirm `match /deliveries/` exists in `firestore.rules`.

### STEP 5 — Data-Drifts REGRESSION (do NOT fix silently — report + ask)

While verifying, check and REPORT these (do not modify app code without explicit approval):
- `MenuRepository._syncFromFirestore` reads `data['price']` but the rules/model validate `priceCents` (V7). If `price` is the real seed payload, flag it and ask which field is canonical.
- `driverLocations` has no app writer anymore — ask if that rule should stay for fleet mapping or be removed.

---

### OUTPUT FORMAT

When done, emit:

1. **Diff summary** — every rule block changed (before → after).
2. **Test results** — the exact emulator test output (25 assertions).
3. **`flutter analyze` + `flutter test` results.**
4. **Verification greps** with their outputs.
5. **Open questions** — the two data-drift items above + anything unexpected found.
6. **Deployment statement** — "safe to deploy" ONLY if Steps 1–4 are all green and the requirements in the fix plan's W-6 (App Check platform coverage) are satisfied. Otherwise list exactly what blocks it.

**Remember:** You are NOT authorised to change `staging.firestore.rules`, the Flutter app code, or Cloud Functions unless the user explicitly approves after you report. Law 51.

--- COPY ABOVE ---

---

## Implementation Checklist (for the human)

- [ ] Confirm emulator + `@firebase/rules-unit-testing` are available (`core_app/package.json` already has firebase tooling).
- [ ] Approve the agent to modify `core_app/firestore.rules` + add `core_app/test/rules/firestore_rules_test.js`.
- [ ] Review the two reported data-drift items (V7 `price` vs `priceCents`; `driverLocations` orphan rule) and decide.
- [ ] After green verification, run `firebase deploy --only firestore:rules` with human sign-off.
- [ ] Double-check App Check enrollment for Android + iOS (and Web/Windows policy) before production rely on `isAppVerified()`.