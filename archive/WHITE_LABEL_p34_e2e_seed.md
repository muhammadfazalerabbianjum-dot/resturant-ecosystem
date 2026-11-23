# WHITE_LABEL p34 — E2E DEVICE LANE (tag: E2E-DEVICE)

**Batch:** P34 · **Master evidence:** `tool_uilib/p31/p31_proof_report.md` §Q9 (23 suites, never run) + issue-register #8
· **Predecessor:** p32+p33 (both DONE) · **Emulator lane:** YES · **Worktree-eligible:** no (device-bound; single tree)

## §0 Rules (batch-specific — `METHOD.md` is the source of truth; cite it, do not restate it)

1. **Emulator-only, always** (Law 30). Every suite binds through `integration_test/test_helpers/emulator_bootstrap.dart` (Firestore `127.0.0.1:8080`, Auth `:9099`, fail-fast host check). `adb reverse tcp:8080 tcp:8080` + `adb reverse tcp:9099 tcp:9099` before any run. Production project `resturants-8547d` is unreachable by construction; `--project demo-carnama` for the emulator suite.
2. **RED LAW.** The first full `integration_test/` run of this repository has never happened — its complete output IS the batch's RED proof, captured to `tool_uilib/p34_e2e/red_r2_first_run.txt` **before any fix is attempted**. No editing between launch and capture.
3. **Fix discipline.** In-territory test/harness bugs (stale selectors in `integration_test/**`, runner script drift) fix red→green here. Any `core_app/lib` / `packages/**` app defect surfaced is written up with the failing output and either (a) fixed with its own dedicated red→green receipt if the fix is ≤20 lines and provably local, or (b) escalated as a handoff note in the findings — never a silent skip, never a weakened assertion.
4. **No fake green:** no `// ignore`, no `skip:`, no `@Tags('e2e')` added to dodge a failing suite (tags restrict the DEFAULT tier only; the p34 gate runs the full directory regardless).
5. **Territory:** §2 only. Zero edits under `core_app/lib/**`, `packages/**`, `apps/*/lib|assets`, `functions/**` except the (a)-branch of rule 3.
6. **Never end on red.** Receipts land under `tool_uilib/p34_e2e/`; failures beyond scope become findings + handoff, not an abandoned run.

## §1 Baseline + blocker + RED proofs

- **Tip:** branch `cline/p32-golden-gates` at the p33/p37 closeout tip (verify `git rev-parse --short HEAD` at SYNC).
- **BLOCKER (fresh receipts → `tool_uilib/p34_e2e/blocker_*`):** `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) → 0; `dart format --output=none --set-exit-if-changed .` → 0 (847 files); suites **core_app 2541 · core_ui 437 · core 396 · halal 77 · tool 239 · functions 172** (floors from `tool_uilib/p37/battery.txt` + p33 closeout; lower = STOP, report drift).
- **R1 (cite):** `tool_uilib/p31/p31_proof_report.md:167` — "e2e tier never run locally — 23 suites exist, excluded from default tier".
- **R2 (re-capture LIVE — the load-bearing red):** first-ever full run (T-2).
- **R3 (cite):** inventory today — 23 files in `core_app/integration_test/` (19 wired into `all_tests.dart`, 4 NOT imported: `golden_a_z_flow_test`, `performance_timeline_test`, `v13_security_rules_test`, `v15_phase1_security_audit_test`) + `apps/halal_boyz/integration_test/app_launch_test.dart`.
- **R4 (cite):** runner drift — `core_app/tool/run_integration_tests.ps1:27` starts emulators with `--project demo-test` (house: `demo-carnama`) and `:42` targets a dead device `-d 192.168.0.103:40903`.
- **R5 (cite):** zero `@Tags(` annotations exist anywhere in `integration_test/**` although `core_app/dart_test.yaml` defines `e2e`/`nightly`/`needs-emulator` — the tier contract is declared but unwired.

## §2 Territory

| | Paths |
|---|---|
| **IN** | `core_app/integration_test/**` (suites, `test_helpers/**`, `all_tests.dart`) · `apps/halal_boyz/integration_test/**` · `core_app/tool/run_integration_tests.ps1` · `core_app/dart_test.yaml` (tag wiring only) · `tool_uilib/p34_e2e/**` |
| **OUT** | `core_app/lib/**` (unless §0-3a, ≤20 lines, with its own red→green receipt) · `packages/**` · `apps/*/lib|assets` · `functions/**` · `firestore.rules` · `FIX_VERIFICATION.md` (coordinator-only) · `WHITE_LABEL_BATCHES.md` (coordinator-only) · any golden baseline |

## §3 Problems → Acceptance → T-x

| | Problem | Acceptance | T-x |
|---|---|---|---|
| 1 | Runner script is device-bound and points at the wrong Firebase project — the lane cannot start from docs | Script auto-selects the one attached emulator, uses `--project demo-carnama`, idempotently sets both `adb reverse` tunnels, and documents the `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_FAKE` debug guard (`app_bootstrap.dart:731`). **RED:** current script's dead IP + `demo-test` cited to `red_r1_runner.txt`. **GREEN:** script runs end-to-end to "emulators ready" → `green_r1_runner.txt` | **T-1** |
| 2 | The 23+1 suites have NEVER run — no one knows if they pass | Emulator (`Medium_Phone_API_36.1`) up → Firebase emulators up → full-directory run **plus** the 4 non-bundled suites **plus** halal `app_launch_test`, complete output captured (T-2 red) then fixes (§0-3) until 0 fail → `green_r2_full_run.txt`. Suites that cannot pass without cross-territory app fixes: findings row each with failing output, no skips | **T-2** |
| 3 | Tier contract unwired: tags defined, never applied | Every file in `integration_test/**` carries `@Tags('e2e')` (and `needs-emulator` where it binds Firebase); proof: grep receipt `gate_tags.txt` + default tier (`--exclude-tags=e2e,nightly,needs-emulator`) still excludes them and stays green at suite floors | **T-3** |
| 4 | Findings + honest verdict | `tool_uilib/p34_e2e/p34_e2e_findings.md` — six-way classification, per-suite pass/fail table, §0-3a fixes listed with receipts, paste-ready ledger block `## APP COMPLETION E2E-DEVICE - ...` (coordinator appends) | **T-4** |
| 5 | Final battery at batch tip | §5 gates all green; receipts committed under `tool_uilib/p34_e2e/` | **T-5** |

**Handoff notes (never fixed here):** real-device release smoke (Play Integrity, OEM fonts, real push — §Q9-4) · ubuntu-CI parity · patrol migration if a native-plugin suite demands it.

## §4 Deliverable

`tool_uilib/p34_e2e/p34_e2e_findings.md` (six-way + per-suite table + paste-ready ledger block) + all receipts + the wired tags. Executor never edits `FIX_VERIFICATION.md` / `WHITE_LABEL_BATCHES.md`.

## §5 Acceptance (measurable floors — all must hold at batch tip)

1. Blocker gates unchanged: analyze ×4 → 0; format → 0; suites core_app **≥2541** · core_ui **437** · core **396** · halal **77** · tool **239** · functions **172** — 0 fail, 0 skip.
2. e2e tier: **24/24 files run** (23 core_app + 1 halal), 0 fail, 0 skip — or every non-passer is a findings row with captured failing output and an explicit handoff verdict (no silent drop; count stated in the ledger block).
3. `gate_tags.txt`: 24/24 files carry `e2e` tags; default-tier run still green.
4. Emulator discipline: bootstrap host-check passed in every run receipt; zero production endpoints in any log line.
5. `git diff --name-only` ⊆ §2-IN (plus any §0-3a file, each named with its receipt). Zero skips/ignores introduced (word-bounded grep).

## §6 Coordinator protocol (judge — fresh re-runs, never re-reads)

1. Re-run the full e2e directory personally → same pass/fail split as findings.
2. Re-run default tier → floors green, e2e excluded.
3. Grep tags + diff audit (§5-3/5) → append ledger addendum (single writer) → merge.

## §7 Executor quickstart (paste-ready)

```
You are the EXECUTOR for batch p34 (WHITE_LABEL_p34_e2e_seed.md) in <repo>.
READ FIRST: 1) this spec (§0 binding) 2) METHOD.md 3) .clinerules/15-tests.md + 20-core-app-carnama.md
4) tool_uilib/p31/p31_proof_report.md §Q9. R1/R3/R4/R5 are citable; R2 you capture live.
Single tree: work on the current branch (device-bound batch — no worktree).
Cadence: SYNC → BLOCKER receipts → T-1 runner → T-2 first run CAPTURED, then green →
  T-3 tags → T-4 findings → T-5 gates → STOP (judge next).
Emulator: flutter emulators --launch Medium_Phone_API_36.1 → adb reverse tcp:8080/9099 →
  firebase emulators:start --only firestore,auth,functions --project demo-carnama →
  flutter test integration_test/ --dart-define=USE_EMULATOR=true --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_FAKE
Commit: test(e2e): E2E-DEVICE <imperative> | body: bullets + per-suite counts + Refs: WHITE_LABEL_p34_e2e_seed.md
NEVER: edit lib/ without §0-3a receipt · skip a suite to get green · touch baselines or the shared ledger · end on red.
```
