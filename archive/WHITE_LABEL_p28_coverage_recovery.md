# WHITE_LABEL_p28 — coverage recovery (coverage_floor.ps1 → exit 0, on merit)

**Scope, one line:** take `powershell -File tool_fix/b7/coverage_floor.ps1` from exit 1
(12 violations, ALL pre-existing at base — `tool_uilib/p27/receipts/g_coverage_floor_final.txt`
+ p27 findings A1) to exit 0 by covering REAL code, with zero regression of anything p27 left
green; every floor pin is immutable (DECISIONS_LOG D-p27-4, PATH A).

Spec file = the acceptance contract (METHOD §1). Coordinator-written 2026-10-01, the same day
D-p27-1..4 were ratified in `DECISIONS_LOG.md`. Execution starts only once this file is
accepted; the executors work inside it, never around it.

## §0 Rules (binding for this batch)

1. `METHOD.md` is the source of truth — cite it, do not restate it. This file encodes only what
   is batch-specific.
2. Every claim in the deliverable is **P1** (file:line opened in the executing session) or
   **P2** (a test/gate that fails if the claim is false). Everything else goes in a mandatory,
   non-empty **UNVERIFIED** section.
3. Every fix ships **red→green**: capture the failing proof BEFORE the fix. The T-1 red proofs
   already exist and are citable, not re-runnable history: `tool_uilib/p26/receipts/
   t9_guard_tdd_red.txt` (5 precision tests failing + live gate) and `t9_guard_cli_red.txt`
   (`Constitution violations found: 73`). They prove the PROBLEM; they never prove a fix.
4. **No fake green**: no `// ignore:`, no `// ignore_for_file:`, no skip, no deleted check, no
   deleted pattern, no identifier renamed to dodge a matcher. A detector may only become *more
   precise* (word boundary, code-vs-comment, argument shape) when a planted-violation test
   proves it still catches every class.
5. Forbidden files (handoff notes only): `FIX_VERIFICATION.md` (ledger — coordinator-only,
   append-only), `AUDIT_TRIAGE_STAGE3.md` (register — coordinator), `firestore.rules`,
   `staging.firestore.rules`, `firestore.indexes.json`, `pubspec.yaml` + lockfiles, generated
   `*.g.dart` / `*.freezed.dart` / `*.arb` + gen-l10n output, `apps/halal_boyz/lib/**`
   (regeneration owns it), `.clinerules/**`, `.clineignore`.
6. Never end on a red tip (METHOD §2.7): if a gate cannot be made green, revert to the last
   green state, ledger the blocker with its evidence, stop.
7. Auth/security paths fail closed (METHOD §2.3). The T-3 refactor must be behaviour-preserving:
   each seam reads the same value at the same instant as the SDK call it replaces (call-time
   freshness stated per seam, see T-3).

## §1 Baseline + blocker gate

**Tip:** `main = b445ff35` at spec time (p27 findings close-out). This spec + the D-p27-1..4
ratification land as the `p28/29 T-0: ...` commit immediately after writing; a lane's SYNC
accepts any tip where `git merge-base --is-ancestor b445ff35 HEAD` is true and the history
contains the `p28/29 T-0:` commit. **Base of p27 was `822a4f88`; tip ≠ base is checked again
at judge time (METHOD §6).**

**BLOCKER (green BEFORE any edit) — cite, do not re-derive (METHOD §2.9), receipts in
`tool_uilib/p27/receipts/` (exit codes recorded inside each file):**

| Gate | Result | Receipt |
|---|---|---|
| `dart format --output=none --set-exit-if-changed .` | 0 changed, exit 0 | `g_format.txt` |
| `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) | 0 issues ×4 | `g_analyze_*.txt` |
| core_app / core / core_ui / halal suites | **2393 / 387 / 411 / 71**, 0 fail 0 skip | `g_test_*.txt` |
| functions lint / tsc / npm test | 0 / 0 / **169** pass, 0 fail | `g_functions_*.txt` |
| guards + detectors | ignore-guard PASS 35/0 · selftest PASS · hygiene PASS · detectors exit 0 | `g_guard_*.txt`, `g_detectors.txt` |
| constitution gates | `constitution_guard` → `All clean.` exit 0 · `verify_constitution` → `AUDIT PASSED` exit 0 | `t1_guard_cli_green.txt`, `t4_verify_cli_green.txt` |
| pipeline | `all 3 gates green` exit 0 | `g_pipeline.txt` |
| greps (core_app/lib) | package:firebase_auth 0 · FirebaseAuth.instance 0 · role == 0 | `g_greps.txt` |
| census | 0 new `@Skip`/`skip:`, 0 new `ignore_for_file` | `g_census.txt` |

**The RED this batch exists to fix — cite, do NOT re-derive the decomposition (METHOD §2.9):**

1. `g_coverage_floor_final.txt` — `coverage_floor.ps1` **exit 1, 12 violations**:
   - floor: `[core] lines 83.63% < 84.24%`;
   - 4 core_ui NEW files: `lib/src/ui/segment_selector.dart`, `lib/src/ui/tip_selector.dart`,
     `lib/src/ui/order_timeline.dart`, `lib/src/ui/brand_chart.dart`;
   - 7 core_app NEW files: `lib/l10n/app_localizations_ar.dart` (**generated l10n** — the only
     file T-5 exempts) + 6 owner tabs: `lib/features/admin/presentation/owner/tabs/`
     `owner_branches_tab.dart`, `owner_menu_tab.dart`, `branch_editor.dart`,
     `confirm_destructive_dialog.dart`, `menu_item_editor.dart`, `panic_switch_banner.dart`.
2. `g_test_core_coverage.txt` + findings **A6** — `push_notification_service_test` flake under
   `--coverage` only: `resetForTest()` (`packages/core/lib/src/network/push_notification_
   service.dart:60`) does not cancel/await in-flight notification echoes (cross-test echo race).
3. Findings **A1** — every violation predates p27: base core = 1500/1794 = 83.62% < 84.24;
   the 11 NEW files never appear in p27's diff. Ratified as D-p27-4 PATH A: recover on merit.

**Lanes measure coverage themselves** (`flutter test --coverage` in their worktree + direct
lcov arithmetic, receipted). **`coverage_floor.ps1` runs ONLY in <repo> on the merged
tip**, coordinator, after both lane merges (§6) — never in a lane worktree.

## §2 Territory (exclusive per lane; anything cross-lane = handoff note)

- **Lane A (executor 1):** `packages/core/{lib,test}/**` → T-1 (push-echo race: production fix
  + tests), T-2 (core floor recovery: tests only).
- **Lane B (executor 2):** `core_app/test/**` + `packages/core_ui/test/**` +
  `tool_fix/b7/coverage_floor.ps1` → T-3, T-4, T-5. Lane B never edits production `lib/` code:
  if a widget needs a seam to become testable, that is a handoff note, not an edit.
- **Coordinator-owned, immutable to BOTH lanes:** `tool_fix/b7/coverage_baseline.json`
  (D-p27-4 PATH A — no allowlist additions, no floor edits, no goalpost moves; `git diff
  tool_fix/b7/coverage_baseline.json` must be empty at judge time). `FIX_VERIFICATION.md`,
  `AUDIT_TRIAGE_STAGE3.md`, `DECISIONS_LOG.md` = coordinator-only.
- **Receipts:** `tool_uilib/p28/receipts/lane_a/<name>.txt` (Lane A) and
  `tool_uilib/p28/receipts/lane_b/<name>.txt` (Lane B); exit code recorded inside each file.
- **Forbidden (p27 §0 rule 5, unchanged):** ledger, register, `firestore.rules`,
  `staging.firestore.rules`, `firestore.indexes.json`, `pubspec.yaml` + lockfiles, generated
  `*.g.dart` / `*.freezed.dart` / `*.arb` + gen-l10n **output** (T-5 edits the *script's*
  exemption list — never the generated dart), `apps/halal_boyz/lib/**`, `.clinerules/**`,
  `.clineignore`.

## §3 Problems → Acceptance → T-x

| T | Lane | Problem (red, cited) | Task + acceptance (proof required) | Floor |
|---|---|---|---|---|
| T-1 | A | Push-echo race (A6): `resetForTest()` (`packages/core/lib/src/network/push_notification_service.dart:60`) leaves in-flight notification echoes running → cross-test contamination under `--coverage` | Make `resetForTest()` cancel/await every in-flight echo before returning — a real lifecycle fix. NO sleeps, NO `Future.delayed` waits, NO shuffling of test order (15-tests determinism). **RED** = reproduction receipt: run `flutter test --coverage test/push_notification_service_test.dart` (cwd `packages/core`) until it FAILS and save the failing output BEFORE the fix; if it will not fail in 5 runs, say so with the 5 run receipts and cite findings A6 (p27 observed fail/fail/pass) as the documented red — never fabricate one. **GREEN** = 5/5 CONSECUTIVE green receipts of the same command + full core suite 0 fail 0 skip | 5/5 + core suite |
| T-2 | A | `[core] lines 83.63% < 84.24%` (`g_coverage_floor_final.txt`) | Fresh `flutter test --coverage` in `packages/core`, parse lcov `DA:` zeros, write **real-behaviour tests** against the clusters until `LH/LF ≥ 84.24%`. Start with the 27 pre-existing uncovered `auth_repository.dart` lines (findings A1/rec-3), then the next-largest clusters. 15-tests rules apply: behaviour not implementation, unhappy paths (permission-denied, malformed payload, retry), NO padding, NO assertion-free or trivially-true tests. Allowlist untouched (§2). Receipts = lcov totals before/after + suite count | core ≥ 84.24%, core suite ≥ 387 |
| T-3 | B | 10 NEW files fail the fleet rule together (4 core_ui + 6 core_app) | **TIMEBOXED 45 min, BEFORE writing any T-4 test:** diagnose why 10 files fail together — likely ONE harness cause (shared pump/fixture/locale/theme setup). Record the outcome in the findings **either way**: confirmed single cause with evidence, or "no single cause within the 45 min" + what was ruled out. Receipt = diagnosis note (this bounds the T-4 design) | diagnosis recorded |
| T-4 | B | same 10 files, `LH<LF` | Widget tests (15-tests widget rules: loading/empty/error/permission states, interaction via taps, no leaks, text-scale bounds) drive **each** file to `LH==LF`: `packages/core_ui/lib/src/ui/{segment_selector,tip_selector,order_timeline,brand_chart}.dart` and `core_app/lib/features/admin/presentation/owner/tabs/{owner_branches_tab,owner_menu_tab,branch_editor,confirm_destructive_dialog,menu_item_editor,panic_switch_banner}.dart`. **0 goldens regenerated** (`git diff --name-only -- '*.png'` vs `b445ff35` = empty). Receipts = per-file LH/LF before and after | 10/10 files at 100% |
| T-5 | B | `lib/l10n/app_localizations_ar.dart` can never reach 100% — it is gen-l10n output (the `.arb` source is authoritative; the `*.arb`+gen-l10n output remain §0-rule-5 forbidden) | `tool_fix/b7/coverage_floor.ps1`: exempt **ONLY** the generated-l10n pattern `lib/l10n/app_localizations_*.dart` from the NEW-file rule — pattern-matched, not a hand-listed filename — with a why-comment (generated from `.arb`; wiring covered by existing l10n tests; generator output is not behaviour coverage). **Negative control receipt:** rerun with `-ReuseCoverage -Baseline <scratch copy>` whose allowlist omits one currently-under-100 NON-l10n file and prove the rule still FAILS on it (the rule must stay live for everything else). `coverage_baseline.json` byte-unchanged (`git diff` empty) | floor exit 0 (coordinator, merged tip) · baseline diff empty · control FAIL as expected |

## §4 Deliverable format (six-way classification, METHOD §2.1 + §3.5)

Each lane ships its own findings file — `tool_uilib/p28/p28_lane_a_findings.md`,
`tool_uilib/p28/p28_lane_b_findings.md` — with: (1) **Verified** P1/P2 table · (2)
**Unverified** mandatory + non-empty · (3) **Anomalies** (spec-vs-code evidence tables; code at
HEAD wins) · (4) **Untested** · (5) **Risks** · (6) **Recommendations**; then honest residuals
(what is NOT closed), a receipts index, and a paste-ready ledger block headed
`LEDGER:p28 (lane-a)` / `LEDGER:p28 (lane-b)` (the coordinator is the single ledger writer).
Commits local only, subjects `p28 T-N: ...`. NEVER push. NEVER edit `FIX_VERIFICATION.md`,
`AUDIT_TRIAGE_STAGE3.md`, `DECISIONS_LOG.md`, `coverage_baseline.json`.

## §5 Acceptance (measurable floors — every row must be green on the MERGED tip)

| Row | Floor | How measured |
|---|---|---|
| coverage floor | `powershell -File tool_fix/b7/coverage_floor.ps1` **EXIT 0** — core ≥ 84.24 % · core_ui ≥ 92.76 % · core_app ≥ 86.87 % · NEW-file rule clean | coordinator, fresh run (NO `-ReuseCoverage`) in <repo> on the merged tip — ONLY place it runs |
| push-flake | **5/5** consecutive green `flutter test --coverage test/push_notification_service_test.dart` + core suite green | Lane A receipts |
| format | `dart format --output=none --set-exit-if-changed .` 0 changed | live |
| pipeline | `dart tool/pipeline.dart` → `all 3 gates green` exit 0 | live |
| analyze | 4/4 = 0 issues (`flutter analyze --fatal-infos` core_app + halal; `dart analyze` core + core_ui) | live |
| suites | core_app ≥ **2393** · core ≥ **387** · core_ui ≥ **411** · halal ≥ **71** — 0 fail **0 skip** | live (default tier: `--exclude-tags=e2e,nightly,needs-emulator`) |
| functions | lint 0 · tsc 0 · npm test **169** pass 0 fail (p29 raises the floor with new tests) | live |
| guards + detectors | ignore-guard PASS (35 probes) · selftest PASS · hygiene PASS · anomaly detectors exit 0 | live |
| greps | `package:firebase_auth` 0 · `FirebaseAuth.instance` 0 · `role ==` 0 over `core_app/lib` | live |
| constitution gates | `constitution_guard` → `All clean.` exit 0 · `verify_constitution` → `AUDIT PASSED` exit 0 | live |
| census | 0 new `@Skip`/`skip:`, 0 new `ignore_for_file`, 0 new `// ignore` (beyond the guard's own pre-existing matchers) | live |
| goldens | 0 regenerated: `git diff --name-only b445ff35..HEAD -- '*.png'` = empty | git |
| floors immutable | `git diff b445ff35..HEAD -- tool_fix/b7/coverage_baseline.json` = empty (D-p27-4 PATH A) | git |

**p28 completion criterion (numeric, METHOD §7):** every row above green on the merged tip →
`LEDGER:p28` proposed by lanes, written at program close; the program FREEZE line additionally
requires p29's §5 and zero open findings (orchestrator STEP 3).

## §6 Coordinator protocol (judge → merge → battery → ledger → hold push)

1. **Judge each lane separately** (METHOD §6): re-run the load-bearing gates personally; open
   every red→green receipt pair and verify the red actually failed BEFORE the fix; verify
   tip ≠ base per lane; spot-check ≥3 claims (e.g. open one lcov DA line claimed covered;
   re-run one 5/5 push command; read the T-5 negative-control output); audit forbidden paths —
   `git diff --name-only b445ff35..HEAD` may show only §2 lane territory + `tool_uilib/p28/**`.
2. **Merge in the primary tree:** `git merge --no-ff p28/lane-a` then
   `git merge --no-ff p28/lane-b` (both must exist before the floor runs).
3. **Battery on the merged tip:** every §5 row live, including the ONE fresh coverage_floor
   run (≈15–20 min). Lane coverage claims are evidence, not the gate.
4. **Ledger:** single writer = coordinator; `LEDGER:p28` and `LEDGER:p29` are both written at
   program close (orchestrator STEP 3) together with the register, CHANGELOG, constitution and
   DEFERRED updates. Lanes only propose text.
5. **Never push. Never edit floor pins. Never end on a red tip** (METHOD §2.7): a lane that
   cannot close its floor reverts to the last green state and ledger-blockers the evidence.

## §7 Executor quickstart — the paste-ready prompts (this IS the dispatch text)

```text
p28 LANE-A EXECUTOR PROMPT — paste into a fresh session (METHOD executor role)

You are the EXECUTOR for p28 LANE A (WHITE_LABEL_p28_coverage_recovery.md) in the
<repo> monorepo (Carnama). The coordinator wrote the spec; it IS the acceptance
contract. You implement ONE lane, deliver findings + a paste-ready ledger block, and never
touch the ledger. METHOD.md is the source of truth.

READ FIRST, in order:
 1. WHITE_LABEL_p28_coverage_recovery.md — §0 (binding rules), §1 (red proofs, cite not
    re-derive), §2 (territory), §3 (your tasks T-1 + T-2), §5 (floors), §4 (deliverable)
 2. METHOD.md — ten laws + seven-step cadence
 3. .clinerules/15-tests.md + .clinerules/20-core-app-carnama.md (commands/tags)
 4. tool_uilib/p27/p27_findings.md §3 A1 + A6 — your RED evidence (citable, not re-runnable)

SETUP (your worktree):
  cd <repo>
  git worktree add ..\resturant-p28a -b p28/lane-a
  cd ..\resturant-p28a
  flutter pub get
  # no .env exists in the primary tree (only tracked core_app/.env.example) — do not create one
  git rev-parse --short HEAD   # must satisfy spec §1: contains b445ff35 + "p28/29 T-0:" commit

MISSION — Lane A only (packages/core/{lib,test}/**), nothing else:
  T-1 push-echo race: resetForTest() cancels/awaits in-flight echoes. RED = reproduction
      receipt BEFORE the fix (or honest 5-run non-repro + cite A6). GREEN = 5/5 consecutive
      `flutter test --coverage test/push_notification_service_test.dart` + core suite.
  T-2 core floor recovery: real-behaviour tests vs lcov DA:0 clusters until core >= 84.24%
      (start: the 27 uncovered auth_repository.dart lines, findings A1). No padding.

SEVEN STEPS (METHOD §3), one session, one lane, coverage run ≈15-20 min:
 0. SYNC    worktree tip checks above; `git status --porcelain` clean except your receipts
 1. BLOCKER dart format --output=none --set-exit-if-changed . = 0 changed; analyze ×4 = 0.
            Suites/functions/guards/constitution gates: CITE the p27 receipts (spec §1).
 2. WORK    red→green per task inside §2 territory; receipts to
            tool_uilib/p28/receipts/lane_a/<name>.txt (UTF-8, exit code inside each file)
 3. GATES   in YOUR worktree: format 0 · analyze 4/4 · core suite ≥387 0 fail 0 skip ·
            core lcov ≥84.24% (direct lcov arithmetic receipt) · push-flake 5/5 ·
            census 0 new skips/ignores · goldens 0 regenerated.
            DO NOT run tool_fix/b7/coverage_floor.ps1 — coordinator runs it on the merged tip.
 4. DELIVER tool_uilib/p28/p28_lane_a_findings.md (six-way classification, spec §4) +
            paste-ready LEDGER:p28 (lane-a) block + receipts index. Commits local, subjects
            `p28 T-N: ...`. NEVER push. NEVER edit FIX_VERIFICATION.md / AUDIT_TRIAGE_STAGE3.md
            / DECISIONS_LOG.md / coverage_baseline.json.
 5. STOP    — the coordinator judges (re-runs gates, opens your receipts, audits paths).

HARD RULES (spec §0) — any violation rejects the lane:
 · no // ignore: / // ignore_for_file: / skip / deleted check / deleted pattern / rename to
   dodge a matcher; no assertion-free padding tests
 · every claim P1 (file:line opened this session) or P2 (fails when claim is false);
   everything else -> non-empty UNVERIFIED
 · forbidden: ledger, register, rules+indexes, pubspecs/lockfiles, generated files,
   apps/halal_boyz/lib/**, .clinerules/**, coverage_baseline.json, DECISIONS_LOG.md,
   anything outside packages/core/**
 · never end on a red tip: revert to last green, record the blocker with evidence, stop
 · one lane one session; commits only, no push; auth paths fail closed
```

```text
p28 LANE-B EXECUTOR PROMPT — paste into a fresh session (METHOD executor role)

You are the EXECUTOR for p28 LANE B (WHITE_LABEL_p28_coverage_recovery.md) in the
<repo> monorepo (Carnama). The spec is the acceptance contract. You implement ONE lane,
deliver findings + a paste-ready ledger block, never touch the ledger.

READ FIRST, in order:
 1. WHITE_LABEL_p28_coverage_recovery.md (§0-§7 — esp. §3 T-3/T-4/T-5 and §2 Lane B limits)
 2. METHOD.md  3. .clinerules/15-tests.md + 20-core-app-carnama.md
 4. tool_uilib/p27/receipts/g_coverage_floor_final.txt — the 12-violation RED (cite it, and
    tool_uilib/p27/p27_findings.md §3 A1 for the file decomposition)

SETUP (your worktree):
  cd <repo>
  git worktree add ..\resturant-p28b -b p28/lane-b
  cd ..\resturant-p28b
  flutter pub get   # no .env exists — only tracked core_app/.env.example; do not create one
  git rev-parse --short HEAD   # must satisfy spec §1 (b445ff35 + "p28/29 T-0:" commit)

MISSION — Lane B only: core_app/test/** + packages/core_ui/test/** + tool_fix/b7/
coverage_floor.ps1. NO production lib/ edits — a widget that needs a seam = handoff note.
  T-3 diagnosis TIMEBOXED 45 min BEFORE T-4: why do the 10 NEW files fail together?
      (likely ONE harness cause). Record the outcome in findings EITHER WAY.
  T-4 widget tests drive the 10 named files to LH==LF; 0 goldens regenerated.
  T-5 coverage_floor.ps1 exempts ONLY the pattern lib/l10n/app_localizations_*.dart from the
      NEW-file rule, with a why-comment; negative-control receipt proves the rule still fails
      a non-l10n file; coverage_baseline.json stays byte-unchanged.

SEVEN STEPS (METHOD §3), one session, one lane:
 0. SYNC    tip checks above; git status clean except your receipts
 1. BLOCKER format 0 · analyze ×4 = 0 live; everything else CITE (spec §1)
 2. WORK    red→green per task; receipts to tool_uilib/p28/receipts/lane_b/<name>.txt
 3. GATES   in YOUR worktree: format 0 · analyze 4/4 · core_ui suite ≥411 · core_app suite
            ≥2393 · 0 fail 0 skip · per-file LH==LF receipts for all 10 · T-5 negative
            control FAILs as expected · census 0 new skips/ignores · goldens 0.
            DO NOT run coverage_floor.ps1 end-to-end (coordinator-only, merged tip).
 4. DELIVER tool_uilib/p28/p28_lane_b_findings.md (six-way, spec §4) + LEDGER:p28 (lane-b)
            block + receipts index. Commits local `p28 T-N: ...`. NEVER push. NEVER edit
            ledger / register / DECISIONS_LOG / coverage_baseline.json / any rule-5 file.
 5. STOP    — coordinator judges.

HARD RULES (spec §0) — any violation rejects the lane:
 · no // ignore: / // ignore_for_file: / skip / deleted check / deleted pattern / matcher
   dodge; the T-5 exemption is pattern-scoped to generated l10n ONLY
 · every claim P1 or P2; else non-empty UNVERIFIED
 · forbidden: ledger, register, rules+indexes, pubspecs/lockfiles, generated dart, gen-l10n
   output, apps/halal_boyz/lib/**, .clinerules/**, coverage_baseline.json, core_app/lib/**,
   packages/*/lib/**
 · never end on a red tip · one lane one session · commits only, no push · fail closed
```
