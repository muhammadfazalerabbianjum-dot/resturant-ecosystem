# CARNAMA LABS — SECURITY & AUTHENTICATION AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify EVERY security control,
authentication flow, credential storage mechanism, and tenant isolation boundary in the Carnama Labs
template (`core_app`) and domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.
Read source, verify against source, report. A claim without `file:line` of current source is a fail.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it. Never trust assumptions — discover dynamically
   from actual source. Code differs → cite, amend, prove.
2. **No stubs / fake success / AI slop.** No "should be secure" without evidence. No "uses encryption"
---

## 1. SCOPE — what to verify

### 1.1 Authentication & Credential Storage

**Files to audit:**
- `packages/core/lib/src/auth/auth_repository.dart`
- `packages/core/lib/src/auth/auth_provider.dart`
- `packages/core/lib/src/auth/user_model.dart`
- `packages/core/lib/src/auth/user_schema.dart`
- `core_app/lib/features/auth/presentation/login_screen.dart`
- `core_app/lib/features/auth/presentation/signup_screen.dart`
- `core_app/lib/features/splash/presentation/splash_screen.dart`
- `packages/core/lib/src/notifications/fcm_service.dart`
- Any file referencing `SharedPreferences`, `flutter_secure_storage`, `UserDefaults`, `Keychain`

**Verify:**
- [ ] What credentials are stored post-login? (session token, refresh token, user ID, FCM token, claims)
- [ ] Where is each credential stored? (SharedPreferences? Secure storage? Memory only?)
- [ ] Is `flutter_secure_storage` used anywhere? (grep for it)
- [ ] Is `SharedPreferences` used for any auth-related data? (grep for it)
- [ ] How is FCM token stored in Firestore? (collection, document ID, fields)
- [ ] What happens to stored credentials on logout? (are they cleared? which ones?)
- [ ] What happens on token refresh? (is the new token persisted? is the old one invalidated?)
- [ ] Is there any PII in logs? (grep for email/name/phone in LoggerService calls)

### 1.2 Multi-Tenant Data Isolation

**Files to audit:**
- `packages/core/lib/src/network/firestore_client.dart`
- `packages/core/lib/src/providers/firestore_provider.dart`
- `packages/core/lib/src/config/core_config.dart`
- `core_app/lib/app/config/core_config_adapter.dart`
- ALL files in `packages/core/lib/src/` that query Firestore (grep for `.collection(`, `.doc(`, `.where(`)
- `apps/halal_boyz/assets/client_config.json` (the `clientScopingFields` section)

**Verify:**
- [ ] Every Firestore query includes a tenant-scoping filter (`clientId`, `userId`, `branchId`, or `customerId`)
- [ ] The `clientId` is derived from `bundleId` and is immutable after app start
- [ ] Firestore security rules (if present in repo) enforce tenant isolation at DB level
- [ ] Logout clears ALL tenant-specific cached data (Isar, Riverpod state, in-memory)
- [ ] FCM tokens are scoped to user+tenant (not just device)
- [ ] No query returns data across tenant boundaries
- [ ] The `clientScopingFields` config matches actual query patterns in code

### 1.3 Admin Access Control & Role Gating

**Files to audit:**
- `packages/core/lib/src/admin/admin_access_service.dart`
- `packages/core/lib/src/admin/seed_admin.dart`
- `core_app/lib/features/admin/presentation/gateway/admin_gateway_screen.dart`
- `core_app/lib/features/admin/presentation/role_router_screen.dart`
- `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart`
- `core_app/lib/features/admin/presentation/manager/manager_dashboard.dart`
- `core_app/lib/features/admin/presentation/kitchen/kitchen_dashboard.dart`
- `core_app/lib/features/admin/presentation/delivery/delivery_dashboard.dart`

**Verify:**
- [ ] Admin screens require authentication (Firebase Auth current user != null)
- [ ] Admin screens require admin role claim (custom claims check)
- [ ] `RoleRouterScreen` routes based on actual role claims (not just any authenticated user)
- [ ] Each dashboard rejects unauthorized roles (owner can't see kitchen, etc.)
- [ ] `admin_gateway_screen.dart` — what is the actual gating mechanism? (PIN? Role claim? Both?)
- [ ] `devAdminPin` from config — is it usable in release builds? Should it be stripped?
- [ ] Admin actions (delete menu item, change user role) are audit-logged
- [ ] `seed_admin.dart` — does it run in production? Should it be dev-only?

### 1.4 Input Sanitization & Injection Prevention

**Files to audit:**
- All form input handlers (login, signup, checkout, reservation, profile)
- `packages/core/lib/src/services/cloudinary_upload_service.dart`
- `packages/core/lib/src/utils/json_converters.dart`
- Any file writing user input to Firestore

**Verify:**
- [ ] All text inputs have length limits enforced
- [ ] Special characters / emoji don't crash the app or corrupt data
- [ ] Firestore writes use `Timestamp.now()` (server time), not client-provided timestamps
- [ ] File uploads are type-checked and size-limited
- [ ] No user input is interpolated into log messages without scrubbing
- [ ] Order special instructions / notes are sanitized

---

## 2. METHODOLOGY — how to verify

### STEP 1 — DISCOVER AUTH STORAGE

1. Grep for `SharedPreferences` across `core_app/lib` and `packages/core/lib` — list every usage
2. Grep for `flutter_secure_storage` — confirm presence/absence
3. Grep for `FirebaseAuth.instance.currentUser` — list every access point
4. Read `auth_repository.dart` — trace the full login → store → use → logout lifecycle
5. Read `fcm_service.dart` — trace token storage path

### STEP 2 — AUDIT EVERY FIRESTORE QUERY

1. Grep for `.collection(` in `packages/core/lib/src/` — list every collection accessed
2. For each collection, read the query code — does it include a tenant/user filter?
3. Cross-reference against `clientScopingFields` in config
4. Identify any query that returns data without scoping

### STEP 3 — VERIFY ADMIN GATING

1. Read `admin_access_service.dart` — what does it check?
2. Read `role_router_screen.dart` — how does it determine role?
3. For each admin dashboard, verify it checks authorization on entry
4. Test: can a non-admin user reach an admin screen via deep link?

### STEP 4 — VERIFY LOGOUT CLEANUP

1. Find the logout handler — what does it clear?
2. Verify: Isar cache cleared? Riverpod providers invalidated? FCM token removed from Firestore?
3. Verify: after logout, can any previous user's data be accessed?

---

## 3. OUTPUT FORMAT — the audit report

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (APPEND to the master report; use the
same Verdict + P0/P1/P2 conventions as the other audit prompts).

### 3.1 Credential Storage Inventory

| # | Credential | Storage Mechanism | file:line | Secure? | Notes |
|---|-----------|-------------------|-----------|---------|-------|
| 1 | [credential] | [mechanism] | [path:line] | ✅/❌ | [notes] |

### 3.2 Firestore Query Tenant-Scoping Matrix

| Query path | Collection | Tenant filter? | file:line | Status |
|-----------|-----------|----------------|-----------|--------|

### 3.3 Admin Access Control Matrix

| Screen | Auth required? | Role check? | Rejects unauthorized? | file:line | Status |
|--------|---------------|-------------|----------------------|-----------|--------|

### 3.4 Logout Cleanup Checklist

| Item | Cleared on logout? | file:line | Status |
|------|-------------------|-----------|--------|

### 3.5 Summary

- Credentials stored securely: N/Total
- Firestore queries with tenant filter: N/Total
- Admin screens with role check: N/Total
- Logout items cleared: N/Total
- **VERDICT:** PASS (all secure) / FAIL (list every failure with file:line)

---

## 4. CANONICAL COMMANDS

| id | CWD | Command | Expected |
|----|-----|---------|----------|
| SECURE_STORAGE | repo root | `grep -rn "flutter_secure_storage\|SecureStorage\|Keychain" packages/ core_app/` | Must find auth token storage |
| PREFS_AUTH | repo root | `grep -rn "SharedPreferences" packages/core/lib core_app/lib` | List all; auth-related = fail |
| FIRESTORE_QUERIES | `packages/core/` | `grep -rn "\.collection(" lib/src/` | Every query must have tenant filter |
| ADMIN_GATES | `core_app/` | `grep -rn "admin\|role\|claim" lib/features/admin/` | Every screen must check role |
| LOGOUT | repo root | `grep -rn "logout\|signOut\|Log Out" packages/ core_app/lib` | Must clear all credential stores |
| PII_LOGS | repo root | `grep -rn "email\|phone\|name" packages/core/lib/src/error_logger/` | No PII in error logs |

---

## 5. WHAT CONSTITUTES A FAILURE

Any of these is a FAIL (must be fixed before production):

- Auth token (session, refresh) stored in SharedPreferences / UserDefaults (plaintext)
- FCM token stored without user+tenant scoping
- Any Firestore query without a tenant/user filter
- Admin screen reachable without role claim verification
- `devAdminPin` functional in release builds
- Logout that doesn't clear all credential stores
- User input written to Firestore without validation
- File upload without type/size check
- PII in log messages
- `seed_admin.dart` executable in production builds

---

## 6. HONESTY BOUNDARY

**PROVABLE FROM SOURCE:** storage API used; presence of tenant filter in query; role check in admin
screen; logout cleanup calls; input validation presence.

**NOT PROVABLE WITHOUT FIREBASE RULES SUITE OR LIVE TEST:** that Firestore rules actually deny
cross-tenant access at the DB layer; that token revocation works end-to-end; that role claims are
set correctly by the Cloud Function. For each, either (a) cite the existing test/rules file, or
(b) mark `NOT PROVEN — needs [test/rules file]`.

---

## 7. VERDICT

- **PASS** — All credentials in secure storage, all queries tenant-scoped, all admin screens gated,
  logout fully cleans up, no PII in logs, honesty boundary respected.
- **FAIL** — List EVERY failure with `file:line`, the exact code, and the fix required.

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in this file (the sections below); the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT.** Read the code. Verify every credential store. Verify every query. Verify every
admin gate. Verify logout cleanup. Report exhaustively. Never claim a security property you cannot
prove from source.
