# P1-4 tenancy — orchestrator brief

Branch: `cline/p32-golden-gates`. Nothing pushed, nothing deployed, no real
Stripe/Firebase calls. Every commit below was green before it was committed.

## Where the work stands

| Area | State |
| --- | --- |
| Rule paths with a tenant scope | 32 of 32 ACTIVE (28 top-level, 4 nested) |
| Rule paths still PENDING | 0 |
| Rules harness | 165 passed, 56 known-failing, 0 new |
| Full battery | 11 gates ran, 0 failed (a 162.9 s, b 317.1 s, c 10.7, d 13.4, e 1.8, f 0.0, i 1.6, g 12.0, h 0.9, j 23.7, k 15.7) |
| Client reads/writes of settings | all tenant-keyed (`settings/<tenant>_<name>`) |
| Server reads of settings | one helper, explicit tenant |
| Ownership (`isOwner`) | reads `settings/<tenant>_ownerInfo` |

Card 7 (settings, admins, audit) and card 8 (deliveries, proof of delivery) are
complete. The 56 harness baseline entries are unchanged: none became fixed, so
nothing was pruned and no expectation was relaxed to make a change pass.

## Decisions taken without a prior owner ruling

Each is recorded in `docs/DECISIONS.md` with its grade and the option it beat.

**D-045 — `featureFlags` stays readable before sign-in.** Making it owner-only
would remove the only pre-login App Store Check arming source; the failure mode
is a tenant-wide outage. The document is six booleans that already ship in the
app. Option A (keep) chosen over B (gate).

**D-046 — the server resolves settings through one helper with an explicit
tenant.** `settingsDoc(name, tenantId)`. Rejected: a second unprefixed server
config surface (drifts from the client's the first time an owner edits either —
unacceptable for tax and delivery fee) and a process-global "current tenant"
(cross-tenant leak waiting for the second deployment).

**D-047 — a driver document's tenant comes from its order.** This is the one
worth the orchestrator's scrutiny, because the rejected option looks safer:
adding `tenantId` to `deliveries`. The driver's GPS ping is `hasOnly([...])` and
*replaces* the document, so a migrated `tenantId` is erased by the first ping and
the second ping is denied — deliveries stop, and the change reads as a security
win. Scoping through the order costs no extra document read (the rule already
fetches that order for `assignedDriverId`), keeps deployed clients working, and
leaves one source of truth.

## What proving it required

- **Gate (k) is a ratchet, not a pass/fail.** It caught two real defects during
  this work: a combined `allow write` on `admins` denied every new admin row
  (`tenantOk()` inspects the existing document; a create has none), and a
  harness assertion that deleted `settings/ownerInfo` while the rule had moved
  to the tenant document — it was asserting against a document nobody read.
- **Allow controls are what make the denials meaningful.** The isolation suite
  asserts tenant A *can* read its own document; without that, rules that deny
  everything would score as isolation. The owner principal was added for exactly
  this reason: a customer token is denied `admins` by role, so the denial would
  have passed without tenant scope being consulted.
- **`userRole()` reads the user document, not the token.** The first owner
  principal had no `users/{uid}` row, so its ALLOW controls failed while every
  DENY passed. The probe now seeds that row. This is the failure mode the brief
  asks the orchestrator to assume is still possible elsewhere.

## Deliberate limitations (not defects)

1. **Signed-in clients must carry a `tenantId` claim.** Rules fail closed
   without one. Claims ship from P1-5; an old token is denied until re-login.
2. **`hasAppId()` may be effectively always-false in production.** It needs one
   real ID token to confirm — human-only, and not done here.
3. **Legacy unprefixed settings writes still exist for embedding/tests.** Panic
   switch, checkout and the repos use the claim when they have one; constructing
   them without a claim reader keeps the old path. Production providers always
   supply one.
4. **Some Dart tests still seed unprefixed settings documents** into
   `FakeFirebaseFirestore`. They pass because the fake ignores rules and the
   repo falls back, but they no longer exercise the path production uses.
5. **The migration has dry-run proof, not a live run.** `v004` is generic over
   `settings/*` (so `ownerInfo` rides it), default is dry-run, second run plans
   zero. It has never been executed against a real project.
6. **No deployment and no visual check.** Nothing was published; the Flutter
   screens were not viewed in a browser.

## Open questions for the orchestrator

1. **Should the legacy unprefixed settings path be retired outright?** It exists
   for embeddings/tests only. Retiring it removes a second write path but breaks
   any embedder that constructs these services without a claim reader.
2. **What is the intended fate of the 56 harness baseline failures?** They are
   pre-existing and unchanged; fixing them is a separate card, and leaving them
   means the harness cannot distinguish a new regression in that area from the
   known state.
3. **Ordering: claims (P1-5) before or after the next tenancy card?** Rules now
   deny any caller without a `tenantId`, so a deployment before claims ship
   would deny real users.
