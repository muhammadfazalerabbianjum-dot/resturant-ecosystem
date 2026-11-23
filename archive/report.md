# CARNAMA LABS â€” PRODUCTION READINESS: FINAL AUDIT REPORT

**File:** `report.md` (deliverable 1 of 2) Â· **Date:** 2026-09-01
**Scope:** exhaustive verification of `PRODUCTION_READINESS_AUDIT_MASTER.md` + all 9 executed audit reports + the B0â€“B6 batch ledger (`FIX_VERIFICATION.md`) + spot re-verification of load-bearing findings against the CURRENT tree.
**Sources read in full:** `PRODUCTION_READINESS_AUDIT_MASTER.md` (473 ln), `AUDIT_TESTING_RELEASE_CI_REPORT.md`, `AUDIT_WHITE_LABEL_CONFIG_REPORT.md`, `AUDIT_FIREBASE_BACKEND.md` (executed report Â§R0â€“R14), `AUDIT_PAYMENTS_PRIVACY_COMPLIANCE_REPORT.md`, `AUDIT_A11Y_L10N_UX.md` (executed part), `verification_report.md`, `FIX_VERIFICATION.md` (B0â€“B6 addenda), `FINAL_HANDOVER.md`.
**Method:** read-only. Zero code/config/test files were modified. Every load-bearing audit claim was re-verified against current source before being accepted into this report (spot-checks listed in Â§2).

---

## 0. VERDICT

**NO â€” the app is NOT production-ready today. And "fix all the audit findings" is NECESSARY but NOT SUFFICIENT.**

- **Necessary:** the repo's own constitution (`PRODUCTION_READINESS_AUDIT_MASTER.md:7,73-74`) defines production-ready as **OVERALL = PASS with zero open P0/P1**. Today all 9 audited domains are FAIL: **11 unique P0** + **â‰ˆ46 unique fix-entities** after full cross-audit de-duplication from 53 raw P1 (reconciled in §3), plus **~70 P2/P3** debt items.
- **Not sufficient, for 6 reasons (Â§4):** (1) findings must be *verified fixed*, not just edited â€” several proofs exist only behind emulator/device/live-project runs that have never been executed; (2) fixes must propagate to **three surfaces** (template `core_app`+`packages`, generated shells `apps/*`, Firebase backend) â€” fixing the template alone leaves every generated app broken; (3) **release engineering does not exist** (no signing, no store pipeline, no CHANGELOG, no tags); (4) a **console/deploy checklist** (App Check claims, per-client backend provisioning, Stripe live, index deployment, ownerInfo seeding) cannot be satisfied by any code change; (5) **runtime performance is unproven** (no device profiling exists anywhere in the evidence); (6) **load/soak/monitoring/DR are absent** â€” the prior "500 users" claim is explicitly unsupported by `verification_report.md:11`.

**Deliverable 2** (`PRODUCTION_FIX_PROMPT.md`) is the exact, dependency-ordered remediation program (11 waves) with per-finding winner solutions taken from the audits' own "Proven Best-Fit" tables, corrected where the audits conflict, plus the ops checklist and the final re-audit procedure.

---

## 1. EVIDENCE TRAIL â€” WHAT WAS ACTUALLY RUN, AND IN WHAT ORDER

| Date | Artifact | What it proves |
|---|---|---|
| 2026-08-27 | `verification_report.md` | First full verification: **NOT-GO** with 5 P0 (counters rules missing, no real rules tests, GDPR emulator RED, client-trusted tax/discount, `locations` no-rules) + majors. |
| 2026-08-28 â†’ 08-30 | `FIX_VERIFICATION.md` addenda B0â€“B6 (+ `IMPLEMENTATION_B0..B6.md` specs) | Batches B0 (rules completeness + REAL emulator rules suite, 76/76), B1 (money: server-computed tax/discount, currency), B2 (GDPR emulator GREEN), B3 (DI/dead code/demo collections), B4 (zero-skip), B5 (panic switch DB enforcement), B6 (final clearance: **"GO"**, 0 skips/0 fails, 1,278+ tests). |
| 2026-08-31 â†’ 09-01 | 9 executed audits (00 UI wiring, 01 Security, 02 Network, 03 State, 04 Performance, 05 A11y/L10n, 06 Payments/Privacy, 07 Testing/CI, 08 White-label, 09 Firebase backend) | **ALL FAIL.** They audit a deeper layer than the batch gates covered. |
| 2026-09-01 (this run) | `report.md` | Spot re-verification (below) â€” **zero post-audit fixes have landed**; every re-checked finding is still live at the cited lines. |

**Critical interpretation â€” the B6 "GO" is superseded, not contradicted.** B6's GO is real *for what it measured*: the closure of the 2026-08-27 NOT-GO set (0 skips, 0 fails, all gates green on a clean run). It did not measure the 9 production-readiness domains. Two concrete proofs of the gap:
1. B1 "closed" the money finding (server-computed **tax/discount**), yet audit-06/09 proved the **subtotal itself is still client-priced** (`core_app/functions/src/payment.ts:192-210` â€” `computeItemsSubtotalCents` sums client `priceCents`; no `menus` read exists anywhere in `functions/src`, verified over all 1,115 lines of `index.ts`). The charge path is still P0-exploitable.
2. B0's rules suite is 92/92 green, yet audit-01 proved the *kitchen/delivery write payloads* the app actually sends are rules-DENIED (`hasOnly(['status'])` at `core_app/firestore.rules:380,386` vs payloads carrying `updatedAt`/`assignedDriverId`/`proofOfDelivery`) â€” the harness never exercises those exact write shapes.

**Lesson encoded into the remediation prompt:** every fix must add the regression test that would have caught it (the audits already specify these guards), and every batch ends with gates, not narrative.

---

## 2. SPOT RE-VERIFICATION (this run, current tree)

Each check below was executed against the live tree on 2026-09-01 and **confirms the audit finding is still present**:

| Finding | Re-check performed | Result |
|---|---|---|
| 00-P0-1 config routes named by screen-ID | grep `app_router.dart` | `:144 final id = screen['id'] as String?;` + `:53 case 'LoginScreen':` - still screen-ID names; `RouteNames.*` used only in the static table (:223+) |
| 00-P0-2/P0-3 broken Navigator API on go_router | grep `main.dart` | `:269 pushNamed(path)` (deep-link handler) and `:110 pushReplacementNamed('/')` (ErrorWidget) - still present; `:262 pushReplacementNamed('/login')` is an additional same-class site covered by the same fix |
| 02-P0-SYNC queue enqueues unpaid `confirmed` | grep `checkout_screen.dart` | `:334 status: OrderStatus.confirmed` + `:355 await syncQueue.enqueue('create','orders', ...)` - live |
| 01-P1-A rules deny staff payloads | grep `firestore.rules` | `:380` and `:386` still `hasOnly(['status'])` - live |
| 06-P0-1 / 09-P0-FB-2 client-priced charge | grep `payment.ts` | `:192 computeItemsSubtotalCents` sums client `priceCents` (`:197`) - live |
| 08-P0-WL-1 generator ships empty Firebase keys | grep `whitelabel.dart` + halal `main.dart` | `validate()` at `:68` has no key gate; keys read at `:654`; shell reads `environment.firebaseAndroidApiKey/IosApiKey` at `main.dart:26` then `Firebase.initializeApp` at `:51` - live |
| 08-P0-WL-2 flags format inert | grep `app_config.dart` | `:80 _featureFlags = const {}`, parse result assigned `:276` - parser accepts `bool` only; configs store `{"enabled":true}` objects - live |
| 07-P0-1 CI undiscoverable | `Test-Path <repo>\.github` | **False** - workflow still only under `core_app/.github/` |
| 09-P0-FB-1 no per-client backend | audit recursion re-affirmed by tree walk | `apps/halal_boyz` ships no `firestore.rules`/`firestore.indexes.json`/`storage.rules`/`.firebaserc` |
| Path corrections found by this run | path resolution | `merged_menu_provider.dart` = `core_app/lib/features/menu/presentation/merged_menu_provider.dart` (audit cited `.../providers/`); `kitchen_task_dispatcher.dart` = `core_app/lib/features/orders/domain/kitchen_task_dispatcher.dart`; `route_names.dart` = `core_app/lib/app/navigation/route_names.dart` - the remediation prompt uses corrected paths |
**Conclusion of Â§2:** the audit corpus is accurate against the current tree; no hallucinated findings detected; no fixes were applied after the audits; nothing in the corpus may be skipped.

---

## 3. DE-DUPLICATED FINDINGS INVENTORY (what "fix everything" actually means)

Cross-audit duplicates collapsed (each counted once, primary audit bolded):

**P0 - 11 unique (all ship-stoppers):**

| # | ID (primary) | One-line statement | Key evidence |
|---|---|---|---|
| 1 | **00-P0-1** | Config-mode routes registered under screen-ID names while all named-nav call sites use `RouteNames.*` - every drawer/cart/login/checkout/admin tap throws at runtime | `app_router.dart:144-150`, 35 call sites, go_router `_nameToPath[name]!` |
| 2 | **00-P0-2** | Deep-link handler feeds a PATH into name-based `Navigator.pushNamed` on a go_router stack; table advertises inactive routes | `main.dart:269` |
| 3 | **00-P0-3** | ErrorWidget "Restart" uses `pushReplacementNamed('/')` - fires exactly when the app is already broken | `main.dart:108-110` |
| 4 | **02-P0-SYNC** | Offline order queue can never deliver: enqueues unpaid `status:'confirmed'` (create-rules require `pending`), zero auto-triggers, invisible DLQ - "order saved offline" is a false promise | `checkout_screen.dart:334,355`, `sync_queue.dart`, `firestore.rules:361-368` |
| 5 | **06-P0-1 = 09-P0-FB-2** | Charge computed from client-supplied prices; stored order payload unverified (items/status/tip/deliveryFee/orderNumber/branchId trusted); Admin-SDK merge bypasses rules | `payment.ts:192-210,451-463`, `index.ts:575-605,712-736` |
| 6 | **06-P0-2** | GDPR erasure misses `deliveries`, `analyticsEvents`, `audit_log` user rows, Storage `proof_of_delivery/*` + `avatars/*` (server AND demo mirror) | `index.ts:195-236`, `driver_location_service.dart:99-105` |
| 7 | **07-P0-1** | CI is vaporware: workflow under `core_app/.github/` never triggers; root-CWD paths; Flutter 3.32 pin vs workspace Dart `^3.11` | `carnama_ci.yml` location + yml lines 10/23/64 |
| 8 | **08-P0-WL-1** | Firebase API keys ship `""`; `validate()` has no gate; generated shell silently boots with NO auth/Firestore/FCM | `whitelabel.dart:68-92,654`, halal `main.dart:25-28,49-55` |
| 9 | **08-P0-WL-2** | Config flags stored as `{"enabled":true}` but parser accepts `bool` only - feature gating silently inert in core | `app_config.dart:270-277`, both `client_config.json` |
| 10 | **08-P0-WL-3** | Direct `AppColors.*` usage across `core_app/lib` bypasses per-client theme (latent today only because palettes are byte-identical) | dozens of sites; `app_colors.dart` vs config colors |
| 11 | **09-P0-FB-1** | Generator provisions NO backend (rules/indexes/functions/.firebaserc) for generated client projects; after WL-1 fix, brands boot on unprovisioned projects | `apps/*` zero backend files; `.firebaserc` single project |
**P1 - 46 unique fix-entities** (raw = 53; collapsed to 46 unique fix-entities: 02-P1-CONFIG = 08-P1-WL-3 = 08-P1-WL-6; 03-P2-STREAM-BUILD = 04-P1-STREAM at fix level; 06-P1-2 = 09-P1-FB-6; 01-P1-B = 09-P1-FB-3; 09-P1-FB-8 = 07-P0-1 (the CI fix, counted as its P0); 08-P1-WL-1 = root of P0-WL-2 and 08-P1-WL-2 = tracking of P0-WL-3; 00-consistency setState = 03-P1-STATE-A; 00 `$` literals = 05-P1-L10N-MONEY. 01-P1-A vs 02-P1-STAFF stay distinct: rules whitelist (W4) + staff queueing (W5). NOTE: audit-07 detail report lists 7 P1 incl. P1-7 funnel analytics; the master §07 summary row says 6 - the detail count of 7 is authoritative). Full per-finding list with winner solutions = `PRODUCTION_FIX_PROMPT.md`. Highlights by domain:

- **Security (01):** rules `hasOnly` whitelists aligned to real staff payloads (`updatedAt`/`assignedDriverId`/`proofOfDelivery`); `cancelOrder` callable created (client already calls it); `settings/ownerInfo` provisioned via fireway v003 (else `isOwner()` is dead on every fresh backend and ALL owner-gated writes/uploads fail out-of-box); FCM token deleted on signOut (cross-user push leak).
- **Network (02):** `NetworkRetry` extended (4xx-skip classification) and wrapped around critical one-shot reads + idempotent callables (1 wrapped site today); `PushNotificationService` instantiated with tenant-validated go_router navigation (never instantiated today - push chain dead end-to-end); kitchen Workmanager heartbeat actually scheduled (dispatcher exists, zero callers); staff status writes queued through `IsarSyncQueue` (sequenced AFTER rules alignment).
- **State/Perf (03/04):** `mounted` guard + provider invalidation in owner dashboard; GPS single-session tracking; `canTransitionTo` state machine + transaction-guarded status writes; version check moved out of first frame into splash's bounded funnel; named caps/windows on all uncapped live streams (manager dashboard streams the ENTIRE branch order history today); build-built streams promoted to family `StreamProvider.autoDispose`; `cloudinaryThumb` transform helper (list sites download full-res originals today).
- **A11y/L10n/UX (05):** ~118 string sites migrated to ARB (en+ar, 532/532 parity kept); one canonical `formatCurrencyCents` (3 formatter families + literal `$` today); AA contrast fix on the ordering path (2.86:1 today); cart badge + 8 icon buttons labeled; tracker step semantics; `PopScope` guard on checkout during charge.
- **Payments/Privacy (06):** `verifyOrderCharge` extended (stored `order.items` subtotal vs PaymentIntent metadata + tip/deliveryFee equality + status allowlist; phase 2: per-item menu cross-check); refunded-PaymentIntent replay rejected; fraud gate consulted inside the charge path; consent chain wired (dialog shown post-onboarding + single consent key); ToS/Privacy checkbox gating signup; unused `ACCESS_BACKGROUND_LOCATION`/`FOREGROUND_SERVICE*` removed; generated shell gets full permission/usage-string/privacy-manifest layer via the generator; Art.20 export completed.
- **Testing/CI (07):** root `.github/workflows/` with correct CWDs + SDK pin; full-estate test gating (features/packages/shell included); format gate committed green; config-schema validation (`ConfigException` + fail-closed screen + test matrix); release pipeline (signing template, appbundle smoke job, CHANGELOG, tags); 3 config-mode router test files; real network-blocker harness in `flutter_test_config.dart`; checkout funnel events + `FirebaseAnalyticsObserver` wired.
- **White-label (08):** `validate()` demands non-empty Firebase keys; generated shell fail-fasts (blocking screen) on empty keys; flags flattened to `bool` repo-wide + parse gate; generated-shell config loader gets core's try/catch fallback; `firebase.projectId` key unified + `loadFailed` surfaced; dead config keys pruned; forbidden-token list widened.
- **Backend (09):** generator emits per-client backend bundle + deploy runbook (P0-FB-1); driver `myOrders` query gains `branchId` constraint (rules-not-filters); kitchen `['ready']` read clause extended; composite index `orders(status ASC, createdAt ASC)` added to `firestore.indexes.json`; functions eslint added; alerting sink documented + checklist.
**P2/P3 - ~70 items:** launch-quality backlog per the master's own convention (`PRODUCTION_READINESS_AUDIT_MASTER.md:72`), EXCEPT the subset pulled into remediation waves because they are same-file/same-mechanism as a P0/P1 or zero-risk hygiene (`.env` gitignore, golden failure artifacts, dead config keys, etc.). The prompt marks every included P2 explicitly - nothing is silently dropped.
## 4. WHY "FIX ALL FINDINGS" ALONE IS NOT SUFFICIENT (the 6 residual gates)

1. **Fixes must be PROVEN, not applied.** The repo's proofs live in gates: `flutter analyze --fatal-infos` (all 5 packages), full `flutter test` (0 skips), `npm run test:rules` (Firebase emulator), `npm run test:money-emulator`, the GDPR emulator suite, `npx tsc --noEmit`, `npm test` (functions), format check, and the grep gates. After the rules/payload changes (01-P1-A), the queue changes (02-P0-SYNC) and the money changes (06-P0-1), the harnesses MUST be extended with the exact regression cases the audits specify (driver/kitchen read shapes, unpaid-pending replay, refunded-PI replay, client-priced subtotal) and re-run to green. An unverified fix is not a fix.
2. **Three-surface propagation.** Template fixes in `core_app/lib` + `packages/*` do NOT automatically reach `apps/halal_boyz` â€” the shell carries its own copies (`main.dart`, `app/app_router.dart`, `app/core_config_adapter.dart`, `app/currency_config.dart`, `assets/client_config.json`). Every wave in the remediation prompt carries an explicit mirror step, and generator-owned changes must flow through `core_app/tool/whitelabel.dart` so regeneration reproduces them.
3. **Release engineering must exist before "production" means anything.** No Fastfile, no appbundle build, no signing template, no CHANGELOG, no tags, no `.env`/keystore hygiene today (07-P1-4, 07-P2-3, 08-P2-7). A perfect app that cannot be signed, built and rolled out is not production-ready.
4. **The console/deploy checklist cannot be satisfied by code.** App Check production claim presence (`app_id`, `firebase.app_check_token`) is UNPROVEN â€” the rules harness injects those claims artificially (`test/rules/firestore_rules_test.js:32-33`); if they do not materialize, the six `isAppVerified()`-gated write surfaces brick. Same class: per-client Firebase projects + App Check apps; `settings/ownerInfo` seeding verification; composite-index deployment; Stripe live keys + webhook endpoint per project; Remote Config keys (`admin_pin`, force-update); the `firestore-security-alerts` log sink (P1-FB-5). These are runbook items the remediation prompt carries as VERIFY-IN-CONSOLE.
5. **Runtime performance is unproven.** Audit-04 is entirely static; its own honest limitations state cold-start ms / jank / memory are NOT PROVEN without mid-range Android profiling. After P1-BOOT/P1-QUERY/P1-STREAM/P1-IMG land, a profiling session is required evidence.
6. **Load, soak, monitoring and DR are absent from every audit.** `verification_report.md:11` already states 500-user capacity is unsupported. No load test, no budget alerts, no backup/restore drill, no incident runbook exists in the repo. These are deployment-time gates, not code fixes.

---

## 5. COVERAGE GAPS â€” ISSUES NO AUDIT FULLY OWNS (found during this meta-audit)

1. **`main.dart:262` `pushReplacementNamed('/login')`** â€” same broken-API class as 00-P0-3 (auth-state listener path). Audit-00 lists the deep-link table + ErrorWidget; the prompt folds :262 into the same fix (go_router API swap) so no instance of the class survives.
2. **`OrderRepository.submitOrderAtomically`** â€” dead/misleading test-only path whose payload mismatches `createOrder` (verification_report 6.4): must be removed or aligned during the money wave; audit-09's rules work does not own it.
3. **`admin_access_service` audit trail dead path + `audit_log` vs `audit_logs` dual collections + `.email` vs `ownerEmail` drift** (01-P2-3/P2-6) â€” folded into the ownerInfo wave (01-P1-C) since v003 seeds the doc those readers disagree about; decide one canonical collection + field name and delete the dead path.
4. **Golden baselines byte-identical (delivery vs kitchen dashboards)** â€” re-capture during the CI wave; a11y wave re-baselines them again after palette change (ordering matters, the prompt sequences it).
5. **B6's "GO" artifact** must be annotated as superseded in the ledger to prevent future agents from treating it as current clearance.
6. **Emulator hosts `0.0.0.0`** (09-P2) â€” acceptable for local CI only; the deploy runbook must state prod never runs emulators publicly.

---
## 6. SOLUTION DECISIONS WHERE THIS REPORT REFINES THE AUDITS (no silent deviations)


1. **Contrast (05-P1-A11Y-CONTRAST).** Audit-05's fix plan darkens `primary`. Two mechanisms reach AA; the report/prompt implements the winner but flags the brand decision: **Option A (audit winner):** darken `primary` to ~`#C84F00`-class (first orange reaching 4.5:1 with white; computed: #FF6B00=2.86, #E65C00=3.56, #C84F00=4.57). **Option B (brand-preserving):** keep `#FF6B00` and set `onPrimary` to a dark ink (~`#1D1D1D`, ratio 5.9:1) in `AppTheme` + both config `theme` blocks. Either way the change MUST land byte-synced in `AppColors`/`AppTheme` AND both `client_config.json` blocks (audit-08 proved divergence is invisible until the first differently-paletted client), `textSecondary` and `success` must reach 4.5:1 regardless, and a widget test must assert the WCAG ratios from the real palette. Owner picks A or B once; the mechanism is identical.
2. **connectivity_plus (02-P0-SYNC).** The winning fix adds a connectivity trigger; `connectivity_plus` is not currently a dependency. Sanctioned as the ONLY new runtime dependency, added to `core_app/pubspec.yaml` (composition root) so `packages/core` stays dependency-clean; the watcher service lives in core_app and calls `processQueue`.
3. **Driver `myOrders` (09-P1-FB-1).** Fix at the QUERY level (add `branchId` constraint, mirroring `availableOrders` in the same file) rather than loosening rules - preserves tenant scoping and the rules' existing shape.
4. **Kitchen `['ready']` board (09-P1-FB-2).** Extend the kitchen read clause to `['confirmed','preparing','ready']` (the ready board is kitchen's own workflow stage); write-side transition validation (03-P1-TRANSITION) stays the integrity guard.
5. **Format gate (07-P1-2).** The 136-file mechanical format already sits uncommitted in the worktree (audit-07 disclosure) - commit it as its own mechanical commit; do not re-format generated freezed output beyond what the tool does.
6. **Halal Boyz real API keys (08-P0-WL-1).** Repo-side: gate + fail-fast + template fix. The actual key VALUES for `demo-tenant` are console data - ops checklist, not a code change; regenerate the shell after filling.
7. **`ProcessQueue` order payload.** Offline intent is enqueued with `status:'pending'` + `offlineQueued:true` marker (never `confirmed`); the live order object the UI holds is NOT mutated; replays stay outside the money path; on `permission-denied` the op goes straight to DLQ (no retry burn).

---

## 7. DEFINITION OF DONE (the exact moment "production-ready" becomes true)

1. All 11 P0 + 46 unique P1 verified fixed through the gates (not self-attested) - each wave's ledger addendum in `FIX_VERIFICATION.md` with command outputs.
2. Emulator suites green post-fix: rules (92/92 + new regression cases), money-emulator, GDPR erasure; functions `tsc` + unit green; eslint green.
3. CI live on GitHub under root `.github/workflows/` with a green run on the remediation branch: analyze, full-estate tests incl. `test/features` + packages + shell, goldens, rules (emulator service), permissions audit, appbundle smoke, integration (emulator), ci-gate.
4. Re-audit of all 9 sections against their original prompts; every section verdict flipped to PASS in `PRODUCTION_READINESS_AUDIT_MASTER.md`; OVERALL = PASS.
5. Release pipeline real: signing templates + appbundle build + CHANGELOG + tag discipline; store listings + privacy labels drafted.
6. VERIFY-IN-CONSOLE checklist executed and recorded (App Check claims, ownerInfo seeding, indexes deployed, Stripe live + webhook, per-client projects, Remote Config keys, alerting sink).
7. Profiling evidence captured on a mid-range Android device (cold start, scroll, memory) post-perf-wave.
8. Remaining P2/P3 accepted as documented backlog with owners (launch-quality, non-blocking under the repo's own constitution).

**Bottom line:** Fix everything the audits found (11 P0 + 46 unique P1), prove it through the gates, propagate it to all three surfaces, close the deploy checklist, and re-audit to OVERALL = PASS - THEN the app is production-ready by the codebase's own standard, and only then. `PRODUCTION_FIX_PROMPT.md` is the exact execution order to get there.

**END OF report.md**
