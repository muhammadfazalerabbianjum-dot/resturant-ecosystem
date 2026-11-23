# P2-1a — thin shell foundation (slice 1: the boundary)

Date: 2026-11-14, item 4 completed 2026-11-15. Card: `docs/queue-P2.md` P2-1a.
Sections 1–3 are the boundary slice (items 1–3); section 4 is the entrypoint;
section 6 is item **4 — the emulator proof**, which closed the card.

## 1. `LocalCache` seam (D-050) — done

`AuthRepository` called `IsarService.shared().clearAll()` directly on sign-out,
which put Isar in every graph that touched auth. Now:

- `packages/core/lib/src/cache/local_cache.dart` — `abstract class LocalCache
  { Future<void> clearAll(); }` + `NoOpLocalCache`. **Imports nothing.**
- `packages/core/lib/src/cache/isar_local_cache.dart` — `IsarLocalCache`
  delegating to `IsarService.shared().clearAll()` (own file, so the seam never
  drags Isar).
- `FirebaseAuthRepository` and `createPlatformAuthRepository` take
  `required LocalCache cache`. The sign-out wipe, its try/catch and its
  `AuthSignOutClearAllError` log tag are unchanged.
- `app_bootstrap.dart` passes `const IsarLocalCache()`; the shell passes
  `const NoOpLocalCache()`.

Construction sites that had to state their cache: **1 production + 10 in
`core_app` tests + 17 in `packages/core/test/auth_test.dart` = 28.** The
compiler named every one, which is exactly why the parameter is required.

New tests (`core_app/test/core/auth/auth_repository_test.dart`, group “P2-1a —
the local-cache wipe is injected”):

- `signOut clears the injected cache exactly once` — spy records `calls == 1`.
- `a throwing cache is logged and sign-out still completes` — `calls == 1` and
  `AuthSignOutClearAllError` verified.

`flutter test test/auth_test.dart test/platform_auth_bindings_test.dart`
(`packages/core`) → **+32 All tests passed**.

## 2. Portable min-int predicate — done

`-9223372036854775807 - 1` is exact on the VM and not representable under
dart2js, where the comparison was false for every value and therefore silently
disabled the T-5 fail-closed render. Replaced by

```dart
bool isMinInt(int v) => v != 0 && v == -v;   // packages/core_ui money_text.dart
```

used by BOTH renderers (`moneyCents` and `currency_format.dart`), so there is
one rule and no second literal.

`flutter test test/money_text_test.dart test/money_cldr_test.dart
test/money_min_int_portability_test.dart` (`packages/core_ui`) →
**+18 All tests passed**, including the new truth-table cases and both
`moneyCents(minInt)` fail-closed assertions.

## 3. Import-graph check — done, and it earned its keep immediately

`core_app/tool/check_shell_imports.dart` walks imports/exports/parts from the
shell entry and fails on: the `package:core/core.dart` barrel, any Isar package,
the 7 named Isar modules, `dart:io`, and `path_provider`/`sqflite`.

**It found a native edge the P2-0 audit had missed.** The spike named 7 Isar
files; `LoggerService` was not among them because it is not Isar — it imports
`dart:io` **and** `path_provider`, and every auth path pulls it
(`auth_repository` → `logger_service`). On the web that is a hard compile error.
First run:

```
shell import graph: 24 file(s) reachable
FAIL: 1 violation(s)
- FORBIDDEN PACKAGE path_provider
  via lib/shell/main.dart -> packages/core/lib/src/error_logger/logger_service.dart
   -> .../log_sink.dart -> .../log_sink_io.dart -> package:path_provider/path_provider.dart
```

Fixed by making the DESTINATION platform-chosen instead of native:

| File | Role |
|---|---|
| `error_logger/log_directory.dart` | conditional export → `typedef LogDirectory = Directory` (VM) / a path holder (web) |
| `error_logger/log_sink.dart` | conditional export → `log_sink_io.dart` / `log_sink_web.dart` |
| `error_logger/log_sink_base.dart` | the `LogSink` interface (`open/append/readLines/clear`) |
| `error_logger/log_sink_io.dart` | `app_logs.txt` + single-generation rotation (behaviour moved verbatim) |
| `error_logger/log_sink_web.dart` | bounded 500-line in-memory buffer + `debugPrint` |

**Why a typedef and not a parameter change:** `LoggerService({Directory?
testDirectory})` is called with a real `Directory` at **106 sites** (measured
with `grep -rn testDirectory`, excluding the definition). On the VM
`LogDirectory` *is* `Directory`, so all 106 compile untouched; on the web it is
a stub. Nothing about rotation, capping or `readLogs` semantics changed.

**Two checker defects were found by using it, and both mattered:**

1. Conditional exports were read literally, so the VM sink looked reachable on
   the web (false FAIL). Fixed by evaluating `if (dart.library…)` for a web
   build.
2. The first directive regex did not accept `show`/`hide`/`as`, so it skipped
   ~90 % of directives and printed **PASS with 1 reachable file** — a vacuous
   PASS. Fixed to parse whole statements including combinators. The reachable
   count is printed precisely so a number like that is visible.

**Negative proof (required before trusting it):** a temporary
`import 'package:core/core.dart' show IsarService;` in the shell →

```
FAIL: 1 violation(s)
- FORBIDDEN BARREL  package:core/core.dart
  via lib/shell/main.dart -> package:core/core.dart
NEGATIVE_EXIT=1
```

then removed; the real graph reports `shell import graph: 24 file(s) reachable`
and `PASS: no Isar, no dart:io and no core barrel on any shell path`.

## 4. The shell entrypoint (code) — done

`core_app/lib/shell/main.dart`: boots Firebase from `--dart-define` values,
points auth+firestore at the emulator under `USE_EMULATORS`, builds a
`ProviderContainer` that overrides `loggerProvider` and `authRepositoryProvider`
(the same seam `app_bootstrap` overrides, cache = `NoOpLocalCache`), signs in by
email/password, reads the `tenantId` claim through `tenantIdProvider`, and
performs ONE bounded read (`menus` `.limit(20)`).

A missing web config is not a stack trace: the shell names the exact
`--dart-define` values it needs (the web Firebase app is a human-only console
action, `ROADMAP.md`).

## 5. Evidence, and what is still open

- `flutter analyze --no-pub lib/shell tool` → **No issues found** after the
  `implementation_imports` exception note (the deep core imports are D-050's
  requirement, not an oversight).
- `flutter build web --release --target lib/shell/main.dart` → **BUILD_EXIT=0**,
  `√ Built build\web`, compile **54.7 s** (the P2-0 spike died at 147 s on
  `isar_community`; the same command now completes).
- Artifact sizes from that run: `build/web` **37 MB** total (includes the
  CanvasKit bundle), `build/web/main.dart.js` **2 530 990 bytes (2.4 MB)**.
- The first build attempt failed with `The argument type 'String?' can't be
  assigned to the parameter type 'String'` at the `FirebaseOptions` construction
  — `messagingSenderId` is non-nullable in `firebase_core` 4.x. Fixed by
  requiring it in the shell's missing-config list rather than passing an empty
  string; rebuilt clean.

**Gate battery:** `checkpoints/gate-20261114T150203Z.md`, `GATE_EXIT=0`,
**11/11 PASS** (a 46.6 s, b 594.5 s, c 34.7 s, d 46.3 s, e 2.5 s, f 0.0 s over
31 files, i 1.3 s, g 24.2 s, h 1.2 s, j 78.4 s, k 23.2 s). Gate (f) now scans
31 files (was 23) — the new shell, sink and checker files are in scope.

**A note on the required parameter, from the gate itself:** the first run after
this change FAILED gate (a) with 12 `missing_required_argument` errors in test
files my earlier `grep | head` had truncated away (`test/golden`, `test/wiring`,
`test/integration`, `test/widget`). That is the compiler doing exactly what D-050
wanted — naming every construction site — and it is why the final count is 28
production+test sites in `core_app`/`packages/core` plus these 12.

## 6. Item 4 — the emulator proof (2026-11-15) — DONE

Instrument: `tool/shell_proof.mjs` (`up` / `verify` / `down`) + a release web
build served over HTTP, per **D-058**. The harness allocates free ports (this
machine holds 8080/8090), seeds `counter@shell.test` with `tenantId:
tenant_shell` **and proves the claim on the issued token**, then writes three
`menus` rows: `proof_1` `Proof Shawarma` 1250, `proof_2` `Proof Falafel` 900 (both
`tenant_shell`) and `proof_other` `Other Tenant Burger` 5000 (`tenant_other`).

### 6a. Browser boot trace (release build, console, verbatim)

```
[shell] boot: app ready
[shell] boot: auth emulator bound
[shell] boot: firestore emulator bound
[shell] boot: logger ready
[shell] boot: container built
[shell] signIn: begin
[shell] signIn: done counter@shell.test
[shell] claim: tenant_shell
[shell] read: 2 row(s) in 450ms for tenant_shell → [Proof Shawarma, Proof Falafel]
```

That is the card's DONE clause in one transcript: boots, signs in, the claim
reports the tenant, and ONE bounded read returns exactly that tenant's two rows —
the decoy is absent. (`Other Tenant Burger` cannot appear: it is excluded by the
query constraint and would be denied by `tenantOk()` besides.)

Build that produced it: `flutter build web --release --target lib/shell/main.dart`
→ **BUILD_EXIT=0**, compile **77.4 s**, `build/web/main.dart.js`
**2 565 636 bytes (2.45 MB)**, `build/web` **37 MB**.

Re-run on the final (reviewed) build, same trace, read now warm:
`[shell] read: 2 row(s) in 52ms for tenant_shell → [Proof Shawarma, Proof Falafel]`
(the 450 ms above is the cold first read, which includes the listen channel
handshake). The import-graph checker now walks **27 file(s)** (was 24 —
`shell_config.dart` and `shell_session.dart` joined the graph) and still prints
`PASS: no Isar, no dart:io and no core barrel on any shell path`.

First paint (same build, Performance API): **519 ms** `first-contentful-paint`
on a warm reload; **9018 ms** on the cold load with an empty HTTP cache (it
fetches CanvasKit and the 10 Firebase JS SDK bundles from the CDN).

### 6b. Outside-the-browser verification (`node tool/shell_proof.mjs verify`)

Asked with the app user's own ID token, against the same emulators:

```json
{
  "claimTenant": "tenant_shell",
  "constrained": {
    "status": 200,
    "count": 2,
    "names": ["Proof Shawarma", "Proof Falafel"]
  },
  "unconstrainedDenied": true,
  "unconstrainedError": "{\"error\":{\"code\":403,\"message\":\"Property tenantId is undefined on object. for 'list' @ L280\",\"status\":\"PERMISSION_DENIED\"}}"
}
verify OK            # VERIFY_EXIT=0
```

The second half is the negative proof: the SAME query without the `tenantId`
constraint is **403 PERMISSION_DENIED** — Firestore rules are not filters, so the
constraint is mandatory (**D-057**).

### 6c. Four defects the proof found, and their fixes

1. **The read was unconstrained** (`collection('menus').limit(20)`). Rules reject
   it — see 6b. Fixed to
   `where('tenantId', isEqualTo: <claim>)`; recorded as D-057.
2. **The read lived in `build()`**, so a hidden/throttled tab (frames = 0) never
   performed it — the trace stopped at `claim`. Claim + read moved into a boot
   prefetch (`ShellSnapshot`), which is also the right counter behaviour: the
   screen opens with data, not a spinner.
3. **A session restored from a previous emulator run poisoned sign-in**: it
   refreshed against the new config and failed
   `firebase_auth/api-key-not-valid`, and the following sign-in inherited the
   failure. The emulator path now signs out any restored session first.
4. **`flutter test --platform chrome` never loaded this graph** (12-minute
timeout run, then ">10 min loading" with a 3-minute per-test timeout that never
fired). That instrument was deleted rather than committed with a skip; D-058
records why and what replaced it.

**Gate battery (this slice):** `checkpoints/gate-20261115T084733Z.md`,
`GATE_EXIT=0`, **11/11 PASS** (a 452.4 s, b 469.4 s, c 22.3 s, d 52.4 s,
e 5.6 s, f 0.0 s over 4 files, i 2.5 s, g 64.9 s, h 2.1 s, j 130.2 s, k 37.2 s).
Stage (a) is slower than the 193 s baseline because the emulators and the
release build were running beside it on this machine.

### 6d. What is NOT verified here

- **Pixels.** The browser window was minimised for the whole run, so no
  screenshot could be captured (`preview_screenshot` refuses an undrawn tab). The
  widget tree's layout for the signed-in panel is therefore reasoned from the
  code, not seen. Everything asserted above is behaviour, captured from the
  console and the emulators.
- **A second account's isolation in the browser.** `verify` proves the rules
  deny the decoy tenant's row to this user; a second signed-in browser session was
  not run.
