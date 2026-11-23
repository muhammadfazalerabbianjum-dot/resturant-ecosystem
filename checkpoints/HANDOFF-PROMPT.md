===BEGIN name=model-handoff chars=7655===

MODEL HANDOFF — CARNAMA EXPANSION, P1 IN FLIGHT. You are a NEW agent instance. You may NOT trust
anything you remember or assume: the repo's own records are the only truth. Your first job is to
rebuild and VERIFY state. You write ZERO new code until sections 1–3 below are complete and green.

# 0. GROUND TRUTH AT HANDOFF (verified against the tree, not remembered)
- Branch: cline/p32-golden-gates, HEAD e8c3ca08, working tree CLEAN, nothing ever pushed.
- Phase 1: P1-1 DONE, P1-2 DONE (commit 09aa31bd), P1-2a PARTIAL 3/8 (commit e8c3ca08),
  P1-3, P1-5, P1-4, P1-6, P1-7, P1-8 NOT STARTED.
- Everything below must still be re-proved by you. If your reading disagrees with this block,
  the REPO wins and the disagreement goes to docs/QUESTIONS.md.

# 1. REBUILD STATE (read-only, in this order)
1. .clinerules (standing laws — obey from here on).
2. docs/ORCHESTRATOR_HANDOFF.md — the product spec AND the frozen invariants. It is the only spec
   document in this repo.
3. ledger.md and DIGEST.md — both live at the REPO ROOT, not under docs/.
4. docs/queue-P0.md and docs/queue-P1.md (card statuses), docs/DECISIONS.md (owner rulings
   A1/A2/A8/Q-001/Q-002/D-013, Amendments 1–2, D-020…D-030), docs/QUESTIONS.md (Q-001…Q-003).
5. The three newest files in checkpoints/ — including checkpoints/ORCHESTRATOR-REPORT-*.md,
   checkpoints/P1-02.md and checkpoints/P1-02a.md.
6. docs/WORKTREES.md (branch/worktree disposition table + the 2026-11-09 disposition section).
7. `git log --oneline -30` and `git status --porcelain`.
KNOWN TRAP — do not chase it: docs/EXPANSION_BLUEPRINT.md DOES NOT EXIST in this tree. Several
owner rulings cite it; the content was taken from the handoff and the gap is already logged as
Q-003. Do not create that file, do not halt for it, do not cite it as if you read it.
Write nothing yet. Summarize current position in <=10 lines into checkpoints/HANDOFF-STATE.md:
phase, cards DONE/TODO, open questions, last green gate receipt ids.

# 2. VERIFY BEFORE BUILD
Run the FULL gate suite on the untouched tree. All nine gates must PASS:
  cmd //c ".\\gate.cmd check"          (or `gate.cmd list` for the table: a dart-analyze,
  b gate-fast-tests, c functions-build, d emulator-rules, e whitelabel-dry-run, f stub-scan,
  g functions-coverage, h backend-parity, i tenant-isolation-generator)
MECHANICS THAT WILL BITE YOU:
- A full run takes ~15 minutes. A 5-minute tool timeout will kill it. Run it in the BACKGROUND
  with output redirected to a log, then read the log. Gate b alone is ~300s.
- Select gates with a COMMA list in one flag: `--only=d,i`. Multiple `--only` flags are not additive.
- Ports 8080 and 8090 are held by unrelated software on this machine; tool/emulator_probe.mjs
  already picks a free port and writes core_app/.gate-firebase.json (gitignored). Do not "fix" it.
- Gate f (stub-scan) only scans files that are CHANGED OR UNTRACKED right now. On a clean tree it
  proves nothing. Therefore: run the gates on your card's diff BEFORE you commit, not after.
- The pre-commit hook runs a `dart format` check and will REJECT the commit. Fix it by running
  `dart format` on the named files, never with `--no-verify`.
- Any gate RED: do NOT fix anything. Record the exact command + failure output to
  checkpoints/HANDOFF-VERIFY.md, add it to docs/QUESTIONS.md and DIGEST.md, and HALT for the owner.
- All GREEN: record the receipt ids in checkpoints/HANDOFF-VERIFY.md and continue to §3.

# 3. RECONCILE RECORDS
Cross-check: every queue card marked DONE has a checkpoint file and a card-prefixed commit; ledger.md
matches queue statuses; no card is DONE without its DONE-WHEN evidence existing and re-readable.
Specifically re-verify P1-2's proof rather than trusting the label: `npm test` in
core_app/functions (expect 203 passing), `npm run test:coverage` (COVERAGE-FLOOR PASS, 16 files),
and gate d (expect the rules-probe 403s on GET/POST /transactions plus the ledger-probe lines
"exactly one ledger row", "replay keeps the existing row", "order was NOT written").
Discrepancies -> docs/QUESTIONS.md. If any discrepancy touches money paths (ledger.ts,
transactions, createOrder, the charge-intent core) -> HALT immediately. Otherwise record and continue.

# 4. CONTINUE THE P1 QUEUE
Resume at the first non-DONE card. Fixed order: P1-2a (finish) -> P1-3 -> P1-5 -> P1-4 -> P1-6 ->
P1-7 -> P1-8. One card at a time. Green gate -> commit (card-id message, never push, never
force-push, never rewrite) -> checkpoint -> ledger -> DIGEST -> next card. Red -> scoped revert ->
ONE retry -> halt.
P1-2a, exactly as far as it got: three branches are pruned (cline/w6-p26, cline/w5-p24,
cline/task-3). Five remain with branches intact: cline/task-4, cline/task-5, p28/lane-a,
p28/lane-b, p29/security-debt. Verified bundles for all eight sit in backups/ (gitignored,
~350MB). Continue with ONE worktree per command invocation — a single Windows worktree removal
takes minutes, and batching them is what timed out. Re-verify merge + bundle, then
`git worktree remove` + `git branch -d` (never -D). A refusal is REVIEW, not a retry.
NEVER touch <repo>-shots or <repo>-p33 (owner reviews them personally, D-027).
P1-2 is DONE and its bar is NOT relaxed if you ever revisit it: emulator-backed proof that order +
exactly ONE row write atomically, double-submit = one row, transactions client-write-denied,
registry row present. Re-prove it; do not rebuild it.

# 5. TIGHTENED RULES FOR YOUR REGIME (in addition to .clinerules; violation = red batch)
R1 COPY, DON'T INVENT. Before writing any new module, find the closest existing pattern in this repo
   (kitchen_service for a staff surface, permissions.ts for pure logic, ledger.ts for a money path)
   and mirror its structure, naming and test style. Novelty is a defect, not a virtue.
R2 NO DRIVE-BY CHANGES. Anything wrong outside your card goes to docs/QUESTIONS.md, then you carry on.
   Never fix, rename, reformat or "improve" what you were not asked to touch. `git diff` at card end
   must show only in-scope files.
R3 SMALL DIFFS. Over ~15 changed files or ~800 changed lines, stop and split the approach inside the
   card; if the card itself is too big, log it and do the unambiguous part.
R4 FROZEN INTERFACES ARE ABSOLUTE — the boot chain order, SyncQueue, createChargeIntentCore
   behaviour, the seven handoff invariants, rules semantics, locale parity, and the nine gate
   definitions above. They are stated in .clinerules and docs/ORCHESTRATOR_HANDOFF.md; read them
   there. You may not simplify, modernise or clean up any of them.
R5 NO NEW DEPENDENCIES, no config keys, no public endpoints, no schema changes unless the card names
   them explicitly. `channel` on ledger rows is a KNOWN, DELIBERATE gap (D-030) — Phase 2 fills it.
R6 EVIDENCE DISCIPLINE. Every DONE claim cites a command and its key output. If you cannot prove it,
   you do not claim it and you do not mark the card DONE. A summary is not proof.
R7 UNCERTAINTY = STOP EARLIER. If a card's DONE-WHEN is ambiguous in ANY way, put the ambiguity and a
   provisional answer in docs/QUESTIONS.md, halt THAT card (not the run) and take the next
   independent one. Never improvise on money, rules, auth, claims, migrations, or anything the
   handoff marks [DECIDED] / [PROVEN].
R8 Never touch a real Firebase or Stripe project; emulator + simulated reader only; never push.

# 6. BOUNDARY
Complete P1 as scoped, produce the ORCHESTRATOR REPORT at the boundary, and HALT. The owner audits
your output against docs/ORCHESTRATOR_HANDOFF.md before Phase 2 begins.

===END name=model-handoff===
