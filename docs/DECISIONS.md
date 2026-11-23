# DECISIONS

Every non-obvious choice made during the expansion, with the alternative that
was rejected. A decision without evidence is not a decision, it is a guess —
guesses belong in `QUESTIONS.md`.

**Entry format**

```
## D-00N — <short title>
- **Date:** YYYY-MM-DD · **Phase:** P0 · **Card:** P0-1
- **Decision:** what was chosen, in one sentence.
- **Alternatives considered:** what else was viable, and the cost of each.
- **Evidence / spec:** file:line, command output, or a handoff section.
- **Grade:** OPTIMAL | CONSTRAINED | ASSUMED
- **If ASSUMED — verification:** the exact check that will confirm or refute it.
```

Grades: **OPTIMAL** = best option on the evidence. **CONSTRAINED** = not ideal,
forced by something real (a missing SDK, a frozen interface). **ASSUMED** = a
guess that is still unverified, so it must carry a verification step.

---

## D-001 — The gate runner is Node, with `gate.cmd` as a thin wrapper
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** `gate.cmd` contains no logic; it calls `node tool/gate.mjs`.
- **Alternatives considered:** (a) all logic in batch — works on Windows only,
  and batch cannot parse `git status --porcelain` or scan files without an
  external binary; (b) PowerShell — same limitation, and the repo already mixes
  shells; (c) a bash script — the owner's machine runs Git Bash but the card
  names `gate.cmd`, and the orchestrator will invoke it from cmd.exe.
- **Evidence / spec:** `node -v` → v24.13.1 (present); `docs/P0-PROMPT.md` §5
  P0-1 requires the command to be `gate.cmd check`.
- **Grade:** OPTIMAL for this machine. The gate logic is testable and
  cross-shell; only the entry point is Windows-specific.

## D-002 — `UNAVAILABLE` and `NOT-ACTIVE` do not make the run red
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** exit 1 only for a gate that actually ran and failed. A missing
  tool or a switched-off gate yields exit 0 with a loud banner, a `!! LOUD` line
  per gate, a row in the receipt, and the verdict printed as
  *not full coverage*.
- **Alternatives considered:** (a) treat unavailable as red — the loop deadlocks
  on card 1 on any machine without the emulator, and the agent would "fix" a
  missing tool by disabling the gate; (b) treat it as a plain pass — the exact
  silent-green failure the card forbids.
- **Evidence / spec:** `docs/P0-PROMPT.md` §1 step 4 ("reports LOUD UNAVAILABLE
  (never silently green) — keep going") and §3 ("must FAIL LOUDLY on bad input,
  never silently continue").
- **Grade:** OPTIMAL. The distinction is carried in three places at once (exit
  code, printed banner, receipt table), so it cannot be misread as green.

## D-003 — Stub-scan excludes only tracked-file churn, never untracked files
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** the baseline (`checkpoints/P0-01.pre.txt`) suppresses paths whose
  porcelain status is not `??`. Untracked files stay in scan scope.
- **Alternatives considered:** (a) suppress every path in the snapshot — would
  have excluded `tool/gate.mjs` itself, i.e. P0's own code invisible to its own
  gate; (b) no baseline at all — the owner's five pre-existing modified files
  would then be judged by P0's gate, violating L11.
- **Evidence / spec:** `checkpoints/P0-01.pre.txt` lists five ` M` entries and
  the untracked tree; `core_app/DEFERRED.md` and `DESIGN.md` are the owner's.
- **Grade:** OPTIMAL for the stated laws. The residue is that a marker inside an
  untracked file that predates P0 would also fail the gate — acceptable, since
  the alternative is hiding new code.
- **Amendment (2026-11-08):** the first implementation ran `git status --porcelain`,
  which collapses a brand-new directory to `?? tool/`. Files inside it therefore
  never matched the extension filter and were silently unscanned — the exact
  shape all future card work will take. Now `--porcelain -uall`, verified by the
  scanned-file count rising from 7 to 10 (the three `tool/*.mjs` files joined the
  seven tagged tests) with the verdict unchanged at PASS
  (`gate-20261108T172555Z`).

## D-004 — `gate_fast` smoke set: config schema + money contracts + payment payload
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** tag seven existing files as `gate_fast`:
  `test/config/client_config_schema_test.dart`,
  `test/rules/order_create_payload_contract_test.dart`,
  `test/app/config/money_{byte_identity,fail_closed,krw_rule,cldr_parity}_test.dart`,
  `test/core/payment/payment_service_test.dart`.
- **Alternatives considered:** whole suite per card — minutes per card, so the
  agent would start skipping the gate; a single file — too thin to catch a
  cross-cutting break.
- **Evidence / spec:** the repo's own tag convention in `core_app/dart_test.yaml`
  (`e2e`, `nightly`, `needs-emulator`, standard run excludes all three); handoff
  §6.1 names the money path and config schema as the two proven-strong areas, so
  they are the right regression net for Phase 1.
- **Grade:** OPTIMAL. Chosen files are emulator-free and cover the two areas the
  expansion is most likely to break.

## D-005 — The emulator gate pins a `demo-` project id
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** gate (d) runs
  `firebase emulators:exec --only firestore --project demo-carnama-gate "flutter test test/firestore_emulator_rules_test.dart"`.
- **Alternatives considered:** using `demo-tenant` or
  `resturants-8547d` — both are real projects and law L10 forbids touching them,
  even accidentally through a mistyped flag.
- **Evidence / spec:** `core_app/firebase.json` declares the emulator ports and
  `firestore.rules`; law L10 in `docs/P0-PROMPT.md` §2.
- **Grade:** OPTIMAL. `demo-` prefixes are the firebase-tools convention for
  emulator-only projects, so no credentials and no real project are involved.

## D-006 — The gate is invoked as `.\gate.cmd`, not `gate.cmd`
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** every documented invocation uses `.\gate.cmd` from cmd/PowerShell
  (or `node tool/gate.mjs` from any shell). `gate.cmd` alone is documented as
  broken on this machine.
- **Alternatives considered:** keep the bare form and hope — measured as failing:
  `cmd /c "gate.cmd list"` prints *'gate.cmd' is not recognized*.
- **Evidence / spec:** `%NoDefaultCurrentDirectoryInExePath%` is `1` on this
  machine, which removes the current directory from cmd's search path. Forms
  tested: bare → exit 1; `.\gate.cmd list` → works; absolute path → works.
- **Grade:** OPTIMAL. Documenting the constraint costs one line and prevents an
  orchestrator from concluding "the gate tool does not exist".

## D-007 — `gate_fast` files declare `library;` under their `@Tags` annotation
- **Date:** 2026-11-07 · **Phase:** P0 · **Card:** P0-1
- **Decision:** each tagged file begins `@Tags(['gate_fast'])` / `library;` /
  blank line, exactly as `test/core/admin_access_test.dart` already does.
- **Alternatives considered:** annotate the first `import` — this is what the
  card's author would write from memory, and it is wrong: `dart analyze` emits
  *library_annotations* for all seven files and exits non-zero, so the gate goes
  red on the tagging itself.
- **Evidence / spec:** first attempt produced 7 `library_annotations` infos and
  gate (a) FAIL at 183.2s (run `20261107T181524Z`); adding `library;` gave PASS at
  326.9s (run `20261108T165018Z`).
- **Grade:** OPTIMAL, and the failure was informative: the gate machine caught a
  real defect in its own setup on its first use, which is the strongest evidence
  available that gate (a) is wired to a real analyzer rather than to `true`.

## D-008 — Gate (d) does not run the existing "emulator rules" suite
- **Date:** 2026-11-08 · **Phase:** P0 · **Card:** P0-1
- **Decision:** `test/firestore_emulator_rules_test.dart` is excluded from gate (d)
  and recorded as a baseline gap instead.
- **Alternatives considered:** keep it as the rules gate — measured as a gate that
  cannot fail, which is the failure mode the whole card exists to prevent.
- **Evidence / spec:** that file imports `fake_cloud_firestore` and carries
  `late FakeFirebaseFirestore fakeFirestore;` plus its own comment: *"we will
  simulate the rules tests by constructing our local logic tests … For true rule
  testing, a node.js script with @firebase/rules-unit-testing is recommended."*
  Experiment: appended an invalid `match` block to `core_app/firestore.rules`,
  ran the gate as configured → **PASS, exit 0, 32.2s**. The suite never touches
  the emulator, so no rules change can turn it red.
- **Grade:** OPTIMAL. A green gate that proves nothing is worse than a loud gap;
  the gap is now written down in `docs/BASELINE-GAP.md` for P0-4/P0-8.

## D-009 — Gate (d) becomes a two-sided REST probe
- **Date:** 2026-11-08 · **Phase:** P0 · **Card:** P0-1
- **Decision:** gate (d) runs `firebase emulators:exec --only firestore --project
  demo-carnama-gate "node ../tool/rules_probe.mjs"`. The probe requires
  unauthenticated `GET /menus` → 200 (rules grant `allow read: if true`) and
  `GET /users` → 403 (no public rule).
- **Alternatives considered:** (a) parse `firestore-debug.log` for compilation
  errors — measured: the emulator boots with invalid rules and writes no error to
  that log either, so there is nothing to parse; (b) a boot-only probe
  (`tool/emulator_boot_probe.mjs`) — measured: exit 0 with invalid rules, so it
  detects a missing emulator but not broken rules; (c) `@firebase/rules-unit-testing`
  — the right long-term tool, but adding a dependency and a harness is P0-8 work.
- **Evidence / spec:** invalid rules → **FAIL exit 1, 11.4s**
  (`checkpoints/logs/d-real-plant.log`: both requests return 400 because nothing
  compiled); clean rules → **PASS exit 0, 9.0s** (`gate-20261108T170901Z`).
  The old command took 102.2s to prove nothing; the new one takes 9.0s and can
  fail.
- **Grade:** OPTIMAL for P0. It proves the rules file is parsed, loaded and
  enforced, and it is 11× faster. It does **not** test tenant isolation or field
  allowlists, and the gate's `proves` string says so.

## D-010 — Per-card gate scope is proportional to the card's change
- **Date:** 2026-11-08 · **Phase:** P0 · **Card:** P0-3, P0-4, P0-7
- **Decision:** a docs-only card runs gate (f) only and says so in its
  checkpoint; a code card runs the gates its change can actually affect
  ((a) analyze, (e) dry-run, (h) parity, plus the targeted test files), and the
  full `gate.cmd check` still runs at each phase boundary.
- **Alternatives considered:** full gate on every card — measured at ~11 minutes
  per run (a 304.7s + b 333.2s dominate), i.e. ~2 hours of pure waiting across
  P0, which in practice means the gate gets skipped rather than run.
- **Evidence / spec:** full run `20261108T171011Z` = 11m05s end to end; warm
  `--only=a` = 54.2s; `--only=f` = 0.0s.
- **Grade:** CONSTRAINED. It is the smallest honest scope, and it is written
  down per card rather than silently narrowed — a green (f)-only receipt is never
  presented as a full pass.

## D-011 — Parity is a standalone Dart script, not a test file or a generator flag
- **Date:** 2026-11-08 · **Phase:** P0 · **Card:** P0-5
- **Decision:** `core_app/tool/check_backend_parity.dart`, invoked directly by
  gate (h), with `--fix` as the refresh path.
- **Alternatives considered:** (a) a `flutter test` file — 30–60s of harness
  startup to compare three files; (b) a `--refresh-backend` flag on the
  4,800-line generator — its argument parsing is shared with real client
  generation and would need dry-run plumbing to avoid writing a client.
- **Evidence / spec:** gate (h) measured at 2.1s clean / 1.0s on a plant; the
  script exits 2 when no `apps/*/backend` exists, so an empty fleet cannot look
  green.
- **Grade:** OPTIMAL.

## D-012 — A stale line-number citation is repaired, not bypassed
- **Date:** 2026-11-08 · **Phase:** P0 · **Card:** P0-6
- **Decision:** after inserting the `tenantId` gate into `tool/whitelabel.dart`,
  the `currency.code` row of the config-key disposition register was re-pointed
  from `whitelabel.dart:354` to `:372`.
- **Alternatives considered:** relaxing the register test to search a window —
  that would have destroyed the only mechanism that catches stale citations.
- **Evidence / spec:** `test/tool/config_key_disposition_test.dart` fails with
  *Expected: contains 'currencyCode'* until the citation is corrected, and passes
  afterwards; a one-off scan of all 8 register rows found this as the only stale
  citation.
- **Grade:** CONSTRAINED. Citations into source files will keep moving whenever
  P1 edits those files; the register test is the tripwire, so this will recur and
  is cheap each time. (It recurred immediately in P0-10: 372 → 400.)

## D-013 — `terminalLocationId` accepts both flat and per-branch placement
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-10
- **Decision:** the schema accepts `branches.terminalLocationId` AND
  `branches.<branchId>.terminalLocationId`; both are type-checked, neither is read.
- **Alternatives considered:** picking one — the card says "branch-level" but the
  `branches` section is a map that already holds a flat `defaultBranchId`, so
  either single reading silently rejects the other's natural config.
- **Evidence / spec:** `docs/P0-PROMPT.md` P0-10; `lib/app/config/app_config.dart:367`
  (`branches` is `_asMap`).
- **Grade:** ASSUMED. **Verification:** the owner rules on the shape before P1
  writes a reader. Whichever loses becomes a deleted validation branch — no data
  migration is needed, because nothing has ever read either field.

## D-014 — Coverage via c8, not Node's built-in test coverage
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-9
- **Decision:** `c8` devDependency; `test:coverage` = `tsc` + `c8 node --test` +
  `scripts/check_coverage_floor.mjs`.
- **Alternatives considered:** `node --experimental-test-coverage` (zero install,
  but thresholds are aggregate-only — no per-file floor, which is exactly what
  the card requires).
- **Evidence / spec:** P0-9 authorises `npm install --save-dev c8` by name; the
  per-file registry needs `coverage-summary.json`, which c8 emits. Measured: gate
  (g) 8.2s end to end.
- **Grade:** OPTIMAL.

## D-015 — Per-file coverage registry with a ratchet, legacy floors at measured truth
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-9
- **Decision:** `coverage-floors.json` holds one floor per `src/**` file (default
  90 for unlisted/new files), plus a total floor. A file with no row FAILS; a row
  whose file is gone FAILS; `--raise` may only move floors up.
- **Alternatives considered:** (a) global 90% — impossible today (repo total
  60.14%, `src/index.ts` 22.3%), would have to be lowered to be green, which is
  how thresholds die; (b) c8 `--check-coverage --per-file` — no notion of "new
  files need more than legacy files", so the monolith would cap everything at 22%.
- **Evidence / spec:** baseline measurement in `checkpoints/P0-09.md`; the
  completeness rule immediately found 3 unregistered migration scripts.
- **Grade:** CONSTRAINED. Legacy floors are a freeze, not an aspiration; the
  `index.ts` debt is recorded in the registry note and in P0-9's checkpoint.

## D-016 — Cross-tenant suite is generated from `firestore.rules`, with a registry row required per collection
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-8
- **Decision:** `tool/gen_tenant_isolation_tests.dart` enumerates top-level
  `match /<collection>` blocks from the rules at four-space indentation, requires
  a row for each in `test/security/tenant_isolation_cases.json`, renders
  `tenant_isolation.generated_test.dart`, and fails in `--check` mode on a
  missing row, a stale row, or generated drift.
- **Alternatives considered:** (a) hand-writing one test per collection — the
  card's actual deliverable is the *enumeration* being complete, which hand
  maintenance cannot guarantee; (b) generating at test-run time — the suite would
  then not exist in review, and a rules change would silently add untested cases.
- **Evidence / spec:** planted collection → exit 2; planted drift → exit 2;
  27/27 rows; gate (i) 1.7s.
- **Grade:** OPTIMAL. The indentation anchor is the one fragile point, and it is
  covered by the completeness check: if a future rules file changes indentation,
  collections disappear from the enumeration and their registry rows become
  "stale" — the gate goes red instead of quietly shrinking.

## D-017 — The processor seam moves money, never decides it
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-11
- **Decision:** `StripeProcessorAdapter.createIntent` owns only the Stripe call
  and the resulting `{paymentIntentId, clientSecret, status}` mapping; every
  money decision stays in `createChargeIntentCore`, and the existing
  `input.stripe` injection seam is preserved by wrapping it.
- **Alternatives considered:** (a) move tax/promo/amount computation into the
  adapter — that is a rewrite of the money path, which the card forbids; (b)
  replace `input.stripe` with the adapter as the injection point — would have
  changed the emulator harness contract and the tests the card requires to stay
  unchanged.
- **Evidence / spec:** `src/index.ts` diff = 35 insertions / 38 deletions, no
  other hunk; 178/178 functions tests; adapter 100% lines; Dart order payload
  contract green.
- **Grade:** OPTIMAL for a pure refactor. The seam is one method wide on purpose:
  a second processor needs only `createIntent`, and the metadata bag that the
  webhook depends on cannot diverge per processor.

## D-018 — Gate (d) asks the OS for a free emulator port
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-12 (found while closing)
- **Decision:** `tool/emulator_probe.mjs` reserves a free loopback port, writes
  `core_app/.gate-firebase.json` (sibling of the real config, so `rules` paths
  still resolve) with that port and the UI disabled, runs `emulators:exec --config`,
  and deletes the temp file.
- **Alternatives considered:** (a) keep 8080 — Docker Desktop publishes
  `127.0.0.1:8080`, so loopback requests never reach the emulator and the probe
  saw an Apache 404; (b) pick another fixed port — 8090 turned out to be held by
  `WsToastNotification.exe` on this machine, so fixed ports are a guess; (c)
  change the project's `firebase.json` — the dev config should not be bent around
  one machine's port squatters.
- **Evidence / spec:** the gate passed with `firestore on free port 48815` in 7.7s;
  the emulator's own error on an occupied port is `Port X is not open on 0.0.0.0,
  could not start Firestore Emulator`, i.e. a hard failure rather than a fallback.
- **Grade:** OPTIMAL. The probe still reads `FIRESTORE_EMULATOR_HOST` and the
  rules file, project id and all other config are unchanged — only the port is
  chosen at run time.

## D-019 — Stub-scan ignores markers that already existed in HEAD
- **Date:** 2026-11-09 · **Phase:** P0 · **Card:** P0-12 (found while closing)
- **Decision:** before flagging a marker, gate (f) spends a per-file budget built
  from the file's **HEAD** content, matched per marker text and per occurrence. An
  added marker fails even if the same text already existed; a file that had to be
  edited keeps its legacy markers without turning the gate red.
- **Alternatives considered:** (a) path allowlists — they would hide future
  additions in exactly the files most likely to grow; (b) count-per-file instead
  of per-line — a second identical marker would be invisible; (c) leaving it —
  P0-6/P0-10 legitimately edited `whitelabel.dart`, whose TODO-stripping helper
  contains the marker, so the gate punished correct work.
- **Evidence / spec:** with the budget, `[f] stub-scan PASS (25 files)`; a new file
  containing a marker still produced `stub markers found in 1 place(s)` and FAIL,
  then PASS after removal.
- **Grade:** OPTIMAL. `gate.mjs` is now itself in the marker-clean state required
  by its own header comment — the first draft of the comment tripped the scan,
  which is the gate working as intended.

## D-020 — Capabilities are server-first; `fleet.dispatch` keeps today's holders
- **Date:** 2026-11-09 · **Phase:** P1 · **Card:** P1-1
- **Decision:** `permissions.ts` defines all six target roles plus the legacy
  `delivery`, and `counter`/`waiter` exist in the server table before any client
  can mint them. `assertCapability` reads `roles[]` and falls back to `role`.
  `dispatchToFleet` gates on `fleet.dispatch`, granted to owner, manager, kitchen
  and delivery — exactly the set that `STAFF_ROLES` admitted before.
- **Alternatives considered:** (a) gate dispatch more narrowly (owner/manager
  only) — a silent authorisation change no card authorised, and the existing
  contract test pins the staff set; (b) add `counter`/`waiter` to the Dart enum
  now — unused enum values with no surface, i.e. the dead code L2 forbids;
  (c) keep `assertStaffRole` — it answers "is staff", not "may do this", and the
  POS/ledger work needs the latter.
- **Evidence / spec:** handoff §2.1 (six roles), §9.2 (capability table),
  §8.1 A3 (roles become a set); `test/permissions.test.js` M-1 asserts the full
  cartesian product against an independent matrix; `test/access_capability.test.js`
  G-1 is the Phase 1 waiter/payment.take denial.
- **Grade:** CONSTRAINED. The capability table and gate are final in shape; the
  `fleet.dispatch` grant is deliberately the pre-existing staff set and MUST be
  narrowed in Phase 2 when the dispatcher surface is defined. Verification step:
  the Phase 2 card that adds the dispatch UI re-reads this entry and updates the
  table plus M-1 together.

---

# Owner rulings — 2026-11-09 (reply to ORCHESTRATOR REPORT 2026-11-09T1535Z)

**Citation note (L1):** the ruling text cites `docs/EXPANSION_BLUEPRINT.md` §3.1 as the
frozen authority. **That file does not exist in this tree** (`find . -iname "*blueprint*"`
returns nothing). The rulings are therefore logged with the handoff sections that carry
the same frozen content, and the absent file is raised as **Q-003** in `docs/QUESTIONS.md`
rather than cited as if it had been read. Grades are OPTIMAL because the owner issued them
as final; the evidence line names what this repo can actually show.

## D-021 — A1: tenancy is flat collections + `tenantId` field
- **Date:** 2026-11-09 · **Phase:** P1 · **Card:** P1-4 (unblocks)
- **Decision:** Owner ruling, final. Collections stay top-level; every document carries
  `tenantId`; one rules helper enforces it on every match block; the generated
  per-collection cross-tenant suite goes ACTIVE. A collection in rules without a registry
  row remains a gate (i) failure.
- **Alternatives considered:** `tenants/{tenantId}/…` subpaths — rejected by the owner;
  also incompatible with P0-8's generator, which enumerates top-level collections.
- **Evidence / spec:** handoff §8.1 A1, §9.1; ruling of 2026-11-09.
- **Grade:** OPTIMAL. Verification: P1-4 flips the generated cases to ACTIVE and gate (i)
  plus gate (d) must both stay green.

## D-022 — A2: fresh shared project; Halal Boyz is tenant #1
- **Date:** 2026-11-09 · **Phase:** P1 mechanics / P2 go-live
- **Decision:** Fresh shared Firebase project; Halal Boyz = tenant #1; the old project
  (`demo-tenant`) is untouched, read-only for 30 days after the switch, then archived.
  P1-6 may BUILD and TEST migration mechanics against the emulator only. Executing any
  migration against a real project, creating the project, enabling billing, and the
  export→import→verify→switch run are human-only gates.
- **Alternatives considered:** migrating the existing project in place — rejected (owner).
- **Evidence / spec:** handoff §7.1; ruling of 2026-11-09. No network mutation is performed
  by this agent under this entry.
- **Grade:** OPTIMAL.

## D-023 — A8: Flutter-web spike is the first Phase 2 card
- **Date:** 2026-11-09 · **Phase:** P2 · **Card:** first P2 card (not P1)
- **Decision:** The 2-day web spike is approved but starts Phase 2, not P1. Fallback if
  goldens/boot gates cannot run on web: a thin PWA shell reusing `packages/core` services,
  never a fork of business logic. The verdict is a QUESTION-TIME halt: owner rules before
  any P2 staff UI card begins.
- **Alternatives considered:** spike now — rejected; P1 has no web work.
- **Evidence / spec:** handoff §8.1 A8; ruling of 2026-11-09.
- **Grade:** OPTIMAL.

## D-024 — Q-001/A10: thermal printing stays a blocked claim
- **Date:** 2026-11-09 · **Phase:** P2 receipts
- **Decision:** Owner has produced no implementation path. Thermal remains a BLOCKED claim
  (`DEFERRED.md` annotation stands). Phase 2 receipts are on-screen + system print + Stripe
  email. No code or document may claim thermal printing until the owner hands over a path.
- **Alternatives considered:** none — the ruling closes the question rather than choosing.
- **Evidence / spec:** handoff §7.3, §6.2; ruling of 2026-11-09.
- **Grade:** OPTIMAL (closed, not deferred by the agent).

## D-025 — Q-002: Canada first; WisePOS E primary; simulated reader only in dev
- **Date:** 2026-11-09 · **Phase:** P2
- **Decision:** Market = Canada (Gulf deferred to the ProcessorAdapter seam only). Reader =
  WisePOS E countertop primary, WisePad 3 budget fallback; Tap-to-Pay on iPhone is
  demo-grade and never a production dependency. All Phase 2 card-present development runs
  on Stripe's **simulated** reader in test mode against emulator/localhost — no real Stripe
  API calls, no hardware ordering. Physical purchase/registration is human-only.
- **Alternatives considered:** Gulf-first, Tap-to-Pay-only, hardware-in-the-loop dev —
  all rejected by the owner.
- **Evidence / spec:** handoff §9.4; ruling of 2026-11-09.
- **Grade:** OPTIMAL.

## D-026 — D-013 narrowing is scheduled into the first Phase 2 config card
- **Date:** 2026-11-09 · **Phase:** P2 · **Amends:** D-013
- **Decision:** `terminalLocationId` is FLAT and branch-level; a single value is
  authoritative. The current both-forms acceptance stays CONSTRAINED until the first
  Phase 2 config card drops the nested form and re-grades to OPTIMAL. Until then no new
  caller may rely on the nested form.
- **Evidence / spec:** handoff §8.3; owner ruling of 2026-11-09 confirming the flat shape.
- **Grade:** CONSTRAINED (time-boxed by the Phase 2 config card, named in the queue).

## D-027 — Worktrees: two preserved, eight pruned under P1-2a
- **Date:** 2026-11-09 · **Phase:** P1 · **Card:** P1-2a
- **Decision:** `<repo>-shots` and `<repo>-p33` are PRESERVED untouched — their
  work exists nowhere else and the owner reviews them personally. The eight SAFE-PRUNE
  branches are approved for pruning by the sequence in D-029 only.
- **Alternatives considered:** prune all ten — rejected; delete the two dirty worktrees —
  rejected by the owner.
- **Evidence / spec:** `docs/WORKTREES.md` rows 2–11; ruling of 2026-11-09.
- **Grade:** OPTIMAL.

## D-028 — AMENDMENT 1: commit policy replaces "nothing committed"
- **Date:** 2026-11-09 · **Phase:** all
- **Decision:** (a) One snapshot commit of all P0 + P1-1 work now; (b) from P1-2 onward, one
  `git commit` per DONE card, message prefixed with the card id — RED attempts are never
  committed; (c) never push, never force-push, never rewrite history. Commits are local
  safety, not publication.
- **Alternatives considered:** commit per file/theme — rejected; stay uncommitted — rejected
  as the top operational risk (121 dirty entries on a single copy).
- **Evidence / spec:** ruling of 2026-11-09; supersedes the L4 "no commit" reading for the
  remainder of P1 and later phases.
- **Grade:** OPTIMAL.

## D-029 — AMENDMENT 2: worktree prune safety sequence
- **Date:** 2026-11-09 · **Phase:** P1 · **Card:** P1-2a
- **Decision:** For each SAFE-PRUNE branch: (1) re-run `git branch --merged
  cline/p32-golden-gates` and require proof of merge — anything unproven moves to REVIEW;
  (2) `git bundle create backups/<branch>.bundle <branch>` and require `git bundle verify`
  to pass before removing anything; (3) `git worktree remove` then `git branch -d` (never
  `-d`'s force counterpart); a refusal is REVIEW, never forced; (4) `WORKTREES.md` records
  disposition + bundle paths and `checkpoints/P1-02a.md` proves the sequence.
- **Alternatives considered:** `git branch -D` for speed — rejected; deleting the
  worktrees' contents without bundles — rejected.
- **Evidence / spec:** ruling of 2026-11-09; `docs/WORKTREES.md`.
- **Grade:** OPTIMAL.

## D-030 — Ledger rows are derived, deterministic and append-only
- **Date:** 2026-11-09 · **Phase:** P1 · **Card:** P1-2
- **Decision:** A sale row's id is `sale_<orderId>`; the row is written in the
  same Firestore transaction as the order document; any existing row is kept
  untouched (no rewrite, ever); all amounts and the currency come from the
  charged PaymentIntent and the order document being written, never from the
  client payload. `channel` is not recorded yet because no surface supplies one.
- **Alternatives considered:** random row ids (a retry would double the ledger);
  a second write after the order (an order could exist untrailered); storing
  `totalCents` from the request (client-controlled money).
- **Evidence / spec:** handoff §8.1 A6, §9.3; `test/ledger.test.js` L-1…L-10;
  gate (d) emulator output in `checkpoints/P1-02.md` (one row on first commit,
  none added on replay, poisoned write rolls back the order too).
- **Grade:** CONSTRAINED. The shape is final. Narrowing step: `channel` (and any
  branch currency nuance) is added with the first surface that knows it — the
  Phase 2 POS — and P1-7's channel breakdown must not claim coverage before that
  exists.

## D-031 — Reversals are new rows; rollup refunds are a separate figure
- **Date:** 2026-11-10 · **Phase:** P1 · **Card:** P1-3
- **Decision:** A reversal's id is `rev_<originalRowId>` (deterministic, so a
  retried refund cannot double). The reversal mirrors the original's amounts with
  the opposite sign and copies `branchId`/`channel`/`currency` from the original;
  a caller cannot supply them. The original row is only ever read. In rollups,
  reversals subtract from `revenueByChannel` but are also reported separately as
  `refundsCents`, so gross sales per channel stay readable and a reversed sale
  never disappears from `ordersCount`.
- **Alternatives considered:** editing the original row's `status` (breaks
  append-only and destroys the evidence of what was charged); netting reversals
  into revenue with no separate refund figure (a manager cannot then see how much
  came back); random reversal ids (a retry refunds twice).
- **Evidence / spec:** handoff §3 (ledger is append-only; corrections are new
  reversal rows), §8.1 A6/A11, §9.3; `test/reversal_rollups.test.js` R-1…R-5,
  U-1…U-4; `checkpoints/P1-03.md`.
- **Grade:** OPTIMAL for the ledger shape. Narrowing step: `topItems` and
  `staffActivity` are deliberately absent from the rollup until a surface writes
  item snapshots (Phase 2 POS) — they must not be faked from order documents.

## D-032 — Claims are built by one function; authority change revokes tokens
- **Date:** 2026-11-10 · **Phase:** P1 · **Card:** P1-5
- **Decision:** `buildUserClaims(usersDoc)` is the only place a custom claim is
  shaped. It carries `tenantId`, `roles[]` (authority, validated against the
  P1-1 table), sorted `branchIds[]`, and `claimsVersion`; the legacy single
  `role` is minted only when exactly one role is present. `planClaimSync` marks
  an authority change (roles, branches, tenant) and the trigger then revokes
  refresh tokens. The capability gate's freshness check is opt-in, so a denied
  stale token is `permission-denied` while existing call sites keep their P1-1
  contract.
- **Alternatives considered:** trusting `role` alone (cannot express counter AND
  floor); re-reading the user document inside every callable (latency and a
  second source of truth); revoking on every user-document write (signs staff
  out when they edit their name).
- **Evidence / spec:** handoff §8.2, §8.3 (roles/branchIds are authority, role is
  derived legacy), §2.1 (several roles per person); `test/claims.test.js`
  C-1…C-6, S-1…S-3; `checkpoints/P1-05.md`.
- **Deployment ordering:** the trigger returns `claims: null` for a user without
  `tenantId`, and today's users have none. The `migrate_v004_tenancy` backfill
  (P1-6) must run BEFORE this trigger is deployed, or staff lose their claims on
  their next profile write. This is fail-closed, not escalation, but it is a
  lockout and the order is not negotiable.
- **Grade:** OPTIMAL for the claim shape. Narrowing step: `tenantIds[]`
  (membership) stays out of the token; membership is checked at sign-in.

## D-033 — Backfills derive, never guess; dry run is the default
- **Date:** 2026-11-10 · **Phase:** P1 · **Card:** P1-6
- **Decision:** `migrate_v004_tenancy` writes `tenantId` only where the field is
  absent (target `halal-boyz`, tenant #1 per A2, overridable with
  `MIGRATION_TENANT_ID`); a document already carrying a DIFFERENT `tenantId` is
  reported as a conflict and left untouched. `migrate_v005_roles` derives
  `roles[]`/`branchIds[]` from the legacy single `role`/`branchId` and keeps the
  legacy fields; a document with no role is skipped, not promoted. Both default
  to a dry run and require `MIGRATION_APPLY=true` to write.
- **Alternatives considered:** overwriting a mismatched tenant (reassigns a
  client's data — unacceptable); inventing roles for documents that have none
  (fabricated authority); applying by default (a migration that writes on import
  is a migration nobody can inspect first).
- **Evidence / spec:** handoff §7.1 (every document needs `tenantId`), §8.2/§8.3
  (roles/branchIds authority); `test/migrations.test.js` M-1…M-10, where the
  second-run-zero-changes property is asserted at both the planner and the
  wrapper layer.
- **Grade:** OPTIMAL for the plan logic. Narrowing step: the collection read is
  unpaginated; paginate before running against a large production collection.
- **Deploy ordering (restated, binding):** v004 → v005 → P1-5 trigger → P1-4
  rules. Any other order breaks claims or reads.

## D-034 — The owner breakdown panel derives from ledger rows, client-side

- **Decision:** `BranchChannelBreakdown.fromRows` re-derives revenue, order count
  and refunds from the same `sale`/`reversal` rows the server rollup folds, and
  the panel renders those numbers as data. Channel values (`app`, `counter`,
  `waiter`) are never translated and never relabelled.
- **Why:** P1-7 needs a breakdown before any provider or route exists to read
  `daily_rollups`. Deriving with the *same rule* as `rollups.ts` (a reversal
  subtracts revenue and is reported as a refund; it never erases a sale from
  `ordersCount`) keeps the screen honest, and a test pins the arithmetic. A
  translated channel label would let the screen disagree with the ledger column
  it came from, which is the one thing a money screen must never do.
- **Alternatives considered:** reading `daily_rollups` documents (the cache is
  not the source of truth — P1-3's whole point); localised channel chips
  (misleading for stored enum values); dropping rows without `branchId`
  (hides money; an `unknown` bucket surfaces it instead).
- **Evidence / spec:** `branch_channel_breakdown_test.dart` (7 tests, both
  widths, overflow captured as an error rather than printed); D-031 for the
  reversal/refund semantics being mirrored.
- **Grade:** CONSTRAINED — the panel is not mounted yet; when P1-4/P1-5 settle
  how a client reads the ledger, wire it to a bounded query and re-check the two
  widths against real data.

## D-035 — Guest clients carry a tenant claim; no collection is exempt from `tenantOk()`

- **Decision (answers Q-004): design 1.** Every client, including an
  unauthenticated guest, carries `tenantId` in its token, and every collection's
  `read` is gated by `tenantOk()`. `allow read: if true` is removed from `menus`,
  `branches`, `branches/*/config`, `branches/*/menu_overrides` and `promotions`;
  the cross-tenant denial suite covers all 28 collections with zero exemptions.
- **The binding (why this is enforceable, not a promise):** the tenant is resolved
  server-side from the requesting client's attested app id — the same
  `request.auth.token.app_id` the existing rules already trust in `hasAppId()`.
  A `tenants/{tenantId}` registry lists each tenant's `appIds`; the claim callable
  maps `app_id → tenantId` and fails closed on an unknown app id. Nothing the
  client puts in a request body or a route decides the tenant, so a probe cannot
  ask for another tenant's tenant id; it can only claim the tenant its own build
  belongs to.
- **Guest claim shape:** an anonymous user has no `users/{uid}` document, so
  `buildUserClaims` gains an explicit guest branch: `{tenantId, roles: [],
  branchIds: [], guest: true, claimsVersion: 1}`. A guest claim never carries a
  role or a branch — anonymous sign-in must not become a path to any staff
  capability, and `assertCapability` must fail for `roles: []` by construction,
  not by a separate check.
- **Why not design 2 (public reads stay `allow read: if true`):** menu prices and
  availability are already per branch and per client, so "public" here means
  pinned to the widest possible audience permanently. Worse, it makes every field
  someone later adds to a menu or branch doc world-readable by default — cost,
  margin, supplier, stock — which is exactly the class of data the ledger work
  exists to keep inside a tenant. A `tenantId` column that is only checked on
  some collections is decoration, and the exemption set would grow by convenience.
- **Cost of being wrong, and the ordering that contains it:** design 1 makes the
  rules depend on a client release. If the rules land first, the live app cannot
  load its own menu. Deploy order is therefore binding and now part of the
  sequence: (1) `tenants` registry + claim callable, (2) `app_id`-derived guest
  claims and the client's boot-time claim fetch, (3) `migrate_v004_tenancy` —
  every document has a `tenantId` before any rule reads one, (4) P1-4 rules last,
  behind the green generated suite. This extends D-032/D-033; it does not replace
  them.
- **Alternatives considered:** design 2 (rejected above); per-tenant Firebase
  projects (would make this trivial but A2/D-022 ruled a single shared project);
  trusting a `tenantId` supplied by the client (a guess dressed as a claim);
  exempting "public" collections from the suite (design 2 with extra steps).
- **Evidence / spec:** handoff §7.1 ("every rule path must check it");
  `firestore.rules:13-35` (`hasAppId`/`isAppVerified` already trust `app_id`);
  `firestore.rules:227-331` (today's `allow read: if true` surfaces);
  `test/security/tenant_isolation_cases.json` (28 rows, all PENDING-TENANCY).
- **Grade:** OPTIMAL for the security property; CONSTRAINED operationally —
  the emulator bootstrap must present a token carrying `app_id` **and**
  `tenantId`, and debug builds need their app id registered, so the harness work
  is a prerequisite of the rules change, not a parallel task.

## D-036 — P1-4 is implemented per the proposal: seeded ids, paired controls, App Check binding

- **Decision (owner verdict, 2026-11-11):** approve `checkpoints/P1-04-PROPOSAL.md`
  as written, and run the emulator isolation proof as a **new gate (j)**, separate
  from gate (d). Consequences, all binding:
  1. The generated suite gains an **allow** control beside every denial case;
     locked collections declare `sameTenant: none` *with a reason* and fall back to
     the global guest-boot control (`menus`, `branches`) plus a structural check
     that allow controls cannot all be downgraded.
  2. ACTIVE rows run against **seeded** tenant-B ids named by the registry, never
     a random path.
  3. The tenant binding is the **verified App Check app id**, not
     `request.auth.token.app_id` — an amendment to D-035, which named the
     unverified claim.
- **Why the amendment is not cosmetic:** Firestore's documented
  `request.auth.token` set has no `app_id`, so `hasAppId()` (`firestore.rules:13`)
  is likely always false, which also makes `hasAppId() && hasAppCheckToken()`
  (strict App Check) deny every write if true. The App Check path is verifiable
  server-side today and does not depend on an unresolved assumption.
- **Carried risk, stated rather than buried:** App Check is not emulated, so gate
  (j) proves rules isolation from Admin-minted claims while the claim callable is
  proven by unit tests with an injected verifier; the `hasAppId()` question stays
  open until one real ID token can be inspected (human-only under A2).
- **Scope limit:** `TenantFirestore` adoption in this card covers the guest-boot
  paths (menu, branch) only; the remaining `.collection(` call sites convert per
  feature as they are touched, rather than in one unreviewable sweep.
- **Grade:** OPTIMAL for falsifiability (a lockdown-only or leaking rule set both
  fail gate (j)); CONSTRAINED by the unemulated App Check service and by the
  per-feature query-constraint ripple.
- **Evidence / spec:** `checkpoints/P1-04-PROPOSAL.md` §2 (the two vacuous-green
  defects), §3.3–3.5 (harness and activation order), §4 (alternatives rejected,
  including `@firebase/rules-unit-testing`).


## D-037 — A collection's rule and its ACTIVE registry row land in one commit

- **Decision:** P1-4 is applied one collection per commit, where that commit
  contains BOTH the `tenantOk()` clauses for the collection and its registry row
  flipped to ACTIVE (plus the regenerated suite). This corrects the ordering in
  the approved proposal §3.5, which listed the flips before the rules change.
- **Why the original order cannot work:** a denial test asserts the absence of a
  cross-tenant read. Before the rule gains a tenant scope, that read is
  legitimately allowed, so a flipped row fails immediately. Any attempt to keep
  the tree green would have meant flipping rows with the assertions still
  skipped — i.e. claiming ACTIVE coverage that never executed.
- **Evidence:** `menus` shipped this way and gate (j) went from the pre-change
  state to green in one commit; both plants (lockdown and leak) fail the gate,
  and the restored rules pass it (checkpoints/P1-04-STEP2.md).
- **Grade:** OPTIMAL for attributability — a wrong denial is tied to the one rule
  that caused it instead of a 28-row avalanche. CONSTRAINED by having to touch
  `firestore.rules` 27 more times; that is the price of a reviewable diff.


## D-038 — `settings`/`ownerInfo` tenancy is flat and tenant-keyed (ruling A1)

- **Decision (owner, 2026-11-12):** settings documents stay in one flat
  collection, keyed `${tenantId}_${name}` (e.g. `t_acme_restaurantConfig`), and
  each carries a `tenantId` field like every other document. `tenantOk()` guards
  every `settings` match block. `ownerInfo` becomes **per tenant**, and
  `isOwner()` reads only the caller's tenant-scoped `ownerInfo` — never a global
  one. `settings`, `admins`, `audit_log` and `audit_logs` all convert on this
  scheme, in that order, in one card (P1-4 step 7).
- **Why this is the shape that works:** D-021 already ruled flat collections with
  a `tenantId` column and one rules helper; a subcollection under
  `tenants/{id}` would have created a second access pattern for the same data and
  a second helper. The per-tenant `ownerInfo` also removes the known debt
  `.clinerules/20-core-app-carnama.md` records ("the owner email is hardcoded at
  line 11 of `firestore.rules` and must move to `settings/ownerInfo`") — after
  this ruling that document is per tenant, so a second restaurant's owner is not
  represented by the first restaurant's email.
- **Consequences that must land in the same card, not after it:**
  1. `migrate_v004_tenancy` gains a settings sub-step: copy each singleton
     `settings/{name}` to `settings/{tenantId}_{name}` and stamp `tenantId`.
     Second run must change zero documents (P1-6 bar).
  2. Any reader that fetches `settings/restaurantConfig` **by literal name** —
     client or Cloud Function — breaks the moment the rules require the prefix.
     Every such read is enumerated first, then changed in the same commit set.
     This is the reason the card is not a rules-only diff.
  3. `isOwner()` changes semantics: it must resolve `ownerInfo` for the caller's
     `tenantId`, so an owner claim without a tenant is denied by construction.
- **Citation defect, recorded rather than repaired by invention:** ruling A1
  cites `EXPANSION_BLUEPRINT §9.1` as OPTIMAL support. **No file by that name
  exists in this repository.** The nearest document is
  `docs/PLATFORM_EXPANSION_PLAN.md`, whose §9.1 is "What it is and what it needs"
  under a PentAGI vulnerability-scanning phase — unrelated to settings tenancy.
  The ruling's substance is therefore supported by D-021 and D-035, which do
  exist and do decide flat-plus-`tenantId`; the citation itself is unresolved.
  Per D-012 a citation is repaired, not bypassed, so this note is the repair: the
  document it names was never written, and no substitute section is claimed.
- **Grade:** OPTIMAL for consistency and for killing the global-owner assumption;
  CONSTRAINED by the migration rename, which touches every literal settings id in
  the codebase.
- **Evidence:** `core_app/firestore.rules` (`isOwner()`, `settings` match block);
  `docs/DECISIONS.md` D-021, D-035; `core_app/functions/src/migrations.ts`
  (`migrate_v004_tenancy`).

## D-039 — `orders`/`reservations` carry `tenantId` in the create payload (ruling A2)

- **Decision (owner, 2026-11-12):** approved. `tenantId` enters the create shape
  lock **and** the client payload in the **same** commit, and the payload
  contract test is updated in that commit. Frozen-interface change: recorded as
  an ADR-04 amendment before that commit.
- **The bar for that card is two-sided:** gate (j) must prove a legitimate
  tenant-A create is **ALLOWED** and a cross-tenant create is **DENIED**. An
  over-lock that denies legitimate creates is a red batch, exactly like a leak.
  This is a **new assertion shape**: today's allow controls are reads of the
  caller's own document, and no case asserts a permitted create. The suite and
  generator must gain a create-allow case before `orders` can be called green —
  otherwise the denial passes while the app cannot take an order at all.
- **Why it cannot be split:** the shape lock (`keys().hasOnly([...])`) rejects any
  key it does not name, so a rule requiring `tenantId` without the lock naming it
  is a contradiction, and a lock naming it without the client sending it rejects
  every real create.
- **Grade:** OPTIMAL for the security property; CONSTRAINED — it changes a
  frozen client payload contract and requires the new allow-create assertion.
- **Evidence:** `core_app/firestore.rules` (`orders`, `reservations` create
  blocks); `checkpoints/P1-04-ORCHESTRATOR-REPORT.md` §4.2.

## D-040 — Nested rule blocks get their own registry rows (ruling A3)

- **Decision (owner, 2026-11-12):** `branches/*/menu_overrides`,
  `branches/*/config` and `branches/*/waitlist_meta` each get their own registry
  row with `sameTenant` scoping, so the generated suite proves the subcollections
  instead of assuming them. `notifications/*/items` is already scoped inside its
  parent card but has no row of its own; it gains one under the same ruling.
- **Consequence:** the registry schema must express a nested path plus the parent
  id used for seeding (a row today is one top-level collection). The generator
  and seed fragment grow accordingly; the row count moves past 28.
- **Grade:** OPTIMAL for the property ("every rule path must check it", D-035);
  CONSTRAINED by registry schema growth.
- **Evidence:** `core_app/firestore.rules` (`branches` block);
  `core_app/test/security/tenant_isolation_cases.json`.

## D-041 — Deploy order is enforced twice (ruling A4)

- **Decision (owner, 2026-11-12):** the order is confirmed and binding: claim
  callable → guest boot claim → `migrate_v004_tenancy` → **rules LAST**;
  emulator-first always. It is encoded twice: as a **check in the deploy script**
  (emitting rules before the claim callable exists is a red) and as prose in
  `DEPLOY.md`.
- **Why a check and not only a document:** the failure is silent and total — a
  guest cannot read a menu, so the app is dead on launch while every gate is
  green. A document nobody runs does not prevent that.
- **Scope limit:** rules ahead of the app is legal **only** inside the emulator.
  Every gate in this repo is an emulator gate, so this does not weaken anything
  today; it forbids the deploy that would.
- **Grade:** OPTIMAL for containing the one change in this phase that can take
  the product offline.
- **Evidence:** D-035's ordering paragraph; `checkpoints/P1-04-ORCHESTRATOR-REPORT.md`
  §5 item 4.

## D-042 — Frozen order amended: tenancy completion precedes the ledger (ruling B)

- **Decision (owner, 2026-11-12):** the frozen card order is amended. P1-4's
  remaining steps (1–7) run **before** P1-2, so ledger rows are born
  tenant-scoped instead of being backfilled later. P1-2's engine code is
  unchanged by this — only its **position** in the sequence moves.
- **Why:** the ledger is append-only and derived at write time (D-005-style
  immutability). Writing the first rows before tenancy exists means either a
  rewrite of an append-only table (forbidden) or rows whose `tenantId` is a
  guess. Ordering the work is cheaper than either.
- **Consequence:** no card definition changes; the DONE WHEN for P1-2 keeps its
  emulator-backed proof bar exactly as written.
- **Grade:** OPTIMAL (avoids an append-only rewrite); CONSTRAINED (delays the
  ledger by seven small cards).


## D-043 — Paste-integrity protocol: a literal `<CHARS>` means the count check does not apply

- **Decision (owner, 2026-11-12):** an owner paste is either under 4K characters
  (no envelope needed) or carries a **real** character count. A literal
  `<CHARS>` placeholder means "count check N/A — judge by the `===END===` marker
  plus section integrity", and that interpretation is recorded here once rather
  than re-litigated on each paste.
- **Why it needed a ruling:** the protocol's purpose is to stop a *truncated*
  directive being executed. A placeholder cannot distinguish truncation from
  completeness, so the honest handling is to say so, check the structural
  signals that do exist (end marker, all named sections present, paired
  SPEC markers), and record that no numeric verification happened — which is what
  happened on 2026-11-12. Fabricating a pass would have been the actual failure.
- **Grade:** OPTIMAL (keeps the anti-truncation guard while removing a placeholder
  that can never pass); CONSTRAINED (structural checks are weaker than a count).
- **Evidence:** the 2026-11-12 master directive arrived with `chars=<CHARS>`;
  `checkpoints/P1-04-STEP3.md` and this log record the limitation.

## D-044 — Receipts cite command output, never memory

- **Decision (owner, 2026-11-12):** every commit hash, count and gate result
  written into a receipt must be **copied from command output in the same
  session**. A recalled value is not evidence.
- **Why:** `checkpoints/P1-04-STEP3.md` was first written with a remembered hash
  (`a2b0e0e`) for the `reservation_counters` commit; the real one is `b69203a`
  and the other three are `ae67a78`, `c84e2d6`, `1036b24`. The error was caught
  only because the hash was re-checked against `git log` before it stood. A
  receipt is the artefact the next session audits, so a wrong hash there is worse
  than no hash.
- **Grade:** OPTIMAL (cheap, and it is the same rule Q1 already applies to code
  claims, extended to bookkeeping).
- **Evidence:** commit `67692cf6` corrects the receipt; `git log --grep` produced
  the four hashes.

## Frozen programme ADRs — backfilled as in-repo owner rulings (2026-11-12)

**Authority:** from 2026-11-12 `docs/DECISIONS.md` is the citation authority
inside this repository. These ADRs were authored in a document that was never
copied into the repo; that omission is why D-038 could not honour a
`§9.1` citation. No `docs/EXPANSION_BLUEPRINT.md` is created — the handoff,
this file and `docs/BACKLOG-P5.md` are the repo's truth. Each entry below is an
owner ruling: **grade OPTIMAL**, **citation "owner directive 2026-11-12 (ADR
backfill)"**. Entries that an existing decision already covers are
cross-referenced, not duplicated.

### ADR-00 — ProcessorAdapter seam at `createChargeIntentCore`

- **Ruling:** the processor seam sits at `createChargeIntentCore` from P1 onward;
  Stripe Canada is implementation #1 of that seam.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **See also:** P0-11 (`checkpoints/P0-11.md`), D-017 (the adapter moves money,
  never decides it).

### ADR-01 — Stripe Connect topology

- **Ruling:** one platform account plus **per-Canadian-tenant connected
  accounts**; card readers sit under each tenant's own connected account;
  `stripeAccountId` and `terminalLocationId` are carried in config.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **Consequence:** a tenant's payments cannot be routed through another tenant's
  account, so account identity becomes part of tenancy, not a deployment detail.

### ADR-02 — Migration deploys are two-step

- **Ruling:** a migration deploys as **two steps — data, then rules** — each
  gated by the emulator suite. Never a single combined push to the shared
  project.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **See also:** D-035's ordering, D-041 (the deploy-order check).

### ADR-03 — Repo hygiene was P0

- **Ruling:** repository hygiene was a P0 deliverable and is done; the true
  baseline is recorded in `EVIDENCE-P0.md`.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).

### ADR-04 — Order/reservation create payload carries `tenantId`

- **Status:** already ruled as **D-039** (owner, 2026-11-12) with the same
  substance: `tenantId` enters the create shape lock and the client payload in
  one commit, with a payload contract test and a two-sided gate (j) proof.
  Recorded here as the ADR-04 identity only; **not duplicated**.
- **Citation:** owner directive 2026-11-12 (ADR backfill).

### Q1 — Tenancy shape

- **Status:** covered by **D-021** (flat collections + `tenantId`) and **D-035**
  (guest claims, no exempt collection). Cross-reference only, no duplicate.
- **Citation:** owner directive 2026-11-12 (ADR backfill).

### Q2 — Project topology

- **Ruling:** one **fresh shared project**; Halal Boyz is tenant #1; the old
  project stays **read-only for 30 days**, then is archived.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **Consequence:** no live data mutation is authorised against the old project;
  it is frozen by ruling, which is why nothing in P1 writes to it.

### Q3 — Thermal printing stays a BLOCKED claim

- **Ruling:** thermal printing remains a **blocked claim** until the owner
  produces a path to the implementation. Receipts are the screen, the system
  print sheet, and the Stripe email.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **See also:** baseline finding G6 (`docs/BASELINE-GAP.md`) — the claim existed
  and did not.

### Q4 — Reversal authority

- **Ruling:** the **owner may always** reverse; a **manager may reverse only with
  a mandatory reason from an enum**.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **Consequence:** the reversal path needs a reason field that a manager cannot
  omit, which is a rules/server guard, not a UI convention.

### Q5 — Counter may 86 an item

- **Ruling:** the counter role **may 86 an item**, attributed and reported.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).

### Q6 — Flutter-web spike is the first Phase 2 card

- **Ruling:** the Flutter-web spike is approved as the **first Phase 2 card**,
  timeboxed to 2 days, with a fallback of a thin PWA shell reusing
  `packages/core`. Its verdict comes to the owner before any staff-UI card.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
- **Consequence:** no Phase 2 staff UI is designed before that verdict, so this
  does not affect P1.

### Q7 — Card-present market is Canada; all Phase 2 dev on the simulated reader

- **Ruling:** the card-present market is **Canada**; hardware preference is
  WisePOS E primary, WisePad 3 budget, Tap-to-Pay demo-grade. **All Phase 2
  development runs against the Stripe simulated reader in test mode**; hardware
  is a human-only gate.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).

### D-013 (resolved) — `terminalLocationId` is flat and branch-level

- **Ruling:** `terminalLocationId` is **flat and branch-level authoritative**;
  the nested acceptance form narrows in P2. This supersedes D-013's `ASSUMED`
  grade.
- **Grade:** OPTIMAL. **Citation:** owner directive 2026-11-12 (ADR backfill).
### D-045 — `*_featureFlags` stays readable before sign-in (card 7, C7-1)

- **Decision:** after the D-038 rename, the read on a settings document whose name
  ends `_featureFlags` stays available without authentication; every other settings
  document requires auth + `tenantOk()`.
- **Why (options compared):** (A) anonymous read only for flag docs costs an
  enumeration surface over six booleans the app already ships as defaults;
  (B) requiring auth for every settings read removes that surface but takes the
  flag source away from the path that arms STRICT App Check *before* login, whose
  failure mode is a tenant-wide outage. A protects information that is already
  public; B can deny service to every user of a tenant. A is chosen.
- **Grade:** OPTIMAL. **Citation:** card 7 plan (`docs/P1-04-CARD7-PLAN.md`),
  option comparison recorded there; owner instruction 2026-11-12 to decide by
  comparing options where no ruling exists.

### D-046 — the server takes the tenant for a settings read from the caller (card 7, C7-2)

- **Decision:** `functions/src` resolves a settings document through one helper
  that takes an explicit `tenantId`. Call sites that hold the order pass
  `order.tenantId`; sites with no record in hand use `DEFAULT_TENANT_ID`.
- **Why (options compared):** (A) explicit per-call tenant keeps one source of
  truth and puts the seam where the tenant is actually known; (B) keeping the
  unprefixed names for the server only creates a second config surface that drifts
  from the client's the first time an owner edits either — unacceptable for tax
  and delivery fee; (C) a process-global "current tenant" in a shared function is a
  cross-tenant leak waiting for the second deployment. A is chosen.
- **Grade:** OPTIMAL. **Citation:** card 7 plan, option comparison recorded there;
  P1-4 producer audit (`docs/P1-04-PRODUCER-AUDIT.md`) enumerates the six sites.
### D-047 — a driver document's tenant comes from its ORDER (card 8, C8-1)

- **Decision:** `deliveries/{orderId}` and `proof_of_delivery/{poid}` are scoped
  by `orderTenantOk(orderId)`: the tenant of the ORDER the document belongs to,
  not a `tenantId` field on the document itself.
- **Why (options compared):** (A) `tenantOk()` on the document, i.e. require
  `tenantId` on the delivery. The driver's GPS ping is `hasOnly(['lat','lng',
  'heading','speed','timestamp','driverId'])` and each ping REPLACES the
  document, so a migrated `tenantId` is erased by the first ping and the second
  ping is denied — a delivery outage that looks like a security win. Adding
  `tenantId` to the allowlist would also strand every deployed client that does
  not send it, and it creates two copies of the tenant that can disagree.
  (B) Scope through the order. The rule already reads `orders/{orderId}` for
  `assignedDriverId`, so the tenant check costs no extra document access, old
  clients keep working, and there is exactly one source of truth. (C) Deny
  drivers without a claim, i.e. no scoping at all until the client ships — leaves
  the collections unscoped, which is what this card exists to fix. B is chosen.
- **Consequence:** a caller whose claim has no `tenantId` is denied (fail
  closed); a document whose order is missing is denied. Neither is reachable
  from the shipped app, which carries the claim from P1-5.
- **Grade:** OPTIMAL. **Proof:** harness `c8-T1..T8` (owner read, driver write,
  and ALLOW controls against a seeded foreign order) in gate (k); isolation rows
  `deliveries` and `proof_of_delivery` ACTIVE in gate (j).

### D-048 — the branch x channel breakdown lives in the admin panel's Analytics tab (owner ruling, 2026-11-13)

- **Decision:** the P1-7 `BranchChannelBreakdownPanel` is mounted inside the
  existing admin panel — `OwnerDashboard` -> the `Analytics` tab
  (`AnalyticsSnapshot`) — instead of a new route or the dashboard's Overview tab.
- **Why (options compared):** (A) the Analytics tab. It is already the money
  view the owner opens, so a branch x channel breakdown sits beside the numbers
  it explains; no new navigation entry, no new route key in the client config,
  and the 9-tab `NavigationBar` does not grow. (B) a new top-level route
  (`/owner/breakdown`). Costs a route key in every client config, a
  `navigation.hiddenRoutes` row and a deep-link surface for one panel, which is
  the "everything is reachable in the app" goal with extra steps. (C) the
  Overview tab. It is a summary surface; the breakdown is a per-branch table
  and would displace the panic-switch banner and today's totals. A is chosen.
- **Consequence that the mount card must carry:** the panel takes data, never a
  provider (D-034), so the tab supplies it from a **bounded, tenant-scoped**
  read of the ledger rows (date window + limit). An unbounded `transactions`
  stream in a tab that every owner opens on launch is a cost bug, not a
  feature. Channel values stay untranslated data (D-034).
- **Authority is unchanged:** `OwnerDashboard` is `RoleGate({owner})`. If a
  manager or counter role should see revenue per branch, that is a separate
  owner ruling widening the gate — it is not implied by this one.
- **Grade:** OPTIMAL for navigation and blast radius; CONSTRAINED until the
  mount lands, since a built panel no surface renders is still unreachable.
- **Citation:** owner instruction 2026-11-13 ("I want everything to be in the
  app ... perhaps we can have it on the admin's view of the admin panel");
  `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart` (tab
  list + `RoleGate`); D-034 (panel derives from rows, takes data).

### D-049 — P2-0 verdict: option B, the thin shell (owner ruling, 2026-11-13)

- **Decision:** the web surface is a **thin shell reusing the Isar-free service
  layer**, not a Flutter-web port of the whole app. This closes the P2-0 halt
  recorded in `checkpoints/P2-00.md`.
- **The measurement it rests on:** `flutter build web --release` fails at 147 s
  in dart2js. `packages/core/lib/core.dart` re-exports `isar_community`, whose
  own pubspec declares platforms `android, ios, linux, macos, windows` and no
  `web`, so no build flag and no edit to the generated schema can make the app
  run in a browser. Two `minInt64` sentinels fail separately. The golden suite
  cannot run on web at all, which is the A8 fallback trigger by itself.
- **Rejected: (A) keep Flutter web** — it needs the cache seam anyway, plus the
  money-renderer fix, plus a web App Check registration, and it still leaves the
  visual gate without a golden suite. The cost is paid and the trigger is not
  cleared. That combination is what made B the stronger option, not a size
  preference.
- **Rejected: a TypeScript PWA calling Firestore directly** — it would re-derive
  money, tenancy and order-shape logic in a second language, which D-023 forbids
  ("never a fork of business logic"). Every `packages/core` service uses Flutter
  plugin packages, so "reuse the service layer" is only true inside Dart.
- **Consequences (binding on the next cards):** the shell is a second entrypoint
  in `core_app` (D-050); P2-1a must land before P2-1; the portable min-int fix is
  part of P2-1a because the shell cannot compile without it; a **web App Check
  registration is a human-only console action** and is named as the one blocker
  the shell carries toward production.
- **Grade:** OPTIMAL for the measured state; CONSTRAINED in that the shell is a
  second surface to maintain and does not reuse the Flutter goldens.
- **Citation:** owner ruling 2026-11-13; `checkpoints/P2-00.md` §3–§5;
  `~/.pub-cache/hosted/pub.dev/isar_community-3.3.2/pubspec.yaml` `platforms:`.

### D-050 — the shell is a second entrypoint in `core_app` behind an import allowlist

- **Decision:** the shell lives at `core_app/lib/shell/` and is built with
  `flutter build web --target lib/shell/main.dart`. It may import individual
  `package:core/src/...` modules but **never the `package:core/core.dart`
  barrel**, and a mechanical import-graph check enforces that. The Isar edge is
  severed by making `LocalCache` a **required** constructor parameter of
  `AuthRepository`, with the Isar-backed implementation supplied by `core_app`'s
  composition root and a no-op supplied by the shell.
- **Why the entrypoint and not a new package:** a separate app package duplicates
  Firebase init, the config/whitelabel loader and the `packages/core` pin; two
  copies drift at the first dependency bump, and the shell's whole value is that
  it is the same domain with a smaller surface.
- **Why required and not optional:** an optional `LocalCache` would let a
  construction that forgot it fall back to "no cache" — which in `core_app`
  would silently retire the sign-out cache clear that P0-07 added for cross-user
  leak prevention. P1-4 7f already ruled this shape for `TenantClaimReader`:
  make it required so the compiler names every site.
- **Why the import-graph check is not optional:** the exact defect that killed
  P2-0 was an invisible transitive edge (barrel → cache → native). A comment in
  the shell's README would not have caught it; a walk over the reachable imports
  does. The check must be shown failing once (a shell file importing the barrel)
  before it is trusted.
- **Grade:** OPTIMAL for the invariant; CONSTRAINED by a second composition root
  to keep in step with `core_app`'s providers.
- **Citation:** `packages/core/lib/core.dart:14-15`; `auth_repository.dart:300-302`;
  `docs/DECISIONS.md` D-023, D-036, D-049; `checkpoints/P2-00.md` §3.

**Web-int constraints for shared code** (`checkpoints/P2-01a-INT-AUDIT.md`): the
sweep found no new defects, and it fixed three rules so the shell cannot be
broken later — a `hashCode` may decide IN-MEMORY equality only (never a stored
key, dedupe key or cache filename, because hashes differ between VM and web); no
bitwise math on colour values (bitwise ops are 32-bit on web; colours are
declared, never decomposed); no multiplication of `microsecondsSinceEpoch`. An
int literal above 2^53 is already caught loudly by dart2js, which is how P2-0
found the class; a runtime value above it is rounded silently, which is why the
constraints above exist.

### D-051 — dietary badges are codes, and the halal CLAIM is owner-only (P6-1)

- **Decision:** menu items gain `dietary: string[]` (one fixed vocabulary),
  `allergenNotes: string`, and a flat certification triple
  `halalCertified` / `halalCertBody` / `halalCertExpiresAt`. The dietary fields
  follow today's menus write lane (owner, or manager on their own branch); the
  three `halal*` fields are **owner-only in the rules**. An expired claim renders
  no badge.
- **Why codes and not the existing `tags`:** `tags` is a comma-separated free
  text field any manager can type into (`menu_item_editor.dart:25`) and matching
  is case-sensitive on the raw string (`menu_screen.dart:165`). Putting a trust
  claim there means the badge is whatever was typed — unvalidatable, unfilterable
  and unverifiable. Codes give the filter an enumerable domain and the editor a
  closed set.
- **Why the claim is owner-only:** a manager may run a shift; a certification
  claim is the business's word to its customers. This is also the one field in
  the card where being wrong is a regulatory/religious matter rather than a
  presentation bug, so the narrower authority is the stronger invariant.
- **Why flat:** rules can name flat keys in an `affectedKeys()` check in one
  line; a nested map makes the same restriction harder to read and to test.
- **Rejected alternatives:** reuse `tags` (above); a nested `halal: {...}` map
  (harder rules, no gain); per-branch certification in v1 (schema + rules
  surface before any client needs it — named as a v1 limit in the card); storing
  English names instead of codes (untranslatable and the filter would break per
  locale).
- **Grade:** OPTIMAL for the trust invariant; CONSTRAINED in that `dietary` is
  manager-written and therefore as accurate as the kitchen — the card states that
  limit and words the badge as a declaration, not a safety guarantee.
- **Citation:** `docs/queue-P6.md` (P6-1), `core_app/firestore.rules:276-307`,
  `core_app/lib/features/admin/domain/menu_item_model.dart`,
  `core_app/lib/features/menu/domain/menu_item_model.dart`.

### D-052 — the dietary vocabulary is two axes, append-only, and pinned (P6-1)

- **Decision:** allergens and dietary suitability are **separate** code lists on
  the menu item — `allergens: string[]` (**13 codes**, verified against CFIA and
  Health Canada: eggs, milk, mustard, peanuts, crustaceans, molluscs, fish,
  sesame, soybeans, sulphites, tree_nuts, wheat_triticale, gluten) and
  `dietary: string[]` (6 codes: vegan, vegetarian, pescatarian, gluten_free,
  dairy_free, nut_free). Codes are
  lowercase snake_case, stored untranslated, **append-only** (never renamed,
  never removed), defined in exactly one Dart const, and pinned by a test.
  Filter exposure: three inline dietary chips (`vegan`, `vegetarian`,
  `gluten_free`) and one sheet offering all 14 allergens. Full spec:
  `docs/DIETARY-VOCABULARY.md`.
- **Why two axes:** one list would make "hide items containing milk" and "show
  only vegan" the same operation, and the facts are independent — a vegan dish
  can contain sesame; a gluten-free dish can contain meat. Merging them would
  force the filter to guess which direction a code means.
- **Why this list and not the obvious eight:** it is the verified Canadian
  federal list — 11 groups, with crustaceans/molluscs split for filter value —
  plus `gluten`, which Canada requires declared alongside the allergens without
  being one (barley, oats, rye, triticale, wheat). A missing allergen is not a
  data gap, it is a badge that *cannot be shown* — and the absence of a badge
  reads as the absence of the allergen. Append-only makes a later addition
  cheap; a wrong *omission* is the expensive error.
- **Corrected by research before anything shipped (2026-11-13):** the first
  proposal had 14 codes including `celery` and `lupin` (EU obligations, not
  Canadian) and one `cereals_gluten` code that conflated **wheat** — a priority
  allergen — with **gluten**, a five-grain declaration. Both are now separate
  codes and the EU-only two are gone. Nothing was stored, so this is a
  correction rather than a migration; the append-only rule starts at the first
  stored code. Sources: `docs/RESEARCH-DRAFT-dietary-regulatory.md`.
- **Why the filter offers all 14 in a sheet rather than chips:** a 390 px chip
  row cannot hold 20 codes, and filtering is the safety-shaped affordance. The
  chip row gets the three choices a customer makes before reading; the sheet gets
  the complete list so the ninth allergy is reachable.
- **Rejected alternatives:** one combined list (above); free-text allergen names
  (unfilterable, untranslatable); per-species tree-nut codes now (the append-only
  rule covers it when a regulator requires it); chips for every code (unusable at
  390 px).
- **Grade:** OPTIMAL for stability and i18n. The **list** is now verified against
  five government pages; what is **not** verified is whether any province
  requires a printed menu statement (sampled, not surveyed) — and it does not
  matter to this feature, because the federal duty is prepackaged-only, so this
  is voluntary trust, not compliance. The badge is a declaration, never a
  safety guarantee.
- **Citation:** `docs/DIETARY-VOCABULARY.md`; D-051; P6-1 acceptance items 2 and 5.

### D-053 — session cadence: run to the batch list, report only when interrupted

- **Decision (owner, 2026-11-13, standing):** a session does not stop to ask
  whether to start the next batch. It works the queue end to end — implement,
  verify, commit, next card — until the owner interrupts or the work is done.
  The only permitted reports are (a) on the owner's interruption ("what's the
  update"), (b) an OWNER-ONLY action that cannot be deferred, or (c) the queue
  drained.
- **Why:** the orchestrator rules already say "proceed by default" and "questions
  are batched, never inline", but the practice had drifted into pausing at each
  card boundary with a summary. Every pause costs a round trip and burns the
  window the owner is paying for. The rule is now explicit so a successor does
  not re-derive it from the prose.
- **What this does NOT license:** skipping RED-before-green, weakening a gate,
  running a check that proves nothing, presenting a partial card as done, or
  entering an owner-only action (money, identity, message content, channel
  arming, safeguard changes, new standing law). The cadence is about *asking*,
  never about *proof*.
- **Batching still applies to questions:** anything that would have been asked
  mid-work goes into the report/ROADMAP as a RULE-GAP or owner decision, with the
  reversible in-lane choice already made and acted on.
- **Evidence duty is unchanged:** every card still ends in a checkpoint with the
  numbers from the run that produced them (D-044), and this file is where the next
  session learns the cadence without asking.
- **Grade:** OPTIMAL. **Citation:** owner instruction 2026-11-13 ("you will fully
  utilize 120 min… the only time you report something is when I interrupt");
  `HANDOFF.md` §5 (autonomy), `orchestrator-rules` autonomy protocol.

### D-054 — the legacy "Vegan" category chip is superseded by the dietary claim (P6-1)

- **Decision:** the menu chip row keeps `All` and `Popular`; the tag-based
  `Vegan` chip is **removed**, and the P6-1 dietary filter chips
  (`vegan`, `vegetarian`, `gluten_free`) take its place. The `initialCategory`
  deep-link path still honours `Vegan` as a tag filter, so old links do not break.
- **Why:** with both present the row rendered **two chips both labelled "Vegan"**
  doing different things — one filtered `tags.contains('vegan')`, the other the
  `dietary` claim. The collision was caught by the test suite (ambiguous finder),
  not by reading the code, which is exactly what the suite is for. Two controls,
  one label, two semantics is a trap for a diner.
- **Why the claim wins:** `tags` is free text typed into a comma-separated box;
  `dietary` is a closed vocabulary validated at the write boundary and rendered
  with a badge. The authoritative one should own the visible control.
- **Accepted cost, stated plainly:** items that only carry the legacy
  `tags: ['vegan']` string are no longer reachable through the chip. That is a
  **data migration**, not a code gap, and is registered in `docs/BACKLOG-P5.md` §P6
  as the tags→codes backfill. Nothing is deleted or rewritten by this card.
- **Grade:** OPTIMAL. **Citation:** `core_app/test/features/menu/presentation/menu_screen_test.dart`
  test 6 (`Found 2 widgets with text "Vegan"`), READ the exception text at
  2026-11-14.

### D-055 — codegen is real here, but only ever with `--build-filter` (P6-1)

- **Decision:** `freezed`/`json_serializable` codegen **works** in `core_app`
  (`dart run build_runner build`, 25.9 s to 1 m 06 s). Every regeneration must be
  scoped: `--build-filter="lib/path/model.freezed.dart"` plus the `.g.dart`
  sibling for each model touched. Unpinning the generator stack is **not** needed
  and is not attempted.
- **Measured, twice:**
  - Unfiltered run: succeeded in 1 m 05 s with **1 540 actions** and rewrote
    **20 unrelated generated files**, including **deleting**
    `features/loyalty/domain/loyalty_model.g.dart` (a committed file). All 20
    were reverted with `git checkout`.
  - Filtered run: succeeded in **25.9 s, 702 outputs**, and touched **exactly the
    four intended files**.
- **Why this rule:** a tool that silently deletes a committed part file and
  rewrites twenty others makes every future diff unreviewable, and the deletion
  would have broken the build for a reason nobody could find in the diff. The
  filter turns codegen from a repository-wide event into a local edit.
- **Guard:** before committing any regeneration, `git status` must show only the
  files the card intended. If it shows more, revert and re-run with filters.
- **Grade:** OPTIMAL. **Citation:** the two codegen runs of 2026-11-14
  (`CODEGEN_EXIT=1` then `CODEGEN_EXIT=0`), with the action/output counts and the
  20-file revert recorded in `checkpoints/P6-01-MODEL-UI.md` §1.

### D-056 — platform edges are chosen by conditional export, and the checker
### evaluates them for the WEB target (P2-1a)

- **Decision:** when a shared module needs a platform-specific implementation,
  it gets a conditional export (`export 'x_io.dart' if
  (dart.library.js_interop) 'x_web.dart'`) behind a small interface, and the
  types in the public signature become platform-neutral (a typedef where the VM
  type must stay identical). The import-graph checker **evaluates conditional
  directives for a web build** instead of reading both branches as reachable.
- **Why:** the P2-0 spike named the 7 Isar files and stopped there, but the
  boundary was not actually clean — `LoggerService` imports `dart:io` **and**
  `path_provider`, and every auth path pulls it. That is a hard web compile
  error, and the first run of the new checker is what found it (24 files,
  `FORBIDDEN PACKAGE path_provider`, chain printed).
- **Why a typedef rather than a signature change:** `LoggerService({Directory?
  testDirectory})` is passed a real `Directory` at **106 call sites**. With
  `typedef LogDirectory = Directory` on the VM, all 106 compile untouched; the
  web variant is a path holder. The alternative — changing the parameter type —
  would have been a 106-line mechanical diff for zero behavioural gain.
- **Why the checker must evaluate conditions:** treating both branches as
  reachable makes every correctly-guarded file look illegal, which would have
  forced a worse design (no conditional imports at all). Evaluating them is also
  what the compiler does; the check must model the build it is protecting.
- **Hard-won caveat:** the checker's first regex rejected `show`/`hide`/`as`
  combinators, silently skipped ~90 % of directives and printed PASS with ONE
  reachable file. Any boundary check must print how much it walked, and must be
  shown failing on purpose before it is trusted. Both are now part of the tool.
- **Grade:** OPTIMAL for the invariant; the typedef is a documented compromise
  to avoid touching 106 call sites.
- **Citation:** `core_app/tool/check_shell_imports.dart` run of 2026-11-14
  (24 files → FAIL on `path_provider`; then PASS), the barrel negative proof
  (`FORBIDDEN BARREL`, `NEGATIVE_EXIT=1`), and
  `checkpoints/P2-01a-BOUNDARY.md` §3.

## D-057 — a tenant-scoped read must CARRY the tenant constraint (P2-1a, measured)

- **Decision:** every collection read in the web shell filters by the caller's
  tenant (`where('tenantId', isEqualTo: <claim>)`). Reading the collection and
  filtering client-side is forbidden, and an unconstrained list query is a bug
  even when the caller "only renders their own rows".
- **Why:** Firestore rules are not filters. `allow read: if tenantOk()` evaluates
  `resource.data.tenantId`, so a list query that does not constrain `tenantId`
  cannot be proven safe and the backend rejects it outright. Measured on the
  emulator with the app user's own ID token:
  `403 PERMISSION_DENIED — Property tenantId is undefined on object. for 'list' @ L280`,
  while the constrained form returns `200`, 2 rows.
- **Why it matters beyond the shell:** it is the rule P2-1's counter screen
  inherits. Every list surface (menus, orders, kitchen tickets) must constrain by
  tenant in the QUERY, not in the widget.
- **Grade:** OPTIMAL — the alternative (client-side filtering) does not function.
- **Citation:** `node tool/shell_proof.mjs verify` (2026-11-15) and
  `checkpoints/P2-01a-BOUNDARY.md` §6.

## D-058 — how a web-only target is proven (P2-1a)

- **Decision:** a change that only runs in the browser is proven by two channels,
  and both are pasted into its checkpoint:
  1. the **boot trace** the shell prints (`[shell] boot: …`, `claim: …`,
     `read: N row(s) in Xms → [names]`) captured from the console of a release
     build served over HTTP, and
  2. `node tool/shell_proof.mjs verify`, which asks the emulators the same
     questions from outside with the app user's ID token (claim + constrained
     rows + the denial of the unconstrained query).
- **Rejected instrument 1 — `flutter test --platform chrome`:** for this import
  graph the harness never finished loading the test (two runs, the first killed
  by the 12-minute default timeout, the second still "loading" after 10 minutes
  with an explicit 3-minute per-test timeout that never fired). A proof loop that
  cannot report a failure is not a proof, so the file was deleted rather than
  committed with a skip.
- **Rejected instrument 2 — a screenshot of the running app:** a hidden or
  minimised browser window throttles animation frames to zero, so nothing is
  drawn and no screenshot can be captured; more importantly a *read that only
  happens in `build()`* silently never runs in that state (measured: the trace
  stopped at `claim`). The claim and the read therefore moved into the boot
  prefetch, which is both observable and better counter behaviour (the screen
  opens with data instead of a spinner).
- **Grade:** STRONG for behaviour that must be witnessed; it is not a substitute
  for pixel review, which is called out as unverified in each checkpoint.
- **Citation:** `checkpoints/P2-01a-BOUNDARY.md` §6 and the console transcript
  quoted there.

## D-059 — the money ledger is RETAINED and ANONYMISED, never deleted (P2-1, verified 2026-11-15)

- **Decision:** `transactions` rows are retained for the statutory financial-record
  period. On an Art.17 erasure the row is **not** deleted: the personal
  identifiers on it (`customerId`, `staffId`, `actorUid`) are set to `null` and
  `anonymisedAt` is stamped, while `orderId`, `tenantId`, `paymentMethod`, the
  amounts and the `items` snapshot stay. A cash sale row may therefore carry
  `staffId`.
- **Why, from the code (re-verified, not remembered):** `collectUserDocs`
  (`core_app/functions/src/index.ts:307`) is the erasure set and **never includes
  `transactions`** — so today every ledger row keeps `customerId` forever with no
  erasure story at all. Deleting the row is not available: it is the taxable
  record of a sale. The repository has already set this precedent for
  `audit_log`: settings rows are *"intentionally RETAINED — legal basis:
  immutable audit proof of configuration writes"* (`index.ts:346`).
  Anonymisation satisfies both obligations at once — the taxable fact survives,
  the person stops being identifiable.
- **Consequences that are now required work:** the erasure path gains a step
  (after `eraseRefs`, call `anonymiseLedgerRows(uid)` for rows where
  `customerId`, `staffId` or `actorUid` is the uid, bounded per query and
  idempotent); and the Art.15/20 export (`collectUserData`,
  `index.ts:600`-`640`) must include the user's own rows, which it currently
  omits. Both are registered in `docs/P2-01-CASH-DECISION.md` §5.1.
- **Rejected:** delete the rows (destroys the audit trail the ledger exists for);
  keep the uids (a compliance breach on every DSAR, and it is the current state);
  put the staff uid in `customerId` (the sweep deletes `orders` by that field, so
  an employee leaving would take the sales with them — `index.ts:313`).
- **Grade:** OPTIMAL for the constraints; the ids stay as the join key to
  `orders`, and no amount ever changes.
- **Citation:** verification of `index.ts:307`, `:313`, `:346`, `:495`–`514`;
  `docs/P2-01-CASH-DECISION.md` §5.1.

## D-060 — cash callables call `assertCapability`, and a void patches, never replaces (P2-1, 2026-11-15)

- **Context:** P2-1 needs two server callables: `createCashOrder` (a sale that has
  no PaymentIntent) and `voidCashSale` (its reversal). Two questions had to be
  answered before either could be written: who may call them, and how the void
  touches the order document.
- **Decision (authority):** the capability table, `functions/src/permissions.ts`,
  is the only answer — `assertCapability(auth, 'payment.take')` to take cash
  (`owner`, `manager`, `counter`) and `payment.reverse` to void (`owner`,
  `manager`). No role string is written into a callable, and the earlier
  recommendation in `docs/P2-01-CASH-DECISION.md` Q3 (`owner|manager`) is
  recorded there as ruled against: `counter` is already a role in the table, and
  a second, narrower rule beside the enforced one is how two answers to the same
  question appear.
- **Decision (the write):** a void commits the reversal row and the order patch
  in **one Firestore transaction** (`commitVoidWithReversal`), and the order is
  patched with **`update`, not `set`**. `set` would have replaced the whole order
  document — items, totals, provenance — leaving a cancelled ticket with no
  content: a defect found by reading the code after the transaction test passed,
  which is why the assertion covers *which* method runs and not only that the
  cancellation happened.
- **Rejected:** a hardcoded role list in the callables (drifts from the table on
  the next permission change); two separate writes for a void (a crash between
  them leaves a reversed sale on a live ticket); `set` with a full document
  (loses concurrent writes and needs the whole document in hand to be correct).
- **Grade:** OPTIMAL for the constraints — one authority, one atomic write, and
  the patch carries only what the void decides.
- **Citation:** `index.ts` §12 (`createCashOrder`, `voidCashSale`, and their
  `*Core` functions); `ledger.ts` `commitVoidWithReversal`; tests
  `cash_sale.test.js` S-8 and `cash_wiring.test.js` K-1…K-5;
  `docs/P2-01-CASH-DECISION.md` Q3.

## D-061 — every role branch on an order update is key-locked, the owner's included (P2-1, 2026-11-15)

- **Context:** landing the cash ledger made the order document's money fields
  load-bearing: the immutable `sale_` row states the total and the order states it
  too, and those two must not be allowed to disagree. Reading the rule while doing
  that found `allow update` on `orders` had a
  `diff(resource.data).affectedKeys().hasOnly([...])` lock on **manager, kitchen,
  customer and delivery** — and nothing at all on **owner**
  (`firestore.rules:590`).
- **Decision:** the owner branch carries the same lock as the other roles, with the
  union of every key a client actually writes: `['status', 'assignedDriverId',
  'updatedAt']`. The set came from an inventory of all five client writers
  (`order_repository.dart:61`, `kitchen_service.dart:131`,
  `delivery_service.dart:157` and `:206`, `proof_of_delivery_service.dart:131`),
  not from taste, so no legitimate write is lost. Money and provenance keys
  (`totalCents`, `taxCents`, `items`, `paymentMethod`, `paymentIntentId`,
  `idempotencyKey`, `changeCents`, `taxRate`, `channel`, `voidReason`, …) are now
  unwritable by **every** client role; the server owns them, and the admin SDK
  bypasses rules, so `createCashOrder`/`voidCashSale` are unaffected.
  `proofOfDelivery` stays available to the delivery branch only — the owner has no
  POD flow.
- **Rejected:** leaving owner open ("owners are trusted") — the trust boundary is
  the *client*, and an owner-claimed client is still a client; a second, narrower
  rules file for the admin app — two rule sets drift and the divergence is silent;
  locking only the money keys and leaving the rest open — the next field added to
  an order would reopen the same hole with nobody noticing.
- **Proof, both directions:** the source-text contract
  (`test/rules/order_update_payload_contract_test.dart`, 10 assertions over BOTH
  rule files: every role branch has a lock, no branch may grant a money key, no
  branch grants a key with no writer, the union still covers every real payload)
  went RED naming exactly `['owner']`, then green. The behavioural harness
  (`test/rules/firestore_rules_test.js`, cases `OWN1`–`OWN3`) went RED with the
  lock removed — `OWN2: Owner rewrites totalCents → DENY — Expected request to
  fail, but it succeeded` and the same for `paymentMethod`/`changeCents` — and is
  green with it in place (`173 passed, 56 failed, 56 in baseline, 0 new`).
- **Grade:** OPTIMAL. The rule now says one thing for every role, and the money
  keys have exactly one writer: the server.
- **Citation:** `firestore.rules` + `staging.firestore.rules` (orders `allow
  update`); `test/rules/order_update_payload_contract_test.dart`;
  `test/rules/firestore_rules_test.js` `OWN1`–`OWN3`;
  `docs/P2-01-CASH-DECISION.md`.
