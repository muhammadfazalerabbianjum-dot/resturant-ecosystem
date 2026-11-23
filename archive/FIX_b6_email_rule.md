# FIX-B6 — PRIV-2: ONE email rule shared by form validation and PII redaction

**Batch:** `B6` · **Finding:** `AUD1-06` (MED, class 3 — divergent twins) · **Authority:** `AUDIT_TRIAGE_STAGE3.md` §2.2/§3.
**Worktree:** `<repo>-cline-4` (`cline/task-4`). May run ∥ `B3b`.

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`). 0.3 Red→green per task, receipt **before** the fix. 0.4 Ledger single-writer. 0.5 Territory exclusivity (§2) + the §9 standing rule (unlisted call site ⇒ STOP). 0.6 Never end on red; commit per task. 0.7 **Privacy direction (fail-closed):** redaction must be a **superset** of validation — **anything the app accepts as an email MUST be redactable in logs**. Over-redaction is acceptable and documented; **under-redaction is a defect.** Where a rule change would also affect log triage, the trade-off is stated explicitly, never silent. 0.8 No new dependencies. 0.9 Git strictly serialized.

## §1 Research receipts (verified at `2a90cb6`)

| Fact | Evidence |
|---|---|
| **Client validation is a substring check** — `a@b` passes: `validator: (v) => (v == null \|\| !v.contains('@'))` | `core_app/lib/features/auth/presentation/login_screen.dart:167`, `signup_screen.dart:147` |
| **The scrubber requires a dotted TLD**, so `a@b` is NOT redacted: `RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')` | `packages/core/lib/src/error_logger/pii_scrubber.dart:14` (fn at `:10`); `tool_audit/aud1/receipts/c3_parity_run.log` TWIN-4 → `email a@b here` = **scrubbed=false**, `email a@b.co here` = scrubbed=true |
| Scrubber consumers (single canonical path since UX-3/W9.11) | `packages/core/lib/src/error_logger/logger_service.dart:88,118,119`; `RedactedError` at `pii_scrubber.dart:38` |
| Phone rows in the same matrix: `555-123-4567` ✅, `+971501234567` ✅, **`1234567` (7 digits) not redacted** | TWIN-4 rows |
| No phone validator exists in the app (reservation fields only check emptiness) | `reservation_screen.dart:282,295` |

## §2 Territory

**MODIFIED:** `packages/core/lib/src/error_logger/pii_scrubber.dart` (patterns + the shared rule export) · `core_app/lib/features/auth/presentation/login_screen.dart` and `signup_screen.dart` (**validators only**).
**CREATED:** the shared rule (either exported from `pii_scrubber.dart` or a small `packages/core/lib/src/validation/email_rule.dart`) · tests under `packages/core/test/**` and `core_app/test/**` · receipts in `tool_fix/b6/**`.
**FORBIDDEN:** auth services/logic · any Firebase Auth call · password rules · theme · configs · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — one rule, two consumers, one invariant.** Define the email rule **once**: a permissive `emailLikePattern` used for redaction and a stricter `isValidEmail` used by forms, with the documented invariant **`isValidEmail(x) ⇒ scrubPii(x)` removes it**.

**T-2 — the invariant test (the red).** A corpus of form-**accepted** addresses — `a@b`, `a@b.co`, `first.last+tag@sub.domain.co.uk`, `x@y.z`, plus the app's real test fixtures — must **all** be redacted after the fix. RED today: `a@b` survives.

**T-3 — forms delegate, reject set unchanged.** Both auth validators call `isValidEmail`; real addresses are still accepted and the reject set (no `@`, empty, whitespace-only) is still rejected — asserted.

**T-4 — phone policy recorded (no silent change).** Either keep the current phone rules or extend them — either way the choice and its triage trade-off are **documented**, and 7-digit sequences are added to the matrix as a recorded row.

**T-5 — no weakening.** Existing scrubber tests are byte-unchanged or strengthened (git diff proof); assertion count does not decrease.

## §4 Deliverable

`tool_fix/b6/b6_report.md`: T-table (red → green), the matrix before/after (incl. the phone rows), the invariant statement, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B6` ledger block. Receipts in `tool_fix/b6/`.

## §5 Acceptance

red→green per T · `dart analyze` core 0 · `flutter analyze --fatal-infos` core_app + core_ui 0 · format 0 · suites core + core_ui + core_app green **0 skip** no drop · the invariant corpus fully redacted · existing scrubber tests not weakened · greps 0 · forbidden paths untouched · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery; spot-checks ≥3 (the corpus `a@b` row now redacted; both validators delegate; no scrubber test modified); merges; appends the ledger block; flips `AUD1-06` → **CLOSED-WITH-RECEIPT** and re-runs the C3 TWIN-4 detector.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B6 (PRIV-2: one email rule shared by validation and PII redaction). Worktree <repo>-cline-4 (branch cline/task-4). May run beside B3b.
Read <repo>\FIX_b6_email_rule.md IN FULL — binding contract; privacy direction (§0.7: redaction ⊇ validation) applies.
1. SYNC (fail-closed): assert branch == cline/task-4; git merge main; flutter pub get; BLOCKER gate: analyze core/core_ui/core_app, format root, suites core/core_ui/core_app green 0 skip. Red => STOP + report.
2. RED: write the invariant corpus test first (tool_fix/b6/red_invariant.txt) — expect 'a@b' to survive scrubPii today.
3. GREEN: implement T-1..T-5 (one rule in packages/core, both validators delegate, phone policy recorded); commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. PROOF: existing scrubber tests unchanged (git diff); assertion count not reduced; territory + grep evidence.
5. REPORT: tool_fix/b6/b6_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-4; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + corpus fully redacted + validators delegated + nothing uncommitted.
```
