# HANDOFF — start here

This is the entrypoint for any session that takes over this repository. It holds
the current measured state, the next action, and the rules the engineer operating
it works under. It is written so that **no chat history is needed**: if you can
read this file and run two commands, you can continue.

Last updated: 2026-11-13, after the P2-0 web-spike measurement and the C-4
fix. Branch `cline/p32-golden-gates`. Nothing pushed. Nothing deployed.

---

## 1. Read order

1. **`HANDOFF.md`** (this file) — state and next action.
2. **`ROADMAP.md`** — every unfinished batch with its acceptance criterion.
3. **`docs/DECISIONS.md`** — every standing ruling. This is the only in-repo
   citation authority; a decision lives there or it does not exist.
4. **`docs/INCIDENT_LEDGER.md`** — failure classes and their four layers.
5. **`docs/ORCHESTRATOR_HANDOFF.md`** — the product spec (self-contained).
6. The checkpoint for the card you are about to touch (`checkpoints/P1-*.md`).

Do not re-derive what those files decide. Do not cite a document that is not in
the tree.

---

## 2. Verified state (measured, not recalled)

Command: `node tool/gate.mjs check` (the wrapper's own body; `gate.cmd check`
is the same runner) — **PASS, 11 gates ran, 0 failed, 0 unavailable, 0
not-active**. Receipt `checkpoints/gate-20261113T120949Z.md`.

Gate (l) `licence-claim-scan` was added on 2026-11-23, after that receipt: run
`node tool/gate.mjs check --only=l` on its own (PASS, and red on its plant in
`gate_config.json`), so the next full run is the first 12-gate receipt.

| Gate | Check | Time |
| --- | --- | --- |
| a | dart-analyze | 163.9 s |
| b | gate-fast-tests | 238.7 s |
| c | functions-build | 20.3 s |
| d | emulator-rules | 38.1 s |
| e | whitelabel-dry-run | 6.7 s |
| f | stub-scan | 0.0 s |
| i | tenant-isolation-generator | 1.2 s |
| g | functions-coverage | 18.8 s |
| h | backend-parity | 1.0 s |
| j | tenant-isolation-emulator | 21.9 s |
| k | rules-harness | 20.1 s |

Tenancy: **32 of 32 rule paths ACTIVE, 0 PENDING-TENANCY** (28 top-level + 4
nested). Harness: **165 passed, 56 known-failing, 0 new**.

Verify any of this yourself before trusting it:

```bash
node tool/gate.mjs check                 # the 12 gates (same runner as .\gate.cmd check)
core_app> dart run tool/gen_tenant_isolation_tests.dart --check
node tool/rules_harness.mjs               # prints "… passed, … failed, … in baseline, N new"
git log --oneline -5
```

A green battery is the floor, not the proof. The proof for a card is its
checkpoint, with the numbers pasted from the run that produced them.

---

## 3. Where the work stands

**P1 is complete** (P1-1 … P1-8). Card P1-4 (tenancy) finished in the prior
session: settings, admins, audit_log, audit_logs, deliveries and
proof_of_delivery are all tenant-scoped; ownership itself resolves
`settings/<tenant>_ownerInfo`; the legacy unprefixed settings path is gone and
the services **require** a claim.
Evidence: `checkpoints/P1-04-STEP7.md`, brief `docs/ORCHESTRATOR-BRIEF-P1-04.md`.

**P2-0 (Flutter-web spike) is measured and halted** — `checkpoints/P2-00.md`.
`flutter build web --release` **FAILS** (147 s, dart2js): `packages/core`'s
barrel exports `isar_community`, which declares no web platform, plus two int64
sentinels (`core_ui/.../money_text.dart:51`, `lib/app/config/currency_format.dart:48`).
First paint and Firebase JS interop are **unmeasured** — there is nothing to
run. Recommendation: the A8 fallback shell. The A/B choice is the owner's.

**C-4 is closed at the cause.** The three "pre-existing" failures were stale
fixtures, not product code: the flags test omitted the required `tenantId` (so
W6.5 rejected the whole load and the test measured a schema failure), and the
tax-tab suite seeded the retired unprefixed `settings/taxRates` with no tenant
claim. 11/11 pass now.

Decisions taken in the final stretch, each with its rejected alternative:
- **D-045** `featureFlags` stays readable before sign-in.
- **D-046** one server helper resolves settings, with an explicit tenant.
- **D-047** driver documents take their tenant from the ORDER, not from a
  `tenantId` field the GPS ping would erase.

**Open, none of them hidden** (see `ROADMAP.md` §Carry):
- C-1 `hasAppId()` may be always-false in production — needs one real ID token.
- C-2 live migration never executed — **owner-only** action.
- C-3 56 known harness failures — the harness cannot see a regression inside
  that set (re-measured this session: 165 passed, 56 failed, 56 in baseline, 0
  new — still exactly the blind spot).
- C-4 **CLOSED** (this session) — see §3.
- C-5 some Dart fakes still seed unprefixed settings documents.
- C-6 the P1-7 owner panel is built but not mounted. **Placement ruled**
  (D-048, 2026-11-13): it goes in the admin panel's Analytics tab
  (`OwnerDashboard` → `AnalyticsSnapshot`) behind a bounded, tenant-scoped
  ledger read — not a new route, not the Overview tab, and the owner-only
  `RoleGate` is unchanged.
- C-8 whole-tree suboptimal-engineering audit — owner-scheduled, runs after
  P2-1 lands; findings enter the ROADMAP with acceptance criteria, not as taste.
  See `ROADMAP.md` §Carry.

---

## 4. Next action

**P2-1a is DONE** (`checkpoints/P2-01a-BOUNDARY.md`): the shell builds for the
web (BUILD_EXIT=0, main.dart.js 2.45 MB, FCP 519 ms warm / 9018 ms cold), boots,
signs in against the emulators, reports `tenant_shell`, and ONE bounded read
returns exactly that tenant's two rows. D-057: every list read must carry the
tenant constraint in the QUERY.

**P2-1 (Counter/POS) is UNBLOCKED, and its server half is DONE and proven.**
The premise that blocked it — a cash sale has no server path — is closed:
`createCashOrder` re-prices every line from `menus`, takes tax and currency from
`resolveChargeTaxAndPromo` (the seam the card path charges with, now
tenant-aware), and commits the order plus its `sale_` row in ONE transaction under
an idempotency key scoped to the caller. `voidCashSale` commits the reversal row
and the cancellation together, patching the order with `update` (D-060:
`assertCapability` decides authority; `payment.take` = owner/manager/counter,
`payment.reverse` = owner/manager). Ledger v2 rows are retained and anonymised on
DSAR, never deleted (D-059).

Measured, from the run that produced it: `node tool/cash_proof.mjs` against the
emulators — **34/34 checks, `CASH PROOF OK`**: one create → `#0002`, total 2436 ¢
(2250 subtotal + 186 tax at 8.25 %), change 564 ¢, exactly one order and one
`sale_` row; replay → same order, `idempotent: true`, no new order or row;
cross-tenant void → `not-found`; void → order `cancelled` with its money and
lines intact, `rev_sale_…` at −2436 ¢, two rows for the order, second void
refused. Unit lane 271/271; `eslint src` clean. The proof caught a real gap and it
is fixed: `verifyMenuPricing` requires the unit price the counter displayed, so
lines carry `priceCents` as a stale-ticket guard only — the money still comes from
the menu.

**What remains on P2-1 before it is DONE:**

(a) **DONE — D-061.** The owner branch of `allow update` on `orders` was the one role
clause with no `affectedKeys().hasOnly(...)`, so an owner-claimed client could rewrite
`totalCents`/`paymentMethod` on an order whose ledger row disagreed. It now carries the
union of the five real client writers, in both rule files. Proven both ways:
`order_update_payload_contract_test.dart` went RED naming exactly `['owner']` then green
(10 assertions per file), and harness `OWN2`/`OWN3` went RED with the lock removed
(`Expected request to fail, but it succeeded`) before `173 passed, 56 failed, 56 in
baseline, 0 new`.

(b) **DONE — the D-057 query pass.** Every tenant-scoped list read now carries the
constraint in the QUERY: `analytics_provider.dart` (2), `admin_data_service.dart` (5),
`kitchen_service.dart` (1), `delivery_service.dart` (2), `revenue_chart_widget.dart` (1),
`data_export_service.dart` (3, including the GDPR export's reservations and waitlist). Each
resolves the caller's claim through one reader and THROWS when there is none, so a
misconfigured session is visible instead of rendering an empty board. Measured per subtree:
admin 342/342, kitchen 58/58, delivery 21/21, driver 29/29, export + profile 12/12,
analytics 13/13, rules contract 20/20, ticket goldens 4/4. The tree still has red tests —
auth cache (2), reservations (6), waitlist (3), splash (1), p16/p21 goldens (2) — and they
fail identically on the previous commit (checked by stashing this work and re-running), so
they are pre-existing debt, not regressions from this pass.

(c) The shell counter surface, which now has a callable to call (C-6: no cart without a
submit path — that path exists now).

Harnesses: `node tool/shell_proof.mjs up|verify|down` (free ports, seeded tenant +
decoy) for the tenancy proof, and `node tool/cash_proof.mjs` for the money round
trip (needs the emulators from `up`). D-058 records why console traces and these
scripts are the proof channels rather than `flutter test --platform chrome`
(which never loads this graph) or a screenshot (a hidden tab draws nothing).

**Then P2-3 (Kitchen Display)** — it reads existing `orders` and advances status,
so it needs no money ruling; the reorder and its reason are recorded in
`docs/queue-P2.md`.

One human-only action is already known: a **web App Check registration**
(registered web app + reCAPTCHA-family provider). Emulator work does not wait
on it; the deployed shell cannot write without it (D-036).

**Also done, and independent of the shell:** `docs/queue-P6.md` **P6-1**
(halal/dietary trust layer) is **CODE-COMPLETE** (`checkpoints/P6-01-MODEL-UI.md`
+ `checkpoints/P6-01-RULES.md`; full battery `checkpoints/gate-20261114T134809Z.md`).
Menu items carry 13 declaration codes and 6 dietary codes on both projections,
validated at the write boundary; customers see badges (an expired certification
renders nothing) and filter by three dietary chips plus a 13-code allergen sheet;
the owner-only halal claim is editor-gated AND rules-enforced.

**The codegen blocker was a myth, and is now settled by measurement (D-055):**
`build_runner` works here. It must be run **filtered** — an unfiltered run rewrote
20 unrelated generated files and deleted a committed `.g.dart`. Never unpin the
stack; always pass `--build-filter` for each touched model.

**What P6-1 left behind, deliberately not done:** the tag-based `Vegan` chip is
superseded by the dietary claim (D-054), so items marked only with the legacy
`tags: ['vegan']` string need a backfill that **rewrites stored documents** —
that is owner-authorised work, registered in `docs/BACKLOG-P5.md` §P6-1 follow-ups
along with the certification-expiry reminder.

**The shell is DONE** — `docs/queue-P2.md` **P2-1a**, battery
`checkpoints/gate-20261114T150203Z.md` for the boundary slice and the gate
receipt quoted in `checkpoints/P2-01a-BOUNDARY.md` for the emulator proof.

- `LocalCache` is a **required** parameter of `AuthRepository` (28 + 12 sites
  named by the compiler); mobile passes `IsarLocalCache`, the shell
  `NoOpLocalCache`.
- The min-int guard is a **predicate** (`isMinInt`), not the dart2js-hostile
  literal, and both renderers share it.
- `core_app/tool/check_shell_imports.dart` walks the shell graph and **fails on
  the core barrel, Isar, `dart:io` and `path_provider`**. It was proved failing
  on purpose before it was trusted.
- **It found a native edge P2-0 missed:** `LoggerService` imports `dart:io` +
  `path_provider`, and every auth path pulls it. Severed with a conditional
  sink (file on VM, bounded memory buffer on web) and a `LogDirectory` typedef,
  so 106 existing call sites are untouched (D-056).
- **`flutter build web --release --target lib/shell/main.dart` → BUILD_EXIT=0,
  54.7 s, main.dart.js 2.4 MB.** The P2-0 blocker is gone.

**Emulator proof (item 4), on the final build:**
`[shell] signIn: done counter@shell.test` → `[shell] claim: tenant_shell` →
`[shell] read: 2 row(s) in 52ms for tenant_shell → [Proof Shawarma, Proof Falafel]`,
and `node tool/shell_proof.mjs verify` → constrained 200 / 2 rows, unconstrained
**403 PERMISSION_DENIED**. Three defects were found and fixed by running it
(unconstrained read; read inside `build()`; stale restored session); §6c.

**Not verified:** the signed-in panel's pixels (the browser window was
minimised for the whole run, so no screenshot exists) and a second account's
isolation in a browser. Both are named in `checkpoints/P2-01a-BOUNDARY.md` §6d
rather than implied to be covered.

If the owner prefers carry work first, C-3 and C-6 are the two that cost the
most credibility if left: C-3 is "green that cannot see its own failure", C-6 is
a built panel no user can reach. C-1/C-2/C-7 remain blocked on human-held
tokens, a scratch project, and owner-only actions respectively.

---

## 5. How the engineer works here

**Authority.** Everything reversible, in-repo, and decidable by a written rule or
a measurement is decided and executed without asking: fix it, pin it with a test,
record it.

**Owner-only, never decided alone.** Anything that changes what gets sent, to
whom, or from which account; spending money; rewriting lead identity or owner
copy; weakening any gate, pin or standing law; disabling a safeguard; creating a
new standing rule that outlives the session. A situation matching no rule is a
RULE-GAP: act only if reversible and in-lane, ledger the gap, batch the
questions.

**Research.** External facts are not guessed and not silently web-searched: write
a RESEARCH DRAFT (question, why it matters, current belief, what needs
verifying), get owner approval, then research.

**Quality law.** TDD, RED before green. Evidence over claims — every claim names
where it can be checked. Loud failures, never silent. Gates fail closed. A check
that cannot fail is a defect. When two designs exist, take the one with the
stronger invariants and say why in the commit. No TODO-shaped debt: unfinished
work enters `ROADMAP.md` with an acceptance criterion.

**Session end.** (1) full gate green, or honestly RED with reasons; (2) a
deliberate self-review of every module touched, hunting anomalies rather than
green; (3) ledger rows for new failure classes with all four layers; (4) ROADMAP
updated; (5) explicit commits, one per green step, card id in the subject.

---

## 6. What this session's engineer cannot execute

Stated plainly, so no successor assumes otherwise:

- **Creating a new standing rule** — that is owner-only. Records written here
  (ROADMAP, INCIDENT_LEDGER) are records, not new laws.
- **Money, identity, message content, channel arming, weakening a safeguard** —
  none touched, all out of scope without an owner ruling.
- **Real-project actions**: creating the new Firebase project, running the
  migration live, Stripe Connect setup, reader purchase/registration, thermal
  printing path. All human-only.
- **The web-spike verdict** itself is the owner's; the engineer produces the
  measurement and recommendation, not the choice.
- **A visual check of the Flutter UI** — no browser surface was used for it in
  this session; screens were verified by widget tests only.

If a future session finds this file stale, the measurement wins, not the prose.
