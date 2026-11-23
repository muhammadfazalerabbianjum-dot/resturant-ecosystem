# P1-4 STEP 2 — gate (j), the probe, and the FIRST proven collection (`menus`)

Part of P1-4 under D-036. The machine now proves isolation against a real
emulator, and `menus` is the first collection converted end to end.

## What landed

### `tool/tenant_isolation_probe.mjs` — gate (j)

Outer process: two free loopback ports → temp emulator config → `firebase
emulators:exec --only firestore,auth`. Inner process: seeds **73 documents
across 28 collections** (tenant A and tenant B ids from the registry, with
`{uid}`/`{uid_b}` substituted), creates `tenant-a@probe.local` /
`tenant-b@probe.local`, mints `setCustomUserClaims({tenantId, roles:['customer'],
claimsVersion, app_id})`, then runs the generated suite and propagates its exit
code. Admin SDK comes through `functions/package.json`'s dependency tree, like
`tool/ledger_probe.mjs` — no new package.

### `firestore.rules` — the tenancy primitive, applied to `menus`

`tenantClaim()` / `tenantOk()` / `tenantOkCreate()` sit beside the existing auth
helpers. `menus` is the first collection: `read` is `tenantOk()`, create/update/
delete additionally require `tenantOkCreate()` / `tenantOk()` before the existing
owner/manager clauses. The other 27 collections are untouched.

### Registry

`menus` is ACTIVE; `tenancyStatus` is `IN-PROGRESS`; `activeControls: 1`. The six
uid-keyed collections (`carts`, `users`, `loyalty`, `deletion_requests`,
`notifications`, `driverLocations`) now use `{uid}`/`{uid_b}` ids so their denial
is caused by tenancy, not by the uid check.

## The transport, and why it is what it is

Three approaches were eliminated by evidence before this one shipped:

1. **`cloud_firestore` SDK** — impossible: `flutter test` runs in flutter_tester,
   where firebase_core's platform channel does not exist. `Firebase.initializeApp`
   threw before any rule was evaluated.
2. **`dart:io` HttpClient** — impossible: `test/flutter_test_config.dart` installs
   the repo's network blocker for every file under `test/`, and its documented
   escape hatch (`restoreNetwork`) returns to flutter_test's own 400-returning
   mock. The file forbids a blanket `HttpOverrides` bypass, so none was used.
3. **`dart test` + `package:test`** — impossible without destabilising the
   workspace: flutter_test pins `test_api 0.7.9`, and five `test` versions
   (1.26.3/1.26.2/1.26.0/1.25.9/1.24.0) all failed to solve; the solver kept
   landing on `freezed` 3 → `macros` → unsolvable. `pubspec.yaml` and
   `pubspec.lock` are unchanged.

What ships is a deliberately narrow loopback HTTP/1.1 client over `Socket`
(loopback hosts only, one request per connection, 1 MiB cap) speaking the same
Firestore REST interface gate (d) uses. Nothing sits between the assertion and
the rules engine.

Two bugs the emulator exposed, both fixed and commented:
- the emulator **ignores `Connection: close`**, so reading to EOF stalled for the
  full 15 s timeout — every assertion failed at exactly 15 s until the reader
  stopped on headers + declared body (Content-Length or chunked terminator);
- the auth emulator rejects `returnSecureToken` as a string
  (`INVALID_ARGUMENT: /returnSecureToken must be boolean`).

## Evidence

```
$ gate.cmd check --only=j
[j] tenant-isolation-emulator PASS       21.2s
GATE RESULT: PASS  (1 ran, 0 failed, 0 unavailable, 0 not-active, 9 not selected)

tenant-probe: seeded 73 documents across 28 collections
flutter test: 00:45 +4 ~81: All tests passed!   (1 status + 3 menus assertions)
```

### Falsifiability (the point of the card)

gate_config.json's `plant` line is not decoration — both plants were executed:

| Plant | Expected | Observed |
|---|---|---|
| `tenantOk()` returns false (lockdown typo) | gate (j) FAILS on the allow control | **FAIL** |
| `menus` read reverted to `allow read: if true` (leak) | gate (j) FAILS on the cross-tenant read | **FAIL** |
| rules restored | gate (j) PASSES | **PASS** (21.7 s) |

A green gate therefore means isolation *and* a working read path, not just one of
them. This is the property P1-4 exists to establish.

## Ordering correction (recorded as D-037)

The proposal's §3.5 put "flip rows ACTIVE" before "apply `tenantOk()`". That
cannot work: before the rule change there is nothing to deny, so the flipped row
would fail immediately. Each collection must land as **rule + registry flip in one
commit**, which is what `menus` does here and what the remaining 27 will follow.

## Still open

- 27 collections PENDING; each needs its own rule + flip commit.
- `settings` has no per-tenant key scheme (its docs are singletons by NAME) — a
  schema decision, not a rule edit.
- The claim callable (App Check → tenantId) is not built yet; gate (j) mints
  claims directly with the Admin SDK, which proves rules isolation, not the
  minting path (D-036 records this split).
- `TenantFirestore` (client) not started; menu/branch adoption follows the rules.
