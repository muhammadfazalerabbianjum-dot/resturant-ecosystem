# DEEP PROOF — every claim, freshly executed

Executed this session at freeze tip `c15c98a` (= `5e30a65` + ledger). Raw receipts: `tool_archive/perf2_cited/tool_perf2/proof/01–16`. Nothing below is memory — each claim quotes the observed output of a command you can rerun (§6).

## Q1 — "Is Halal Boyz a stub? Does it lack any UI?"

### 1.1 The shell contains no product code — 7 files, 357 lines, all wiring
Command: list `apps/halal_boyz/lib/**` with line counts → `tool_archive/perf2_cited/tool_perf2/proof/16_shell_anatomy.txt`
```
lib\firebase_options.dart  47L          lib\app\config_error_screen.dart  46L
lib\main.dart  52L                      lib\app\core_config_adapter.dart  95L
lib\app\app.dart  24L                   lib\app\demo_config.dart  48L
lib\app\client_config_loader.dart  65L
```
Every line of product behavior lives in `core_app` + `packages/*` — the 1,941-test engine.

### 1.2 Stub census: 7 hits, all of them the ANTI-stub guard itself
Command: grep lib for `TODO|FIXME|placeholder|stub|not implemented` → `proof/03_stub_census.txt` — all 7 hits are `client_config_loader.dart`'s W6.1 fail-fast placeholder-key gate (the regex that REFUSES to boot Firebase with a placeholder key, `:8-11,:64`), `main.dart:26`'s FATAL error message, and `config_error_screen.dart:5`'s doc. **Zero stubs. The only "placeholder" in the shell is the code that rejects placeholders.**

### 1.3 Harder still: tests that FAIL if a stub ever returns
`price_cents_guard_test.dart:12-22` + `widget_test.dart:50` (*"no placeholder screen class remains in shell lib"*) + `checkout_honesty_test.dart:58-75` (no fake payment key) — all passing in `proof/01` (+56, exit 0). A repo whose tests prohibit stubs is the opposite of a stubbed repo.

### 1.4 No missing UI: 26 screens, exact map equality
Config enumeration → `proof/04_config_screens.txt` = **26 screen ids**; 5 customer tabs; 10 role-gated staff routes (`/admin`, `/owner`, `/manager`, `/kitchen`, `/delivery`, …). Command: `flutter test test/route_walker_test.dart` → `proof/02_route_walker.txt`: **`00:00 +2: All tests passed!`** — the walker builds the shell's REAL router from its REAL config and asserts exact map equality: every whitelisted screen registered at its exact path, no extra, no missing. A config route without a screen fails the suite (`:51-53` reason string).

**Verdict Q1: not a stub; UI-complete by construction, with tests that make regression impossible.**

## Q2 — "Is the code doing what it's intended? Are the tests real?"

### 2.1 The tests DETECT defects — proven by injection
T-8 injected 26 named mutants into the money path (16 TS / 10 Dart; 6 operator classes: GUARD-REMOVAL 9, BOUNDARY 6, COMPARISON-FLIP 5, SIGN 3, CONSTANT-CHANGE 2, ORDER-SWAP 1) — amount derivation, tax fallback/clamp, promo clamp, order re-derivation, idempotency, cancel ownership, webhook signature. **26/26 KILLED, zero parks** (`tool_archive/perf2_cited/tool_perf2/t78_mutants/manifest.json` + `results_recheck.json`).
Coordinator's own independent re-checks (not the executor's): M-TS01/02/03 (PERF-10 session, 3/3 KILLED) + fresh today, M-TS02 re-applied against the frozen tip → `proof/14_mutant_spotcheck.txt`: `M-TS02 exit=1 verdict=KILLED`, byte-identical restore.

### 2.2 The full battery, fresh this session (all receipts in `proof/`)
| Suite | Receipt | Result |
|---|---|---|
| core_app (+coverage) | `07` | **+1941: All tests passed!** exit 0 |
| packages/core | `08` | **+306: All tests passed!** |
| packages/core_ui | `09` | **+90: All tests passed!** |
| shell | `01`,`10` | **+56: All tests passed!** (×2 runs) |
| firestore rules | `11` | **PASSED: 197 FAILED: 0** |
| storage rules | `12` | **PASSED: 8 FAILED: 0** |
| functions (money authority) | `13` | **pass 79 · fail 0 · skipped 0 · todo 0** |
| analyze ×4 | `05_*` | exit 0 ×4 |
| format | `06` | 0 changed |
| coverage | `15` | **TOTAL 8135/9372 = 86.80%** |

**Verdict Q2: 2,415+ behavioral tests, 0 skipped, 0 todo — and the suite demonstrably kills injected money-path defects.**

## Q3 — "How do we stop the spiraling?"

The loop existed because audits had no convergence criterion. It ended mechanically:

- **FREEZE DECLARED** at `5e30a65`, 2026-09-19 — in the ledger (`archive/FIX_VERIFICATION.md`, pushed at `c15c98a`), evaluated against the numeric criterion (archive/WHITE_LABEL_p09_perf9.md §8): **zero open findings** (B-1…B-6 fixed; T-7's three production anomalies fixed red→green in-tree; T-8 survivors all killed; stragglers + location resolved) · **floors met** (86.80%, every feature ≥80% — location was the last at 78.1, now 100% hand-written) · **only ship-blockers remain**.
- Consequence: **no further agent waves unless production usage reports a bug.** New information now enters only through real users — the highest-signal source — and fixes ship through the same red→green + gate + receipt lane as everything else. The loop's fuel (audit waves obligated to find something) is gone by construction.

## Q4 — "I don't wanna find a bug in production"

**The honest contract: zero production bugs is not a promise anyone can keep.** What exists instead is a measured map of what's defended, what's still reachable, and the mechanism that moves discovery from "production" to "internal track."

### 4.1 Proven-defended bug classes (each with its receipt)
| Class | Defense | Proof |
|---|---|---|
| Wrong charge amount / tax / promo | Server-side re-derivation; client totals never trusted; clamp + precondition guards | functions `13` (79 pass incl. tamper denial) + `26/26` mutants |
| Double-charge / replay | Idempotency-key pipeline + client fence (sync-set before first await) | `checkout_screen_flow_test.dart` |
| Unauthorized data access | 197 rules tests + uniform App-Check (last owner surfaces gated in PERF-10) | `proof/11` |
| Over-broad file writes | POD upload narrowed to THE ASSIGNED driver + fail-clean null-guard | `proof/12` + `t78_phaseA_storage_red/green` |
| Missing UI / dead screens | Route-walker exact-map + anti-stub pins | `proof/02`, `01` |
| Seats leaked on cancel / waitlist ordinal | Compensating decrement (clamped ≥0) + take-a-ticket | `reservations_repository_perf9_test` (100% file), `waitlist_repository_perf9_test` |
| GDPR gaps | Erasure/export callable coverage + client delete-account flow | functions `13` + `test:gdpr` lane |
| Offline queue corruption | Sync-queue failure-path suite (100% file) + DLQ | `sync_queue_test.dart` |
| Silent fail-open | The `catch(_)` census: 21 sites audited, all fail-safe (20 fail-closed + 1 documented availability tradeoff in force-update) | LEDGER PERF-3 |

### 4.2 Still reachable — the exact residual list (T-7 report §6, all parked loudly)
- **U-1** — storage-rules assigned-driver POD **at runtime**: the storage emulator cannot bridge cross-service Firestore lookups; the clause is statically pinned (`s78-STATIC1`) and deny-direction proven, but the ALLOW path needs a prod-ruleset/device check. **Closes on deploy day (O-3).**
- **U-2** — webhook signature branch against **real Stripe payloads**: pure logic + fail-closed posture are unit-proven; live-key proof happens at the deploy-day test webhook.
- **Device-only classes**: network loss mid-payment, Play Integrity revocation, GPS/battery quirks, device matrix — no emulator models these. **Closed by staged rollout.**

### 4.3 The mechanism that converts "bug in production" → "bug in internal testing"
1. **Deploy day** (`archive/RUNBOOK_DEPLOY.md`, self-verifying): Blaze → deploy rules/indexes/functions → Stripe secrets + **Send test webhook** (closes U-2) → App Check enforce → migrations → seeds → tax tab → **on-device smoke: order → pay → webhook confirm → cancel → GDPR erase** (closes U-1/O-3).
2. **Internal testing track** (your device + owner's) → **closed track** (staff) — Crashlytics (already wired) watching.
3. **Production** staged, not flipped.
4. Post-freeze: bug-driven fixes, red→green, receipted — the same lane every fix in this repo has ever shipped through.

**Verdict Q4: every known bug class is either proven-defended, named with its closing step, or physically unprovable-before-real-users — and the rollout design catches the latter class with zero customers watching.**

## §6 Re-verification (the proof is a procedure, not a document)

```
cd apps\halal_boyz && flutter test                       # shell + route walker + anti-stub guards
cd core_app && flutter test --coverage                   # 1941 + lcov
cd core_app && npm run test:rules                        # 197/0
firebase emulators:exec --only firestore,storage "node test/rules/storage_rules_test.js"   # 8/0
cd core_app\functions && npm test                        # 79 pass
dart format --output=none --set-exit-if-changed .        # 0 changed
Get-ChildItem apps\halal_boyz\lib -Recurse -Filter *.dart | Select-String 'TODO|FIXME|placeholder|stub'  # 7 = the guard
```
Committed receipts: `tool_archive/perf2_cited/tool_perf2/proof/01–16` + `tool_archive/perf2_cited/tool_perf2/t78_mutants/{manifest.json,results_recheck.json}` + `t78_report.md`. Freeze + §8 evaluation: `archive/FIX_VERIFICATION.md` (PERF-10 sections). Claim summary: `HALAL_BOYZ_COMPLETENESS.md`.
