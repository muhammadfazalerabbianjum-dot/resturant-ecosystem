# BATCH ROUTER-3 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W2.7, W2.8.**

## 6. BATCH ROUTER-3 - CONFIG-MODE ROUTER TESTS + NETWORK-BLOCKER HARNESS

**Predecessor:** ROUTER-1 (independent of ROUTER-2). **Emulator-gated:** no. **Master:** W2.7, W2.8.

### 6.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `test/app/` (8 files) + `test/core/router/` (17 files) | Router tested ONLY in static mode; 0 references to `config`/`mode` - kiosk exposing managerDashboard or config route missing from RouteNames ships untested | P1 (07-P1-5) |
| P-2 | all 231 test files | Documented network-blocker harness does NOT exist (grep `NetworkBlocker|HttpOverrides` = 1 unrelated comment) - widget tests can silently hit real network / be order-dependent | P1 (07-P1-6) |

### 6.2 Solution - design principle + acceptance contract

**Design principle:** test the ACTUAL config-driven router; isolate the transport so no test can touch the network.

**Acceptance contract (from master W2.7/W2.8):**
1. Create 3 config-mode router test files in `core_app/test/app/`: for each `ConfigMode` value, build the router from a `ClientConfig` fixture and assert (1) every whitelisted route resolves (never `find.byType(NotFoundScreen)`), (2) every `RouteNames.*` constant resolves only when mode-allowed, (3) mode-forbidden navigation fails closed, (4) a test asserting every `screens[].id` in BOTH client_config.jsons is a key of `_screenIdToRouteName` (the ROUTER-1 guard).
2. Create `core_app/test/helpers/network_blocker.dart`: `HttpOverrides` returning a failing `HttpClient` + `NetworkBlockedException`; plus a `blockNetworkImages()` variant.
3. Wire into `core_app/flutter_test_config.dart` (it already runs `setupFirebaseAuthMocks()` for every test).
4. Add one canary test asserting outbound `HttpClient().getUrl(...)` throws `NetworkBlockedException`.

### 6.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Config-mode whitelist resolves per mode | 3 test files x every whitelisted route -> no NotFoundScreen |
| T-2 | RouteNames resolves only when mode-allowed | Forbidden navigation fails closed |
| T-3 | Every config screens[].id is mapped | Config-json vs `_screenIdToRouteName` comparison test |
| T-4 | Network blocked everywhere | Canary: `HttpClient().getUrl` throws `NetworkBlockedException` under `flutter_test_config.dart` |
| T-5 | Existing suites still green under the blocker | `flutter test test/app test/core/router test/helpers` |

### 6.4 Proof gates

- [ ] New test files green under `flutter test test/app` + `flutter test test/helpers`
- [ ] Canary asserts `NetworkBlockedException`
- [ ] grep `HttpOverrides` in test helpers present
- [ ] Universal Gate Set U (index Section 1)

### 6.5 Honest residuals

- The blocker harness proves transport isolation at the `HttpClient` layer; Firebase/Stripe SDKs have their own mocks (`test/mock_firebase.dart`) - those are out of scope here.
- If any test legitimately needs network (e.g., a golden fetching a remote image), that test must use the `blockNetworkImages()` exemption explicitly documented - never a blanket bypass.

**END OF BATCH ROUTER-3 SPEC** - do not proceed until these gates pass and the ROUTER-3 addendum is appended to FIX_VERIFICATION.md.