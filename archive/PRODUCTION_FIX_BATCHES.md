# CARNAMA LABS — PRODUCTION FIX: BATCH EXECUTION DRIVER (potato4-style index)

**Read this index + the ONE batch file you are implementing. Never load all batch files at once.**
**Source of truth for HOW:** `PRODUCTION_FIX_PROMPT.md` (the single solutions spec — the audits' proven best-fit winners). Each batch file cites its master wave subsection; this index holds the RULES, the Universal Gate Set U, the environment/decisions, the batch map, and the execution order.

---

## 0. RULES THE EXECUTING AGENT MUST FOLLOW (hard gates — from `PRODUCTION_FIX_PROMPT.md` §0)

1. **Codebase-only truth.** Verify every cited `file:line` against current source before editing. If code drifted from a citation, fix against the CODE and record the drift in the batch addendum — never fake a citation or skip a fix.
2. **No stubs / no fake success / no placeholders / no TODOs / no `@Skip` / no `skip:`.** B4 achieved zero-skip; keep it. Every test asserts a real outcome on real production code.
3. **No new runtime dependencies** except the two sanctioned: `connectivity_plus` (core_app only) and functions eslint tooling. Anything else requires a stopping ledger note with justification BEFORE adding.
4. **Mirror rule (three surfaces).** A fix is DONE only in (a) template `core_app`/`packages`, (b) generated shell `apps/halal_boyz` where it carries a copy, and (c) the backend where server-side. DEFAULT mechanism = regenerate via `core_app/tool/whitelabel.dart` for generator-owned files; hand-mirror with a ledger note only where the generator does not own the file. State which, per batch addendum.
5. **Fail-closed over fail-open** for money, auth, GDPR, security. When in doubt, throw/log + clean error — never silently succeed.
6. **One batch per session.** End on a green gate set, append the batch addendum to `FIX_VERIFICATION.md`, THEN start the next. A failed gate = stop inside the batch, fix, re-run; never widen scope silently. **Parallel-workspaces clause (2026-09-01 amendment):** separate git worktrees MAY run disjoint batches concurrently, ONLY under the `## 3.5 PARALLEL EXECUTION + MERGE-BACK PROTOCOL` + `## 3.6 FIVE-WINDOW TERRITORY MAP` rules (restrictions: per-worktree ledger files, file-disjoint pools, predecessors-DONE-in-main, chain merge-back, post-merge gate re-runs. Any run not conforming to §3.5 defaults back to strict sequential.
7. **Conventions:** Riverpod DI (no `FirebaseFirestore.instance` in features), `RouteNames` for named nav, `FirebaseExceptionMapper.map` + snackbar, `if (!mounted) return;` after every async gap, money in integer cents, l10n via `AppLocalizations` (en+ar parity must stay green), `unawaited()` for fire-and-forget.
8. **Prohibited:** editing `isar.dll`, hand-editing `pubspec.lock`, `node_modules`, generated `*.g.dart`/`*.freezed.dart` (regenerate), anything under `.dart_tool/` or `build/`.
9. **Test-addition policy (2026-09-01 amendment):** each batch implements its spec's T-x behavior table as NEW real tests (red-today/green-after). If the code the batch touches lacks tests beyond its T-x table, the batch ADDS the missing REAL tests within its own §3.6 territory (Rule 2 applies — no stubs, no skips, no `// coverage:ignore`). A test hole discovered in ANOTHER window's territory is recorded in the batch addendum as a handoff note for that window — never fixed cross-territory. The CI 80% aggregate-coverage floor (CI-1) is the global backstop and stays red until the recorded coverage debt is paid; faking it (excludes, ignore comments, skipped tests) is a gate failure.

---

## 1. UNIVERSAL GATE SET U (EVERY batch applies ALL of these, PLUS its own proof gates)

- **U-ANALYZE** — `flutter analyze --fatal-infos` (core_app, apps/halal_boyz) and `dart analyze` (packages/core, packages/core_ui) → **No issues found** for the batch's scope.
- **U-TESTS** — the batch's test suite is GREEN; `Select-String -Path <batch test files> -Pattern 'skip:|@Skip|markTestSkipped'` → **0 matches**.
- **U-FORMAT** — `dart format --output=none --set-exit-if-changed .` (repo root) → **exit 0**.
- **U-GREPS (G0)** — within the batch scope, ALL of these must be **0 matches**: `FirebaseFirestore.instance` in `core_app/lib/features` + `packages/core/lib/src` (bootstrap/DI defaults exempt per verification_report 6.6); `Color(0xFFFF6B35)`; `Color(0xFFFF6B00)` **outside `packages/core_ui`** (2026-09-01 spec audit: the original token alone was vacuously green — 0 occurrences anywhere — while the real brand literal `0xFFFF6B00` lives canonically in `packages/core_ui/lib/src/theme/app_colors.dart`; banning it outside core_ui is the non-vacuous form, 0 matches today); literal `$` money strings in `menu_screen`/`home_screen` (UX-1 onward); `sk_test_`/`ReplaceMe` in `functions/src`; `Navigator.pushNamed|pushReplacementNamed` in lib trees (ROUTER-1 onward); `screen['id']` route registration (ROUTER-1 onward); `@Skip|skip:` (always).
- **U-REPORT** — append ONE addendum to `FIX_VERIFICATION.md` (`## REMEDIATION <BatchTag> - <title> - VERIFICATION REPORT` with VERIFIED FIXES / SPEC AMENDMENTS / SUPPRESSION / UNVERIFIED / TEST TARGETS / CLEAN-GAP-CLOSURE PROOF with exact commands + exit codes) BEFORE starting the next batch.
- **U-TRUTH** — the code is the judge. Re-verify every citation; no shortcuts, no stubs, no fake success.

---

## 2. ENVIRONMENT PREREQUISITES + DECISIONS (deterministic defaults)

**Environment:** every batch needs the repo toolchain (Flutter 3.41.2 / Dart ^3.11 / node v24 / Java 21 / Firebase CLI 15). Batches whose gates include an emulator suite — **MONEY-1, MONEY-2, MONEY-3, RULES-1, RULES-2, QUEUE-1, RELEASE-2** — additionally require `firebase` CLI on PATH with emulators available (run `firebase --version` before starting those batches; if unavailable, stop and report — don't skip the gate). [MONEY-1 added 2026-09-01 spec audit: its batch map row + T-5 gate require `npm run test:money-emulator`; the list previously omitted it.]

**Decisions (record once; override only with an explicit owner note in the addendum):**
1. **Contrast strategy (UX-1/W9.1):** DEFAULT = **Option A** — darken `primary` to ~`#C84F00`-class (4.57:1 with white), because audit-05's own fix plan states "darken primary to ≥4.5:1" — Option A IS the audit's stated winner. Option B (keep `#FF6B00`, set dark `onPrimary` ~`#1D1D1D`, 5.9:1) is permitted ONLY as an explicit owner override. Either way: `textSecondary` and `success` must still reach ≥4.5:1, and the change must land byte-synced in `AppColors`/`AppTheme` AND BOTH client-config `theme` blocks.
2. **Mirror mechanism:** DEFAULT = regenerate the shell via `core_app/tool/whitelabel.dart` wherever the change is generator-owned (router, main, config adapter, platform files, backend bundle); hand-mirror with a ledger note only where the generator does not own the file (e.g., feature screens the shell doesn't carry). State which, per batch addendum.
3. **Dependencies:** already sanctioned — `connectivity_plus` (core_app only) + functions eslint tooling. ANY new dependency beyond these two requires a stopping ledger note with justification BEFORE adding (no silent additions).
4. **Line-drift policy:** if a cited `file:line` disagrees with the live tree, treat the code as truth, implement the INTENDED contract stated in the wave, and record the drift in the batch addendum — never fake the citation or skip the fix.

---
﻿
## 3. BATCH MAP (one batch = one file = one session)

| Spec file | Batch | Title | Master waves | Predecessor | Emulator-gated |
|---|---|---|---|---|---|
| `PRODUCTION_FIX_b00_preflight.md` | B0 | Preflight baseline (no code) | - | - | no |
| `PRODUCTION_FIX_b01_ci1.md` | CI-1 | CI relocate + repair | W1.1, W1.6 | B0 | no |
| `PRODUCTION_FIX_b02_ci2.md` | CI-2 | Format commit + secrets + goldens | W1.2-1.4 | CI-1 | no |
| `PRODUCTION_FIX_b03_ci3.md` | CI-3 | Functions lint tooling | W1.5 | CI-2 | no |
| `PRODUCTION_FIX_b04_router1.md` | ROUTER-1 | Route-name resolution + go_router swaps | W2.1-2.3 | CI-3 | no |
| `PRODUCTION_FIX_b05_router2.md` | ROUTER-2 | Wiring + orphan surfacing + role gating | W2.4-2.6, 2.9 | ROUTER-1 | no |
| `PRODUCTION_FIX_b06_router3.md` | ROUTER-3 | Config-mode router tests + network blocker | W2.7-2.8 | ROUTER-1 | no |
| `PRODUCTION_FIX_b07_money1.md` | MONEY-1 | Server money integrity + menu cross-check | W3.1 | CI-3 | money-emulator |
| `PRODUCTION_FIX_b08_money2.md` | MONEY-2 | Refund-replay guard + cancelOrder | W3.2, W3.4 | MONEY-1 | money-emulator |
| `PRODUCTION_FIX_b09_money3.md` | MONEY-3 | Erasure coverage + index + webhook + dead code | W3.5-3.8 | MONEY-1 | GDPR emulator |
| `PRODUCTION_FIX_b10_rules1.md` | RULES-1 | Rules hasOnly alignment + read fixes | W4.1-4.3, 4.6, 4.7, 4.9, 4.10 | MONEY-3 | rules emulator |
| `PRODUCTION_FIX_b11_rules2.md` | RULES-2 | ownerInfo bootstrap + FCM lifecycle + drift | W4.4, 4.5, 4.8, 4.11 | RULES-1 | rules emulator |
| `PRODUCTION_FIX_b12_queue1.md` | QUEUE-1 | Offline queue deliverable + DLQ UI | W5.1 | RULES-1 + ROUTER-1 | rules emulator |
| `PRODUCTION_FIX_b13_queue2.md` | QUEUE-2 | Retry coverage | W5.2 | QUEUE-1 | no |
| `PRODUCTION_FIX_b14_staffqueue.md` | STAFF-QUEUE | Queue staff status writes | W5.4 | RULES-1 + QUEUE-1 | rules emulator |
| `PRODUCTION_FIX_b15_push1.md` | PUSH-1 | Kitchen heartbeat scheduling | W5.3 | QUEUE-2 | no |
| `PRODUCTION_FIX_b16_push2.md` | PUSH-2 | End-to-end push chain + FCM timing | W5.5-5.6 | ROUTER-1 + PUSH-1 | no |
| `PRODUCTION_FIX_b17_wl1.md` | WL-1 | Generator key gate + shell fail-fast + flags | W6.1-6.3 | CI-3 | no |
| `PRODUCTION_FIX_b18_wl2.md` | WL-2 | Config drift + schema validation + dead keys | W6.4-6.6 | WL-1 | no |
| `PRODUCTION_FIX_b19_backend1.md` | BACKEND-1 | Generator backend bundle + runbook + deploy tool | W7.1 | MONEY-3 + WL-2 | no |
| `PRODUCTION_FIX_b20_backend2.md` | BACKEND-2 | Platform privacy layer + function auth gaps | W7.2-7.4 | BACKEND-1 | no |
| `PRODUCTION_FIX_b21_state1.md` | STATE-1 | Lifecycle correctness (dashboard/GPS/state machine/cart) | W8.1-8.4 | RULES-1 | no |
| `PRODUCTION_FIX_b22_state2.md` | STATE-2 | Family stream providers + query caps | W8.5, 8.7 | STATE-1 | rules emulator |
| `PRODUCTION_FIX_b23_state3.md` | STATE-3 | Thumbnails + first-frame boot | W8.8, 8.6 | STATE-2 | no |
| `PRODUCTION_FIX_b24_state4.md` | STATE-4 | Perf/state P2 + Isar versioning | W8.9, 03-P3, 02-P2 | STATE-3 | no |
| `PRODUCTION_FIX_b25_ux1.md` | UX-1 | AA contrast + ARB migration + money formatter | W9.1-9.3 | any (after BACKEND-2 ideal) | no |
| `PRODUCTION_FIX_b26_ux2.md` | UX-2 | Semantics + labels + PopScope + a11y P2 | W9.4-9.7 | UX-1 | no |
| `PRODUCTION_FIX_b27_ux3.md` | UX-3 | Consent + signup ToS + Art.20 export + privacy P2 | W9.8-9.11 | UX-1 | GDPR emulator |
| `PRODUCTION_FIX_b28_ux4.md` | UX-4 | Analytics funnel | W9.12 | UX-3 | no |
| `PRODUCTION_FIX_b29_color1.md` | COLOR-1 | AppColors theme-bypass elimination | W10 | any | no |
| `PRODUCTION_FIX_b30_release1.md` | RELEASE-1 | Release pipeline + versioning | W11.1-11.3 | all code batches | no |
| `PRODUCTION_FIX_b31_release2.md` | RELEASE-2 | Full battery + re-audit + OVERALL decision | W11.4-11.5 | ALL + RELEASE-1 | all emulator |

---

## 3.5 PARALLEL EXECUTION + MERGE-BACK PROTOCOL (2026-09-01 amendment — optional; non-parallel runs follow §3/§5 unchanged)

**Purpose:** let separate git worktrees run disjoint batches concurrently without breaking the ledger or predecessor gates.

**Eligibility (ALL three, else the run is not parallel-legal and must go sequential):**
1. **Predecessors-DONE-in-main:** every batch in the pool has ALL its `Predecessor:` rows (from §3) already DONE and committed into `main` (verify: their addenda exist in `FIX_VERIFICATION.md` at the pool start).
2. **File-disjoint:** no two pool members' evidence-table File sets intersect (verify mechanically after both commit: `git diff --name-only main...<branchA>` vs `...<branchB>` — zero shared paths). Batches colliding on: `functions/src/**` (CI-3 vs MONEY-1), `**/lib/main.dart` + routers (ROUTER-1 vs WL-1), `packages/core_ui/.../theme/*` (UX-1 vs COLOR-1), `core_app/firestore.rules`+harness (RULES-1 vs QUEUE-1/STAFF-QUEUE/MONEY-3), configs (WL-1/WL-2 vs UX-1/UX-2) are NOT pool-eligible together;
3. **Per-worktree ledger:** each agent appends its addendum ONLY to `FIX_VERIFICATION_<branch>.md` in ITS worktree (never the shared `FIX_VERIFICATION.md`, never `PRODUCTION_FIX_BATCHES.md` — index edits stay single-writer on main).

**Current legal pool (post-CI-1; grows as predecessors land):** `{CI-2 ∥ CI-3 ∥ ROUTER-1}`. CI-2 owns the format-only commit + secrets + goldens (commits only ITS worktree; merge FIRST); CI-3 owns `core_app/functions/**`; ROUTER-1 owns routers/mains/route_names/tests — file-disjoint; all predecessors DONE (CI-1 in main). Emulator-gated: none. A claimed 5-way incl. MONEY-1 (races CI-3 on `functions/src/*.ts`) or WL-1 (races ROUTER-1 on `apps/halal_boyz/lib/main.dart`) is NOT parallel-legal — record as such, don't fake a pool. A 4th/5th worktree stays idle (no fabricated work). **For the full 5-window run, §3.6 defines the territory partition + sync points and relaxes three START edges — it governs once the operator starts the fleet.**



**Bootstrap per worktree (CMD):** worktrees `..\resturant-cline-1..5` + branches `cline/task-1..5` already exist; after committing main, fast-forward all five:
```cmd
git -C <repo>-worktree merge main & git -C <repo>-cline-2 merge main & git -C <repo>-cline-3 merge main & git -C <repo>-cline-4 merge main & git -C <repo>-cline-5 merge main
git worktree list
```
then per agent, in-tree, before the batch: `flutter pub get` (emulator-gated pools additionally `firebase --version`). Worktrees 4–5 stay idle this round — do NOT fabricate work for them.

**Merge-back (after each worktree's batch is DONE + committed + its addendum written to its per-worktree ledger):** from `main`:
```cmd
cd /d <repo>
git merge cline/task-1        (CI-2 — merge FIRST)
git merge cline/task-2        (CI-3)
git merge cline/task-3        (ROUTER-1)
```
- No shared files ⇒ clean merges expected. If a conflict appears: STOP, resolve manually, record — never force-resolve a real content conflict with `-X`.
- Reconcile ledgers: append each `FIX_VERIFICATION_cline-task-N.md` addendum into the canonical `FIX_VERIFICATION.md` (order = merge order); delete the per-branch ledger files in the same commit.
- After merge-back, fast-forward idle worktrees off updated `main` before their next batch.

---

## 3.6 FIVE-WINDOW TERRITORY MAP (2026-09-01 amendment — the file-set partition. Governs START eligibility; merge-order + per-worktree-ledger rules from §3.5 are unchanged)

**Principle:** partition by batch CHAIN (territory), not raw file sets — several files are touched by batches in different chains (collision ledger below), so ownership is per-territory and cross-territory predecessors become SYNC POINTS: the window waits until that batch is merged into `main`, runs `git merge main` inside its worktree (clean — territories disjoint), re-verifies its gates, proceeds. Merge-back is ROLLING: the operator merges each window's finished batch immediately (CI-2 first, then any disjoint order); windows never wait for the whole fleet, only for their named syncs.

| Win | Territory (owns) | Chain (strict order) | Sync points (`git merge main` + gate re-run before starting) |
|---|---|---|---|
| 1 | CI + functions/money: `.github/workflows/carnama_ci.yml`, secrets, goldens, `core_app/functions/**` | CI-2 → CI-3 → MONEY-1 → MONEY-2 → MONEY-3 | none — CI-2 merges FIRST; every other window waits for it once |
| 2 | Router/nav/queue/push client: routers + route_names, core `main.dart`, checkout_screen, sync_queue, kitchen offline/dispatcher, push services | ROUTER-1 → ROUTER-2 → ROUTER-3 → QUEUE-1 → QUEUE-2 → PUSH-1 → PUSH-2 | QUEUE-1 ← RULES-1 (W4); PUSH-1 ← WL-2 (W3 owns `core_config_adapter.dart`); PUSH-2 ← WL-1 (W3) |
| 3 | White-label + provisioning: `tool/whitelabel.dart`, both `client_config.json`, shell `main.dart`/adapter, generator, platform manifests, `deploy_backend.dart` | WL-1 → WL-2 → BACKEND-1 → BACKEND-2 | BACKEND-1 ← MONEY-3 (W1) |
| 4 | Rules + state/services: `firestore.rules` + rules harness, admin/bootstrap, owner/GPS/cart/stream state, kitchen/delivery/POD services, Isar | RULES-1 → RULES-2 → STATE-1 → STATE-2 → STAFF-QUEUE → STATE-3 → STATE-4 | STAFF-QUEUE ← QUEUE-1 (W2); STATE-2 ← ROUTER-2 (W2 owns `merged_menu_provider.dart`); STATE-3 ← UX-2 (W5 owns early `home_screen/menu_screen` edits) and ← PUSH-2 (W2, core `main.dart`); STATE-4 after QUEUE-1 (W2 owns `sync_queue.dart`); RULES-1→STATE-1 edge is internal to W4 |
| 5 | UX/a11y/l10n/theme: ARB + money formatter, screen a11y/semantics, consent/telemetry/signup/export, analytics pkg, core_ui theme | UX-1 → UX-2 → UX-3 → UX-4 → COLOR-1 | UX-2 ← STATE-1 (W4 owns `owner_dashboard.dart`) + QUEUE-1 (W2 owns `checkout_screen.dart`); UX-3 ← MONEY-3 (W1, `index.ts` erasure region); UX-1 ← WL-2 (W3 — UX-1's contract byte-syncs BOTH `client_config.json` `theme` blocks, W3-owned files; discovered at fleet start 2026-09-01) |

**START-eligibility relaxations (recorded amendments):** ROUTER-1, WL-1 and RULES-1 may START once CI-2 is merged — their per-spec `Predecessor:` rows (CI-3 / CI-3 / MONEY-3) were map-linearity, not file dependencies: their file sets are provably disjoint from the functions chain. MONEY-1 still waits for CI-3 (both touch `functions/**`). Any batch whose gates expose a REAL cross-territory dependency at execution time: STOP fail-closed, record the edge, re-serialize — never fake a green.

**Single-owner collision ledger (file → owning window; everyone else syncs first):** `sync_queue.dart` → W2 · `kitchen_service/delivery_service/proof_of_delivery_service.dart` → W4 · `functions/src/index.ts` → W1 (W3's BACKEND-2 and W5's UX-3 both edit it → order their merges BACKEND-2 before UX-3's index.ts edit starts) · core `main.dart` → W2 (UX-3/STATE-3 blocks region-disjoint; merge PUSH-2 before either starts) · shell `main.dart` + generator outputs → W3 · `home_screen/menu_screen/cart_screen` early edits → W5 (UX-1/2); W4's STATE-3/STATE-4 sync after UX-2 · `owner_dashboard.dart` → W4 (STATE-1) · `checkout_screen.dart` → W2 (QUEUE-1) · `merged_menu_provider.dart` → W2 (ROUTER-2) · `core_config_adapter.dart` → W3 (WL-2).

**Emulator discipline (one machine):** `firebase emulators:exec` is serial GLOBALLY — W1 (money ×2, GDPR, rules ×2), W4 (rules ×2) and W5 (GDPR) must never run emulator suites simultaneously: stagger them, or give each worktree its own emulator ports in its own `firebase.json`. Repo-wide `flutter test`/`analyze`/`dart format` gates are safe concurrently but will thrash a single CPU — stagger heavy suites when practical.

**RELEASE-1/RELEASE-2 are NOT window work:** after the final merge they run on `main` only (RELEASE-2 = full battery + re-audit of the merged tree; its verdict is the only clearance authority).

---

## 4. FILE LAYOUT (token-lean execution model)

- Full solutions spec = `PRODUCTION_FIX_PROMPT.md` (waves W1-W11 + sections 12-14). Never duplicated.
- Execution index = THIS file (rules + Universal Gate Set U + environment/decisions + batch map).
- One spec per batch = `PRODUCTION_FIX_b<NN>_<tag>.md`. Each is self-contained for that ONE batch: evidence table (audit + master citations), design principle, acceptance contract (the HOW lives in the cited master wave), behavior-test table (T-x, red on today/green after), proof-gate checklist, honest residuals.
- An executing agent loads ONLY: this index + the ONE batch file + (when it needs the deep HOW) the cited master-wave subsection.

## 5. EXECUTION ORDER

**B0 -> CI-1 -> CI-2 -> CI-3 -> ROUTER-1 -> ROUTER-3 (or ROUTER-2) -> MONEY-1 -> MONEY-2 -> MONEY-3 -> RULES-1 -> RULES-2 -> QUEUE-1 -> QUEUE-2 -> STAFF-QUEUE -> PUSH-1 -> PUSH-2 -> WL-1 -> WL-2 -> BACKEND-1 -> BACKEND-2 -> STATE-1 -> STATE-2 -> STATE-3 -> STATE-4 -> UX-1 -> UX-2 -> UX-3 -> UX-4 -> COLOR-1 -> RELEASE-1 -> RELEASE-2.**

Strictly one batch per session; each ends with its Universal Gate Set + proof gates green and its addendum appended to `FIX_VERIFICATION.md`. On resume, verify the predecessor is DONE in the ledger before starting the next batch.

**END OF INDEX - load a batch spec file per session.**
