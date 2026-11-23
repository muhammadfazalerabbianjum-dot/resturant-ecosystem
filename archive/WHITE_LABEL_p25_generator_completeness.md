# WHITE_LABEL p25 — UI-14: generator completeness, dead config keys, guard correctness

**Batch:** UI-14 (p25). **Predecessors:** UI-9 (p19, generator/config schema mirror) and UI-12 (p22) merged;
`p25` is serialized behind `p19` by the exclusive-territory law (same generator/config files) — both are merged
on main. **Runs concurrently with UI-8 (p18)** under the carve-out in §2b.
**Floor:** `git merge-base --is-ancestor c05faf7 HEAD` must exit 0 (rule W2b: a sync claim is only valid with this proof quoted).

## §0 Rules (inherited p10 §0 0.1–0.7 + fleet laws W1–W7 + R-W/R-X/R-Y)

### Batch laws
- **L-P1 (warnings are not errors).** The generator already rejects invalid configs. Completeness findings are
  **warnings**: they must never fail a generation that succeeds today, and must never change an emitted byte.
  Prove with the existing validation test staying green plus a dry-run content-drift check.
- **L-P2 (no product wiring).** A config key that is parsed but read by nobody is **disposed**, not wired.
  Wiring any key into a screen is a product change owned by a spec wave — record a handoff row instead.
- **L-P3 (read-only on shipped semantics).** `core_app/lib/app/config/**` parsers, the ARB files and the
  accessibility guard are read-only here. If a disposition requires changing a parser, STOP and report.
- **L-P4 (a verifier that can never pass is noise).** Every guard or verifier touched must be shown to FIRE on a
  broken input and PASS on a correct one, in the same receipt set.
- **L-P5 (AA guard is an acceptance gate, not a courtesy).** `core_app/test/ui/accessibility_guidelines_test.dart`
  reads both shipped client configs; it must stay green with **zero edits** (git-diff proof).

## §1 Baseline (P1, verified at `c05faf7` before dispatch)

- **The F-8 root cause, located:** `core_app/tool/whitelabel.dart:127` —
  `List<String> validate({bool allowUsdFallback = false})` returns `errors` only. It checks *validity*: section
  presence (`app`/`firebase`/`theme`/`navigation`/`features`), non-empty `app.name`/`bundleId`, and firebase key
  emptiness/placeholders (helper `checkFirebaseKey`, placeholder pattern `_placeholderPattern` at `:88`, mirror at
  `:2077`). It never reports a *missing brand key*. That is why halal_boyz silently shipped with Material-default
  inputs/chips/backdrop (the B9 defects).
- **Existing generator/config tests (the additive surface):** `core_app/test/tool/whitelabel_config_validation_test.dart`,
  `whitelabel_schema_identity_test.dart`, `whitelabel_money_template_test.dart`, `whitelabel_backend_bundle_test.dart`,
  `whitelabel_platform_privacy_test.dart`; `core_app/test/config/client_config_schema_test.dart`.
- **AA guard:** `core_app/test/ui/accessibility_guidelines_test.dart` exists and reads both client configs' themes.
- **AUD2R-04 (dead keys):** parsed/validated with no production consumer — `navigationTabs`,
  `navigationHiddenRoutes`, `navigationRoutes`, `storeAndroidUrl`, `storeIosUrl`, `typography.*Size`,
  `theme.spacing.*`; `currencyCode` has real consumers and is **not** in scope.
- **AUD2R-01:** `tool_guard/check_hygiene.ps1` — the auditor-territory rule emits `[RULE 4]` (line 58) while
  `[RULE 4]` is also the root-litter label used seven times (`:84`–`:102`); the rule-number space therefore
  collides and the docblock disagrees with the code.
- **AUD2R-02:** `tool_guard/verify_ignore_rules.ps1` — the probe table expects `tool_archive/perf2_litter.tar.gz`
  and `tool_archive/perf2_judge_litter.tar.gz` to be **`untracked`** (`:62`–`:63`), but batch B10 committed both
  as tracked tarballs → the verifier reports `RESULT: FAIL (2 of 34 probes misclassified)` and **can never pass**.
- **F3-05 residual:** `apps/halal_boyz/assets/client_config.json:43` still carries `"referrals": true` (the
  capability was removed from the service default by p21/D-2; the parser tolerates the orphan). The l10n key
  `enterReferralCode` also survives in both ARBs + generated l10n with zero consumers — **ARB removal is p18's
  lane, not this batch's** (handoff row).
- **V4 (LOW):** B10's `.gitignore` uses global `*.log` / `*.info` with a single negation.

## §2 Territory (exclusive)

MODIFIED:
- `core_app/tool/whitelabel.dart` — `validate()` gains a **warnings** channel + truthful docblock. The error
  semantics, messages and ordering stay byte-identical (L-P1).
- `tool_guard/check_hygiene.ps1` — rule label/docblock truth only (behaviour unchanged).
- `tool_guard/verify_ignore_rules.ps1` — probe expectations corrected; verifier must exit 0 on a correct tree.
- `apps/halal_boyz/assets/client_config.json` — the single `referrals` line (T-4).
- `.gitignore` — **only if the owner approves D-P25-1** (V4 narrowing). Otherwise record the decision and leave it.

NEW:
- `core_app/test/tool/whitelabel_completeness_warnings_test.dart` (T-1)
- `core_app/test/tool/client_config_engine_key_matrix_test.dart` (T-2)
- `core_app/test/tool/config_key_disposition_test.dart` (T-3)
- `tool_uilib/p25/**` (receipts, report, guard self-test receipts)

FORBIDDEN (explicit, fail-closed): `core_app/lib/l10n/**` (ARB + generated — p18's lane) ·
`core_app/lib/features/**` · `packages/**` (incl. `core_ui`) · `core_app/functions/**` · any `*.rules` file ·
`core_app/lib/app/config/**` parser semantics (read-only; changed parser ⇒ STOP + handoff) ·
`core_app/test/ui/accessibility_guidelines_test.dart` (read-only, L-P5) · `FIX_VERIFICATION.md` ·
existing tests beyond additive changes named one-by-one in the report.

### §2b Concurrent-wave carve-out (binding)
This batch runs beside **UI-8 (p18)**, whose territory is the ARB pair + `formatCurrencyCents` + RTL fixes in
`features/**` and `core_ui/**` + RTL goldens. Therefore:
- p25 must not touch `core_app/lib/l10n/**`, `features/**`, `packages/**` — those are p18's.
- p18 must not touch `tool_guard/**`, `core_app/tool/**`, `apps/halal_boyz/assets/client_config.json`, `.gitignore`
  — those are p25's (recorded as p18 Amendment A2).
- Any needed change in the other lane's files is a **handoff row**, never an edit.


## §3 T-x table

| Task | Deliverable | Acceptance |
|---|---|---|
| T-1 | **Completeness warnings** in `validate()` (F-8): an engine-surfaced visual key a client config leaves unset produces a named warning (`WARNING: theme.components.input.* unset — Material default will render`). Errors unchanged; exit code unchanged for today's configs. | RED: the new test fails on the current generator (no warnings emitted). GREEN: warnings present for a synthetic incomplete config, absent for a complete one; existing `whitelabel_config_validation_test.dart` green; generator dry-run **CONTENT-DRIFT 0** (L-P1). |
| T-2 | **Engine-key matrix test** (the systemic fix): a single in-test list of engine-read config keys (each row citing its read site) × each shipped config; every unset key is either a **failing row** or an allowlist entry carrying a written reason. | RED on today's gaps; GREEN after allowlisting with reasons. This allowlist is the artefact that makes F-8 unrepeatable. |
| T-3 | **AUD2R-04 disposition** (+ pinned test): every parsed-but-unread key classified `WIRED-BY(<spec>)` / `INTENTIONAL-INERT(<reason>)` / `REMOVE(<owner>)`; `config_key_disposition_test.dart` pins the classification so it cannot drift silently. | Disposition table in the report with a read-site citation per key; test RED before it exists. No wiring, no removal (L-P2) — handoff rows only. |
| T-4 | **F3-05 residual:** remove `"referrals": true` from the halal config; prove the parser tolerates the removal, the AA guard is untouched and green, and the halal suite is green. | RED: a test asserting the orphan key is absent fails pre-edit. GREEN after the one-line removal; `git diff` proof only that line changed; AA guard `git diff` **empty**. |
| T-5 | **Guard repairs (AUD2R-01 + AUD2R-02):** give the auditor-territory rule its own number and make the docblock match; correct the archive expectations so `verify_ignore_rules.ps1` can pass; add a self-test proving each guard **fires** on a broken input. | Guard self-test receipts: broken probe ⇒ exit ≠ 0, correct tree ⇒ exit 0 (L-P4). Docblock == emitted labels, verified by grep. |
| T-6 | **V4 disposition** (owner-gated, D-P25-1): narrow the global `*.log`/`*.info` rules **or** keep them and record why, plus a probe proving a legitimate fixture path stays addable. | Owner decision recorded; if narrowing, the probe set + `check_hygiene` stay green. LOW: may close as "keep, documented". |

## §4 Deliverable

`tool_uilib/p25/p25_report.md`: warnings table (key → message → read site) · the T-2 matrix with allowlist reasons ·
the T-3 disposition table · guard self-test receipts · six-way classification · DECISIONS-NEEDED-FROM-OWNER
(D-P25-1 `.gitignore` narrowing; the `enterReferralCode` ARB orphan handed to p18; any key proposed for removal) ·
UNVERIFIED (non-empty is allowed) · DRIFT · handoff table · paste-ready `## APP COMPLETION UI-14 (p25)` ledger block.
`FIX_VERIFICATION.md` is never touched.

## §5 Acceptance

1. `flutter analyze --fatal-infos` (core_app) + `dart analyze` (core, core_ui) clean; halal clean.
2. `dart format --output=none --set-exit-if-changed .` → 0 changed.
3. Suites 0 skip, no drop: core_app ≥ its current count, core_ui / core / halal_boyz held, `functions` untouched.
4. AA guard green with **zero** edits (L-P5, git-diff proof).
5. `whitelabel_schema_identity_test.dart` green; generator dry-run CONTENT-DRIFT **0**.
6. Guard self-tests: fire on a broken input, pass on a correct tree (L-P4).
7. Territory: `git status` proves zero forbidden paths; every touched file named in the report.
8. Nothing uncommitted; per-task commits; never end on red.

## §6 Judge + close

Coordinator re-runs 1–3 and 5 independently, spot-checks the T-2 allowlist reasons against their read sites,
verifies the AA guard diff is empty, then flips `AUD2R-01`, `AUD2R-02` and (if D-P25-1 resolves) `AUD2R-04`
plus the F3-05 residual in `AUDIT_TRIAGE_STAGE3.md`, and appends the ledger block.

## §7 Executor quickstart

1. SYNC: assert branch == `cline/w4-p25`; tracked tree clean; `git merge --ff-only main`; prove
   `git merge-base --is-ancestor c05faf7 HEAD` = 0 (W2b). `flutter pub get`.
2. BLOCKER gate: analyze ×3 + halal; format 0; core_app / core_ui / core / halal suites 0 skip;
   `cd core_app/functions && npx tsc --noEmit && npm test`. Quote each into `tool_uilib/p25/gate_baseline.txt`.
   Red ⇒ STOP + evidence table.
3. RED per task, captured to `tool_uilib/p25/red_t<N>.txt`; GREEN in T-1 → T-6 order, one commit per task.

**END OF UI-14 SPEC — §2b concurrent carve-out binds beside UI-8 (p18).**

