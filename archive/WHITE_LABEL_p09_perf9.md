# PERF-9 — "Launch Gap": the LAST audit/fix wave (then freeze)

Spec = acceptance contract. Code at HEAD (`6567b23`) = source of truth for evidence tables.
Rule set: TDD (red→green for every fix and behavioral test) · No hallucination (P1 = file:line opened this
session, P2 = a test that fails if the claim is false; anything else is UNVERIFIED) · No stubs · No shortcuts ·
No TODO-as-done · No `@Skip`/`skip:` · No fail-open on money/auth · No drive-by fixes outside territory
(handoff notes only) · No AI slop (findings ≤6 lines, closed vocabularies, no "appears to" in VERIFIED class).

§0.1 PREMISE LAW (PERF-8 lesson A-3, binding on the coordinator): every cited file:line in §7 is re-verified
by the coordinator BEFORE window dispatch. Drift ⇒ spec patch, recorded. No window discovers the spec was wrong.

## §1 WHY THIS WAVE EXISTS (the loop-breaker)

PERF-8 (5 windows) verified the whole Dart client and found real bugs + dead code. The failure mode to kill is
the audit loop: waves that find the previous wave's incompleteness forever. Therefore:

1. This spec dispositions **every** open PERF-8 finding (§7 register). Each item gets exactly one of:
   **FIX (this wave, red→green)** or **PARK-FOREVER (written reason in §7, irreversible without a new wave)**.
2. **Zero carried handoffs at freeze.** "Handed off" is not a terminal state anymore.
3. **Convergence criterion (numeric, §8).** When it is met, we declare FREEZE: no further audit waves; bugs come
   only from production usage (deploy day, real orders). Quality thereafter = feedback-driven hardening.

## §2 TERRITORY (2 parallel windows — fleet-size rule: ≤2 windows from here on)

| Window | Branch | Owns (exclusively) |
|---|---|---|
| W1 | cline/task-1 | `core_app/lib/features/reservations/**` repository+domain, `core_app/lib/features/menu/presentation/merged_menu_provider.dart`, dead-code deletions (§3 T-5 file list) |
| W2 | cline/task-2 | `core_app/lib/features/reservations/presentation/reservation_screen.dart` + its tests, `core_app/firestore.rules`, waitlist feature (`lib/features/waitlist/**`), the rules test file |
| Coordinator (sequential, post-merge) | main | T-7 read-only audit, T-8 bounded mutation run, SYSTEM MAP, freeze declaration |

Production files are disjoint across W1/W2. `firestore.rules` is W2-only; W1 writes rules **assertions** only
through W2 (§3 T-2 step 5) and must NOT edit `core_app/test/rules/firestore_rules_test.js`. No window touches
`FIX_VERIFICATION.md` (§6).

## §3 THE FIXES (designs are FIXED — windows implement; they do not redesign)

### T-1 (W1) — Seats released on cancel [B-1 · LEDGER:PERF-8/W4]
- P1 FIRST: enumerate EVERY reservation status-transition site (grep requestSlot/cancel/no-show/complete + all counter writes). The fix lives at the single chokepoint that owns transitions; record the enumeration.
- Fix: compensating decrement in the SAME Firestore transaction as the transition, guarded by a status precondition (e.g. `pending→cancelled`) so retries cannot double-decrement; clamp the counter at ≥0 (drift can never go negative).
- Red proof: book 2, cancel 1, assert capacity returns — fails on HEAD because the counter is monotonic.
- REJECTED (do not relitigate): scheduled reaper as primary (turnover latency); client-untrusted free decrement; server-only CF (runtime coupling the deploy day does not require).
- Backstop permitted ONLY if a transition site proves un-transactional: scheduled reconciliation job, documented as backstop with the reason → HANDOFF note to coordinator.

### T-2 (W2) — Waitlist take-a-ticket [B-2 · LEDGER:PERF-8/W1-A2] (corrected design: a counter answers "how many", not "how far am I" — an ordinal is required)
1. New doc `branches/{bid}/waitlist_meta` `{ nextTicket:int, nowServing:int }`.
2. Join = transaction: assigns `myTicket = nextTicket++` and writes the guest doc `{ myTicket }` in the SAME transaction (existing deterministic id `${branchId}_$userId` stays).
3. Serve/leave (staff, or guest via own-doc path) advances `nowServing` past the served ticket.
4. Customer position = `myTicket − nowServing − 1`, computed locally from two READABLE docs (own guest doc + meta doc). No list-query. No CF fan-out.
5. RULES (why W2 owns the rules file): branch customers READ `waitlist_meta`; writes ONLY via the join/leave transaction paths + staff. Pin: the exact W1-T7 scenario (2+ queued users) now yields a PASSING read + a correct ordinal. W1's code may only ASSERT against these rules through W2's pins — W1 never edits the rules test file.
6. UI: `waitlist_screen.dart` renders the position, replacing the dead `streamQueuePosition` path for customers; record whether the old method is kept (staff views) or removed.

### T-3 (W1) — Menu override overlay [B-3 · LEDGER:PERF-8/W4-2]
- Schema: `branches/{bid}/menu_overrides/{canonicalItemId}` `{ priceCents?, isAvailable?, … }` — additive, no migration.
- Merge in `merged_menu_provider.dart` by DOMAIN id (doc id == canonical item id); absence = inherit global. This is the fix for "merge keyed by doc id can never match".
- Tests: override wins · absence inherits · `isAvailable:false` via override renders the masked row (consumer contract proven in PERF-8 W4).

### T-4 (W2) — Rules hardening pins [B-4, B-5]
- B-4: orders cancel path gains the customer-ownership clause (`resource.data.customerId == request.auth.uid`); pin: own-cancel allowed (demo path), other's denied.
- B-5: carts block gains `isAppVerified()` (uniformity with b10 P-6); full rules suite green; count 156 → 160+ with T-2's pin.

### T-5 (W1) — Dead-code deletions [B-6 · LEDGER:PERF-8/W4-4, W5]
- Delete: `admin_provider.dart` (carries the only unscoped `admins` access), `admin_dashboard.dart`, `lib/app/config/env.dart`, and the W4-4 dead provider declarations. Test-only-referenced calculators/banners (`cart_calculator`, `promo_calculator`, `referral_engine`, `analytics_helpers`, `allergen_disclaimer_banner`): delete file + their property tests (tests of dead code are test-theater) — note each in the register.
- Precondition: FRESH zero-refs grep THIS session (W5's proofs age).
- TOUR FILES ARE EXEMPT: `tour_manager`/`tour_overlay` are a PARKED product decision (PERF-6f) — do NOT delete built features.
- Absence pin: source-scan test asserting the deleted files/public symbols never return.

### T-6 (W2) — `reservation_screen.dart` coverage sweep [LEDGER:PERF-7 residual]
- Floor: 68.9% (measured at W3's tip) → **≥80%** feature floor via behavioral tests (success path, invalid input, back navigation, disabled states). No UI redesign; tests only.
- If a remainder is genuinely untestable in widget-test lanes (platform plugin internals), name the lines and the reason in the findings file — that is the PARK record, not a shortcut.

### T-7 (COORDINATOR, read-only, post-merge) — the two never-scouted territories [closes PERF-8 §2 answer]
- **Full clause sweep of `core_app/firestore.rules`** (W1 pinned 10 surfaces = sampling with receipts; this is clause-by-clause) + **line audit of W1's 73 non-data Dart query sites** (already enumerated in `tool_perf2/p8_w1_nondata_query_sites.txt`).
- **`core_app/functions/**` trace** (~1900+ lines): every callable — auth gate, App Check gate, input validation, Firestore scoping, secret use, money math (re-pricing, webhook verify), error paths. The 75-test suite stays P2 evidence; this pass is the P1 line-audit that was never done.
- Output: VERIFIED/UNVERIFIED/ANOMALY/RISK entries appended to the SYSTEM MAP. **A new ANOMALY here is freeze-blocking** — it ships as a red→green fix before freeze; "zero anomalies" is the final evidence line.

### T-8 (COORDINATOR, post-merge) — bounded mutation run [retires PERF-6e]
- Scope (bounded, hours not days): `functions/src` money path (`createOrder` re-pricing, `stripeWebhook` verify) + `core_app/lib/features/checkout/domain/checkout_service.dart`.
- Method: hand-mutated killers only (flip a comparison, drop a precondition, swap == / !=, remove a bound) — one file at a time; a mutation is *killed* if a test fails; report = killed/total per file.
- Honest outcome: the ledger claim upgrades from "tests are green" to a **measured kill-rate** (e.g. "14/16 killed; 2 survivors dispositioned"). Survivors become named tests in the same session or PARK-recorded with reason. No framework install required; no repo-wide run.

## §4 RULEBOOK PATCH (A-2 — one authority, zero conflict class)
1. **Wave spec supersedes the driver template.** For multi-window waves the U-REPORT appendix to `FIX_VERIFICATION.md` is **coordinator-written** from the windows' paste-ready blocks. Windows deliver `tool_perf2/p9_wN_findings.md` + a paste block and **never touch the ledger**. (PERF-8 lesson: W2/W3 both appended at EOF — a merge conflict by construction, §6.2 violated by the template itself.)
2. The single-line driver-contract note is amended accordingly; future waves inherit this §4 text.

## §5 ACCEPTANCE (per window, all mandatory)
- Blocker gate BEFORE any edit: `git merge --ff-only main` to the **post-PERF-8-closure tip** (not `6567b23`), then `flutter analyze --fatal-infos` (core_app) + `dart analyze` (packages) exit 0.
- TDD evidence per fix: red proof captured BEFORE the fix (log file under `tool_perf2/p9_wN_*.log`), green after, mutation reverted-if-proof-only.
- Gates at final tip: format `--set-exit-if-changed` 0 changed · full core_app suite 0 fail / 0 skip · rules suite green at the new count (§3 T-4) · skip/TODO/`expect(true` greps in touched scopes = 0.
- Territory audit: `git diff --name-only <baseline> HEAD` contains ONLY files in the window's §2 row + its `tool_perf2/p9_wN_*` artifacts. Forbidden paths (pubspec.lock, *.g.dart/*.freezed.dart, isar.dll, .dart_tool, build) = 0.
- Deliverable: findings file with the six-way classification (VERIFIED/UNVERIFIED/ANOMALY/UNTESTED/RISK/RECOMMENDATION), ≤3 RECOMMENDATIONs, honest UNVERIFIED section (non-empty allowed; missing = suspicious).
- Zero ledger edits (§4.1). Paste block provided for the coordinator.

## §6 COORDINATOR PROTOCOL (order of operations — nothing skips)
1. **PERF-8 closure FIRST** (before any PERF-9 window starts): merge `cline/task-1..5` (tips `10f2ef9`/`c7f489b`/`d6fbef9`/`fdc5343`/`548244e`, all verified + backed up on origin) into main; production files are disjoint; resolve the expected W2/W3 ledger EOF conflict **keeping both addenda in order**; full battery on merged main (format/analyze/suites/rules/coverage stamp); append `## VERIFIED SYSTEM MAP (PERF-8)` single-writer; push. Windows then sync to that tip.
2. Dispatch W1+W2 (§2) → judge per §6.3 of PERF-8 (100% re-verify money/auth/isolation claims, ≥20% sample elsewhere) → merge.
3. Coordinator executes T-7 (read-only audits) → then T-8 (bounded mutation run).
4. Append `## APP COMPLETION PERF-9 - Launch Gap - VERIFICATION REPORT` (single-writer) + **declare FREEZE** if §8 holds.
5. Push after every durable step (outage discipline — the user has lost work twice).

## §7 THE REGISTER — every open finding, dispositioned (durable note-down; PARK-FOREVER is irreversible without a new wave)

### From PERF-8 (verified by coordinator)
| ID | Finding | Disposition |
|---|---|---|
| W4-1 | merged_menu_provider dropped unavailable items on branch path (owner couldn't re-enable an out-of-stock dish) | **FIXED in PERF-8** (61ba25e, red→green) |
| W4-3 | reservations requestSlot fail-open guard (partySize ≤0 decremented atomic counter) | **FIXED in PERF-8** |
| B-1 / W4 | reservation capacity counter monotonic — seats never released on cancel | **FIX → T-1 (W1)** |
| B-2 / W1-A2 | waitlist branch list-query denied for customers at 2+ queued — queue position dead | **FIX → T-2 (W2)** |
| B-3 / W4-2 | per-branch menu override merge structurally unreachable (keyed by unique doc ids) | **FIX → T-3 (W1)** |
| B-4 / W1-A3 | demo-mode cancelOrder orders-rules gap (latent, no customer-ownership clause) | **FIX → T-4 (W2)** |
| B-5 / W1-R1 | carts rules block missing `isAppVerified()` gate | **FIX → T-4 (W2)** |
| B-6 / W5 | dead `admin_provider.dart` = only unscoped `admins` collection access | **FIX → T-5 (W1)** |
| W4-5 | `ReservationModel.fromDoc` has no production caller (admin tab uses fromJson) | **FIX → T-5 (W1): delete factory + its tests** |
| W4-4 | 6 dead + 2 unwired provider declarations (incl. `selectedBranchProvider` second branch source-of-truth; `themeConfigProvider` dead — mechanism verified as `AppConfig.theme`) | **FIX → T-5 (W1): delete declarations; delete `themeConfigProvider` + labs.dart:48 export** |
| W5 dead-10 | env.dart · admin_dashboard.dart · admin_provider.dart · analytics_helpers · cart_calculator · promo_calculator · referral_engine · allergen_disclaimer_banner (config no-op flag with it) | **FIX → T-5 (W1): delete files (+ property tests of dead code)** |
| W5 tour | tour_manager / tour_overlay — built feature, deliberately unrouted | **PARK-FOREVER**: product decision PERF-6f; graceful no-op at HEAD; deletion would destroy built value |
| W1 premise drift | A-1's per-tenant clientId premise wrong — tenancy = one Firebase project per client (verified whitelabel.dart:1205-1211) | **RESOLVED**: drift recorded; real contract (uid/branch) fully pinned by W1's 18 tests |
| W1 73 non-data sites | enumerated, not line-audited | **FIX → T-7 (coordinator line audit)** |
| W2 config race | contact deep-link judged before config loads; reorder dropped items on cold cart | **FIXED in PERF-8** (c7f489b) |
| W3 fences | double-tap opened 2 money pipelines; reservation re-entrancy via onFieldSubmitted | **FIXED in PERF-8** (d6fbef9) |

### From PERF-7 / earlier waves (quality residue — each gets a terminal disposition)
| ID | Finding | Disposition |
|---|---|---|
| PERF-7 | reservations feature 75.4% (repo/domain mass under floor) | **FIX → T-1 (repo→100 via fix tests) + T-6 (screen ≥80)** |
| PERF-6a-3 | tracking 78.4 / driver 56.2 / location 78.1 / menu_provider 52.9 | **FIXED in PERF-8** (W2: 92.3/100/91.7; W4: 100) |
| D-residue | `app_bootstrap` 63.2% | **PARK-FOREVER**: boot wiring exercised indirectly by every suite; direct tests would only test the harness |
| D-residue | admin screens partial (delivery_dashboard 65.5, owner_dashboard 71) | **PARK-FOREVER** at package floor (85%+); per-screen floors are diminishing returns — post-freeze bugs come from deploy day, not speculation |
| PERF-6f | NFC Stripe Terminal · DoorDash/Uber dispatch · tour auto-routing | **PARK-FOREVER**: product decisions; graceful degradation at HEAD (typed errors, no-op) — revisit only on owner request |
| Honesty | `url_launcher` unused dep (core_ui); goldens "68" superseded by audited 27 | **PARK-FOREVER**: cosmetic; dep removal = pubspec churn with zero behavior gain |
| Gates | emulator-gated suites compile-gated (EMULATOR_AVAILABLE), never run in CI lanes | **CARRIED to T-7 note + operator deploy day**; the rules suite (160+) IS the emulator-backed isolation evidence |
| W5 UNVERIFIED×5 | dynamic/string dispatch · per-file intent · functions-dir aggregation · unexecuted generator template · name-based barrel attribution | functions-dir → **T-7**; rest **PARK-FOREVER** with W5's stated closers (recorded in p8_w5_findings.md) |

### Outstanding questions — CLOSED by coordinator verification (receipts in p8_coordinator_findings.md)
- **Q1 (W5):** any *live* unscoped collection access? → No: the only one sat in dead `admin_provider.dart` (T-5 deletes it); all 22 data sites pinned by W1's 18 tests.
- **Q4 (W5):** does dead `themeConfigProvider` mask a wrong theming mechanism? → No: live path verified `AppConfig.theme` → `AppTheme.buildTheme` (app_bootstrap.dart:792, app_config.dart:313); deletion is hygiene, not a behavior change (T-5).

## §8 CONVERGENCE CRITERION — FREEZE is declared when ALL of these hold (numeric, no judgment calls)

1. §7 register: **zero items with disposition FIX unmerged** (every FIX row is shipped red→green, or upgraded to PARK-FOREVER with a written reason).
2. Coverage: package floors ≥80% all four packages (CI Law 48); PERF-9's named targets (T-1 repo, T-6 screen, §3 floors) met; residuals = §7 PARK rows only.
3. Gates on merged main: format 0 changed · analyze --fatal-infos exit 0 · all suites (core_app / core / core_ui / shell / functions) 0 fail / 0 skip · rules suite green at its new count.
4. T-7 audit output contains **zero un-fixed ANOMALY** entries (new anomalies ship red→green before freeze).
5. T-8 kill-rate measured and every survivor dispositioned (test added or PARK-recorded).
6. The system map + this spec + register are committed and pushed.

**After FREEZE:** no further audit/fix waves. Bug intake = deploy-day reality (on-device smoke, real orders, production logs). New work requires a new wave spec with a written justification — "suboptimal" alone does not qualify.

## §9 WINDOW QUICKSTART (paste into each window)

```
You are window Wn of PERF-9 (spec: WHITE_LABEL_p09_perf9.md at repo root — read §0–§6 + §7 fully,
then ONLY your own §3 row; §8–§9 are coordinator material).
1. cd to your worktree; git merge --ff-only main  (must be the post-PERF-8-closure tip, NOT 6567b23 —
   if main still shows 6567b23, STOP and report: PERF-8 closure has not happened).
2. Blocker gate BEFORE any edit: cd core_app; flutter pub get; flutter analyze --fatal-infos  → exit 0.
3. Execute ONLY your §3 row's steps (designs are FIXED — implement, do not redesign). TDD: capture the
   red proof to tool_perf2/p9_wn_<name>.log BEFORE fixing; then green.
4. Territory is §2's row for your window. Zero edits to FIX_VERIFICATION.md, firestore.rules (unless W2),
   or the other window's files. Cross-territory = handoff note in your findings file.
5. Gates at final tip (§5): format --set-exit-if-changed = 0 changed · full core_app suite 0 fail/0 skip ·
   skip/TODO/expect(true greps in your touched scopes = 0.
6. Deliver tool_perf2/p9_wn_findings.md (six-way classification; honest non-empty UNVERIFIED) + a
   paste-ready ledger block. Commit on your branch. Report. Do NOT merge, do NOT push, do NOT start
   another batch.
```
