# P1-4 step 7 — settings, ownerInfo, admins, audit (D-038)

Plan and open decisions: `docs/P1-04-CARD7-PLAN.md` (C7-1, C7-2, recorded as
D-045/D-046). Reader and producer inventory: `docs/P1-04-PRODUCER-AUDIT.md`.

## 7a — settings rename planner (`40ba119e`)

`planSettingsRename` copies `settings/{name}` to `settings/${tenantId}_{name}`,
stamps `tenantId`, and refuses a document claimed by another tenant. It is a COPY
per D-038, and an already-migrated pair is `unchanged`, which is what makes a
second run plan zero writes while the source is still present for rollback.
Wired into `migrate()` after the field backfill (D-041 ordering applied to
configuration: a copied settings doc never lacks its tenant).

Proof: `tsc` clean, `eslint` clean, `node --test test/migrations.test.js` → 14
pass (M-11…M-14 new).

## 7e — branch and menu creation was denied (producer audit finding)

`AdminDataService.saveBranch` / `saveMenuItem` used `.add(data)` with no
`tenantId`, while `branches` and `menus` have required `tenantOkCreate()` since
step 5b — so creating a branch or a menu item from the admin UI was a hard denial.
Both creates now stamp the claim, and the claim wins over anything in `data`.

- `AdminDataService` takes an optional `TenantClaimReader`; the provider passes
  `tenantClaimProvider`. When no reader and no claim exist the create throws a
  named `StateError` instead of becoming a silent permission error.
- `admin_data_service_test` asserts the created document carries `tenantId`.

Proof: focused suite (admin domain + menu manager) 27 tests pass; analyze clean.

## 7b(1) — restaurant config and tax rates (`e02caac8`)

`settingsDocId(tenantId, name)` is the single definition of D-038's naming rule.
Both repositories take a `TenantClaimReader` and resolve their own document, so no
screen or call site changed shape:

- `RestaurantConfigRepository.streamConfig` yields the model's documented defaults
  when there is no claim (identity before login is bundled config), and `save` /
  `patch` throw instead of writing to a guessed document.
- `TaxRatesRepository.streamClientRates` yields `null` when there is no claim (the
  server's documented fallback applies, as the setup UI already states); a write
  without a claim throws.

Proof: (a) 46.3 s PASS, (b) 261.9 s PASS, plus the two touched suites (11 tests).

## Blocker found in 7b(2): the panic switch's production construction

`PanicSwitchService` reads `settings/restaurantConfig` and `CheckoutService`
constructs it as `panicSvc ?? PanicSwitchService(firestore: firestore)` — a
production path with no claim in hand. Threading the claim through means either
giving `CheckoutService` a claim reader (and every screen-test construction that
builds it) or letting the panic switch read a document it cannot name correctly.
Both are real; neither should be improvised late in a session, and the switch gates
order creation, so a wrong answer takes ordering offline. 7b(2) therefore starts
with `CheckoutService`'s construction graph, not with the panic switch file.

The same question decides `settings/featureFlags`: D-045 permits an anonymous read,
but a signed-out client cannot derive a tenant-prefixed name, so the pre-login flag
source needs either a bundled tenant id or a deliberate exception recorded as a
decision. `featureFlags` stays on its unprefixed name until that is settled, which
means 7c's rules must allow it explicitly.

## 7b(2) — the panic gate reads the tenant-keyed config

`PanicSwitchService` takes a `TenantClaimReader`. With one, it reads
`settings/${tenantId}_restaurantConfig`; with none (older tests and embedding) it
keeps the pre-tenancy path, and the production provider always passes one.
`CheckoutService` gained the same optional reader and forwards it when it builds
the gate, which is what closes the construction seam recorded above.

Proof: a new test writes the unprefixed document OPEN and the tenant document
CLOSED, then asserts the gate reads CLOSED — so it fails unless the claim really
decides which document is read. Panic suites 14 pass; (a) 30.1 s PASS; (b) 344.4 s
PASS.

## 7c must now carry a rule change or the app regresses

Tracing the rules after 7b(1) exposed a consequence that only a rule change fixes:
`settings/{doc}` currently grants read to `doc == 'featureFlags'` or `isOwner()`,
so once a customer reads `settings/${tenantId}_restaurantConfig` the generic block
DENIES it. Local `fake_cloud_firestore` tests do not evaluate rules, and gate (d)
seeds only the unprefixed documents, so nothing in the current battery would have
caught this.

7c therefore has to, in one commit:

1. grant authenticated read of a tenant-prefixed settings document to that tenant
   (`tenantOk()` unchanged for the field, plus a doc-name prefix check),
2. keep writes owner-only,
3. retire or reconcile the three literal match blocks so the prefixed path is the
   live one,
4. seed the harness with prefixed settings documents and assert the read for a
   non-owner, or the regression ships untested.

## 7c(1) — a tenant reads its own prefixed settings documents

`settings/{doc}` now grants read of `settings/${tenantId}_...` to that tenant's
signed-in users, keeps writes owner-only, and refuses an owner writing another
tenant's prefix. `isTenantSettingsDoc(docId)` is the one prefix test; `featureFlags`
keeps its unprefixed name and its read (D-045). The three literal blocks stay for
the legacy documents until the rename is applied.

Harness cases T-E5 (four): own prefix ALLOW, other prefix DENY, customer write
DENY, owner cross-tenant write DENY. All four pass.

### A false green worth recording

Gate **[d]** is `node ../tool/emulator_probe.mjs`: it compiles and loads the rules
and checks two basic auth facts. **It does not run `test/rules/firestore_rules_test.js`.**
That harness is `npm run test:rules` (Firebase `emulators:exec`), which no gate in
`gate_config.json` selects. Consequence: a new harness assertion is unverified by
gate (d), and I found this the hard way — a deliberately inverted assertion stayed
green because the block never executed (it referenced an undefined `admin` and
would have thrown). After fixing it to seed through
`testEnv.withSecurityRulesDisabled`, the four cases ran and passed.

Measured in the same ad-hoc environment (firestore emulator on 8080, no auth
emulator):

| rules | passed | failed | total |
|---|---|---|---|
| committed HEAD | 149 | 60 | 209 |
| with 7c(1) | 157 | 56 | 213 |

No new failure appears; the four T-E5 cases pass. The 56 remaining failures are
stale or environment-dependent expectations that predate this change (the same
suite shows 60 without it).

### Gate (k) now owns the harness

`gate_config.json` gains gate **k — rules-harness**, which runs
`tool/rules_harness.mjs`. Division of ownership, recorded in the gate's own
`proves` field:

- **gate (d)** — the rules compile, load and are enforced at all
  (`tool/emulator_probe.mjs`, two REST probes). It does **not** execute the
  semantic harness and never did.
- **gate (k)** — the semantic harness actually runs and its assertions hold.

Two properties were needed to make (k) trustworthy, and both were proven by
mutation rather than assumed:

1. **Port independence.** The harness hardcoded `127.0.0.1:8080`. It now reads
   `FIRESTORE_EMULATOR_HOST` (falling back to 8080 for a manual
   `npm run test:rules`), and the runner takes a free loopback port from the OS
   and writes a sibling config, the same approach gate (d) uses.
2. **A ratchet, not a rubber stamp.** The suite has 56 known-stale failures, so a
   hard gate would be permanently red and ignored.
   `core_app/test/rules/known_failures.txt` records them; gate (k) fails when a
   failure appears that is **not** in that list, fails when the harness crashes,
   and fails when the harness reports **no assertions at all**. It reports
   baseline entries that start passing so the list gets pruned.

Proof that (k) can fail — both mutants were restored byte-for-byte afterwards:

| mutation | gate (k) result |
|---|---|
| inverted one passing assertion (`assertFails` where the rules allow) | **FAIL**, naming `T-E5: tenant reads its own prefixed settings doc → ALLOW` |
| made `runTests()` throw before any assertion | **FAIL**, "no assertions were reported — the harness did not run" |
| clean tree | **PASS** 16.1 s |

The 56 baseline entries are debt, not a pass: each is an assertion whose
expectation predates the tenancy work.

## Still open

- **7b** — the four settings readers, the two admin writers and the six
  `functions/src` sites (D-046 helper). Not started.
- **7c** — settings rules, per-tenant `isOwner()`, registry rows.
- **7d** — admins, audit_log, audit_logs.
- The `*_featureFlags` doc: D-045 permits an anonymous read, but a signed-out
  client cannot derive a tenant-prefixed name, so the pre-login flag source needs
  either a bundled tenant id or a deliberate exception before 7c. This is the one
  place where "the claim is the client tenant source" (owner ruling) and the
  pre-login read genuinely conflict, and it must not be resolved by improvisation.
## Full gate battery with gate (k) included

Receipt: `checkpoints/gate-20261113T083210Z.md` — branch `cline/p32-golden-gates`,
head `428b1c54`, command `gate.cmd check`, verdict **PASS** (11 ran, 0 failed,
0 unavailable, 0 not-active).

| Gate | Name | Status | Duration |
|---|---|---|---|
| a | dart-analyze | PASS | 190.2 s |
| b | gate-fast-tests | PASS | 272.2 s |
| c | functions-build | PASS | 9.4 s |
| d | emulator-rules | PASS | 29.1 s |
| e | whitelabel-dry-run | PASS | 4.8 s |
| f | stub-scan | PASS | 0.0 s |
| i | tenant-isolation-generator | PASS | 1.6 s |
| g | functions-coverage | PASS | 11.4 s |
| h | backend-parity | PASS | 0.9 s |
| j | tenant-isolation-emulator | PASS | 24.7 s |
| k | rules-harness | PASS | 17.8 s |

Sum of gate durations 562.1 s (≈9 m 22 s). Gate (k) adds 17.8 s of that, about
3%; (a) and (b) dominate at 82%.

### Finding: the first full run was RED, and it was my change

The first battery with (k) included returned `11 ran, 1 failed` — gate
**(g) functions-coverage**. Not (k): (g) caught that 7a's settings rename had
dropped `src/migrations/v004__tenancy_backfill.ts` to 86.82% against its 94%
floor and `plans.ts` to 97.54% against its 100% floor. Seven tests closed it
(empty-tenant refusal, nested path, target claimed by another tenant, applied
copy plus idempotent re-run, wrapper conflict report, batching past 400
documents, and the `migrate()` entrypoint via a shadowed admin handle). The
second run above is from the fixed tree.

The `migrate()` test shadows `admin.firestore` with `Object.defineProperty`
because the real one is a getter that calls `ensureApp()`; a plain assignment is
silently ignored and the test then fails with "The default Firebase app does not
exist".
## 7b(3) — the server resolves settings through one helper (D-046)

`settingsDoc(name, tenantId = DEFAULT_TENANT_ID)` replaced all six bare
`db.collection('settings').doc('<name>')` reads in `functions/src/index.ts`
(order counter, tax table ×2, restaurant config ×4). Every one of them would
have found nothing after the D-038 rename, and a missing tax or delivery-fee
document is a money fallback, not an error — which is why the helper exists with
a comment instead of six independent literals.

The default is explicit: the order payload does not carry a tenant yet, so the
call sites target the deployment's own tenant, the same value the migration
backfills. When the payload gains a tenant, the helper is the only place that
changes shape.

Proof: `tsc` clean, `eslint src/index.ts` clean, gate (c) 4.2 s PASS, gate (g)
13.6 s PASS (no test seeded the old literal paths, so no test churn was needed).
## 7c(2) — default operating hours follow the tenant

`OperatingHoursScreen._ref` became async because the document cannot be named
before the tenant is known: `settings/${tenantId}_defaultOperatingHours`, with a
branch override still branch-scoped. A missing claim throws instead of writing to
a guessed document.

The three suites that exercise the screen were moved with it (prefixed document
ids, `tenantClaimProvider` overrides, and the read-only fake ruleset renamed to
the prefixed path — without that last one the fake matched nothing, so the
"denied save" case silently stopped testing a denial). 20 tests pass; (a) 163.2 s
PASS; (b) 280.9 s PASS.
## 7d(1) — admins, audit_log and audit_logs are tenant-scoped

Reads now require `isOwner() && tenantOk()`; admins writes are owner-only AND
tenant-scoped. The combined `allow write` had to be split into
create/update/delete: `tenantOk()` inspects the EXISTING document, which does not
exist on a create, so `allow write: ... tenantOk()` denied every new admin row.
Gate (k) caught exactly that (`t78-CTL10: flagged owner writes admins -> ALLOW`
became a new failure) and the split fixed it — this is the case for having made
the harness a gate.

`isOwner()` still resolves the single shared `settings/ownerInfo`. Making it
per tenant is 7d(2): it flips every owner assertion in the harness and depends on
the rename (7a) having run, so it is not a same-commit edit.

Registry rows for the three collections stay PENDING-TENANCY on purpose. Their
only readable principal is the owner, the isolation probe has no owner principal,
so flipping them would add skips, not assertions — an ACTIVE count that proves
nothing. They activate with 7d(2) plus an owner principal in the probe.

Proof: (d) 7.4 s PASS, (k) 14.6 s PASS, (j) 63.8 s PASS, parity refreshed.
## 7d(2) — ownership itself is per tenant

`isOwner()` now resolves `settings/${tenantId}_ownerInfo` through one
`ownerInfoDoc()` helper: a claim without a tenant can never be an owner. The
migration already renames `ownerInfo` with the other settings documents (7a is
generic over `settings/*`), and no app or function code writes that document
except the v003 seed, which the rename then moves.

Two harness assertions were asserting against the document they deleted: `b11-T5b`
removed `settings/ownerInfo` and expected the owner write to fail, which it no
longer does because the rule no longer reads it. Both now target the tenant
document — gate (k) reported the stale one by name before the fix.

Proof: (d) 8.5 s PASS, (j) 37.9 s PASS, (k) 15.6 s PASS, parity refreshed.
## 7c(3) — the literal settings blocks are retired

Deleting `match /settings/restaurantConfig`, `/settings/taxRates` and
`/settings/defaultOperatingHours` was not cosmetic. A literal block does not
stop applying when the app starts using a renamed document: it keeps
AUTHORIZING the old name, so an owner could write `settings/restaurantConfig`
and the tenant's real `settings/<tenant>_restaurantConfig` would never see it —
two documents drifting in silence, one of them read by nobody.

What had to move with them:

* the three shape checks, now `tenantSettingsShapeOk(doc, data)`, keyed by the
  document-name suffix (rules cannot index by name any other way);
* `isOrdersAccepting()`, which read the literal document and would have read
  "absent" forever — the panic switch would have failed OPEN; it now reads the
  caller tenant's config, keeping the legacy open default only when there is no
  claim (guest path, matching `?? true`);
* the `ownerInfo` read exception: the generic read allowed any tenant-prefixed
  document to any signed-in user, which would have published the owner's email
  to the tenant's customers. `settings/*_ownerInfo` is owner-only again.
* the delete posture: the literal blocks denied deletes; the generic block
  allowed them. Settings are operator state, so delete is `false`.

Registry: the three literal rows are gone (the 5a parser will not regenerate
them, their blocks no longer exist) and `settings` is ACTIVE with
`sameTenant: allow` — 27 ACTIVE, 5 PENDING (`admins`, `audit_log`,
`audit_logs`, `deliveries`, `proof_of_delivery`). Gate (k) named all six stale
prefixed fixtures one at a time before they were moved.

Proof: (d) 7.2 s PASS, (k) 14.6 s PASS, (j) 19.8 s PASS, generator `--check` in
sync (32 rule paths).
## Full battery after 7b(3)–7d(2) + 7c(3)

`gate.cmd check` — 11 gates ran, 0 failed, 0 unavailable, 0 not-active:

| gate | result | time |
| --- | --- | --- |
| a dart-analyze | PASS | 105.8 s |
| b gate-fast-tests | PASS | 237.4 s |
| c functions-build | PASS | 11.2 s |
| d emulator-rules | PASS | 22.9 s |
| e whitelabel-dry-run | PASS | 2.9 s |
| f stub-scan | PASS | 0.0 s |
| i tenant-isolation-generator | PASS | 2.7 s |
| g functions-coverage | PASS | 14.2 s |
| h backend-parity | PASS | 0.9 s |
| j tenant-isolation-emulator | PASS | 56.7 s |
| k rules-harness | PASS | 15.7 s |

Card 7 is complete on the rule and producer side: settings (all of them),
admins, audit_log and audit_logs are tenant-scoped, the server and the app both
name their documents through one tenant-aware helper per language, and ownership
itself resolves the caller's own tenant document. 27 of 32 rule paths are ACTIVE;
the 5 PENDING are `admins`/`audit_log`/`audit_logs` (need an owner principal in
the isolation probe, not a rule change) and `deliveries`/`proof_of_delivery`
(card 8).
## 7e — an owner principal, so the owner-only rows assert something

The last three rows could not be flipped before because the probe only had
customer principals: a customer is denied `admins`/`audit_log`/`audit_logs` by
ROLE, so the denial would have passed without the tenant scope ever being
consulted — an ACTIVE count proving nothing, which is why 7d(1) left them
PENDING rather than dress them up.

The probe now mints `owner-a@probe.local` (tenant A, role owner, App-Check claim)
and seeds `settings/tenant_a_ownerInfo` with that email — the document
`isOwner()` actually reads since 7d(2). The generated suite takes a per-row
`principal`, and the three rows name the owner.

The same-tenant control is what proves the setup: if `isOwner()` were still
false for that token (a typo in the claim or the owner document), the ALLOW read
would fail. So the row cannot pass by being uniformly denied.

30 of 32 rule paths ACTIVE; the 2 PENDING are `deliveries` and
`proof_of_delivery`, which are card 8's collections.

Proof: generator in sync, `dart analyze test/security` clean, (j) 38.2 s PASS.
## Card 8 — deliveries and proof_of_delivery (D-047)

Both collections belong to an order, and the rule already fetched that order for
`assignedDriverId`, so the tenant check rides the same read.

The rejected option is the one that looks obvious: add `tenantId` to the
delivery document. The driver's ping is `hasOnly([...])` and REPLACES the
document, so a migrated `tenantId` disappears on the first ping and the second
ping is denied — deliveries stop, and the change looks like a security win. It
would also strand deployed clients that do not send the field.

Proof: harness `c8-T1..T8` (owner read foreign/own, driver write foreign/own,
proof read foreign/own, driver proof update foreign, fixture cleanup) — all
green; delivery and proof isolation rows ACTIVE with the owner principal and a
probe that seeds the linked order, so the denial is tenancy and not a missing
parent. 32 of 32 rule paths ACTIVE; no PENDING rows remain.

Gates: (d) 10.8 s, (h) 1.2 s, (k) 17.8 s, (j) 23.7 s — all PASS.
## Full battery after card 8

`gate.cmd check` — 11 ran, 0 failed, 0 unavailable, 0 not-active:

a 162.9 s · b 317.1 s · c 10.7 s · d 13.4 s · e 1.8 s · f 0.0 s · i 1.6 s ·
g 12.0 s · h 0.9 s · j 23.7 s · k 15.7 s.

Every rule path in the registry is ACTIVE (32/32) and the harness is at its
baseline with no new failures (165 passed, 56 known, 0 new).
## 7f — the legacy unprefixed settings path is gone

`PanicSwitchService` and `CheckoutService` now REQUIRE a `TenantClaimReader`
instead of accepting an optional one. With the optional version, a construction
that passed no reader silently read `settings/restaurantConfig` — the retired
name, which no rule authorizes any more and which nothing writes. That is the
worst shape a config bug can take: the switch keeps reporting "accepting" while
the document it reads is empty forever, so an owner pauses orders and nothing
happens.

Tests had to move with it (18 files): constructions take
`const FixedTenantClaim()`, or their local `_FixedTenantClaim`; the shared
`test/support/tenant_claim_fakes.dart` exists so a test names its tenant at the
call site instead of relying on a fallback. Three suites asserted against the
unprefixed document after a write and were moved to the tenant-keyed one
(`panic_switch_flow`, `p28_panic_switch_banner`, `panic_switch_service_test`),
and the retry-wrapping stub now follows the `collection('settings').doc(...)`
hop the production code actually makes.

Proof: (a) 17.0 s PASS, (b) 229.9 s PASS. Three failures in
`restaurant_setup_tax_tab_test` / `feature_flags_test` are PRE-EXISTING —
verified by stashing this change and re-running those files at HEAD (same 3
fail), so they are not caused by it and are not fixed here.
