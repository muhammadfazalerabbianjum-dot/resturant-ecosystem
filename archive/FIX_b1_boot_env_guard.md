# FIX-B1 — boot-env-guard (template boot reachability + placeholder project id)

**Batch:** `B1` · **Findings:** `F-AUD2-01` (**CRITICAL**), `F-AUD2-05` (MED), `F-AUD2-06` (LOW/doc) · **Triage authority:** `AUDIT_TRIAGE_STAGE3.md` §2.1/§2.2 · **Owner decisions:** D-1…D-8 ratified 2026-09-24 (register §6).
**Worktree:** `<repo>-worktree` (`cline/task-1`). One executor.

## §0 Laws (inherited — binding)

0.1 **Spec = acceptance contract.** Anything not enumerated here is out of scope; a spec-vs-code conflict is a **STOP + report**, never a silent choice.
0.2 **Proof law.** Every claim carries a receipt (raw command output) + P1 `file:line`. Unverifiable items go to a mandatory UNVERIFIED section.
0.3 **Red→green.** Each task's test is written first and its failure captured (`tool_fix/b1/red_*.txt`) before the fix. No fake greens.
0.4 **Ledger single-writer.** The executor NEVER edits `FIX_VERIFICATION.md`; the coordinator judges and ledgers.
0.5 **Territory exclusivity.** Only §2 paths may change. Scratch files must be deleted before the commit.
0.6 **Never end on red**; commit per phase; nothing left uncommitted.
0.7 **Security fixes preserve fail-closed.** Absence of a secret may never gain a permissive default. Each fix ships with the regression test that would have caught the original defect.
0.8 **No new dependencies.** No `pubspec` additions.
0.9 **Git strictly serialized** (one window at a time mutating this repo — see the Stage-3 coordinator race, register §1).

## §1 Research receipts (verified at `a7a74f5`)

| Fact | Evidence |
|---|---|
| Only `core_app/lib/main.dart:24` passes `loadEnv: true` | `tool_audit/aud2/receipts/c10_dotenv_git_history.txt` |
| `app_bootstrap.dart:441-443` calls **non-optional** `dotenv.load()` | AUD-2 P1 |
| `.env` added `6c13dfa`, **deleted `4137b1d`** (CI-2); never a declared asset (`core_app/pubspec.yaml:106-107` = `assets/` only) | `c10_dotenv_git_history.txt` |
| `flutter_dotenv 5.2.1` → bundle miss + `isOptional:false` ⇒ **`FileNotFoundError`** | `c10_dotenv_receipt.txt` |
| Runtime proof (no mocks): `AUD2_PROOF threw=true error=FileNotFoundError` | `c10_dotenv_runtime_probe.txt` |
| Consequence: throw → `handleBootFailure` (`:724-731`) → the `runApp` at the same `try`'s end (`:723`) **never runs** | AUD-2 §0 |
| Shells unaffected: `loadEnv` defaults `false` (`app_bootstrap.dart:76`) | AUD-2 §0 |
| Template config carries `firebase.projectId = REPLACE_ME_…`, which wins the options merge | AUD-2 §3.4 |
| Stripe release guard is a debug-only `assert` while its comment claims "fail fast in production" | `F-AUD2-06` |

## §2 Territory

**MODIFIED:** `core_app/lib/main.dart` · `core_app/lib/app/app_bootstrap.dart` · `core_app/pubspec.yaml` (assets section only) · `core_app/assets/client_config.json` (projectId handling only) · the Stripe bootstrap comment.
**CREATED:** `core_app/.env.example` (documented, **no secret values that enable anything**) · tests under `core_app/test/**` · receipts under `tool_fix/b1/**`.
**FORBIDDEN:** `core_app/functions/**` · `apps/**` · `packages/**` · any theme file · `FIX_VERIFICATION.md` · `tool_audit/**` · any dependency addition.

## §3 Tasks (each starts red)

**T-1 — boot with no `.env` (the CRITICAL).** Write a test that boots the template's env step with `loadEnv: true` and no `.env` present and asserts **graceful degradation, no throw**. RED today (`FileNotFoundError`). GREEN = optional load + explicit absence handling that documents precedence (`.env` → `--dart-define` → config) and fabricates **no** secret. Fail-closed proof: a test showing an absent security key does not become a permissive default.

**T-2 — placeholder projectId guard.** A `REPLACE_ME_*` projectId must fail **clearly and actionably** naming the key (or be excluded from the options merge), never a silent Firebase init against a bogus project. Test asserts the placeholder is caught and the message names the key.

**T-3 — shell non-regression.** Test asserting a bootstrap built with `loadEnv: false` never touches dotenv; `dart analyze` clean. Proves zero blast radius for shipping clients (`apps/halal_boyz`).

**T-4 — doc truth (`F-AUD2-06`).** Either correct the comment to what the code does (debug `assert`) **or** promote the guard to a release-visible check — pick the one matching intent and record the choice. The comment may not overclaim in either direction.

## §4 Deliverable

`tool_fix/b1/b1_report.md`: T-table (red receipt → green receipt), six-way classification, DECISIONS-NEEDED-FROM-OWNER, UNVERIFIED (non-empty allowed), DRIFT, paste-ready `## FIX B1` ledger block. Raw receipts in `tool_fix/b1/`.

## §5 Acceptance (all green, on the committed tip)

red→green receipt per T · `flutter analyze --fatal-infos` (core_app) exit 0 · `dart analyze` (core, core_ui) exit 0 · `dart format --set-exit-if-changed .` 0 changed · suites core_app + core + core_ui green **0 skip**, no drop · T-1/T-2 boot proofs present · T-3 shells-unaffected · greps 0 (`TODO|FIXME|@Skip|skip:|expect(true`) · forbidden paths untouched (git proof) · no new dependency · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery on the committed tip; spot-checks ≥3 (the T-1 red receipt predates the fix; T-2's message names the key; the pubspec/assets diff is minimal); merges to main; appends the ledger block; flips `F-AUD2-01`, `F-AUD2-05`, `F-AUD2-06` → **CLOSED-WITH-RECEIPT** in `AUDIT_TRIAGE_STAGE3.md`.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B1 (boot-env-guard), worktree <repo>-worktree (branch cline/task-1).
Read <repo>\FIX_b1_boot_env_guard.md IN FULL — binding contract.
1. SYNC (fail-closed): assert `git -C <repo>-worktree rev-parse --abbrev-ref HEAD` == cline/task-1; git merge main; flutter pub get in core_app; BLOCKER gate: analyze core_app + core/core_ui, format (root), suites core_app/core/core_ui all green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: write T-1..T-3 tests first; capture failures to tool_fix/b1/red_*.txt.
3. GREEN: implement T-1..T-4 per §3, one commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. FORBIDDEN + territory checks of §2 (git diff --name-only proof).
5. REPORT: tool_fix/b1/b1_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-1 (one commit per task + a receipts commit); re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + receipts committed + nothing uncommitted + no forbidden path touched.
```

