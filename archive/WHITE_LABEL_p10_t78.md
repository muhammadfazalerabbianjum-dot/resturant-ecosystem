# WHITE_LABEL_p10_t78 — PERF-10: T-7 + T-8 (final pre-freeze wave) — SINGLE EXECUTOR

**One executor session, two sequential phases, no fleet.** Coordinator = the main session (merges, judges, writes the ledger, evaluates freeze). The executor runs Phase A then Phase B in ONE session (the user sleeps — see §0.8). This spec supersedes the generic batch driver contract where they conflict — **including the DONE clause**: the executor does NOT append to `FIX_VERIFICATION.md` (single-writer, §0.4); deliver a paste-ready ledger block in the report instead.

## §0 Rules (binding, verified against this repo's own incident history)

0.1 **Proof law.** Every factual claim in a deliverable carries a receipt: **P1** = file:line you opened this session, or **P2** = a test that fails if the claim is false. Claims without receipts go in a mandatory, non-empty **UNVERIFIED** section with what would settle them. An honest unknown beats a confident guess.
0.2 **No fake green.** No `@Skip`/`skip:`/TODO-as-done/`expect(true, isTrue)`. Every fix ships **red→green**: capture the failing proof BEFORE the fix (log in `tool_perf2/`), then the green.
0.3 **Blocker behavior is canonical.** If your baseline check fails (§1), or the spec conflicts with code: **STOP, change nothing, report with an evidence table** (the PERF-9 W1 stop is the model — it was correct and praised in the ledger).
0.4 **The executor NEVER touches `FIX_VERIFICATION.md`.** This rule is in-file on purpose: PERF-9's patch lived only in chat and both windows violated it. Your deliverables live under `tool_perf2/t78_*` + a paste-ready `## APP COMPLETION …` block in the report (§5).
0.5 **Territory exclusivity.** Edit only files named in the Phase territory (§2) plus documented red→green fix fallout. Cross-territory findings = handoff note, not a drive-by fix. Forbidden everywhere: `pubspec.lock`, `*.g.dart`/`*.freezed.dart` (regenerate, never hand-edit), `isar.dll`, `.dart_tool/`, `functions/package.json` (no new dependencies — freeze zone), `apps/halal_boyz/**` (shell untouched), `HALAL_BOYZ_COMPLETENESS.md` (coordinator), `FIX_VERIFICATION.md` (coordinator).
0.6 **Do not re-derive receipted facts.** The ledger (`FIX_VERIFICATION.md`) already holds verified findings. Cite the receipt (`LEDGER:PERF-x`), spend your effort on the never-scouted territories. Re-deriving is waste; contradicting a receipt requires evidence and goes in your findings as DRIFT.
0.7 **Baseline discipline.** `git merge --ff-only main` must land you on the §1 tip. Verify clean tree, run the blocker gate BEFORE any edit.
0.8 **Unattended-run discipline (the user is asleep).** Never block on a question. Where a decision would normally be asked: choose the **fail-safe** option, implement it, and record it in the report's **DECISIONS-NEEDED-FROM-OWNER** section (a §0.3 blocker — spec-vs-code contradiction — is the only thing that may stop a phase). **Commit + push after each phase** (outage protection; push via a timeout'd background job — the repo's known credential-prompt trap — and continue locally if push stalls; retry once at the very end). The branch tip must be GREEN at all times: if a gate stays red after 3 honest attempts, restore the last green state for that change, record the failure in the report, and continue with remaining work — never end the session on a red tip.

## §1 Baseline (verified by coordinator; spec committed at `5dcd4a8`)

- Baseline tip: **`5dcd4a8`** = `origin/main` (contains `34e6c36` = closure + COMPLETENESS matrix, plus this spec). Gates at baseline: core_app **1921**, core **291**, core_ui **90**, shell **56**, rules **174/0**, functions **75**, analyze ×4 clean, format 0 changed, coverage **86.56%** (8112/9372). Feature floors from `HALAL_BOYZ_COMPLETENESS.md` §3.
- Executor sync: work in `<repo>-worktree` on branch `cline/task-1` (keeps the main worktree clean for the coordinator). After `git merge --ff-only main`: **`git merge-base --is-ancestor 0b4fec3 HEAD` must exit 0** (the floor — main contains the final spec) AND **HEAD must equal the `PERF10-TIP=` hash stated in the dispatch prompt** (the coordinator states it at dispatch, after any final spec amendment — this avoids the self-reference regress where amending the spec moves the tip the spec pins). If either check fails, STOP and report (§0.3). Blocker gate before any edit: `flutter pub get`, `flutter analyze --fatal-infos` (core_app) + `dart analyze` (packages/core, packages/core_ui) all exit 0, `dart format --output=none --set-exit-if-changed .` → 0 changed.

## §2 Phases (sequential, ONE session)

| Phase | Content | Territory |
|---|---|---|
| **A — T-7 read-only audit** | `core_app/functions/**` (src + test; package.json READ-only), `core_app/firestore.rules` (full clause sweep), `core_app/storage.rules`, `core_app/tool/**` (whitelabel, deploy tooling, seeds, migrations). Anomalies fixed ONLY via §3.3 protocol. Plus the allergen decision memo (§3.4). **Commit + push at end of Phase A.** | functions + rules + storage + tool |
| **B — T-8 mutation run + straggler sweep** | Hand-rolled bounded mutation harness (§4.1–4.3) + direct tests for the 3 WIRED-UNTESTED files + location feature ≥85% (§4.4). Mutant manifest is built against the **post-Phase-A tree**. **Commit + push at end of Phase B.** | `tool_perf2/t78_mutants/`, Dart/TS money-path files + their test files, `core_app/lib/app/presence_lifecycle_observer.dart`, `packages/core/lib/src/services/cloudinary_upload_service.dart`, `packages/core/lib/src/utils/json_converters.dart`, `core_app/lib/features/location/**` + their test dirs |

## §3 Phase A — T-7: read-only audit of the never-scouted territories

### 3.1 Scope and method

Deep-read each territory ONCE, exhaustively, with receipts. For every claim: P1 (file:line opened this session). Output tables go in `tool_perf2/t78_report.md` (§5):

1. **`functions/src/index.ts` (~1900 lines) + sibling modules** — build the callable table: for EVERY exported callable / trigger / scheduled fn: name, auth posture (is `context.auth` enforced? role checks?), App Check posture, money-touch (y/n), error posture (fail-closed or silent on bad input?), idempotency/replay behavior. Specific attention: `createPaymentIntent` / `createOrder` / `calculateTax` / `applyPromo` / `cancelOrder` / `stripeWebhook` (signature verify fail-closed — re-verify P1) / `deleteUserData` / `exportMyData` (GDPR completeness: every collection the client writes is covered?) / `recoverAbandonedCarts` / role-claims sync. Also: server-side re-derivation (client totals never trusted), demo-mode separation, the tax fallback table's fail-closed unknown-state throw (re-verify, cite).
2. **`firestore.rules` FULL clause sweep** — every `match` block → posture table (read/create/update/delete × helpers × shape locks). Hunt: over-broad writes on personal-data surfaces, missing ownership clauses, ordering bugs (most-specific shadowed by generic), inconsistent App-Check posture between sibling surfaces (the known carts-style gap class — find any remaining).
3. **`storage.rules`** — same posture table (uploads: who, what path shapes, size/type limits?).
4. **`core_app/tool/**`** — generator `validate()` vs what it emits (schema-identity test is a receipt — cite it; look for validate gaps: runtime-read config keys not validated, emitted files missing from the identity test); `deploy_backend.dart` preflight gates; seed scripts (creds fix from PERF-6c — verify P1); migrations bundle-separation claim (v001–v003 never deployed — verify P1).

### 3.2 Do-not-re-derive list (cite the receipt, move on)

`LEDGER:PERF-6d` defineSecret fail-closed · `LEDGER:PERF-8 W1` tenancy = project-per-client (the clientId-premise falsification) · `LEDGER:PERF-4` deploy runbook + docs-only scope · `LEDGER:PERF-6b/9` taxRates + menu_overrides + waitlist_meta rules lanes (proven this month) · `LEDGER:PERF-6c` seed creds fix · W6.5 generator schema-identity test. Contradicting any of these requires evidence and goes in the report as DRIFT.

### 3.3 Anomaly-fix protocol (the ONLY production edits allowed in Phase A)

A verified ANOMALY (P1 + explained impact) on money/auth/data may be fixed in-territory, but ONLY red→green: rules anomaly → failing pin FIRST (`firestore_rules_test.js`, `npm run test:rules`, capture the red log), then the clause, then green. TS anomaly → failing test in `functions/test/` first (targeted run), then the fix. Logs under `tool_perf2/t78_phaseA_*.log`. Cosmetic/style findings are NOT fixes — report only.

### 3.4 Allergen decision memo (owner decides; you only cost it)

`allergenDisclaimerEnabled` is parsed/set/persisted but renders nothing (its only renderer was deleted as dead code — `LEDGER:PERF-9 W1`). Deliver `tool_perf2/t78_allergen_memo.md`: Option A (wire the banner: renderer + plumbing + tests, est. effort, blast radius incl. generator mirror) vs Option B (remove the key: config schema + generator `validate()` mirror + tests, est. effort), a recommendation with reasoning, and an explicit "decision: OWNER".

## §4 Phase B — T-8 mutation run + straggler sweep

### 4.1 Harness contract (hand-rolled, ZERO new dependencies — `functions/package.json` is forbidden)

`tool_perf2/t78_mutants/` contains: `manifest.json` (array: `{id, file, class, search, replace, rationale, targetTestCmd}`), `run_mutants.ps1` (per mutant: assert `search` occurs EXACTLY ONCE in the file → apply → run `targetTestCmd` with a 120s timeout → record `KILLED` (targeted tests fail) / `SURVIVED` (pass) / `UNRESOLVED` (timeout/harness error + reason) → `git checkout -- <file>` → assert clean). Idempotent; tree clean after every mutant. Commit harness + manifest + receipts.

### 4.2 Mutant budget and classes

Manifest built against the **post-Phase-A tree**. Minimums: **≥12 mutants in `functions/src`** (money authority: amount derivation, tax fallback/clamp, promo clamp, order total re-derivation, idempotency-key handling, cancel ownership/precondition, webhook signature/event branch, GDPR delete scope) and **≥8 in core_app Dart money path** (`checkout_service.dart`, tax state-code normalization in `core_app/lib/app/config/tax_rates_repository.dart`, `cart_validator_service.dart` isAvailable gate, `reservations_repository.dart` decrement clamp/precondition + party-size guard, price-cents guard). Every mutant cites file:line + rationale (no blind spray). Operator classes (≥4 used): BOUNDARY (`>=`↔`>`), COMPARISON-FLIP, GUARD-REMOVAL, CONSTANT-CHANGE, ORDER-SWAP, SIGN. Targeted suites ONLY — single test file per mutant (TS runner discovered from `functions/package.json`, P1; Dart e.g. `flutter test test/features/checkout/domain/checkout_service_test.dart`). **Never the full suite per mutant.**

### 4.3 Survivor disposition (no unexplained survivors)

Every SURVIVED mutant: (a) add a killing test — proof = the new test FAILS with the mutant applied, PASSES without (both logs) — or (b) PARK with a written reason (equivalent mutant / redundant with a named server-side layer). Report the kill-rate table + the one-sentence defensible metric for the ledger ("N/M named money-path mutants killed; survivors dispositioned").

### 4.4 Straggler sweep

Direct behavioral tests for the 3 WIRED-UNTESTED files: `core_app/lib/app/presence_lifecycle_observer.dart` (read its real contract first; simulate lifecycle transitions; assert writes/teardowns), `packages/core/lib/src/services/cloudinary_upload_service.dart` (config-gating + pure parts; HTTP only via an existing injected-client seam — adding a minimal constructor seam is allowed as documented red→green fallout), `packages/core/lib/src/utils/json_converters.dart` (round-trips + malformed-input paths). Plus: location feature 78.1% → **≥85%** (`core_app/lib/features/location/**`, 64 lines — read the uncovered lines from lcov first, test those branches). Suites stay green; no existing test weakened.

## §5 Acceptance + the one report

Final tip must be green: analyze exit 0 (core_app `--fatal-infos`, `dart analyze` core + core_ui, shell untouched) · format 0 changed · suites: core_app ≥1921+new / core ≥291+new / core_ui ≥90+new / shell 56 untouched / rules ≥174 (+ any Phase-A pins) / functions 75 (+ any Phase-A tests) · coverage: location ≥85%, aggregate ≥86.56% (no drop), the 3 straggler files now carry direct suites (or documented PARK with reason — but prefer tests) · forbidden-path grep 0 · skip/TODO greps 0 in new code.

`tool_perf2/t78_report.md` (the ONE deliverable the user reads after waking):
1. Phase summaries (A then B) — what was examined, what was found.
2. The audit tables (§3.1) with P1 receipts.
3. Anomalies found → disposition (fixed red→green w/ log paths | reported-only + why).
4. Mutation kill-rate table + survivor dispositions + harness/manifest paths.
5. Straggler + location receipts (before/after coverage).
6. **DECISIONS-NEEDED-FROM-OWNER** (every fail-safe default you chose, the allergen memo pointer, anything you'd have asked).
7. **UNVERIFIED** (mandatory, non-empty allowed; what would settle each).
8. DRIFT (spec-vs-code corrections, with evidence).
9. **Paste-ready `## APP COMPLETION PERF-10 (T-7+T-8) - … - VERIFICATION REPORT` block** — the coordinator appends it to the ledger verbatim after judging.

## §6 Coordinator protocol (main session — NOT the executor)

On report-back: judge (re-run gates; spot-check ≥3 mutants + ALL survivors + ALL red→green proofs; verify no forbidden files touched), merge `cline/task-1`, full battery on merged main, append the ledger block, update `HALAL_BOYZ_COMPLETENESS.md` §4 (stragglers/location resolved), then evaluate the **freeze criterion** (WHITE_LABEL_p09_perf9.md §8): zero open findings + floors met + only ship-blockers remain → **declare FREEZE** in the ledger with the date and tip, or list the exact named residuals that still block it.

## §7 Executor quickstart (paste into the one screen)

```
You are the SINGLE EXECUTOR of PERF-10 (T-7 + T-8), the final pre-freeze wave.
Working dir: <repo>-worktree (branch cline/task-1). The user is asleep — §0.8 applies: never block on a question; fail-safe defaults + record them.

1. Read <repo>\WHITE_LABEL_p10_t78.md IN FULL — it is the binding contract.
2. git merge --ff-only main  → verify: git merge-base --is-ancestor 0b4fec3 HEAD (exit 0) AND HEAD equals the PERF10-TIP hash in the dispatch prompt; either fails → STOP and report (§0.3).
3. Blocker gate (§1): pub get + analyze --fatal-infos + format check, all green BEFORE any edit.
4. Phase A (§3): T-7 audit — functions/src, full rules sweep, storage.rules, tool/. Audit tables + allergen memo.
5. Commit + push Phase A. 6. Phase B (§4): mutation harness + ≥12 TS/≥8 Dart mutants + survivors + straggler tests + location ≥85%.
7. Commit + push Phase B. 8. Write tool_perf2/t78_report.md per §5 (incl. paste-ready ledger block).

Forbidden: FIX_VERIFICATION.md, functions/package.json deps, pubspec.lock, generated files, apps/halal_boyz/**, new test deps.
Definition of done: every §5 acceptance item green, report written, branch tip green, nothing left uncommitted.
```
