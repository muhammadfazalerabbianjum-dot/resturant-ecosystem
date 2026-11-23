# FIX-B9 — halal theme tokens + brand confetti (p16.5)

**Batch:** `B9` · **Findings:** `F-AUD2-07` (MED), `F-AUD2-10` (MED) · **Triage authority:** `AUDIT_TRIAGE_STAGE3.md` §2.2 · **Owner decision D-7:** this batch runs **before** `p16` so the owner's first-look visual review judges the best available version.
**Worktree:** `<repo>-cline-2` (`cline/task-2`). One executor.

## §0 Laws (inherited — binding)

0.1 Spec = acceptance contract; a spec-vs-code conflict is **STOP + report**.
0.2 Proof law (receipts + P1 `file:line`); UNVERIFIED section mandatory if non-empty.
0.3 Red→green per task, receipt captured first.
0.4 Ledger single-writer (executor never edits `FIX_VERIFICATION.md`).
0.5 Territory exclusivity (§2); scratch deleted before commit.
0.6 Never end on red; commit per phase.
0.7 **Guards are not negotiable:** `core_app/test/ui/accessibility_guidelines_test.dart` reads **both** client configs' theme and asserts the AA-passing palette. It may not be edited to accommodate a hue — the hue must pass.
0.8 No new dependencies.
0.9 Git strictly serialized.

## §1 Research receipts (verified at `a7a74f5`)

| Fact | Evidence |
|---|---|
| Halal config leaves engine-surfaced keys **UNSET**: `theme.components.input.*`, `theme.chip.radius`, `theme.shape.smallRadius`, `theme.background.*` | `tool_audit/aud2/receipts/c6_*` (F-AUD2-07) |
| Those keys DO have readers in the engine (attach-when-set component themes) | `packages/core_ui/lib/src/theme/app_theme.dart:587-617` (AUD-2 §2.1) |
| `theme.confettiOverlay.colors` is **set** but byte-identical to the in-code generic default → "configured but not branded" | F-AUD2-10 |
| The AA guard reads both configs | `core_app/test/ui/accessibility_guidelines_test.dart:203-232` |
| Halal's live brand values are already in the file (maroon `0xFF900000` family, dark nav neutrals) — **use these, invent nothing** | `apps/halal_boyz/assets/client_config.json` |

## §2 Territory

**MODIFIED:** `apps/halal_boyz/assets/client_config.json` **only** (plus, if the shell has a golden lane, the halal goldens re-captured via the documented flow and packed for owner review).
**CREATED:** tests under `apps/halal_boyz/test/**` · receipts + visual pack under `tool_fix/b9/**`.
**FORBIDDEN:** `core_app/**` (including its tests — the AA guard is read-only) · `packages/**` · any theme file · the other client's config · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — config completeness (red→green).** Test driven by the **engine's own reader list**: every theme key the engine surfaces for branding must be SET for halal, and must differ from the generic default where branding is promised. RED today (input/chip/smallRadius/background unset). GREEN = the four families set from the client's own palette.

**T-2 — brand confetti (red→green).** Assert `theme.confettiOverlay.colors` ≠ the in-code default and equals the client's declared brand palette. RED today (byte-identical to the default).

**T-3 — AA guard stays green (no edits).** Run `core_app`'s accessibility suite against the new config; every chosen hue/surface pair must pass. If a hue fails, change the **hue**, never the test.

**T-4 — schema + shell parity.** Config schema-identity/validation tests green (fail-closed for unknown keys); halal shell suite + `flutter analyze` green **0 skip**; the generator dry-run's emitted config still matches schema.

**T-5 — visual pack for the owner (D-7).** Before/after captures of the affected surfaces (input fields, chips, card corners, backdrop/background, order-success confetti) into `tool_fix/b9/visual_review/` with an index. This pack is the first-look material for the owner's `p16` review — the executor claims nothing about looks; the verdict is the owner's.

## §4 Deliverable

`tool_fix/b9/b9_report.md`: T-table (red → green receipts), the visual-pack index, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B9` ledger block. Receipts in `tool_fix/b9/`.

## §5 Acceptance

red→green per T · `flutter analyze --fatal-infos` for `apps/halal_boyz` + core_app + core + core_ui exit 0 · format 0 · suites (halal, core_app, core, core_ui) green **0 skip** no drop · config schema + validation green · AA guard green **unmodified** (git proof: zero diff in `core_app/test/ui/**`) · greps 0 · forbidden paths untouched · visual pack complete · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery; verifies the AA guard file is byte-unchanged; walks the owner through the visual pack (**appeal verdict = owner's**); merges to main; appends the ledger block; flips `F-AUD2-07`, `F-AUD2-10` → **CLOSED-WITH-RECEIPT** in `AUDIT_TRIAGE_STAGE3.md`.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B9 (halal theme tokens + brand confetti / p16.5), worktree <repo>-cline-2 (branch cline/task-2).
Read <repo>\FIX_b9_halal_theme_tokens.md IN FULL — binding contract.
1. SYNC (fail-closed): assert `git -C <repo>-cline-2 rev-parse --abbrev-ref HEAD` == cline/task-2; git merge main; flutter pub get; BLOCKER gate: analyze (apps/halal_boyz + core_app + core + core_ui), format root, suites green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: write T-1/T-2 tests first; capture failures to tool_fix/b9/red_*.txt.
3. GREEN: set the missing theme families + the branded confetti palette in apps/halal_boyz/assets/client_config.json ONLY, using the file's own existing brand values; dart format; analyze 0; suites green 0 skip.
4. T-3: the AA guard must stay GREEN with ZERO edits to core_app/test/ui/** (prove with git diff).
5. T-4 schema/generator parity; T-5 capture the visual pack into tool_fix/b9/visual_review/ with an index.
6. REPORT: tool_fix/b9/b9_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
7. COMMIT locally on cline/task-2; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + visual pack ready for the owner + receipts committed + nothing uncommitted + zero edits outside apps/halal_boyz/assets/client_config.json (plus your own tests/receipts).
```

