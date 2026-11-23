# P1-4 STEP 1 — registry fields + suite bootstrap (rows still PENDING)

Part of P1-4 under D-036. **No rule changed, no row flipped to ACTIVE.** This step
builds the machine and is verified to change nothing about today's behaviour: the
suite still runs green with 84 skipped assertions and the loud status test.

## What changed

### `test/security/tenant_isolation_cases.json`

Every row gained five fields, and the registry now carries `allowControls: 17` /
`noneControls: 11` so the balance is inspectable without parsing rows:

| field | meaning |
|---|---|
| `readDocId` (`iso_b_<collection>`) | the SEEDED tenant-B document the read denial runs against |
| `writeDocId` (`iso_bw_<collection>`) | the SEEDED tenant-B document the write denial targets |
| `allowDocId` (`iso_a_<collection>`) | the SEEDED tenant-A document the allow control reads |
| `sameTenant` | `allow` or `none` |
| `sameTenantWhy` | required when `none`; documents why no tenant-scoped principal can read that collection |

The 11 `none` verdicts are the collections whose read clause needs something other
than a tenant-scoped user — owner-email (`admins`, `audit_log`, `audit_logs`,
`transactions`), a role the suite does not mint (`analyticsEvents`,
`notification_queue`, `promoCodes`, `presence`), a linked order fixture
(`deliveries`, `proof_of_delivery`), or a schema that has no per-tenant key at all
(`settings`). `settings` is the one that deserves attention before step 3: its
documents are singletons keyed by NAME (`restaurantConfig`, `taxRates`,
`featureFlags`), so tenancy there is a key-scheme change, not a rule edit.

### `tool/gen_tenant_isolation_tests.dart`

- Two new status constants (`allow` / `none`) and validation: a row without
  `readDocId`/`writeDocId`, an unknown `sameTenant`, a `none` row without a reason,
  or an `allow` row without `allowDocId` all fail the generator with exit 2 — the
  same fail-closed contract as the existing completeness checks.
- Emission carries the five new fields per case and the generated header now
  explains that an ACTIVE row is three assertions (deny read, deny write, allow
  own).
- `main` became `Future<void> main() async` and calls `bootstrapTenantSuite()`
  **only when `kActiveCases > 0`**, so an all-PENDING registry still runs with no
  emulator — that is why this step cannot break `flutter test` on any machine.

### `test/security/tenant_isolation_support.dart`

- `crossTenantCase` now emits three tests. The allow test skips with
  `NO SAME-TENANT CONTROL [<collection>]: <reason>` for `none` rows, so a missing
  control is visible in the runner output rather than silently absent.
- `expectCrossTenantDenied` takes the seeded `docId` instead of substituting a
  random path, and writes with `SetOptions(merge: true)` so the write case targets
  an existing tenant-B document.
- `expectSameTenantAllowed` fails when the document is **missing**, not just when
  the read is denied: `get()` on an unseeded path succeeds with `exists == false`,
  which would otherwise let a broken seed masquerade as a working control.
- `bootstrapTenantSuite()` initialises Firebase against the emulators from
  `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST`, signs in as
  `tenant-a@probe.local`, and `fail`s loudly when those variables are absent — a
  suite that silently skipped its own bootstrap would report green for the wrong
  reason.

## Evidence

```
$ dart run tool/gen_tenant_isolation_tests.dart
wrote test/security/tenant_isolation.generated_test.dart — 28 collections, 0 ACTIVE, 28 PENDING-TENANCY

$ dart run tool/gen_tenant_isolation_tests.dart --check
TENANT-ISOLATION: PASS — 28 collections, 0 ACTIVE, 28 PENDING-TENANCY, generated suite in sync

$ dart analyze test/security tool/gen_tenant_isolation_tests.dart
No issues found!

$ flutter test test/security/tenant_isolation.generated_test.dart
00:00 +1 ~84: All tests passed!

[f] stub-scan              PASS   (2 file(s) scanned)
[i] tenant-isolation-generator PASS
gate a / b               see the receipt in checkpoints/
```

`~84` skipped is the arithmetic of this step: 28 collections × 3 assertions, plus
the status test that still prints `0 active / 28 PENDING-TENANCY` to stderr.

## What this step deliberately does NOT do

- **No ACTIVE row.** Flipping one now would execute the seed-dependent assertions
  with no probe, and `bootstrapTenantSuite` would fail — which is the correct
  behaviour, but it would leave the tree red until step 2 lands.
- **No gate (j) yet.** It needs `tool/tenant_isolation_probe.mjs` (seed + claims +
  `flutter test` child) to exist first.
- **No rules change.** `tenantOk()` lands last, per D-036 and the card's ordering.

## Next in step 2

`tool/tenant_isolation_probe.mjs`: free ports → `emulators:exec --only
firestore,auth` → Admin SDK seeds `iso_a_*` for tenant A and `iso_*_*` for tenant B
across all 28 collections → `createUser` + `setCustomUserClaims({tenantId})` for
both principals → spawn `flutter test --tags needs-emulator test/security/` with
the emulator env, propagating the child exit code. Then register gate (j) in
`gate_config.json`, and only then flip the first collection.
