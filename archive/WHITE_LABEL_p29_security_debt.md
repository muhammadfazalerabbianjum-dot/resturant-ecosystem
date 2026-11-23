# WHITE_LABEL_p29 — security debt closure + LIVE rules battery

**Scope, one line:** close the three constitution-declared debts against the code that ACTUALLY
exists at HEAD (two of the three debt statements are stale — §1 premise corrections) and make
the rules battery run LIVE (kills p27 U1/U3), with fail-closed auth/security behaviour proven
red→green. ONE executor, serial (emulator gates are serial).

Spec file = the acceptance contract (METHOD §1). Coordinator-written 2026-10-01 after premises
were verified against HEAD per METHOD §2.1/§2.4 (code at HEAD wins). Execution starts only
once this file is accepted; the executor works inside it, never around it.

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

## §1 Baseline + blocker gate + premise corrections

**Tip:** p29 executes AFTER p28 merges (serial program). **SYNC gate:** in <repo> verify
(a) `git merge-base --is-ancestor b445ff35 HEAD`, (b) `git log --merges --oneline -2` shows the
`p28/lane-a` and `p28/lane-b` merges, (c) `git status` clean. Then: `dart format --output=none
--set-exit-if-changed .` = 0 and analyze ×4 = 0 live (cheap gates, re-run); suites / functions /
guards / constitution gates / **coverage_floor** = CITE the coordinator's p28-close battery
receipts (named in the dispatch prompt), do not re-derive them at SYNC. Full §5 battery re-runs
live at GATES.

**Premise corrections (verified 2026-10-01 in the primary tree — code at HEAD is the source of
truth, METHOD law 4. The debt texts in `.clinerules/20-core-app-carnama.md` are STALE; the
constitution correction is coordinator work at program close):**

| # | Debt as written | Code at HEAD (P1) | Consequence |
|---|---|---|---|
| PC1 | "owner email is hardcoded at line 11 of `firestore.rules`" | `firestore.rules:11` = strongAppCheck comment; **zero literal emails in either rules file** (regex sweep 2026-10-01); `isOwner()` already does `exists(settings/ownerInfo) && get(...).ownerEmail == request.auth.token.email` (`firestore.rules:47-51`, `staging.firestore.rules:9-12`); absent doc → `exists()` false → DENY = already fail-closed; migration `functions/src/migrations/v003__seed_settings_owner_info.ts` seeds the doc | T-1 reframed: the email move is DONE; remaining work = prove it with NEW tests + fix the REAL red (PC4) + seed note |
| PC2 | "Cloud Functions are on the deprecated v1 API and must move to v2" | every export in `core_app/functions/src/**` uses `firebase-functions/v2/*` (`onCall`/`onRequest`/`onSchedule`/`onDocument*`/`onMessagePublished`); only root import = `logger` (`index.ts:3`); dep `firebase-functions ^5.0.0`; recursive grep `firebase-functions/v1`, `functions.https`, `= functions.` → **0 hits** | T-3 reframed: verification + receipt, not migration (unless the executor's inventory finds a remnant → then fix it red→green in-territory) |
| PC3 | "`calculateTax` at functions/src/index.ts ~:37 trusts client `subtotalCents`" | line number is stale (`calculateTax` = `index.ts:147`, schema `:141`), premise **HOLDS**: `subtotalCents` from `request.data` is the tax base (`:150`,`:160`); caller `core_app/lib/features/checkout/domain/checkout_service.dart:322` | T-2 proceeds as ordered |
| PC4 | (undeclared) staging parity | `staging.firestore.rules` = **259 lines** vs `firestore.rules` = **811**; staging LACKS the App Check family (`hasAppId`/`hasAppCheckToken`/`strongAppCheckEnabled`/`isAppVerified`), `isAnonymous`, and 665 changed lines total (`git diff --no-index`, P1 this session) | **This is T-1's genuine RED** — the staging battery cannot be green at HEAD |

**BLOCKER (green BEFORE any edit):** format 0 + analyze ×4 = 0 live; everything else cited per
SYNC gate above. RED proofs for T-1/T-2 are captured by the executor BEFORE editing (§3) — the
staging-battery run at HEAD is the T-1 red; the tampered-subtotal test at HEAD is the T-2 red.

## §2 Territory (ONE executor, serial; everything else = handoff note)

- **IN:** `core_app/firestore.rules`, `core_app/staging.firestore.rules`,
  `core_app/functions/**` (src + tests + fixtures), `core_app/test/rules/**` (harness +
  fixtures), `core_app/test/functions/**`.
- **Territory override (explicit, batch-specific per §0 rule 1):** §0 rule 5's ban on
  `firestore.rules` / `staging.firestore.rules` yields to this §2 for p29 — the coordinator
  allocates exactly these two files to this batch. Every other rule-5 entry stays forbidden.
- **FORBIDDEN hard:** `firestore.indexes.json` — no query changes are planned; a needed index =
  STOP and escalate, never edit. Plus all remaining §0 rule 5 files, `tool_fix/b7/**` (p28's
  pinned floor machinery), `core_app/lib/**`, `packages/**`, `apps/**` (the halal backend has
  its own rules — out of scope; note findings only).
- **Worktree (serial, one lane):**
  `cd <repo>` → `git worktree add ..\resturant-p29 -b p29/security-debt` →
  `flutter pub get` in the worktree. **No `.env` exists in the primary tree** (only the tracked
  `core_app/.env.example`) — nothing to copy; do not create `.env`.
- **Receipts:** `tool_uilib/p29/receipts/<name>.txt`, exit code recorded inside each file.

## §3 Problems → Acceptance → T-x (serial order — one executor, emulator gates never overlap)

| T | Problem (red) | Task + acceptance (proof required) | Floor |
|---|---|---|---|
| T-1 | PC4 staging parity broken + owner fail-closed behaviour unproven (PC1) | **(a) RED FIRST:** run the firestore battery against `staging.firestore.rules` at HEAD — parameterize `RULES_PATH` in `core_app/test/rules/firestore_rules_test.js` via an env var (harness edit is in-territory) — and capture the failing output BEFORE editing any rules file; expected: failures from the missing helper functions (PC4). **(b)** Bring `staging.firestore.rules` into Law-18 parity: byte-identical mirror of `firestore.rules` (no intentional env deltas exist at HEAD — P1 diff). `firestore.rules` is the reference; NEVER weaken prod to reach parity. **(c)** NEW battery tests, red→green: `settings/ownerInfo` present with matching auth-token email → ALLOW; doc absent → DENY (fail-closed); the battery must pass against BOTH files. **(d)** Seed note: confirm `functions/src/migrations/v003__seed_settings_owner_info.ts` seeds the doc and record the seed requirement in findings; if `core_app/tool/seed*.js` lacks it → handoff note only (`tool/` is out of territory). **GREEN (LIVE)** from `core_app`, after `npm ci` (firebase-tools 15.15.0): `firebase emulators:exec --only firestore,auth,functions --project demo-carnama "node test/rules/firestore_rules_test.js"` → **≥206 pass, 0 fail** (CI parity = `npm run test:rules`); `firebase emulators:exec --only firestore,storage --project demo-carnama "node test/rules/storage_rules_test.js"` → **≥8 pass, 0 fail**; staging-parameterized run → **≥206 pass, 0 fail**. All three receipted | firestore ≥206 · storage ≥8 · staging ≥206 · 0 fail |
| T-2 | `calculateTax` trusts client `subtotalCents` (PC3: `index.ts:150,160`; caller `checkout_service.dart:322`) | **RED FIRST:** tampered-subtotal test in `core_app/functions/test/` — a client `subtotalCents` that disagrees with the server-recomputed base must NOT yield tax computed on the tampered value; capture the failing test BEFORE the fix (at HEAD the tampered base wins — that IS the red). **Fix:** recompute/validate the subtotal from authoritative server state (the authenticated user's cart/menu snapshot in Firestore) before `computeTaxCents`; mismatch → `failed-precondition` (fail-closed); integer cents only, no float math, no new rounding rule (money sanctuary). The existing payload must keep working: prefer an auth-scoped cart lookup; if the payload would need a NEW Dart-side field → STOP, escalate as handoff (Law 1/5) — `core_app/lib/**` is out of territory. **GREEN:** `npm run lint` 0 · `npx tsc --noEmit` 0 · `npm test` ≥ **169 + new** pass, 0 fail; chosen contract documented in findings | lint 0 · tsc 0 · ≥169+new, 0 fail |
| T-3 | Debt text says "v1 API"; HEAD is already v2 (PC2) | **Verification, not migration.** P2 inventory receipt: recursive grep over `core_app/functions/src/**` for `firebase-functions/v1`, `= functions.`, `functions.https|firestore|scheduler|pubsub` → must be 0 hits; then fresh `npm run lint` 0 · `npx tsc --noEmit` 0 · `npm test` green (build regenerates `lib/`, which is untracked — never hand-edit it). If, and only if, the inventory finds a real v1 remnant → fix it red→green in-territory. Findings carry the PC2 correction text for the constitution update (coordinator, program close). **Deploy is NEVER an executor gate** — actual deploy = owner step, staging first (Law 18) | inventory 0 · lint/tsc/test green |
| T-4 | p27 U3 open: emulator-tier suites never run | Under `firebase emulators:exec --only firestore,auth,functions --project demo-carnama` (from `core_app`): `flutter test --tags=needs-emulator` and `flutter test --tags=nightly` — record exact counts + exit codes per run. e2e: `flutter devices` FIRST — a device/emulator present → run the e2e suite for real; absent → **UNVERIFIED** entry in findings with that exact reason and the `flutter devices` output as receipt. Never skip, never delete or re-tag a test, never fake a count; if a tag matches 0 tests, record "0 tests matched" with the grep evidence | both tier runs receipted; U3 closed or honestly UNVERIFIED |

## §4 Deliverable format (six-way classification, METHOD §2.1 + §3.5)

`tool_uilib/p29/p29_findings.md`: (1) **Verified** P1/P2 table · (2) **Unverified** mandatory
+ non-empty · (3) **Anomalies** (PC1–PC4 evidence tables live here) · (4) **Untested** ·
(5) **Risks** · (6) **Recommendations**; then honest residuals, receipts index, and a
paste-ready ledger block headed `LEDGER:p29` (the coordinator is the single ledger writer),
including proposed constitution-correction text for PC1/PC2. Commits local only, subjects
`p29 T-N: ...`. NEVER push. NEVER edit `FIX_VERIFICATION.md`, `AUDIT_TRIAGE_STAGE3.md`,
`DECISIONS_LOG.md`, `firestore.indexes.json`.

## §5 Acceptance (measurable floors — every row green on the executed tip)

| Row | Floor | How measured |
|---|---|---|
| rules LIVE (prod) | `firebase emulators:exec --only firestore,auth,functions --project demo-carnama "node test/rules/firestore_rules_test.js"` → **≥206 pass, 0 fail** | live emulator run (CI parity: `npm run test:rules`) |
| rules LIVE (storage) | `firebase emulators:exec --only firestore,storage --project demo-carnama "node test/rules/storage_rules_test.js"` → **≥8 pass, 0 fail** | live emulator run |
| rules LIVE (staging) | staging-parameterized battery → **≥206 pass, 0 fail**; staging byte-identical to prod (`git diff --no-index` empty) | live run + git |
| ownerInfo tests | NEW: doc present → ALLOW, doc absent → DENY, both pass against BOTH rules files | battery |
| functions | lint 0 · tsc 0 · `npm test` ≥ **169 + new** pass, 0 fail | live |
| T-3 inventory | 0 v1 exports (grep receipt) | P2 |
| U3 tiers | needs-emulator + nightly runs receipted with exact counts; e2e run or UNVERIFIED with the exact device-absence reason | receipts |
| format | `dart format --output=none --set-exit-if-changed .` 0 changed | live |
| pipeline | `dart tool/pipeline.dart` exit 0 | live |
| analyze | 4/4 = 0 issues | live |
| suites | core_app ≥ **2393** · core ≥ **387** (p28 raised it) · core_ui ≥ **411** · halal ≥ **71** — 0 fail **0 skip** | live (default tier) |
| guards + detectors | ignore-guard PASS (35 probes) · selftest PASS · hygiene PASS · detectors exit 0 | live |
| greps | `package:firebase_auth` 0 · `FirebaseAuth.instance` 0 · `role ==` 0 over `core_app/lib` | live |
| constitution gates | both exit 0 (`All clean.` / `AUDIT PASSED`) | live |
| coverage floor (p28 row must NOT regress) | `powershell -File tool_fix/b7/coverage_floor.ps1` EXIT 0 | live, fresh |
| census | 0 new `@Skip`/`skip:`, 0 new `ignore_for_file`, 0 new `// ignore` | live |
| goldens | 0 regenerated (`git diff --name-only <p28-tip>..HEAD -- '*.png'` = empty) | git |

**p29 completion criterion (numeric):** every row green → `LEDGER:p29` proposed; FREEZE is
declared only at program close (orchestrator STEP 3) when both batches' rows are green and
zero findings remain open.

## §6 Coordinator protocol (judge → merge → battery → ledger → hold push)

1. **Judge personally (METHOD §6):** re-run the LIVE rules wrapper yourself (never trust a
   self-report of an emulator gate); spot-check ≥3 claims — (a) open the T-1 staging RED
   receipt and confirm the battery genuinely failed at HEAD before the parity edit, (b) open
   the T-2 tampered-subtotal RED receipt and confirm it failed before the guard, (c) re-run
   the v1 grep yourself; verify tip ≠ base; audit forbidden paths —
   `git diff --name-only <p28-merge-tip>..HEAD` must show 0 hits in `firestore.indexes.json`,
   `core_app/lib/**`, `packages/**`, `apps/**`, lockfiles, `.clinerules/**`, `tool_fix/b7/**`.
2. **Merge:** `git merge --no-ff p29/security-debt` in the primary tree.
3. **Battery on the merged tip:** every §5 row live (the p28 coverage-floor row included).
4. **Ledger:** single writer = coordinator at program close (with LEDGER:p28); executor only
   proposes the `LEDGER:p29` block. Constitution corrections for PC1/PC2 are coordinator text.
5. **Never push. Deploy is owner-only (staging first, Law 18). Never end on a red tip.**
6. **LCOV sequencing caution (learned during the p28 judge):** a single-file
   `flutter test --coverage <file>` run OVERWRITES `coverage/lcov.info` with a partial
   measurement — it clobbered the floor's full-fleet lcov during the p28 battery and made a
   legitimate `-ReuseCoverage` re-check fail (7.46 % artifact). Always run `coverage_floor.ps1`
   (fresh) AFTER any single-file `--coverage` invocation, and treat any `-ReuseCoverage`
   failure as suspect until the lcov's mtime/record-count is confirmed to be the floor's own.

## §7 Executor quickstart — the paste-ready prompt (this IS the dispatch text)

```text
p29 EXECUTOR PROMPT — paste into a fresh session (METHOD executor role)

You are the EXECUTOR for batch p29 (WHITE_LABEL_p29_security_debt.md) — ONE executor, serial —
in the <repo> monorepo (Carnama). The coordinator wrote the spec; it IS the acceptance
contract. You deliver findings + a paste-ready ledger block and never touch the ledger.
METHOD.md is the source of truth.

READ FIRST, in order:
 1. WHITE_LABEL_p29_security_debt.md — §0 (binding), §1 premise corrections PC1-PC4 (TWO of
    the three constitution-declared debts are STALE at HEAD: trust the evidence tables, not
    the debt prose), §2 territory (incl. the explicit rules-file override), §3 tasks, §5 floors
 2. METHOD.md — ten laws + seven-step cadence
 3. .clinerules/15-tests.md + .clinerules/20-core-app-carnama.md (money/security laws)
 4. .github/workflows/carnama_ci.yml — firestore-rules job = the real gate command
 5. tool_uilib/p27/p27_findings.md §2 U1/U3 (the residuals you exist to kill)

SETUP (only after p28 has merged — §1 SYNC gate):
  cd <repo>
  git worktree add ..\resturant-p29 -b p29/security-debt
  cd ..\resturant-p29
  flutter pub get   # no .env exists — only tracked core_app/.env.example; do not create one

MISSION — §2-IN territory only (firestore.rules + staging.firestore.rules + functions/** +
rules-test fixtures):
  T-1 rules: RED = staging battery at HEAD (must fail — PC4) captured BEFORE any edit;
     then staging byte-parity, ownerInfo tests present->ALLOW / absent->DENY on BOTH files,
     seed note. GREEN = LIVE emulators:exec wrapper: firestore >=206, storage >=8,
     staging >=206, 0 fail (exact commands in §3/§5).
  T-2 calculateTax guard: RED = tampered-subtotal rejection test first; GREEN = lint 0,
     tsc 0, npm test >=169+new 0 fail. Existing payload keeps working; a needed Dart-side
     change = STOP + escalate, never an edit outside territory.
  T-3 v1->v2 = verification at HEAD (PC2): inventory grep 0 hits + fresh lint/tsc/test green;
     real remnant found -> fix red->green in-territory. Deploy is NEVER your step.
  T-4 close U3: needs-emulator + nightly under the emulators:exec wrapper with exact counts;
     e2e: flutter devices FIRST, device absent -> UNVERIFIED with that exact reason.
     Never skip, never re-tag, never fake a count.

SEVEN STEPS (METHOD §3), one session, serial (emulator gates never overlap):
 0. SYNC    §1 gate (b445ff35 ancestor + p28 merges + clean status); create worktree
 1. BLOCKER format 0 + analyze x4 = 0 live; other rows CITE the p28-close receipts (§1)
 2. WORK    red->green per T in order; receipts to tool_uilib/p29/receipts/<name>.txt
            (UTF-8, exit code recorded inside each file)
 3. GATES   every §5 row live: rules LIVE >=206 / >=8 / staging >=206 · functions
     lint 0 tsc 0 >=169+new · format 0 · pipeline 0 · analyze 4/4 · suites >= p28 counts
     0 fail 0 skip · guards+detectors · greps 0/0/0 · both constitution gates 0 ·
     coverage_floor EXIT 0 (p28 row, must not regress) · census 0 · goldens 0
 4. DELIVER tool_uilib/p29/p29_findings.md (six-way §4) + paste-ready LEDGER:p29 block +
     PC1/PC2 constitution-correction text. Commits local, subjects `p29 T-N: ...`.
     NEVER push. NEVER edit firestore.indexes.json, FIX_VERIFICATION.md,
     AUDIT_TRIAGE_STAGE3.md, DECISIONS_LOG.md, or anything outside §2-IN.
 5. STOP    — the coordinator judges: re-runs the LIVE rules wrapper personally, opens your
     red receipts, spot-checks >=3 claims, audits forbidden paths.

HARD RULES (spec §0 + §2) — any violation rejects the batch:
 · no // ignore: / // ignore_for_file: / skip / deleted check / deleted pattern / matcher
   dodge; a detector may only become MORE precise with a planted-violation test proving it
 · every claim P1 or P2; everything else -> mandatory non-empty UNVERIFIED
 · red->green: the failing receipt (staging battery / tampered subtotal) MUST exist before
   the corresponding fix
 · forbidden: firestore.indexes.json (needed index = escalate), every rule-5 file not
   allocated by §2, tool_fix/b7/**, core_app/lib/**, packages/**, apps/**
 · never end on a red tip: revert to the last green state, record the blocker, stop
 · one batch one session; commits only, no push; auth/security paths fail closed;
   deploy (staging first, Law 18) is an owner step you never run
```
