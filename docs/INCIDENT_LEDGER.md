# INCIDENT LEDGER — mistake register

Every class of failure that actually happened in this repository, with its four
layers. A row exists to stop the same class from recurring, not to assign blame.
Rows are records of what was learned; they are not new standing laws (that is an
owner decision).

Legend for the layers:
- **Prevention** — what stops it being written.
- **Detection** — what turns it red if it is written anyway.
- **Recovery** — what makes the damage reversible.
- **Owner control** — what the owner can see or veto without reading code.

---

## I-1 — A rule authorized a document name the app no longer used

**What happened.** `settings/restaurantConfig`, `/taxRates`,
`/defaultOperatingHours` had literal `match` blocks. D-038 renamed the documents;
the literal blocks kept authorizing the OLD names, so an owner write could land
in a document nothing reads. Two documents drift, one of them empty forever.

**Prevention.** The rename and the rule change are one card (7c), and the
retirement step deletes the literal blocks rather than leaving them "for
compatibility".
**Detection.** `isOrdersAccepting()` and the shape checks moved into the generic
block; gate (k) fixtures exercise the tenant-keyed names, so an unreadable
document fails a test rather than a customer.
**Recovery.** The retired blocks are one `git revert` of a single commit;
migration v004 is dry-run-first and idempotent.
**Owner control.** `docs/ORCHESTRATOR-BRIEF-P1-04.md` states the drift risk and
the commit that closes it.

---

## I-2 — A panic switch that reads a dead document fails OPEN

**What happened.** `isOrdersAccepting()` read the literal
`settings/restaurantConfig`. After the rename that document is gone, and "absent
= accepting" is the legacy default — so pausing orders would have done nothing.

**Prevention.** The switch reads the tenant's document through the same helper as
everything else (`tenantRestaurantConfigDoc()`), with the "no claim" legacy
default stated explicitly.
**Detection.** A panic-switch integration test asserts the toggle flips the
document the checkout guard reads (`checkout-guard parity`).
**Recovery.** Toggle is a merge-write on one document; re-open is one tap.
**Owner control.** The dashboard banner is the visible state; the parity test is
the reason to trust it.

---

## I-3 — A read exception published the owner's email to customers

**What happened.** The generic settings read allowed any tenant-prefixed document
to any signed-in user, which included `settings/<tenant>_ownerInfo`.

**Prevention.** `isOwner()` resolves the owner document server-side; clients never
need it, and the read rule now excludes `*_ownerInfo`.
**Detection.** Harness `T-E3` asserts a customer is denied it.
**Recovery.** No data left the emulator; the rule never shipped.
**Owner control.** Stated in the brief as a deliberate exception with its reason.

---

## I-4 — `tenantOk()` on a create denies every new row

**What happened.** `allow write: ... && tenantOk()` was applied to `admins`.
`tenantOk()` inspects the EXISTING document; a create has none, so every new
admin row was denied.

**Prevention.** Tenancy checks are split `create` (`tenantOkCreate()`) from
`update`/`delete` (`tenantOk()`).
**Detection.** Gate (k) reported it by name as a NEW failure:
`t78-CTL10: flagged owner writes admins -> ALLOW`.
**Recovery.** One rule change; no data affected.
**Owner control.** This is the argument for the harness being a gate, not a
script.

---

## I-5 — An allow-control that could not pass for the right reason

**What happened.** The isolation probe gained an owner principal. Its ALLOW
controls failed while every DENY passed, because `userRole()` reads the USER
DOCUMENT, not the token — the synthetic owner had no `users/{uid}` row. Without
the allow control, the row would have "proved" isolation by denying everything.

**Prevention.** Every isolation row with a same-tenant control must assert ALLOW;
a row that can only deny is marked `sameTenant: none` WITH a written reason.
**Detection.** The allow control itself.
**Recovery.** Probe seeds the user document; the row then passes both ways.
**Owner control.** Registry counts (ACTIVE vs PENDING) are reported, never
inflated: a skipped row is visible as a skip.

---

## I-6 — A fake that stopped matching what it claimed to test

**What happened.** Two cases, same class:
(a) the operating-hours suite used a fake ruleset naming
`settings/defaultOperatingHours`; after the rename it matched nothing, so the
"denied save" case still passed — for the wrong reason;
(b) a harness assertion deleted `settings/ownerInfo` and expected an owner write
to fail; the rule had moved to the tenant document, so it was asserting against a
document nobody reads.

**Prevention.** Fixtures name the document the production code reads; a rename
greps its own fixtures in the same commit.
**Detection.** Gate (k) named (b) directly (`b11-T5b`); (a) was caught by reading
the fake rather than trusting the green.
**Recovery.** Both fixtures rewritten against the live path.
**Owner control.** Recorded here so "it was green" is never accepted as "it was
tested".

**Recurrence (2026-11-13, ROADMAP C-4).** The same class twice more, both
carried for weeks as "three pre-existing Dart failures":

1. `test/core/feature_flags_test.dart` named an *orphan-key tolerance* case and
   asserted `loadFailed == false`, but its fixture had no `tenantId` — a required
   config field since P0-6. The W6.5 schema therefore rejected the whole load and
   the test failed at the assertion above the behaviour it claimed to cover. The
   test had stopped measuring orphan tolerance at P0-6 and nothing said so.
2. `restaurant_setup_tax_tab_test` seeded and asserted the RETIRED unprefixed
   `settings/taxRates` and supplied no tenant claim, so the repository correctly
   refused to read or write (D-038). It was red for the right reason (the code
   moved) and green in nobody's interest.

**What this adds to prevention:** a red test is not automatically "stale, ignore
it". The distinguishing question is whether the failure is at the assertion the
test is named for or above it. Both were above it, and both were recorded as
"pre-existing" instead of diagnosed — which is how a fixture reaches the state
this entry already described.

---

## I-7 — Generation-time string interpolation broke the generated suite

**What happened.** A registry `why` string contained `${tenantId}_${name}`. The
generator emits it verbatim into Dart, where `${...}` is interpolation → the
generated suite did not compile.

**Prevention.** Registry prose avoids `${`; the generator escapes registry
strings before emitting them.
**Detection.** Gate (j) compiles the generated suite before running it.
**Recovery.** Reworded; regenerate; gate re-run.
**Owner control.** `dart run tool/gen_tenant_isolation_tests.dart --check` is
part of gate (i) and cannot be satisfied by hand-editing the output.

---

## I-8 — Shell heredocs silently mangled the work

**What happened.** Three times: a Python heredoc lost a backslash (unterminated
string), and a large heredoc was truncated. Twice the partial script had already
written files before failing.

**Prevention.** Multi-line scripts are written to a file (`write_file`) and run;
heredocs only for one-liners without backslashes.
**Detection.** The script's own `assert` on every anchor, before writing; a
non-zero exit is visible.
**Recovery.** `git checkout -- <paths>` for the touched test files, then re-apply.
**Owner control.** Commits are per green step, so an interrupted edit never spans
a verified state.

---

## I-9 — The harness baseline hides regressions in its own area

**What happened.** 56 assertions have been failing since before P1-4 and are
accepted as a baseline. The gate is a ratchet: new failures fail, but a
regression among those 56 areas is indistinguishable from the known state.

**Prevention.** None yet — this is a known blind spot, not a solved one.
**Detection.** None in that area.
**Recovery.** `core_app/test/rules/known_failures.txt` is the list; it can be
pruned or worked down.
**Owner control.** ROADMAP C-3 tracks it with an acceptance criterion (baseline
reaches 0 or each entry is replaced by a justified expectation).
