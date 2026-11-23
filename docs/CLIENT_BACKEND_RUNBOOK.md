# CLIENT BACKEND RUNBOOK — Carnama Labs per-client Firebase provisioning

**Owner:** window 3 (white-label + provisioning). **Batch:** BACKEND-1 (W7.1, 09-P0-FB-1).
**Scope:** everything the generator ships EXCEPT GCP project creation (impossible from a repo).
The generator emits `apps/<dir>/backend/` (firestore rules, storage rules, indexes incl. the
W3.6 composite, `.firebaserc`, `firebase.json`); this runbook owns every console-side step.

Keep this document in sync with `archive/PRODUCTION_FIX_PROMPT.md` §12 (VERIFY-IN-CONSOLE).

---

## Prerequisites

- Firebase CLI ≥ 12 (this repo pins 15.x) authenticated with a role that can create/manage
  projects and deploy Cloud Functions for Firebase.
- Node 20 toolchain (functions `engines.node=20`; `npm run build` is the predeploy step).
- Stripe account with LIVE keys: `STRIPE_SECRET_KEY` and webhook signing secret
  `STRIPE_WEBHOOK_SECRET`.
- The generated app dir with its backend bundle:
  `dart run tool/whitelabel.dart --config <client_config.json>` (writes `apps/<dir>/backend/`).
- Owner role on Google Cloud for the project being created.

---

## Ordered console operations

### Step 1 — Create the Firebase project

1. Firebase console → **Add project** → name it for the brand (e.g. `demo-tenant`).
2. Record the **project ID**; it must equal `firebase.projectId` in the client config
   (the generator wired it into `apps/<dir>/backend/.firebaserc`).
3. Verify reachability with the deploy tool preflight:
   `npm run deploy:backend -- --app <dir> --check-only` → the first check
   (`project-reachable`) must print PASS before continuing.

### Step 2 — Enable auth providers

1. **Authentication → Sign-in method**.
2. Enable **Email/Password** and **Anonymous** — the rules branch on
   `sign_in_provider == 'anonymous'` and the app flows use both.
3. Set authorized domains for the app's web origins / iOS bundle ID / Android package name.

### Step 3 — Register App Check apps

1. **App Check → Apps**: register the Android app (package = `app.bundleId`) and the iOS app
   (bundle = `app.bundleId`).
2. Under each, register the provider Play Integrity (Android) / App Attest (iOS). In debug
   builds use the debug provider for local testers.
3. Do NOT flip enforcement to STRICT yet — §12.1 first (production claims must be proven).

### Step 4 — Enable Blaze (pay-as-you-go) billing

1. **Project settings → Usage and billing → Upgrade to Blaze**.
2. Cloud Functions, Storage and App Check enforcement require the Blaze plan.

### Step 5 — Configure the Stripe webhook endpoint

1. Stripe dashboard → **Developers → Webhooks → Add endpoint**:
   `https://<region>-<project>.cloudfunctions.net/stripeWebhook`
   (region = the functions deploy region; project = this client's project ID).
2. Subscribe the endpoint to at least: `payment_intent.succeeded`,
   `charge.refunded`, `charge.dispute.created` (matches `stripeWebhook`'s dispatched types).
3. Copy the **signing secret** (`whsec_...`) — needed in Step 6.

### Step 6 — Set the Stripe secrets (Secret Manager)

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY --project <projectId>
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project <projectId>
```

The functions read `process.env.STRIPE_SECRET_KEY` / `process.env.STRIPE_WEBHOOK_SECRET`;
Secret Manager secrets are surfaced as env vars to deployed functions automatically.
The deploy tool's preflight (`stripe-secret-key`, `stripe-webhook-secret`) verifies both
are accessible before any deploy starts.

### Step 7 — Deploy the backend bundle

```bash
cd core_app
npm run deploy:backend -- --app <dir>
```

The tool:
1. validates the bundle (integrity: rules/indexes/storage/.firebaserc/firebase.json +
   shared functions source), then
2. runs preflight (project reachable, both Stripe secrets set, Android + iOS apps
   registered) — **any FAIL aborts with exit 1, nothing deploys**; then
3. deploys `firestore:rules,firestore:indexes,storage,functions` with `--project <projectId>`
   using the bundle's `firebase.json` (functions source = the SHARED `core_app/functions`).

Use `--check-only` any time to re-verify readiness without deploying.

### Step 8 — Run the data migrations (v002 + v003)

The migrations are bootstrap artifacts under `core_app/functions/src/migrations/`
(emulator/bootstrap-only, never imported by `index.ts`). Run them against the deployed
backend exactly once per project, in order:

```bash
cd core_app/functions
npm run build
firebase emulators:exec --project <projectId> \
  "node lib/migrations/v002__seed_admin_user.js && node lib/migrations/v003__seed_settings_owner_info.js"
```

- **v002** seeds the initial admin user (needed before any owner-gated write can succeed).
- **v003** seeds `settings/ownerInfo { ownerEmail, updatedAt }` — `isOwner()` is dead on a
  fresh backend until that doc exists, so ALL owner-gated writes/uploads fail out-of-the-box.
  Rerunning is safe: both guard with an idempotent `doc.exists` check.

### Step 9 — Set Remote Config keys

1. **Remote Config → Params**:
   - `admin_pin` (release pin used by the owner bootstrap flow; set per-client).
   - force-update minimum versions keys (e.g. `forceUpdateMinVersion.android`,
     `forceUpdateMinVersion.ios`) — used by the app's ForceUpdateGuard.
2. Publish after all values are entered. A fresh backend has NO defaults; leaving them unset
   means the guard falls back to fail-closed behavior — verify with the app.

### Step 10 — Create the `firestore-security-alerts` alerting pipeline (closes 09-P1-FB-5)

`onFirestorePermissionDenied` consumes Pub/Sub topic `firestore-security-alerts`; nothing in
the repo publishes to it — the sink is a console-side prerequisite, otherwise the alerts
are dead plumbing:

1. **Pub/Sub → Create topic**: `firestore-security-alerts`.
2. Grant the Firestore service account `roles/pubsub.publisher` on the topic.
3. **Cloud Logging → Create sink**:
   - filter: `protoPayload.status.code=7` (permissions-denied audit entries), plus the
     function's `[firestore-security-alerts]` marker stream from `console.error`:
     `protoPayload.status.code=7 OR (logName:"cloudfunctions.googleapis.com" AND textPayload:"[firestore-security-alerts]")`
   - destination: Pub/Sub topic `firestore-security-alerts`.
4. Verify: deliberately cause a permission-denied read; confirm the alert traverses the path
   (console → sink → topic → Cloud Function invocation).

### Step 11 — Verify the client end-to-end

1. **App Check**: mint a live token, inspect the ID token for `app_id` + `firebase.app_check_token`
   (see §12.1); only then flip `settings/featureFlags.strongAppCheck=true`.
2. **Boot proof**: install the generated shell on a device, boot WITH Firebase, confirm auth /
   Firestore / FCM initialize (no `ConfigErrorScreen`).
3. **Indexes**: open the revenue chart on real data — the `orders(status ASC, createdAt ASC)`
   composite must serve it (no `failed-precondition` in Logs Explorer).
4. **Money**: run a test charge + refund + cancel-refund against the live endpoint
   (Stripe test keys first, then a real smoke charge).

---

## Section-12 checklist coverage (VERIFY-IN-CONSOLE)

| Item | Console op (see above) | Proven by |
|------|------------------------|-----------|
| 12.1 | App Check production claims (`app_id` + `firebase.app_check_token` present BEFORE `strongAppCheck=true`) | Step 11.1 |
| 12.2 | Per-client backend runbook executed (project created; rules/indexes/functions/storage deployed; webhook endpoint live; App Check apps registered; v002+v003 migrations run; Remote Config keys set) | Steps 1–11 |
| 12.3 | `demo-tenant`: real API keys in `apps/halal_boyz/assets/client_config.json`, shell regenerated, boot WITH Firebase proven by logs | Step 11.2 |
| 12.4 | Indexes deployed incl. `orders(status ASC, createdAt ASC)`; charts verified on real data (no `failed-precondition`) | Step 11.3 |
| 12.5 | Stripe: live keys per project, webhook signing secret set, test charge + refund + cancel-refund exercised end-to-end | Steps 5–6, 11.4 |
| 12.6 | `firestore-security-alerts`: Pub/Sub topic + Cloud Logging sink created; a deliberate denial traverses the alert path | Step 10 |
| 12.7 | Store presence: listings + privacy/data-safety forms matching the audit-06 PII inventory + screenshots + POST_NOTIFICATIONS disclosure | Store console (outside this repo) |
| 12.8 | Remote Config: `admin_pin` release path + force-update minimum versions set | Step 9 |

---

## Reference commands

```bash
# Preflight only (deploys nothing)
npm run deploy:backend -- --app <dir> --check-only

# Full deploy
npm run deploy:backend -- --app <dir>

# Equivalent direct invocations
dart run tool/deploy_backend.dart --app <dir> --check-only
dart run tool/deploy_backend.dart --app <dir>

# Set Stripe secrets (first-time per project)
firebase functions:secrets:set STRIPE_SECRET_KEY --project <projectId>
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project <projectId>
```

## Fail-closed notes

- The deploy tool NEVER continues when a preflight check FAILs; a FAIL means the operator
  must resolve the item and re-run. No silent partial deploys.
- `firebase deploy` itself requires a live project + auth — it is executed per client
  project by the operator at provisioning time (RELEASE-2 coordinates the full battery).
- The bundle `firebase.json` functions `source` (the SHARED `core_app/functions`) is
  resolved relative to the bundle dir — never copy functions into a brand.
- Emulator hosts in the core `firebase.json` bind `0.0.0.0` (CI-only note, 09-P2): the
  bundle's deploy `firebase.json` intentionally carries NO emulator block.