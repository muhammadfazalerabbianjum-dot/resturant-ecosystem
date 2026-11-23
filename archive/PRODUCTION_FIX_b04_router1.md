# BATCH ROUTER-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W2.1, W2.2, W2.3.**

## 4. BATCH ROUTER-1 - ROUTE-NAME RESOLUTION + GO_ROUTER API SWAPS

**Predecessor:** CI-3. **Emulator-gated:** no. **Master:** W2.1, W2.2, W2.3. **MIRROR: yes - both routers.**

### 4.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/lib/app/app_router.dart:144-150` | Config mode ACTIVE but routes register under screen-ID names (`'LoginScreen'`...) while all 35 named-nav call sites use `RouteNames.*` -> every tap throws at runtime | P0 (00-P0-1) |
| P-2 | `core_app/lib/main.dart:269` | Deep-link handler uses `Navigator.pushNamed(path)` (name API fed a PATH) on a go_router stack; table advertises inactive routes | P0 (00-P0-2) |
| P-3 | `core_app/lib/main.dart:108-110` | ErrorWidget "Restart" uses `pushReplacementNamed('/')` - fires when app is already broken | P0 (00-P0-3) |
| P-4 | `core_app/lib/main.dart:262` | `pushReplacementNamed('/login')` - same broken-API class (auth-state listener path) | P0 (00-P0-3 class) |

### 4.2 Solution - design principle + acceptance contract

**Design principle:** `RouteNames` constants are the single source for named nav (35 sites); the config branch must resolve screen-ids THROUGH that map (compile-checked), never the reverse. go_router is the active stack - all navigation goes through it.

**Acceptance contract (from master W2.1/W2.2/W2.3):**
1. In `_buildRoutesFromConfig` (config branch ~:143-167): add `const Map<String, String> _screenIdToRouteName = { 'SplashScreen': RouteNames.splash, 'LoginScreen': RouteNames.login, ... }` covering EVERY `screens[].id` in BOTH `core_app/assets/client_config.json` and `apps/halal_boyz/assets/client_config.json` (enumerate ids from the JSONs; values from `core_app/lib/app/navigation/route_names.dart`). Registration: `name = _screenIdToRouteName[screen['id']]`; unmapped id -> debug `assert(false, ...)` + `logger.error` + SKIP registration; release: log-and-skip. Static table untouched.
2. `main.dart:269`: replace `navigatorKey.currentState?.pushNamed(path)` with go_router path navigation (`router.push(path)`); log-and-ignore unknown paths (never throw). PRUNE the deep-link table to the 26 ACTIVE config-mode paths (drop `/owner`, `/admin`, `/logs` or map through the role gateway).
3. `main.dart:108-110`: `context.go('/')` (ErrorWidget builder has BuildContext).
4. `main.dart:262`: `router.go(RouteNames.login)`.
5. After the batch, grep `pushNamed|pushReplacementNamed` across `core_app/lib` + `apps/halal_boyz/lib` = 0 (fix any stragglers).
6. MIRROR: apply identically to `apps/halal_boyz/lib/app/app_router.dart` + `apps/halal_boyz/lib/main.dart` (verify they carry the same code first).

### 4.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Every `screens[].id` in both configs is a key of the map | New unit test iterating both JSONs vs `_screenIdToRouteName` |
| T-2 | Config-mode named nav resolves | New widget test: build router from config fixture, `goNamed(RouteNames.login)` lands on LoginScreen (not NotFound) |
| T-3 | Deep-link handler uses go_router | grep `pushNamed` in lib = 0 |
| T-4 | ErrorWidget restart works | Widget test: trigger ErrorWidget, tap Restart, assert home renders |
| T-5 | Existing static-mode router tests still green | `flutter test test/app test/core/router` |

### 4.4 Proof gates

- [ ] grep `pushNamed|pushReplacementNamed` in `core_app/lib` + `apps/halal_boyz/lib` = 0
- [ ] `flutter analyze --fatal-infos` green (core_app + halal)
- [ ] T-1..T-5 green
- [ ] Universal Gate Set U (index Section 1)

### 4.5 Honest residuals

- The crash behavior at unknown route names is asserted from go_router 14.8.1 source (`configuration.dart:266-267`), not a failing integration run - T-2/T-3 close that gap behaviorally.
- The deep-link table prune must match the ACTUAL 26 active paths; if the configs differ between core and halal, the table is per-app (mirror both).

**PARALLEL MODE (§3.5):** if running in a `cline/task-N` worktree, append the addendum to `FIX_VERIFICATION_cline-task-N.md` in YOUR worktree (never the shared `FIX_VERIFICATION.md`), commit everything in your worktree, and STOP at the end of this spec — predecessor-gating and merge-back are performed on `main` by the operator per §3.5. In sequential mode the line below applies unchanged.

**END OF BATCH ROUTER-1 SPEC** - do not proceed to ROUTER-2/ROUTER-3 until these gates pass and the ROUTER-1 addendum is appended to FIX_VERIFICATION.md.