# CARNAMA LABS — APP COMPLETION: WHITE-LABEL EXECUTION DRIVER (RELEASE-2 successor)

**Read this index + the ONE batch file you are implementing. Never load all batch files at once.**
**Purpose:** the 32-batch remediation fleet (see `PRODUCTION_FIX_BATCHES.md`) fixed and proved the code. This phase CLOSES THE 3 GAPS the remediation could not (architecture, coverage, deployment) — see `PROJECT_STATUS.md` §4 for the verified gap analysis.

---

## 0. RULES THE EXECUTING AGENT MUST FOLLOW (inherited from the remediation driver — same gates, same discipline)

1. **Codebase-only truth.** Verify every cited `file:line` against current source before editing. Record drift in the batch addendum.
2. **No stubs / no fake success / no TODOs / no `@Skip` / no `skip:`.** Every test asserts a real outcome on real production code.
3. **No new runtime dependencies** except sanctioned ones (recorded per batch in its spec). Anything else requires a stopping ledger note.
4. **Mirror rule.** A fix is DONE only in template + shell + backend (where applicable). DEFAULT = regenerate via `core_app/tool/whitelabel.dart`; hand-mirror with a ledger note only where the generator doesn't own the file.
5. **Fail-closed over fail-open** for money, auth, GDPR, security.
6. **One batch per session.** End on a green gate set, append the addendum to `FIX_VERIFICATION.md`, then start the next. **Worktree clause (2026-09-11 amendment):** separate git worktrees MAY run this fleet's batches concurrently or on separate machines, ONLY under `## 3.5 WORKTREE EXECUTION + MERGE-BACK PROTOCOL` + `## 3.6 WORKTREE TERRITORY MAP` (restrictions: blocker gate before any move, per-worktree ledger files, file-disjoint territories, predecessors-DONE-in-main, rolling merge-back, post-merge gate re-runs on main). Any run not conforming to §3.5 defaults back to strict sequential single-tree execution.
7. **Conventions:** Riverpod DI, `RouteNames`, `FirebaseExceptionMapper.map`, `if (!mounted) return;`, integer cents, ARB l10n (en+ar parity), `unawaited()`.
8. **Prohibited:** editing `isar.dll`, hand-editing `pubspec.lock`, `node_modules`, `*.g.dart`/`*.freezed.dart` (regenerate), `.dart_tool/`/`build/`.
9. **Test-addition policy.** Each batch implements its spec's T-x table as NEW real tests. Cross-territory holes = handoff notes, never fixed cross-territory.
10. **Never hand-edit a generated shell's structure** (`apps/*/lib` beyond what the generator emits). The migration batches (ARCH-*) are the ONLY exception — they are scoped to restructure the generator + shell, and they land in the generator template FIRST (Rule 4: template before shell).

# __WL_INDEX_2__

---

## 1. UNIVERSAL GATE SET U (same as remediation — inherited verbatim)

- **U-ANALYZE** — `flutter analyze --fatal-infos` (core_app, apps/halal_boyz) + `dart analyze` (packages/core, packages/core_ui) → No issues found.
- **U-TESTS** — batch test suite GREEN; skip-grep → 0.
- **U-FORMAT** — `dart format --output=none --set-exit-if-changed .` (repo root) → exit 0.
- **U-GREPS** — G0 within batch scope (same list as remediation index §1).
- **U-REPORT** — append addendum to `FIX_VERIFICATION.md` (`## APP COMPLETION <BatchTag> - <title> - VERIFICATION REPORT`).
- **U-TRUTH** — the code is the judge.

---

## 2. ENVIRONMENT

Same toolchain as remediation (Flutter 3.41.2 / Dart ^3.11 / node v24 / Java 21 / Firebase CLI 15). ARCH-1 additionally requires the emulator running for flow verification (`firebase emulators:start` + seed from `core_app/tool/seed_demo_data.js`).

---

## 3. BATCH MAP

| Batch spec | Tag | Title | Master | Predecessor | Emulator |
|---|---|---|---|---|---|
| `WHITE_LABEL_b01_arch1.md` | ARCH-1 | Shell imports real screens (path dep + barrel + placeholder deletion) | PROJECT_STATUS §5-Gap1 | RELEASE-2 | yes (flow verify) |
| `WHITE_LABEL_b02_arch2.md` | ARCH-2 | Shared app body: parameterized `initCarnamaApp()` + shell calls it | PROJECT_STATUS §5-Gap1 | ARCH-1 | yes (boot verify) |
| `WHITE_LABEL_b03_cov1.md` | COV-1 | Coverage: kitchen + splash + promo_code (thin areas) | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b04_cov2.md` | COV-2 | Coverage: driver + onboarding + tour | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b05_cov3.md` | COV-3 | Coverage: home + waitlist + location | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b06_cov4.md` | COV-4 | Coverage: auth + loyalty | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b07_cov5.md` | COV-5 | Coverage: admin dashboards integration tests | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b09_corecov.md` | CORE-COV | Coverage: packages/core (20 modules/51 src files, 14 untested) + core_ui theme chain | PROJECT_STATUS §5-Gap2 | RELEASE-2 | no |
| `WHITE_LABEL_b10_tokens.md` | TOKENS | Design token system (typography split, shape, component themes, animation intensity) | playbook §8A + halal_boyz UI spec | ARCH-1 | no |
| `WHITE_LABEL_b08_release2.md` | RELEASE-2R | RELEASE-2 re-run on the final tree (OVERALL verdict) | RELEASE-2 spec | ALL | yes |

---


---

## 3.5 WORKTREE EXECUTION + MERGE-BACK PROTOCOL (2026-09-11 amendment — the white-label fleet's worktree system; single-tree runs follow §0/§1 unchanged)

**Purpose:** let separate git worktrees (or clones) run this fleet's batches — in parallel where territories are disjoint, sequentially where they are not — without breaking the ledger, the predecessor gates, or the generator's template-before-shell mirror rule. Modeled on `PRODUCTION_FIX_BATCHES.md` §3.5/§3.6 (the proven remediation protocol).

### 3.5.1 THE BLOCKER GATE — run BEFORE any move (fail-closed)
An executing agent claims a batch ONLY after every check below passes. Any blocker ⇒ the agent does **NOT** start the batch: it either (a) syncs if the blocker is a stale worktree, (b) moves to the next eligible batch in §4's order, or (c) reports the blocker and STOPS. Never fake a green, never fabricate work for an idle worktree, never widen scope to dodge a blocker.

| # | Check | How to verify | On blocker |
|---|---|---|---|
| B-1 | **Predecessors-DONE-in-main** | Every `Predecessor:` row of the claimed batch (from §3) has its addendum in `FIX_VERIFICATION.md` **on `main`** (not just in some branch) | Batch is not eligible yet — pick another eligible batch or wait for the merge-back |
| B-2 | **Territory free** | §3.6 collision ledger: no OTHER running worktree owns a file set intersecting the claimed batch's evidence/territory files. Mechanical: `git diff --name-only main...<otherBranch>` vs the claimed territory — zero shared paths | Not pool-eligible together — serialize (wait for the other window's merge) or pick a disjoint batch |
| B-3 | **Worktree clean + synced** | `git status --short` empty (no uncommitted work); `git merge main` clean (or fast-forward). At a declared §3.6 sync point the merge is MANDATORY before starting | Commit or stash nothing half-done; resolve the sync first, then re-run this gate |
| B-4 | **Gates green after sync** | On the synced worktree, before the first edit: `flutter analyze --fatal-infos` (touched packages) + `dart format --output=none --set-exit-if-changed .` (repo root) — exit 0. A red gate AFTER a sync means main moved under the batch ⇒ STOP, record the edge in the batch addendum, re-serialize | Fix-forward only if the breakage is inside the batch's own territory; otherwise report + stop |
| B-5 | **Emulator lane free** (emulator-gated batches only — §3 map) | `firebase emulators:exec`/`emulators:start` is serial GLOBALLY: verify no other window is running an emulator suite; stagger, or give each worktree its own emulator ports in its own `firebase.json` | Stagger with the other window, or defer the emulator-gated flow phase until the lane frees (record the deferral) |

### 3.5.2 Per-worktree execution loop
1. **Bootstrap** — the five worktrees ALREADY EXIST on this machine (the remediation fleet's layout; verify with `git worktree list`):
   `<repo>-worktree..5` on branches `cline/task-1..5`. Fast-forward all five onto updated `main` before each batch:
   ```cmd
   git -C <repo>-worktree merge main & git -C <repo>-cline-2 merge main & git -C <repo>-cline-3 merge main & git -C <repo>-cline-4 merge main & git -C <repo>-cline-5 merge main
   git worktree list
   ```
   (A missing worktree is re-created as `git worktree add <repo>-cline-N -b cline/task-N`.)
   Then, in-tree, before the batch: `flutter pub get` (the workspace resolves all members; ARCH-2's boot verify additionally verifies `firebase --version` and the §2 toolchain).
2. **Implement** the ONE batch spec (§0 rules unchanged — codebase-only truth, no stubs, mirror rule, prohibited edits).
3. **Gates** = Universal Gate Set U (§1) + the batch's proof gates, run INSIDE the worktree.
4. **Addendum** goes ONLY to `FIX_VERIFICATION_cline-task-N.md` in ITS worktree (never the shared `FIX_VERIFICATION.md`, never this index — **index + shared-ledger edits are single-writer on main**).
5. **Commit** in the worktree (one commit per batch, everything included):
   `<type>(<scope>): <BATCH-TAG> <imperative one-liner>`
   e.g. `test(core_app): COV-3 home + waitlist + location coverage suite` · `feat(shell): ARCH-2 parameterized initCarnamaApp() + generator template mirror` · `docs(ledger): cline/task-3 addendum`. Body: 3–6 bullets — what changed, the exact proof-gate numbers, spec ref (`Refs: WHITE_LABEL_b03_cov3.md`). No WIP commits on `cline/*` branches; a red-gate commit never merges.

### 3.5.3 Merge-back (rolling — after each worktree's batch is DONE + committed + its addendum written)
From `main` (single-writer machine):
```cmd
cd /d <repo>
git merge cline/task-1
git merge cline/task-2
```
- Merge in the order §3.6 declares (ARCH-2 first; then pool windows in any disjoint order; windows never wait for the whole fleet, only for their named sync points).
- No shared files ⇒ clean merges expected. **If a conflict appears: STOP, resolve manually with the code as judge, record the resolution in the addendum — never force-resolve a real content conflict with `-X`.**
- **Reconcile ledgers in the same commit:** append each `FIX_VERIFICATION_cline-task-N.md` addendum into the canonical `FIX_VERIFICATION.md` (order = merge order), then delete the per-branch ledger files.
- **Post-merge gate re-run on `main`** BEFORE the next batch starts (the ARCH-1 precedent): `flutter analyze --fatal-infos` (core_app + touched apps) + `dart analyze` (touched packages) + `dart format --output=none --set-exit-if-changed .` + the touched packages' `flutter test`. A red main ⇒ fix on main before anything else moves.
- Fast-forward idle worktrees off updated `main` before their next batch (`git -C <worktree> merge main`).

**Batch-end cadence (MANDATORY — merges and commits happen AS batches end):** a batch ends ONLY through the five-step cadence — Gate Set U green → addendum to the per-worktree ledger → `git add -A && git commit` in the worktree → `git merge cline/task-N` into `main` (its declared merge-order slot; W1/ARCH-2 first) → post-merge gates green on `main`. **An unmerged batch is NOT DONE** — the ledger records merged batches only, and a finished batch never sits uncommitted or unmerged across sessions: the only thing it may wait for is its merge-order slot (W1 first).

---

## 3.6 WORKTREE TERRITORY MAP (the file-set partition for THIS fleet — governs B-2 eligibility; merge-order + per-worktree-ledger rules from §3.5 unchanged)

**Principle:** partition by batch chain (territory), not raw file sets — files touched by several chains become **sync points** (single-owner collision ledger below).

| Win | Territory (owns) | Chain (strict order) | Sync points (`git merge main` + gate re-run BEFORE starting) |
|---|---|---|---|
| 1 | Shell architecture + generator: `core_app/tool/whitelabel.dart` + everything it emits (shell `lib/**`, pubspec, l10n.yaml, emitted tests), `core_app/lib/labs.dart`, shared l10n ARB, shell android config | **ARCH-2** (ARCH-1 DONE in main) | none — W1 merges FIRST; every other window waits for it once (merge-back order, §3.5.3) |
| 2 | Kitchen + splash + promo_code tests (the spec's thin areas) | COV-1 | ← ARCH-1 DONE (relaxation below) |
| 3 | Driver + onboarding + tour tests | COV-2 | ← ARCH-1 DONE (relaxation below) |
| 4 | Home + waitlist + location tests | COV-3 | ← ARCH-1 DONE (relaxation below) |
| 5 | Auth + loyalty tests | COV-4 | ← ARCH-1 DONE (relaxation below) |
| 6 | Admin dashboards integration tests | COV-5 | ← ARCH-1 DONE (relaxation below) — **not emulator-gated** (§3 map: no) |
| 7 | `packages/*/test/**` (core modules/51 src files + core_ui theme chain) | CORE-COV | ← ARCH-1 DONE (relaxation below); core_ui theme-chain tests ← **TOKENS merged** (ledger below) |
| 8 | Design tokens: `packages/core_ui/lib/src/theme/**`, token surfaces in `core_app/config`, shell theme configs | TOKENS | ← ARCH-1 DONE for the PACKAGE-side tokens (relaxation below; map predecessor = ARCH-1); **shell-config token surfaces ← ARCH-2 merged** (generator owns those files) |

**Single-owner collision ledger (file → owning window; everyone else syncs first):** `core_app/tool/whitelabel.dart` + every generator-emitted shell file + `apps/halal_boyz/**` → W1 (ARCH-2; ARCH-1 already landed the template-gap handoff) · `core_app/test/features/<featureDir>/**` → the COV window owning that feature dir (two COV specs naming the same dir = NOT pool-eligible together — re-serialize) · `core_app/test/helpers/**` → any window may ADD disjoint helper FILES, never edit another window's helper · `packages/core/test/**` + `packages/core_ui/test/**` → CORE-COV · `packages/core_ui/lib/src/theme/**` + token surfaces → TOKENS (CORE-COV's theme-chain tests re-run after TOKENS merges) · `FIX_VERIFICATION.md` + `WHITE_LABEL_BATCHES.md` → single-writer on main.

**More windows than worktrees:** lower-priority windows stay idle — do NOT fabricate work (§0 rule 6). **Emulator discipline:** in THIS fleet only ARCH-2 (W1, `yes (boot verify)`) and RELEASE-2R (`yes`) are emulator-gated per the §3 map — the parallel pool (W2..W8) runs WITHOUT the emulator lane. The serial-lane rule (`firebase emulators:*` is serial GLOBALLY on one machine) binds W1's boot verify and the final RELEASE-2R run: never two emulator suites at once; stagger, or give each worktree its own emulator ports in its own `firebase.json`. Repo-wide `flutter test`/`analyze`/`dart format` gates are safe concurrently but will thrash a single CPU — stagger heavy suites when practical.

**START-eligibility relaxations (recorded amendment — mirrors the remediation fleet's §3.6):** COV-1..5, CORE-COV, and TOKENS's PACKAGE-side work may START once ARCH-1 is DONE in main — their per-spec `Predecessor: RELEASE-2` rows mark the PHASE boundary (the remediation fleet is complete), not file dependencies: their file sets are provably disjoint from the ARCH-2 chain (`core_app/tool/whitelabel.dart`, every generator-emitted shell file, `core_app/lib/main.dart`/`labs.dart`). TOKENS's map predecessor is ARCH-1 (not ARCH-2) by design — §4's "touches different files than ARCH-2". The carve-outs are HARD: (1) TOKENS's shell-config token surfaces and ANY generator-emitted file wait for ARCH-2 (collision ledger: `apps/halal_boyz/**` → W1); (2) CORE-COV's core_ui theme-chain tests re-run after TOKENS merges; (3) every window's merge-back waits for W1 (ARCH-2) first (§3.5.3). A real cross-territory dependency discovered at execution time: STOP fail-closed, record the edge, re-serialize — never fake a green.

**RELEASE-2R is NOT window work:** after the final merge it runs on `main` only (full battery + re-audit of the merged tree; its verdict is the only clearance authority).

## 3.7 ANOMALY HARVEST + POST-FLEET GUARANTEE (runs inside/after RELEASE-2R — the fleet's end-game)

**Principle:** every anomaly any batch ever recorded must end its life in exactly one of three states — **FIXED by a batch**, **OPERATOR-ACCEPTED with a runbook entry**, or the fleet verdict is FAIL. Nothing dies in a ledger footnote.

**§3.7.1 HARVEST → ANOM batches.** During RELEASE-2R, mechanically sweep the entire ledger (`HANDOFF|residual|drift|BUG|H-\d|does not exist|NOT IMPLEMENTED|owner decision`) plus every addendum's residuals section → dedupe into the PRODUCT GAP REGISTER (b08 bullet 5). Every **class-(a)** (code/test fix) and **class-(b)** (new feature) row MUST be spawned as an anomaly batch spec `WHITE_LABEL_anom_<NN>_<tag>.md` — standard skeleton (territory, acceptance contract, T-x table, gates, honest residuals) — executed through the SAME machine (Gate Set U, §3.5 cadence, one batch per session, ledger addendum). **Class-(c)** operator rows (config/deploy/history rewrite) cannot be code batches: they become RUNBOOK entries with exact steps and stay open until the operator closes them.

**§3.7.2 LOOP-TO-FIXED-POINT (the convergence guarantee).** After each ANOM wave merges, re-run the FULL RELEASE-2R battery on the new tip. New anomalies surfaced ⇒ harvest again ⇒ next ANOM wave. The fleet is DONE only at the **fixed point**: one full battery pass with ZERO new anomalies AND zero class-(a)/(b) rows remaining (every row fixed) AND every class-(c) row operator-accepted. Bounds: **max 3 harvest loops** — if loop 3 still surfaces anomalies, OVERALL verdict = FAIL naming the blockers (no infinite loop, no fake convergence). Each ANOM batch must strictly shrink the register; coverage-only work is not an ANOM batch.

**§3.7.3 THE A–Z ATTESTATION (what "guarantee" means here — honest form).** No agent can promise bug-free software; the fleet's guarantee is mechanical: **every claim is a rerunnable command, and the loop runs until the commands stop finding anything.** The final addendum appends the attestation matrix — one row per aspect: `aspect | proof command | result at final tip | ledger line`. Minimum rows: (A) analyze ×4 clean · (B) format 0-changed · (C) all suites green (core_app + packages + shell, 0 fail / 0 skip) · (D) skip/TODO greps 0 · (E) money: server re-pricing + tampered total DENIED · (F) auth: role gates all 4 roles · (G) GDPR: callable erasure + local wipe · (H) offline queue: Isar DLQ FIFO cap on both paths · (I) l10n en/ar parity · (J) a11y W9 suite green · (K) goldens 66 · (L) white-label: generator stamps a fresh client from config alone and boots REAL screens · (M) on-device boot · (N) flow driver 28/28 · (O) functions lint+tsc+test · (P) coverage number recorded · (Q) rules battery · (R) migration gates · (S) ledger complete in merge order · (T) gap register at fixed point · (U) operator items runbooked. **PASS only if every row's command exits 0 at the final tip — signed with the tip hash.**

---

---

## 4. EXECUTION ORDER

**ARCH-1 → ARCH-2 → COV-1..5 + CORE-COV + TOKENS (parallel, disjoint territories) → RELEASE-2R → §3.7 ANOMALY-HARVEST waves (ANOM batches) until the fixed point → §3.7.3 A–Z ATTESTATION signed at the final tip → PERF-1 → PERF-2 (post-fleet PERFECTION wave, operator-authorized 2026-09-14: register code-fixes H-1..H-4 + per-package coverage floors, then the core_app 80% campaign; specs `WHITE_LABEL_p01_perf1.md` / `WHITE_LABEL_p02_perf2.md` — §3.7.2 fixed-point deliberately reopened by this authorization, closes again when PERF-2's decision gate lands).**

| Batch spec | Tag | Title | Status | Note |
|---|---|---|---|---|
| `WHITE_LABEL_p04_perf4.md` | PERF-4 | CF deploy lane → OPERATOR RUNBOOK | **DONE (2026-09-15)** | Re-scoped pre-execution: CI Tier 8 already at HEAD → docs-only batch. Deliverable: `RUNBOOK_DEPLOY.md` (repo root, self-verifying §1 grep). |


COV/CORE-COV/TOKENS may run in parallel with each other (disjoint territories: COV-* = `core_app/test/features/*`, CORE-COV = `packages/*/test/*`, TOKENS = `core_ui/theme` + `core_app/config` + shell configs) under the §3.5/§3.6 worktree protocol. ARCH-1 and ARCH-2 are sequential (ARCH-2 depends on ARCH-1's barrel + path dep). TOKENS depends on ARCH-1 (shells inherit instantly) but touches different files than ARCH-2.

---

## 5. FILE LAYOUT

- Full gap analysis = `PROJECT_STATUS.md` (§4-§5: the three gaps, cures, timeline). Never duplicated.
- Execution index = THIS file (rules + gate set U + batch map + execution order).
- One spec per batch = `WHITE_LABEL_b<NN>_<tag>.md`. Each is self-contained: evidence table, design principle, acceptance contract, T-x test table, proof gates, honest residuals.
- The remediation ledger `FIX_VERIFICATION.md` is shared: each batch appends `## APP COMPLETION <BatchTag> - ...` (same discipline as the remediation fleet).

## 6. FLEET RUNBOOK — the remaining 9 batches, screen by screen (2026-09-11)

**Assignment (chains; §3.5 blocker gate + §3.6 territory govern every step):**
`cline-1: ARCH-2 → TOKENS` · `cline-2: COV-1 → COV-5` · `cline-3: COV-2 → CORE-COV` · `cline-4: COV-3` · `cline-5: COV-4` · `main: RELEASE-2R (last, main-only)`

**STEP 0 — main (once):** anchor-commit ARCH-1 (`git add -A && git commit`) → fast-forward all five worktrees (`git -C <repo>-cline-N merge main`). **STEP 1 — wave 1 (all 5 screens in parallel):** blocker gate B-1..B-5 → batch 1 of each chain → batch-end cadence; merges rolling, **ARCH-2 FIRST** (everyone waits for that one merge). **STEP 2 — wave 2 (screens free in finish order):** pull the backlog (cline-1→TOKENS · cline-2→COV-5 · cline-3→CORE-COV) → same cadence (ARCH-2 already in main). **STEP 3 — main:** after the LAST merge, RELEASE-2R = full battery + re-audit = the OVERALL verdict.

Per-screen commands live in the batch specs (§3.5.2 loop); the batch-end cadence (§3.5.3) is MANDATORY at every end. Emulator lane: ARCH-2's boot verify (wave 1) + RELEASE-2R only (§3 map).

## 7. WAVE p32+ REGISTRATION + ISSUE COVERAGE REGISTER (2026-10-04 — coordinator, post-p31 audit)

| Batch spec | Tag | Title | Status | Predecessor | Emulator |
|---|---|---|---|---|---|
| `WHITE_LABEL_p32_golden_gates.md` | GOLDEN-GATES | 6 void golden gates → real gates; re-baseline 3 stale; ops captures; hygiene pin | **DONE (committed `510d0228` · `816a020c`; receipts `tool_uilib/p32/` 75 files, census `gate_census_final.txt` TOTAL=66 VOID=0; ledger `## APP COMPLETION GOLDEN-GATES` appended 2026-10-09)** | none (merge slot FIRST) | no |
| `WHITE_LABEL_p33_config_deadkeys.md` | DEADKEYS | Flag truth pins, dead-key dispositions/wirings, tax-quote cap, doc-drift fixes, rules-suite receipt | **DONE (executed on worktree `p33/config-deadkeys` `e24f949b`; merged `b93d52ac` + p33×p37 sync `2654d9d6`)** | p32 (goldens) | T-5 only |
| `WHITE_LABEL_p34_e2e_seed.md` | E2E-DEVICE | 23 `integration_test/` suites on emulator (tags defined) | **DONE (committed `c27e7955`·`302d53a8`·`3c4f05d4`·`03cc3f81`, device emulator-5554 16 KB; full battery 22/22 green this pass, v13/v15/waitlist all fixed; 26/26 e2e files tagged; 2 env-bound cold-start benchmarks recorded; ledger `## APP COMPLETION E2E-DEVICE` appended 2026-10-14)** | p32+p33 | yes |
| `WHITE_LABEL_p35_theme_engine.md` | THEME-V2 | Visual-perfection foundation: DESIGN.md guardrail, AppSpacing scale, `theme.shape.style` preset (sharp/soft/round/pill); generator parity | **DONE scope A (committed `c804fe56`·`502d432f`·`93f7ab41`·`d17bcea0`·`dced327c`·`0d969e3f`; battery `tool_uilib/p35/T-5_battery.txt`: format 0, analyze×4 clean, core_ui +454 / core_app +2529 / core / halal +77 / tool +243 / functions 172, dry-run 0, zero golden drift). Deferred p35-B.1 spacing migration (D-P35-1), p35-B.2 nav 5+More, p35-C preset gallery, p35-D layout variants. **Scope B B-1 SHIPPED (commits `f1cc5464`·`65eb012e`·`edadfbad`·`c641e9b4`; battery `tool_uilib/p35/battery.txt`: all gates green, zero golden drift): `theme.depth` preset (flat/soft/elevated) on the 5 flat card/tile surfaces + generator fail-closed + AppDepthTokens. B-2/B-3 (designed dark surface ramp + AA-on-dark) DEFERRED (D-P35-2 — visual audit `tool_uilib/p35/VISUAL_AUDIT.md`: dark shallow-but-functional, not broken). Spec `WHITE_LABEL_p35_depth_dark.md`** | p33 | no |
| `WHITE_LABEL_p36_generator_grade.md` | GEN-GRADE | `whitelabel.dart` production-grade: stamp gates (identity/branding/analyze/49 emitted tests/APK), template parity, fail-closed flutterfire, icon/splash surface | **DONE (pushed `ee3d8b5f` · `13e2fe72` · `623d7bdf`)** | p32/p34 branch work | T-5 only |
| `WHITE_LABEL_p37_nine_push.md` | NINE-PUSH | 9/10 push: AA contrast (T-1), six-flag wiring w/ D-P37-1 (T-2), currency seed (T-3), inverse-matrix config honesty (T-4), deploy runbook (T-5) | **DONE (committed `61bbefdb` · `4196080b` — push pending owner approval)** | p36 | no |

**Issue coverage register** — every open finding from `tool_uilib/p31/p31_proof_report.md` + this session's research has exactly one owner:

| # | Issue (proof-report ref) | Owner |
|---|---|---|
| 1 | 6 void golden gates + 3 stale baselines + time-fragility (§Q11 N-1) | **CLOSED (p32 T-1/T-2 — `510d0228`: 6/6 VOID→`await expectLater`; reds `tool_uilib/p32/red_t1_stale_*` + R1/R2; verdict-scoped re-baseline of manager+owner, green ×2 `green_t2_twice.txt`; census `gate_census_final.txt` TOTAL=66 VOID=0)** |
| 2 | No visual truth for ops dashboards (§Q8) | **CLOSED (p32 T-3 — `510d0228`: `tool_uilib/p32/ops_captures/{owner,manager,kitchen}_dashboard.png` captured with real fonts and committed; harness green in default suite)** |
| 3 | Void-gate regression protection | **CLOSED (p32 T-4 — `510d0228`: `core_app/test/ui/golden_gate_hygiene_test.dart` fires on planted sync-expect (`red_t4_plant.txt` EXIT=1) → green at HEAD (`green_t4_plant.txt` EXIT=0); re-verified green at p37 tip 2026-10-09)** |
| 4 | Config dead keys + both Dart flag surfaces inert (§Q3, §Q4-corrected) | **CLOSED (p37 T-2/T-4 — `bcbb2a93`·`e7c00d96`: six flags wired through FlagGate with per-flag absent-when-false tests; inverse config matrix + fail-closed validate() on unknown keys)** |
| 5 | `calculateTax` quote upper bound (§Q3-3, §Q10-3) | **CLOSED (p33 T-3 — `e24f949b` merged `b93d52ac`: `.max(100_000_000)` at `index.ts:142` + `tax_quote_cap.test.js`; re-proven 172/172 on merged tip)** |
| 6 | RUNBOOK §4.1 seed-residual is STALE (code fixed PERF-6c) + proof-report Q10-2 | **CLOSED (p33 T-4 — `e24f949b` merged `b93d52ac`: `RUNBOOK_DEPLOY.md:117` rewritten to PERF-6c env→ADC→fail-closed truth + p31 proof-report Q10 mirror)** |
| 7 | Rules-suite local UNVERIFIED (§Q10) | **CLOSED (p33 T-5 — `tool_uilib/p33/rules_suite_local.txt`: PASSED 209 / FAILED 0 / EXIT=0, local emulator 2026-10-06; rules paths untouched since)** |
| 8 | 23 e2e suites never run (§Q9) | **CLOSED (p34 E2E-DEVICE — `c27e7955`·`302d53a8`·`3c4f05d4`·`03cc3f81`: full per-suite device battery on emulator-5554, 22/22 green this pass; v13 guest hang root-caused (user.delete() wedges native auth queue) + fixed; v15 8/8 vectors; 26/26 e2e files tagged; 2 env-bound cold-start benchmarks recorded, assertions not relaxed; ledger `## APP COMPLETION E2E-DEVICE`)** |
| 9 | Theme Engine v2 / epic per-client UI / icon+splash stamping / nav redesign (§Q2, §Q3-2) | **p35** (owner scope) |
| 10 | GitHub 92 commits ahead, unreachable; CI-ubuntu golden parity; untracked `.impeccable/` + `WHITE_LABEL_p27_constitution.md` | **P32a coordinator ops at first CLOSE** (§Q6) |
| 11 | Deploy lane: Blaze, Stripe, migrations, seeds, App Check, per-client backend | `RUNBOOK_DEPLOY.md` §3 (operator — not a batch) |
| 12 | Freeze criterion (numeric) | **DECLARED (coordinator 2026-10-14): issues 1–8 all CLOSED — remediation fleet frozen. p34 E2E-DEVICE closed the last open code issue (#8). Release work #11 (deploy lane) and theme epic #9 (p35) remain, outside the freeze line.) |

**END OF INDEX — load a batch spec file per session.**

