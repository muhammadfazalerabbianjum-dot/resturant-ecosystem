# QUEUE — P0 (hygiene, gate machine, baseline)

The card text for each entry lives in `docs/P0-PROMPT.md` §5. This file is the
status board: one row per card, the exact deliverable, and a pointer to the
evidence. A card is `DONE` only when its checkpoint file exists and the
`DONE WHEN` clause is demonstrably true.

**Loop:** first `TODO` from the top → `gate.cmd check` → `PASS` writes the
checkpoint and marks `DONE`; `FAIL` reverts only this card's files, records the
failure, retries once, then `HALT`s.

**Status vocabulary:** `TODO` · `WIP` · `DONE` · `RED` (failed once, retrying) ·
`HALTED` (two failures, owner needed) · `BLOCKED` (waiting on an owner ruling).

| # | Card | Status | Deliverable | Evidence |
|---|---|---|---|---|
| P0-1 | Gate machine | DONE | `gate.cmd`, `tool/gate.mjs`, `gate_config.json`, queue, checkpoints, ledger, DIGEST, `gate_fast` tag | `checkpoints/P0-01.md` |
| P0-2 | Worktree census | DONE | `docs/WORKTREES.md` — 11 worktrees, every branch, keep/merge/delete recommendation | `checkpoints/P0-02.md` |
| P0-3 | Stale docs + thermal contradiction | DONE | SUPERSEDED banners on `PROJECT_STATUS.md`, `FINAL_HANDOVER.md`; annotation on `DEFERRED.md` H2 | `checkpoints/P0-03.md` |
| P0-4 | Baseline run (truth, not repair) | DONE | `docs/EVIDENCE-P0.md`, `docs/BASELINE-GAP.md` — real suite results, every failure triaged | `checkpoints/P0-04.md` |
| P0-5 | Rules parity gate | DONE | Parity check across every `apps/*/backend/*` copy, wired as gate (h), proven by a planted divergence | `checkpoints/P0-05.md` |
| P0-6 | Config schema: `tenantId` | DONE | Required `tenantId` in both validators; halal_boyz config updated; absent → refused before generation | `checkpoints/P0-06.md` |
| P0-7 | Decisions + questions scaffold | DONE | `docs/DECISIONS.md` with format and full P0 backfill; `docs/QUESTIONS.md`; this queue audited | `checkpoints/P0-07.md` |
| P0-8 | Cross-tenant test generator | DONE | Generator enumerating rules collections → PENDING-TENANCY cases; fails if a collection has no case | `checkpoints/P0-08.md` |
| P0-9 | Functions test scaffold | DONE | Coverage tooling in `npm test`, 90% floor for new/touched files, planted under-coverage fails | `checkpoints/P0-09.md` |
| P0-10 | Payment config fields (schema only) | DONE | Optional `stripeAccountId`, branch `terminalLocationId`; accepted by both validators; zero consumers | `checkpoints/P0-10.md` |
| P0-11 | Processor adapter (pure refactor) | DONE | `ProcessorAdapter` around `createChargeIntentCore`, line-identical move, all money tests green | `checkpoints/P0-11.md` |
| P0-12 | P0 boundary pack | DONE | `DIGEST.md` complete; every checkpoint present; `gate.cmd` verdict itemized; HALT for owner | `checkpoints/P0-12.md` |

## Notes carried between cards

- The working tree is dirty **before** P0. `checkpoints/P0-01.pre.txt` records
  that state; tracked-file churn in it is the owner's and is excluded from all
  gate judgement (law L11). Untracked files are in scope.
- Gate (d) needs the Firebase emulator; if it cannot run, it says `UNAVAILABLE`
  loudly and the run is marked *not full coverage*. That is not a pass.
- Gate (g) is `NOT-ACTIVE` until P0-9; gate (h) does not exist until P0-5.
