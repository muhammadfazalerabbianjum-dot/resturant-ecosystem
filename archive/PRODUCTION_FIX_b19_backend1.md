# BATCH BACKEND-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W7.1.**

## 19. BATCH BACKEND-1 - GENERATOR BACKEND BUNDLE + RUNBOOK + DEPLOY TOOL

**Predecessor:** MONEY-3 AND WL-2. **Emulator-gated:** no. **Master:** W7.1. **MIRROR: generator output IS the shell - dry-run a throwaway `apps/<scratch>` to prove, then remove scratch.**

### 19.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `apps/*` (recursive search) | Generated shells ship NO `firestore.rules`/`firestore.indexes.json`/`storage.rules`/`.firebaserc` - after WL-1's key fix, brands boot on UNPROVISIONED projects | P0 (09-P0-FB-1) |
| P-2 | `.firebaserc:1-5` | Single project `resturants-8547d`; per-brand project model has no repo artifact | P0 (09-P0-FB-1) |
| P-3 | `index.ts:902` | `firestore-security-alerts` Pub/Sub topic - no publisher/sink in repo (dead plumbing) | P1 (09-P1-FB-5) |

### 19.2 Solution - design principle + acceptance contract

**Design principle:** the generator ships EVERYTHING the deploy needs except GCP project creation (impossible from repo) - the runbook owns that step.

**Acceptance contract (from master W7.1):**
1. `whitelabel.dart` writes into `apps/<dir>/backend/`: `firestore.rules` (template copy - per-project model), `storage.rules`, `firestore.indexes.json` (incl. the W3.6 composite), `.firebaserc` (`projects.default = <config firebase.projectId>`), `firebase.json` (firestore rules/indexes + storage + functions predeploy pointing at the SHARED `core_app/functions`).
2. New `core_app/tool/deploy_backend.dart` (npm script `deploy:backend --app <dir>`): `firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project <projectId>` with preflight checks (project reachable, STRIPE secrets set, App Check apps registered) printing PASS/FAIL per check.
3. New `docs/CLIENT_BACKEND_RUNBOOK.md`: ordered console ops (create project; enable Auth providers; register App Check apps; Blaze; Stripe webhook endpoint `https://<region>-<project>.cloudfunctions.net/stripeWebhook`; deploy backend bundle; run v002+v003 migrations; set Remote Config `admin_pin` + force-update keys; create `firestore-security-alerts` Pub/Sub topic + Cloud Logging sink filter `protoPayload.status.code=7` - closes 09-P1-FB-5; verify).

### 19.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Bundle files written | Generator dry-run into `apps/<scratch>`: assert rules/storage/indexes/.firebaserc/firebase.json exist |
| T-2 | projectId wired | `.firebaserc` in scratch contains the config projectId |
| T-3 | Identity check | scratch applicationId == pbxproj bundle id == config bundleId |
| T-4 | Runbook completeness | Every master section-12 item represented |
| T-5 | Preflight tool present | `deploy_backend.dart` compiles (analyze) |

### 19.4 Proof gates

- [ ] Dry-run writes bundle files (T-1); scratch removed afterward
- [ ] Identity check passes (T-3)
- [ ] Analyze green (tool compiles)
- [ ] Runbook exists covering all section-12 items
- [ ] Universal Gate Set U (index Section 1)

### 19.5 Honest residuals

- `firebase deploy` itself requires live projects + auth - the tool runs it but RELEASE-2 executes it per client project. NOT run in this batch (that would mutate GCP).
- The runbook is the single source for per-client console ops; it must be kept in sync with master section 12.

**END OF BATCH BACKEND-1 SPEC** - do not proceed to BACKEND-2 until these gates pass and the BACKEND-1 addendum is appended to FIX_VERIFICATION.md.