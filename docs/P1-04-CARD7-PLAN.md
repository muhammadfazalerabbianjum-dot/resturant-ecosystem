# Card 7 plan — settings, ownerInfo, admins, audit (D-038)

Card 7 is the last tenancy card and the only one whose subject is **configuration
that the server reads to compute money**. It therefore cannot be a rules-only
diff, and it is staged so every commit is green on its own.

## Decisions that are not covered by an existing ruling

D-038 fixes the storage shape (flat `settings`, `${tenantId}_${name}`,
per-tenant `ownerInfo`), but not the two questions below. Options were compared
and one chosen; both choices are recorded here and in `docs/DECISIONS.md`.

### C7-1 — can a signed-out client read `*_featureFlags`?

The rules currently allow `read` for `settings/featureFlags` **without auth**,
because the flag doc arms STRICT App Check and is read before sign-in.

- **A. Keep an unauthenticated read, but only for a doc whose name ends in
  `_featureFlags`.** Feature flags are not secrets (six booleans that the client
  already ships as defaults). Cost: a signed-out client can enumerate flag docs
  by guessing tenant prefixes; it learns booleans it already knows.
- **B. Require auth + tenant for every settings read.** Removes the enumeration
  surface. Cost: the pre-login App Check arming path loses its flag source, and a
  wrong default there can arm enforcement for a tenant that is not ready — the
  failure mode is an outage for every user of that tenant, before they can log in.

**Chosen: A.** The information protected is already public in the shipped app,
while B's failure mode is an outage on the exact path that guards every other
read. Tenancy still holds on writes (owner + tenant) and on every other doc.

### C7-2 — where does the server get the tenant for its settings reads?

`functions/src/index.ts` reads `settings/taxRates` (×2), `settings/restaurantConfig`
(×3) and `settings/orderCounter` with no tenant context.

- **A. One server helper `settingsDoc(name, tenantId)`; callers that have the
  order pass `order.tenantId`, everything else uses `DEFAULT_TENANT_ID`.**
  Behaviour on today's single tenant is byte-identical; the seam exists where the
  tenant is actually known.
- **B. Keep the global names for the server and give only the client the
  prefixed names.** Two sources of truth for tax and delivery fee, drifting the
  moment an owner edits one. Rejected: money must have one source.
- **C. Derive the tenant inside the helper from a global "current tenant".**
  A process-global tenant in a multi-tenant function is a cross-tenant leak
  waiting for the second deployment. Rejected.

**Chosen: A.** It is the only option that keeps one source of truth and passes the
tenant explicitly at the site that knows it. The order-counter doc follows the same
helper (its tenant comes from the order being numbered).

## Sub-steps (each one commit, each green)

- **7a — settings rename machinery.** Add the settings sub-step to the migration
  planner (`planSettingsRename`): `settings/{name}` → `settings/{tenantId}_{name}`
  with `tenantId` stamped; second run plans zero. Pure function + `node --test`.
  No rule change yet, so nothing can be denied.
- **7b — settings producers and readers.** The four client readers, the admin
  writers and the `featureFlags`/`orderCounter` paths resolve the prefixed name
  from the ID token claim (client) or `settingsDoc` (server, C7-2). Tests updated
  in the same commit.
- **7c — settings rules.** `tenantOk()`/`tenantOkCreate()` on the generic
  `settings/{doc}` block, `ownerInfo` resolved per tenant inside `isOwner()`
  (D-038 consequence 3), the three literal match blocks retired in favour of the
  prefix check, registry rows for `settings` and the three literals flipped ACTIVE
  with two-sided create fixtures.
- **7d — admins, audit_log, audit_logs.** Same scheme per D-038; `isOwner()` now
  tenant-scoped means these inherit the fix. Registry rows flipped.
- **7e — the branch/menu producer fix** from `docs/P1-04-PRODUCER-AUDIT.md`
  (admin creation of branches and menus is denied today).

## Ordering constraint

7a must land before 7c: the migration is what creates the documents the new rules
require. 7b may land with or before 7c, but not after it — otherwise 7c denies
every settings read in the app. This is the D-041 ordering rule applied to
configuration instead of claims.

P1-6's bar (a second migration run changes nothing) applies to 7a directly and is
proven at the planner level, where it can be tested without a project.
