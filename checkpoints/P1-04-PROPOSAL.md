# P1-04 PROPOSAL — tenancy rules + a harness that can actually fail

**Status: APPROVED 2026-11-11 (D-036) — implementation may start. Gate (j) carries the emulator proof.**
has changed; no registry row has been flipped; no gate was added. This document asks
for a decision before any of that happens, because two parts of the design change
what "green" means for the most security-sensitive card in the expansion.

Date 2026-11-11 · branch `cline/p32-golden-gates` · HEAD `84bc5483` · D-035 is the
ruling this proposal implements.

---

## 1. What P1-4 is supposed to prove

Card: *`tenantOk()` helper on every match block, `TenantFirestore` wrapper,
generated suite ACTIVE per collection.* DONE WHEN: *every collection has an
ACTIVE cross-tenant denial case; 0 rows remain PENDING-TENANCY; rules emulator green.*

The machinery is already built and complete by construction: gate (i) fails if a
rules collection has no registry row, and `crossTenantCase` turns one registry row
into a real emulator assertion (`test/security/tenant_isolation_support.dart`,
`tool/gen_tenant_isolation_tests.dart`). What is missing is the *bootstrap* the
support file's own doc comment names as a precondition — emulator + sign-in as
tenant A — plus seeding, because the suite only ever asserts **denial**.

## 2. Two ways this card goes green while proving nothing

These are the reason I am asking before implementing. Both are provable from the
current code, not hypothetical.

### 2.1 Denial-only: a rules typo scores 28/28

`expectCrossTenantDenied` returns success on `permission-denied` and `fail`s on
anything else (support file, the `on FirebaseException` branch). There is no
allow-case anywhere in the suite, generated or hand-written.

So a `tenantOk()` that is **always false** — a misspelled claim, a `||` where an
`&&` belongs, a helper that throws — passes every one of the 56 tests. The suite
would report "tenants are isolated" when what it actually proved is "nobody can
read anything", which for a live restaurant app is an outage, not a security win.

**Every denial assertion needs a paired allow assertion, or the gate measures
lockdown.**

### 2.2 The read probe reads a document that does not exist

`pathTemplate.replaceAll('{id}', 'p08probe_${microseconds}')` builds a random,
never-seeded path. Today every row is PENDING so nothing runs; the moment a row
goes ACTIVE, the read test fetches a **missing** document.

A rules read of a missing document is denied for a completely different reason:
there is no `resource`, so `resource.data.tenantId == token.tenantId` can't be
satisfied no matter what the other tenant actually holds. The test would pass
forever while tenant B's real documents sat unprotected. The write half has the
same disease in the other direction — it writes a fresh path, so it never tests a
write to an *existing* tenant-B document either.

**Active cases must run against documents the probe seeded, at ids the registry
names.** Otherwise the suite is a random-number generator that always denials.

## 3. Recommended solution

Six parts, in dependency order. Parts 1–2 make the proof mean something; 3–5
build it; 6 is the client side that the deploy order depends on.

### 3.1 Rules: one predicate, applied mechanically (28 collections + 3 nested)

```
function tenantClaim() {
  return isAuthenticated() ? request.auth.token.tenantId : null;
}
function tenantOk() {
  return tenantClaim() != null && resource.data.tenantId == tenantClaim();
}
function tenantOkCreate() {
  return tenantClaim() != null && request.resource.data.tenantId == tenantClaim();
}
```

- Every `read` gains `&& tenantOk()`; every `create` gains `tenantOkCreate()`.
  That replaces the 5 `allow read: if true` sites (`menus:228`, `branches:255`,
  `branches/*/menu_overrides:268`, `branches/*/config:277`, `promotions:322`) and
  covers 32 `match` blocks (28 unique top-level collections + `menu_overrides`,
  `config`, `waitlist_meta`, plus the `notifications/{userId}/items` subcollection).
- **Queries, not just documents.** A `list` whose rule references `resource.data`
  must constrain that field, so every tenant-scoped query needs
  `.where('tenantId', '==', tenant)`. This is the real cost of design 1 and the
  reason `TenantFirestore` exists — see §3.6 and the cost table in §5.
- `transactions` keeps `allow write: if false` (P1-2), and gains tenant scoping on
  the owner read only.
- The duplicate `match /notifications` blocks at `:790` and `:793` should be left
  alone in this card (they are legal — rules OR together) but noted, because a
  reader will assume the first one wins and it does not.

### 3.2 Claim path: guest claims from a verified App Check app id (amends D-035)

D-035 said the tenant comes from `request.auth.token.app_id`, because `hasAppId()`
(`firestore.rules:13`) already trusts that name. Checking the documented claim set
for `request.auth.token` settles it the other way: the documented fields are
`email`, `email_verified`, `phone_number`, `name`, `sub`,
`firebase.identities`, `firebase.sign_in_provider`, `firebase.tenant` — **there
is no `app_id`**. Custom claims can carry `tenantId`, but the repo has never
verified that a real ID token carries `app_id`.

Two consequences, and the second is a landmine independent of this card:

1. The binding moves to **App Check**: a callable verifies
   `X-Firebase-AppCheck` with `getAppCheck().verifyToken()`, whose decoded token
   exposes the calling **app id** (confirmed in the Admin SDK reference, and the
   documented pattern "check that the token's subject matches your app's App
   ID"). `tenants/{tenantId}.appIds[]` maps that app id → tenant; unknown app id
   fails closed. Unforgeable, and it does not depend on an unverified claim.
2. **`hasAppId()` is probably always false in production.** In relaxed mode that
   is invisible (`hasAppId() || hasAppCheckToken()`); in strict mode
   `hasAppId() && hasAppCheckToken()` is then always false, so flipping
   `settings/featureFlags.strongAppCheck` to true would deny **every** write in
   the app. I cannot verify this from the repo — it needs one real ID token from a
   deployed client, which is human-only under A2. It should be checked before
   strict App Check is ever armed; the fix is a one-line change of `hasAppId()` to
   whatever the token actually carries.

Claim work itself: `buildUserClaims` currently throws when `roles` is empty
(`claims.ts`, `ClaimsValidationError('roles', ...)`), so the guest branch from
D-035 is a real code change: an anonymous caller gets
`{tenantId, roles: [], branchIds: [], guest: true, claimsVersion: 1}` and must
still fail `assertCapability` structurally.

### 3.3 Harness: Node seeds, Dart asserts

Reuse the pattern gate (d) already runs (`tool/emulator_probe.mjs` → free port →
`firebase emulators:exec` → `tool/rules_probe.mjs` → `tool/ledger_probe.mjs`), with
the auth emulator added (`firebase.json` already declares it on 9099, and
`tool/verify_demo_flows.js` already sets `FIREBASE_AUTH_EMULATOR_HOST`).

`tool/tenant_isolation_probe.mjs`, inside `emulators:exec --only firestore,auth`:

1. **Seed** tenant A and tenant B documents at the ids the registry names, for all
   28 collections, with `tenantId` set. Admin SDK writes bypass rules (the reason
   seeding works at all), exactly as `ledger_probe.mjs` already does.
2. **Create principals**: `admin.auth().createUser` for
   `tenant-a@probe.local` / `tenant-b@probe.local`, then
   `setCustomUserClaims(uid, {tenantId, roles: [...], claimsVersion: 1})`. Admin
   SDK is already reachable from tools via `createRequire` against
   `functions/package.json` — no new dependency.
3. **Run the suite**: spawn
   `flutter test --tags needs-emulator test/security/` with
   `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST` and the two
   credentials in the environment; propagate the child's exit code, never swallow
   it.
4. **Cleanup** the temp config, mirroring `emulator_probe.mjs`.

Dart side, `tenant_isolation_support.dart` gains `bootstrapTenantSuite()`:
`Firebase.initializeApp` with the emulator project id, `useFirestoreEmulator`,
`useAuthEmulator`, `signInWithEmailAndPassword` as tenant A. It throws loudly if
the env vars are absent, so a stray `flutter test` cannot silently self-skip into
green.

### 3.4 Registry grows three fields, and the generator enforces them

`tenant_isolation_cases.json` per row:

| field | used for |
|---|---|
| `readDocId` / `writeDocId` | the **seeded** tenant-B ids (§2.2) |
| `sameTenant` | `"allow"` (tenant A may read its own doc) or `"none": "<reason>"` |
| `status` | unchanged |

`crossTenantCase` then emits, for an ACTIVE row:

- A is **denied** read on B's seeded doc;
- A is **denied** write on B's seeded doc (create, and update of the seeded one);
- A is **allowed** read on A's own doc, when `sameTenant == "allow"`.

Locked collections (`transactions`, `audit_log`, `deletion_requests`, …) cannot
have a per-collection allow control without inventing a readable principal, so
they declare `"none": "<reason>"` and the suite instead asserts a **global
positive control**: tenant A can read its own `menus` doc and its own `branches`
doc — the exact reads the guest app performs at boot. Plus a structural assertion
that at least N rows carry a real `"allow"`, so a future change cannot quietly
convert every control into `"none"` and return to a lockdown-only suite.

That last assertion is what makes the whole thing falsifiable: **a rules change
that denies everything fails the gate**, and so does one that leaks.

### 3.5 Activation order inside the card

1. Registry + support-file extensions, all rows still PENDING → gate (i) green,
   suite green with every case skipped *and* the status test still loud. (Proves
   the machine, changes no rule.)
2. Probe + bootstrap land; rows flip to ACTIVE **one collection per commit**,
   smallest blast radius first (`menus`, `branches`, `promotions`, then staff
   collections). Each commit re-runs the probe. A denial that is wrong shows up
   next to the rule that caused it, not in a 28-row avalanche.
3. `tenantOk()` rules change last, with all rows ACTIVE and the probe green.

This keeps the "no half-deployed security" law: rules never ship ahead of claims
(D-032/D-033 ordering, and D-035's deploy order).

### 3.6 `TenantFirestore` (client) — bounded, not a sweep

`packages/core/lib/src/tenancy/tenant_firestore.dart`: a wrapper that takes a
`FirebaseFirestore` + tenant id (from the **claim**, never from
`client_config.json`), exposes `collection(path).where('tenantId', '==', tenant)`
for queries and stamps `tenantId` on writes, and throws when the tenant is
missing rather than issuing a query that will be denied.

Scope for this card: the wrapper plus the **menu and branch repositories**, which
are the guest-boot paths design 1 puts at risk. The remaining references
(130 `.collection(` call sites across `core_app/lib` + `packages/core/lib`) are
converted per feature as each feature is touched; pretending to convert all 130 in
this card is how a security change turns into an unreviewable sweep.

## 4. Why this is the best available solution

| Option | Proves isolation | Detects a leak | Detects lockdown | Fits gate (i) / generated suite | New deps | Verdict |
|---|---|---|---|---|---|---|
| **A. This proposal** (Dart suite + Node seed/claims + positive controls + seeded doc ids) | yes | yes | yes | yes, one source of truth | none | **recommended** |
| B. Node/REST probe only (extend `rules_probe.mjs`) | yes | yes | yes | **no** — card requires the generated suite ACTIVE; two rule-test stacks | none | rejected |
| C. `@firebase/rules-unit-testing` in Node | yes | yes | yes | **no** — a second harness gate (i) does not govern; duplicates 28 rows | one | rejected |
| D. Flip rows ACTIVE with today's support file | **no** (§2.1, §2.2) | no | no | yes, mechanically | none | rejected — this is the trap |
| E. Separate Firebase project per tenant | yes | yes | n/a | n/a | infra | rejected earlier (A2/D-022: one shared project) |
| F. Keep public reads open (design 2) | partially | **no** | n/a | n/a | none | rejected (D-035) |

A is the only option that satisfies the card as written *and* is falsifiable. C is
the objectively most idiomatic rules-testing stack in the Firebase ecosystem, and I
still reject it here: the card's DONE-WHEN is the generated Dart suite, gate (i)
is the completeness machine, and introducing a parallel 28-row registry means two
places to keep in sync — the exact drift class gate (i) exists to prevent.

**Proof obligations this design meets, in the card's own words:**
- *every collection has an ACTIVE cross-tenant denial case* → 28 rows ACTIVE,
  each running against a seeded tenant-B document.
- *0 rows remain PENDING-TENANCY* → the generator rejects PENDING rows once
  `tenancyStatus` is ACTIVE (needs a small generator change; do it in step 3.5.3).
- *rules emulator green* → the probe is the emulator run, in gate (d)'s style.

## 5. Cost, risk, and what stays unproven

| Item | Cost |
|---|---|
| Probe + bootstrap + seed/claims | ~1 day, mostly plumbing that already exists in `ledger_probe.mjs` |
| Registry fields + generator + positive controls | ~0.5 day |
| Rules: 32 match blocks, 5 public reads, 3 nested | ~1 day, mechanical but needs care per collection |
| Client wrapper + menu/branch adoption | ~1 day |
| **Query constraint ripple** | 130 `.collection(` sites will fail at runtime until they carry the tenant filter — the largest hidden cost, spread per feature |
| New gate (j) | ~0.5 day; alternative is extending gate (d) (slower receipt, one boot) |

Risks I am accepting and naming:
- **App Check in the emulator is not emulated.** The probe must therefore prove
  *rules* isolation from claims minted directly by the Admin SDK, and prove the
  *claim callable* separately (unit tests for `app_id → tenantId`, plus a handler
  test with an injected verifier). No gate will hit the real App Check service.
- **`hasAppId()` (§3.2.2)** is unverifiable here and may be a production
  landmine. Human-only to confirm.
- **Positive controls are per-collection only where a readable principal exists.**
  For locked collections the control is global; that is a real gap, declared in
  the registry with a reason rather than hidden.
- The suite proves *denial and allow at the rules layer*. It does not prove the
  client sends a claim on every path — that is the `TenantFirestore` work and the
  per-feature conversion.

## 6. What I need from you

Pick one, and I will record it as the P1-4 implementation ruling (and tell the
orchestrator in the next ORCHESTRATOR REPORT):

1. **Approve as written** — including the positive controls, seeded doc ids, and
   the App Check binding that amends D-035.
2. **Approve, but keep the D-035 `token.app_id` binding** — smaller diff, but the
   tenant binding then rests on a claim the documented API does not list, and
   §3.2.2's strict-mode landmine stays unexplained.
3. **Approve the harness, defer the rules change** — build the machine and flip no
   rule until the live app sends claims (deploy-risk choice, not a security one).
4. **Something else** — say which part and why.
