# FIX-B7 — TEST-1 + DEAD-1 + COV-3 + the shared-state flake (F-W4-01)

**Batch:** `B7` · **Findings:** `AUD1-07` (2 tests that cannot fail) · `AUD1-10` (dead shadow tokens) · `AUD1-08` (no coverage floor anywhere — SPEC row owned here) · **`F-W4-01` (new, found by the wave-4 coordinator battery: a nondeterministic test that fails because it reads a machine-global log file)**.
**Worktree:** `<repo>-cline-3` (`cline/task-3`). May run ∥ `B8`. *(Corrected: B4 holds `cline-5`; B3b's `cline/task-3` is merged and free.)*

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1). 0.3 Red→green — for `F-W4-01` the **red must be reproducible on demand**. 0.4 Ledger single-writer. 0.5 Territory (§2). 0.6 Never end on red; commit per task. 0.7 **Determinism law (new):** no test may depend on state that survives a test run — no machine-global files, no cross-file ordering, no temp residue. A test that passes only because the shared state happens to be clean is a **defect**. 0.8 No new dependencies. 0.9 Git strictly serialized (one writing window at a time). 0.10 A "fixed" flake is proven by **repeated runs**, never by one green run.

## §1 Research receipts (verified at `2f6d90d`)

| Fact | Evidence |
|---|---|
| `core_app/test/app_bootstrap_states_test.dart:230` asserts the marker is **absent**: `expect(await _bootLogContains('ClientConfigLoadFailed'), isFalse)` | file:line |
| `_bootLogContains` reads a **machine-global, ever-appending** file: `File('${Directory.systemTemp.path}/app_logs.txt')` (`:115-120`) | file:line |
| The marker **is present** in the rotated generation: `%TEMP%\app_logs.1.txt` = 1,049,410 B with **8** occurrences | measured this session (re-capture into `tool_fix/b7/`) |
| The writer is legitimate: `core_app/lib/app_bootstrap.dart:549` logs `ClientConfigLoadFailed` when `AppConfig.loadFailed`; `core_app/test/client_config_schema_test.dart:307,:320` force `loadFailed = true` | file:line |
| The harness documents the sharing: *"The systemTemp log files are shared by every test file on the …"* | `core_app/test/helpers/boot_env_harness.dart:8` |
| Observed: full `core_app` failed `+1988 -1` on the merged tip, then passed `+1989` **twice isolated** and `+1989` full-suite after deleting `%TEMP%\app_logs*.txt` — **identical code** | `tool_fix/wave4/m_core_app.txt` vs `m_core_app_clean.txt` |
| Dead tokens: `softShadow` / `activeShadow` referenced nowhere | `packages/core_ui/lib/src/theme/app_colors.dart:65`, `:75` |
| The 2 vacuous tests are enumerated by AUD-1 | `tool_audit/aud1/receipts/c2_vacuous_tests3.txt` |
| Package baselines for the floor: core **84.24 %**, core_ui **92.76 %**, core_app **86.87 %**; 108 files < 100 % | `tool_audit/aud1/receipts/c2_coverage_totals.txt` |

## §2 Territory

**MODIFIED:** `core_app/test/app_bootstrap_states_test.dart` · `core_app/test/helpers/boot_env_harness.dart` · the 2 vacuous test files named by AUD-1 · `packages/core_ui/lib/src/theme/app_colors.dart` (**only** the two dead shadow declarations).
**CREATED:** the coverage-floor script + pinned baseline JSON under `tool_fix/b7/` · receipts in `tool_fix/b7/**`.
**FORBIDDEN:** any production logic outside `app_colors.dart` · theme token *values* · money paths · `functions/**` · configs · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — `F-W4-01`, the flake (highest value).** Reproduce it **on demand**: seed a `ClientConfigLoadFailed` line into `%TEMP%\app_logs.txt`, run the isolated boot-states test → it must fail (that is the red receipt). Then make the test hermetic: it must **own** the state it asserts on — delete the boot-log generations in `setUp` (restore/clean in `tearDown`), or scope the logger to a per-test directory. Prove by: (a) the seeded run now **passing**, (b) **three consecutive full `core_app` suites** green with the same count, (c) the isolated run green.

**T-2 — `AUD1-07`: kill the 2 tests that cannot fail.** For each: either assert the real contract or **delete it** (one-line justification naming what covers it instead). Record before/after test counts.

**T-3 — `AUD1-10`: dead shadow tokens.** Drop `softShadow`/`activeShadow` **or** wire them at a real, named call site. Default = drop. Prove: grep shows 0 references and the suite is green.

**T-4 — `AUD1-08`: a coverage floor that cannot regress silently.** Commit a re-runnable script (`tool_fix/b7/coverage_floor.ps1`) + a pinned baseline JSON (per package lines %, plus the fleet rule that **new files must be 100 %**). The script must FAIL if a package drops below its pinned baseline. Capture the baseline receipt and a deliberate-break proof (lower a threshold → exit 1 → restore).

## §4 Deliverable

`tool_fix/b7/b7_report.md`: T-table (red → green, with the seeded-flake proof), six-way classification, the new **determinism law** restated for the fleet, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B7` ledger block. Receipts in `tool_fix/b7/`.

## §5 Acceptance

T-1 proven by 3 consecutive green full `core_app` suites + the seeded red → green pair · T-2 count recorded · T-3 grep 0 + suite green · T-4 script fails on a deliberate break and passes at baseline · format 0 · analyze ×3 (core_app, core, core_ui) 0 · suites core + core_ui + core_app + halal green **0 skip** no drop · greps 0 · forbidden paths untouched · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the full battery (all four suites) on the committed tip; **independently reproduces the flake** (seed → red) and its fix (seed → green); verifies the coverage script fails on a lowered threshold; merges; appends the ledger block; flips `AUD1-07`, `AUD1-08`, `AUD1-10`, `F-W4-01` → **CLOSED-WITH-RECEIPT**.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B7 (TEST-1 + DEAD-1 + COV-3 + the shared-state flake). Worktree <repo>-cline-3 (branch cline/task-3). May run beside B8.
Read <repo>\FIX_b7_tests_hygiene.md IN FULL — binding contract; the determinism law (§0.7) and the repeat-run rule (§0.10) apply.
1. SYNC (fail-closed): assert branch == cline/task-3; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core + core_ui, format root, suites core + core_ui + core_app + apps/halal_boyz green 0 skip BEFORE any edit. Red => STOP + report.
2. T-1 RED: seed a ClientConfigLoadFailed line into %TEMP%\app_logs.txt, run the isolated boot-states test, capture the failure to tool_fix/b7/red_flake.txt.
3. T-1 GREEN: make the reader own its state; prove with the seeded run passing + THREE consecutive full core_app suites green (same count) + the isolated run green.
4. T-2/T-3/T-4 per §3 (vacuous tests, dead shadows, coverage floor + deliberate-break proof).
5. PROOF: format 0; analyze 0 x3; suites core/core_ui/core_app/halal green 0 skip; greps 0; territory diff.
6. REPORT: tool_fix/b7/b7_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
7. COMMIT locally on cline/task-3 (explicit paths, one commit per task); do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + seeded-state red->green proof + 3 consecutive clean suites + coverage floor proven + nothing uncommitted.
```

