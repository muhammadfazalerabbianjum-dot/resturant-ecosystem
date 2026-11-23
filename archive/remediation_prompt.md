# CARNAMA REMEDIATION PROMPT (potato6-spec -> potato7-verify)

**Purpose:** A single self-contained remediation prompt that turns `verification_report.md`
(`NOT-GO`) into a done-and-**proven** production app, without breaking anything. You will
NOT rubber-stamp a verdict. You will (1) first author **`potato6.md`** — a minimal,
batch-mapped, rollback-safe SOLUTIONS SPEC (the potato4 discipline); then (2) implement
**one controlled batch at a time**; then (3) append a per-batch VERIFICATION REPORT to
**`potato7.md`** (potato5.md format). You finish ONLY when every open issue is Closed with
`file:line` + a green behavior-asserting test / emulator result on YOUR run.

**Source of truth:** the codebase. `verification_report.md` and every potato*.md are
UNTRUSTED until you read the actual source and cite `file:line`. Errors in the report are
corrected with evidence, never silently adopted.

---

## 0. GLOBAL RULES (non-negotiable; violating any = batch failure)

1. **Truth-telling over every ledger.** A fix is real only when the code AND a
   behavior-asserting test prove it. Never mark a batch verified from this doc or the
   report.
2. **One command per tool call.** NEVER chain with `&&` / `;` / `|`. Commands must run in
   BOTH `cmd.exe` and PowerShell. Grep with `findstr` / `Select-String`. No `$()`.
   No interactive pagers; `firebase emulators:exec` only with a bounded, non-interactive
   command.
3. **Best, safest, production-grade only.** No shortcuts, no stubs, no placeholders, no
   tautological/skipped tests, no `catch (_)` that swallows silently, no fake success,
   no dead code kept, no hardcoding that pretends to be config.
4. **Cite `file:line`.** Every finding and every proof cites exact current source. A
   symbol is "dead" only if it appears nowhere but its own definition.
5. **Money, auth, GDPR, security FAIL-CLOSED.** On any doubt: throw/log + clean error.
   Never silently succeed or fake a result.
6. **Never break anything (the Prime Care rule).** Every batch =
   (a) READ every file you will touch first; (b) make the **minimal** change;
   (c) run `flutter analyze --fatal-infos` for every touched package/app + `dart analyze`
   + `tsc --noEmit` + the FULL affected test suite + the relevant emulator run;
   (d) ALL GREEN before advancing. If you change any public signature/contract, prove
   every caller still compiles. Define the **rollback** (safe, known-good path) for every
   change BEFORE you make it.
7. **Zero-skip gate.** After your work in a batch:
   `findstr /S /N "skip:\|@Skip\|markTestSkipped"` in every touched test file -> 0 matches,
   OR you have replaced each skipped test with a real, running test and said so.
8. **Append-only verification.** Each batch appends exactly ONE VERIFICATION addendum to
   `potato7.md` (same six sections potato3 used: VERIFIED FIXES / SUPPRESSION /
   UNVERIFIED-MISSING / INDUSTRY-GRADE / RUTHLESS-TEST / CLEAN + the commands run).
   Do not edit prior addenda.
---

## 0b. THE VERIFICATION RULES WE QUOTE (from potato2/potato4 — apply verbatim)

These are the exact definitions that make a "fix" real. Quote them in every potato7.md
addendum under the relevant section, not just reference them.

### R-1 TDD / Ruthless-Test gate (potato2 §6.1–§6.3, GO/NO-GO for publication)
- For every target, report **current coverage** (read `coverage/lcov.info`: is the path
  hit?), **why it's critical** (money, auth, GDPR, sync, atomicity, security), and **the
  hard test required** (what behavior it must assert).
- **No placeholder tests.** A test asserting a constant or "widget exists" does NOT satisfy
  the gate. It must assert a real outcome: exact money in integer cents, atomicity
  (exactly-one-wins), erasure completeness, idempotency (no double charge).
- A target with **< 100% of its critical branches covered** is a **finding** — report it,
  do not hide it.
- The ruthless-test targets (map your batch to these): **T1** checkout money math all
  combos; **T2** order idempotency; **T3** reservation atomicity; **T4** cart
  modifier-variant dedupe/remove; **T5** GDPR erasure completeness; **T6** sync queue
  integrity (enqueue→process→DLQ, no duplicate writes, clearAll purges all 4 on sign-out);
  **T7** auth sign-out cleanup (cross-user leak); **T8** admin role transitions;
  **T9** driver assign-to-me transaction (exactly one succeeds); **T10** deep-link
  resolution; **T11** Stripe empty-key fail-closed (never fake "Paid"); **T12** kitchen
  status transitions + `hasOnly(['status'])`; **T13** modifier pricing
  `(priceCents+upcharges)*qty`; **T14** promo validation (invalid/expired/over-limit
  rejected, clamped); **T15** GDPR two-phase deletion (durable marker first, atomic batch,
  auth delete leaves `in_progress` for retry).

### 0-2 Suppression hunt (potato2 §1.1–1.2) — every file, even when suites are green
- **Test suppressions:** `skip:true`/`@Skip`/`markTestSkipped` (never runs);
  **tautological test** (seeds the same wrong field/value as the bug, so the bug looks
  "verified"); **weak test** (only renders, never taps/enters/asserts — a broken
  `_signIn`/`_submit` would pass); **simulated wrapper** (tests a fake method
  `executeSyncWrapper`, not the real `_syncUserProfile`); `pumpAndSettle`-timeout
  "fixed" by removing the assertion; **test mocks the thing it tests**; **placeholder**.
- **Analyzer suppressions:** `// ignore:` / `// ignore_for_file:`; disabled lints /
  excluded `lib/` paths in `analysis_options.yaml`; `@visibleForTesting` on production
  code; `// ignore: avoid_print` on debug prints.
- **Error/first-level:** `catch (_)`  that swallows silently, `catch (e)` with no log,
  silent `return []`/`null` (can't tell "no data" from "failed"),
  `Future.delayed` fake loading (a stub as init).

### 0-3 Flow / wiring rules (potato2 §7 methodology + §part)
- **READ the actual file** — never trust the ledger. **HUNT suppression** patterns.
  **CITE file:line** for every finding (a build is "dead" only if it appears nowhere but
  its own definition).
- **TRACE the full path**: Screen → Provider → Repository → Firestore collection → Rules →
  (Cloud Function) → back to UI; verify happy + error/empty/loading/offline.
- **Wiring completeness**: provider consumed by a real read/write, repository injected,
  route 1:1 with widget. A provider that only references itself is dead.

### 0.4 Truth-telling / fail-closed (potato2 Methodology + potato4 §0.5-6)
- If a claimed fix is NOT in code, or present but broken/suppressed, that is a **finding** —
  report it; never assume the ledger is right.
- **Money, auth, GDPR, security FAIL-CLOSED**: throw/log + clean error, never silently
  succeed or fake a result.

### 0.5 No AI slop / best only (potato4 §0.1–0.5)
- One command per tool call; never chain `&&`/`;`/`|`; both cmd+PowerShell; grep with
  `findstr` / `Select-String`; no `$()`; no interactive pagers.
- No placeholders, no stubs, no dead code kept, no hardcoding that pretends to be config,
  no `// TODO_DEPLOY:` faking success.
- Report as you go — append each batch to `potato7.md` BEFORE starting the next; if a
  command fails/hangs, **stop and report**, never retry the same broken command blindly.
- Keep batches small; split a too-large batch into sub-batches.

---
---

## 1. STEP 0 — GROUND THE TRUTH, THEN WRITE potato6.md (no production change yet)

1. Read `verification_report.md` top to bottom. It contains (second pass) these issues
   you must CLOSE — re-verify each by reading the cited `file:line`:

   **P0 release-blockers (7):**
   - **2.1** `reservation_counters` + `waitlist_counters` have NO `firestore.rules`
     `match` -> transactional writes in `reservations_repository.dart:18-22,45-55` and
     `waitlist_repository.dart:49-52,80-87` are permission-denied -> booking & waitlist
     broken in production (deny-by-default).
   - **2.2** no REAL emulator rules suite — `firestore_emulator_rules_test.dart` is a mock
     and `firestore_rules_test.dart` uses fake_cloud_firestore (L6-8) which does NOT
     execute real rules.
   - **2.3** GDPR erasure emulator integration is RED (exit 1): `PASSED 19 FAILED 2` —
     `T4` (user docs STILL erased before the durable-marker/auth-failure) and `T5`
     (locks+waitlist also erased); root cause `testEnv.clearFirestore()` not clearing the
     admin-client namespace (harness).
   - **6.1** money-integrity: `createPaymentIntent` (index.ts:413-423) trusts client
     `tax`/`discount`; `calculateTax` is display-only; promo validated only client-side
     (`promo_code_service.dart:21`). A hostile client can send `tax 0` or huge discount.
   - **6.2** `locations` collection has NO rules `match` but is read by feature code
     (`location_repository.dart:26-31`).
   - **8.7** `settings/restaurantConfig` + `defaultOperatingHours` are written by feature
     code (`restaurant_config_service.dart:16-28`, `operating_hours_screen.dart:33`) but
     the `settings` rule only allows `featureFlags`.
   - **8.9** panic switch NOT enforced at the DB layer: `panic_switch_service.dart:11-14`
     claims a rule blocks order-writes, but the `orders` `create` rule
     (firestore.rules:201-207) never reads `ordersAccepting`. P0-class product-safety gap.

   **Major (4):**
   - **2.4** 8 skipped tests: `checkout_e2e_test.dart:2,17` + `reservation_e2e_test.dart:2,16`.
   - **2.5** direct `FirebaseFirestore.instance` X3 in `restaurant_config_service.dart:8,17,25`.
   - **2.6** literal `currency: 'usd'` (`functions/src/index.ts:441`) — blocks multi-currency.
   - **6.3** (Major-demo) `notifications` / `notification_queue` / `audit_logs` in demo
     paths (`cloud_function_mocks.dart:169,187,195,248`) with no rules `match`.

   **Minor (3):**
   - **2.7** three `// ignore: invalid_annotation_target` in hand-written models
     (`order_model.dart:44`, `user_model.dart:29`, `presence_model.dart:15`).
   - **6.4** dead `OrderRepository.submitOrderAtomically` (order_repository.dart:86,117);
     payload diverges from `createOrder`.
   - **6.6** (informational) inline `LoggerService()` in bootstrap/DI-defaults.

2. For each, READ the code and CONFIRM or CORRECT. Keep the corrections list.
3. Write **`potato6.md` — the remediation solutions spec**, structured exactly like
   potato4.md: one section per batch (B-R1…), each with (a) confirmed `file:line`
   evidence, (b) the minimal, safest solution with the exact first change, (c) the precise
   NEW test / rules-test / emulator-test and exact assertion, (d) the rollback / undo,
   (e) the proof gates, (f) the "deliberately NOT changed" scope, (g) the honest boundary.
   Present the completed `potato6.md` and STOP. **Do not implement until the reader
   confirms the spec.**
---

## 2. THE BATCHES (implement in this order; each gets a potato7.md addendum)

### B-R1 [P0 #2.1] — Add Firestore rules for `reservation_counters` + `waitlist_counters`
**Rules to apply:** R-0.3 (flow trace: repository transaction → rules), R-0.5 (minimal change, read before edit), R-0.1 T3 (reservation atomicity).
**Evidence (verified in source this pass):** `reservations_repository.dart:18-22,51-55`
writes `reservation_counters/{branchId}_{startTimeMs}` via `transaction.set(counterRef,
{'booked': booked + partySize}, SetOptions(merge:true))` — the counter doc stores ONLY
`booked` (branchId+startTime live in the DOC ID, not as fields). `waitlist_repository.dart:52,80-87`
writes `waitlist_counters/{branchId}` = `{'count': joinOrder, 'updatedAt': serverTimestamp()}`
(count increments by exactly 1 per join). There is NO `match /reservation_counters` or
`match /waitlist_counters` in `firestore.rules` -> deny-by-default -> every booking and
waitlist join FAILS in production.

**Minimal, safe solution (append to `firestore.rules`)** — use the EXACT stored keys:
```
match /reservation_counters/{doc} {
  allow read: if isAuthenticated() && !isAnonymous();
  // First booking CREATES the doc (merge-set) as {'booked': partySize}.
  allow create: if isAuthenticated() && !isAnonymous()
    && request.resource.data.keys().hasOnly(['booked']);
  // Only non-decreasing increments, bounded by a sane max party size.
  allow update: if isAuthenticated() && !isAnonymous()
    && request.resource.data.keys().hasOnly(['booked'])
    && resource.data.keys().hasOnly(['booked'])
    && request.resource.data.booked is int
    && resource.data.booked is int
    && request.resource.data.booked >= resource.data.booked
    && request.resource.data.booked - resource.data.booked <= 50;
}
match /waitlist_counters/{branchId} {
  allow read: if isAuthenticated() && !isAnonymous();
  allow create: if isAuthenticated() && !isAnonymous()
    && request.resource.data.keys().hasOnly(['count','updatedAt']);
  allow update: if isAuthenticated() && !isAnonymous()
    && request.resource.data.keys().hasOnly(['count','updatedAt'])
    && resource.data.keys().hasOnly(['count','updatedAt'])
    && request.resource.data.count is int
    && resource.data.count is int
    && request.resource.data.count - resource.data.count <= 1;
}
```
- **CRITICAL (do not break):** the `hasOnly` sets above are the ACTUAL stored keys. Do NOT
  demand `branchId`/`startTime`/`joinOrder` as fields — they are NOT on these docs (they are
  in the doc ID / entry doc), so adding them would DENY every legitimate create/update and
  break booking & waitlist.
- **Do NOT change the Dart transaction logic.** Only add the rules; prove with the real
  emulator (B-R2) that a genuine two-request `requestSlot` and a `joinWaitlist` are ALLOWED
  and a reset/negative/tamper is DENIED.
- **Rollback:** revert the two `match` blocks (prior state was deny-by-default; reverted =
  booking returns to its currently-broken state, which is the status quo — document it).
- **Test (added in B-R2 suite):** legitimate increment ALLOW; `booked` reset / negative /
  >50 jump DENIED; waitlist count >1 jump DENIED; first-create ALLOWED.

### B-R2 [P0 #2.2] — A REAL Firestore-rules emulator suite
**Rules to apply:** R-0.2 (suppression: fake/mock rules tests are tautological — replace with real behavior), R-0.4 (truth-telling: prove with a real emulator run, not a mock).
Replace the mock/fake-only "rules" tests with a real run that loads `firestore.rules`:
- `firebase emulators:exec --only firestore --project demo-carnama` around a `rules.test.js`
  that initializes the **admin SDK against the emulator** and asserts, under real rules:
  counters legitimate-increment ALLOW (per B-R1 rule), tamper/reset DENY; own-list
  GDPR queries (reservations / reservation_locks / waitlist / promo_usage by `userId`)
  succeed for owner and deny for non-owner; `locations` public read (B-R5) works;
  `settings/restaurantConfig` read/write by role (B-R6); orders `create` blocked when
  `ordersAccepting=false` (B-R7). The suite must pass (exit 0) on THIS run.
- Keep the existing unit rules tests (ownership helpers) as fast unit coverage; they do
  NOT replace the emulator suite.

### B-R3 [P0 #2.3] — GDPR erasure emulator: make T4/T5 GREEN
**Rules to apply:** R-0.1 T5 + T15 (erasure completeness + two-phase marker), R-0.4 (fail-closed), R-0.2 (do not weaken the assertion — fix the harness).
The field claims `PASSED 19 FAILED 2` and the root cause is a harness leak:
`testEnv.clearFirestore()` clears the client namespace but not the admin-client namespace.
Fix the HARNESS so the two failing assertions genuinely hold:
- Give each test a fully isolated dataset (per-test keys/rows) or a separately initialized
  admin client that is re-created to the same emulator before and after
  `clearFirestore()`, so no test can observe another test's residue.
- Preserve the real semantics T4/T5 assert:
  - T4: marker (`deletion_requests/{uid}`) is written `in_progress` BEFORE the first
    user-scoped doc is deleted; when auth-deletion fails, docs MUST NOT be half-wiped into
     a completed state, and the marker remains `in_progress` for the retrier.
  - T5: `reservation_locks` + waitlist are erased exactly when the erasure completes.
- Run full `gdpr_erasure_test.js` -> exit 0. Add a T4/T5 note that says these specifically
  went from FAILED -> PASSED and why.

### B-R4 [P0 #6.1] — Money integrity: server-authoritative tax & discount
**Rules to apply:** R-0.1 T1 + T2 + T14 (money math, idempotency, promo validation), R-0.4 (money fail-closed).
**Verified this pass (index.ts):** `createPaymentIntent` already re-derives
`itemsSubtotalCents` from flat line items, clamps `tax`/`discount` to non-negative via
`Math.max(0, ...)` (index.ts:417-418), and REJECTS `discount > itemsSubtotalCents`
(index.ts:421-423). The GENUINE remaining gaps are: (a) **tax is client-supplied**
(`taxCents` from `request.data:382,387,417`) — a hostile client can set `tax:0` and
underpay tax; (b) **the promo is never validated server-side** — the discount is echoed
from the client (`promo_code_service.dart:21` validates only on the client). Fix BOTH on
the server; keep the existing subtotal-derivation + clamp + reject (already present):
1. Server computes `tax` authoritatively from the SAME tax source `calculateTax` uses —
   `settings/taxRates` per `clientId`+`stateCode` (index.ts:39-73, already fail-closed on
   unknown state). Add a server-side `computeTax(subtotalCents, stateCode, clientId)` and
   use its result; ignore any client-sent `taxCents` beyond an advisory display value.
2. Server validates the promo **server-side** before honoring any `discountCents`: read
   `promoCodes/{code}` (active, within window, branch-scoped) + `promo_usage/{uid}` (not
   over limit) and compute the discount in server cents from that code — never echo a
   client-supplied discount. Keep `discount <= itemsSubtotalCents` and `total >= 0`.
3. Keep the existing `createOrder` money-equality check (index.ts:506-516) so the charge
   matches the recomputed total (subtotal + serverTax - serverDiscount + tip + delivery).
- **Client freeze:** `checkout_service.dart:286-294` + `promo_code_service.dart:21` stop
  authorizing; they send only identifiers (code, stateCode) for display/summary; the server
  is the source of truth.
- **Do NOT regress:** keep the existing `Math.max(0,...)` clamps and the
  `discount > subtotal` rejection (they are already correct — re-verify, don't remove).
- **Test (functions unit + emulator):** client sends `tax:0` -> server applies the real
  rate, not 0; client sends an invalid/expired/over-limit code -> server REJECTS and the
  intent is not charged; a huge client discount -> clamped/re-computed to the server
  value; `total >= 0` always.
### B-R5 [P0 #6.2] — `locations` collection rules
**Rules to apply:** R-0.3 (flow trace: repository read → rules), R-0.5 (do not over-constrain; read the model before locking shapes).
**Verified this pass:** `location_repository.dart:26-31` reads `locations` (limit 50);
`LocationModel.fromDoc` (location_model.dart:33-60) requires `name`/`openHours` (fallback
"—"), reads `address`, and resolves coordinates via `LatLngParse.fromMap` which accepts
ALL real shapes — `geo.geopoint`, `coordinates` (GeoPoint | [lng,lat] | {latitude,
longitude}), OR top-level `lat`/`lng`. `branch_service.dart` (packages/core) uses the
`geo.geopoint` shape. No `match /locations` -> deny-by-default -> Locations + map pins
broken.
**Minimal, safe solution:** add a read rule (any authenticated user — it is a customer
feature) and a staff-only WRITE. **Do NOT use a rigid `hasOnly` on the coordinate
representation** — the docs legally store `geo.geopoint` OR `coordinates` OR `lat`/`lng`,
so a `hasOnly(['lat','lng',...])` would DENY the legitimate `geo.geopoint` rows and break
branch_service. Instead require the owner/manager role + the non-coordinate invariants:
```
match /locations/{doc} {
  allow read: if isAuthenticated() && !isAnonymous();
  allow create, update: if isAuthenticated() && !isAnonymous()
    && userRole() in ['owner','manager']
    && request.resource.data.name is string
    && (request.resource.data.keys().hasAny(['geo','coordinates','lat'])
        || request.resource.data.keys().hasAny(['lat','lng']));
  allow delete: if isAuthenticated() && !isAnonymous()
    && userRole() in ['owner','manager'];
}
```
Keep the invariant loose-enough for both storage styles but role-locked (writes are
staff-only; the UI is read-only). Test (B-R2 suite): customer read ALLOW; customer write
DENIED; owner/manager write with `geo.geopoint` shape ALLOWED and with top-level `lat`/`lng`
ALLOWED.

### B-R6 [P0 #8.7] — `settings/restaurantConfig` read/write
**Rules to apply:** R-0.3 (trace the config read/write path), R-0.5 (do not hand-type a `hasOnly` of guessed fields).
**Verified this pass:** `core_app/lib/app/config/restaurant_config_service.dart:7-28`
reads a `settings/restaurantConfig` stream and writes it via `saveRestaurantConfig` /
`patchRestaurantConfig` (`.set(map, SetOptions(merge:true))`). The model
(`restaurant_config_model.dart`) fields include `currency`, `operatingHours`,
`socialLinks`, plus the rest written by `toFirestore()` (read it for the EXACT key set).
Per the report, the current `settings` rule allows only `featureFlags` -> the config UI and
the panic reopen are denied. Fix the `settings/{doc}` rule to scope by ROLE and doc-type,
NOT to guess a rigid key list:
```
allow read: if isAuthenticated() && !isAnonymous();
allow create, update: if isAuthenticated() && !isAnonymous()
  && userRole() in ['owner','manager']
  && (doc == 'restaurantConfig' || doc == 'featureFlags' || doc == 'taxRates');
allow delete: if false;
```
- **Do NOT use a hand-typed `hasOnly` of guessed fields** — the config map is rich and
  `merge`-written; an incomplete `hasOnly` would DENY legitimate saves. If a shape-lock is
  wanted, derive `hasOnly` from the EXACT `RestaurantConfigModel.toFirestore()` key set
  (read the model first), and re-verify against `patchRestaurantConfig` call sites.
- **Operating hours:** verify where `operating_hours_screen.dart` writes — if it targets
  `branches/{id}` (per potato3 B5) that is covered by the branch rule; if it targets
  `settings`, include that doc id above. Read the screen before finalizing the rule.
- Panic reopen (`ordersAccepting` on `restaurantConfig`) must succeed for owner/manager so
  the B-R7 gate can be flipped back on.
- Test (B-R2 suite): owner/manager update to `settings/restaurantConfig` ALLOW; customer
  write DENIED; delete DENIED.

### B-R7 [P0 #8.9] — Panic switch enforced at the DB layer (orders-create gate)
**Rules to apply:** R-0.4 (fail-closed), R-0.3 (trace the real order-create path before gating), R-0.5 (a missing config must not block all orders).
`panic_switch_service.dart:11-14` claims "the Firestore security rule blocks all new
order writes (fail at the database layer)" but `orders` `create` (firestore.rules:201-207)
never reads `ordersAccepting`. Make the DB the enforcement layer, minimally:
```
function ordersAccepting() {
  // Fail-safe: only BLOCK when the switch is explicitly `false`. A missing
  // settings/restaurantConfig doc must NOT silently behave as "closed" and block
  // every order (that would be a self-inflicted outage). `!= false` -> null/absent = open.
  return get(/databases/$(database)/documents/settings/restaurantConfig)
            .data.ordersAccepting != false;
}
```
and add `&& ordersAccepting()` to the `orders` `allow create` rule. **Verify which path is
the real client order-create path**: if the app creates orders via the `createOrder`
callable (server-authoritative, bypasses rules — verify in index.ts:463-552), then this
rule guards any DIRECT client `orders` write; ALSO make `createOrder` itself read
`ordersAccepting` and reject when false, so the panic switch is enforced server-side with
no DB-rule bypass. Match the exact `ordersAccepting` default (confirm the model default is
`true`/open at restaurant_config_model.dart) so an unseeded config defaults to OPEN — do
not block all orders by accident.
- **Cost note:** the `get()` per order-create is one document read per write — acceptable,
  but confirm the `settings/restaurantConfig` read is cached/cheap and doesn't blow the
  per-write rule budget.
- Test (B-R2 suite): `ordersAccepting=false` -> a customer DIRECT `orders` create is
  DENIED; `createOrder` callable also returns a clean rejection; `true`/missing -> create
  allowed; reopen via owner Config save works (B-R6).
### B-R8 [Major #2.4] — unskip / replace the 8 `@Skip` e2e tests
**Rules to apply:** R-0.2 (skip is a suppression) + R-0.1 (behavior-asserting, no placeholders).
`checkout_e2e_test.dart:2,17` and `reservation_e2e_test.dart:2,16` are `@Skip`-ed; the
suite reports ~8 skipped. Make them run headless OR delete them and give real coverage:
- Preferred: rewrite as emulator-backed integration tests (real Firestore emulator via
  `firebase emulators:exec`, real rules, real assertions) so they genuinely exercise the
  checkout money path and the reservation atomic path (no double-booking). If emulator
  dependence is unavoidable in CI, run them under `firebase emulators:exec` explicitly.
- Fallback: delete the two files if truly non-headless and replace each with a real
  unit/widget test that hits the production repository/calculator (B0/B2/B4 already fixed
  those paths) — so the money/booking behavior is not lost.
- Gate: `findstr /S /N "skip:\|@Skip\|markTestSkipped"` in the touched suite -> 0.

### B-R9 [Major #2.5] — DI: replace direct `FirebaseFirestore.instance` X3
**Rules to apply:** R-0.3 (wiring: provider consumed, no DI bypass), R-0.5 (reuse the real provider, minimal change).
**Verified this pass:** `core_app/lib/app/config/restaurant_config_service.dart:8,17,25`
use `FirebaseFirestore.instance` directly (line 8 = the read stream inside the existing
`restaurantConfigProvider`; 17/25 = `saveRestaurantConfig`/`patchRestaurantConfig` top-level
functions). These bypass the DI `firestoreProvider`. Fix minimally:
- Make the read stream use `ref.watch(firestoreProvider)` (it is already inside a Provider —
  `restaurantConfigProvider`, line 7).
- Convert the two write functions into a small service class (e.g.
  `RestaurantConfigWriter`) that takes `FirebaseFirestore` in the constructor, and expose it
  through a tiny Provider constructed with `ref.watch(firestoreProvider)` — same shape as
  every other feature. Update call sites (setup screens) to use the provider.
- Keep analyze + the DI-grep gate at 0 (`FirebaseFirestore.instance` in feature code).
- Rollback: keep the existing functions as thin delegates to the injected instance for one
  release, or revert to the exact prior file (documented).
- Test: existing config tests pass unchanged with an injected fake (no real Firestore); the
  stream provider resolves from `firestoreProvider`.

### B-R10 [Major #2.6] — currency config-driven, never literal `'usd'`
**Rules to apply:** R-0.5 (no hardcoding that pretends to be config), R-0.4 (fail-closed: missing currency must not silently default to usd).
`functions/src/index.ts:441` hardcodes `'usd'` in `createPaymentIntent` (Stripe).
Make currency a function of clientId/env/config so a non-USD white-label client crosses:
- Read currency from the resolved client config / env (`CURRENCY`) / `clientId` mapping,
  with a fail-closed default if missing (do not silently pay in usd for the wrong tenant).
- Pass the resolved currency into the Stripe Amount object; assert it is a supported
  code from the allowed set.
- Test (functions): a config with `currency=AED` produces a Stripe payload in `aed`; a
  missing currency FAILS CLOSED (does not silently default to usd); `usd` is never a bare
  literal — grep `functions/src` for `'usd'` -> 0 (allow it only from config).

### B-R11 [Major #6.3] — demo `notifications` / `notification_queue` / `audit_logs` rules
**Rules to apply:** R-0.3 (trace the demo write path), R-0.5 (role-locked, shape-aware), R-0.1 (T5 if any holds user PII).
These are written in demo paths (`cloud_function_mocks.dart:169,187,195,248`) with no
`match`; a strict-rules gap. Since these are admin/system collections in the demonstration
mocks, decide and implement:
- If they must be writable by the cloud-function mock under emulator, add rules scoped to
  the admin/service only (owner/manager write, or `request.auth != null` restricted), with
  `hasOnly` shape-lock; and
- ensure the GDPR erasure set covers them if any could hold user PII (add
  `notifications/{uid}` already covered; verify `notification_queue`/`audit_logs` hold no
  user PII — if they might, they belong in `collectUserDocs` too appends nothing).
- Test: a demo-mock write succeeds under the new rule; a customer write is denied.
### B-R12 [Minor #2.7] — remove the 3 `// ignore: invalid_annotation_target`
**Rules to apply:** R-0.2 (analyzer suppression), R-0.5 (regenerate code, keep round-trip).
`order_model.dart:44`, `packages/core/.../user_model.dart:29`,
`packages/core/.../presence_model.dart:15`. Refactor the JSON codec from blind casts to
defensive `is`-typed getters so the ignore becomes unnecessary, then regenerate the
`.freezed.dart` / `.g.dart` (`dart run build_runner build`). Grep these three files for
`// ignore: invalid_annotation_target` -> 0. Test the round-trip still parses.

### B-R13 [Minor #6.4] — remove or align `submitOrderAtomically`
**Rules to apply:** R-0.4 (grep proves dead: no production caller), R-0.5 (never leave two divergent order-writing paths).
`OrderRepository.submitOrderAtomically` (order_repository.dart:86,117) is referenced only
by tests and its payload diverges from `createOrder` -> it is dead/misleading production
code. Decide: if NO production caller invokes it (grep `submitOrderAtomically` -> only its
definition + tests), DELETE it and its test; if a caller exists, align its payload to the
`createOrder` contract used in production. Do not leave two divergent order-writing paths.

### B-R14 [Minor #6.6] — thread injected loggers in bootstrap/DI (informational)
**Rules to apply:** R-0.2 (DI bypass), R-0.5 (no feature path constructs its own logger).
Batch-1/5 already eliminated inline `LoggerService()` in feature screens (grep 0 on
screens). This pass: tighten the two remaining inline uses (bootstrap/DI-defaults and the
package network layer) to receive injected loggers where cheap and safe; otherwise record
as accepted with a `// TODO_DEPLOY:`/rationale comment. Do not over-engineer; the gate is
that no feature path constructs its own logger.

### B-R15 — FINAL GATE (GO / NOT-GO)
**Rules to apply:** R-0.1 (every ruthless-test target mapped), R-0.2 (zero suppressions), R-0.4 (truth-telling verdict).
Re-run the entire verification_report evidence after B-R1…B-R14 on a clean run:
- [ ] All 7 P0s closed with green behavior + emulator results (rules suites pass; erasure
      T4/T5 green; money server-authoritative; locations + counters + settings rules allow
      the legitimate paths; DB layer enforces the panic switch).
- [ ] All 5 Majors closed (skips 0; DI firestore 0; currency config-driven; demo
      collections fit rules; demo write allowed / customer denied).
- [ ] All Minors closed (3 ignores 0; dead method gone; logger threading accepted or
      documented).
- [ ] Full monorepo: `flutter analyze --fatal-infos` every package/app; `dart analyze`;
      `tsc --noEmit`; ALL suites green incl. `firebase emulators:exec` rules + erasure;
      grep gates 0.
- [ ] Re-open the app flow smoke (delete-account -> full erasure marker `completed`;
      booking -> lock + capacity; waitlist -> position; checkout -> empty-key honest
      error; panic on -> orders blocked).
- [ ] **Ruthless-test map complete** — every batch's target is a REAL behavior-asserting test in the suite: T1/T2/T13/T14 (money) from B-R4; T3 (reservation atomicity) from B-R1; T4 (cart variants) verified green; T5/T15 (GDPR erasure + two-phase) from B-R3; T6 (sync integrity) + T7 (sign-out cleanup) verified green; T9 (driver transaction) and T11 (empty-key fail-closed) verified green; T10 (deep-link) and T12 (kitchen) verified green. Any target with <100% critical-branch coverage is a reported finding (R-0.1).
- Then write the final verdict in `potato7.md` B-R15 addendum: **GO — every P0/Major/Minor
  closed and proven on this run**, OR **NOT-GO** with the explicit remaining list + the
  exact failing command. Do not say GO unless every box above is green on YOUR run.

## 3. THE ONLY ACCEPTABLE FINAL OUTPUT
1. `potato6.md` — the full remediation solutions spec (B-R1…B-R15, minimal fixes, tests,
   rollback, gates, honest boundaries).
2. `potato7.md` — append-only verification ledger, one addendum per batch, each
   VERIFIED FIXES / SUPPRESSION / UNVERIFIED-MISSING / INDUSTRY / TEST TARGETS / CLEAN +
   the commands run with their exit codes.
3. The final Batch-15 verdict (GO or NOT-GO) with the evidence list above.

**Honesty boundary (mandatory in potato6 + potato7):** `apps/sunset_grill` and
`apps/blue_ocean` are ABSENT from the repo (verification_report.md §4). They cannot be
remediated or audited here; record them as a repo-level decision, never as "fixed". Also
record what is not provable from this repo (real-device App Check enrollment, real
hardware NFC, live third-party Stripe) under "NOT-PROVABLE", and do not claim them closed.
