# AUDIT TRIAGE REGISTER â€” Stage 3 (coordinator, main only)

**Purpose:** the single triage authority for the 13-class audit fleet (`AUDIT_FLEET_13CLASSES.md`). Every finding gets exactly one disposition (A3: FIX Â· SPEC Â· ACCEPT Â· FALSE-POSITIVE) and exactly one owner batch. Audit reports are **evidence and are never rewritten**; this register is the closure record.

## 0. Inputs & verification (coordinator, re-run â€” not taken from the reports)

| Audit | Branch / tip | Territory files | A5: paths outside territory | Where it lives in main |
|---|---|---|---|---|
| AUD-1 (classes 1,2,3,13) | `cline/task-1` `c82430d` | 63 | **empty** âœ… | merged `bbbd290` |
| AUD-2 (6,10,11) | **main** `1ba5fc8` â€” W1 deviation `D-AUD2-W1` | 26 | **empty** âœ… | native (no merge needed) |
| AUD-3 (7,8,9) | `cline/task-3` `910f1b0` | 14 | **empty** âœ… | fast-forward |
| AUD-4 (4,5,12) | `cline/task-4` `0f7f1ae` | 27 | **empty** âœ… | merged `c1bd1e5` |

**Stage 3 tip:** `c1bd1e5` = `main` = `origin/main` (pushed). **Format gate exit 0** at tip. Auditor receipts: analyze Ã—4 green; suites core **+306** Â· core_ui **+281** Â· core_app **+1941**, 0 skip.

## 1. Coordinator remediation + ratifications (Stage 3 preamble)

| Item | Finding | Action / ruling | State |
|---|---|---|---|
| `AUD4-C12-01` | W2 branch-assert clause existed only in main's **working copy** (dispatch-vs-committed drift) | committed `ea59071`; dispatch text now provably matches HEAD | **CLOSED** |
| `AUD4-C12-04` + `AUD4-D1` | AUD-1 committed its scratch `.dart` files (W3 breach) â†’ **B-1 red for every worktree** | formatted (`6350d8c`), probe evidence retained for Stage 5; `FORMAT_EXIT=0` proven | **CLOSED** |
| `D-AUD1-STRAY` (Stage 1) | 63 untracked duplicates of aud1 in main | hash-identical proof (`HASH_MISMATCH=0`, `EXTRAS=0`) â†’ removed â†’ merge unblocked | **CLOSED** |
| `AUD4-D1` ruling | "continue past a red B-1" discretion | **RATIFIED as option (b)** â€” the gate is green by remediation; the *continue* discretion is **REVOKED**: a red gate caused by foreign committed files = STOP + report + coordinator remediates. Never a waiver. | ruling made |
| `AUD-3` B-1 deviation (same root cause) | sweep started with the foreign-scratch red | accepted as read-only, root cause since fixed | **CLOSED** |
| `AUD-1` W3 breach (scratch committed) | rule: scratch must be deleted before commit | ratified **with** remediation; standing rule refined: scratch retained as evidence must be **formatted** before commit; enforced by the `p26` pre-commit guard | ruling made |
| **COORDINATOR INCIDENT (self-reported)** | I ran the repair command and the merges **in parallel in one call** â†’ `error: could not write index` / `fatal: stash failed` on `cline/task-4`; index briefly untidy | detected immediately, state re-inspected, both merges redone **sequentially**; no force, no data loss, main never red, no bad state pushed | **CLOSED** â€” lesson: git mutations in one repo are strictly serialized (now a Stage 6 dispatch note) |

## 2. FINDING REGISTER â€” 69 rows, one disposition each

> **READ THIS FIRST: section 2 records each finding AS FOUND, not its live status.** Live status is in the wave judgments (§8–§16) and the status board (§12): **37 of 69 rows are CLOSED-WITH-RECEIPT**, and every remaining row has a named owner (`B10`/`B11`/`B12` or `p21`–`p26`). A row under "2.1 FIX — CRITICAL / HIGH" means it was triaged launch-relevant *when found*: both CRITICALs (`AUD1-01`, `F-AUD2-01`) and every money-path HIGH are already closed. **No launch-blocking defect is open.**


### 2.1 FIX â€” CRITICAL / HIGH (first priority, launch-relevant)

| id | Sev | Finding (short) | Owner batch |
|---|---|---|---|
| `AUD1-01` | **CRITICAL** | checkout idempotency key is session-scoped while the server dedupes orders by it â†’ silent resolution to the first order; compensation/refund path unreachable | `B2 MONEY-4` |
| `F-AUD2-01` | **CRITICAL** | `core_app` template cannot reach `runApp()` (`.env` deleted CI-2 + `loadEnv: true` + non-optional `dotenv.load()`); shells proven unaffected | `B1 boot-env-guard` |
| `AUD1-02` | HIGH | 3 money formatters, **8/14 parity rows diverge** (`$-1.50` vs `-$1.50`, CAD/AUDâ†’`$`, JPY decimals, AED/SAR labels, lowercase/unknown codes) | `B3 MONEY-5/6` |
| `F-AUD2-14` | HIGH | shipped `apps/halal_boyz/backend/*.rules` stale vs templates (missing the t78 POD assignment gate; 137 lines) â€” the deployable artifact is weaker than source | `B8 backend-bundle-refresh` |
| `F3-07` | HIGH | 10 of 81 surfaces **UNASSIGNED** (delivery tracker, splash, pin-drop map, delete-account, terms, onboarding, live-map picker, logs screen, bug reporter) | `p21` |
| `F3-09` | HIGH | spinner adoption gap: `CircularProgressIndicator` 76 sites / 33 screens | `p21` |
| `AUD4-C12-04` | HIGH (gate) | aud1 committed scratch broke B-1 fleet-wide | **CLOSED** (Â§1 remediation) |

### 2.2 FIX â€” MEDIUM / LOW (code, config, process)

| id(s) | Finding (short) | Owner batch |
|---|---|---|
| `AUD1-03`, `AUD1-17` | retry twins disagree on 5 codes (queue retries `failed-precondition`/`invalid-argument`) | `B5 QUEUE-3` |
| `AUD1-04` | two server tax implementations; `calculateTax`'s fail-closed guard is **unreachable** â†’ silent 5 % tax where the charge path fails closed | `B4 TAX-1` |
| `AUD1-06` | `'a@b'` passes client validation but `scrubPii` will not redact it (divergent rules) | `B6 PRIV-2` |
| `AUD1-07` | 2 truly vacuous tests (try/catch swallow) | `B7 TEST-1` |
| `AUD1-09` | live cross-package duplicate `GdprConsentDialog` (core_ui **and** labs); analyzer ambiguity hidden at 2 `hide` sites | `B7 ARCH-3` (pin the hide list) |
| `AUD1-10` | `softShadow`/`activeShadow` declared and never referenced | `B7 DEAD-1` |
| `AUD1-11`â€¦`AUD1-16` | stale doc claims: `app_colors.dart:10` byte-sync false since the halal rebrand; `labs.dart` names a non-duplicate + a `main.dart` hide that does not exist; 9 post-ARCH-2 "wiring in main.dart" comments; 2 comments citing non-existent test files; "banker's rounding" mislabel | `B11 DOC-1` |
| `F-AUD2-05` | template `firebase.projectId = REPLACE_ME_â€¦` wins the options merge once dotenv is fixed | `B1` |
| `F-AUD2-06` | Stripe release guard is a debug-only `assert`; the "fail fast in production" comment overclaims | `B1` (doc-fix) |
| `F-AUD2-07` | halal config leaves surfaced theme tokens **unset** (`components.input.*`, `chip.radius`, `shape.smallRadius`, `background.*`) â†’ Material-default surfaces the engine supports branding | `B9` (p16.5) |
| `F-AUD2-10` | `theme.confettiOverlay.colors` is set but byte-identical to the generic default â†’ "configured but not branded" | `B9` (p16.5) |
| `F-AUD2-15` | shipped `build.gradle.kts` carries a hand-mirrored signing gate + desugaring the generator does **not** emit â†’ a regeneration silently reverts them | `B8` (+ SPEC note) |
| `AUD4-C4-01`â€¦`-04` | 176/789 doc path claims BAD_REF (22.3 %); 22 hard-bad (16 missing files + 6 past-EOF, root cause = the ARCH-2 split: `main.dart` is now 27 lines); 78 leaf-ambiguous | `B11 DOC-CITES` |
| `AUD4-C5-01` | `WHITE_LABEL_p20_adoption2.md:43` deferred the staff rung to a never-written "candidate p21" | **FIXED in this commit** â†’ owner `p22_staff` |
| `AUD4-C5-03` | 18 deferral rows with no named owner (benign prose/echoes) | `B11` (annotate) |
| `AUD4-C12-02`, `-03`, `-05` | 212 untracked files (11.5 MB) + 215 tracked `*.log` + 3 tracked lcov `*.info`; `.gitignore` ignores nothing | `B10 HYGIENE` |

### 2.3 SPEC â€” needs a new batch contract

| id(s) | Finding (short) | Owner spec |
|---|---|---|
| `F3-01`, `F3-02`, `F3-04` | code-supported but user-unreachable: locale switcher (l10n hardened, 0 UI controls), theme mode (`toggle()` has 0 external callers), end-user notification settings (only merchant tone/opt-in text exists) | `p24_settings` |
| `F3-05` | `referrals` flag `true` + l10n keys, **zero** presentation hits | `p21` build or flag removal â†’ **decision D-2** |
| `F3-06` | guided tour built but unwired (self-documented at `tour_overlay.dart:8`) | `p21` wire or delete â†’ **decision D-3** |
| `F3-08` | ownership evidence is ledger-heavy (`LEDGER-main` 63 of 71 assigned) â€” spec tables alone would leave gaps | `p25` (registry discipline) |
| `F3-10`, `-11`, `-12`, `-15` | adoption gaps: `ListTile` 19 sites/13 screens, `Card` 15/10, raw `TextField` 12/4 (owner_dashboard 9), decorated `Container` 7/6 | `p21` |
| `F3-13` | **MISSING component**: `showModalBottomSheet` 4 sites/1 screen with **no** barrel counterpart (`BrandSheet` absent) â€” the only family with real frequency and no library equivalent | `p23_widgets` |
| `F3-14` | `owner_dashboard.dart` = 1159 lines / 31 primitive sites = largest **and** densest surface | `p22_staff` |
| `AUD1-05` | JS `Math.round(-2.5) = -2` vs Dart `(-2.5).round() = -3` â€” 1-cent divergence on negative halves | `B3` (rounding contract + parity test) |
| `AUD1-08` | no coverage floor anywhere (core 84.24 %, core_ui 92.76 %, core_app 86.87 %; 108 files <100 %) | `B7 COV-3` |
| `F-AUD2-09` | SET-but-UNREAD config surface (flags/source, tabs, hiddenRoutes, routes, store, typography sizes Ã—4, spacing Ã—3, stripePublishableKey, devAdminPin, currency.code) | `p25` |
| `F-AUD2-13` | no config-vs-config completeness/parity test (11 core-only keys vs 1 halal-only) | `p25` |

### 2.4 ACCEPT â€” deliberate / benign, documented

`AUD1-18` (shadowed refs) Â· `AUD1-22` (flutter_test config claim verified true) Â· `AUD1-23` ("does not throw" contract) Â· `F-AUD2-02` (documented placeholder credentials â€” every consumer fail-closed or dead) Â· `F-AUD2-08` (`animationStyle` absent = engine default `full` = baseline) Â· `F-AUD2-11` (branch fallback fail-closed `null`) Â· `F-AUD2-12` (empty Cloudinary preset fails closed) Â· `F-AUD2-16`/`-17`/`-18` (drift PASS, guards green, no secrets or `.env` anywhere) Â· `F3-03` (currency has no in-app control â†’ white-label by design, pending **decision D-4**).

### 2.5 FALSE-POSITIVE / PASS â€” disproved, recorded so they are never re-raised

`AUD1-19` (0 SDK collisions â€” 236 public names swept with `material.dart` in scope) Â· `AUD1-20` (scanner blind spots, 50 of 70) Â· `AUD1-21` (all 6 `DateFormat` sites pass an explicit locale) Â· `F-AUD2-03` (empty admin PIN **cannot** open admin â€” 3 fail-closed paths) Â· `F-AUD2-04` (`DEMO_MODE` **cannot** reach a release artifact) Â· `AUD4-C4-05` (live queue p16â€“p20: **0 stale path premises**) Â· `AUD4-C5-02` (p08â†’p09 = the model deferral pattern).

**Class-13 correction to the playbook:** AUD-3's C8Ã—C9 join **refutes** the playbook's "hand-rolled â‡’ unassigned" correlation (checkout is now owned yet 921 lines hand-rolled; owner_dashboard is unassigned *and* densest). The playbook's detector 9 keeps its value for **missing components**, not as an ownership proxy â€” recorded so the next audit does not inherit the wrong model.

## 3. Fix batches â€” territory-disjoint, parallel-safe map

| Batch | Findings | Territory (files) | May run âˆ¥ with |
|---|---|---|---|
| `B1 boot-env-guard` | F-AUD2-01, -05, -06 | `core_app/lib/main.dart`, `core_app/lib/app/app_bootstrap.dart`, `core_app/pubspec.yaml`, `core_app/assets/*.json`, `.env.example` | B9 |
| `B2 MONEY-4` | AUD1-01 | `core_app/lib/features/checkout/domain/checkout_service.dart`, `core_app/functions/src/index.ts` | **nothing** (money-critical, alone) |
| `B3 MONEY-5/6` | AUD1-02, -05, D-1 | `core_app/lib/app/config/currency_format.dart`, `packages/core/lib/**` money helpers + tests | B5, B9 |
| `B4 TAX-1` | AUD1-04 | `core_app/functions/src/**` tax, `packages/core/**` tax | B6, B7 |
| `B5 QUEUE-3` | AUD1-03, -17 | queue/retry helpers | B3, B7 |
| `B6 PRIV-2` | AUD1-06 | validation helpers + `scrubPii` | B4, B7 |
| `B7 TEST/DEAD/ARCH/DOC-1 + COV-3` | AUD1-07, -08, -09, -10, -11â€¦16 | `**/test/**`, comment-only edits (`app_colors.dart`, `labs.dart`, wiring comments) | B4, B5, B6 |
| `B8 backend-bundle-refresh` | F-AUD2-14, -15 | `apps/halal_boyz/backend/*.rules`, `core_app/tool/whitelabel.dart`, `android/app/build.gradle.kts` | B7 |
| `B9 halal theme tokens + confetti (p16.5)` | F-AUD2-07, -10 | `apps/halal_boyz/assets/client_config.json` **only** | B1, B3 |
| `B10 HYGIENE` | C12-02, -03, -05, D1 close, D-6 | `.gitignore`, `tool_perf2/**`, root litter, log policy | B11 |
| `B11 DOC-CITES + DOC-1` | C4-01â€¦04, C5-01, C5-03, AUD1-11â€¦16 | `AUDIT_*.md`, `WHITE_LABEL_*.md`, ledger annotations, inline comments | B10 |

**Gate set for every B-batch (identical to the UI fleet):** redâ†’green per fix (failing detector/test first, receipt) Â· analyze Ã—3 + `dart analyze` (core) exit 0 Â· format 0 Â· all suites 0-skip no-drop Â· coverage floors held (and COV-3 introduces them) Â· greps 0 Â· forbidden paths 0 Â· receipt dir `tool_fix/<batch>/` Â· paste-ready ledger block. **Sanctuary rule for B2/B3/B4:** money-path tests (idempotency, tax, rounding, parity) may never be weakened â€” only added to; every fix ships with the regression test that would have caught it.

## 4. Stage 4 â†’ 5 â†’ 6 order (â‰¤2 concurrent, **git strictly serialized**)

1. **S4.1:** `B1` âˆ¥ `B9` â†’ battery on merged main. *(B9 first-look visuals feed the owner's p16 review â€” decision D-7.)*
2. **S4.2:** `B2` **alone** (money) â†’ battery + money-path mutation gate.
3. **S4.3:** `B3` âˆ¥ `B5` â†’ then `B4` âˆ¥ `B6`.
4. **S4.4:** `B7` âˆ¥ `B8` â†’ then `B10` âˆ¥ `B11`.
5. **S5 verification (the numeric criterion):** re-run all four audits; **every row in Â§2 must flip to CLOSED-WITH-RECEIPT**; any detector still firing = loop S4 for that row only. AUD4-D1's ruling is re-checked here (B-1 must be green in all four worktrees).
6. **S6:** `p16` â†’ (`p17` âˆ¥ `p19`) â†’ (`p20` âˆ¥ `p23`) â†’ (`p21` âˆ¥ `p24`) â†’ (`p22` âˆ¥ `p25`) â†’ `p18` alone â†’ `p26`. Every dispatch carries the **W2 branch assert** + the serialized-git caution (my Stage 3 race is the receipt) + the AUD-verified premises from Â§2.


## 5. OWNER DECISIONS (shape Stage 4/6)

| # | Question | Coordinator recommendation |
|---|---|---|
| **D-1** | Money-formatter unification direction: adopt CLDR `-$1.50` (**standards-conformant** â€” AUD1-02 + the Unicode CLDR negative sub-pattern) or keep legacy `$-1.50`? | adopt CLDR; it also settles p16's L13 money-parity law with an external standard instead of a preference |
| **D-2** | `referrals` (flag `true`, l10n keys, zero surface): build a referral surface or remove the flag? | remove the flag until a surface exists (a flag that advertises nothing is a false promise) |
| **D-3** | Guided tour (built, unwired): wire it or delete it? | wire it in `p21` â€” it is customer-facing value already paid for |
| **D-4** | Currency in-app control (F3-03): by design as a white-label value? | by design; record the decision, no UI |
| **D-5** | Staff-screens rung owner: ratify `p22_staff` as the owner of the deferred kitchen/delivery/dead-letter dashboards + owner-dashboard split? | ratify â€” already applied to `WHITE_LABEL_p20_adoption2.md:43` in this commit |
| **D-6** | 212 untracked files (11.5 MB) + 215 tracked `*.log` + 3 tracked `*.info`: archive or delete? | archive `tool_perf2/**` evidence to a receipts branch, delete root `perf2_*.log`, keep audit receipts; add the `.gitignore` + pre-commit guard list from AUD4-C12-05 |
| **D-7** | Run `B9` (halal theme tokens + brand confetti / p16.5) **before** or after `p16`? | **before** â€” the owner's first-look p16 visual review then judges the best available version |
| **D-8** | Halal Cloudinary upload preset is `""` (unsigned uploads fail closed) | keep as an operator RUNBOOK item (fail-closed today, no code risk) |

## 6. OWNER RATIFICATION (2026-09-24)

**Owner approved D-1â€¦D-8 exactly as recommended.** Accordingly: D-1 = adopt CLDR `-$1.50` (B3 target) Â· D-2 = remove the `referrals` flag (goes to `p21`) Â· D-3 = wire the guided tour in `p21` Â· D-4 = currency stays a config-only white-label value (recorded, no UI) Â· D-5 = `p22_staff` owns the staff rung Â· D-6 = archive `tool_perf2/**` evidence, delete root logs, add `.gitignore` + guards (B10) Â· **D-7 = `B9` runs before `p16`** (wave 1 order: `B9` âˆ¥ `B1`) Â· D-8 = Cloudinary preset stays a RUNBOOK item.

**Wave-1 contracts committed:** `FIX_b1_boot_env_guard.md` Â· `FIX_b9_halal_theme_tokens.md`.

## 8. STAGE 4 â€” WAVE 1 JUDGED (`B9` âˆ¥ `B1`)

**Merge:** `25d3f6e` = main (B9 `05b1761` + B1 `273a5cd`). Both branches: A5-clean (B9 = `apps/halal_boyz/{assets,test}` + `tool_fix/b9/**`; B1 = 2 `core_app/lib` files + 4 new/2 modified tests + `tool_fix/b1/**`; **zero** paths outside).

**Coordinator battery on the merged tip** (receipts `tool_fix/wave1/`): format **682 files / 0 changed** Â· `flutter analyze --fatal-infos` core_app **0** Â· halal **0** Â· `dart analyze` core **0** Â· core_ui **0** Â· suites core_ui **+281** Â· core **+306** Â· halal **+71** Â· core_app **+1951**, all passed, **0 skip markers**.

| Finding | Batch | Verdict | Evidence |
|---|---|---|---|
| `F-AUD2-01` **CRITICAL** | B1 | **CLOSED-WITH-RECEIPT** | red `tool_fix/b1/red_t1.txt` (`UncaughtZoneError: FileNotFoundError`) â†’ green `green_t1.txt`; `loadEnvLayer()` optional load + explicit `EnvFileMissing`, no fabrication; `main_test` anchor follows the moved call site |
| `F-AUD2-05` | B1 | **CLOSED-WITH-RECEIPT** | red `red_t2.txt` (`merged.projectId == REPLACE_ME_â€¦`, silent bogus init) â†’ green; placeholder excluded from the merge + STEP-13 FATAL **names `firebase.projectId`** |
| `F-AUD2-06` | B1 | **CLOSED-WITH-RECEIPT** | red `red_t4.txt` (comment overclaim) â†’ corrected to DEBUG-ONLY truth; choice recorded (not promoted to a release check â€” that would change behaviour AUD-2 ACCEPTed) |
| `F-AUD2-07` | B9 | **CLOSED-WITH-RECEIPT** | red `red_t1.txt` (`+1 -5`: unset `shape.smallRadius`, no `background` family) â†’ green `+6`; the four families set at the engine's own reader paths |
| `F-AUD2-10` | B9 | **CLOSED-WITH-RECEIPT** | red `red_t2.txt` (confetti byte-identical to the generic default) â†’ green `+3` brand quartet `900000/FFA500/FFC107/2E7D32` |

**Test-change audit (the only test edits in wave 1 â€” coordinator spot-check):** `core_app/test/app_bootstrap_states_test.dart` **re-pinned** an assertion that encoded the audited bug (`config id wins â€¦` with the placeholder value) â†’ now asserts the caller's safe default; identical expect/reason structure, and `boot_env_t2_test.dart` independently asserts the guard. `main_test.dart` = source-contract anchor for the moved STEP-06 call site. **Neither is a weakening**; both are sanctioned by the B1 spec Â§3/T-2 and were re-verified here.

**OWNER ACTION (open):** review `tool_fix/b9/visual_review/` (`INDEX.md`; before/after, 6 surfaces). Delta: **inputs, chips, confetti CHANGED** Â· cards, buttons, backdrop unchanged **with stated reasons** (`cardRadius`/`ctaRadius` were already branded; `background.color` equals the already-applied `colors.background`; `overlayAsset: null`). The appeal verdict is the owner's.

**Residuals carried forward (not closed by wave 1, never hidden):** `shape.smallRadius` moves pixels only on enabled compact buttons Â· template identity strings at config lines 6/10 are outside the diff (`p25`/hygiene) Â· `theme.animationStyle` still unset = ACCEPT (`F-AUD2-08`) Â· a present-but-empty `.env` still fails fast (contract covers absence) Â· template with an unresolved projectId boots without Firebase **by design** (FATAL names the key).

## 9. STAGE 4 â€” WAVE 2 JUDGED (`B2` MONEY-4, ran alone)

**Merge:** `1f38508` = main (fast-forward â€” `cline/task-1` carried B2 on top of B1). Branch A5-clean: `core_app/**` + `tool_fix/b2/**` only.

**Coordinator battery on the merged tip** (receipts `tool_fix/wave1/w2_*`): format **692 / 0 changed** Â· `flutter analyze --fatal-infos` core_app **0** Â· `dart analyze` core **0** Â· core_ui **0** Â· suites core_ui **+281** Â· core **+306** Â· core_app **+1958** (= 1951 + B2's **7** new) Â· halal **+71** â€” all passed; the only `~` occurrences are **test titles** (`~50 lines`, `~2.8T`), not skips.

| Finding | Verdict | Independent evidence (coordinator-verified) |
|---|---|---|
| `AUD1-01` **CRITICAL** | **CLOSED-WITH-RECEIPT** | `tool_fix/b2/red_t2_cartB_resolves_to_cartA.txt`: `Expected: 'ORD-B' / Actual: 'ORD-A'` (captured **before** the fix) Â· mutation gate **5/5 killed** with real assertion sites and `SHIPPED_CODE_RESTORED=yes`, SHA-256 identical before/after (`1592D0F7â€¦DC3`) Â· money sanctuary: the money-test dirs show **only the NEW test file** in `git diff` â€” no existing money test modified Â· the mechanism and its activation are proven **separately** (`green_commit1_interim_state.txt`) |

### Territory deviation â€” RATIFIED (with a standing rule)

The spec's Â§2 listed `checkout_service.dart` only, but the fix also changed **`checkout_screen.dart` (+4 lines: comment + `cart`/`userId` arguments)** â€” unavoidable once the signature changed, minimal, isolated and documented.
**Ruling: RATIFIED as a documented extension. Standing rule:** when a batch changes a function signature, Â§2 must enumerate the call sites; an unlisted call site means **STOP and report**, never a silent extension.

### Spec premise corrected (my own error, class 13)

My B2 Â§1 row claimed `core_app/test/wiring/phase7_regression_test.dart`'s *"L4 â€“ Checkout Idempotency Token"* guarded this defect. **False** â€” that group asserts the **order-id token helpers** (`generateToken`/`generateSessionOrderId`), runs green (+13) and **would not have caught `AUD1-01`**. The row is struck through with the correction + receipt (`FIX_b2_money_idempotency.md` Â§1). **Lesson:** a "guard exists" claim must name the *assertion it makes*, not the test's title.

### Carried forward (new, from B2's findings)

| Item | Disposition |
|---|---|
| `REC-B2-1` â€” server dedupe (`index.ts:1100-1108`) returns the existing order id **without content comparison** | new batch **`B12 functions-dedupe-content-guard`** (Stage-4 tail; **serialized with `B4`** â€” both edit `functions/src`) |
| `REC-B2-2` â€” the no-arg `getOrCreateSessionId()` stays (frozen suite pins its session bookkeeping) | `p26` hygiene (make private + documented re-pin) |
| `R-B2-1` â€” a caller that mints without a cart keeps legacy semantics | recorded in `tool_fix/b2/b2_report.md`; covered by `B12`/`p26` |

### Wave-3 assignment adjustment (territory-derived)

`AUD1-05` (JS `Math.round(-2.5) = -2` vs Dart `(-2.5).round() = -3`) is **tax rounding across nodeâ†”dart** â€” it moves from `B3` to **`B4 TAX-1`** so `B3` stays purely client-side (`apps`-free) and the two never touch `functions/src` in the same window.

## 11. STAGE 4 â€” WAVE 3 JUDGED (`B3` âˆ¥ `B5`) + the regression the battery caught

**Merge:** `2a90cb6` = main (B3 `fbc255c` + B5 `0f05202`). Both branches A5-clean (B3 = `core_app/**` + `packages/core_ui/**` + `tool_fix/b3/**`; B5 = exactly 2 lib files + 2 new tests + `tool_fix/b5/**`).

**Coordinator battery on the merged tip** (receipts `tool_fix/wave3/`): format **0 changed** Â· `flutter analyze --fatal-infos` core_app **0** Â· `dart analyze` core **0** / core_ui **0** Â· suites core_ui **+289** Â· core **+317** Â· core_app **+1989** â€” **but `apps/halal_boyz` = `+70 -1` (RED).**

### The regression (found by the coordinator battery, not by either batch's own gates)

`apps/halal_boyz/test/price_cents_guard_test.dart:38` asserts `Expected: '$-5.00'` while the unified formatter now renders `'-$5.00'` (owner decision **D-1**). The test was authored by **B9/p16.5** while the legacy formatter still composed symbol-first â€” i.e. it **pins the audited defect** (`AUD1-02`). **Root cause of the miss:** neither B3's nor B5's spec required the **halal shell suite**; both ran core/core_ui/core_app only.

**Actions taken:** new batch **`B3b`** (halal money re-pin, one-file diff, assertion count provable, `FIX_b3b_halal_money_repin.md`) â€” dispatched next; and the standing rule is added: **every money-touching batch's gate set now includes `apps/halal_boyz`** (already written into `FIX_b4_tax_rounding.md` Â§5).

| Finding | Verdict | Independent evidence (coordinator-verified) |
|---|---|---|
| `AUD1-02` | **CLOSED-WITH-RECEIPT** (app/core/core_ui scope) | 3 formatters â†’ 1 source of truth; 14-row matrix; the two re-pinned assertions in `currency_format_test.dart` are justified (unknown-code â†’ `XYZ `; negatives â†’ CLDR) with assertions **added**, not removed â€” re-verified by reading both file versions; B3's report row-4 cell was corrected after my catch (base `moneyCents` already rendered `-$1.50`) |
| `AUD1-03` | **CLOSED-WITH-RECEIPT** | `IsarSyncQueue.isPermanentFailure` now delegates to `NetworkRetry.isRetryable`; TWIN-2 matrix **9/9 AGREE** (was 5 DIVERGE) with a per-code gRPC rationale table; existing queue tests byte-unchanged |
| `AUD1-17` | **CLOSED-WITH-RECEIPT** | the two ladders stay distinct **and are pinned by test** (`NetworkRetry` 4 attempts 1s/2s/4s vs `IsarSyncQueue` 6 attempts, 2Ã— at equal depth, DLQ at attempt 6) via the `IsarSyncQueue.delay` seam |

**Spec errors of mine, recorded:** (a) B3's Â§3 T-3 ("every positive amount byte-identical") **contradicted** T-2 (7 positive rows had to change) â€” the executor narrowed it correctly and documented it; (b) I omitted `apps/halal_boyz` from B3/B5's gate set, which is exactly how the halal red escaped. Both are fixed in the contracts, not just in prose.

**Process deviation:** B3 completed its work but **did not commit** (DoD step 7) until instructed; the coordinator verified the content via file reads before authorising the commit. Standing note: a batch is not DONE until its commits exist on the branch.

## 12. Status board

| Stage | State |
|---|---|
| Stage 0 (worktrees synced) | âœ… |
| Stage 1 (AUD-1 âˆ¥ AUD-2) | âœ… judged, merged, ledgered (`bbbd290`, `ea8edf3`) |
| Stage 2 (AUD-3 âˆ¥ AUD-4) | âœ… judged, merged (`c1bd1e5`) |
| **Stage 3 (register)** | âœ… complete (`a7a74f5`) |
| **Stage 4 (B1â€¦B12 + B3b)** | ðŸŸ¡ waves 1â€“7 merged & judged; **37 of 69 (section 17) findings CLOSED** + 1 new (`F-B8-01`, owner `B11`); remaining: `B10 âˆ¥ B11`, `B12` |
| Stage 5 (re-audit â†’ CLOSED-WITH-RECEIPT) | â³ after all B-batches |
| Stage 6 (p16 â†’ p26) | â³ after Stage 5 |

## 13. STAGE 4 â€” WAVE 4 JUDGED (`B3b` âˆ¥ `B6`) + a latent flake found by the battery

**Merge:** `2f6d90d` = main (B3b `77f62f3` + B6 `2f004b7`). A5 verified for both: B3b = **one test file** + receipts (assertion count 13 â†’ 13, no deletion, negatives re-pinned to the CLDR form per `AUD1-02`+`D-1`, unknown code to the `CODE ` fail-closed form); B6 = `packages/core/lib/src/validation/email_rule.dart` (new) + `core.dart` (additive export) + `pii_scrubber.dart` (permissive pattern) + the **two validators only** in `login_screen.dart`/`signup_screen.dart`.

**Coordinator battery on the merged tip** (receipts `tool_fix/wave4/`): format **697 files / 0 changed** Â· `flutter analyze --fatal-infos` core_app **0** Â· core_ui **+289** Â· core **+326** Â· **halal +71 GREEN** (`B3b` closed the wave-3 regression) Â· `core_app` **+1988 -1 â†’ investigated**.

### `F-W4-01` â€” NEW FINDING (class 12/2: machine-global shared state â†’ nondeterministic failure)

The red was **not** a `B6` regression. `core_app/test/app_bootstrap_states_test.dart:230` asserts `ClientConfigLoadFailed` is **absent** from a log it reads via `File('${Directory.systemTemp.path}/app_logs.txt')` â€” a **machine-global, ever-appending** file shared by every test file (the harness says so at `boot_env_harness.dart:8`). The marker is written legitimately by `app_bootstrap.dart:549` when `AppConfig.loadFailed` (`client_config_schema_test.dart:307,:320` force that state). Proof of nondeterminism **on identical code**: full suite `+1988 -1` â†’ isolated run **fail** â†’ isolated run **pass** â†’ full suite **+1989 pass** after deleting `%TEMP%\app_logs*.txt`; and the rotated generation `%TEMP%\app_logs.1.txt` (1,049,410 B) holds **8** marker occurrences.

**Verdict:** B3b + B6 **CLOSED-WITH-RECEIPT**; the flake is a **new finding with owner `B7`** (contract `FIX_b7_tests_hygiene.md` T-1), carrying a new fleet law â€” **the determinism law (Â§0.7 of B7): no test may depend on state that survives a run**, and a flake fix is proven by **repeated runs**, not one green run.

| Finding | Verdict |
|---|---|
| `AUD1-02` (halal scope) | **CLOSED** â€” the shell suite is green again; the re-pin is justified (it pinned the retired legacy form) |
| `AUD1-06` | **CLOSED** â€” one rule (`emailLikePattern` âŠ‡ `strictEmailPattern`), both validators delegate, invariant test green, scrubber tests byte-unchanged |
| `F-W4-01` | **NEW â†’ `B7`** (above) |
| Wave-4 spec note | B6's own battery ran only `core_app/test/features/auth` (+ 2 named files) â€” **not** the full `core_app` suite. Standing rule reinforced: a batch's gate set is the **full** suite of every touched package, and the coordinator battery re-runs it regardless. |

**Standing gates added in waves 4â€“6:** (i) `apps/halal_boyz` is part of every money-touching batch's gate set; (ii) a batch is not DONE until its commits exist on its branch; (iii) any test reading `Directory.systemTemp` is on the determinism watch-list; (iv) **every batch's gate set is the FULL suite of every package it touches** â€” a subset run is not a gate (the wave-4 lesson).

## 14. Worktree / branch assignment for the remaining Stage-4 batches

Verified `git worktree list` + per-worktree clean/`commits_main_lacks` at `15714a4`: **all five worktrees clean, none holds unmerged commits.**

| Batch | Worktree | Branch | Runs |
|---|---|---|---|
| `B4` tax (money) | `<repo>-cline-5` | `cline/task-5` | **alone** |
| `B7` tests/hygiene/coverage/flake | `<repo>-cline-3` | `cline/task-3` | âˆ¥ `B8` (corrected from `cline-5`, which `B4` holds) |
| `B8` backend bundle | `<repo>-cline-4` | `cline/task-4` | âˆ¥ `B7` |
| `B10` hygiene | `<repo>-worktree` | `cline/task-1` | âˆ¥ `B11` |
| `B11` doc-cites | `<repo>-cline-2` | `cline/task-2` | âˆ¥ `B10` |
| `B12` server dedupe | `<repo>-cline-5` | `cline/task-5` | **alone** (money; reuses the B4 worktree after B4 merges) |

Each executorâ€™s step 1 asserts its own branch name (`D-AUD2-W1`) and runs `git merge main` first, so a worktree reused by a later batch is re-synced before any edit.

## 15. STAGE 4 â€” WAVE 5 JUDGED (`B4` TAX-1, alone)

**Merge:** `b7f02c5` = main (fast-forward; 3 commits: code `7987791`, report `de44d45`, battery addendum `b7f02c5`). Territory = **exactly** `core_app/functions/src/{payment.ts,index.ts}` (modified) + 2 **new** tests (`core_app/functions/test/tax_fail_closed.test.js`, `packages/core/test/tax_display_authority_test.dart`) + `tool_fix/b4/**`.

### Coordinator-verified independently (not taken from the report)

| Check | My result |
|---|---|
| `Math.round(subtotalCents` anywhere in `functions/src` | **0** â€” the second rounding rule is gone |
| Single rounding implementation | `export function roundHalfAwayFromZero` at `payment.ts:180`, used at `:248` â€” half **away from zero** (Dart `num.round()` semantics) |
| `calculateTax` delegation | the callable parses + delegates to the charge path's `extractClientTaxConfig`/`computeTaxCents` (`index.ts`), fail-closed guard now reachable in both paths |
| **Parity script re-run by me on merged main** | `node tool_fix/b4/tax_round_parity.js` â†’ **PASS, exit 0** (P1 positives byte-identical 34 rows Â· P2 NEW === Dart 42 rows Â· P3 divergence isolated to the 2 negative-half rows Â· P4 single impl) |
| Server lane | `npm test` â†’ **pass 90 / fail 0** |
| Sanctuary | no existing tax test modified (the one match is a **new** file); existing suites byte-unchanged |
| Merged battery | format **698 / 0 changed** Â· analyze core_app **0** Â· core_ui **+289** Â· core **+329** Â· halal **+71** Â· core_app **+1989**, **0 skip** |

| Finding | Verdict |
|---|---|
| `AUD1-04` (two tax impls; unreachable fail-closed guard â†’ silent 5 %) | **CLOSED-WITH-RECEIPT** â€” one implementation, guard reachable in both paths (`MoneyComputationError` â†’ `failed-precondition`), no hardcoded state table, no `?? 0.05` |
| `AUD1-05` (Node vs Dart rounding on negative halves) | **CLOSED-WITH-RECEIPT** â€” explicit half-away-from-zero; the 2 divergent rows corrected (`-3â†’-4`, `-2â†’-3`), **all positives byte-identical** |

**Notes carried forward:** (i) `dart fix --apply` was **not** applied â€” all 3 proposals fell outside B4's territory (correct, recorded in the report); (ii) the server lane remains *read-not-executed in CI* by design â€” the running proof is the parity script + `npm test`, both green; (iii) `B12` (server dedupe content-comparison) still holds `cline-5` after B4.

**Milestone:** with `AUD1-04` closed, **every launch-blocking code defect in the register is now closed** (both CRITICALs + all money-path rows). What remains in Stage 4 is tests/coverage (`B7`), the backend bundle (`B8`), hygiene (`B10`), doc-cites (`B11`), and the server dedupe (`B12`) â€” none of which block deploying the app.



## 16. STAGE 4 â€” WAVE 6 JUDGED (`B7` âˆ¥ `B8`)

**Merge:** `15fac44` = main (B7 `38af9e4` + B8 `eb5eb2f`). **A5 verified:** B7 = 5 commits, territory exactly `core_app/test/{app_bootstrap_states_test.dart,helpers/boot_env_harness.dart,core/kitchen/kitchen_offline_service_test.dart,core/theme/app_colors_test.dart}` + `packages/core_ui/lib/src/theme/app_colors.dart` (the two shadow declarations only â€” 22 lines removed, nothing else in that file) + `tool_fix/b7/**`. B8 = 7 commits, territory exactly the 2 rules files + `core_app/test/tool/whitelabel_backend_bundle_test.dart` (+188) + `core_app/tool/whitelabel.dart` (+216) + `tool_fix/b8/**`.

### Coordinator-verified independently

| Check | My result |
|---|---|
| **Rules strengthening** | 12 removed broad grants (`allow write: if isOwner();` â€¦) reappear **App-Check-gated** (`allow write: if isAppVerified() && isOwner();`) plus new shape-lock validators (`isValidWaitlistMeta`, `isValidMenuOverride`, `isValidTaxRatesShape`); `allow` lines 80 â†’ 92 â†’ **0 weakening** |
| **Regeneration parity (B8 T-4 census)** | `backend/firestore.rules` **byte-IDENTICAL (45,796 B both sides)**; `build.gradle.kts` IDENTICAL modulo EOL â†’ the signing-gate alignment worked; generator exit 255 is the documented temp-workspace `pub get` failure **after** all 177 files were written |
| **Test-count reconciliation** | `core_app` 1989 (f2eaa40) **âˆ’ 2** (B7's 2 shadow tests, tied to the token deletion) **+ 6** (B8's parity/gate tests) = **+1993** â€” measured, exact |
| Suites on merged main | core_ui **+289** Â· core **+329** Â· halal **+71** Â· **core_app +1993 run 1 and run 2** (two consecutive clean full runs) Â· analyze Ã—3 **0** Â· format **698/0** |
| B7's flagged flake (`boot_env_t1_test.dart` T-1b) | **did not recur in two full runs** on merged main; B8's own receipts independently show the same shared-temp class (`gate_suite_core_app_RED_shared_temp.txt`, `b7_shared_temp_pollution.txt`), which corroborates B7's root cause and raises confidence in the harness fix |

| Finding | Verdict |
|---|---|
| `AUD1-07` (2 vacuous tests) | **CLOSED** â€” rewritten to the real fail-closed contract (mutants red) |
| `AUD1-08` (no coverage floor) | **CLOSED** â€” re-runnable `coverage_floor.ps1` + pinned baseline (84.24/92.76/86.87 + new-file-100 % rule); breaks exit 1, restore exit 0 |
| `AUD1-10` (dead shadows) | **CLOSED** â€” dropped with their 2 tests; grep 0 |
| `F-W4-01` (shared-temp flake) | **CLOSED** â€” harness owns the `%TEMP%` generations; the states test now asserts process-local `AppConfig.loadFailed` |
| `F-AUD2-14` (stale shipped rules) | **CLOSED-WITH-RECEIPT** â€” refresh + parity test; deploy-day ruleset verification remains a RUNBOOK item |
| `F-AUD2-15` (gradle drift) | **CLOSED** â€” generator re-applies the RELEASE-1 gate fail-closed (idempotent, half-applied â‡’ throws) |
| **`F-B8-01` (NEW, MED-HIGH, fail-open)** | **found by B8, independently reproduced by me**: `core_app/tool/whitelabel.dart:2185-2200` still emits `expect(formatCurrencyCents(-500,'USD'), r'$-5.00')` and `r'$1.00'` for unknown codes, with the comment *"the canonical formatter renders the sign after the symbol"* â€” a regeneration would ship a **failing** client test and re-introduce the audited money form (`AUD1-02`/D-1). â†’ **owner `B11` T-5** (contract extended: expectation string + comment only; `money_text.dart` and every formatter forbidden) |

**Totals: 22 of 69 findings CLOSED (+1 new found and owned). Wave 6 of 8 judged.**

**Notes:** B8's pre-edit gate reading of `core_app +1972` is a **measurement anomaly** (the same tree measured 1989 before and 1995 after its own +6); the authority is the merged-tip battery above. Both batches' batteries were re-run by me on merged main, not taken from their reports.

---

## 17. STAGE 4 - WAVE 7 JUDGMENT (B11 DOC-CITES || B10 HYGIENE)

**Branches judged:** `cline/task-2` (B11, 6 commits) and `cline/task-1` (B10, 4 commits).
**Merges:** B11 = fast-forward `ab468c7 -> 26d6c0c` (base proven: `merge-base --is-ancestor ab468c7 cline/task-2` exit 0). B10 = real merge (base `267fdd5`, NOT `ab468c7` - see V1) -> merge commit `677a707`. Main tracked tree clean after both; the section-2 status note survived the merge intact (B10 never touched the register: `git diff 267fdd5..cline/task-1 -- AUDIT_TRIAGE_STAGE3.md` = EMPTY).

**Merged-main battery (`677a707`, receipts `tool_fix/wave7/m_*.txt`):**
format root **695 files / 0 changed** (exit 0) - analyze core **0** / core_ui **0** / core_app **0** - suites core **+329** / core_ui **+289** / halal **+71** / core_app **+1996**, 0 failures, 0 skips.
Test math reconciles exactly: 1993 (wave 6) + 3 (B11's new generator-template detector) = 1996.

**Wave-7 verification (coordinator, run independently of the executors' reports):**

---

## 21. STAGE 6 KICKOFF - S5-01 CLOSED (SPEC AUTHORED) + WAVE 1 DISPATCHED

### 21.1 S5-01 / `AUD4-C5-01` - closure receipt (spec-existence half)
The register's Stage-6 prerequisite was: author the backlog so no deferred rung is unowned. Done, and receipted by file existence rather than by prose:

| Claim | Receipt |
|---|---|
| `WHITE_LABEL_p22_staff.md` now EXISTS (was `Test-Path = False` in AUD-4R2 Task 2, the S5-01 receipt) | file authored this session; §1 carries P1 line counts measured at authoring |
| The deferral's target is real and specific (kitchen 413, delivery 479, manager 128, dead-letter 124, gateway 112, role_router 74 + role_gate 68, setup 862/216/116, admin_menu_manager 83, owner_dashboard 1107, admin_reservations_tab) | measured this session; `F3-14`'s "1159 lines" is audit-time - Stage-4 fixes reduced it to 1107, so the spec pins the re-measure at SYNC |
| Scope boundaries are named, not implied | p22 §2 forbids `admin/presentation/analytics/**` (p17) and `privacy_policy_screen.dart` + `compliance/**` (p21) - verified against the register, not assumed: `F3-07`'s "10 of 81 unassigned" list is **customer** surfaces and belongs to p21 |

**Row status change:** `S5-01` / `AUD4-C5-01` moves **OPEN → CLOSED-WITH-RECEIPT** (the file exists; the finding was "the deferral points at nothing"). Honest residual, stated in p22 §6: the *orphan* is fully closed only when UI-12 ships and the staff surfaces are built - that is now a Stage-6 execution item with a named spec and a wave, not an audit hole.

### 21.2 Specs authored in this cycle

| File | Closes / owns |
|---|---|
| `WHITE_LABEL_p22_staff.md` (UI-12) | S5-01 / `AUD4-C5-01`, `F3-14`, the M-7 family (all staff/admin surfaces) |
| `WHITE_LABEL_p23_widgets.md` (UI-11) | the coherence ladder's component hole W-1..W-6 (tip/timeline/charts/sheet/splash/table) and `F3-13`'s owner; supplies the components p17/p21/p22 adopt |
| `STAGE6_DISPATCH_W1.md` | the dispatch contract: two paste-ready prompts (lane mechanics, floor `4fba146`, R-X/R-Y receipt law), the territory-disjointness proof, the serialized merge protocol, and the W1-W5 wave plan |

**Still to author** (scope already fixed by `AUDIT_COHERENCE_LADDER.md` §6, so nothing is unowned): `p21_adoption3` (M-1 checkout/tip, M-2 splash/onboarding/tour, M-3 auth, M-4 locations, M-5 delivery tracker, M-6 compliance - also the register owner of `F3-07`) · `p24_locale_toggle` (F-5) · `p25_generator_completeness` (F-8 + rows `AUD2R-01`, `AUD2R-02`, `AUD2R-04`) · `p26_harness`.

### 21.3 Wave 1 dispatched (parallel, territory-disjoint)

| Lane | Spec | Worktree / branch | Territory | Verified ready |
|---|---|---|---|---|
| A | `p16_adoption1` (UI-6) | `<repo>-worktree` / `cline/task-1` | customer-core presentation + existing `core_ui` seams + `tool_uilib/p16/**` | clean, ff-able (tip `8c1ab55` is an ancestor of `main`) |
| B | `p19_delivery1` (UI-9) | `<repo>-cline-2` / `cline/task-2` | `packages/core/lib/src/delivery/**` + `functions/src/**` + config keys + generator mirror + `tool_uilib/p19/**` | clean, ff-able (tip `b6e52b9` is an ancestor of `main`) |

No path appears in both territories; `p20`/`p17`/`p18`/`p21`/`p22` are blocked by declared predecessors, `p23` is serialized behind `p16` by the exclusive-territory law (same `ui/**` directory), `p25` behind `p19` (same generator/config files). Dispatch floor: `git merge-base --is-ancestor 4fba146 HEAD` == 0. Merges are serialized; the second lane re-runs the full battery on its merged tip before the coordinator merges it.

### 21.4 Register accounting after this cycle
73 rows total: **37 CLOSED-WITH-RECEIPT** (36 + S5-01) · **36 open**, of which `AUD2R-01`, `AUD2R-02`, `AUD2R-04` are now wave-assigned (W2 lane `p25_generator_completeness`) and the remainder are Stage-6 spec waves with named owners. 0 CRITICAL, 0 money-path HIGH open (unchanged from §20).

| Check | Result |
|---|---|
| B11 forbidden paths | **0** (`money_text.dart`, core `money.dart`, `.gitignore`, `tool_audit/**`, `FIX_VERIFICATION.md` all untouched) |
| B11 "text-only" claim | **PROVEN**: 45 changed lines across 13 source/test files; exactly **1** non-comment line (a test group description string) |
| B11 T-5 generator fix | 4 expectation strings + 2 truthful comments in `whitelabel.dart:2407-2415`; emitted client test now matches D-1 |
| B11 x B10 overlap | **0** references to any path B10 deletes -> disjoint, order-independent merge |
| B10 deletion census | 269 = 208 `tool_perf2` logs + 20 audit scratch + ~41 root litter + 1 core_app log; all 4 audit reports intact |
| B10 "no product/test refs" | **CONFIRMED**: residual mentions live only in `.md` docs (V5) |
| B10 CI safety | `carnama_ci.yml` regenerates each `coverage/lcov.info` per package before aggregating -> untracking committed `.info` is harmless |
| B10 archive integrity | `perf2_litter.tar.gz` = exactly **212 entries** (200 `tool_perf2/` + 12 root) = the census; 11,505,001 raw bytes = AUD4-C12-02 byte-exact |

**Findings from verification (V1-V5), all B10-side, none blocking:**
| id | Sev | Finding | Ruling / owner |
|---|---|---|---|
| V1 | MED | **Stale-sync claim**: the report says base `ab468c7`; actual merge-base is `267fdd5` (`is-ancestor` exit 1) | ACCEPT (benign - doc region only) + rule W2b |
| V2 | MED | **Cross-worktree mutation**: T-2 moved main's 212 untracked litter out of `<repo>`, although B10's own summary says that worktree is not its to edit | **RATIFY the outcome** (it is exactly D-6, byte-exact, nothing lost) + rule W3b |
| V3 | LOW-MED | **Vacuous receipt**: `tool_fix/b10/t2_proof_main_clean_after.txt` is **0 bytes** | **FIXED** by coordinator: real receipt `tool_fix/wave7/t2_proof_main_clean_after_REAL.txt` |
| V4 | LOW | **Over-broad ignore rules**: global `*.log` / `*.info` with a single negation -> a future legit fixture of those types would be silently untracked | OPEN (LOW) - optional narrowing pass |
| V5 | LOW | Stale cites to removed/archived paths: `FIX_VERIFICATION.md:4562`, `HANDOVER_AUDIT.md:11` | CLOSED - doc sweep: `HANDOVER_AUDIT.md` is a 2.1 MB machine-generated log that is not part of the public snapshot, so the cite is recorded here, not followed; `FIX_VERIFICATION.md:4562` keeps its historical text |

**New standing rules added to the fleet law set:**
- **W2b** a sync claim is only valid with `git merge-base --is-ancestor <claimed-base> HEAD` = 0, quoted in the receipt.
- **W3b** main-worktree cleanup (moving/deleting files in `<repo>`) is coordinator-executed unless the batch dispatch explicitly waives it.
- **R-V** every proof receipt must be non-empty and reproducible; a 0-byte receipt is vacuous by definition.

**Rows closed by this wave:** B11 -> `AUD4-C4-01...04`, `AUD4-C5-03`, `AUD1-11...16`, `F-B8-01` (12 rows). B10 -> `AUD4-C12-02`, `-03`, `-05` (3 rows). (`AUD4-C12-04` was already closed in section 1.) **New total: 37 of 69 CLOSED-WITH-RECEIPT** (recomputed exactly at Stage 5).

**Wave 7 verdict: GREEN.** No functional regression, no data loss, one defect class eliminated structurally (audit scratch untracked -> the format-gate red class is gone at its root), and `F-B8-01` is fixed so a regeneration can no longer ship a client suite that fails.

**Remaining Stage 4:** `B12` (server dedupe content-comparison, alone, `cline-5`) -> then **Stage 5** (re-run all four audits; every remaining row must flip to CLOSED-WITH-RECEIPT).

---

## 18. STAGE 4 - WAVE 8 JUDGMENT (B12) - **STAGE 4 IS COMPLETE**

**Batch:** B12, `cline/task-5`, base `5264871` (rule W2b proven: `merge-base --is-ancestor 5264871 HEAD` exit 0). **Merge:** fast-forward -> `b06fafc`. Tree clean.

**Merged-main battery on `b06fafc` (coordinator-run, receipts `tool_fix/wave8/m_*.txt`):**

| Gate | Result |
|---|---|
| server `npx tsc --noEmit` | exit 0 |
| server `npm test` | **124 / 124 pass, 0 fail** (90 baseline + 34 new) |
| format (root) | 696 files, 0 changed |
| analyze | core 0 / core_ui 0 / core_app 0 |
| suites | core **+329** / core_ui **+289** / halal **+71** / core_app **+2002**, 0 fail, 0 skip |

**Independent verification (run by me, not taken from the report):**
- `index.ts` diff = **exactly** the new import + the dedupe block; nothing else in the file changed.
- `idempotency.ts` = a genuinely pure classifier (no I/O, no Firestore, no Stripe): precedence customer -> PaymentIntent -> amount; blank/non-integer on either side fails closed; `Number.isSafeInteger` on both amounts. Read line by line - no money computation, no mutation (law 0.4 intact).
- Client mapping = typed `IdempotencyConflictException` (+35/-0), guarded by BOTH `code == 'already-exists'` AND `details.code == 'IDEMPOTENCY_CONFLICT'`; its message is an abort, never a success.
- Red receipts real and non-empty (`red_conflict.txt` 57,730 B; `red_client.txt` 11,547 B); the red commit `0df5466` precedes implementation `ccaa890`.
- Territory = exactly the 5 code files + `tool_fix/b12/**`; forbidden set **zero** (payment.ts, packages, apps, rules, `.github`, `FIX_VERIFICATION.md` untouched).

**Finding closed:** `REC-B2-1` -> **CLOSED-WITH-RECEIPT**. The blind key-hit return at base (`index.ts:1092-1101`) is gone: a content-mismatched key now yields `already-exists` + `IDEMPOTENCY_CONFLICT` + a `logSecurityAlert`, and **never a foreign orderId**; a genuine replay still returns the same `orderId` with `idempotent: true` (server T-8 pin green in BOTH red and green).

**Disclosures (recorded, not hidden):**

| id | type | content | ruling |
|---|---|---|---|
| W8-D1 | DRIFT (my contract wording) | section 5 said the suites stay "+1996 core_app", yet T-3 *mandated* a new client test -> **+2002 (+6)**. The real invariant (no existing test changed, no drop) holds. | MY wording was too loose - the +6 is contract-mandated. Same class as B3's T-2/T-3 contradiction. |
| W8-D2 | ANOMALY (process) | the client mapping (`725f2d9`) was bundled with the server change rather than its own commit; ordering proven by the red receipt's timestamp. | ACCEPT with note: one-task-one-commit remains the rule; the evidence chain is intact. |
| W8-D3 | RESIDUAL (LOW) | whether the checkout SCREEN renders `IdempotencyConflictException.message` verbatim vs a generic failure | fail-closed either way (the call throws; "order placed" is unreachable). Owner: `p21` UI pass. |

**STAGE 4 IS COMPLETE.** All batches (B1, B2, B3, B3b, B4, B5, B6, B7, B8, B9, B10, B11, B12) are merged and judged; both CRITICALs and every money-path HIGH are closed; 37 of 69 register rows are CLOSED-WITH-RECEIPT (Stage 5 recomputes this precisely) and every remaining row has a named owner.

**NEXT - STAGE 5 (verification wave):** re-run all four read-only audits (AUD-1..AUD-4; prompts in `AUDIT_FLEET_13CLASSES.md`; rules A1-A6 + W1-W7) against this merged tree. Acceptance: every finding the re-audit raises is either already CLOSED-WITH-RECEIPT or receives a named owner, and any NEW finding enters the register with a disposition. Then **STAGE 6:** `p16 -> p17 || p19 -> p20 || p23 -> p21 || p24 -> p22 || p25 -> p18 -> p26`.

---

## 19. STAGE 5 - DELTA RE-AUDIT JUDGMENT (3 of 4 verified, 1 REJECTED)

**Merged (verified):** `cline/task-1` (AUD-1R, 2 commits) · `cline/task-2` (AUD-2R, 2 commits; stale base `2ec92c4` - the three-way merge correctly KEPT this register and the Stage-5 doc block) · `cline/task-3` (AUD-3R, 1 commit). Merge tip **`4e4eaaf`**. Post-merge proof: `git diff --name-only 40c3cb0..HEAD -- . ':!tool_audit'` = **0 files** (receipt-only, as the contract demands) and the worktree is clean.

### 19.1 What the three verified audits confirmed (with my own spot-checks)
| audit | independent verification I ran | result |
|---|---|---|
| AUD-1R | its receipts are derived from CURRENT code (`checkout_service` L75-L99 attempt-key/fingerprint, `index.ts` L1099-L1138 `classifyIdempotentReplay`); `gate_tsc.txt` is now non-empty (304 B - it was 0 B before its self-correction); `a5_zero_modification_proof.txt` 819 B; class-1 sweep = 226 names | all 11 target closures **HELD**; 0 new anomalies |
| AUD-2R | 35 receipts; findings AUD2R-01..04 present; it **retracted its own false lead** (the two tool suites DO run - `+85` tests via `--reporter json`) instead of reporting a phantom gap | class 10/11 GREEN; class 6 residual re-measured |
| AUD-3R | quotes the REAL baselines (`+329 / +289 / +2002 / +71`, npm 124/124, format 696/0); my own counts agree (barrel **43** exports; `showModalBottomSheet` **4** in `owner_dashboard.dart`); C8/C7/C9 all UNCHANGED vs Stage 1 | no unintended edit crept in during Stage 4 |

### 19.2 AUD-4R - **REJECTED (quarantined, NOT merged)**
Its *receipts* are genuine (`r0_test_core.txt` = +329, `core_ui` = +289, `core_app` = +2002, halal = +71 - the true baselines), but its *report prose* contradicts those receipts and the repository in six checkable places:

| # | the report says | the repo says |
|---|---|---|
| 1 | "core 22/22, core_ui 14/14, core_app 436/436, `apps/halal_app` 25/25" | its own receipts say 329/289/2002/71; **no `apps/halal_app` exists** (the shell is `apps/halal_boyz`) |
| 2 | "Registered worktrees: exactly 1" | `git worktree list` = **6** |
| 3 | "`origin/main` and `main` are identical at `eb5eb2f`" | main = `40c3cb0`; `eb5eb2f` was B8's feature tip |
| 4 | "53 deferral sites in 37 files, matching the B11 baseline" | `tool_fix/b11/c5_deferrals_head_raw.csv` has **29** rows |
| 5 | "all 4 sites point to `WHITE_LABEL_p22_adoption.md:38/42/48/54`"; owners "team-core", "platform-infra" | **no `WHITE_LABEL_p22_*` file exists**; no such owner names exist |
| 6 | "`isar.dll` documented in `FIX_VERIFICATION.md:4562`" | line 4562 is a D-5 row (pin-drop / menu re-scope); `isar.dll` IS tracked - the citation is false |

**Ruling: the class 4/5/12 delta is UNVERIFIED.** Its verdicts carry no authority; its scratch branch stays unmerged on `cline/task-4`. Do not cite it. AUD-4R must be re-run (see 19.4).

### 19.3 New findings from Stage 5 (each enters as a register row)
| id | class | Sev | finding | owner |
|---|---|---|---|---|
| **S5-01** | 5 | **MED** | **`AUD4-C5-01` REOPENED**: p20's staff-rung deferral now names `WHITE_LABEL_p22_staff.md`, but only p16..p20 exist - **p21..p26 were never written**. Renaming the owner did not create the spec, so the class-5 orphan survives in substance. | Stage 6: write the p21..p26 spec set; the row stays OPEN until the file exists |
| AUD2R-01 | 13 | LOW | `tool_guard/check_hygiene.ps1` rule-number drift (doc-block says 5/6, code emits `[RULE 4]`, format block commented `# Rule 5`). Behaviour is correct; the labels are not. | post-Stage-5 hygiene pass |
| **AUD2R-02** | 1/12 | LOW | `tool_guard/verify_ignore_rules.ps1:62-63` probes two **tracked** archives expecting them untracked -> the verifier can never pass (`RESULT: FAIL (2 of 34)`). A permanently-failing verifier is worse than none: it trains readers to ignore it. | post-Stage-5 hygiene pass |
| AUD2R-03 | 13 | INFO | methodology: the compact reporter prints no per-test lines into redirected stdout for fast suites - grepping stdout is NOT coverage proof; use `--reporter json`. | recorded as a fleet standing note |
| AUD2R-04 | 6 | LOW | class-6 residual re-confirmed: `navigationTabs` / `navigationHiddenRoutes` / `navigationRoutes`, `storeAndroidUrl` / `storeIosUrl`, and the typography/spacing/stripe keys have **no production consumer**. | `p25_generator_completeness` |

**Row accounting:** 69 original rows + 4 new = **73**; **36 CLOSED-WITH-RECEIPT** (37 minus the reopened `AUD4-C5-01`); 37 open, each with a named owner. No Stage-4 fix was weakened - the three verified audits found **0 regressions** across classes 1/2/3/6/7/8/9/10/11/13.

### 19.4 Follow-up: AUD-4R re-run (AUD-4R2) - VERIFIED AND MERGED
The re-run was dispatched to `<repo>-cline-4` under laws R-W, R-X, R-Y and completed at commit `f8093b8`.
- **Integrity verified:** `tool_audit/aud4r2/**` (42 files, +8841 lines, 0 deletions) merged cleanly to `main` at commit `35727fc`.
- **Blocker gate:** 100% GREEN verbatim matching receipts (`+329 / +289 / +2002 / +71`, npm 124 pass / 0 fail / 0 skip, tsc 0, format 696/0).
- **Task 1 (Class 4 premises):** Evaluated all 71 premises across FIX_b1..b12/b3b. 12 exact, 45 exact-loc, 10 relocated, 4 broken (2 windowing artifacts re-adjudicated valid, 2 genuinely dead due to deliberate deletions: `_moneySymbol` and `app_colors.dart` truncation).
- **Task 2 (Class 5 deferrals):** Re-ran deferrals extractor. Yielded 34 rows (31 live deferral sites + 3 section headers). Disproved AUD-4R fabricated "53 deferrals" claim. Confirmed **S5-01** (`WHITE_LABEL_p22_staff.md` does not exist via `Test-Path = False`). Finding `AUD4-C5-01` remains OPEN for Stage 6 resolution.
- **Task 3 & 4 (Class 12 hygiene & claim checks):** Confirmed **AUD2R-02** (`verify_ignore_rules.ps1` fails with `RESULT: FAIL (2 of 34)` expecting tracked archives to be untracked). Confirmed **AUD2R-01** (rule-number drift). Validated all 6 contradictions cited against rejected AUD-4R against repo tip.

**Stage-5 Final Status:** 4 of 4 audits executed and verified (`AUD-1R`, `AUD-2R`, `AUD-3R`, `AUD-4R2` all merged on `main`). All 13 anomaly classes fully audited. Stage 5 is COMPLETE.

---

## 20. STAGE 5 COMPLETE - GATEWAY TO STAGE 6 ADOPTION

With Stage 5 delta re-audits complete and verified:
1. **Zero Blocker Defects:** 0 CRITICAL and 0 money-path HIGH issues remain open.
2. **Register Status:** 73 total rows tracked; **36 CLOSED-WITH-RECEIPT**; 37 open across planned spec waves with explicit owners.
3. **Stage 6 Immediate Prerequisite:** Resolve **S5-01** by authoring the spec backlog `WHITE_LABEL_p21..p26` (including `WHITE_LABEL_p22_staff.md`) to satisfy deferrals before dispatching p16+ adoption batches.



---

## 22. STAGE 6 WAVES 1-3 JUDGED + THE LEDGER GAP CLOSED

### 22.1 Wave verdicts (coordinator re-run, not executor claims)

| Wave | Batches | Merge | Coordinator battery on merged main |
|---|---|---|---|
| W1 | UI-6 (p16) · UI-9 (p19) | p19 FF `80356e3`; p16 -> `efc456e` | analyze 0 x4, format 0, all suites 0 skip |
| W2 | UI-10 (p20) · UI-11 (p23) | p23 FF `c838d7e`; p20 `--no-ff` -> `42b7fcc` | suite math reconciled exactly (1993 + 3); barrel 43 -> 52 exports |
| W3 | UI-13 (p21) · UI-12 (p22) | p21 FF `6c74a1a`; p22 `--no-ff` `4e75ac2` (127 vs 204 files, ZERO overlap); receipts `c05faf7` | format 770/0; analyze 0 x4; core_app **+2209**; core_ui **+391**; core **+364**; halal **+71**; functions 169/169; 0 skips |

Amendment A1 verified **in code**, not prose: `onboarding_screen.dart:110-111` wires both `pageLabelBuilder`
and `pageDotLabelBuilder` from `trackerStepOfTotal` (the temporary reuse whose successor keys are now p18 §A2.2).

### 22.2 The ledger gap (found and closed this session)

`FIX_VERIFICATION.md` had **no** Stage-6 entries: the last block was the p11..p15 library wave. Six shipped waves
(UI-6, UI-9, UI-10, UI-11, UI-13 and the newly composed UI-12) were merged but unrecorded. Closed by appending:
- the five paste-ready blocks from `tool_uilib/p{16,19,20,21,23}/*_report.md` (extracted mechanically, not retyped);
- a **composed** UI-12 block (`p22_report.md` never wrote one) built only from its own receipts, plus per-phase commits;
- a coordinator wave-closure addendum carrying the merged tips, the independent battery, the app-wide
  remaining banned-pattern census (`tool_uilib/merged_sweep_main_4e75ac2.txt`: `7 spinners + 2 Cards`, all owned),
  the four corrigenda, and the open-row list.
Result: 233 lines appended (`FIX_VERIFICATION.md` 4560 -> ~5790 lines), BOM-free, byte-verified (69 `E2 80 94`
em-dashes, 0 double-encoded sequences).

### 22.3 Rows moved this cycle

**Newly CLOSED-WITH-RECEIPT:** `F3-07` (unassigned surfaces — customer half p21 phase G, staff half p22;
survivors are p17) · `F3-13` (missing `BrandSheet` family — p23 delivered 9 files) · `F3-14`
(`owner_dashboard.dart` 1102 -> 111 lines split, byte-identical goldens) · `F3-05` **partially** (service default +
shipped core config removed by p21/H; residuals: halal config line -> p25 T-4, orphan ARB key -> p18 §A2.4).

**Still open, each with a named owner:** `F3-09`, `F3-10/-11/-12/-15` (p17 + the 2 driver-POD + 1 reservations
survivors) · `AUD2R-01`, `AUD2R-02`, `AUD2R-04` (p25) · V4/V5 LOW (p25 / next doc sweep) · plus the p18/p24/p26
carriers. **0 CRITICAL, 0 money-path HIGH open** (unchanged since §20).

**New handoff recorded:** `BrandDataTable` pager copy is unreachable at `dead_letter_screen.dart:98` (no pagination
arguments -> no English fallbacks rendered). Owner **p23b** (unscheduled; latent, zero user-visible effect until
pagination is enabled there). See p18 §A2.3.

### 22.4 Wave 4 dispatch (this session)

| Lane | Batch | Worktree / branch | Territory |
|---|---|---|---|
| A | UI-8 (p18) arabic | `<repo>-worktree` / `cline/w4-p18` | ARB pair + generated l10n + `currency_format.dart` + RTL as found in `features/**` and `core_ui/src/ui/**` + the C-1 call-site swap + C-3 key removal + `tool_uilib/p18/**` |
| B | UI-14 (p25) generator/guards | `<repo>-cline-2` / `cline/w4-p25` | `core_app/tool/whitelabel.dart` (warnings + docblock) + `tool_guard/*.ps1` + `apps/halal_boyz/assets/client_config.json` (one line) + 3 new tool tests + `tool_uilib/p25/**` |

Verified disjoint: the only near-overlap (`core_app/lib/app/config/**`) is p18's `currency_format.dart` vs p25's
**read-only** parser constraint (L-P3) — no shared file. `p17` is deliberately NOT paired with `p18` (it adds event
lines to the same `features/**` files p18 sweeps); `p17 || p24` is wave 5.


___

## 23. STAGE 6 WAVE 4 JUDGED - ARABIC HARDENING + GENERATOR/HYGIENE LANDED

### 23.1 Wave verdicts (coordinator re-run on the merged tree, not executor claims)

| Lane | Batch | Merge into main | Coordinator battery on merged main `765874c` |
|---|---|---|---|
| A | UI-8 (p18) arabic/localization | `cline/w4-p18` @ `4ee3a4e` -> **fast-forward** `11ee087 -> 4ee3a4e` | format **775/0** · analyze **0 x4** · core_app **+2262** · core_ui **+391** · core **+364** · halal **+71** (0 skips) · functions tsc 0 + npm **169/169** |
| B | UI-14 (p25) generator/guards | `cline/w4-p25` @ `621c54c` -> **merge commit `765874c`** (parents `4ee3a4e` + `621c54c`) | same run as above (single merged battery) |

Suite reconciliation proves nothing was lost: plain baseline `11ee087` = **2226**; +39 (p18) +14 (p25) = **2279**;
minus the **17** tests carrying `e2e`/`nightly`/`needs-emulator` = **2262** observed. Arithmetic closes.

Incident recorded for future merges: a first `git merge cline/w4-p25` aborted with
`Another git process seems to be running in this repository` (exit 1, no leftover `index.lock`, no `MERGE_HEAD`,
tree clean) after printing `Updating 11ee087..621c54c` — it was one step from moving `main` onto the p25 tip and
**past p18**. Nothing was written. Rule: after a lock-abort, inspect `git log -1 --format='%h %p'` before retrying.

### 23.2 Rows moved this cycle

- `AUD2R-01` **CLOSED-WITH-RECEIPT** — `check_hygiene.ps1` rules 1-6 now self-tested and the docblock names all six.
- `AUD2R-02` **CLOSED-WITH-RECEIPT** — `verify_ignore_rules.ps1` PASS **35 probes / 0 misclassified** (pre-fix FAIL 2 of 34).
- `AUD2R-04` **CLOSED-WITH-RECEIPT (disposition recorded)** — 16-row register, citations validated, INERT rows re-proven consumer-free; the single REMOVE candidate (`environment.devAdminPin`) stays an **operator** action (L-P2: no wiring, no removal in-lane).
- `F3-05` **fully CLOSED** — both residues named in §22.3 are gone: halal `"referrals": true` (p25 T-4) and the orphan `enterReferralCode` ARB key in both ARBs (p18 A2.4 / C-3).
- Batch-level, no register row of their own: **UI-8** (CLDR six-form plurals, locale-aware currency, 18 RTL fixes behind a fail-closed inventory guard, 5 RTL goldens, `ARABIC_REVIEW_CHECKLIST.md` + visual pack) and **UI-14** (completeness warnings channel with **L-P1 content-drift 0**, 28-key engine matrix, 16-row config disposition, guard self-tests).

### 23.3 Cross-lane handoff verified post-merge, not by prose

`p25 H-1` asked `p18` to drop the orphan `enterReferralCode`; `p18 C-3` did (both ARBs + regenerated l10n) and
`p25 T-4` deleted the matching halal config line. Post-merge `git grep` finds **zero production references** — the
only hits are the parity test asserting the key's absence and the immutable `tool_audit/aud3*` receipt regexes.
`p18 C-2` keeps the `BrandDataTable` pager-copy gap owned by **p23b** (unchanged, still latent: `dead_letter_screen.dart:98` passes no pagination arguments).

### 23.4 Still open, each with a named owner

`F3-09` and `F3-10/-11/-12/-15` (**p17** + the 2 driver-POD + 1 reservations survivors) · V4/V5 LOW (next doc sweep)
· `environment.devAdminPin` removal (operator) · Class-D `String`->`int` placeholder migration for 8 count-bearing
keys (owner -> future batch) · native Arabic sign-off + visual-pack approval (owner) · `BrandDataTable` pager copy
(p23b) · p24/p26 carriers. **0 CRITICAL, 0 money-path HIGH open** (unchanged since §20).

### 23.5 Wave 5 dispatch (next) and why the pairing is what it is

| Lane | Batch | Worktree / branch to create | Territory |
|---|---|---|---|
| A | UI-7 (p17) banned-pattern floor sweep | `<repo>-worktree` / `cline/w5-p17` | `core_app/lib/features/**` (menu/cart/checkout/home/profile event lines + the 4 CPI / 2 raw Card survivors in analytics) + its own tests + `tool_uilib/p17/**` |
| B | UI-15 (p24) **settings surface** (`F3-01` locale choice, `F3-02` theme mode, `F3-04` notification preference; register §2.3 owner column = `p24_settings`) | `<repo>-cline-2` / `cline/w5-p24` | `WHITE_LABEL_p24_settings.md` §5.7: `features/profile/**` + the single `app_bootstrap.dart` locale wiring + `packages/core_ui/lib/src/settings/**` + exactly one gate in `packages/core/lib/src/network/push_notification_service.dart` (`:205-208`). Intersection with p17's file list = **∅** (proof in §5.7); `apps/**` forbidden — the halal shell inherits with zero edits |

`p17` was deliberately **not** paired with `p18` (both add lines to the same `features/**` files); with `p18`
merged, `p17` is unblocked and now pairs with `p24`, whose spec is authored in the same session. `p26` (closing
harness) rewrites the very harness the other lanes are measured with, so it runs **last, alone**.


## 24. STAGE 6 WAVE 5 JUDGED - ANALYTICS + SETTINGS LANDED (coordinator re-run on the merged tree)

### 24.1 Wave verdicts

| Lane | Batch | Branch tip | Merged into `main` as | Verdict |
|---|---|---|---|---|
| A | UI-7 (p17) client analytics | `cline/w5-p17` `9bf70fd` (7 commits) | `45ee505` | GREEN - merged |
| B | UI-15 (p24) settings surface | `cline/w5-p24` `375f68b` (6 commits) | `c8a1c13` | GREEN - merged |

`main`: `61ff5a9` -> `45ee505` -> `c8a1c13`. Both lanes were based on the same `61ff5a9` (`merge-base` = `61ff5a9`; `--is-ancestor 61ff5a9` exits 0 for both). Every gate below was re-measured on the merged tree; nothing is inherited from a lane report. Nothing pushed - `origin/main` is still `c05faf7`.

### 24.2 Merge mechanics (why the l10n overlap was safe)

- The two lanes' source intersection is exactly 5 files: `core_app/lib/l10n/app_{en,ar}.arb` plus the 3 generated `app_localizations*.dart`. No other shared file, and **neither lane touched a coordinator doc** - proved by intersecting the two `git diff --name-only` lists.
- Git auto-merged all five with **zero conflict markers**. A clean auto-merge of a *generated* artefact proves nothing, so it was re-proved: `flutter gen-l10n` on the merged tree exits 0 with an **empty** `git status --porcelain -- core_app/lib/l10n` - the merged generated files are byte-identical to a fresh regeneration from the union ARB.
- ARB union measured independently of the tests: **672 en keys = 672 ar keys**, 0 one-sided keys, no `referral` key => `F3-05` remains fully closed post-merge.

### 24.3 Merged-tip battery (`c8a1c13`)

format 793 files / **0 changed** · analyze x4 = **0 issues** (`--fatal-infos` on core_app + halal, `dart analyze` on the packages) · core_app plain-tier **2311** pass (exit 0, **0 skip**) · packages/core **383** · packages/core_ui **411** · apps/halal_boyz **71** · functions `tsc --noEmit` exit 0 · functions `npm test` **169/169** (0 fail / 0 skip / 0 todo) · profile goldens (light, dark, textScale-1.5x) + the RTL set pass on the merged tree · territory: 184 files changed with **0** `apps/**`, **0** pubspec, **0** functions, **0** rules, **0** `*.g.dart`, the source set being exactly the union of the two declared territories.

### 24.4 Tier-normalised arithmetic, and the one lane claim it corrects

Plain-tier core_app = 2262 (baseline) + 24 (p17) + 25 (p24) = **2311** = measured. Unfiltered = 2279 + 24 + 25 = 2328, matching the lane receipts (p17 `2303` unfiltered / `2286` plain; p24 `2304` unfiltered / `2287` plain). **p24's ledger line compared its unfiltered `2304` against the 2262 plain-tier floor** - the floor is still cleared, but the ledger block now states the tier and the normalised value **2287**, re-measured on p24's own worktree (whose `b0` receipt ends `+2262`, proving its baseline run was plain-tier). No test was lost at the merge: `test/settings/**` and `test/core/analytics/**` both ran inside the merged suite, and running those files explicitly on the merged tip gives `+20: All tests passed!`.

### 24.5 Rows moved this cycle, and rows deliberately left open

- **CLOSED:** `F3-01` (locale switcher), `F3-02` (theme mode), `F3-04` (end-user notification preference) - all three were "code-supported but user-unreachable" (this register, §2). Each now has a reachable control that changes the running app in-session and a named production consumer, pinned by p24's reachability guard and the echo preference read-once assertion.
- **NOT closed:** `F3-09` (spinner adoption gap, 76 sites / 33 screens) and `F3-10/-11/-12/-15` (ListTile 19/13, Card 15/10, raw TextField 12/4, decorated Container 7/6). p17 replaced its named analytics survivors - verified in the diff, not the prose: the `CircularProgressIndicator` loading path in `analytics_snapshot.dart` became `SkeletonLoader.card(...)`, a raw `Card(` became `BrandCard(` - but the register's residual counts across the other screens are untouched, so those rows keep their original owners.
- `F3-05` stays fully closed (ARB parity re-proved post-merge).

### 24.6 One transient failure, recorded

`packages/core` reported `+382 -1` once during a deliberately parallelised 4-way battery run; it did not reproduce (2 solo runs on the merged tip: 383/383, exit 0) and the failing test's name was not captured. Pre-existing load-sensitivity surface: 13 `packages/core` test files use wall-clock or temp-dir IO (`isar_service_test.dart` 9 hits, `json_converters_test.dart` 4, `sync_queue_test.dart` 2, ...). Disposition **PRE-EXISTING-FLAGGED**, owner = the **p26** harness lane. No new row opened.

### 24.7 Corrections recorded this cycle

1. p17's report and receipt index cite `receipts/b_final_territory.txt`; the file is `tool_uilib/p17/b_final_territory.txt`.
2. p24's `2304` is unfiltered (see §24.4).
3. The p24 spec's T-4 ARB placeholder `532 -> 532+n` contradicts the measured `655 -> 672` (p17 +5 keys: topDishesToday, abandonedCarts, openAnalyticsConsole, externalDataDailyNote, externalLinkUnavailable; p24 +12 settings* keys; none removed); the spec line was corrected (Law 19).
4. The p24 spec pinned the notification gate at `push_notification_service.dart:205-208` (test-seam vicinity); the executable gate is `:348-353` inside `_onForegroundMessage` - one occurrence, read-once asserted by the T-5 guard. Same site, recorded, not a deviation.
5. The rules/storage suites were not re-run on the merged tip (no rules or index file is in either lane's diff); their last measured state stands at the p17 tip (firestore `197/0`, storage `8/0`, functions GDPR `30/0`) and is **carried over, not re-verified on `c8a1c13`**.

### 24.8 Wave 6 assembled: D-P26-1 answered FULL, spec authored, single `p26` lane dispatched

Wave 6 is `p26` **alone** - it rewrites the harness every other lane is measured with, so it runs last. **D-P26-1 was answered 2026-09-30: FULL** (harness rewrite + hygiene). The spec is authored and on disk: `WHITE_LABEL_p26_harness.md`, 101 lines, every premise carrying a file:line verified against `2db244c` - the fleet's own detector objective (`ANOMALY_CLASS_PLAYBOOK.md:32`, detectors 3/5/6/8/9 as a committed script + repo test; fleet row `AUDIT_FLEET_13CLASSES.md:103`), `REC-B2-2`'s "make private + documented re-pin" (`:183`), p22's `hasOnly` handoff row (`WHITE_LABEL_p22_staff.md:71`), the `%TEMP%` logger-injection residue (**77 sites in 60 test files**) plus the two production logger sites (`app_bootstrap.dart:529-534` correctly gated; `tax_service.dart:16` a genuine production defect), the litter duplicate (110 tracked `tool_perf2/**` files vs the tracked `tool_archive/perf2_litter.tar.gz`), and the `pipeline.dart` stub. Assembling it corrected two facts carried in earlier notes: the orders **create** rule is `firestore.rules:451` / `:465-472` (the `hasOnly` clauses at `:483-530` are update-time only; `:361-368` is the unrelated `settings/{doc}` rule), and the no-arg mint branch is pinned by exactly **two** tests (`checkout_service_test.dart:373`, `:385`), not eight. The spec raises three new owner decisions - **D-P26-2** (litter), **D-P26-3** (`pipeline.dart`), **D-P26-4** (`hasOnly` hardening) - and this is the last wave of the sequence. **All three were answered the same day and folded into the spec, so the lane executes them instead of stopping: D-P26-2 = delete the 110-file `tool_perf2/**` duplicate (the tracked `tool_archive/perf2_litter.tar.gz` stays as the evidence), track `.clinerules/**` + `.clineignore`, add one ignore pattern for the machine-local `.agents/**` cache · D-P26-3 = implement the real Law-10 gate · D-P26-4 = harden the orders create rule with `affectedKeys().hasOnly([...])` in both rule files and drop the offline payload's `orderSource: null` key.** D-P25-1 = keep (no narrowing). The push of `main`, the wave-1..5 branch/worktree retirement and the 22 encoding-damaged ledger lines remain **coordinator actions at Stage-6 close**, after this lane merges.

**Still open, each with a named owner:** `F3-09` + `F3-10/-11/-12/-15` (their original owners) · V4/V5 LOW (next doc sweep) · `environment.devAdminPin` removal (operator) · Class-D `String`->`int` placeholder migration for the 8 count-bearing keys · native Arabic sign-off + visual-pack approval (owner) · `BrandDataTable` pager copy (p23b) · the p26 harness lane. **0 CRITICAL, 0 money-path HIGH open** (unchanged since §20).

**Owner decisions after wave 6:** summarised in §25.7 - push `main` to `origin` (`origin/main` is still `c05faf7e`; nothing pushed) · retire the wave-1..5 worktrees/branches, but **keep** `cline/task-4` unmerged (it carries the documented `tool_audit/aud4r/**` quarantine) · `cline/task-1` / `cline/task-2` unpushed commits · two pre-existing reds to own: `constitution_guard` 73 and `verify_constitution.dart` on Windows. D-P26-2/-3/-4 are **answered and executed** (§25.6); D-P25-1 honoured as no-narrowing.

**State:** `main = 50dc930c` + the wave-6 merged-tip battery commit (the `t8_merged_*` receipts, this register's §25, `core_app/CHANGELOG.md`, the encoding repair, the UI-16 block); primary worktree clean; `origin/main = c05faf7e` - unpushed. See §25.8.


---

---

## 25. STAGE 6 WAVE 6 JUDGED - p26 HARNESS + HYGIENE LANDED (coordinator re-run on the merged tree)

### 25.1 Wave verdicts

| Lane | Batch | Branch tip | Merged into `main` as | Verdict |
|---|---|---|---|---|
| A | UI-16 (p26) harness + hygiene | `cline/w6-p26` `50dc930c` (7 commits) | `50dc930c` (fast-forward) | GREEN - merged; one pre-existing red named in §25.3 |

Wave 6 was `p26` **alone** - it rewrites the harness every other lane is measured with, so it runs last. Commits, oldest first: T-1 `2e276b51` (detectors 3/5/6/8/9 as a committed script + repo test, and the real Law-10 gate) · T-2 `d08ac589` (hermetic per-test log dirs, killing the machine-global `Directory.systemTemp` sink, + the fleet negative guard) · T-3 `896d53b8` (the session-wide key path closed: no-arg mint made private, attempt-scoped re-pin) · T-4 `ec313e88` (orders-create key-shape lock in **both** rule files + the forbidden offline `orderSource` key dropped, halal mirror regenerated) · T-5 `1ad57a23` (hygiene sweep: `DEFERRED.md` reconciled on file:line evidence, `tool_perf2/**` deleted per D-P26-2(a)) · T-6 `a5a274a5` (final battery, report, receipts) · T-7 `50dc930c` (the T-5 dangling-evidence repair, §25.4).

Every owner decision raised by the p26 spec was **answered the same day and executed by the lane instead of re-deferred**: D-P26-2 (litter disposition + versioning), D-P26-3 (`pipeline.dart`), D-P26-4 (orders-create `hasOnly` hardening), with D-P25-1 honoured as *no narrowing* of any existing ignore pattern (one pattern **added**: `/.agents/`).

### 25.2 Merge mechanics

`main` (`1ac14c1f`) was a strict ancestor of the lane tip, so the merge is a **fast-forward** with no merge commit: `git log --format='%h parents:%p'` shows `50dc930c parents:a5a274a5` and `a5a274a5 parents:1ad57a23` - one parent each - and `git merge-base --is-ancestor 1ac14c1f main` exits 0. Six paths in the primary worktree were pre-existing *untracked* copies of files the lane had just started tracking under D-P26-2(c) (`.clineignore` plus five `.clinerules/*.md`); five were byte-identical to the lane blobs, and the sixth (`20-core-app-carnama.md`) was the **older** pre-p26 text - its accuracy warning still called `pipeline.dart` unimplemented, which T-1 made false, so Law 19 had already corrected it in the lane and the tracked version correctly overwrote the stale copy. All six were copied to `%TEMP%\stage6_rules_backup\` and removed so the fast-forward could write the tracked versions. Result: `tool_perf2/` is gone from the tracked tree, `.agents/**` is ignored, the tree came out clean, and all 57 cited files live again under `tool_archive/perf2_cited/**`.
### 25.3 Merged-tip battery (`main = 50dc930c`, coordinator's own run)

Every number below was measured **on the merged tree**; nothing is inherited from a lane report. Receipts: `tool_uilib/p26/receipts/t8_merged_*.txt`.

- `dart format --output=none --set-exit-if-changed .` - **0 changed**, exit 0.
- `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) - **0 issues**, 4/4 exit 0.
- Tests: core_app plain tier **2359** pass, **0 fail / 0 skip**, exit 0 · packages/core **383** · packages/core_ui **411** · apps/halal_boyz **71** - each reported `All tests passed!`.
- `dart tool/pipeline.dart` - **exit 0**: `[gate] format ok` / `[gate] analyze ok` / `[gate] tests ok` / `[pipeline] all 3 gates green -> exit 0`.
- Cloud Functions: `npm run lint` exit 0 · `npx tsc --noEmit` exit 0 · `npm test` **169 pass / 0 fail / 0 skipped / 0 todo**.
- Rules, emulator with `--project demo-carnama`: firestore **PASSED 206 / FAILED 0 / TOTAL 206** · storage **PASSED 8 / FAILED 0 / TOTAL 8**.
- Harness guards: `tool_guard/verify_ignore_rules.ps1` **PASS (35 probes, 0 misclassified)** · `tool_guard/guard_selftest.ps1` **PASS** (it proves the verifier is falsifiable - the deliberately lying probe is caught) · `tool_guard/check_hygiene.ps1` **all hygiene checks passed** · `dart run tool/anomaly_detectors.dart` **exit 0** (`all candidates declared`).

Deltas against dispatch: core_app **2311 -> 2359** (+48, none lost) · core **383**, core_ui **411**, halal **71**, functions **169** unchanged · **0 new skips**. §24.5's note 5 is now closed: the rules and storage suites **were** re-run on the merged tip (206/206, 8/8) rather than carried over.

**The one red, named.** `dart run tool/constitution_guard.dart` exits 1 with `Constitution violations found: 73`. It is **pre-existing and untouched by this cycle**, proved by running the same tool on three trees: the merged `main` = **73**, the untouched lane worktree `<repo>-worktree` = **73**, and the **pre-p26** wave-5 worktree `<repo>-cline-2` (`cline/w5-p24` `375f68ba`) = **73**. The tool scans only `core_app/lib` (non-`const` `Color(`/`Colors.`, `// TODO`/`// FIXME`, `print(`, `package:firebase_auth` imports), so no doc, receipt or rule file in this cycle can move it. It is **not a CI job** (`carnama_ci.yml` defines no `constitution_guard` step), and the constitution's other named check, `dart tool/verify_constitution.dart`, still cannot run on Windows (pre-existing `_checkGrep` failure). Both are recorded rather than hidden: a green verdict must not be bought by deleting the check (Laws 10 and 13).

### 25.4 The regression T-5 opened, repaired rather than reverted (T-7)

D-P26-2(a) stands - the `tool_perf2/**` duplicate stays deleted. But **26 citation tokens in 9 tracked files** (live source and tests, not just prose) pointed at **57 of the deleted paths**, so those references resolved to nothing. T-7 restored exactly those 57 files under a new tracked prefix, `tool_archive/perf2_cited/tool_perf2/**`, and repointed the 26 tokens. Byte accounting measured on the diff instead of on tree size: T-5 removed **104 files / 6,566,852 B**; of that set **57 files / 1,577,243 B** are restored and **47 files / 4,989,609 B** remain history-only. Restoring at the *original* path was impossible - the ignore-guard probes (`*.info`, `*.log`) must stay ignored - which is why the archive uses a new prefix, and the guard behaves exactly as before (35 probes, 0 misclassified). Every restored file is identical to its `1ac14c1f` blob, verified twice: at staging (`git rev-parse :path` against `git rev-parse 1ac14c1f:path` - **57/57 equal, 0 mismatches**) and again after the merge. Residue: **12 lines / 15 tokens** still name `tool_perf2/**` paths; each was checked with `git log --all --diff-filter=A` and **none was ever tracked**, so no dangling reference remains. One figure in the wave-6 block is corrected here: `tool_archive/perf2_litter.tar.gz` (212 entries of *untracked* scratch) has **0 intersection** with the 104 *tracked* paths T-5 deleted, so "the tarball stays as the evidence" is false for that duplicate - git history under `1ac14c1f` is the only copy. Recorded in `tool_archive/perf2_cited/README.md` and `tool_uilib/p26/receipts/t7_evidence_restore.txt`.
### 25.5 The encoding item: closed by repair, and the note that mis-described it

The item was carried since §22 as "22 encoding-damaged lines", with U+FFFD codepoints at `:112`, `:171`, `:2138`, `:4568-4581` and `:5529-5539`. Measurement corrects the description: `FIX_VERIFICATION.md` carried exactly **32 U+FFFD codepoints on 8 lines** (`:5529`, `:5532-5537`, `:5539`) - and it carried the same 32 when that note was first written (`ed7c9db1`) - so the other four ranges never held damage; they are the false-positive class a console dump produces for *correctly* stored multi-byte characters, of which this file legitimately has 103. The decisive evidence is git itself: at `15bc0384`, the commit that **introduced** the wave-2 text, the file decodes with **U+FFFD = 0**, so the original characters were in the repository and nothing had to be guessed. Each damaged sequence was replaced with the byte-exact original from `15bc0384:FIX_VERIFICATION.md` (`§` in `(§2 W2 row only)` and `(W2 §2 row)`; `—` in "FAILED — no customer clause" and "ungated — both flipped"); arrows and separators elsewhere were already intact and are untouched. Post-repair state, measured on the working file: **U+FFFD = 0**, CRLF uniform (6167 CRLF, 0 lone LF, 0 lone CR), no BOM, and the staged blob differs from `HEAD` on **exactly 8 lines** (equal-length object-level blob comparison, stricter than a `--numstat` heuristic). The only intended difference inside those lines beyond the restoration is the `:5529` citation T-7 repointed.

### 25.6 Rows moved this cycle, and rows deliberately left open

- **Answered and executed:** D-P26-2 (a: delete the duplicate; c: track `.clinerules/**` + `.clineignore`, ignore `/.agents/`) · D-P26-3 (i: `pipeline.dart` is a real gate - proved both by its repo test, which pins a failing gate to exit 1, and by the exit-0 run on the merged tree in §25.3) · D-P26-4 (a: orders-create key-shape lock in `firestore.rules` **and** `staging.firestore.rules`, the forbidden offline `orderSource` key dropped, the generated halal mirror regenerated byte-for-byte).
- **CLOSED by T-5 on file:line evidence:** `DEFERRED.md` D1, D3, D4, D5, D7, D8; H2 `Stubbed` -> `Unstarted` (no thermal code exists); C1 `Stubbed` -> `Done` with the residual owner named; M2's stale App Check path corrected. H1 + C2 stay open with named owners.
- **NOT closed, owners unchanged:** `F3-09` and `F3-10/-11/-12/-15` adoption gaps - the detector's own merged-tip numbers are 6 sites / 5 files (`CircularProgressIndicator`) and 2/2 (`Card`) against baselines 76/33 and 15/10, all still `[non-increasing]` · V4/V5 LOW (next doc sweep) · `environment.devAdminPin` removal (operator) · Class-D `String`->`int` placeholder migration for the 8 count-bearing keys · native Arabic sign-off + visual-pack approval (owner) · `BrandDataTable` pager copy (p23b). **0 CRITICAL, 0 money-path HIGH open** (unchanged since §20).

### 25.7 Owner decisions after wave 6

- **Push.** `main` is `50dc930c` plus this cycle's commit, locally; `origin/main` is still `c05faf7e`, nothing pushed. On your word: `git push origin main`.
- **`cline/task-4` retention.** That branch holds the *documented quarantine* (`tool_audit/aud4r/**`) that `main`'s audit references cite. Recommendation: **keep the branch, do not merge it**; retire only the wave-1..5 worktrees/branches (`cline/w3-p21`, `cline/w3-p22`, `cline/w4-p18`, `cline/w4-p25`, `cline/w5-p17`, `cline/w5-p24`). `<repo>-worktree` (`cline/w6-p26`) is now content-identical to `main` and can be retired with them.
- **`cline/task-1` / `cline/task-2`** each hold unpushed local commits (`3f4ad724`, `c838d7eb`) ahead of their remotes (`5e30a656`, `15bc0384`): decide push vs fold into a follow-up batch.
- **Pre-existing reds to own (not this cycle's):** `constitution_guard` 73 (§25.3) and `verify_constitution.dart` being unrunnable on Windows.
- Carried from §24: D-P24-1 (server-side unsubscribe; shipped default = client-side foreground echo only), native Arabic sign-off, and the disclosed `apps/halal_boyz/backend/firestore.rules` regeneration (the generated byte-copy is asserted by `whitelabel_backend_bundle_test.dart`).

### 25.8 State

`main = 50dc930c` + this cycle's commit (the `t8_merged_*` receipts, the encoding repair, the UI-16 block, `core_app/CHANGELOG.md` and this section). Primary worktree clean. `origin/main = c05faf7e` - unpushed. Worktrees live: primary, `cline-1` (w6-p26, = `main`), `cline-2` (w5-p24), `cline-3` (task-3), `cline-4` (task-4, quarantine), `cline-5` (task-5). Every wave-6 artefact is committed locally; **the push and the branch retirement are the only remaining steps, and both need your go-ahead.**
