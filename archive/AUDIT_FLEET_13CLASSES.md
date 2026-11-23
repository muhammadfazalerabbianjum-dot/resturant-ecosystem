# AUDIT FLEET — the 13 anomaly classes, four read-only audits (then fix batches, then p16+)

**Purpose:** mechanically hunt each anomaly class (`ANOMALY_CLASS_PLAYBOOK.md`) BEFORE the next feature waves. Audits are **READ-ONLY**: they may write ONLY their findings + receipts under `tool_audit/audN/` and commit those; they must NOT modify lib/test/config/spec files. Findings → coordinator triage → FIX batches (red→green, fleet laws) → then p16+.

**Universal audit rules (all four):**
A1 **No fixes.** A code change in an audit is a failure of the audit. Exceptions: none.
A2 **Proof law.** Every finding carries the exact command + raw output (receipt file) and P1 file:line. Unverifiable items go to a mandatory UNVERIFIED section.
A3 **Four dispositions only:** FIX (needs a code/config change) · SPEC (needs a new batch contract) · ACCEPT (documented, deliberate) · FALSE-POSITIVE (documented, with why).
A4 **Live CRITICAL rule:** if a money/auth/security/launch-blocking issue surfaces (placeholder secret in a shipping path, fail-open catch, cross-tenant read, demo mode reachable in release), STOP the sweep and report it immediately as **CRITICAL** with the receipt — do not wait for the audit end.
A5 **Zero-modification proof:** final command `git status --porcelain --untracked-files=no` must show ONLY `tool_audit/audN/**` additions.
A6 **Deliverable:** `tool_audit/audN/audN_report.md` — findings table (id, class, severity, receipt, disposition, proposed fix-batch) + UNVERIFIED + a short "what I could not check and why".

## WORKTREE EXECUTION (binding — per `WHITE_LABEL_BATCHES.md` §3.5/§3.6)

W1 **Assignment (disjoint by territory):** AUD-1 → `<repo>-worktree` (`cline/task-1`) · AUD-2 → `cline-2` · AUD-3 → `cline-3` · AUD-4 → `cline-4`. (clone-5 idle — never fabricate work.)
W2 **Sync ritual (before ANY command):** first assert you are in the right tree/branch — `git -C <repo>-cline-N rev-parse --abbrev-ref HEAD` must print `cline/task-N` (the **D-AUD2-W1 correction**: AUD-2 ran in the main clone instead of `cline-2`, 2026 audit wave A; committing from the wrong tree is a W1 breach even when the content is A5-clean). Then `git -C <repo>-cline-N merge main` → the worktree tip must equal/descend from main; `flutter pub get` once per worktree; then blocker gate B-1..B-5: analyze (touched packages) + format check + the relevant suites green BEFORE the first sweep command. Red after a sync = STOP, report, re-serialize.
W3 **Territory = `tool_audit/audN/**` ONLY.** No other path may be modified, added, or deleted in the FINAL commit. Scratch/probe files (probe tests, throwaway dart scripts, temp parses) are permitted DURING the sweep under EITHER `tool_audit/audN/scratch/` OR — when the toolchain requires a package-relative path (e.g. a probe test must compile under `packages/*/test/`) — in that package with a name prefixed `_audN_` AND they MUST be deleted before the final commit. A5 proof then shows `tool_audit/audN/**` additions only.
W4 **Forbidden commands:** any `git checkout/merge/reset/rebase/stash/commit -a`, any write to `FIX_VERIFICATION.md` / specs / `pubspec.*` / `core_app/tool/whitelabel.dart` outside a dry-run temp dir, any `git add -A`, any push. Auditors COMMIT LOCALLY on their branch only; the coordinator merges (findings-only branches are safe by W3).
W5 **Staggered heavy runs:** `flutter test --coverage` and generator dry-runs are CPU-heavy — never run two worktree batteries simultaneously; if two audits both need a heavy run, the second waits (record the stagger in the report).
W6 **Commit format:** `aud<N>(13classes): <class list> sweep — findings + receipts` (one commit; receipts under `tool_audit/audN/`). Report file: `tool_audit/audN/audN_report.md` per A6.
W7 **Delivery:** auditor leaves the branch green with findings committed; coordinator verifies A5 (findings-only diff), merges into main, records the audit completion in the ledger. No auditor merge-backs, no ledger writes.



```
You are the AUDITOR (read-only) for AUD-1: code-vs-itself classes 1,2,3,13.
Worktree: <repo>-worktree (branch cline/task-1). Read <repo>\ANOMALY_CLASS_PLAYBOOK.md IN FULL + <repo>\AUDIT_FLEET_13CLASSES.md §WORKTREE EXECUTION (W1-W7). Rules A1-A6 bind.
0. SYNC FIRST (W2): git -C <repo>-worktree merge main; cd <repo>-worktree; flutter pub get; blocker gate: analyze (touched packages) + format check + relevant suites green BEFORE the first sweep command. Red => STOP + report.
C1 NAMESPACE COLLISIONS: enumerate every public name exported by packages/core_ui and packages/core (parse the barrels). For each name, grep the Flutter SDK (A:\flutter\packages\flutter\lib) for `class <Name>`; report every hit as a COLLISION CANDIDATE. Then prove live collisions: write a probe test under tool_audit/aud1/ importing the barrel + flutter/material and referencing each candidate unqualified; a compile error = live collision (quote it). Receipts: candidates + compile output.
C2 COVERAGE ATTRIBUTION: per package (core, core_ui, core_app) run `flutter test --coverage`; parse lcov; list every file <100% lines WITH uncovered line numbers; classify each uncovered line as (a) untested behavior, (b) never-executed declaration (const-evaluated ctor / abstract signature — the UI-1 class), (c) dead code. Also: grep the test tree for tests that CANNOT fail (expect(true, , no-expect bodies, only-pump tests). Receipts: lcov parses + uncovered-line table + vacuous-test list.
C3 DIVERGENT TWINS: for each concept with 2+ implementations, find all impls and build a PARITY TABLE on edge inputs (throwaway dart test under tool_audit/aud1/ printing the table): money formatting (formatCurrencyCents vs moneyCents vs inline NumberFormat in features), date/time formatting (every DateFormat site — check the locale param), currency symbol maps, phone/email/postcode validation, idempotency-key derivation, retry/backoff helpers, tax rounding. Differing rows = findings; classify intentional (documented) vs anomaly. Receipts: table + test source.
C13 DOC CLAIMS: grep lib/** and packages/** for `asserted by|pinned by|enforced by|guarded by|verified by`. For each: resolve the named file; confirm it actually asserts that property. Report stale/wrong/absent claims.
Deliver tool_audit/aud1/aud1_report.md per A6. Territory = tool_audit/aud1/** ONLY (W3; scratch probe files deleted before commit). Commit LOCALLY on cline/task-1 (W6); do NOT merge, do NOT push, do NOT touch FIX_VERIFICATION.md. Do not fix anything.
```

## AUD-2 — CLIENT & CONFIG (classes 6, 10, 11)

```
You are the AUDITOR (read-only) for AUD-2: client/config classes 6,10,11.
Worktree: <repo>-cline-2 (branch cline/task-2). Read <repo>\ANOMALY_CLASS_PLAYBOOK.md + AUDIT_FLEET_13CLASSES.md §WORKTREE EXECUTION (W1-W7). Rules A1-A6 bind.
0. SYNC FIRST (W2): git -C <repo>-cline-2 merge main; cd <repo>-cline-2; flutter pub get; blocker gate green BEFORE the first sweep command. Red => STOP + report.
C6 MECHANISM-VS-CONFIG MATRIX: (i) enumerate every config key the ENGINE READS — grep core_app/lib/app/config/**, app_theme.dart/app_tokens.dart, screen_variants.dart, feature flags, navigation/screens registry, currency, environment; (ii) enumerate what EACH client config SETS (core_app/assets/client_config.json, apps/halal_boyz/assets/client_config.json, any other); (iii) per-client matrix of UNSET keys with (default, impact, severity), ranked by visual impact (the confetti/input/chip class).
C10 LAUNCH-STATE HAZARDS: scan every config VALUE for placeholder patterns (`REPLACE_ME|changeme|<your|TODO|pk_test|sk_test`) with JSON paths. For every security/behavior-critical key (admin PINs, payment keys, API keys, env mode, demo toggles, role allowlists): find the guard defining empty/invalid behavior and PROVE fail-closed — or report its absence. Explicitly verify: can DEMO_MODE be enabled in a release artifact by mistake? can an empty admin PIN open admin? (receipts: paths + tests).
C11 GENERATED-VS-SOURCE DRIFT: run the generator's schema-identity + validation tests (receipts). Dry-run generation to a TEMP directory (never over the repo); diff emitted shell files vs apps/halal_boyz/** and emitted config vs the shipped configs; per-file drift table (template-expected vs shipped-actual).
Deliver tool_audit/aud2/aud2_report.md per A6. Territory = tool_audit/aud2/** ONLY; generator dry-runs go to a TEMP dir (never over the repo, never over the shipped configs). Commit LOCALLY on cline/task-2 (W6); no merge/ledger/push. Do not fix anything.
```

## AUD-3 — COVERAGE & CAPABILITY (classes 7, 8, 9)

```
You are the AUDITOR (read-only) for AUD-3: coverage/capability classes 7,8,9.
Worktree: <repo>-cline-3 (branch cline/task-3). Read <repo>\ANOMALY_CLASS_PLAYBOOK.md + AUDIT_FLEET_13CLASSES.md §WORKTREE EXECUTION (W1-W7). Rules A1-A6 bind.
0. SYNC FIRST (W2): git -C <repo>-cline-3 merge main; cd <repo>-cline-3; flutter pub get; blocker gate green BEFORE the first sweep command. Red => STOP + report.
C8 SURFACE × WAVE MATRIX (mechanical, repeatable): script over core_app/lib/features/**/presentation/** (excluding *_provider.dart) + UI-bearing files in packages/core_ui/lib/src/** and core_app/lib/app/**. For each: grep the spec corpus (WHITE_LABEL_*.md) + ledger for its path; record the owning batch (or NONE). Output the full matrix with file sizes + line counts; flag every unassigned surface. This must supersede the one-off coherence table with a committed SCRIPT at tool_audit/aud3/surface_matrix.ps1 (re-runnable on demand).
C7 CAPABILITY INVENTORY: for each user-facing capability the code supports (config keys, flags, services — locale choice, theme mode, currency display, notifications, payments, loyalty, referrals, waitlist, tour, delivery tracking, promo codes): determine whether a UI control/screen exposes it to the END USER. Output capability × (code-supported? UI-reachable?) with receipts (the widget/screen grep proving presence or absence — the language-toggle class).
C9 DUPLICATION DENSITY: per presentation file, count hand-rolled UI primitives (Card(, ListTile(, showDialog(, showModalBottomSheet(, CircularProgressIndicator(, raw TextField(, decorated Container() via the committed script; diff against the library class inventory (parsed from the core_ui barrel); output a ranked MISSING-COMPONENT candidate list (frequency × distinct screens × lines) naming the screens that would consume each — the W-1..W-6 family, re-derived mechanically.
Deliver tool_audit/aud3/aud3_report.md per A6 + the reusable scripts. Territory = tool_audit/aud3/** ONLY. Commit LOCALLY on cline/task-3 (W6); no merge/ledger/push. Do not fix anything.
```

## AUD-4 — PREMISES & PROCESS (classes 4, 5, 12)

```
You are the AUDITOR (read-only) for AUD-4: premises/process classes 4,5,12.
Worktree: <repo>-cline-4 (branch cline/task-4). Read <repo>\ANOMALY_CLASS_PLAYBOOK.md + AUDIT_FLEET_13CLASSES.md §WORKTREE EXECUTION (W1-W7). Rules A1-A6 bind.
0. SYNC FIRST (W2): git -C <repo>-cline-4 merge main; cd <repo>-cline-4; flutter pub get; blocker gate green BEFORE the first sweep command. Red => STOP + report.
C4 PREMISE VERIFICATION: extract every file:line-style claim from the ACTIVE specs (WHITE_LABEL_p1*.md, WHITE_LABEL_p2*.md, AUDIT_*.md, RESEARCH_*.md) — "X lives at path:line", "Y reads Z", "N tests exist", "the gate is at…". Verify each against code AT HEAD. Output claim → verified / stale / wrong (with the actual current line). This protects every future dispatch (the p17 consent-gate lesson).
C5 DEFERRAL LEDGER: extract every deferral phrase (`candidate pNN|later wave|deferred to|future batch|for now|TBD`) from the spec corpus + FIX_VERIFICATION.md + both audit docs; map each to an EXISTING owning spec. Output deferral → owner / ORPHAN. Confirm the corrected queue (p16..p26) leaves zero orphans; report any new orphan created since.
C12 HYGIENE & PROCESS: inventory the 212-file untracked litter (grouped by dir + size); list worktrees + branch tips vs main; prove no worktree holds commits main lacks; detect generated/artifact files committed by mistake (build/, coverage/, *.log, *.g.dart outside the l10n generator); propose (DO NOT implement) the pre-commit-guard list that would have prevented: litter accumulation, cross-window WIP blocking a merge, and the coordinator's `git add -A` sweep.
Deliver tool_audit/aud4/aud4_report.md per A6. Territory = tool_audit/aud4/** ONLY. Git commands allowed: READS ONLY (`status`, `log`, `worktree list`, `rev-parse`, `diff`). Commit LOCALLY on cline/task-4 (W6); no merge/ledger/push. Do not fix anything.
```

## After the audits — the fix flow (coordinator)

1. **Triage:** every finding gets FIX / SPEC / ACCEPT / FALSE-POSITIVE; FIX+SPEC items are grouped into fix batches by **TERRITORY** (never by class) so each batch owns disjoint files.
2. **Fix batches:** one spec each (red→green per fix, UI-fleet gates: analyze ×3, format 0, suites 0-skip, coverage floors, greps 0, forbidden paths) — expected shapes: `FIX_aud1_code`, `FIX_aud2_config`, `FIX_aud4_process`; SPEC items become the already-planned p21..p26.
3. **Verification:** the same 4 audits re-run; every finding must flip to **CLOSED-WITH-RECEIPT**; any detector still firing = not done (the numeric criterion, not an opinion).
4. **Then p16 onwards** with the corrected queue (p16 · p17 · p18 · p19 · p20 · p21 · p22 · p23 · p24 · p25 · p26) — now carrying **AUD-verified premises** instead of assumptions.

## FULL SEQUENCE AFTER THE DATA (worktree-map, 2-concurrent max per METHOD §8)

**Stage 0 — prep (coordinator, main):** `git push` main; fast-forward all five worktrees to main; `flutter pub get` per worktree. Confirm `git worktree list` shows each on a main descendant.

**Stage 1 — audit wave A (parallel 2):** **AUD-1 → cline-1** ∥ **AUD-2 → cline-2** (disjoint: code-vs-itself vs client/config). Heavy coverage runs staggered (W5).

**Stage 2 — audit wave B (parallel 2):** **AUD-3 → cline-3** ∥ **AUD-4 → cline-4** (disjoint: inventory vs documents/process).

**Stage 3 — triage + merge (coordinator, main only):** verify each branch is findings-only (A5/W3), merge all four into main, ledger note per audit, then produce the triage table: every finding → FIX / SPEC / ACCEPT / FALSE-POSITIVE.

**Stage 4 — fix batches (territory-grouped; 2 concurrent max):** FIX specs written from triage (expected: `FIX_aud1_code`, `FIX_aud2_config`, `FIX_aud4_process`; SPEC items fold into p21..p26). Each fix batch = red→green per fix, all fleet gates, merge-back per p13 §0.12 (barrel-union rule where applicable), post-merge battery on main.

**Stage 5 — verification (the numeric criterion):** re-run **all four audits**; every prior finding must flip to **CLOSED-WITH-RECEIPT**. Any detector still firing = the fixes are incomplete; loop Stage 4 for those only.

**Stage 6 — p16 onwards, ALL batches, in this concurrency map:**

| Wave | Parallel pair (disjoint territories) | Notes |
|---|---|---|
| 6.1 | **p16** (adoption 1: menu/dish/home/cart) — main | Gate for p17/p18/p20; owner visual review of the pack |
| 6.2 | **p17** (analytics: core-analytics + core_app features) ∥ **p19** (delivery: functions + core-delivery) | Truly disjoint file sets |
| 6.3 | **p20** (adoption 2: orders/profile/res/loyalty/waitlist/owner) ∥ **p23** (widgets: `packages/core_ui` only) | Library vs app — zero overlap |
| 6.4 | **p21** (adoption 3: checkout/auth/first-run/locations/tracking/compliance) ∥ **p24** (locale toggle: config + settings surface) | Watch the settings file overlap; serialize if it appears |
| 6.5 | **p22** (staff surfaces: `features/admin/**`) ∥ **p25** (generator completeness: `tool/` + config tests) | Disjoint |
| 6.6 | **p18** (Arabic hardening sweep — ALONE) | Its RTL fixes touch presentation files "as found"; it must not run beside any features wave |
| 6.7 | **p26** (audit harness: `tool_audit/` detectors as committed script + test) | Can pair with leftovers; final full battery + ledger closures |

**Close-out:** full battery on merged main (analyze ×3, format 0, all suites 0-skip, coverage floors, greps 0, forbidden paths 0) → ledger addenda for every batch → **fleet-complete declaration** with the tip hash, mirroring the UI-fleet freeze pattern.

---

## STAGE 1 CLOSE-OUT — coordinator verification log (main only)

**Tip after Stage 1: `bbbd290` = main = origin/main (pushed, exit 0).**

| Item | Verification (coordinator, re-run — not taken from the reports) | Result |
|---|---|---|
| AUD-1 A5 (W3) | `git diff --name-only e4f98cc..cline/task-1` filtered to non-`tool_audit/aud1/**` | **empty** (63 files, all in territory); base `e4f98cc` confirmed ancestor (`merge-base --is-ancestor` = 0) |
| AUD-2 A5 (W3) | `git diff --name-only e4f98cc..HEAD` filtered to non-`tool_audit/aud2/**` | **empty** (26 files tracked in main) |
| Merge | `git merge cline/task-1` → `bbbd290` | clean, no conflicts |
| Green tip | `git status --porcelain --untracked-files=no` | **empty** |

### Deviations found by the coordinator (process class 12 — recorded, not hidden)

1. **D-AUD2-W1 (AUD-2 ran in the main clone, not its assigned worktree).** AUD-2's three commits (`6a26103`, `ad9505a`, `1ba5fc8`) were authored in `<repo>` (branch `main`) instead of `<repo>-cline-2` (`cline/task-2`, still at `e4f98cc`). **Ratified, no re-do:** content is A5-clean and findings-only, so main gained nothing but `tool_audit/aud2/**`; the branch artifact is what W1 wanted, not the outcome. Standing correction for Stages 2/5: the sync ritual (W2) must also assert `git rev-parse --abbrev-ref HEAD` equals `cline/task-N` **before** the first sweep command.
2. **D-AUD1-STRAY (audit byproducts left untracked in the main tree).** AUD-1 executed part of its sweep from `<repo>`, leaving **63 untracked duplicates of `tool_audit/aud1/**`** in the main working tree. This is the p13 blocker shape: `git merge cline/task-1` refuses when untracked files would be overwritten. **Resolved with proof, not by force:** for all 63 paths, `git hash-object <worktree file>` vs `git rev-parse cline/task-1:<path>` → **HASH_MISMATCH=0** and set difference **EXTRAS=0**; the duplicates were then deleted and the merge proceeded. Receipts in this log (re-runnable: the two loops above).

### Resolved / disproved since the reports

- AUD-2's flagged stray `core_app/test/_aud1_*_probe_test.dart` files: **now 0 present** (`Get-ChildItem core_app\test -Filter '_aud*'` = empty; `git ls-files --others core_app/test` = empty) — the hazard AUD-2 reported is CLOSED, not merely re-raised.
- Main-tree litter census: 275 untracked → **212 after the dedupe**, all pre-existing PERF-2 (`tool_perf2/**` + root `perf2_*.log`), foreign to this fleet (class-12 item, owned by p26/AUD-4).

### Wave-A findings that may NOT be silently absorbed (A4 carry-forward)

| id | Sev | Disposition (proposal only) | Batch |
|---|---|---|---|
| AUD1-01 | **CRITICAL** — checkout idempotency key is session-scoped while the server dedupes by it (silent resolution to the first order; refund path unreachable) | FIX | `MONEY-4` |
| F-AUD2-01 | **CRITICAL** — `core_app` template app cannot reach `runApp()` (`.env` deleted CI-2 + `loadEnv: true` + non-optional `dotenv.load()`); **shells proven unaffected** | FIX | `boot-env-guard` |
| AUD1-02 | HIGH — 8/14 money-formatting parity rows diverge (`$-1.50` vs `-$1.50`, CAD/AUD→`$`, JPY decimals, AED/SAR labels) | FIX | `MONEY-5` |
| F-AUD2-14 | HIGH — shipped `apps/halal_boyz/backend/*.rules` stale vs templates (missing the t78 POD assignment gate, 137 lines) | FIX | `backend-bundle-refresh-and-CI-parity` |

Both CRITICALs are launch-relevant; they enter Stage 4 triage as first-priority FIX batches, and Stage 5 re-verification must show their detectors silent.

### Next

**Stage 2 — audit wave B (parallel 2, staggered heavy runs):** AUD-3 → `<repo>-cline-3` (classes 7/8/9) ∥ AUD-4 → `<repo>-cline-4` (classes 4/5/12). Both worktrees are at `e4f98cc`, so the W2 ritual (`merge main`) is mandatory and brings `bbbd290` (both wave-A findings) into the tree. Stage 3 triage/verification then merges cline-3 + cline-4 (AUD-2 needs no merge — already in main).

---

## STAGE 5 - RE-AUDIT (DELTA WAVE) - staged after Stage 4 completed at `2ec92c4`

**Purpose:** (a) confirm every CLOSED-WITH-RECEIPT row is genuinely closed, (b) detect NEW defects introduced by the 12 fix batches (regression class), (c) refresh the mechanical inventories (surfaces, capabilities, duplication, config matrix, hygiene) against the post-fix tree.
**Authority:** a Stage-5 finding that contradicts a closure is a REGRESSION and outranks any closure claim; it reopens the row.

**Current baselines at `2ec92c4` (the Stage-1 numbers in the prompts above are STALE - use these):**
format **696 / 0 changed** · analyze core **0** / core_ui **0** / core_app **0** · suites core **+329** / core_ui **+289** / core_app **+2002** / halal **+71**, 0 skip · server `npx tsc --noEmit` exit 0 and `npm test` **124 / 124** · core_ui barrel **43 exports** · register: **37 of 69 CLOSED-WITH-RECEIPT** + `REC-B2-1` closed.

**Assignment (W1):** AUD-1R -> `<repo>-worktree` · AUD-2R -> `cline-2` · AUD-3R -> `cline-3` · AUD-4R -> `cline-4`. Territory `tool_audit/audNR/**` only (receipts for the re-audit; do NOT overwrite the Stage-1 receipts). Rules A1-A6 + W1-W7 bind; **W2** now requires proving the sync with `git merge-base --is-ancestor 2ec92c4 HEAD` = 0; **W3b** no writes to `<repo>`; **R-V** receipts must be non-empty.

### AUD-1R (classes 1, 2, 3, 4, 13) - code vs itself, delta
1. **CLOSURE RE-PROOF:** for every class 1/2/3/13 row marked CLOSED (`AUD1-01`, `-02`, `-04`, `-05`, `-07`, `-08`, `-10`, `-17`, `F-W4-01`, `F-B8-01`, `REC-B2-1`), independently re-derive the property from the current code (money parity table across the formatters; retry matrix 9 rows; namespace probe vs the Flutter SDK; vacuous-test census; per-file lcov attribution; the generator money template's emitted strings). A property that does not re-derive reopens the row.
2. **NEW-DEFECT SWEEP:** re-run every Stage-1 detector on this tree and diff against the Stage-1 receipts committed under `tool_audit/aud1/receipts/` - report per detector: unchanged / improved / regressed.
3. Report: delta table + any NEW finding with an evidence path and a disposition proposal.

### AUD-2R (classes 6, 10, 11) - client/config, delta
1. Re-run the engine-vs-config key matrix (B9 set several halal keys - re-measure; `typography.*Size`, `spacing.*`, `features.*`, `navigation.{tabs,hiddenRoutes,routes}`, `currency.code`, `devAdminPin`, `stripePublishableKey` were SET-but-UNREAD AT STAGE 1: re-check).
2. Re-run the placeholder scan and the fail-closed proofs (the template boot path changed in B1 - re-prove `runApp` is reachable).
3. Re-run the generated-vs-shipped drift census (B8 refreshed `backend/*.rules` and B11 fixed the generator's money template - both must now be identical; prove it) and confirm the new `.gitignore` has not hidden a file that the generator expects to emit.

### AUD-3R (classes 7, 8, 9) - coverage/capability, delta
1. Re-run the three committed scripts (`surface_matrix.ps1`, `capability_inventory.ps1`, `handrolled_density.ps1`) - the adoption waves have not run, so expect the surface/capability numbers to be unchanged; a change means an unintended edit.
2. Re-measure the hand-rolled density against the current 43-export barrel (the `showModalBottomSheet` / `BrandSheet` gap is still open by design).
3. Report deltas only, plus any NEW unassigned surface created by the 12 batches.

### AUD-4R (classes 4, 5, 12) - premises/process, delta
1. Re-verify every file:line premise in the specs written AFTER Stage 1 (`FIX_b*.md`) against HEAD - the contract premises must still be true.
2. Re-run the deferral ledger: every deferral must name an existing owner; the p20 -> p22 correction must hold; report any NEW orphan.
3. Hygiene: untracked census (expect 0 litter + only wave receipts), worktree/branch census (no worktree may hold unmerged commits), tracked-artifact scan, and whether the new `tool_guard` rules would have fired on anything committed during Stage 4.
4. Report: any claim in the Stage-4 reports that no longer holds at `2ec92c4`.

**Stage-5 acceptance:** all four reports delivered; every row either re-proved CLOSED or reopened with an owner; zero unexplained regressions. Then Stage 6: `p16 -> p17 || p19 -> p20 || p23 -> p21 || p24 -> p22 || p25 -> p18 -> p26`.

---

### STAGE 5 - SINGLE-WINDOW VARIANT (all four re-audits, one session)

**When to prefer it:** one operator, and no appetite for cross-window git contention. It removes the W5 stagger hazard, the cross-window WIP blockers and three merges - at the cost of wall-clock time (the four audits run serially).
**Assignment:** `<repo>-worktree` (branch `cline/task-1`) - verified clean, with `commits_main_lacks = 0` for all five worktrees at `2ec92c4`/`a18c670`.
**Safety:** the four audits write ONLY `tool_audit/aud1r..aud4r/**`, so they cannot collide with each other or with product code, and this window is the only one mutating git.
**Resumability:** one commit per audit (four commits). If the session dies, resume at the first missing `tool_audit/audNr/**` directory.
**Gates:** run the FULL blocker gate ONCE at the start and ONCE at the end (not four times). Per audit, run only what that audit needs (coverage for AUD-1R, the three scripts for AUD-3R, and so on).
**Extra deliverable:** `tool_audit/stage5/INDEX.md` - one table across all four audits (detector | Stage-1 value | Stage-5 value | verdict), so the coordinator can judge the wave from a single page.

```text
You are the SINGLE AUDITOR for STAGE 5 (all four delta re-audits) in ONE session, read-only.
Worktree <repo>-worktree (branch cline/task-1). Read <repo>\ANOMALY_CLASS_PLAYBOOK.md,
<repo>\AUDIT_FLEET_13CLASSES.md (all four Stage-1 prompts + the STAGE 5 block + this single-window
variant) and <repo>\AUDIT_TRIAGE_STAGE3.md sections 8-18. Rules A1-A6 + W1-W7 bind, with:
W2 proven by `git merge-base --is-ancestor 2ec92c4 HEAD` = 0 · W3b never write to <repo> ·
W6 one commit per audit on cline/task-1 · R-V receipts non-empty · A1 = no fixes, findings only.

0. SYNC + FULL GATE ONCE (fail-closed):
   assert branch == cline/task-1; git merge main; flutter pub get
   format root 696/0 · analyze core 0 / core_ui 0 / core_app 0 · suites core +329 / core_ui +289 /
   core_app +2002 / halal +71 (0 skip) · in core_app/functions: npx tsc --noEmit 0 and npm test 124/124.
   Any red => STOP and report; do not proceed into the audits.
   Also record `git worktree list` plus per-worktree `commits_main_lacks` as the hygiene baseline.

1. AUD-1R (classes 1,2,3,4,13) -> tool_audit/aud1r/**: run the Stage-1 AUD-1 prompt as a DELTA.
   a) CLOSURE RE-PROOF for AUD1-01..17, F-W4-01, F-B8-01, REC-B2-1: independently re-derive each property
      from the CURRENT code (money parity across the formatters, retry matrix 9 rows, SDK namespace probe,
      vacuous-test census, per-file lcov attribution, generator money template strings, the server
      classifyIdempotentReplay wiring). A property that does not re-derive REOPENS the row.
   b) NEW-DEFECT SWEEP: re-run every Stage-1 detector and diff against tool_audit/aud1/receipts/*.
   c) Run tool_fix/b7/coverage_floor.ps1 and report any package/file that dropped.
   Deliver tool_audit/aud1r/aud1r_report.md (delta table + new findings + UNVERIFIED). COMMIT (audit 1 of 4).

2. AUD-2R (classes 6,10,11) -> tool_audit/aud2r/**: engine-vs-config matrix RE-MEASURED (B9 set halal
   components.input / chip.radius / background / confetti; re-verify the SET-but-UNREAD set too);
   fail-closed re-proofs (template runApp reachability post-B1, placeholders, empty security keys,
   DEMO_MODE); generated-vs-shipped drift RE-RUN (B8 rules refresh + B11 generator money template must
   both be clean now); and prove the new .gitignore (global *.log / *.info) has not silently untracked
   anything the repo needs.
   Deliver tool_audit/aud2r/aud2r_report.md. COMMIT (audit 2 of 4).

3. AUD-3R (classes 7,8,9) -> tool_audit/aud3r/**: re-run the three committed scripts
   (tool_audit/aud3/surface_matrix.ps1, capability_inventory.ps1, handrolled_density.ps1) against the
   current tree. Expectation: no adoption wave has run, so the numbers stay UNCHANGED - any change is a
   finding (an unintended edit during Stage 4). Flag NEW unassigned surfaces; re-check the 6 CODE-ONLY
   capabilities.
   Deliver tool_audit/aud3r/aud3r_report.md. COMMIT (audit 3 of 4).

4. AUD-4R (classes 4,5,12) -> tool_audit/aud4r/**: re-verify every file:line premise in the post-Stage-1
   specs (FIX_b1..b12, FIX_b3b) against HEAD; re-run the deferral ledger (p20 -> p22 must hold, no new
   orphans); hygiene census (untracked, worktree/branch, tracked artifacts, and whether tool_guard would
   have fired on anything Stage 4 committed); and list any Stage-4 report claim that no longer holds at
   the tip.
   Deliver tool_audit/aud4r/aud4r_report.md. COMMIT (audit 4 of 4).

5. WRITE tool_audit/stage5/INDEX.md: one table - detector | Stage-1 value | Stage-5 value | verdict
   (CLOSED-RE-PROVED / unchanged / improved / REGRESSED) - plus a short "rows reopened" list. COMMIT.

6. FINAL GATE on the last tip (same commands as step 0). Report the four commit hashes, the per-audit
   verdict counts, the reopened rows, and `git status --porcelain -uall` (expect only the pre-existing
   foreign tool_perf2/p8_w3_*.log files, which the new .gitignore now hides).

Do NOT fix anything. Do NOT merge. Do NOT push. Do NOT touch FIX_VERIFICATION.md, product code, specs,
or any file outside tool_audit/**.
```
