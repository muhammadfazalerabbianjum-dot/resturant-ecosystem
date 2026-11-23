# METHOD — Spec-Driven Batch Engineering (the reusable skeleton)

The batch methodology this repository was built with, distilled repo-agnostic so it can be applied anywhere. Proven over 10 waves (PERF-1…10) + the white-label generator series. Copy §1–§9 to any repo and start at batch one.

## 0. Three roles — never blur them

| Role | Who | Does |
|---|---|---|
| **Owner** | you | Product decisions only. Never writes code, never judges own work |
| **Coordinator** | one session | Writes specs, **judges** (re-runs gates personally — never trusts a self-report), merges, **single writer of the ledger**, pushes |
| **Executor** | 1–2 agent sessions | Implements one batch inside a bounded territory, delivers findings + a paste-ready ledger block, **never touches the ledger** |

*Why: two writers on one ledger = merge conflicts by construction.*

## 1. The spec file = the acceptance contract (one per batch)

```
WHITE_LABEL_pNN_<name>.md
§0 Rules (binding — encode EVERY exception-prone rule here, not in chat)
§1 Baseline + blocker gate (exact tip hash, gates that must be green BEFORE edits)
§2 Territory (exclusive per executor; forbidden files listed)
§3 Problems → Acceptance → T-x table (each task: what, proof required, floor)
§4 Deliverable format (six-way classification, see §2 law 1)
§5 Acceptance (measurable floors: tests ≥ N, coverage ≥ N%, 0 skips)
§6 Coordinator protocol (judge → merge → battery → ledger → push)
§7 Executor quickstart (paste-ready prompt)
```

*Why: chat instructions lose against a driver template's DONE clause — every rule that matters must live in the file.*

## 2. The ten laws

1. **Proof law** — every claim needs **P1** (file:line opened this session) or **P2** (a test that fails if the claim is false). Everything else goes in a mandatory, non-empty **UNVERIFIED** section.
2. **No fake green** — no `@Skip`, no TODO-as-done, no `expect(true, isTrue)`; every fix ships **red→green** (failing proof captured *before* the fix).
3. **Fail-closed** — on money/auth/security paths, silent `catch(_)` fail-open is prohibited; audit every catch site.
4. **Spec-vs-code → STOP** — if the spec's premise conflicts with the code at HEAD, change nothing, report with an evidence table. Code at HEAD is the source of truth.
5. **Territory exclusivity** — cross-territory findings are handoff notes, never drive-by fixes (unless red→green in-territory and documented).
6. **Forbidden files** — lockfiles, generated code (regenerate, never hand-edit), the ledger, anything coordinator-owned.
7. **Unattended discipline** — never block on a question: fail-safe default + record in DECISIONS-NEEDED-FROM-OWNER; commit+push every phase; **never end on a red tip**.
8. **Findings ship with fixes** — an audit that only documents spawns the next wave's backlog.
9. **Do not re-derive** — receipted facts get cited (`LEDGER:batch-x`), effort goes to the unscouted.
10. **One batch, one session** — finish, gate, ledger, merge, push; never start the next batch.

## 3. The cadence (every batch, the same seven steps)

```
1. SYNC     executor: merge --ff-only main → verify exact tip (floor-ancestor check)
2. BLOCKER  analyze + format green BEFORE any edit
3. WORK     red→green per fix; territory-respecting; receipts captured to files
4. GATES    analyze(fatal) · format(0) · suites · coverage floors · grep gates (skip/TODO/vacuous)
5. DELIVER  findings file: six-way classification
            (Verified / Unverified / Anomalies / Untested / Risks / Recommendations)
            + honest residuals + paste-ready ledger block
6. JUDGE    coordinator re-runs gates + spot-checks claims personally; rejects get ledgered
7. CLOSE    merge → full battery on merged tip → ledger addendum (single writer) → push
```

## 4. The gate set (adapt to your stack)

| Gate | Purpose | Our form |
|---|---|---|
| Static | no drift | `analyze --fatal-infos` / lint 0 |
| Style | zero churn noise | format 0 changed |
| Behavioral | intent as executable spec | full suites, 0 fail **0 skip** |
| Security | fail-closed posture | rules/permission tests + app-check-style uniformity sweep |
| Coverage | floors per package **and** per feature | ≥80% floors |
| Structural | completeness by construction | route-walker exact-map, absence pins, schema-identity tests |
| **Mutation** | tests detect defects, not just pass | named mutants on the money path, kill-rate reported |
| Greps | no fake-green class | skip/TODO/vacuous-assert census with word boundaries |

*The two that caught the most real bugs: the post-merge battery (cross-window integration breaks) and the mutation run (tests aren't theater).*

## 5. The ledger — one file, single writer, append-only

`archive/FIX_VERIFICATION.md`: chronological `## APP COMPLETION <batch> — VERIFICATION REPORT` addenda. Each contains: proof commands **+ results**, drifts recorded (spec-vs-code corrections), honest residuals, handoffs with named owners. It becomes the repo's master document — the next batch cites `LEDGER:x` instead of re-deriving.

## 6. The judge protocol

Coordinator must: re-run the load-bearing gates personally · spot-check ≥3 claims · verify **tip ≠ base** before trusting "batch complete" · verify every red→green proof actually failed first · audit forbidden paths (0 expected) · resolve only *predicted* conflicts.

## 7. The anti-loop (the most important piece)

Audits without a convergence criterion loop forever — every wave must find something, so it will. Fix: **numeric freeze criterion**: `zero open findings AND floors met AND only ship-blockers remain → FREEZE DECLARED (date + tip), in the ledger`. After freeze: bugs come only from production usage; fixes are bug-driven, red→green, no waves. Owner decisions are recorded with fail-safe defaults held in-tree until decided.

## 8. Fleet sizing

- **1 executor** for small/bounded waves (audit spikes, micro-batches).
- **2 max** for parallel work — with *disjoint production files* and one predicted-conflict resolution (the ledger) prepared in advance.
- Never 5. Coordination overhead grows faster than value.

## 9. File skeleton to copy

```
repo/
  archive/FIX_VERIFICATION.md          # append-only ledger (coordinator-only)
  DECISIONS_LOG.md             # owner decisions + fail-safe defaults
  RUNBOOK_<operation>.md       # self-verifying operator procedures
  WHITE_LABEL_pNN_<name>.md    # one spec per batch
  tool_<fleet>/                # committed receipts: logs, coverage parses, inventories,
                               # mutation harnesses, generator scripts
  (worktrees) task-1..task-2   # executor branches, merged by coordinator
```

## 10. The five lessons that made it work

1. **Verify premises before dispatch** — one unverified spec premise cost an entire executor's effort falsifying it.
2. **Completion = merged + gated + ledgered + pushed** — a "complete" report with no commit is a failure mode.
3. **Proof beats memory** — every "it works" claim that got re-run contradicted its report at least once.
4. **Tier your depth**: 100% mechanical inventory (cheap, complete) + risk-tiered deep reads (money/auth/flows) + behavioral proofs. Uniform exhaustive depth produces confident-sounding slop.
5. **Stubs are killed by pins, not comments** — delete the dead thing AND add the test that fails if it returns.
