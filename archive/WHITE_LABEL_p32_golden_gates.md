# WHITE_LABEL p32 — GOLDEN-GATE REPAIR (tag: GOLDEN-GATES)

**Batch:** P32 · **Master evidence:** `tool_uilib/p31/p31_proof_report.md` §Q11 defect N-1 (corrected 2026-10-04)
· **Predecessor:** none · **Emulator lane:** no · **Worktree-eligible:** yes (§3.5/§3.6 conditions; merge slot FIRST — see §7)
· **Territory clash with p33:** predicted = goldens (resolve by merging p32 before p33's close; see p33 spec §0/§6)

## §0 Rules (batch-specific — `METHOD.md` is the source of truth; cite it, do not restate it)

1. **P1/P2 law.** Every claim = file:line opened this session or a test that fails if false. §1 RED proofs are citable — do not re-derive, but DO re-capture R2 live (it is the load-bearing red).
2. **RED LAW (this batch's core).** No `--update-goldens` until (a) all six sites are converted and (b) the three named tests were observed FAILING with output captured to `tool_uilib/p32/red_t1_*.txt`. A regenerated baseline without a captured prior failure = batch failure (METHOD law 2).
3. **Regeneration scope is closed:** only `manager_dashboard`, `owner_dashboard`, `p22_manager_dashboard_rows` baselines. Any other golden failing after T-1 ⇒ STOP, handoff note, do not widen (law 4/5).
4. **Visual judgment before regenerate.** For each of the 3: read `masterImage` vs `testImage` PNGs (read_files) and record verdict = `expected-drift (date/time)` | `layout-change` | `regression`. `regression` ⇒ STOP (fix is cross-territory).
5. **Territory:** §2 only. Zero edits under `core_app/lib`, `packages/**`, `apps/*/lib|assets`, `functions/**`.
6. **No fake green:** no `// ignore`, no `skip:`, no assertion weakening. The new hygiene pin (T-4) must FIRE on a planted violation (p25 L-P4 law, inherited).
7. **Never end on red.** Worktree mode inherits §3.5: in-worktree ledger file, gates run inside the worktree, merge slot = FIRST.

## §1 Baseline + blocker + RED proofs

- **Tip:** `main` = `a105a05` (verify `git rev-parse --short HEAD` at SYNC).
- **BLOCKER before any edit** (fresh receipts → `tool_uilib/p32/blocker_*`): `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) → "No issues"; `dart format --output=none --set-exit-if-changed .` → 0; suites **core_app 2458 · core_ui 431 · core 396 · halal 75** (floors from `tool_uilib/p31/receipts/fresh_*`; a lower count = STOP, report drift).
- **R1 (cite):** mechanical census at 2026-10-04 — 66 `matchesGoldenFile` sites total = 60 `await expectLater` + **6 VOID sync `expect`**:
  `core_app/test/ui/kitchen_dashboard_golden_test.dart:61`,
  `manager_dashboard_golden_test.dart:35`,
  `owner_dashboard_golden_test.dart:58`,
  `p22_manager_dlq_goldens_test.dart:123,141,155`.
  Re-capture as `tool_uilib/p32/red_r1_census.txt` (classifier output, VOID=6).
- **R2 (re-capture live — the load-bearing red):** run `flutter test test/ui/manager_dashboard_golden_test.dart` → **exit 0 while rewriting `test/ui/failures/manager_dashboard_*` artifacts** (mtime advances, `testImage ≠ golden`). Save stdout+exit+artifact listing → `red_r2_void_exit0.txt`.
- **R3 (cite):** current stale set by failure-artifact mtimes 2026-10-04 13:20–14:06 = `manager_dashboard`, `owner_dashboard`, `p22_manager_dashboard_rows` (kitchen artifacts predate at 09-28 → currently matching).
- **R4 (cite):** attestation row (K) "goldens 66" in `WHITE_LABEL_BATCHES.md` §3.6 — final census must remain total 66 (VOID=0).

## §2 Territory

| | Paths |
|---|---|
| **IN** | `core_app/test/ui/*.dart` (the six sites + new hygiene test) · `core_app/test/golden/**` · any `test/**/goldens/**` baselines touched by T-2 · `tool_fix/b9/visual_review/after/**` (T-3 only) · `tool_uilib/p32/**` |
| **OUT** | `core_app/lib/**` · `packages/**` · `apps/*/lib`, `apps/*/assets` · `functions/**` · `.clinerules/**` · `FIX_VERIFICATION.md` (coordinator-only) · `pubspec.lock` · `*.g.dart`/`*.freezed.dart` · `firestore.rules` |

## §3 Problems → Acceptance → T-x

| T | What | Red→green proof required | Floor |
|---|---|---|---|
| **T-1** | Convert the six VOID sites to `await expectLater(...)` (exact lines, §1-R1). Do NOT touch baselines yet. | **RED:** run the three stale test files → suite FAILS, output captured `red_t1_stale_{manager,owner,p22}.txt`. (Void gate becomes a real one and immediately exposes staleness — the batch's core proof.) | 6/6 sites converted; classifier `VOID(expect)=0` |
| **T-2** | Judge + re-baseline the three stale goldens. Per golden: read `failures/<name>_masterImage.png` vs `testImage.png`, write verdict into findings (§0-4). `expected-drift`/`layout-change` ⇒ `flutter test --update-goldens` **scoped to that test file only**; `regression` ⇒ STOP + handoff. Fix time-fragility: make rendered date/time deterministic in the TEST (fixed clock/date injection — test-only edit). | **GREEN:** each of the 3 files passes **twice in a row** (`green_t2_twice.txt` — determinism, not a fluke). Verdict table in findings with PNG paths cited. | 3/3 green ×2; `git status` shows only the 3 baselines + test files changed |
| **T-3** | **Ops visual truth:** capture owner / manager / kitchen dashboards with REAL fonts (pattern: `apps/halal_boyz/test/visual_review_capture_test.dart` FontLoader) → `tool_uilib/p32/ops_captures/{owner,manager,kitchen}_dashboard.png`, committed. Harness inside IN-territory, green in the default suite (no new tags). | Files exist + suite green + dimensions nonzero; findings cite each. Closes the proof report's "ops screens never visually seen" gap. | 3 PNGs committed; suite 0 fail 0 skip |
| **T-4** | **Regression pin:** new `core_app/test/ui/golden_gate_hygiene_test.dart` — scans `core_app/test/**`; any `matchesGoldenFile` statement not preceded by `await expectLater(` ⇒ FAIL naming file:line. | **RED:** planted sync-`expect` fixture → fails (`red_t4_plant.txt`). **GREEN:** HEAD → passes (`green_t4_plant.txt`). Judge re-plants independently (§6). | Fires on plant, passes at HEAD |
| **T-5** | Final census + battery (§5): classifier → `gate_census_final.txt` (`VOID=0`, `TOTAL=66`). | Receipt present; all §5 floors met. | VOID=0, TOTAL=66 |

**Handoff notes (never fixed here):** ubuntu-CI golden parity (first push, P32a) · test-font typography blind spot (P35) · any `regression` verdict from T-2.

## §4 Deliverable

`tool_uilib/p32/p32_findings.md` — six-way classification (**Verified / Unverified / Anomalies / Untested / Risks / Recommendations**) + T-2 verdict table + honest residuals + paste-ready ledger block `## APP COMPLETION GOLDEN-GATES - ...` (coordinator appends; executor never edits `FIX_VERIFICATION.md`). All receipts under `tool_uilib/p32/`.

## §5 Acceptance (measurable floors — all must hold at batch tip)

1. `flutter analyze --fatal-infos` (core_app + halal) + `dart analyze` (core + core_ui) → 0 issues, exit 0.
2. `dart format --output=none --set-exit-if-changed .` → exit 0, 0 changed.
3. Suites: core_app **≥ 2459** (2458 + T-4's new test; T-1/T-2 add none but must not remove) · core 396 · core_ui 431 · halal 75 — **0 fail, 0 skip**.
4. Census: `VOID=0`, `TOTAL=66`.
5. Coverage-floor command (per `.clinerules/20-core-app-carnama.md`) → PASS, newUncovered = 0.
6. `git diff --name-only` ⊆ §2-IN. Zero skips/ignores introduced (word-bounded grep).

## §6 Coordinator protocol (judge — fresh re-runs, never re-reads)

1. Re-run the classifier personally → expect `VOID=0/66`.
2. Re-run the 3 golden files twice → green both times.
3. Plant a sync-`expect` in a temp test → hygiene test must FIRE → delete plant.
4. Spot-check ≥3 T-2 verdicts: open baseline vs regenerated PNG pairs personally.
5. Verify `tip ≠ base` + forbidden-path audit (zero §2-OUT paths in the diff) → append ledger addendum (single writer) → merge.

## §7 Executor quickstart (paste-ready)

```
You are the EXECUTOR for batch p32 (WHITE_LABEL_p32_golden_gates.md) in <repo>.
READ FIRST: 1) this spec (§0 binding) 2) METHOD.md 3) .clinerules/15-tests.md + 20-core-app-carnama.md
4) tool_uilib/p31/p31_proof_report.md §Q11 N-1. §1 R1/R3/R4 are citable; R2 you re-capture live.
Mode A (default, single tree): git checkout -b cline/p32-golden-gates main
Mode B (worktree, WHITE_LABEL_BATCHES §3.5): git worktree add <repo>-p32 -b p32/golden-gates main
  → in-worktree ledger FIX_VERIFICATION_p32.md; merge slot FIRST (before p33); gates run in-worktree.
Cadence: SYNC → BLOCKER (§1 receipts) → T-1..T-5 red→green → §5 gates → §4 deliverable → STOP (judge next).
Commit: test(core_app): GOLDEN-GATES <imperative> | body: bullets + proof numbers + Refs: WHITE_LABEL_p32_golden_gates.md
NEVER: edit lib/ · regenerate goldens before the red is captured · touch the shared ledger · end on red.
```

