# WHITE_LABEL_p37_nine_push — NINE-PUSH (the 9/10 push)

| | |
|---|---|
| Batch / tag | **p37 / NINE-PUSH** |
| Predecessor | p36 (DONE, pushed `ee3d8b5f` · `13e2fe72` · `623d7bdf`) |
| Base at dispatch | current `cline/p32-golden-gates` tip — re-hash in §1 BLOCKER |
| Owner decision | **D-P37-1** (wire the six Firestore feature flags; inherited from D-P33-1) — **AWAITING**; fail-safe = branch B (§0-4) |
| Emulator lane | no (widget/golden-covered) |
| Ratings targeted | APP 8→9 · GENERATOR 8.5→9 · UI 7.5→9 · Customizability 6→9 (ratings = 2026-10-08 generator-grade session) |
| Method | `METHOD.md` §1–§9 — laws 1–10 apply verbatim; this file encodes the batch-specific exceptions only |

## §0 Rules (binding)

- **0-1 Cite-not-rederive.** p25 disposition register (`tool_uilib/p25/p25_report.md`), the p33 spec (flag truth), audit `AUDIT_A11Y_L10N_UX.md` (P1-A11Y-CONTRAST), p36 spec + receipts (`tool_uilib/p36/`). Re-open a cited file:line only to verify it is still true (proof law), never to restate it.
- **0-2 Red→green, receipts.** Every task captures a failing proof BEFORE its fix → `tool_uilib/p37/<task>_red.txt`; the passing proof → `<task>_green.txt`. No fix ships without its red.
- **0-3 Golden neutrality.** T-1/T-2/T-3 must leave all 152 baselines **byte-identical** (shipped primaries are dark; shipped flags default true; shipped config currency = the runtime doc value). Any diff = STOP + receipts + report. Regeneration requires explicit owner approval — never to make a broken layout pass.
- **0-4 D-P37-1 fail-safe (METHOD law 7).** If the owner has not flipped D-P37-1 by dispatch, executor runs **branch B** for T-2 (no wiring; record in `core_app/DEFERRED.md` + `DECISIONS-NEEDED-FROM-OWNER`), never blocks, never silently assumes. **FLIPPED → branch A, owner 2026-10-08 — recorded in `DECISIONS_LOG.md` §"p37 batch decisions"; T-2 wires all six flags.**
- **0-5 Hygiene.** No suppressions (`// ignore*`), no stubs/TODOs, no new packages, no ARB/l10n changes, no lockfile/`pubspec.yaml`/`*.g.dart`/`*.freezed.dart` edits. `FIX_VERIFICATION.md` = coordinator-only (METHOD §0).
- **0-6 Territory exclusivity.** §2 below; cross-territory findings = handoff notes, not drive-by fixes (law 5).
- **0-7 Spec-vs-code STOP.** If any P1 in §1 is stale at HEAD, change nothing — ship an evidence table and report (law 4).

## §1 Baseline + blocker gate

**Tip:** `623d7bdf` (p36 M3), branch `cline/p32-golden-gates`. Re-run the full gate set at dispatch; floors measured **2026-10-08** this session:

| Suite | Floor | Gate | Floor |
|---|---|---|---|
| core_app unit | **2500** | analyze ×4 | **0** (infos fatal) |
| core_ui | **431** | dart format | **0** changes |
| packages/core | **396** | goldens | **152 baselines, byte-gate 0** |
| apps/halal_boyz | **77** | dry-run | **EXIT=0** |
| core_app tool | **231** | anomaly detectors | **0** |
| functions | **169** (p33 floor — re-measure in BLOCKER) | skips / ignores | **0** |

**RED proofs (P1 opened 2026-10-08):**

- **R1 — contrast.** `packages/core_ui/lib/src/ui/brand_button.dart:74-79`: label, icon and spinner all paint `AppColors.background` on `Theme.of(context).primaryColor`; `packages/core_ui/lib/src/theme/app_colors.dart:22` = `Color(0xFFFFFFFF)` → fixed white on every primary CTA. Audit: `AUDIT_A11Y_L10N_UX.md:336` (P1-A11Y-CONTRAST, cart BC → checkout → place-order path).
- **R2 — flags.** `featureEnabled(...)` callers = **0** at HEAD; `app/config/feature_flags_service.dart:5` and `:132-147` are docstring/demo only; `featureFlagsProvider` consumers = its own definition (`feature_flags_service.dart:29`), the admin screen (`tier_flag_manager_screen.dart:40`), and the re-export (`labs.dart:100`). Zero customer/kitchen/owner gating.
- **R3 — currency.** Both shipped configs carry `currency: {"code":"USD","symbol":""}` with **0 Dart readers**; `restaurant_config_model.dart:92` hard-defaults `?? 'USD'`; the customer money path resolves the Firestore doc only (`menu_screen.dart:182-188`, W9.3) — the JSON block seeds nothing.
- **R4 — honesty.** p25 register (`tool_uilib/p25/p25_report.md`): 14 keys INERT / 1 REMOVE / 1 WIRED-BY, still present in both shipped configs (top-keys: `_meta, app, currency, environment, firebase, features, theme, navigation, screens`). The engine-key matrix (`core_app/test/tool/client_config_engine_key_matrix_test.dart:8-21`) pins READ keys only — no inverse test forbids unread promises.
- **R5 — deploy.** The stamp emits `backend/firestore.rules` + `backend/firestore.indexes.json` and prints their paths (`core_app/tool/whitelabel.dart:1922-1931`) but ships **no copy-paste deploy command**, and the new-project flutterfire login path is undocumented beyond the `--skip-firebase` escape.

## §2 Territory

**IN:** `packages/core_ui/lib/src/**` (brand_button, theme/color helpers); `core_app/lib/app/config/**` (`client_config`, `currency_format`, feature-flag service); the feature widgets behind the six flags (enumerated at dispatch); `core_app/tool/whitelabel.dart`; `core_app/test/**`; the two shipped configs `core_app/assets/client_config.json` + `apps/halal_boyz/assets/client_config.json`; this spec + the `WHITE_LABEL_BATCHES.md` §7 registry row.

**FORBIDDEN:** lockfiles, `pubspec.yaml`, `*.g.dart`/`*.freezed.dart`, ARB/l10n, `firestore*.rules` + `functions/**` (except suite re-measure), `FIX_VERIFICATION.md` (ledger = coordinator), goldens (§0-3), receipts under `tool_uilib/p25|p26|p36/`, other batch specs.

## §3 Problems → Acceptance → T-x

Order of execution: **T-1 → T-2 → T-3 → T-4 → T-5 → T-6** (priority order agreed with owner: contrast first; T-4 reads T-2/T-3 outcomes).

### T-1 — AA contrast (UI 7.5→9 move #1)

- **Problem (R1):** fixed white label/icon on primary backgrounds.
- **Fix shape:** derive the foreground from WCAG relative-luminance of the actual background (dark primary ⇒ light label stays; light primary ⇒ dark label), one shared helper in `core_ui`; apply to `brand_button` primary/disabled paths plus every site the audit's contrast list names (enumerate in-territory).
- **Acceptance:** NEW unit test: (a) contrast ratio ≥ **4.5:1** for each shipped `theme.colors.primary/secondary/accent` against its resolved foreground; (b) red witness — a planted light primary (`0xFFFFC107`-class) with the old fixed white measures **< 4.5** and with the fix **≥ 4.5**. Goldens byte-identical (§0-3).
- **Proof:** `T-1_red.txt` / `T-1_green.txt`. **Floor:** core_ui ≥ **431** + new tests.

### T-2 — flag wiring (Customizability 6→9 move #1; gated by D-P37-1)

- **Problem (R2):** `smartReorder`, `waitlist`, `promoCode`, `deliveryTracking`, `loyaltyPoints`, `tourMode` are advertised but inert.
- **Branch A (owner flips D-P37-1):** each flag gates its entry point through `ref.watch(featureFlagsProvider).valueOrNull?.isEnabled('<flag>') ?? true` (default-true = shipped behavior unchanged). Acceptance: ≥ **6** production `isEnabled` call sites, one per flag, pinned by a grep-style test; per-flag widget test — flag `false` ⇒ the control is absent; shipped/default config ⇒ goldens **byte-identical**; admin-toggle reflection test with a fake stream (flip ⇒ next pump shows the change).
- **Branch B (fail-safe, §0-4):** no wiring; record the standing decision in `core_app/DEFERRED.md` (one row, owner + reason) and `DECISIONS-NEEDED-FROM-OWNER`; green receipt = the DEFERRED row + a test asserting shipped flags stay documented as inert (truth-pin, per the p33 spec's citation — do not re-derive its rules).
- **Proof:** `T-2_{red,green}.txt` (branch actually run, named in the receipt). **Floor:** core_app ≥ **2500** + new tests; golden byte-gate 0.

### T-3 — currency seed (APP 8→9 move)

- **Problem (R3):** `currency.code`/`currency.symbol` in the config JSON have zero readers; money formatting falls back to the Firestore doc, else USD.
- **Fix shape:** `AppConfig` gains `currencyCode` / `currencySymbol` getters (absent ⇒ `''`); one shared resolver next to `formatCurrencyCents` (`app/config/currency_format.dart:56-73`) implements precedence **runtime doc → config JSON → `'USD'`**, and the customer money path (`menu_screen.dart:185-188`) goes through it.
- **Acceptance:** NEW tests — (1) getter pin (reads both shipped configs' `currency` block); (2) precedence chain: doc-present ⇒ doc wins, doc-absent/empty ⇒ config value wins, config-missing ⇒ `USD`; (3) liveness: the config key has ≥ 1 production reader (pinned). Goldens byte-identical (§0-3 — shipped runtime doc values unchanged).
- **Proof:** `T-3_{red,green}.txt`. **Floor:** core_app ≥ **2500** + new tests.

### T-4 — config honesty: inverse matrix + fail-closed validate (GENERATOR 8.5→9 move)

- **Problem (R4):** shipped configs advertise keys nobody reads; the engine-key matrix only proves read-keys are present, never that unread keys are absent.
- **Fix shape:** (a) NEW **inverse-matrix** test — every top-level key (and every p25-registered dotted path) in BOTH shipped configs ∈ { production-read site (cite `file:line`), allowlist entry with a WRITTEN reason } — flags/navigation/currency rows resolve to T-2 branch outcome + T-3; (b) `validate()` fails closed on unknown **top-level** keys (`_meta` allowlisted with reason); (c) **amended by owner decision D-P37-2 (2026-10-08): inert schema keys STAY in the shipped configs with register-written reasons** — `validate()` requires the `navigation`/`features` sections and the disposition register pins their presence ("every INERT row names a key the shipped configs really carry"); the dead-key trim is a later owner wave, not p37. The inverse matrix + fail-closed unknown-top-key gate are the p37 honesty deliverable.
- **Acceptance:** inverse test green; `validate()` rejects a planted unknown key (red witness → green); tool suite ≥ **231** stays green (fix fixtures forward if stricter validation reddens them — never weaken the test); config load path still parses both shipped configs.
- **Proof:** `T-4_{red,green}.txt`. **Floor:** core_app tool ≥ **231** + new tests.

### T-5 — deploy runbook in the output (APP/GENERATOR move)

- **Problem (R5):** artifacts printed, no command; new-project flutterfire path undocumented.
- **Fix shape:** first re-verify what the stamp actually emits (Spec-vs-code, §0-7), then extend the backend print block (`whitelabel.dart:1922-1931`) and the emitted receipt/README with exact copy-paste deploy commands against those artifacts (project id from config, index/rules paths) + one runbook line for the new-project flutterfire login (vs `--skip-firebase`). **No real deploy** (no Blaze in this environment).
- **Acceptance:** dry-run **EXIT=0** and its receipt/README contains the commands; a test pins the emitted template lines (no drift); commands match the emitted file set.
- **Proof:** `T-5_{red,green}.txt`. **Floor:** dry-run EXIT=0, tool suite ≥ **231**.

### T-6 — full battery (closes the batch)

- Gates: analyze ×4 = **0** · format **0** · six suites at §1 floors · 152 goldens **byte-identical** · dry-run EXIT=0 · anomaly detectors **0** · 0 skips/`// ignore*`/TODO · T-1..T-5 red+green receipts all present.
- Deliver the paste-ready `FIX_VERIFICATION` block to the coordinator (executor never edits the ledger).

## §4 Deliverable format

Code + tests strictly inside §2; receipts `tool_uilib/p37/T-{1..6}_{red,green}.txt` + `battery.txt` (raw command output); this spec's §5 filled with measured numbers (never asserted); coordinator-only afterwards: §7 registry row flip → `FIX_VERIFICATION.md` append → commit/push **after owner approval** (standing rule: never commit/push unasked).

## §5 Acceptance (measurable — all must hold)

**MEASURED 2026-10-08 (T-6 battery; raw output `tool_uilib/p37/battery.txt` + `T-6_*.txt`):**

1. core_app unit ≥ **2500** + T-3/T-4/T-2A new tests · core_ui ≥ **431** + T-1 tests · packages/core ≥ **396** · halal ≥ **77** · tool ≥ **231** · functions ≥ **169** (re-measured). **Measured: core_app 2541 · core_ui 437 · core 396 · halal 77 · tool 239 · functions 169/169 — all green.** (Run 1 of core_app = +2540 with 1 pre-existing flake in `app_bootstrap_states_test` STEP 16 — not p37-caused; isolated rerun 9/9 green, run 2 = 2541 green; see `battery.txt`.)
2. `flutter analyze --fatal-infos` in `core_app` **and** `apps/halal_boyz` = **0**; `dart analyze` in `packages/core` + `packages/core_ui` = **0**; `dart format --set-exit-if-changed` repo-wide = **0**. **Measured: analyze ×4 = 0 · format 0 (847 files, 0 changed).**
3. 152 goldens byte-identical (byte-gate 0); **no golden regenerated**. **Measured: byte-gate 0 — no baseline modified vs HEAD; CI golden job (`test/ui test/golden`) +117 green; `--update-goldens` never invoked; `test/failures/**` artifacts stale (Oct 3/7), git-ignored.**
4. New proofs green: contrast-ratio (T-1), flag-gate or truth-pin per D-P37-1 branch (T-2), currency precedence (T-3), inverse-matrix + fail-closed validate (T-4), receipt deploy-command pin (T-5). **Measured: all green — `T-1`..`T-5` `_green.txt` present.**
5. Dry-run EXIT=0; anomaly detectors 0; zero skips, zero `// ignore*`, zero TODO/stubs; no package/lockfile/ARB changes. **Measured: dry-run EXIT=0 (emits `backend/DEPLOY.md` line) · detectors EXIT=0 · skips 0 in every suite · p37 diff introduces 0 `// ignore*`/0 TODO · no package/lockfile/ARB touched.**
6. Every T-x has BOTH red and green receipts with observed exit codes. **Measured: T-1..T-5 = 10/10 red+green receipts; T-6 = battery receipts with observed exit codes (run-1 red + run-2 green pair captured for the core_app suite).**

## §6 Coordinator protocol

1. **Judge:** re-run §5 personally; never trust the executor's self-report (METHOD §0).
2. **Merge:** follow `WHITE_LABEL_BATCHES.md` §3.5.3 cadence; p36 already merged on this branch (predecessor satisfied).
3. **Ledger:** coordinator is the single writer of `FIX_VERIFICATION.md` (paste the executor's block verbatim, prefixed `## APP COMPLETION NINE-PUSH`).
4. **Registry:** flip the §7 row to DONE with the merge hash; keep issue-coverage rows honest (issue #4 — dead keys + inert flags — is now owned by **p37 T-2/T-4**; p33 retains its T-3..T-5 = issues #5–#7).
5. **Push:** report gates to the owner; push only on owner approval.

## §7 Executor quickstart (paste-ready)

```
Batch p37 / NINE-PUSH @ <repo> (branch cline/p32-golden-gates)
Read: METHOD.md (laws 1-10) -> this spec in full -> WHITE_LABEL_p37_nine_push.md §0 is binding.
Verify §1 P1s are still true (R1..R5); stale => STOP with evidence table (§0-7).
Loop per task: red receipt -> fix -> green receipt -> next (order T-1 -> T-2 -> T-3 -> T-4 -> T-5 -> T-6).
T-2: check DECISIONS-NEEDED-FROM-OWNER for a D-P37-1 flip; absent => branch B (§0-4), never block.
Gates (re-run yourself):
  cd <repo>\core_app
  flutter test test/tool                       # >= 231
  flutter test                                 # >= 2500
  flutter analyze --fatal-infos                # 0
  dart run tool/whitelabel.dart <p36 dry-run args>   # EXIT=0 (args: see tool_uilib/p36 receipts)
  cd <repo> && dart format --output=none --set-exit-if-changed .   # 0
  flutter test packages/core_ui  # >=431 ; flutter test packages/core # >=396
  cd apps/halal_boyz && flutter test --exclude-tags=e2e,nightly,needs-emulator  # >=77
  flutter analyze --fatal-infos                # 0
Golden neutrality (§0-3): before/after byte-compare all 152 baselines; any diff => STOP + receipts.
Deliver: findings + paste-ready FIX_VERIFICATION block (NEVER edit the ledger yourself).
```

**END OF SPEC — dispatch executor(s) with §7 as the session prompt.**
