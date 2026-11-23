# WHITE_LABEL_p27 — constitution zero-red (both constitution gates to exit 0)

**Scope, one line:** close exactly two reds — `constitution_guard` 73 → 0 and
`verify_constitution.dart` unrunnable → exit 0 — with their genuine code defects only (10 colour
lines, 6 auth-import sites, 5 role sites); everything else is already green (§1) and stays out (§2).

Spec file = the acceptance contract (METHOD §1). Coordinator-written 2026-09-30, after that
session's unspec'd edit attempt was parked rather shipped (§1). Execution starts only once this
file is accepted; the executor works inside it, never around it.

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

**Tip:** `main = 822a4f88` (single parent `50dc930c` — the p26 lane fast-forward).

**BLOCKER (green BEFORE any edit) — cite, do not re-derive (METHOD §2.9):**

| Gate | Result | Receipt |
|---|---|---|
| `dart format --output=none --set-exit-if-changed .` | 0 changed, exit 0 | `t8_merged_format.txt`, re-confirmed post-stash this session (813 files, 0 changed) |
| `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) | 0 issues ×4 | `t8_merged_analyze_*.txt` |
| core_app plain tier / core / core_ui / halal | **2359** / 383 / 411 / 71, 0 fail 0 skip | `t8_merged_test_*.txt` |
| functions lint / tsc / npm test | 0 / 0 / **169** pass 0 fail | `t8_merged_functions_*.txt` |
| rules (emulator, `--project demo-carnama`) | firestore **206/206**, storage **8/8** | `t8_merged_rules_*.txt` |
| guards + detectors | ignore-guard PASS 35/0 · selftest PASS · hygiene PASS · detectors exit 0 | `t8_merged_guard_*.txt`, `t8_merged_detectors.txt` |

**R1 — `constitution_guard` exit 1, `Constitution violations found: 73`** (`t9_guard_cli_red.txt`),
over `core_app/lib` (141 dart files). Case-faithful mirror breakdown: COLOR 65 · FBAUTH 6 ·
PRINT 2 · TODO 0. Classed: **~57 false positives** (39 `BrandColors.of(...)` — the token layer
the constitution demands; 11 identifiers containing `Color(` such as `isValidHexColor(` and
`_promotionColor(`; 2 `buildOrderAttemptFingerprint(` = the only PRINT hits; 3 comment-only
lines) vs **16 genuine** (8 confetti `Color(0xFF…)` elements inside a `const [` block, the
`color: Colors.white` banner, the Google-blue literal, 6 `package:firebase_auth` imports).

**R2 — `verify_constitution.dart` cannot run** without GNU `grep`, and even there its cwd
contract is self-contradictory (`File('lib')` needs `core_app`, `File('.git/hooks/pre-push')`
needs the repo root); it carries `// ignore_for_file: avoid_print`. Re-measured in
Dart-equivalent form over `lib`: Law1 `assume|guess|probably` **0** · Law3 `Colors.` **43**
(39 BrandColors + 3 comments + 1 real) · Law4 `TODO|FIXME` **0** but bare `placeholder` 49
(prose + `_placeholderKeyPattern`, the *guard against* placeholders) and `REPLACE_ME` 4 (all
inside the fail-closed gate that rejects them) · Law12 `role ==` **5** (presentation-only:
gateway tab whitelist + DLQ link) · Law16 `API_KEY|SECRET` **2** (env-var *names* in
`firebase_options.dart` — the law's own correct mechanism) · Laws 21/13/18/26 file checks all
exist (`<repo>\.git\hooks\pre-push`, `tool/measure_apk.sh`, `staging.firestore.rules`,
`DEFERRED.md`).

**UNVERIFIED at spec time (executor measures, does not assume):**

- Exact breakdown of the **55 `flutter analyze --fatal-infos` issues** the parked WIP produced
  (receipt `t9_analyze_core_app.txt`; only its tail was seen — `unnecessary_import` for test
  files importing both `package:core` and `package:firebase_auth`; head never inspected).
- How many test files carry that import redundancy.
- Whether inline `const` additions are lint-clean: the run died on a **syntax error**
  (`config_validation_error_screen.dart:82` — `const Colors.white` is invalid Dart), so that
  approach has NO analyze verdict. T-2's design must be proven, not assumed.
- Fresh coverage state: `core_app/coverage/lcov.info` and `packages/core/coverage/lcov.info` are
  ABSENT on disk (only `packages/core_ui/coverage/lcov.info`, dated 2026-09-24) — the floor's
  last receipted pass is cited, not live, so §5 requires a fresh `coverage_floor.ps1` run at GATES.

**Parked WIP:** stash `p27 WIP: unspec'd constitution zero-red (parked per METHOD - spec first)`
= tracked changes under `core_app/` + `packages/core/` plus untracked
`core_app/test/tool/constitution_guard_test.dart`. `git stash pop` ONLY after this spec is
accepted, and only as a starting point that must still prove every §5 floor. The `t9_*` receipts
are deliberately NOT stashed (proof material).

## §2 Territory (single executor — METHOD §8: 1 executor)

**IN (the executor may edit):**

- `core_app/tool/constitution_guard.dart`, `core_app/tool/verify_constitution.dart`
- `core_app/test/tool/**` (guard test, verify test, fixtures)
- `core_app/lib/**` — ONLY the sites named in §3: 10 colour lines, the 6 auth-import files,
  the 2 role sites
- `packages/core/lib/src/auth/**` (type export + platform bindings + capability extension)
- `core_app/test/**` — ONLY where a constructor contract changes (the 4 `DataExportService`
  sites) or an import became redundant by construction (T-3 anomaly)
- `tool_uilib/p27/receipts/**` (new receipts), `tool_uilib/p27/p27_findings.md`
- this spec file (acceptance/status lines only)

**OUT (handoff note if a finding lands here):** everything in §0 rule 5, plus
`packages/core_ui/**`, `functions/**`, `tool_guard/**`, `apps/**`, `DEFERRED.md`.

## §3 Problems → Acceptance → T-x

| T | Problem → what | Acceptance (proof) | Floor |
|---|---|---|---|
| T-1 | Detector precision: 73 → true positives only. Word-bounded patterns over the CODE portion of each line; `// TODO` still read from comments; FBAUTH and the `const` exemption keep their meaning | (a) `flutter test test/tool/constitution_guard_test.dart` green: 5 positive controls FIRE, 6 named false-positives SILENT, live gate 0; (b) `dart run tool/constitution_guard.dart` → `All clean.` exit 0 | 12 tests, 0 fail 0 skip; CLI exit 0 |
| T-2 | 10 genuine colour lines → named constants (design below) | guard COLOR = 0 over lib; `flutter analyze --fatal-infos` 0; **goldens pass with 0 regenerated** | analyze 0; goldens byte-unchanged |
| T-3 | 6 `firebase_auth` imports + 5 `role ==` sites → core owns the SDK bindings and the capability map | `package:firebase_auth` in `core_app/lib` = 0 AND `FirebaseAuth.instance` in `core_app/lib` = 0 AND `role ==` in `core_app/lib` = 0; plain tier green incl. auth/profile/export/gateway/home suites | suites ≥ baseline + 12 |
| T-4 | `verify_constitution.dart` runs everywhere, precise, its own suppression removed | `dart run tool/verify_constitution.dart` exit 0 on Windows; per-law planted fixtures FIRE; real tree silent | exit 0; ≥1 fixture per law (9 laws) |
| T-5 | CLOSE (coordinator, not executor): register §25 red paragraph → 0/0, FIX addendum, CHANGELOG, `LEDGER:p27` block | coordinator's own re-run of every §5 gate | — |

**T-1 design (settled — do not re-derive):** `codePortionOf(trimmedLine)` returns `''` for a
comment-only line, else the text before a `//` that sits outside single/double quotes. Patterns:
`(?<![A-Za-z0-9_])Color\(\s*\d` (literal argument, so the config parser's `Color(parsed)`
passes), `(?<![A-Za-z0-9_])Colors\.`, `(?<![A-Za-z0-9_])print\(` (kills `fingerprint(`). FBAUTH
is checked on code, TODO on the full text (markers live in comments). The guard's existing
"line contains `const`" exemption STAYS — it is the rule's documented line and the Google-blue
exception (`FIX_VERIFICATION.md` §29.5) relies on it. `scanLines`/`scanDirectory` remain
importable so the test is a P2 proof (METHOD §2.2).

**T-2 design (constrained by §1 evidence):** inline `const` inside a const context is OUT —
`const Colors.white` does not parse, and a redundant const risks `unnecessary_const` under
`--fatal-infos` (UNVERIFIED). Per site: a **named private const declaration whose own line
carries `const`** (exactly the guard's exemption) plus a use-site reference to the name.
Sites: `app_config.dart` 81-84 and 468-471 (four named confetti colours, both list sites),
`config_validation_error_screen.dart:82` (neutral on-error white),
`login_screen.dart:357` (`_kGoogleBlue`, keeping the documented §29.5 exception). Every pixel
byte-identical: 0 goldens regenerated (P2: the golden suite must pass untouched).

**T-3 design + anomaly (fail-safe default recorded):** core gains
`createPlatformAuthRepository(...)` and `usePlatformAuthEmulator(...)` — the only places
`FirebaseAuth.instance` may live — plus `export 'package:firebase_auth/firebase_auth.dart'
show FirebaseAuthException, User;` from `auth_repository.dart` (types core's own API already
speaks: `Stream<User?>`, the rethrown exception). core_app drops the 6 imports; bootstrap calls
the two bindings; `DataExportService` takes a `User? Function()` call-time seam (mirrors its
existing `localSummary` seam) — the provider wires `() => repository.currentUser` (sign-out
between provider build and export stays correct) and ALL FIVE construction sites move with it:
the provider plus the 4 test sites (`data_export_service_test` ×1, `profile_repository_test` ×3;
grep-verified this session, no other caller exists). **Anomaly:** the export makes every test file that imports BOTH
`package:core` and `package:firebase_auth` an `unnecessary_import` INFO → fatal (part of the
observed 55). Fail-safe default (D-p27-1): inventory the exact files, remove the now-redundant
`firebase_auth` import from each — types arrive via core, and SDK fakes
(`MockFirebaseAuth`/`MockUser` from `firebase_auth_mocks`, a *different* package) keep working;
if the inventory exceeds 60 files, STOP and escalate to the owner instead of mass-editing.

**T-4 design:** Dart-native search (no external process); import `codePortionOf` from
`constitution_guard.dart` (one source for both tools); resolve the repo root by walking up
(same idea as `pipeline.dart`'s `pipelineRepoRoot`) for `.git/hooks/pre-push`; `stdout.writeln`
everywhere so `// ignore_for_file: avoid_print` is DELETED, not honored. Pattern changes — each
needs a planted fixture proving both directions: Law1 unchanged · Law3 = word-bounded `Colors.`
over code + literal `Color(` · Law4 = `TODO|FIXME` (whole line) + `Placeholder(` + `throw
UnimplementedError` (net STRONGER; bare prose `placeholder`/`REPLACE_ME` dropped as
false-positive classes — D-p27-2) · Law12 = `role ==` byte-identical, fixed in CODE (the core
capability extension) never in the pattern · Law16 = `(API_KEY|SECRET)\s*[:=]\s*['"]`
(env-var names pass, hardcoded literals fail) · Laws 13/18/21/26 unchanged file checks.

## §4 Deliverable format (METHOD §3.5)

1. Findings file `tool_uilib/p27/p27_findings.md`, six-way classification: **Verified** (P1/P2)
   / **Unverified** (mandatory, non-empty) / **Anomalies** (spec-vs-code corrections as evidence
   tables) / **Untested** / **Risks** / **Recommendations** — plus honest residuals and a
   paste-ready ledger block headed `LEDGER:p27`.
2. Receipts: raw gate outputs under `tool_uilib/p27/receipts/` (one file per gate, UTF-8, CRLF,
   exit code recorded inside the file). Red→green pairs for T-1..T-4 — the T-1 red already exists
   (`t9_guard_tdd_red.txt`, `t9_guard_cli_red.txt`); the other reds are captured on the running
   tree BEFORE their fix.
3. `DECISIONS_LOG.md` is coordinator-owned: the executor proposes the D-p27-1 / D-p27-2 text
   (each with its fail-safe default held) inside the findings file; the coordinator writes them.

## §5 Acceptance (measurable floors — every row must hold on the executed tip)

| Gate | Floor |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 0 changed |
| `dart tool/pipeline.dart` (Law 10) | exit 0, `all 3 gates green` |
| `flutter analyze --fatal-infos` (core_app, halal) + `dart analyze` (core, core_ui) | 0 issues, 4/4 |
| core_app plain tier | **≥ 2371** (2359 baseline + 12 guard tests), 0 fail 0 skip |
| packages/core · core_ui · halal_boyz | ≥ 383 · ≥ 411 · ≥ 71, 0 fail |
| functions `lint` · `tsc --noEmit` · `npm test` | 0 · 0 · ≥ 169 pass, 0 fail |
| rules (emulator, `--project demo-carnama`) | firestore ≥ 206 · storage ≥ 8, 0 failed |
| ignore-guard · guard selftest · hygiene · anomaly detectors | PASS · PASS · PASS · exit 0 |
| **NEW** `dart run tool/constitution_guard.dart` | exit 0, prints `All clean.` |
| **NEW** `dart run tool/verify_constitution.dart` | exit 0, prints `AUDIT PASSED` |
| greps over `core_app/lib`: `package:firebase_auth` · `FirebaseAuth.instance` · `role ==` | 0 · 0 · 0 |
| goldens | 0 regenerated, suite green |
| coverage floor `powershell -File tool_fix/b7/coverage_floor.ps1` | exit 0: core ≥ **84.24 %** · core_ui ≥ **92.76 %** · core_app ≥ **86.87 %** (pinned `tool_fix/b7/coverage_baseline.json`) **and** every NEW file 100 % (fleet rule, package allowlist) |
| skip/stub census | 0 `@Skip`/`skip:` added; 0 new `// ignore` anywhere |

**Freeze criterion (numeric — METHOD §7):**
`constitution_guard = 0 AND verify_constitution exit 0 AND every §5 floor met AND zero open
findings from this batch → FREEZE DECLARED (date + tip)` in the ledger. After freeze: fixes are
bug-driven only, no further waves.

## §6 Coordinator protocol (judge → merge → battery → ledger → push)

1. **Judge:** re-run the two new gates + analyze ×4 + format personally; spot-check ≥3 claims —
   (a) open a `BrandColors.of(...)` line in `lib/` and require SILENT, (b) plant
   `print('x');` / `Color(0xFFDEADBE)` in a scratch fixture and require FIRE, (c) run the three
   §5 greps over `core_app/lib`. Verify **tip ≠ base**, verify each red→green pair actually
   failed first (open the receipts), audit forbidden paths (`git status` may show only §2-IN
   files + receipts).
2. **CLOSE:** coordinator writes T-5 (register §25 red paragraph → 0/0, FIX addendum, CHANGELOG,
   `LEDGER:p27`, DECISIONS_LOG entries), commits, re-runs the full battery on the committed tip,
   then — owner permitting — pushes and declares freeze.

## §7 Executor quickstart — the paste-ready prompt (this IS the dispatch text)

```text
p27 EXECUTOR PROMPT — paste into a fresh session (METHOD executor role)

You are the EXECUTOR for batch p27 (WHITE_LABEL_p27_constitution.md) in <repo>
(Carnama monorepo). The coordinator wrote the spec; it is the acceptance contract. You
implement ONE batch, deliver findings, and never touch the ledger. METHOD.md is the
source of truth.

READ FIRST, in this order:
 1. WHITE_LABEL_p27_constitution.md  — the contract (§0 rules, §1 baseline+reds, §2 territory,
    §3 tasks+settled designs, §5 floors)
 2. METHOD.md — the ten laws + seven-step cadence
 3. .clinerules/20-core-app-carnama.md (commands/tags/coverage) + .clinerules/15-tests.md
 4. Receipts you must NOT re-derive (METHOD §2.9): tool_uilib/p26/receipts/t8_merged_*.txt
    (green baseline) and t9_guard_cli_red.txt / t9_guard_tdd_red.txt (the T-1 red proof: 73)

MISSION — scope, nothing else. Take TWO reds to zero:
 R1  dart run tool/constitution_guard.dart     → exit 1 / 73  → target exit 0 + "All clean."
 R2  dart run tool/verify_constitution.dart    → cannot run (external grep, contradictory cwd,
     ignore_for_file) → target exit 0 + "AUDIT PASSED" on Windows
plus their GENUINE code defects only: 10 colour lines (T-2), 6 package:firebase_auth imports
+ 5 role == sites (T-3). Everything else is already green — do not touch it.

THE SEVEN STEPS (METHOD §3), one session, one batch, ≈60–90 min (coverage run alone ≈15–20 min):
 0. SYNC     git -C <repo> rev-parse --short HEAD  → must be 822a4f88
             git status --porcelain → only the spec + tool_uilib/p26/receipts/t9_*.txt
 1. BLOCKER  green BEFORE any edit: dart format --output=none --set-exit-if-changed . (0 changed);
             flutter analyze --fatal-infos (core_app, halal) + dart analyze (core, core_ui) = 0.
             Suites/rules/guards: CITE the t8 receipts, do not re-run them here.
 2. POP      git stash pop   → restores stash@{0} (the coordinator's unspec'd attempt) as a
             STARTING POINT ONLY. First fix its known defect: core_app/lib/app/config/
             config_validation_error_screen.dart:82 is invalid Dart (const Colors.white) —
             apply T-2's named-const design, never an inline const.
 3. WORK     red→green per task, inside §2 territory, receipts to
             tool_uilib/p27/receipts/<gate>.txt (UTF-8, exit code recorded inside):
    T-1 detector precision — §3 design is SETTLED (word-bounded patterns over codePortionOf;
         TODO read from comments, const exemption stays). Proof: constitution_guard_test
         12/12 (5 positive controls FIRE, 6 named false-positives SILENT, live gate 0) + CLI
         "All clean." exit 0.
    T-2 the 10 colour lines → named const declarations (const on the declaration line = the
         guard's own exemption; inline const is forbidden — see step 2). Proof: guard COLOR 0,
         analyze 0, goldens pass with 0 regenerated.
    T-3 core owns the SDK: createPlatformAuthRepository + usePlatformAuthEmulator + the
         User/FirebaseAuthException export; drop the 6 imports; DataExportService call-time
         seam across ALL FIVE construction sites (provider + 4 test sites); role sites move to
         the core capability extension. FIRST: inventory the unnecessary_import list (head of
         t9_analyze_core_app.txt = 55 issues), apply the D-p27-1 fail-safe default (drop the
         redundant firebase_auth imports), ESCALATE if >60 files. Proof: three greps = 0 in
         core_app/lib (package:firebase_auth, FirebaseAuth.instance, role ==).
    T-4 verify_constitution rewrite — Dart-native search, shared codePortionOf, repo-root
         walk-up for .git/hooks, stdout.writeln (the ignore_for_file gets DELETED), the §3
         per-law pattern table (Law4 gains Placeholder( + throw UnimplementedError; Law12
         pattern byte-identical). Red planted fixture per law BEFORE the fix; ≥1 fixture/law
         (9 laws) in the test.
    T-5 = COORDINATOR (ledger/register/CHANGELOG). You propose text only.
 4. GATES    run EVERY §5 row on the working tree, capture outputs: format 0 · pipeline exit 0 ·
    analyze ×4 = 0 · core_app ≥2371 / core ≥383 / core_ui ≥411 / halal ≥71, 0 fail 0 skip ·
    functions 0/0/≥169 · rules ≥206/≥8 · guards PASS · detectors 0 · NEW: constitution_guard
    exit 0 + verify_constitution exit 0 · three greps 0 · goldens 0 regenerated ·
    powershell -File tool_fix/b7/coverage_floor.ps1 exit 0 (core ≥84.24, core_ui ≥92.76,
    core_app ≥86.87, new-files-100%) · 0 new skips, 0 new // ignore.
 5. DELIVER  tool_uilib/p27/p27_findings.md: six-way classification (Verified P1/P2 · Unverified
    mandatory/non-empty · Anomalies · Untested · Risks · Recommendations) + honest residuals +
    paste-ready ledger block headed LEDGER:p27 + proposed DECISIONS_LOG lines (D-p27-1,
    D-p27-2, each with its fail-safe default). Commit locally, subjects like "p27 T-N: ...".
    NEVER push. NEVER edit FIX_VERIFICATION.md / AUDIT_TRIAGE_STAGE3.md.
 6. STOP     — the coordinator judges: re-runs the load-bearing gates personally, spot-checks
    ≥3 claims, verifies tip ≠ base, audits forbidden paths.

HARD RULES (spec §0) — any violation rejects the batch:
 · no // ignore: / // ignore_for_file: / skip / deleted check / deleted pattern / rename to
   dodge a matcher; precision only, each proven by a planted-violation test that still fires
 · every claim is P1 (file:line opened this session) or P2 (a test that fails when the claim
   is false); everything else → non-empty UNVERIFIED
 · forbidden: ledger, register, rules+indexes, pubspecs/lockfiles, generated files,
   apps/halal_boyz/lib/**, .clinerules/** → handoff note, never an edit
 · never end on a red tip: floor unmet → revert to 822a4f88, ledger the blocker, stop
 · one batch, one session; commits only, no push; auth paths fail closed
```




