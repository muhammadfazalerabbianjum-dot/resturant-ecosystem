# BATCH RULES-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W4.4, W4.5, W4.8, W4.11.**

## 11. BATCH RULES-2 - OWNER BOOTSTRAP + FCM LIFECYCLE + CONFIG DRIFT

**Predecessor:** RULES-1. **Emulator-gated:** rules emulator (harness cases). **Master:** W4.4, W4.5, W4.8, W4.11. **MIRROR: auth_repository + fcm_service are shared code - shell carries copies, mirror them.**

### 11.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `functions/src` (no writer) + `firestore.rules:47-51` | `settings/ownerInfo.ownerEmail` never provisioned -> `isOwner()` DEAD on fresh backend -> ALL owner-gated writes/uploads fail out-of-box | P1 (01-P1-C) |
| P-2 | `admin_access_service.dart:106` vs `firestore.rules:51` | Reads `.email` while rules use `ownerEmail` (field-name drift) | P2 (01-P2-6c) |
| P-3 | `auth_repository.dart:299-325` | signOut clears prefs/Isar/Firestore-persistence/auth but NEVER `fcmToken` -> cross-user push leak on shared devices | P1 (01-P1-D) |
| P-4 | `cloud_function_mocks.dart:248` writes `audit_logs` (plural); rules define `audit_log` (singular) | Collection drift; `admin_access_service.dart:80-91` `_logAudit` always DENIED (dead) | P2 (01-P2-3, 01-P2-6b) |
| P-5 | both `client_config.json` `clientScopingFields` | Reservations listed under customerId; queries+rules use userId | P2 (01-P2-6a) |

### 11.2 Solution - design principle + acceptance contract

**Design principle:** bootstrap ownerInfo exactly like v002 (fireway migration); clean up auth + audit + config contract drift in the same pass; delete dead paths.

**Acceptance contract (from master W4.4/W4.5/W4.8/W4.11):**
1. New `core_app/functions/src/migrations/v003__seed_settings_owner_info.ts` (v002 pattern: idempotent `doc.exists` guard, NOT imported by `index.ts`, emulator/bootstrap-only): seeds `settings/ownerInfo { ownerEmail, updatedAt }` from the owner-claim user.
2. Canonical field = `ownerEmail`: fix `admin_access_service.dart:106`.
3. Canonical audit collection = `audit_log`: migrate `cloud_function_mocks.dart:248` from `audit_logs`; delete the dead `_logAudit` path in `admin_access_service.dart:80-91` (rules deny client writes) and replace with a comment pointing at the CF-owned audit trail.
4. signOut (`auth_repository.dart:299-325`, BEFORE `terminate()`): best-effort try/catch `users/{uid}` update `{'fcmToken': FieldValue.delete(), 'fcmLastUpdated': FieldValue.delete()}`; then guarded `FirebaseMessaging.instance.deleteToken()` wrapped like the Google signOut step. Self-healing: `fcm_service.dart:26-49` re-writes on re-login.
5. Both configs: reservations under `userId` (+`branchId`) in `clientScopingFields`.
6. Rules harness: `isOwner()` true/false by ownerEmail doc presence (case).

### 11.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | signOut removes fcmToken | Fake-Firestore seam: signOut -> `users/{uid}` no longer has fcmToken |
| T-2 | Re-login re-uploads token | Integration-style unit: init() after signOut re-writes token (self-healing) |
| T-3 | ownerEmail read canonical | `admin_access_service` test reads `ownerEmail` not `email` |
| T-4 | v003 idempotent + not imported | Migration unit: run twice -> one doc; `index.ts` grep `v003` = 0 |
| T-5 | isOwner() by ownerEmail | Rules harness: doc present -> owner allow; absent -> owner deny |
| T-6 | audit_log singular | grep `audit_logs` in lib = 0 |

### 11.4 Proof gates

- [ ] `npx tsc --noEmit` + `npm test` green (migration compiles; v003 not imported)
- [ ] Client unit tests T-1..T-3 green
- [ ] Rules harness green with isOwner case (T-5)
- [ ] grep `fcmToken` in signOut path: delete present; grep `audit_logs` = 0
- [ ] Universal Gate Set U (index Section 1)

### 11.5 Honest residuals

- The migration seeds ownerInfo only where console/emulator runs it - add the VERIFY-IN-CONSOLE checklist line (master section 12) for production provisioning.
- Token-clearing is best-effort (network may fail during signOut); self-healing on re-login covers the missed case - documented in code.

**END OF BATCH RULES-2 SPEC** - do not proceed until these gates pass and the RULES-2 addendum is appended to FIX_VERIFICATION.md.