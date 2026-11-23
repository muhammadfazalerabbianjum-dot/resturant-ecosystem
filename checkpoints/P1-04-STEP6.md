# P1-4 step 6 — orders and reservations (D-039)

Step 6 closes the two collections that carry money and time. Both are written by
the app in a transaction, so converting the rule alone would deny the app; the
rule change and every producer of `tenantId` therefore land in one commit each
(same reasoning as D-037, applied per collection instead of globally).

## 6a — two-sided create assertion (`1ec91000`)

Gate (j) originally proved only *denial*. A rule that denies everything (a typo
that takes ordering offline) would have passed. 6a adds the missing half:

- `createBodyJson` on a registry row: the exact shape the client sends.
- `expectSameTenantCreateAllowed` — tenant A creates its own document, must be 200.
- `expectCrossTenantCreateDenied` — the same body stamped tenant B, must be 403.
- `_encodeValue` encodes the fixture into Firestore REST `value` form.
- `{uid}` in a fixture resolves to tenant A's principal, because each emulator
  run mints its own uids and a hard-coded uid would be a lie.

Gate (j) 136.1 s PASS. Analyze first failed on
`prefer_interpolation_to_compose_strings` (`tenant_isolation_support.dart:135`);
fixed by interpolation, analyze PASS 17.8 s.

## 6b — orders (`81693748`)

- `TenantClaimReader` / `TenantClaim` (`lib/app/tenancy/tenant_claim.dart`): the
  claim is the client's tenant source (D-035), read once per session and cached.
- `buildOfflineOrderPayload(..., required String tenantId)` stamps the payload;
  checkout reads the claim first and refuses to enqueue without it.
- Rules: `tenantOk()` on read/update, `tenantOkCreate()` on create, `tenantId`
  added to the create allowlist — production and staging, byte-identical.
- Contract test asserts the allowlist names `tenantId` and the payload carries it.
- JS harness: `authedApp` sets `token.tenantId` (default `tenant_a`), and 31
  orders fixtures carry the key. A global claim was measured first: gate (d)
  PASS 15.0 s, so the harness stamp is safe rather than hopeful.
- `apps/halal_boyz/backend/firestore.rules` refreshed by `check_backend_parity --fix`.

Proof: (d) 9.4 s, (j) 21.2 s, (a) 20.7 s, (b) 389.2 s — all PASS.

Two failures found on the way, both real:

1. `_substitutePrincipal` returned `Map<dynamic, dynamic>` from `.map()`, so the
   cast at the create call site threw a type error that hid the fixture problem.
   Rebuilt as `Map<String, dynamic>`.
2. Three `buildOfflineOrderPayload(order)` call sites in the payload test were
   missed by the first regex; analyze caught them (3 × `missing_required_argument`).

## 6c — reservations

- `requestSlot(..., {required String tenantId})`; the value reaches all three
  documents the transaction writes: the lock, the counter and the reservation.
- `isValidReservationCounter` widened to `hasOnly(['booked', 'tenantId'])` —
  without it the counter write the transaction makes would be rejected by the
  reservation flow's own shape lock, i.e. the fix would deny itself.
- Rules: `tenantOk()` on read/update/delete, `tenantOkCreate()` on create,
  `tenantId` in the create allowlist; production and staging in lockstep.
- Screen reads the claim before booking and reports `loc.error` when absent.
- 25 test call sites patched; two fake repositories widened to the new
  signature; `tenantClaimProvider` overridden in the three widget harnesses that
  pump `ReservationScreen` (otherwise the screen would reach real Firebase Auth).
- Registry: reservations ACTIVE with a two-sided create fixture.

Proof: (d) 31.7 s, (j) 59.4 s, (a) 67.0 s, (b) 338.2 s — all PASS.

Defect found: the call-site inserter appended `, tenantId: ...` after an existing
trailing comma (`50,\n, tenantId: ...`), which analyze reported as
`missing_identifier` at three sites; fixed by a comma-aware regex, then formatted.

## State after step 6

**26 of 35 rule paths ACTIVE** (21 top-level + 5 nested), 9 PENDING-TENANCY:
admins, audit_log, audit_logs, deliveries, proof_of_delivery, settings,
settings/restaurantConfig, settings/taxRates, settings/defaultOperatingHours.

## 6d — producer alignment for the waitlist

The waitlist rules were already scoped (card 1 for the counters, step 5b for the
entry and the branch ordinal), which meant the app's own waitlist writes were
denied. This sub-step aligns the producer:

- `WaitlistRepository` takes a `TenantClaimReader`; join, serve and leave read
  the claim first and fail closed (`error` / `-1` / `false`) rather than start a
  transaction that cannot commit.
- The entry and all three branch-ordinal writes carry `tenantId`.
- `isValidWaitlistMeta` admits `tenantId`; without that the ordinal write would
  be rejected by the waitlist's own shape lock. `isValidWaitlistCounter` was left
  alone because nothing writes that collection any more.
- Harness fixtures for `waitlist/` and `waitlist_counters/` carry the key.

Proof: (d) 15.1 s, (j) 24.7 s, (a) 18.2 s, (b) 203.9 s — all PASS.

## Remaining producer risk

`settings` and the literal `settings/restaurantConfig`, `settings/taxRates`,
`settings/defaultOperatingHours` readers still fetch by bare name, which is why
they belong to card 7 (D-038 consequence 2: enumerate first, then change in the
same commit set).
