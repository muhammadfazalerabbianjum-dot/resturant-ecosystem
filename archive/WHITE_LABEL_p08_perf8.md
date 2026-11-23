# WHITE_LABEL_p08_perf8.md — PERF-8: DEEP VERIFICATION AUDIT

Status: PLANNED · Fleet batch · 5 worktrees + 1 coordinator (main session)
Baseline tip: `7be8e90` (= origin/main, clean). Verify before start: `git rev-parse --short HEAD`.

---

## §0 CONTRACT — read this fully before anything else

1. **Spec = acceptance contract. Code at HEAD = source of truth.** Doc comments, this file, and
   `FIX_VERIFICATION.md` are claims until verified against code.
2. **Proof law (the whole batch in one rule):** every claim you emit must carry exactly one of:
   - **P1** — a `file:line` citation you opened *in this session* (paste the relevant 1–3 lines), or
   - **P2** — a test you wrote that fails if the claim is false (name the test file + test name).
   Anything without P1/P2 goes under class `UNVERIFIED`. A VERIFIED-class finding without P1/P2 is
   **AI slop and will be rejected by the judge** with a reason; reject-count is recorded in the ledger.
3. **Six-way classification only:** `VERIFIED | UNVERIFIED | ANOMALY | UNTESTED | RISK | RECOMMENDATION`.
   Do not call something a bug because it looks unusual. Anomaly = unexpected AND evidenced AND explained.
4. **Do not re-derive ledger-known facts.** Seven waves of audits exist. If a fact is already in
   `FIX_VERIFICATION.md` (e.g. "dead shell mirror removed PERF-6c", "tax toMap bug PERF-6", "21 catch
   sites dispositioned PERF-3"), cite it as `LEDGER:PERF-n/…` — restating it as a new finding is slop.
5. **TDD applies to every fix and every new behavioral test:** red → green → refactor. The test name
   states the behavior it pins. No `test_1`, no `expect(true, isTrue)`, no `@Skip`/`skip:`, no TODO comments.
6. **Territory discipline:** you may READ anything; you may EDIT only files in your §2 row. A finding
   that belongs to another window's territory = a handoff note with evidence, not a fix.
7. **Prohibited edits:** `pubspec.lock` (hand-edit), `*.g.dart`/`*.freezed.dart` (regenerate, never hand-edit),
   `isar.dll`, `.dart_tool/`, `core_app/functions` (W3 may add tests only if stated in its row — otherwise none).
8. **One batch, one session, one window:** branch `cline/task-N`, commit prefix `p8(Wn)`, no force-push,
   worktree left clean when idle.

---

## §1 WHY THIS BATCH EXISTS (the only unverified cross-cutting claims left)

Seven waves verified components, wiring, coverage floors, and money-path behavior. What remains
unproven is cross-cutting:

- **T1 — Tenant isolation:** every Firestore/Isar query is *supposed* to be clientId/branch-scoped.
  Rules tests exist for rules; nobody has ever proven **every repository read** in code carries the filter.
  One missing `where('clientId')` in an orders query = client A sees client B's orders. Highest value.
- **T2 — Driver/tracking/location chain:** the lowest-coverage feature cluster in the repo (measure
  current values from lcov before editing). The end-to-end flow (accept → location stream → customer
  map → proof of delivery → delivered) has never been audited as a flow.
- **T3 — Concurrency/money edges:** double-submit place-order, payment-intent reuse on retry (only the
  happy idempotency path is pinned), sync-queue replay ordering, reservation last-seat race.
- **T4 — Provider lifecycle:** who is autoDispose vs keepAlive vs family is unmeasured; one known trap
  (`LEDGER:PERF-2` — autoDispose tore down a service under test). Coverage stragglers exist in
  menu_provider and reservations repo/domain — measure current values, do not trust figures quoted
  in earlier waves (they drift as waves land).
- **T5 — 100% mechanical inventory:** every file opened once and classified. Never done as a single sweep.

Perfect-8 closes T1–T5 with proof, fixes what it finds in-batch, and leaves one master map.

---

## §2 TERRITORY MAP (exclusive — no file appears in two rows)

| Window | Branch | Territory (READ all; EDIT only these) |
|---|---|---|
| W1 | cline/task-1 | `core_app/lib/**/data/*.dart` query sites + `core_app/firestore.rules` + `core_app/test/rules/*` |
| W2 | cline/task-2 | `core_app/lib/features/driver/**`, `core_app/lib/features/tracking/**`, `packages/core/lib/src/location/**`, and their existing + NEW tests |
| W3 | cline/task-3 | `core_app/lib/features/checkout/**`, `packages/core/lib/src/network/sync_queue*`, `core_app/lib/features/reservations/presentation/**` (race/stuck-button only), and their existing + NEW tests |
| W4 | cline/task-4 | every `*provider*.dart` file (sweep), `core_app/lib/features/menu/presentation/merged_menu_provider.dart`, `core_app/lib/features/reservations/domain/**` + `reservations/data/**`, and their existing + NEW tests |
| W5 | cline/task-5 | none (read-only sweep) except its deliverable CSV + any NEW test file it must add to pin a dead-code claim |
| main | — | coordinator: merges, judges, appends the SYSTEM MAP to `FIX_VERIFICATION.md`, runs Gate Set U, pushes |

Cross-territory bug found while reading (expected — e.g. W5 finds a checkout anomaly): record it as a
handoff with P1 evidence. The coordinator routes it. Do not fix across territory.

---

## §3 THE FIVE SUB-BATCHES (each window reads ONLY its row + §0/§4/§5)

### W1 — A-1 TENANT ISOLATION (T1) — *the money-adjacent one*

**Mission:** prove or disprove that every data read is client-scoped; pin it with tests that fail if a
future query forgets the filter.

**Steps (in order):**
1. Enumerate every query/read site: grep all `core_app/lib/**/data/*.dart` and
   `packages/core/lib/src/**/data/**` for `get()`/`snapshots()`/`.where(`/`collection(`. Build the list
   with `file:line` for each. Every site ends up in exactly one bucket:
   `SCOPED-CLIENT | SCOPED-BRANCH | GLOBAL-BY-DESIGN | UNPROVEN`.
2. For `GLOBAL-BY-DESIGN` (menu catalog, config): verify the rules file also treats it as readable and
   say why it is safe (no per-client privacy expectation) — P1 required.
3. For every `UNPROVEN`: read the query body. If unscoped and it touches orders/carts/reservations/
   loyalty/PoD → **ANOMALY, P0 severity**. Stop, report to coordinator immediately before fixing.
4. TDD the pin: first write a **failing** rules test — auth context of client A cannot read client B's
   `orders`, `carts`, `reservations`, `loyaltyAccounts` docs (follow the existing harness patterns in
   `core_app/test/rules/firestore_rules_test.js`). Then a **source-scan unit test** (pattern:
   `LEDGER:PERF-2/checkout_honesty_test`): asserts every enumerated query site in bucket SCOPED-* still
   exists and contains its scoping constant — a future unscoped query fails CI.
5. Fix any confirmed gap + regression test in the same commit.

**Proof required:** the bucket table (every site P1-cited) · rules test red→green transcript ·
source-scan test name. **Floors:** rules suite green incl. ≥4 new tests; analyze/format clean.

### W2 — A-2 DRIVER/TRACKING/LOCATION FLOW (T2)

**Mission:** audit the chain as ONE flow, not three folders, and lift coverage to floors.

**Steps:**
1. Deep-read with the 15 questions (§5) on: `driver_location_service.dart`,
   `proof_of_delivery_service.dart`, driver feature screens, `tracking/**` customer map,
   `packages/core/lib/src/location/**`. Trace the full chain: accept order → start/stop location
   stream → customer sees driver → PoD capture → `markDelivered` state machine
   (`LEDGER:PERF-7/W2` — it is now fail-closed; verify the guard holds from THIS side too).
   **Before editing, measure your territory's real coverage from the current lcov** — do not trust
   any percentage written in this spec (they drift as waves land); record BEFORE numbers in your
   findings file and beat them.
2. Every state transition, timer/stop condition, permission-denied path, and Firebase write gets
   P1 or is listed UNVERIFIED.
3. TDD the gaps. Behavioral, not tautological: inactive-stop writes nothing (exists — extend);
   denied permission publishes no row (exists — extend); NEW: stream restart idempotence,
   PoD on a non-deliverable order is rejected (fail-closed), status transitions reject illegal edges.
4. Floors: driver ≥75%, tracking ≥80%, location ≥80% — relative to the BEFORE numbers you measured,
   not spec-stale ones. Aggregate must not regress below its measured value.

### W3 — A-3 CONCURRENCY + MONEY EDGES (T3)

**Mission:** break the checkout/queue/race surfaces the way a real user or a flaky network would.

**Steps:**
1. Deep-read `checkout_service.dart` (intent reuse is pinned `LEDGER:PERF-2` — do not re-prove; find
   what is NOT pinned): double-submit guard on place-order, cancel-after-intent, retry-after-failure,
   tax fail-closed interplay with demo mode.
2. Deep-read `packages/core/lib/src/network/sync_queue*`: replay ORDER (FIFO? priority?), failure
   quarantine, what happens when replay runs during an active payment.
3. Reservation last-seat race: `_resolveBranchCapacity` + `_submit` under two concurrent submits —
   is the decrement transactional? If not: ANOMALY with P1, fix via transaction/fail-closed guard.
4. TDD each: double-tap place-order → exactly ONE `createOrder` call (fake callable counts);
   sync replay preserves submission order after two enqueues + one forced failure; slot-full race
   leaves zero overbooked reservations.
5. Floors: checkout ≥ its BEFORE number as measured by W3, sync package improves, reservations
   presentation covers the stuck-button regression area (`LEDGER:PERF-7/W3`) + race test.

### W4 — A-4 PROVIDER LIFECYCLE + STRAGGLERS (T4)

**Mission:** one authoritative state-management map + close the two coverage stragglers.

**Steps:**
1. Sweep EVERY provider declaration in all four packages (`grep Provider(` + `autoDispose` + `family`).
   Output a table: provider, `file:line`, mode, state held, who watches it, risk-if-disposed-early
   (cite the known trap `LEDGER:PERF-2/CF-mocks-autoDispose`). Classify each row:
   CORRECT / RISK / ANOMALY (with P1).
2. Deep-read + test `merged_menu_provider.dart` (measure its current % from lcov first): merge
   precedence, empty-category handling, availability masking, cache invalidation.
3. Deep-read + test `reservations/domain/**` + `reservations/data/**` (measure current % first):
   capacity math, slot validation, repository error paths.
4. Floors: menu_provider ≥75%, reservations repo/domain ≥80% — again measured BEFORE editing, not
   taken from this spec.

### W5 — A-0 MECHANICAL 100% INVENTORY (T5) — *breadth, not depth*

**Mission:** every `.dart` file under `core_app/lib`, `packages/{core,core_ui}/lib`,
`apps/halal_boyz/lib` gets exactly one row. NO deep reads. NO prose.

**Steps:**
1. For each file emit one CSV row (`tool_perf2/p8_w5_inventory.csv`):
   `path, LOC, public symbol count, referenced-by count (grep all 4 packages + apps/), tested-by (test file or NONE), verdict`.
2. Verdict vocabulary is CLOSED: `WIRED-TESTED | WIRED-UNTESTED | DOMAIN-PURE | DEAD-CANDIDATE | INFRA`.
   Anything else = you are editorializing; stop.
3. `DEAD-CANDIDATE` requires a repo-wide grep proving zero references (pattern: `LEDGER:PERF-6c`
   zero-importer proof). Each DEAD-CANDIDATE gets a pinning test ONLY if deletion is in-scope — it is
   NOT: deletion is a later batch; your job is the list.
4. Emit anomalies ONLY with P1 (e.g. a public symbol referenced by nothing AND untested AND not a model).
5. Floor: 100% of files classified. Compute both counts with the same command shape:
   `Get-ChildItem core_app\lib, packages\core\lib, packages\core_ui\lib, apps\halal_boyz\lib -Recurse -Filter *.dart | Measure-Object`
   vs CSV row count. Paste BOTH numbers. A gap means unfinished work, not a smaller job.
6. Only §0, your row here, §4, §8, §9 are required reading — W5 skips §5 (the 15 questions) entirely;
   its standard is the closed verdict vocabulary, not deep prose.

---

## §4 DELIVERABLE FORMAT — every window writes `tool_perf2/p8_wN_findings.md`

```markdown
# P8 W<N> FINDINGS — <batch letter> · <one-line mission restatement>
Baseline verified: HEAD <sha> at start · tips of my commits: <shas>

## FINDINGS  (ID: Wn-k, sequential)
| ID | Class | Claim (one sentence) | Evidence (P1 file:line + pasted lines, or P2 test id) | Impact | Fix commit |
|----|-------|----------------------|--------------------------------------------------------|--------|------------|

## UNVERIFIED  (MUST exist; empty is only allowed with a stated reason)
| ID | What could not be established | What would establish it |
|----|-------------------------------|--------------------------|

## CROSS-TERRITORY HANDOFFS
| To | Finding | Evidence |

## PROOF NUMBERS (filled from gates, not memory)
new tests: N (list names) · rules suite: x/x · suites touched: pass/fail · analyze: exit · format: files/changed ·
coverage of MY territory files before → after (parse the lcov, paste the numbers) · findings count: V/U/A/UNTESTED/RISK/REC
```

Rules for the table: findings ≤ 6 lines each · max 3 RECOMMENDATIONs per window (each must state impact;
no "consider refactoring" filler) · a missing UNVERIFIED section = rejected deliverable.

## §5 THE 15 QUESTIONS (for every deep-read component — W2/W3/W4 use these verbatim)

1. Where defined? 2. Who imports it? 3. Who calls it? 4. What does it call? 5. Data in?
6. Data out? 7. State it mutates? 8. External systems touched? 9. Assumptions it makes?
10. Error paths (exhaustive list, P1 each)? 11. Which tests cover it (file + test names)?
12. Which important paths have NO test? 13. Is it actually wired into the running app (trace a live
call path from `main.dart`/a screen, not just an import)? 14. Naming/structure inconsistent with
the rest of the repo? 15. What happens when its dependencies fail (firestore error, no network,
permission denied)? — Anything not answerable with P1/P2 → UNVERIFIED.

## §6 COORDINATOR PROTOCOL (main session — me. One writer, ever.)

1. **Sync:** windows start from main tip (`merge --ff-only`), end on their branch, clean tree.
2. **Merge:** `cline/task-1..5` merged sequentially into main. Windows NEVER touch
   `FIX_VERIFICATION.md` (zero conflicts by construction).
3. **Judge (the quality gate on the audit itself):**
   - Re-verify with own eyes: **100% of money/auth/isolation findings** (W1 all, W3 all, any P0),
     **≥20% random sample** of everything else.
   - Reject with a one-line reason any finding missing P1/P2, restating a ledger fact, or
     editorializing outside the closed verdict vocabularies. Rejects are recorded in the ledger —
     they are a quality metric, not an insult.
4. **Master document:** append `## VERIFIED SYSTEM MAP (PERF-8)` to `FIX_VERIFICATION.md`:
   repo overview → component map (from W5 CSV, summarized) → data-flow per feature → the five
   targets' verdicts → all cross-batch findings connected → verified/anomaly/untested/risk/residual →
   outstanding questions. Answers, with receipts: what exists, how it is wired, what is tested,
   what is fragile, what remains uncertain.
5. **Close:** full Gate Set U on merged main (analyze ×packages, format, all suites + rules, coverage
   floors, skip-greps) → commit ledger → push → report.

## §7 ACCEPTANCE — DONE means ALL of:

- [ ] Every window's findings file exists, complete per §4 (UNVERIFIED section present).
- [ ] W1: bucket table 100% P1-cited; ≥4 new rules tests green; source-scan pin test green.
- [ ] W2: driver/tracking/location each ≥ its BEFORE number as measured by W2 (targets ≥75/≥80/≥80);
      ≥3 new behavioral tests.
- [ ] W3: double-submit + replay-order + seat-race tests green (red→green shown); any fix has its
      regression test; checkout coverage ≥ its BEFORE number as measured by W3.
- [ ] W4: provider table 100% classified; menu_provider and reservations repo/domain ≥ their BEFORE
      numbers as measured by W4 (targets ≥75 / ≥80).
- [ ] W5: CSV row count == file count (both numbers pasted); every DEAD-CANDIDATE grep-proven.
- [ ] Aggregate coverage ≥ its measured pre-wave value (no regression); all suites 0 fail / 0 skip;
      analyze ×packages exit 0; format 0 changed.
- [ ] SYSTEM MAP appended by coordinator; rejects recorded; push receipt (`x..y main -> main`).

## §8 ANTI-SLOP RULES (violation = finding rejected; pattern = window's whole deliverable demoted)

1. VERIFIED claims with "appears to", "seems to", "should be", or a file you never opened.
2. Restating a ledger-known fact as a new finding (cite `LEDGER:` instead).
3. Volume padding: prose about the repo's "architecture philosophy", summaries of what coverage
   already is, or restating this spec back.
4. Tests that cannot fail (tautologies), tests without behavior-stating names, bulk trivial tests
   added to move a percentage without pinning a behavior.
5. Drive-by fixes outside territory; formatting sweeps; hand-edited generated files.
6. An empty UNVERIFIED section on a deep-read batch (W2/W3/W4). You will have unknowns; an honest
   unknown beats a confident guess. This rule is the anti-hallucination clause — the judge will
   sample-verify, and every unverifiable claim you made VERIFIED poisons the whole batch.

## §9 WINDOW QUICKSTART (paste into your agent)

```
cd <repo>-cline-N
git merge --ff-only main            # start from tip 7be8e90
cd core_app; flutter pub get; flutter analyze --fatal-infos   # exit 0 BEFORE any edit (blocker gate)
# read: WHITE_LABEL_p08_perf8.md §0, your §3 row, §4, §5 (W2/W3/W4 only), §8, §9
# branch: cline/task-N · commit prefix p8(Wn) · deliverable: tool_perf2/p8_wN_findings.md
# red→green for every new test · leave tree clean · report to coordinator
```


