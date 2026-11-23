# AUDIT PROMPT 09 — FIREBASE BACKEND: RULES, FUNCTIONS, INDEXES & DEPLOY SAFETY

**Spec date:** 2026-08-31 · Audits the ENTIRE server side of the Carnama Labs platform:
`core_app/firestore.rules` (535 lines), `core_app/functions/src/index.ts` (1001+ lines, 17
exports), `core_app/storage.rules`, `core_app/firestore.indexes.json`, `core_app/firebase.json`,
`core_app/.firebaserc`, `core_app/test/functions/`, and the rules↔Dart / functions↔Dart contracts.

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it. Never trust comments or docs.
2. **No stubs / fake success / AI slop.** "Rules deny it" requires the actual rule text, cited.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source. All 535 rules lines and
   all 1001 index.ts lines get READ — no sampling.
4. **Completeness.** Every collection × every rule; every function × every check; every Dart
   query × every index. Exhaustive tables.
5. **No escapes.** No skipping, no "too long to read".
6. **Production-grade or not at all.** A callable without an auth check is a fail. A client-supplied
   price trusted server-side is a fail. A rule gap exposing another tenant's orders is an
   automatic P0 and FAIL regardless of everything else.

---

## 1. SCOPE

### 1.1 Rules ↔ Client Contract (both directions)

Enumerate EVERY `match` block in `firestore.rules` (all 535 lines) and EVERY
collection/document path the Dart side touches (grep `core_app/lib`, `packages/core/lib` for
`.collection(`, `.doc(`, `collectionGroup(`, `withConverter`).

- [ ] Collection × rules table: every client-touched path has an explicit rule (no accidental
      `match /{allPaths=**}` fallback catch that silently denies or allows)
- [ ] Reverse: rules that exist for collections the client NEVER touches (dead rules = drift)
- [ ] Query-safety: Firestore rules are NOT filters — for every Dart `where()` query, verify the
      rule grants read of the ENTIRE result set (rules-are-not-filters violation = runtime
      permission-denied on real data even though "it worked with 3 test docs")
- [ ] Public reads (`allow read: if true` at menus:189, branches:216, hours:220, promotions:247)
      — enumerate exactly what fields/documents that exposes; any PII in those docs?
- [ ] `settings/{doc}` split (273-278): verify `featureFlags` public-read is intended and no other
      settings doc leaks
- [ ] `onFirestorePermissionDenied` (index.ts:902) subscribes to Pub/Sub topic
      `firestore-security-alerts` — rules CANNOT publish to Pub/Sub. Find what feeds that topic
      (GCP log sink? nothing?) or flag as dead plumbing.

### 1.2 Tenant Isolation & White-Label Backend Topology (THE white-label question)

`.firebaserc` declares ONE project: `resturants-8547d`. `firebase.json` flutter config pins one
android/iOS app. Client apps are keyed by `clientId` = bundle identifier (client config).

- [ ] Determine the ACTUAL tenant model from code+rules: one shared Firestore for all brands, or
      per-client projects? Cite evidence (rules referencing clientId? per-brand collections?
      .firebaserc lists one project? generated apps' firebase config?).
- [ ] `hasAppId()` (rules:13) — what does it compare against, and does it SCOPE DATA or only
      verify the requesting app binary? A halal_boyz user must not read another brand's orders.
- [ ] If one shared project: every order/branch/menu/reservation read+write must be tenant-scoped
      IN THE RULES — verify or flag P0. If per-client projects: verify nothing hardcodes
      `resturants-8547d` for generated apps (grep projectId in Dart + configs + firebase.json).
- [ ] `google-services.json` / `GoogleService-Info.plist` handling per generated app.
- [ ] Firestore backup/export story: any evidence of scheduled exports? Absence = flagged risk,
      never silently ignored.

### 1.3 Auth, Roles & Privilege Escalation

- [ ] `userRole()`/`isOwner()` (rules:47-61) — custom claims vs users-doc fields; verify the claim
      source (`syncUserRoleClaims`, index.ts:878) cannot be self-triggered by a malicious write to
      one's own `users/{uid}` doc (rules 292-296: WHAT FIELDS may a user self-write? role/branch
      excluded? Cite the exact field checks or flag P0 escalation).
- [ ] `admins/{doc}` (rules:284) — owner-only; who seeds the FIRST owner? Bootstrap path
      documented or flagged (chicken-and-egg is what pushes teams to loosen rules in prod).
- [ ] `loyalty/{userId}` (rules:288) — user can read AND WRITE their own loyalty doc: enumerate
      what a user could self-mint (points? tier? redemption state?) and whether server flows
      (createOrder/applyPromo) reconcile — self-mint potential = P0/P1 by redemption impact.
- [ ] Anonymous auth: rules gate `!isAnonymous()` broadly — enumerate every feature that breaks
      for guests vs the guest flows the app actually implements.
- [ ] Every onCall in index.ts: `request.auth` null-check + role/claim verification + tenant
      check BEFORE any sensitive work. Table of 17 exports × checks present/absent.

### 1.4 App Check

- [ ] `isAppVerified()`/`strongAppCheckEnabled()` (rules:17-30) — soft vs hard enforcement: do
      production rules REJECT absent tokens, or is a debug fallback shipping?
- [ ] Do the v2 onCall functions verify App Check (`appCheckData`) or rely on rules only?
- [ ] Any committed debug App Check providers/tokens reachable in release builds.

### 1.5 Functions Inventory & Per-Function Security (17 exports — ALL, no sampling)

`calculateTax`:60 · `screenPaymentFraud`:101 · `dispatchToFleet`:127 · `logFunnelEvent`:159 ·
`deleteUserData`:336 · `deleteUserDataRetry`:383 · `applyPromo`:535 · `createPaymentIntent`:555 ·
`createOrder`:667 · `recoverAbandonedCarts`:763 · `onOrderStatusChange`:805 ·
`syncUserRoleClaims`:878 · `onFirestorePermissionDenied`:902 · `stripeWebhook`:978 ·
`onReservationCreated`:1038 · `auditSettingsChanges`:1076 · `auditRoleChanges`:1096

For EACH: (a) auth+role check, (b) input validation (types/bounds/whitelists), (c) tenant scoping,
(d) idempotency (retries/duplicate events/duplicate charges), (e) error handling (fail-open vs
fail-closed), (f) PII/log hygiene, (g) timeout/memory config, (h) cost-amplification risk
(unauthenticated or cheap-call entry points that trigger paid work — `logFunnelEvent`,
`recoverAbandonedCarts`, `calculateTax` especially).

### 1.6 Payment Integrity (server-side)

- [ ] `createOrder`/`createPaymentIntent`/`applyPromo`: prices/tax/discounts computed SERVER-SIDE
      from Firestore-authored data, never from client-supplied amounts (client-sends-total = P0).
- [ ] `stripeWebhook` (978): signature verification, event-id dedup, order-state reconciliation,
      `payment_intent.payment_failed` handling, replay protection.
- [ ] Idempotency across createOrder retry + offline sync-queue replay (packages/core) — can one
      client operation create two orders or two charges? Cite the dedup key or flag.
- [ ] Race: order status transitions (onOrderStatusChange:805) vs concurrent client writes
      (rules 347-380 update conditions) — state machine enforced server-side or client-honored?

### 1.7 GDPR Erasure Chain (backend half)

- [ ] `deleteUserData` (336) + `deleteUserDataRetry` (383) + rules `deletion_requests` (341-345):
      collection × erased-by-flow matrix for EVERY collection holding user data (merge with the
      client-side matrix from prompt 06 into one truth table).
- [ ] `test/functions/gdpr_erasure_test.js` (347 lines): runs against the emulator? Covers ALL
      collections? Only 1 of 17 functions has ANY test — list the other 16 as untested (finding).
- [ ] Stripe-side data (customers, payment methods) erasure or flagged absence.

### 1.8 Indexes ↔ Queries Contract

- [ ] Every composite query in Dart (two+ equality/range fields, orderBy) maps to an entry in
      `firestore.indexes.json` (157 lines) — missing index = runtime failure at scale, not in dev.
- [ ] Reverse: indexes no query uses (cost + maintenance drift).
- [ ] The permission-denied alerting function implies ops expect query-vs-rules mismatches in
      production — cross-check §1.1 findings against what that alert would actually catch.

### 1.9 Storage Rules (80 lines — read every one)

- [ ] `proof_of_delivery/{orderId}/{fileName}` write (rules:65-73): authenticated + size/type —
      can ANY authenticated user write a POD for ANY orderId? Upload-overwrite of an existing
      POD? Cite conditions.
- [ ] `avatars/{userId}` — `isOwnFile(userId)` proof; single-segment `{fileName}` wildcard (no
      path traversal) — verify.
- [ ] Public promotion reads vs uploaded content moderation (any user-uploaded content reachable
      publicly without review?).
- [ ] MIME-type-only image check (`contentType.matches('image/.*')`) — content-type spoofing
      flagged; size limit value cited.
- [ ] Deny-all fallback (`match /{allPaths=**}` at 90) — confirm no earlier permissive catch-all.

### 1.10 Deploy, Build & Test Hygiene

- [ ] BOTH `functions/src/index.ts` AND compiled `lib/index.js` are committed: verify which one
      deploys (`firebase.json` predeploy runs `npm run build` ⇒ lib is deployed AND committed =
      drift risk); check lib is in sync with src (spot-diff exports) or flag.
- [ ] `functions/package.json` (22 lines): engines, TS version, dependency pinning; TS strictness
      in tsconfig; lint config presence.
- [ ] NO CI exists (established in prompt 07 scope) — rules/functions changes deploy by hand:
      flag as P1 process gap; document the exact commands a deploy needs.
- [ ] ZERO Firestore rules unit tests (`@firebase/rules-unit-testing` absent) — 535 lines of
      security logic with no regression net = flag; recommend test-per-rule-block plan.
- [ ] Emulator config (`firebase.json`): `host: 0.0.0.0` exposure, `singleProjectMode`, ports —
      dev-only OK? Any secrets committed anywhere in functions/ (service accounts, .env)?
- [ ] **Console-side checklist** (cannot be verified from repo — output as an ops checklist):
      App Check ENFORCED (not just registered) for Firestore/Storage/Functions in prod; IAM
      principle-of-least-privilege on the project; Stripe webhook secret + endpoint config;
      budget alerts; Firestore PITR/exports enabled; auth providers list matches app flows;
      Pub/Sub topic `firestore-security-alerts` actually wired to a log sink; Cloud Logging
      retention. Mark each "VERIFY IN CONSOLE" — repo cannot prove these.

### 1.11 Known-Strength Verification (do NOT assume; prove)

The rules show: App Check helpers, schema validators (geometry/location/restaurantConfig/
operatingHours, reservation/waitlist counters), owner-gated admin writes, deny-all fallback.
For each claimed strength, cite the line proving it is ACTIVE in every relevant match block —
a validator defined but not wired into an `allow` condition is a finding, not a strength.

---

## 2. DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in this file (the tables above); the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.
5. Include: (a) collection × rule matrix, (b) 17-function × 8-check matrix, (c) index × query
   matrix, (d) the console-side ops checklist, (e) rules-test plan.

**Report ONLY. No code changes. No fixes.** Running read-only commands (grep, `npm --prefix
functions run lint`, `npx tsc --noEmit`, emulator-based rules tests IF already configured) is
permitted; deploying anything is NOT.

---

## 3. SELF-CHECK (all must be YES before submitting)

- [ ] All 535 rules lines read and every match block in the matrix?
- [ ] All 17 functions in the check matrix, none skipped?
- [ ] Every Dart collection path mapped to a rule (or flagged unmatched)?
- [ ] Tenant-isolation verdict stated with evidence for BOTH projects-shared and per-project?
- [ ] Client-supplied-price question answered with code citations (not assumptions)?
- [ ] No claim about console settings presented as proven (all marked VERIFY IN CONSOLE)?
- [ ] Zero recommendations to add a library unless an equivalent pattern already exists?

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**

---

# AUDIT 09 — EXECUTED REPORT: FIREBASE BACKEND (RULES, FUNCTIONS, INDEXES, DEPLOY SAFETY)

**Executed:** 2026-09-01 · **Mode:** report-only, zero code changes · **Verdict: ❌ FAIL** — 2×P0
(one server-side unique to this audit, one cross-cutting with 08) + 8×P1 + P2/P3 debt. Report-only
per spec §2; fixes specified as "Proven Best-Fit" candidates, not applied.

## R0. Spec-premise corrections (current codebase wins over this prompt)

| Spec claim (this file) | Current codebase reality | Proof |
|---|---|---|
| `firestore.rules` = 535 lines | **591 lines** (all read) | full sequential reads 1–591 |
| `functions/src/index.ts` = "1001+ lines, 17 exports" | **1115 lines**; 17 exports confirmed | `Select-String '^export const'` → 17; full reads 1–1115 |
| "ZERO Firestore rules unit tests (`@firebase/rules-unit-testing` absent)" | **FALSE.** `test/rules/firestore_rules_test.js` (1225 lines, 58 scenario groups T1–T37, T-D1..12, T-E0..4, T-P1..4) + `test/functions/gdpr_erasure_test.js` (369 lines) + `functions/scripts/money_emulator_check.js`; `@firebase/rules-unit-testing@^5.0.2` present in `core_app/package.json` + `node_modules` | `core_app/package.json`: `test:rules` = `firebase emulators:exec --only firestore "node test/rules/firestore_rules_test.js"` |
| Emulator rules tests "IF already configured" (assumed impossible) | **CONFIGURED AND EXECUTED THIS SESSION: 92/92 assertions PASS, exit 0** | run output: `PASSED: 92 FAILED: 0 TOTAL: 92` · `Script exited successfully (code 0)` |
| `npm --prefix functions run lint` runnable | **Missing script** (`npm error Missing script: "lint"`); no eslint config/devDeps in `functions/` | P1 confirmed |
| `npx tsc --noEmit` | **PASS (exit 0)** | run in `core_app/functions` |

All citations below use ACTUAL current line numbers (spec's were stale).

## R1. Coverage proof (no sampling — hard gate 3)

Read in full, sequential, no gaps:
- `core_app/firestore.rules` — 591/591 · `core_app/functions/src/index.ts` — 1115/1115
- `functions/src/payment.ts` 477/477 · `ddos.ts` 53/53 · `notification_copy.ts` 175/175
- `core_app/storage.rules` 94/94 (spec said 80 — stale) · `firestore.indexes.json` 157/157 · `firebase.json` 54/54 · `.firebaserc` 5/5
- `functions/package.json` 22/22 · `functions/tsconfig.json` 17/17 · rules-test harness (1225 lines, coverage mapped) · `test/functions/gdpr_erasure_test.js` (369 lines)
- **lib↔src sync:** `functions/lib/index.js` `exports.*` = the 17 src exports + internal helpers (`collectUserDocs`, `eraseRefs`, `deleteAuthUser`, `runErase`, `eraseUserData`, `retryIncompleteErasures`, `resolveChargeTaxAndPromo`, `commitChargePromoUsage`, `serverApplyPromo`) — no drift; `ddos/payment/notification_copy/migrations` all compiled. Spot-diff PASS.
- Dart contract surface: recursive greps over `core_app/lib`, `packages/core/lib`, `packages/ui/lib`, `apps/halal_boyz/lib` for `.collection(`, `.doc(`, `collectionGroup(`, `.where(`, `httpsCallable('…')`, `FirebaseStorage|.ref(`; every hit then read at cited lines (plugin `ephemeral/` symlinks excluded from analysis).

## R2. Tenant isolation & white-label backend topology — VERDICT (spec §1.2)

**Intended model: ONE Firebase project per client brand; `resturants-8547d` is the TEMPLATE's own backend.**

Evidence:
1. `.firebaserc:1-5` — single project `resturants-8547d`.
2. `firebase.json:34-53` — flutter block pins ONE android/iOS appId on `resturants-8547d`.
3. `apps/halal_boyz/android/app/google-services.json` — `project_info.project_id` = **`demo-tenant`**; `api_key` array **null**; `package_name` **empty** (confirms master 08 P0-WL-1; the generated client targets its OWN project).
4. Recursive search of `apps/` for `firestore.rules|firestore.indexes.json|storage.rules|.firebaserc` → **zero hits**. The generator provisions NO backend for the new project.
5. `firestore.rules` grep `clientId|appId|bundle` → only the `hasAppId()` helper (13–15). No rule scopes data by client.
6. Per-client config keyed by clientId only where server-side config exists: `settings/taxRates.clients[clientId]` (index.ts:72–77; payment.ts:102–149) and callable payloads (`clientId` in calculateTax/createPaymentIntent schemas, payment.ts:468).

**Verdict:**
- `hasAppId()` (rules:13–15) checks the request's auth token carries an `app_id` claim — i.e., verifies the requesting BINARY is App-Check-attested. It does **not** scope data and cannot. Tenant isolation is (by design) the **project boundary**, not a rule clause.
- Under the intended per-project model, the unscoped rules are correct. But **nothing in the generator or repo enforces that model**: a generated brand ships with no rules, no indexes, no functions, no Stripe webhook, no App Check apps, no `settings/ownerInfo` seeding. Once master-08's empty-key defect is fixed, that client boots against a project whose rules are whatever the console default is — plausibly locked (deny-all → dead app) or leftover test-mode (open). **P0-FB-1** (cross-cuts 08).
- Shared-project hypothetical: two brands on `resturants-8547d` → owner/manager roles read ALL orders/branches/menus/users across brands (rules:348–360, 292–300, 185–223) — cross-brand exposure. The per-project invariant must be asserted at generation time (solution table in master).

## R3. App Check (spec §1.4) — PARTIAL enforcement; production claim-path unprovable from repo

- Helpers: `hasAppId()` rules:13–15 · `hasAppCheckToken()` rules:17–20 · `strongAppCheckEnabled()` rules:22–28 (flag-gated STRICT via `settings/featureFlags.strongAppCheck`, exists-guarded) · `isAppVerified()` rules:30–35 (RELAXED = OR default).
- **Wired with `isAppVerified()`** (verbatim-verified): orders create :361 / update :369; `deletion_requests` :342; `reservation_counters` :419–421; `waitlist_counters` :533–535; `notifications`(+items) :565/:568. Functions: `enforceAppCheck()` (index.ts:42–49) called by **all 8 onCall callables** (:61, :102, :128, :160, :337, :536, :556, :668).
- **NOT App-Check-gated** (`isAuthenticated()` only): presence write :396; `reservation_locks` :403–409; `reservations` :430+; `waitlist` :541–552; `promo_usage` :516–526; `users` write :296; plus carts/driverLocations/deliveries blocks. → **P2: App Check gating inconsistent across write surfaces** (spec §1.11 "defined but not wired" trap, applied to App Check).
- **Load-bearing caveat:** the claim paths `request.auth.token.app_id` (rules:14) and `request.auth.token.firebase.app_check_token` (rules:17–19) are INJECTED ARTIFICIALLY by the test harness (`test/rules/firestore_rules_test.js:32-33`). The 92/92 emulator pass proves the rules LOGIC, not that Firebase emits these claims on production ID tokens. If neither claim materializes, `isAppVerified()` is false for every request and **all six gated write surfaces brick**. Repo cannot prove claim presence → **VERIFY IN CONSOLE (P1 risk)**: enforce App Check, mint a live token, inspect claims before flipping `strongAppCheck=true`.

## R4. Function × check matrix — all 17 exports, none skipped (spec §1.5)

Checks: **AC**=App Check · **AuthN** · **AuthZ** (caller binding/scope) · **Zod** · **Money** (server-authoritative) · **Idem** (idempotency) · **Blast** (Admin-SDK write blast radius) · **Tenant**.

| # | Export (line) | AC | AuthN | AuthZ | Zod | Money | Idem | Blast | Tenant |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `calculateTax` onCall :60 | ✓ :61 | **✗ no auth check** | n/a (pure calc) | ✓ :54-58 | tax server-side ✓ :72-86, fail-closed :81-86 | n/a | none (no writes) | ✓ via `clients[clientId]` |
| 2 | `screenPaymentFraud` onCall :101 | ✓ :102 | **✗** | **✗ `customerId` client-supplied → spoofable** | ✓ | n/a | n/a | read-only count | ✗ spoofable (see P1-FB-6) |
| 3 | `dispatchToFleet` onCall :127 | ✓ :128 | **✗ no auth gate in :127-158** (App Check only) | **✗ staff action exposed to any attested client** | ✓ | n/a | tx ✓ | `orders/{id}` update (Admin SDK, bypasses rules) | template project only |
| 4 | `logFunnelEvent` onCall :159 | ✓ :160 | ✗ (by design, pre-auth funnel) | n/a | loose (event/properties) | n/a | append-only | `analyticsEvents` add | ✓ |
| 5 | `deleteUserData` onCall :336 | ✓ :337 | ✓ self (`request.auth.uid` required) | ✓ self-only erasure | n/a (no payload) | n/a | ✓ marker + ≥1h retrier | wipes 11 collections (see R6) | per-project ✓ |
| 6 | `deleteUserDataRetry` onSchedule :383 ('0 * * * *') | n/a | n/a (scheduled) | n/a | n/a | n/a | ✓ completes only `in_progress` ≥1h (gdpr test T6) | same set | ✓ |
| 7 | `applyPromo` onCall :535 | ✓ :536 | ✓ uid-bound | ✓ per-user usage doc | ✓ :473-477 | ✓ discount 100% server (payment.ts:327-371) | ✓ idempotencyKey replay-safe :339-347 | `promo_usage`/`promoCodes` | ✓ |
| 8 | `createPaymentIntent` onCall :555 | ✓ :556 | **✗ no auth binding observed :556-576** | n/a | ✓ :451-471 | **✗ P0-FB-2: subtotal = Σ client-supplied `priceCents`** (:575-576 "re-derive … from the FLAT line items"; payment.ts:192-210; **no `menus` read anywhere in index.ts**) | ✓ Stripe idempotencyKey | Stripe PaymentIntent | ✓ tax lookup per clientId |
| 9 | `createOrder` onCall :667 | ✓ :668 | ✓ uid-bound | ✓ intent-ownership check | partial (order object spread) | partial: total/tax/discount equality enforced (payment.ts:417-443) but **item prices never re-verified vs menus** | ✓ (intent-status + equality gate) | **`orders/{id}` merge-write of client payload via Admin SDK — rules bypassed** (P0, cross 06 P0-2) | ✓ |
| 10 | `recoverAbandonedCarts` onSchedule :763 (5 min) | n/a | n/a | n/a | n/a | n/a | merge writes | `carts` + FCM | ✓ |
| 11 | `onOrderStatusChange` onDocumentUpdated :805 | n/a | n/a | n/a | n/a | ✓ loyalty points server-computed | n/a | `loyalty` + FCM | ✓ |
| 12 | `syncUserRoleClaims` onDocumentWritten :878 | n/a | n/a | n/a | n/a | n/a | idempotent claim set :886-890 | Auth custom claims | ✓ |
| 13 | `onFirestorePermissionDenied` onMessagePublished :902 | n/a | n/a | n/a | n/a | n/a | bucket tx ✓ :917-931 | `securityMetrics` + FCM | ✓ |
| 14 | `stripeWebhook` onRequest :978 | n/a (correct) | ✓ signature verify raw body :982-996 | metadata `orderId` :1001 | raw | ✓ amount from Stripe event only | re-delivery = same update (benign; no ledger) | `orders/{id}` status='confirmed' :1005-1009 | ✓ |
| 15 | `onReservationCreated` onDocumentCreated :1038 | n/a | n/a | n/a | n/a | n/a | n/a | FCM only | ✓ owner + same-branch managers :1051 |
| 16 | `auditSettingsChanges` onDocumentWritten :1076 | n/a | n/a | n/a | n/a | n/a | append | `audit_log` (rules write=false :557) | ✓ |
| 17 | `auditRoleChanges` onDocumentWritten :1096 | n/a | n/a | n/a | n/a | n/a | role-diff only :1104 | `audit_log` | ✓ |

**Matrix verdicts:** AC 8/8 onCall ✓ · AuthN gaps on #1/#2/#3/#8 (P1/P3, see findings) · Money P0 on #8/#9 (client-priced charge — P0-FB-2) · Blast-radius: #9's client-payload spread through the Admin SDK is the single largest rules-bypass surface.

## R5. Collection × rule matrix (rules ↔ client contract, both directions — spec §1.1)

Client paths from greps; rule line ranges verbatim-verified. Public reads listed per spec.

| Collection | Client touch (evidence) | Rule (firestore.rules) | Verdict |
|---|---|---|---|
| `orders` | order_repository.dart:31-37; kitchen_service.dart:27-32; delivery_service.dart:29-51; admin_data_service.dart:37-42/69-74/108-113/216-221/236-241; revenue/top charts; fraud_screening_service.dart:28-33; gdpr_service.dart:54-57; data_export_service.dart:67-70; proof_of_delivery_service.dart:54-60; sync_queue offline flush | :347-388 — read :348-360 (owner ∪ manager-branch ∪ kitchen-branch[confirmed,preparing] ∪ delivery-branch[ready,pickedUp ∪ assigned] ∪ customer-own); create :361-368 (`customerId==uid`, `isOrdersAccepting()`, branchId non-empty, `totalCents` int≥0, **`status=='pending'`** :368 → **breaks offline queue flushing `'confirmed'`** = master 02 P0 confirmed server-side; NO items validation); update :369-387 (owner any · manager status+assignedDriverId same-branch · kitchen confirmed→preparing→ready status-only · delivery assigned ready/pickedUp→pickedUp/delivered status-only; **no customer disjunct → client-side cancel impossible**); delete → **no allow = deny** (demo GDPR batch-delete fails; prod CF unaffected) | Strict + mostly sound; 3 contract breaks (P1-FB-1/2/3 + 02 P0) |
| `users` | admin_access_service.dart:112-125; seed_admin.dart:15-30; admin_data_service.dart:129-174; owner_dashboard.dart:462; gdpr (erased LAST) | :292-334 — read self ∪ owner ∪ manager; write self ∪ owner ∪ manager-same-branch (manager limited to kitchen/delivery/customer); **anti-self-demotion** :305-316; **owner-demote protection** :318-324; `branchId` owner-only :326-334 | STRONG — no self-escalation; :119-124 query provable for staff, denied→fail-secure `catch → false` :126-129 for customers ✓ |
| `reservations` | reservations_repository.dart (locked create); admin_reservations_tab.dart:21-32; gdpr_service.dart:62-65 | :425-445+ — read staff ∪ customer-own(userId); create: locked key set, **`customerId` forbidden (hasOnly)** — tested T-E4 ✓ | ✓ |
| `reservation_counters` | reservations_repository.dart:18-22/51-55 | :418-423 app-verified + `isValidReservationCounter` | ✓ (hostile write = slot corruption only, :417) |
| `reservation_locks` | reservations_repository.dart:24; gdpr_service.dart:70-73 | :401-410 staff-branch-read ∪ own; create self; delete own | ✓ |
| `waitlist` / `waitlist_counters` | waitlist_repository.dart:102-120 / :80-87 | :539-552 (self, immutable keys) / :532-537 (`isValidWaitlistCounter`) | ✓ |
| `menus` | merged_menu_provider.dart:120-141; menu_repository.dart | :185-213 **public read** (name/price/tags/branchId/isAvailable/image — no PII) | ✓ intended |
| `branches` | home_service.dart:102-105; merged_menu_provider.dart:43-58; admin_data_service.dart:177-233 | :215-223 public read; owner write | ✓ |
| `locations` | locations feature | :226-241 geometry validator wired | ✓ (T-E2 ✓) |
| `promotions` | home_service.dart:69-73 | :242-250 **public read** (title/subtitle/imageUrl/colors — no PII) | ✓ |
| `settings/restaurantConfig` | restaurantConfigProvider | :259-267 signed-in read; owner write + shape validator (T-E3 ✓) | ✓ |
| `settings/defaultOperatingHours` | hours reader | :268-272 | ✓ (T-E3 ✓) |
| `settings/{doc}` | featureFlags public; ownerInfo; taxRates | :273-279 read `featureFlags` ∪ isOwner; owner write | ✓ (T-E3 regression ✓); flags = booleans, no PII (prod contents VERIFY) |
| `settings/panicSwitch` | rule-internal `isOrdersAccepting()` :362 | :167-184 owner-gated | ✓ **fail-OPEN when doc missing** (T-P3) — P3 note |
| `carts` | cart uid docs; data_export_service.dart:106; CF :763+ | :461-477 self-uid | ✓ |
| `loyalty` | data_export_service.dart:81 | :287-291 self | ✓ |
| `notifications`(+items) | B3 P4 mailbox; gdpr_service.dart:94-95 | :564-569 self-only, app-verified | ✓ (T-D1..D5 ✓) |
| `notification_queue` | demo daemon (owner identity) | :577-580 staff-read, owner-write | ✓ (T-D6..D9 ✓) |
| `audit_log` / `audit_logs` | admin_access_service.dart:82 `.add()` → **DENIED** (write:false) [cross 01] | :554-558 / :586-589 owner-read, write:false | ✓ immutable |
| `driverLocations` | driver_location_service; gdpr_service.dart:108 | :481-491 self-write/staff-read | ✓ |
| `deliveries` | driver_location_service.dart:99 `.set()` | :505-507 role-scoped | ✓ |
| `deletion_requests` | gdpr_service.dart:150/176/196 + CF | :341-345 self read/create/update, **delete:false** (audit-proof + retrier worklist) | ✓ |
| `promo_usage` | applyPromo CF; gdpr_service.dart:86-89 | :516-526 self, code immutable | ✓ |
| `promoCodes` | **client NEVER reads** (promo_code_service.dart:19) | :455-458 read = ANY authenticated non-anon | **over-exposed** (`usedCount`/`maxUses` readable) → P3 tighten |
| `analyticsEvents` | telemetry_service.dart:28 (**DEMO mode only**; prod → `logFunnelEvent` CF) | **NO match block → implicit deny** | demo telemetry silently fails (caught :37-38) → P3 |
| `securityMetrics` | CF-only (index.ts:915-931) | none (Admin SDK bypasses) | ✓ |
| `admins` | admin_access_service.dart:112-115 | :281-286 isOwner-only | non-owner → fail-secure ✓; `admins` check dead for managers → P3 [cross 01] |
| `archived_users` | **no client touch** (mocks only) | :515 | dead rule → drift P3 |

**Reverse + fallback notes:** `archived_users` dead; `securityMetrics` CF-only by design. No explicit deny-all block in firestore.rules — implicit default-deny (equivalent; spec §1.11's literal "deny-all block" NOT present → drift P3). Storage has one (storage.rules:90-92).

## R6. Rules-are-not-filters audit — every client query (spec §1.1)

**FAILS (runtime permission-denied on real data):**
- **FAIL-1 — driver "my orders" stream.** `delivery_service.dart:29-37` queries `orders.where('assignedDriverId'==uid).where('status' whereIn [ready,pickedUp]).orderBy('createdAt')`; the delivery read-clause (rules:354-357) additionally requires `resource.data.branchId == userBranch()` and the query has **no branchId constraint** → not provable for the result set → **permission-denied for delivery-role users**. The same file's `availableOrders` (:46-51) DOES filter `branchId` → provable ✓.
- **FAIL-2 — kitchen "ready" board.** `kitchen_dashboard.dart:301-302` calls `streamOrders(branchId, ['ready'])`; the kitchen read-clause (rules:351-353) permits only `['confirmed','preparing']` → **denied for kitchen-role users** (owner/manager unaffected). Main board (`kitchen_dashboard.dart:141`, `['confirmed','preparing']`) is provable ✓.

**Conditional (owner-only in practice):** admin_data_service.dart:37-42/69-74/108-113 (no branchId), analytics_provider.dart:30-40, revenue/top charts :26-34/:24-32 — provable ONLY for owner (manager clause needs branchId; customers denied). VERIFY UI role-gating: if managers reach these screens → runtime denial (P2).

**PASS (provable):** order_repository.dart:31-37 (customerId==uid ↔ :358-359); admin_reservations_tab.dart:21-32 (startTime single-field); waitlist_repository.dart:102-120; merged_menu_provider.dart:43-58/120-141; home_service.dart:69-73/102-105; admin_data_service.dart:216-221 (branchId+status whereIn ↔ staff clauses); fraud_screening_service.dart:28-33; gdpr_service.dart + data_export_service.dart self-keyed queries; admin_access_service.dart:119-124 (staff-only; customer → fail-secure).

## R7. GDPR erasure chain — server-side citation (spec §1.7; cross 06 P0-2)

`collectUserDocs` (index.ts:195-234): orders(customerId), reservations(userId), reservation_locks, waitlist, promo_usage, notifications+items, carts, presence, loyalty, driverLocations, users LAST. `ERASE_CHUNK_SIZE=400` :180 (under the 500-write cap ✓). `deleteUserData` requires `request.auth`, erases self only; `deleteUserDataRetry` ('0 * * * *', :383) completes `in_progress` markers ≥1h (gdpr test T6 ✓; retrier `retryIncompleteErasures` is exported for the callable + scheduler to share).
**Still missed (CONFIRMED present):** `deliveries` (created by driver flow, driver_location_service.dart:99), `analyticsEvents` (telemetry_service.dart:28), and **Storage objects** (`proof_of_delivery/{orderId}/…` order-attached PII photos — no delete anywhere in repo) → cross-cites 06 P0-2 with exact server-side lines. `deletion_requests` marker + `audit_log` retention are intentional (audit-proof) — legal basis must be documented.

## R8. Index × query matrix (spec §1.8) — firestore.indexes.json: 16 composite indexes

| Index (json lines) | Query it serves (client call sites) | Verdict |
|---|---|---|
| orders: (branchId, status, createdAt ASC) :3-10 | kitchen_service.dart:27-32 (whereIn statuses) · admin_data_service.dart:216-221 (whereIn + limit(1)) | ✓ USED |
| orders: (branchId, status, createdAt DESC) :12-19 | manager order streams descending variant | ✓ kept (no current client caller — P3 verify) |
| orders: (branchId, assignedDriverId, createdAt ASC) :21-28 | dispatch/driver-assignment views | no client caller found → P3 VERIFY (console/server) |
| orders: (branchId, assignedDriverId, createdAt DESC) :30-37 | same | no client caller found → P3 VERIFY |
| orders: (branchId, customerId, createdAt DESC) :39-46 | per-branch customer history | no client caller found → P3 VERIFY |
| orders: (customerId, createdAt DESC) :48-54 | order_repository.dart:31-37 (`getUserOrders`) | ✓ USED |
| orders: (customerId, createdAt ASC) :56-62 | fraud_screening_service.dart:28-33 (range query, direction-agnostic) | ✓ USED |
| orders: (assignedDriverId, status, createdAt ASC) :64-71 | delivery_service.dart:29-37 (`myOrders`) — **query is rules-denied (R6 FAIL-1) even though the index exists** | index ✓ / runtime ✗ |
| presence: (branchId, isOnline, lastSeen DESC) :73-80 | **no client query found** (presence read via doc get) | P3 dead-or-server (VERIFY) |
| menus: (branchId, isAvailable) :82-88 | admin menu list (admin screens) | ✓ plausible (no lib caller — VERIFY) |
| menus: (branchId, tags CONTAINS, isAvailable) :90-97 | tag-filtered menu browse | no client caller found → P3 VERIFY |
| menus: (branchId, createdAt ASC) :99-105 | menu editor ordering | no client caller found → P3 VERIFY |
| reservations: (branchId, startTime ASC) :107-113 | branch day-view variants | no client caller in lib (admin tab uses single-field startTime) → P3 VERIFY |
| reservations: (userId, startTime DESC) :115-121 | "my reservations" history | no client caller found → P3 VERIFY |
| promotions: (isActive, priority DESC) :123-129 | home_service.dart:69-73 | ✓ USED |
| users: (email, role) :131-137 | admin_access_service.dart:119-124 | ✓ USED |
| carts: (updatedAt, recovered) :139-145 | CF recoverAbandonedCarts (index.ts:763+) | ✓ USED (Admin SDK queries also need composites) |
| waitlist: (branchId, createdAt) :147-153 | waitlist_repository.dart:102-120 branch filter (auto single-field suffices; composite for future sort) | ✓ harmless |

**MISSING INDEX (runtime failure):** `revenue_chart_widget.dart:26-34` and `top_items_chart_widget.dart:24-32` run `orders.where('status'=='delivered').where('createdAt' >= X)` — an equality + range across TWO fields requires composite **(orders: status ASC, createdAt ASC)**, which is **NOT in firestore.indexes.json** → `failed-precondition` at runtime on real data (works only until a second field makes the SDK demand the composite — this query already does). → **P1-FB-4**.
**Missing-index scan of every remaining query:** single-field equality/range/orderBy queries all served by automatic single-field indexes (analytics_provider.dart:33-39 ×2, admin_data_service.dart:37-42/69-74/108-113, admin_reservations_tab.dart:21-32, merged_menu_provider.dart:43-58/120-141, home_service.dart:102-105, waitlist_repository.dart:105, seed_admin.dart:15-19 (email whereIn → single-field auto)). No other gaps.

## R9. Storage rules (spec §1.9) — all 94 lines read

| Rule (storage.rules) | Client usage | Verdict |
|---|---|---|
| `/menus/{itemId}/{fileName}` :50-54 — read any authed; write/delete manager + 5MB + image | **no client write path in lib** (console/owner-side) | ✓ (future admin UI must use manager token) |
| `/promotions/{promoId}/{fileName}` :57-61 — **public read**; owner write/delete | hero banners (non-PII) | ✓ |
| `/proof_of_delivery/{orderId}/{fileName}` :65-71 — read manager; write `token.role=='delivery'` + 5MB + image | proof_of_delivery_service.dart:46-52 uploads `proof_of_delivery/$orderId/<ts>.jpg` + `image/jpeg` metadata | ✓ wired — **but** the `role` custom claim is set by `syncUserRoleClaims` (index.ts:878) and lands only after token refresh → driver uploads may fail right after role grant (P2 note) |
| `/avatars/{userId}/{fileName}` :75-79 | **no client usage anywhere in lib** | dead rule → P3 drift |
| `/branches/{branchId}/{fileName}` :83-87 — read authed; owner write | no client usage (console) | ✓ |
| catch-all deny :90-92 | — | ✓ explicit (firestore.rules has none — drift P3) |
| App Check (`request.token`) | not used in any storage rule | enforcement console-only → VERIFY IN CONSOLE |

## R10. Deploy, build & test hygiene (spec §1.10)

- `functions/package.json`: engines node 20 ✓; `firebase-admin ^12`, `firebase-functions ^5`, `stripe ^22.1.1`, `zod ^4.4.3` (caret ranges; `package-lock.json` committed ✓); `main: lib/index.js` ✓; predeploy `npm run build` (firebase.json:4) ✓.
- `tsconfig.json`: `strict: true` + `noImplicitReturns` + `noUnusedLocals` ✓; `npx tsc --noEmit` → **PASS (exit 0)**.
- **Lint: ABSENT** — `npm run lint` → `Missing script: "lint"`; no eslint config/devDeps → **P1-FB-7**.
- `functions/package.json` `test` = `build && node --test` → runs **zero test files** (tests live in `core_app/test/…`) → vacuously green; real suites: `test:rules` (92/92 PASS this session), `test/functions/gdpr_erasure_test.js`, `functions/scripts/money_emulator_check.js` (P2: wire real suites into a gate).
- **NO CI** (07 P0) → rules/functions/indexes deploy by hand. Deploy sequence for ops, from `core_app/`: `firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project resturants-8547d` (+ `firebase functions:secrets:set` for STRIPE_WEBHOOK_SECRET / STRIPE_SECRET_KEY on first setup) → **P1-FB-8 process gap**.
- Secrets scan (non-node_modules; `*.env*|secret|serviceAccount|key.json`): **zero hits** ✓ — Stripe secrets env-injected (index.ts:980, :990) ✓.
- Emulator config: firestore+auth on `0.0.0.0` (firebase.json:16,20) → P2 dev-only exposure (bind 127.0.0.1 unless LAN device testing required); `singleProjectMode: true` :32 ✓.
- **Console-side checklist (repo cannot prove — mark each VERIFY IN CONSOLE):**
  1. App Check **ENFORCED** (not merely registered) for Firestore + Storage + Functions; live ID token inspected for `app_id` / `firebase.app_check_token` claim presence BEFORE flipping `settings/featureFlags.strongAppCheck=true` (R3 caveat).
  2. IAM least-privilege (deploy SA vs runtime SA).
  3. Stripe: webhook endpoint registered (`payment_intent.succeeded` minimum; add `charge.refunded`, `charge.dispute.created`), secrets set.
  4. Budget alerts; Firestore PITR/scheduled exports.
  5. Auth providers = password + anonymous (rules branch on `sign_in_provider=='anonymous'`, rules:43-44).
  6. **Pub/Sub topic `firestore-security-alerts` wired to a Cloud Logging sink** (filter `protoPayload.status.code=7`). NOTHING in the repo publishes to it (grep: index.ts:902 only (the compiled lib/index.js build artifact is not tracked at HEAD)) → until the sink exists, `onFirestorePermissionDenied` + DDOS alerting is **dead plumbing** → **P1-FB-5** (spec §1.1 suspicion confirmed).
  7. Cloud Logging retention; `securityMetrics/ddosCounters` monitoring.
  8. `settings/ownerInfo`, `settings/panicSwitch`, `settings/taxRates` seeded console-side (client bootstrap impossible for non-owners; cross 01 P1-C).
  9. **Per-client project runbook executed per brand** (rules + indexes + functions + webhook + App Check apps + owner seeding) — the generator does none of it (P0-FB-1).

## R11. Known-strength verification (spec §1.11) — prove, don't assume

| Claimed strength | Verdict | Proof |
|---|---|---|
| App Check helpers active | **PARTIAL** | Defined rules:13-35 and wired in 6 blocks + all 8 callables; NOT wired in ~10 write surfaces (R3). Production claim presence unproven (R3 caveat). |
| Counter schema validators wired | ✓ | `isValidReservationCounter` :419-421 · `isValidWaitlistCounter` :533-535 (executed: T-series PASS) |
| restaurantConfig shape validator wired | ✓ | :259-267 write path + T-E3 PASS (negative-int DENY) |
| Location geometry validator wired | ✓ | :226-241 + T-E2 PASS |
| Owner-gated admin writes | ✓ | settings/branches/menus/promos/panicSwitch owner-only; T-P1..P4 + T-E3 |
| Anti-privilege-escalation on `users` | ✓ | self-role-change blocked :305-316; owner-demote protection :318-324; manager role-writes limited :307-316; branchId owner-only :326-334 |
| deny-all fallback | **DRIFT** | storage.rules:90-92 explicit ✓; firestore.rules relies on implicit default-deny (no explicit block; equivalent security, spec claim not literal) |
| Fail-closed money (tax/currency/promo) | ✓ | payment.ts:73-81 (currency allowlist), :171-186 (tax fail-closed), :297-306 (promo clamp); calculateTax unknown-state throw :81-86 |
| **BUT** fail-open item pricing | ✗ | P0-FB-2 — the subtotal (the largest money term) is client-supplied (payment.ts:192-210) |
| Panic switch wired into order creation | ✓ | :362 via `isOrdersAccepting()` :167-184; fail-OPEN default (T-P3) — documented; owner-only writes |

## R12. Findings register (server-side, this audit)

**P0**
- **P0-FB-1 — Generator provisions NO backend for generated client projects.** Per-tenant isolation is the project boundary (R2), but `apps/` ships no rules/indexes/functions/`.firebaserc`; `demo-tenant` is referenced with no deployable backend. After 08's empty-key fix, each brand boots on an unprovisioned project. (Cross-cuts 08; unique backend evidence here.)
- **P0-FB-2 — Client-priced charge CONFIRMED server-side.** `createPaymentIntent` charges `Σ items[].priceCents + selectedOptions[].upchargeCents` (payment.ts:192-210; index.ts:575-576) with NO cross-check against `menus` (no menus read exists in index.ts — verified over all 1115 lines); `createOrder` stores the client payload via Admin SDK merge (rules bypassed). verifyOrderCharge (payment.ts:417-443) checks only internal consistency. (Cross-cuts 06 P0-1/P0-2 — this audit supplies the definitive server-side citations.)

**P1**
- **P1-FB-1 — driver `myOrders` runtime-denied** (delivery_service.dart:29-37 vs rules:354-357 — missing branchId constraint; rules-not-filters).
- **P1-FB-2 — kitchen "ready" board runtime-denied** (kitchen_dashboard.dart:302 `['ready']` vs kitchen clause :351-353 `['confirmed','preparing']`).
- **P1-FB-3 — customer cancel is double-dead**: no `cancelOrder` export among the 17 (Dart calls it — order_repository.dart:59-63 region; master 01) AND rules :369-387 provide no customer update disjunct. Two independent fixes required.
- **P1-FB-4 — missing composite index (orders: status ASC, createdAt ASC)** → analytics charts `failed-precondition` on real data (R8).
- **P1-FB-5 — permission-denied/DDOS alerting dead plumbing** — no publisher/sink for `firestore-security-alerts` anywhere in repo (R10 checklist 6).
- **P1-FB-6 — fraud gate advisory + spoofable**: screenPaymentFraud (index.ts:101-126) trusts client `customerId`, is not consulted by createPaymentIntent/createOrder (cross 06 P1).
- **P1-FB-7 — no lint tooling** in functions (missing script, no eslint).
- **P1-FB-8 — no CI → hand-deploys** of 591-line security rules + 17 functions (cross 07 P0).
- **P1-FB-9 (VERIFY, high risk)** — App Check production claim presence (`app_id`, `firebase.app_check_token`) unproven; if absent, flipping STRICT (or even RELAXED for gated blocks) bricks all gated writes (R3). Harness simulates the claims (test/rules/firestore_rules_test.js:32-33) — that proves logic, not production claims.

**P2** — App Check gating inconsistent across write surfaces (R3); `dispatchToFleet` lacks an auth gate (staff action, App-Check only, index.ts:127-158); `createPaymentIntent` lacks auth binding (no user claim on intent, index.ts:556-576); demo-mode breaks (analyticsEvents rule missing → demo telemetry fails silently; demo GDPR batch-delete hits orders delete-deny + users delete-deny); webhook refund/dispute unhandled (cross 06); claim-propagation delay for driver storage uploads; emulator hosts 0.0.0.0; vacuous `functions` test script; manager-facing screens that query orders without branchId will deny for managers (loadOrders/analytics/charts — VERIFY UI gating).

**P3** — promoCodes over-exposed read (:455-458) though client never reads it; dead/drift rules (`archived_users` :515) + dead storage rule (avatars) + speculative indexes (R8); no explicit deny-all in firestore.rules; `calculateTax`/`logFunnelEvent` no auth (by-design-ish, App-Check-gated); seed_admin client-side bootstrap paradox (needs owner token while ownerInfo unprovisioned — cross 01); spec line-count drift (591 vs 535; 1115 vs 1001; storage 94 vs 80); `admin_access_service.dart:82` audit_log client add always denied (dead path).

## R13. Executed commands (read-only, permitted by spec §2)

| Command | Result |
|---|---|
| `npm run test:rules` (emulator, from core_app) | **92/92 PASS, exit 0** — T1-T37, T-D1..12, T-E0..4, T-P1..4 all green |
| `npx tsc --noEmit` (functions) | exit 0, no errors |
| `npm --prefix functions run lint` | `Missing script: "lint"` |
| lib↔src export spot-diff | 17/17 names identical + internal helpers exported |
| Repo-wide greps | callables (8 names), collection paths, where-sites, storage refs, `firestore-security-alerts` (2 hits, both the function itself), rules clientId (none) |
| Secrets scan (functions/, non-node_modules) | zero hits |

## R14. Rules-test plan (extend the EXISTING harness — no new framework)

The 1225-line harness (`test/rules/firestore_rules_test.js`, run via `test:rules`) already covers 58 scenario groups. ADD these cases, each tied to a finding:
1. **P1-FB-1**: delivery-role context (branchId claim set) running the EXACT `myOrders` query shape (assignedDriverId+whereIn status, NO branchId) → assert DENY today; after the chosen fix, ALLOW. Add the branchId-filtered variant → ALLOW.
2. **P1-FB-2**: kitchen context `streamOrders(branchId, ['ready'])` shape → DENY today; document intended outcome (either extend kitchen clause with 'ready' or keep + change dashboard).
3. **P1-FB-3**: customer update `pending→cancelled` → currently DENY (no customer update disjunct); add the intended-rule case (TDD-first per Law 2).
4. **P0-FB-1 guard**: once per-project provisioning exists, add a smoke test asserting deployed rules hash per project (console/CI-side).
5. **Regression guard for P0-FB-2 fix**: rules can't test the callable — add a money_emulator_check scenario that createOrder REJECTS an order whose line prices differ from seeded `menus` docs (runs in the existing money emulator harness).
6. Keep 92 existing assertions green as the regression net (CI gate once 07's CI P0 is fixed).

## R15. Verdict + self-check

**VERDICT: ❌ FAIL** — 2×P0 (P0-FB-1 backend provisioning gap per generated tenant; P0-FB-2 client-priced charge) + 9×P1 + P2/P3. Backend strengths are real (rules suite green 92/92, strict money for tax/discount/currency/promo, strong anti-escalation users rules, immutable audit) but the P0s are stop-ship.

Self-check (spec §3): all 591 rules lines read ✓ · all 17 functions in matrix ✓ · every Dart collection path mapped or flagged ✓ · tenant verdict stated with evidence for both models ✓ · client-supplied-price answered with citations (payment.ts:192-210, index.ts:575-576, no menus read) ✓ · zero console claims presented as proven (all VERIFY IN CONSOLE) ✓ · zero library additions recommended ✓ · **END OF AUDIT 09 REPORT**