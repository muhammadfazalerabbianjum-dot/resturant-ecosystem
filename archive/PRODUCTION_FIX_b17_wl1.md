# BATCH WL-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W6.1, W6.2, W6.3.**

## 17. BATCH WL-1 - GENERATOR KEY GATE + SHELL FAIL-FAST + FLAGS FORMAT + SHELL LOADER RESILIENCE

**Predecessor:** CI-3. **Emulator-gated:** no. **Master:** W6.1, W6.2, W6.3. **MIRROR: regenerate shell per W6.1(d) or hand-mirror identical gate - state which in ledger.**

### 17.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `whitelabel.dart:68-92, 654` + halal `main.dart:25-28, 49-55` | Firebase API keys ship `""`; `validate()` has no gate; shell silently boots with NO auth/Firestore/FCM (throw swallowed) | P0 (08-P0-WL-1) |
| P-2 | both `client_config.json` `features.flags` | `{"enabled":true}` objects vs parser `bool` -> `_featureFlags ≡ {}`, gating silently inert | P0 (08-P0-WL-2) |
| P-3 | halal `main.dart:15-18` `_loadClientConfig()` | Bare `rootBundle.loadString` + `jsonDecode` NO try/catch -> missing/malformed config crashes at boot (core degrades gracefully) | P1 (08-P1-WL-8) |

### 17.2 Solution - design principle + acceptance contract

**Design principle:** fail-fast, never silent; the generator validates what the generated code consumes; one flag format repo-wide.

**Acceptance contract (from master W6.1/W6.2/W6.3):**
(a) `validate()`: require `environment.firebaseAndroidApiKey` + `environment.firebaseIosApiKey` non-empty and not matching `REPLACE_ME|changeme|<your` (case-insensitive), and `firebase.projectId` non-empty; errors name the exact JSON path.
(b) Shell fail-fast: template `apps/<dir>/lib/main.dart` - if the resolved key is empty/placeholder, render blocking `ConfigErrorScreen` ("Firebase configuration missing - contact the operator") and skip `Firebase.initializeApp` + auth/Firestore/FCM init; never silently continue; `logger.error`. Add a generated widget test asserting the gate (beside the `:1444` honesty-gate test).
(c) Template config ships documented placeholders + the validator forbids placeholders; core keeps its dart-define fallback (`main.dart:36-53`); REAL values per-client ops (master section 12).
(d) MIRROR: regenerate `apps/halal_boyz` via `--regenerate` with real `demo-tenant` values OR hand-mirror the identical gate (state which).
(e) W6.2: flatten `features.flags` to `"flagName": true` (bool) in BOTH configs; `validate()` fails generation when a declared flag doesn't parse to a non-empty bool map; unit test: object-valued flag -> warn + `unknownFlagDefault` fallback (never crash).
(f) W6.3: shell `_loadClientConfig()` gets core's try/catch fallback (defaults + dotenv + recorded error).

### 17.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | validate() rejects empty/placeholder keys | Unit: config fixture -> validation error naming the path |
| T-2 | validate() rejects object-valued flags | Unit: `{"flag":{"enabled":true}}` -> error |
| T-3 | Shell fail-fast renders ConfigErrorScreen | Generated widget test: empty key -> blocking screen, no Firebase init |
| T-4 | Flags parsed non-empty | Unit: flattened config -> `featureFlags` non-empty |
| T-5 | Shell loader resilient | Unit: missing/malformed JSON -> defaults + recorded error, no crash |

### 17.4 Proof gates

- [ ] validate() unit tests green (T-1, T-2)
- [ ] Generated shell analyze green; generated widget test asserts the gate (T-3)
- [ ] Both JSONs parse; flags are bool values
- [ ] Universal Gate Set U (index Section 1)

### 17.5 Honest residuals

- Real `demo-tenant` API key VALUES are console data (master section 12, item 3) - the repo gate + fresh shell are the code-side; the values are ops.
- Core's dart-define fallback stays; the fail-fast applies to the GENERATED shell (which has no other path).

**END OF BATCH WL-1 SPEC** - do not proceed to WL-2 until these gates pass and the WL-1 addendum is appended to FIX_VERIFICATION.md.