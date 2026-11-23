# WHITE_LABEL p33 — CONFIG DEAD-KEYS + FLAG TRUTH (tag: DEADKEYS)

**Batch:** P33 · **Master evidence:** `tool_uilib/p31/p31_proof_report.md` §Q3/§Q4/§Q10 (corrected 2026-10-04) +
`tool_uilib/p25/p25_report.md` (T-2 matrix, T-3 disposition register) · **Predecessor:** none strictly · **Merge slot:** AFTER p32
(predicted conflict: goldens — resolve by p32-first ordering + post-merge gate re-run, `WHITE_LABEL_BATCHES.md` §3.5.3)
· **Emulator lane:** only T-5 (B-5 stagger)

## §0 Rules (batch-specific — cite `METHOD.md`, do not restate it)

1. **P1/P2 law** + cite-not-rederive (p25 receipts, §1 REDs). Drift between this spec and code at HEAD ⇒ STOP with an evidence table (METHOD law 4) — two drift items are already known, see §1.
2. **Fail-safe owner defaults.** Every undecided product choice below carries a default that changes NO behavior (record in `DECISIONS-NEEDED-FROM-OWNER` inside the findings, mirrored to `DECISIONS_LOG.md` by the coordinator). Executing an owner-visible behavior change without its decision row = batch failure.
3. **Golden-neutrality rule for visual wirings (T-2):** attempt the wiring; if the full golden suite shows ANY pixel delta ⇒ the wiring is not behavior-neutral for shipped configs ⇒ **revert it and disposition the key `INTENTIONAL-INERT(reason)`** instead. p32's real gates make this checkable — that is why p32 merges first.
4. **Money law (T-3):** integer cents only; the charge path re-prices server-side (`functions/src/index.ts:899-926` — cite) and must stay untouched; this batch only hardens the quote input.
5. **Territory §2.** Forbidden: `pubspec.yaml`/`pubspec.lock` edits (the `firebase_remote_config` dependency question is a DECISION row only), `firestore.rules`, ARB files, goldens/baselines (p32's), the shared ledger.
6. **L-P4 inherited from p25:** every new guard/pin must FIRE on a planted violation and PASS at HEAD, both receipted.
7. **Never end on red.** Worktree mode inherits §3.5: in-worktree ledger, gates in-worktree, merge slot AFTER p32.

## §1 Baseline + drift + RED proofs

- **Tip:** `main` at claim time (base `a105a05`, or the p32-merged tip when serial). **B-1:** if p32 already merged, cite its ledger addendum.
- **BLOCKER (fresh receipts → `tool_uilib/p33/blocker_*`):** analyze ×4 → 0 · format → 0 · suites **core_app 2458 · core_ui 431 · core 396 · halal 75 · functions 169** (floors from p31 fresh receipts / p25 functions).
- **Known drift (code at HEAD wins — fix docs, not code):**
  - **D1:** `RUNBOOK_DEPLOY.md:117` still claims `seed_test_accounts.js:11` hardcodes a machine path — **STALE**: `core_app/tool/seed_test_accounts.js:17-23` (PERF-6c) resolves `GOOGLE_APPLICATION_CREDENTIALS` → ADC → fail-closed abort. Task T-4 corrects the doc.
  - **D2:** proof-report §Q4 "live gating uses the Firestore stream" — already corrected in-file 2026-10-04; this batch pins the truth as tests (T-1).
- **RED proofs (re-capture → `tool_uilib/p33/red_*`):**
  - **R1:** `featureEnabled(` in production sources = **1 hit, the definition** (`core_app/lib/app/config/app_config.dart:190-191`), callers 0.
  - **R2:** `featureFlagsProvider` consumers = **only** `features/admin/presentation/setup/tier_flag_manager_screen.dart:40` (admin editor) + export `labs.dart:100`; `.isEnabled(` in `lib/` = 0 → **no Dart feature consumes any flag**; the only gating flag is rules-side `strongAppCheck` (`firestore.rules:8-32`).
  - **R3:** `functions/src/index.ts:141-142` — `subtotalCents: z.number().int().min(0)` with **no upper bound**; test accepted `1000000000` (T-3 red).
  - **R4 (cite):** p25 disposition register `tool_uilib/p25/p25_report.md` T-3 = 16 rows (14 INERT / 1 REMOVE / 1 WIRED-BY) + engine-key matrix (28 keys × 2 configs).

## §2 Territory

| | Paths |
|---|---|
| **IN** | `core_app/lib/app/config/**` · `packages/core_ui/lib/src/theme/**` (T-2 wiring candidates) · `core_app/tool/whitelabel.dart` (schema/validator/disposition updates) · `core_app/functions/**` (T-3) · `RUNBOOK_DEPLOY.md` (T-4) · tests (new + the disposition/matrix pins) · `tool_uilib/p33/**` · `tool_uilib/p31/p31_proof_report.md` (D2 residual note only) |
| **OUT** | `core_app/test/**/goldens/**` + `test/ui|golden/*.dart` (p32) · `core_app/lib/l10n/**` · `firestore.rules`/`storage.rules` · `pubspec.yaml`/`pubspec.lock` · `FIX_VERIFICATION.md` · `*.g.dart`/`*.freezed.dart` · `apps/*/assets/client_config.json` (unless a T-2 row requires removing a dead key — then the schema-identity test must stay green and the edit is declared in findings) |

## §3 Problems → Acceptance → T-x

| T | What | Red→green proof required | Floor |
|---|---|---|---|
| **T-1** | **FLAG TRUTH (D-P33-1, default = INTENTIONAL-INERT).** (a) Correct the misleading usage docstring `feature_flags_service.dart:5` and the `featureEnabled` docs to state current truth (admin-editable, not consumed; rules-side `strongAppCheck` excepted). (b) New pin `core_app/test/config/flag_surface_truth_test.dart`: source-scans `lib/` — fails if a *new* production caller appears without the register row being updated (pattern: p25 T-3 zero-consumer scan + L-P4). (c) Decision row: WIRE real consumers (product batch, needs owner feature-by-feature sign-off) vs remain INERT — **fail-safe default INERT, no behavior change here.** | (b) **RED** on planted fixture caller (`red_t1_plant.txt`) · **GREEN** at HEAD (`green_t1_plant.txt`) · docstring diff quoted in findings. | Pin fires on plant, passes at HEAD; suite green |
| **T-2** | **DEAD-KEY DISPOSITIONS — close the p25 register for real.** Per remaining row, choose one (recorded with read-site citation): (i) **WIRE** if behavior-neutral under the §0-3 golden-neutrality rule — candidates: `theme.spacing.*`, `typography.*Size` → `app_theme.dart` text/metric reads; (ii) **INTENTIONAL-INERT(reason)** — `navigation.tabs` (evidence: hardcoded nav `home_screen.dart:136-186` includes a Search tab the config's route-tab list cannot represent — wiring would DELETE search ⇒ behavior change ⇒ INERT, redesign deferred to P35), `navigation.routes` (router builds from `screens[]`), `storeAndroidUrl`/`storeIosUrl` (remote-config-driven copy); (iii) REMOVE only with schema+identity tests updated and both shipped configs still valid. Every row ends classified in `config_key_disposition_test.dart` (extended) + the engine-key matrix gains read-sites for any wired key. | For each attempted wire: **RED** = matrix/disposition test failing pre-wiring (row shows unread) → wire → goldens byte-identical receipt (`green_t2_goldens_unchanged.txt`, run after p32) → matrix row now cites the read-site. For each INERT: register row green with written reason + evidence line-number. | Register: 0 unclassified rows · matrix green · goldens unchanged (or declared + justified under §0-3) |
| **T-3** | **TAX QUOTE CAP (functions).** Add an upper bound to `calculateTaxSchema.subtotalCents` (`.max(100_000_000)` = $1M sanity cap) + a caller-input test. Quote endpoint only — charge path (`index.ts:899-926`) untouched. | **RED:** pre-fix test showing `1_000_000_000` accepted → `red_t3_tax.txt`. **GREEN:** oversized input rejected with a clear error; all existing functions tests still pass. | functions 169+new, 0 fail |
| **T-4** | **DOC DRIFT D1:** rewrite `RUNBOOK_DEPLOY.md:117` to match HEAD (PERF-6c env→ADC→fail-closed order; cite `seed_test_accounts.js:17-23`); mirror the correction as the Q10 residual note in `tool_uilib/p31/p31_proof_report.md`. | Grep receipt: RUNBOOK no longer claims the hardcode (`grep -n hardcod RUNBOOK` → only true statements); findings quote old vs new line. | Docs match HEAD |
| **T-5** | **RULES-SUITE LOCAL RECEIPT (closes a proof-report UNVERIFIED).** Run the firestore-rules battery locally per CI/RUNBOOK command, output → `tool_uilib/p33/rules_suite_local.txt`. Emulator required ⇒ obey B-5 (stagger lane). If the lane is unavailable: record **UNVERIFIED** honestly + handoff to deploy smoke — an allowed outcome, never a fake. | Receipt file with exit code (or the honest UNVERIFIED block). | Receipt present |
| **T-6** | Full battery (§5) + census of disposition/matrix tests. | All §5 floors. | — |

**Handoffs (never fixed here):** flag-consumer wiring as product behavior → D-P33-1 owner decision (candidate batch P36) · `navigation.tabs` redesign (≤5 + More, Search representation) → P35 · `firebase_remote_config` declared-but-unused dependency → D-P33-4 owner decision (pubspec edit forbidden here) · ubuntu-CI parity → P32a.

## §4 Deliverable

`tool_uilib/p33/p33_findings.md` — six-way classification + the **disposition table** (key → class → reason → read-site/evidence line) + `DECISIONS-NEEDED-FROM-OWNER` (D-P33-1 flags, D-P33-2 tabs redesign, D-P33-3 store URLs, D-P33-4 unused dependency) with fail-safe defaults held + honest residuals + paste-ready ledger block `## APP COMPLETION DEADKEYS - ...`. Receipts under `tool_uilib/p33/`.

## §5 Acceptance (measurable floors — all must hold at batch tip)

1. analyze ×4 → 0 issues · format → 0 changed.
2. Suites: core_app **≥ 2458 + new pins** · core_ui ≥ 431 · core 396 · halal 75 · functions **169 + T-3 test** — 0 fail, 0 skip.
3. Disposition register: 0 unclassified rows; engine-key matrix green; flag-truth pin green.
4. Goldens: unchanged byte-wise, OR changed only under §0-3 with the neutrality receipt + declared list.
5. Coverage floor PASS, newUncovered = 0. `git diff --name-only` ⊆ §2-IN (pubspec/lockfile/rules absent).

## §6 Coordinator protocol (judge — fresh re-runs, never re-reads)

1. Re-run R1/R2 greps personally → caller counts still 0.
2. Plant an oversized `calculateTax` input → T-3 guard must reject; plant a `lib/` caller → T-1 pin must fire (then remove plants).
3. Spot-check ≥3 disposition rows against their cited read-sites at HEAD.
4. Verify goldens untouched (or the declared neutrality receipt holds), `tip ≠ base`, forbidden-path audit.
5. Append ledger addendum (single writer) → merge AFTER p32 → post-merge gate re-run on main (§3.5.3).

## §7 Executor quickstart (paste-ready)

```
You are the EXECUTOR for batch p33 (WHITE_LABEL_p33_config_deadkeys.md) in <repo>.
READ FIRST: 1) this spec (§0 binding) 2) METHOD.md 3) WHITE_LABEL_p25_generator_completeness.md + tool_uilib/p25/p25_report.md (register/matrix) 4) .clinerules/15-tests.md + 20-core-app-carnama.md 5) tool_uilib/p31/p31_proof_report.md §Q3-§Q4. §1 R1-R4 citable; re-capture R1-R3 live (they are load-bearing).
Mode A (default, single tree): git checkout -b cline/p33-config-deadkeys main   [run AFTER p32 merges]
Mode B (worktree, §3.5): git worktree add <repo>-p33 -b p33/config-deadkeys main
  → in-worktree ledger FIX_VERIFICATION_p33.md; merge slot AFTER p32; B-2 check: zero shared paths vs p32's diff;
    golden checks run only after p32's merge (sync point per §3.5.3).
Cadence: SYNC → BLOCKER (§1) → T-1..T-6 red→green → §5 gates → §4 deliverable → STOP (judge next).
Commit: feat(config): DEADKEYS <imperative> | body: bullets + proof numbers + Refs: WHITE_LABEL_p33_config_deadkeys.md
NEVER: edit pubspec/lockfile/rules/ARB · wire owner-visible behavior without its decision row · touch goldens or the shared ledger · end on red.
```
