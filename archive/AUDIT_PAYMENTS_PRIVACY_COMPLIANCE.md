# CARNAMA LABS — PAYMENTS, PRIVACY & LEGAL COMPLIANCE AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify payment safety, privacy flows,
data-subject rights, permissions posture, and store-policy compliance in the Carnama Labs
template (`core_app`) and domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Deletion screen exists" ≠ deletion WORKS end-to-end.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every PII field, every permission, every payment path. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A broken account-deletion flow is an Apple rejection
   (5.1.1(v)) and a GDPR art. 17 violation. A double-charge is a chargeback + reputation loss.

---

## 1. SCOPE

### 1.1 Payment Flow Integrity

**Files to audit:**
- `packages/core/lib/src/payment/**` (including fraud_screening_service.dart)
- `core_app/lib/features/checkout/**`
- Every `httpsCallable(` that touches money (create order, refund, tip)
- `packages/core/lib/src/network/sync_queue.dart` (order retries = double-charge risk)

**Verify:**
- [ ] Card data NEVER touches app servers or logs — identify the PSP from code; document the
  flow with file:line (who computes the charge, where the token goes)
- [ ] Server-authoritative pricing: client sends item IDs + quantities, server computes totals —
  any client-computed total trusted by the backend = P0 (price tampering)
- [ ] Idempotency: order/payment submission carries a client-generated key; retry after timeout
  cannot double-charge (sync-queue retry paths included)
- [ ] Tip flow: tip is included in the SERVER-computed total; tip can't be altered post-payment
- [ ] Fraud screening service: what does it actually gate? document with code citations; if it
  is consulted only in demo mode, that is a FINDING
- [ ] Refund path: who can trigger it, and is it authenticated server-side?
- [ ] Receipts: what does the user receive (email? in-app)? receipt failure must not fail order

### 1.2 PII Inventory & Data-Subject Rights

**Files to audit:**
- `core_app/lib/features/compliance/**` (delete_account_screen, data export)
- `packages/core/lib/src/export/data_export_service.dart` (and all export/backup sources)
- ALL Firestore writes containing user data (grep `.set(`, `.update(`, `.add(` with user fields)
- Auth providers (Google/Apple/email) and what profile data is persisted

**Verify:**
- [ ] PII inventory table: every field stored about a user, where (collection), why, retention.
  Include: name, email, phone, address, location traces, device tokens, order history,
  loyalty balances, reservation history, presence data, FCM tokens
- [ ] Account deletion: delete_account_screen → what does it actually call? Prove the chain
  (Auth deletion + Firestore docs + storage + FCM token + third parties). Any collection
  NOT covered by deletion = P0 finding (GDPR art. 17 / Apple 5.1.1(v))
- [ ] Data export: covers ALL PII categories above in machine-readable format; verify the
  source list inside data_export_service.dart is complete against the PII inventory
- [ ] Location data: pin_drop_map_screen / delivery flows — stored? retention? user can clear?
- [ ] Analytics/crash data: what is sent to Crashlytics/Analytics — is PII scrubbed?
- [ ] Logs: any `debugPrint`/`log(` printing email/phone/token — list every leak site

### 1.3 Consent & Transparency Surfaces

**Files to audit:**
- `core_app/lib/features/auth/presentation/terms_of_service_screen.dart`
- `core_app/lib/features/admin/presentation/privacy_policy_screen.dart`
- Signup flow, onboarding flow, location permission request moments

**Verify:**
- [ ] ToS + Privacy: actually surfaced during signup (checkbox/link), not only reachable later?
  (UI wiring audit said both screens exist — verify the signup gate)
- [ ] Config-driven URLs: privacy URL and ToS URL come from client_config per client — verify
  fields exist and are consumed (a template app showing TEMPLATE legal text to halal_boyz
  customers is a FINDING)
- [ ] Location permission: requested IN CONTEXT (when the feature needs it), not at first
  launch; graceful denied state exists
- [ ] Notification permission: same in-context pattern; denied state degrades gracefully
- [ ] Marketing consent (if any comms exist) is opt-in, not pre-checked

### 1.4 Permissions Posture (least privilege)

**Files to audit:**
- `core_app/android/app/src/main/AndroidManifest.xml` (location + foreground service confirmed)
- iOS: the iOS folder is ABSENT in the repo — confirm and document as a finding (release
  engineering prompt covers build aspects; here audit DECLARED permissions only)
- `packages/core/lib/src/**` permission-consuming services

**Verify:**
- [ ] AndroidManifest permission list vs features used: flag any permission without a consuming
  feature (bloat + Play policy risk). Specifically verify ACCESS_FINE_LOCATION,
  ACCESS_COARSE_LOCATION, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, CAMERA, INTERNET
- [ ] Android 14+ foreground-service type declared correctly
  (`foregroundServiceType="location"`) and the service has a user-visible rationale
- [ ] POST_NOTIFICATIONS runtime request flow exists (Android 13+)
- [ ] No permission requested that the store listing wouldn't declare (consistency doc)

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). Include: (a) PII inventory table, (b) deletion-coverage matrix (collection ×
deleted-by-flow), (c) permission × feature justification table.

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] PII inventory complete across ALL collections (not just obvious ones)?
- [ ] Deletion chain proven with code citations for every data store?
- [ ] Payment idempotency traced through BOTH direct path and sync-queue retry path?
- [ ] Every Android permission justified or flagged?
- [ ] No compliance claim based on docs instead of code?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**