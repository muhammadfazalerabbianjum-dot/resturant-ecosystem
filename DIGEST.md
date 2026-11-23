# DIGEST

Human-readable running summary of P0.

## P0 boundary pack — 2026-11-09

**Verdict:** `gate.cmd check` → **PASS** (9 ran, 0 failed, 0 unavailable,
0 not-active), exit 0 → `checkpoints/gate-20261109T135306Z.md`.
Branch `cline/p32-golden-gates` @ `7c139d5c`; **nothing committed** (no P0 card
carries `COMMIT: yes`).

### Per-card status — 12/12 DONE

| Card | Deliverable | Evidence |
|---|---|---|
| P0-1 | Gate machine (9 gates, receipts, ledger, DIGEST) | `checkpoints/P0-01.md` |
| P0-2 | Worktree/branch inventory, no deletion | `checkpoints/P0-02.md` |
| P0-3 | Superseded banners + thermal contradiction annotated | `checkpoints/P0-03.md` |
| P0-4 | Baseline measured, gap register (G1–G6) | `checkpoints/P0-04.md` |
| P0-5 | Rules parity gate (h) + `--fix` | `checkpoints/P0-05.md` |
| P0-6 | `tenantId` required in both validators | `checkpoints/P0-06.md` |
| P0-7 | DECISIONS / QUESTIONS / queue scaffold | `checkpoints/P0-07.md` |
| P0-8 | Cross-tenant test generator, 27/27 rows, gate (i) | `checkpoints/P0-08.md` |
| P0-9 | c8 + per-file coverage registry + gate (g) | `checkpoints/P0-09.md` |
| P0-10 | Optional `stripeAccountId` / `terminalLocationId` | `checkpoints/P0-10.md` |
| P0-11 | `ProcessorAdapter`, 178/178, 100% new-file coverage | `checkpoints/P0-11.md` |
| P0-12 | This pack + full gate | `checkpoints/P0-12.md` |

### Red count

31 gate runs recorded, **14 red**. Every red was one of two things: a **planted
failure** proving a gate bites, or a **real defect the gate found** — and the ones
found while closing P0 were all real: `avoid_print` in the generated suite; Docker
Desktop owning `127.0.0.1:8080` so the rules probe got an Apache 404; a toast app
owning `8090`; gate (f) counting legacy markers inside legitimately edited files;
and one stale line citation. Each was fixed **at cause** (D-018, D-019), never by
weakening an assertion.

### Decisions (D-001 … D-019)

Gate machine: D-001 Node runner · D-002 only FAIL is red · D-003 stub-scan churn
basis (+`-uall`) · D-004 `gate_fast` set · D-005 demo project id · D-006 `\.\gate.cmd`
· D-007 `library;` for tags · D-008 drop the mock rules suite · D-009 two-sided
probe. Bookkeeping: D-010 proportional gate scope · D-011 parity as a script ·
D-012 citations are repaired, not bypassed. Surface: D-013 `terminalLocationId`
placement (ASSUMED, needs an owner ruling). Coverage: D-014 c8 over built-in ·
D-015 per-file registry with a ratchet. Tenancy: D-016 generator from the rules,
registry required. Money: D-017 the adapter moves money, never decides it. Gate
repairs: D-018 OS-chosen emulator port · D-019 HEAD marker budget.

### Open questions (owner input)

- **Q-001** Where is the thermal printing implementation? (`blocks-phase-2`)
- **Q-002** Which Stripe reader, in which market? (`blocks-phase-2`, first live demo)

### Top baseline findings (full register: `docs/BASELINE-GAP.md`)

- **G1** The only "rules test" is a `fake_cloud_firestore` mock — no rule is ever
  evaluated. (`BLOCKS-P1`)
- **G2** `e2e` / `nightly` / `needs-emulator` tiers are unmeasured.
- **G3** `test/rules/firestore_rules_test.js` is executed by nothing.
- **G4** Gate (b) covers 7 of ~2541 tests by design.
- **G5** Nothing verifies the rules **deployed** to any Firebase project. (`BLOCKS-P1`)
- **G6** Thermal printing is claimed done and does not exist.

### What is actually true about this repo right now

1. Everything that existed is green: 2541 Dart tests, 178 functions tests,
   `analyze` clean, functions build clean, real emulator enforcement proven.
2. Nine gates now stand where "trust me" used to be, and each has been proven to
   go red on a planted failure.
3. The money path behaves exactly as before; it is only *shaped* differently
   (adapter seam, 100% covered, all money tests unchanged).
4. Tenant isolation is **not** implemented and **not** proven: 27/27 collections
   are PENDING-TENANCY, surfaced loudly by name in the suite and by gate (i).
5. The largest untested surface is `src/index.ts` (2282 lines, 22.3% lines,
   frozen at that floor); rules say nothing about tenancy yet (G1/G5).

### Owner ruling needed

`docs/WORKTREES.md`: 8 branches are SAFE-PRUNE and 2 worktrees need review
(`<repo>-shots` has 4 uncommitted files including `app_bootstrap.dart`;
`<repo>-p33` has untracked work). **Nothing was deleted.** L5's destructive
allowance is empty, so this waits for the owner — as does D-013's shape choice.

## P5 backlog registered — 2026-11-12

P5 backlog registered, 7 features, build starts after P4.

## Gate runs

- 20261107T180915Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261107T180915Z.md`
- 20261107T181524Z — gate **FAIL** (1 failed, 0 unavailable, 1 not-active) → `checkpoints/gate-20261107T181524Z.md`
- 20261108T165018Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T165018Z.md`
- 20261108T165625Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T165625Z.md`
- 20261108T165700Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T165700Z.md`
- 20261108T165711Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T165711Z.md`
- 20261108T170148Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T170148Z.md`
- 20261108T170157Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T170157Z.md`
- 20261108T170901Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T170901Z.md`
- 20261108T170911Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T170911Z.md`
- 20261108T171011Z — gate **PASS** (0 failed, 0 unavailable, 1 not-active) → `checkpoints/gate-20261108T171011Z.md`
- 20261108T172555Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T172555Z.md`
- 20261108T173134Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T173134Z.md`
- 20261108T173136Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T173136Z.md`
- 20261108T173139Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T173139Z.md`
- 20261108T174245Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T174245Z.md`
- 20261108T174257Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T174257Z.md`
- 20261108T174900Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261108T174900Z.md`
- 20261109T124534Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T124534Z.md`
- 20261109T124640Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T124640Z.md`
- 20261109T130932Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T130932Z.md`
- 20261109T132951Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T132951Z.md`
- 20261109T132257Z — gate **FAIL** (3 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T132257Z.md`
- 20261109T134425Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T134425Z.md`
- 20261109T134911Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T134911Z.md`
- 20261109T134952Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T134952Z.md`
- 20261109T135029Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T135029Z.md`
- 20261109T135033Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T135033Z.md`
- 20261109T135106Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T135106Z.md`
- 20261109T135243Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T135243Z.md`
- 20261109T135306Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T135306Z.md`
- 20261109T141202Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T141202Z.md`
- 20261109T150023Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T150023Z.md`
- 20261109T150037Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T150037Z.md`
- 20261109T151907Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T151907Z.md`
- 20261109T151932Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T151932Z.md`
- 20261109T151938Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T151938Z.md`
- 20261109T151942Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T151942Z.md`
- 20261109T151944Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T151944Z.md`
- 20261109T152112Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T152112Z.md`
- 20261109T153152Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T153152Z.md`
- 20261109T155305Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T155305Z.md`
- 20261109T155435Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T155435Z.md`
- 20261109T161412Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T161412Z.md`
- 20261109T161521Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T161521Z.md`
- 20261109T161833Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T161833Z.md`
- 20261109T161845Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T161845Z.md`
- 20261109T161852Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T161852Z.md`
- 20261109T162625Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T162625Z.md`
- 20261109T162627Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T162627Z.md`
- 20261109T162633Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T162633Z.md`
- 20261109T162642Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261109T162642Z.md`
- 20261110T151711Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T151711Z.md`
- 20261110T151806Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T151806Z.md`
- 20261110T151901Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T151901Z.md`
- 20261110T151912Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T151912Z.md`
- 20261110T152912Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T152912Z.md`
- 20261110T152919Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T152919Z.md`
- 20261110T152944Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T152944Z.md`
- 20261110T155039Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T155039Z.md`
- 20261110T155046Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T155046Z.md`
- 20261110T155056Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T155056Z.md`
- 20261110T155123Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261110T155123Z.md`
- 20261111T093127Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T093127Z.md`
- 20261111T093736Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T093736Z.md`
- 20261111T095027Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T095027Z.md`
- 20261111T094446Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T094446Z.md`
- 20261111T095108Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T095108Z.md`
- 20261111T155139Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T155139Z.md`
- 20261111T155209Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T155209Z.md`
- 20261111T161944Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T161944Z.md`
- 20261111T161956Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T161956Z.md`
- 20261111T163822Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T163822Z.md`
- 20261111T163849Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T163849Z.md`
- 20261111T164317Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T164317Z.md`
- 20261111T164841Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T164841Z.md`
- 20261111T164956Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T164956Z.md`
- 20261111T165019Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T165019Z.md`
- 20261111T165119Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T165119Z.md`
- 20261111T165502Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T165502Z.md`
- 20261111T165531Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T165531Z.md`
- 20261111T170739Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T170739Z.md`
- 20261111T171347Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T171347Z.md`
- 20261111T171924Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T171924Z.md`
- 20261111T173508Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T173508Z.md`
- 20261111T173640Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T173640Z.md`
- 20261111T173824Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T173824Z.md`
- 20261111T174027Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T174027Z.md`
- 20261111T174250Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T174250Z.md`
- 20261111T175004Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T175004Z.md`
- 20261111T175135Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T175135Z.md`
- 20261111T175220Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T175220Z.md`
- 20261111T175322Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T175322Z.md`
- 20261111T180856Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T180856Z.md`
- 20261111T181026Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181026Z.md`
- 20261111T181126Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181126Z.md`
- 20261111T181213Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181213Z.md`
- 20261111T181259Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181259Z.md`
- 20261111T181355Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181355Z.md`
- 20261111T181849Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261111T181849Z.md`
- 20261112T163554Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T163554Z.md`
- 20261112T163757Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T163757Z.md`
- 20261112T163828Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T163828Z.md`
- 20261112T163901Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T163901Z.md`
- 20261112T165021Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T165021Z.md`
- 20261112T165138Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T165138Z.md`
- 20261112T165235Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T165235Z.md`
- 20261112T165249Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T165249Z.md`
- 20261112T165350Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T165350Z.md`
- 20261112T170257Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T170257Z.md`
- 20261112T170526Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T170526Z.md`
- 20261112T171012Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T171012Z.md`
- 20261112T172148Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T172148Z.md`
- 20261112T173626Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T173626Z.md`
- 20261112T173857Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T173857Z.md`
- 20261112T173906Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T173906Z.md`
- 20261112T174109Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T174109Z.md`
- 20261112T174459Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T174459Z.md`
- 20261112T174735Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T174735Z.md`
- 20261112T174807Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T174807Z.md`
- 20261112T175922Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T175922Z.md`
- 20261112T175955Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T175955Z.md`
- 20261112T180109Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T180109Z.md`
- 20261112T180550Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T180550Z.md`
- 20261112T180704Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T180704Z.md`
- 20261112T181711Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T181711Z.md`
- 20261112T181727Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T181727Z.md`
- 20261112T181757Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T181757Z.md`
- 20261112T181821Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T181821Z.md`
- 20261112T183832Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T183832Z.md`
- 20261112T183927Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T183927Z.md`
- 20261112T184716Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T184716Z.md`
- 20261112T184747Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T184747Z.md`
- 20261112T185001Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T185001Z.md`
- 20261112T185614Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T185614Z.md`
- 20261112T185648Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T185648Z.md`
- 20261112T185730Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T185730Z.md`
- 20261112T185807Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T185807Z.md`
- 20261112T190343Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190343Z.md`
- 20261112T190351Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190351Z.md`
- 20261112T190414Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190414Z.md`
- 20261112T190650Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190650Z.md`
- 20261112T190715Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190715Z.md`
- 20261112T190740Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190740Z.md`
- 20261112T190755Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190755Z.md`
- 20261112T190954Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261112T190954Z.md`
- 20261113T082934Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T082934Z.md`
- 20261113T083031Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T083031Z.md`
- 20261113T083152Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T083152Z.md`
- 20261113T083210Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T083210Z.md`
- 20261113T085417Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T085417Z.md`
- 20261113T085855Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T085855Z.md`
- 20261113T085854Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T085854Z.md`
- 20261113T090728Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T090728Z.md`
- 20261113T090757Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T090757Z.md`
- 20261113T090911Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T090911Z.md`
- 20261113T090943Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T090943Z.md`
- 20261113T091144Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091144Z.md`
- 20261113T091233Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091233Z.md`
- 20261113T091347Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091347Z.md`
- 20261113T091656Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091656Z.md`
- 20261113T091842Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091842Z.md`
- 20261113T091929Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T091929Z.md`
- 20261113T092048Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092048Z.md`
- 20261113T092126Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092126Z.md`
- 20261113T092154Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092154Z.md`
- 20261113T092237Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092237Z.md`
- 20261113T092313Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092313Z.md`
- 20261113T092434Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T092434Z.md`
- 20261113T093956Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T093956Z.md`
- 20261113T095354Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T095354Z.md`
- 20261113T095510Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T095510Z.md`
- 20261113T095927Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T095927Z.md`
- 20261113T100015Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T100015Z.md`
- 20261113T100146Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T100146Z.md`
- 20261113T100237Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T100237Z.md`
- 20261113T100330Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T100330Z.md`
- 20261113T110133Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T110133Z.md`
- 20261113T110649Z — gate **FAIL** (1 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T110649Z.md`
- 20261113T110736Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T110736Z.md`
- 20261113T110812Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T110812Z.md`
- 20261113T112655Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T112655Z.md`

## P1 boundary — 2026-11-13

**Verdict:** `gate.cmd check` → **PASS** (11 ran, 0 failed, 0 unavailable,
0 not-active). Branch `cline/p32-golden-gates`; local commits only, nothing
pushed, nothing deployed.

**P1 complete:** 8 of 8 cards. Tenancy closed with **32 of 32 rule paths ACTIVE**
and 0 PENDING; harness at 165 passed / 56 known / **0 new**.

**What the last cards had to get right** (full reasoning in
`checkpoints/P1-04-STEP7.md`):

- A literal `settings/*` rule keeps authorizing the OLD document name after a
  rename — so the literals were deleted, not kept for compatibility, and the
  panic-switch read, the shape checks and the `ownerInfo` read exception moved
  into the generic block. Left in place, the switch would have failed OPEN.
- Driver documents (`deliveries`, `proof_of_delivery`) take their tenant from
  the ORDER (D-047). Giving them a `tenantId` field would have been erased by the
  first GPS ping, since that write is `hasOnly`-shaped and replaces the document.
- The optional claim reader was removed: a construction without one silently read
  the retired document, which is an owner pause that visibly does nothing.

**Open:** three pre-existing Dart failures (C-4), 56 harness baseline entries
(C-3), `hasAppId()` unverified in production (C-1), live migration and all
real-project actions owner-only (C-2). See `ROADMAP.md`.

**Next:** Phase 2 card P2-0, the owner-approved Flutter-web spike, which ends in
a verdict returned to the owner before any staff-UI work starts
(`docs/queue-P2.md`).
- 20261113T120949Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T120949Z.md`
- 20261113T124504Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T124504Z.md`
- 20261113T125800Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T125800Z.md`
- 20261113T130713Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T130713Z.md`
- 20261113T132313Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T132313Z.md`
- 20261113T133440Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T133440Z.md`
- 20261113T134105Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T134105Z.md`
- 20261113T135423Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T135423Z.md`
- 20261113T140119Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261113T140119Z.md`
- 20261114T134809Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261114T134809Z.md`
- 20261114T150203Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261114T150203Z.md`
- 20261115T084733Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261115T084733Z.md`
- 20261123T100443Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261123T100443Z.md`
- 20261123T100509Z — gate **PASS** (0 failed, 0 unavailable, 0 not-active) → `checkpoints/gate-20261123T100509Z.md`
