# FIX-B8 — backend-bundle refresh + generated-vs-shipped parity

**Batch:** `B8` · **Findings:** `F-AUD2-14` (**HIGH**: `apps/halal_boyz/backend/{firestore,storage}.rules` stale vs the `core_app/` templates — missing the t78 POD assignment gate and 137 further lines → over-broad delivery write path in the shipped deployable copy) · `F-AUD2-15` (gradle drift: the shipped `android/app/build.gradle.kts` is hand-mirrored, with an in-file note that regeneration reverts RELEASE-1's signing gate).
**Worktree:** `<repo>-cline-4` (`cline/task-4`). May run ∥ `B7`.

## §0 Laws

0.1 Spec = acceptance contract; **read the audit receipts first** — if any premise no longer holds (file/line/line-count) ⇒ **STOP + report**, never adjust silently. 0.2 Proof law (receipts + P1). 0.3 Red→green: the parity test must fail **before** the refresh. 0.4 Ledger single-writer. 0.5 Territory (§2). 0.6 Never end on red; commit per task. 0.7 **Security direction (fail-closed):** the shipped rules must be **at least as strict** as the templates; where they differ the **stricter** rule wins, and a weaker rule is a defect — never a "fix". 0.8 No new dependencies. 0.9 Git strictly serialized. 0.10 **Never deploy anything**: no `firebase deploy`, no writes to a real project; this batch is files + tests only.

## §1 Research receipts (verified at `2f6d90d`)

| Fact | Evidence |
|---|---|
| Drift sizes: `firestore.rules` = **149-line** diff (137 template-only / 12 shipped-only); `storage.rules` = **17 template-only** lines | `tool_audit/aud2/receipts/c11_rules_diff.txt` |
| Template root: `core_app/firestore.rules`, `core_app/storage.rules`; shipped copy: `apps/halal_boyz/backend/*.rules` | audit C11 table (`aud2_report.md`) |
| 26 of 29 emitted files are byte-identical to shipped; the 3 drifts are the two rules files + the hand-mirrored gradle | `F-AUD2-14`, `F-AUD2-15`; `c11_gradle_diff.txt` (emitted 1199 B stock debug signing vs shipped 4508 B with the RELEASE-1 signing gate + desugaring + "regeneration reverts these lines" notes) |
| No CI/lint check compares the shipped bundle to the templates → the drift was silent | `F-AUD2-15` (parity check absent) |
| The generator emits shells + config: `core_app/tool/whitelabel.dart`; schema-identity tests exist and pass | AUD-2 C11 |

## §2 Territory

**MODIFIED:** `apps/halal_boyz/backend/firestore.rules` · `apps/halal_boyz/backend/storage.rules` · `apps/halal_boyz/android/app/build.gradle.kts` (only the drift lines the receipts name) · `core_app/tool/whitelabel.dart` (only if the template is the correct source of the fix, or to add a regeneration warning).
**CREATED:** the **parity test** (committed): fails when the shipped rules diverge from the templates in any way other than a documented, **stricter** allowlist · receipts in `tool_fix/b8/**`.
**FORBIDDEN:** Dart product logic · `packages/**` · money paths · theme · other clients · `FIX_VERIFICATION.md` · `tool_audit/**` · any deploy command.

## §3 Tasks (each starts red)

**T-1 — the parity test (red first).** A committed test compares `apps/halal_boyz/backend/{firestore,storage}.rules` against `core_app/{firestore,storage}.rules` and fails on any un-allowlisted difference. RED at today's tip. Allowlist entries must name the rule + a one-line reason (e.g. a stricter halal-specific scope).

**T-2 — refresh the shipped bundle.** Bring both rules files up to the templates (including the t78 POD assignment gate), keeping any **stricter** halal clause and allowlisting it. Prove: parity green; the diff is a superset (no weakening); sizes/lines before/after recorded.

**T-3 — gradle drift made safe.** Either (a) mirror the RELEASE-1 signing gate + desugaring into the template so regeneration cannot revert it, or (b) add a generator/CI warning naming the lines. Choose per the receipts, record the rationale; prove with a **temp-dir** regeneration diff.

**T-4 — regeneration dry-run parity.** Run the generator to a **temp directory only**; diff emitted shell/config files against `apps/halal_boyz/**`; record residual drift (expected 0 after T-1…T-3) with command + output receipts.

## §4 Deliverable

`tool_fix/b8/b8_report.md`: T-table (red → green), the rules diff summary (added lines; **weakened lines = 0**), the gradle decision, six-way classification, DECISIONS, UNVERIFIED (the deploy-time effect of the rules is a device/prod item — stays in `RUNBOOK_DEPLOY.md`), DRIFT, paste-ready `## FIX B8` ledger block. Receipts in `tool_fix/b8/`.

## §5 Acceptance

parity test red → green · **0 weakened rules** (diff proof) · regeneration dry-run shows no un-allowlisted drift · format 0 · analyze ×3 0 · suites core_app + core + core_ui + halal green **0 skip** no drop · greps 0 · forbidden paths untouched · no deploy command executed · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery; runs the parity check myself; inspects the rules diff for weakening (the fail-closed direction); merges; appends the ledger block; flips `F-AUD2-14`, `F-AUD2-15` → **CLOSED-WITH-RECEIPT** (with the deploy-day ruleset verification remaining an explicit RUNBOOK item).

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B8 (backend-bundle refresh + generated-vs-shipped parity). Worktree <repo>-cline-4 (branch cline/task-4). May run beside B7.
Read <repo>\FIX_b8_backend_bundle.md IN FULL — binding contract; the fail-closed security direction (§0.7) and the no-deploy rule (§0.10) apply.
1. SYNC (fail-closed): assert branch == cline/task-4; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core + core_ui, format root, suites core + core_ui + core_app + apps/halal_boyz green 0 skip. Red => STOP + report.
2. Read the audit receipts (c11_rules_diff.txt, c11_gradle_diff.txt, aud2_report.md C11) and CONFIRM every premise at HEAD; any mismatch => STOP + report.
3. RED: write the parity test; run it; capture the failure to tool_fix/b8/red_parity.txt.
4. GREEN: T-2 refresh (no weakening), T-3 gradle decision, T-4 dry-run parity; commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
5. PROOF: 0 weakened rules; dry-run output committed; territory + grep evidence; NO deploy command run.
6. REPORT: tool_fix/b8/b8_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
7. COMMIT locally on cline/task-4; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + zero weakened rules + parity test committed + dry-run receipt + nothing uncommitted.
```

