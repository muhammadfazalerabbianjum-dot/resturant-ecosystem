# RUNBOOK_DEPLOY.md — Cloud Functions / Firebase deploy lane (operator runbook)

**Batch:** PERF-4 (re-scoped: docs-only) · **Status:** EXECUTED 2026-09-15 · **Verified at tip:** `60a25d2`
**Scope:** the deploy lane for `core_app/functions` + per-client backend provisioning. This runbook documents; it does NOT execute (no Blaze project here — see §4 Residuals).

**CI Tier 8 already proves the functions gate** (`npm ci → npm run lint → npx tsc --noEmit → npm test`, wired into `ci-gate` at `.github/workflows/carnama_ci.yml:388` — job `functions` at `:347-374`). This runbook covers everything CI cannot: Blaze, secrets, webhooks, App Check enforcement, per-client projects, seeds, pre-deploy smoke.

---

## 0. EVIDENCE TABLE (verified against HEAD `60a25d2` before this runbook was written)

| Claim | Proof (verified) |
|---|---|
| Functions runtime = node 20, v2 API | `core_app/functions/package.json` → `"engines": {"node": "20"}`; `firebase-functions ^5.0.0`; imports `firebase-functions/v2/https` (`functions/src/index.ts:2`) |
| Secrets read from `process.env` at runtime; declared via `defineSecret` since PERF-6d (deploy-time fail-closed validation) | `STRIPE_SECRET_KEY` at `functions/src/index.ts:939, 1098, 1317, 1520, 1522, 1526, 1885`; webhook secret at `:1875` |
| Webhook is a raw `onRequest` | `export const stripeWebhook = onRequest(...)` — `index.ts:1873`; signature verify `stripe.webhooks.constructEvent` `:1886`; missing secret → HTTP 400 fail-closed `:1877-1879` |
| Webhook events consumed | `payment_intent.succeeded` `:1803` · `payment_intent.payment_failed` `:1824` · `charge.refunded` `:1841`; unknown types = acknowledged no-op `:1869-1870` |
| Callables enforce App Check in code | `enforceAppCheck()` `index.ts:60-68` — called on ALL callables (`:116, 157, 183, 226, 488, 647, 802, 1004, 1052, 1495`) |
| Client already sends App Check tokens | `core_app/lib/app_bootstrap.dart:556-572` — `playIntegrity` (Android) / `appAttest` (Apple) / `ReCaptchaV3` (web, `RECAPTCHA_WEB_KEY`); debug providers in `kDebugMode` |
| Rules-side App Check = flag-gated | `core_app/firestore.rules:13-35` — RELAXED (OR) by default; STRICT (AND) when `settings/featureFlags.strongAppCheck == true` |
| Tier-4 rules command | `core_app/package.json:8` → `test:rules = firebase emulators:exec --only firestore "node test/rules/firestore_rules_test.js"` (CI: `carnama_ci.yml:194-196`, firebase-tools pinned `15.15.0` at `:26`) |
| Master project | `core_app/.firebaserc` → `default: resturants-8547d`; `core_app/firebase.json` → `functions.source = "functions"`, predeploy `npm run build` |
| Generator emits per-client backend + options | `core_app/tool/whitelabel.dart` → `<app>/lib/firebase_options.dart` + `<app>/backend/{firestore.rules, storage.rules, firestore.indexes.json, .firebaserc, firebase.json}` (bundle's `firebase.json` points `functions.source` at `../../core_app/functions`) |
| Per-client backend deploy tool | `core_app/tool/deploy_backend.dart` — `dart run tool/deploy_backend.dart --app <dir>`; preflight gates, then `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`; also wired as `npm run deploy:backend -- --app <dir>` (`core_app/package.json:12`) |
| Migrations v001–v003 | `core_app/functions/src/migrations/v001__seed_branches.ts` · `v002__seed_admin_user.ts` · `v003__seed_settings_owner_info.ts` (v001/v002 export `migrate()`; v003 has a `require.main` guard) |
| Seeds | `core_app/tool/seed_test_accounts.js` · `seed_menu_data.js` · `seed_promotions.js` · `seed_demo_data.js` (fail-closed: refuses without `settings/ownerInfo` → run v002+v003 first) |
| Env hygiene | `core_app/functions/.gitignore` ignores `*.env` (`!.env.example`) — secret files cannot be committed |

## 1. SELF-VERIFYING GREP (run before using this runbook — names are load-bearing)

Paste this exact command and compare against §0. If anything drifts, STOP and update this runbook first.

```bash
grep -n "STRIPE_SECRET_KEY\|STRIPE_WEBHOOK_SECRET\|strongAppCheck" \
  core_app/functions/src/index.ts core_app/functions/src/*.ts core_app/firestore.rules
```

Expected (at `60a25d2`): 7 × `STRIPE_SECRET_KEY` in `index.ts` (939, 1098, 1317, 1520, 1522, 1526, 1885), 1 × `STRIPE_WEBHOOK_SECRET` (1875), and the `strongAppCheck` rules helpers (`firestore.rules:22-35`).

**Executor output (paste here on use):** `_PASTE GREP OUTPUT_`

## 2. OPERATOR STEPS (master project)

### (a) Blaze upgrade + billing
1. Firebase console → project `resturants-8547d` → **Usage and billing** → **Upgrade to Blaze** (pay-as-you-go; Cloud Functions v2 + outbound webhooks require it).
2. Link/verify the billing account; set a **budget alert** (recommended: $50 hard, $30 warning) before the first deploy.
3. Verify CLI + project: `npx firebase-tools@15.15.0 use --add` (select `resturants-8547d`).

### (b) Deploy functions
```bash
cd core_app/functions
npm ci
npx tsc --noEmit        # must exit 0
firebase deploy --only functions --project resturants-8547d
```
Node 20, functions v2 (predeploy builds via `firebase.json` → `npm --prefix "$RESOURCE_DIR" run build`). Note the printed function URLs — the webhook URL comes from there (step d).

### (c) Stripe secrets (names MUST match the code — see §1 grep)
Functions read `process.env.STRIPE_SECRET_KEY` / `process.env.STRIPE_WEBHOOK_SECRET`; since PERF-6d the source also declares both via `defineSecret` (`firebase-functions/params`), so a deploy **fails closed** when either secret is missing. Provision via the v2 `.env` file mechanism (below), or equivalently `firebase functions:secrets:set STRIPE_SECRET_KEY` / `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET` — runtime injection is identical either way (v2 injects declared secrets as env vars), which is why the code's `process.env` reads are unchanged:

1. Get the **restricted** API key from the Stripe dashboard (server-side only — never the publishable key).
2. Get the webhook signing secret from step (d) — set the env only after Stripe shows it.
3. Create `core_app/functions/.env.resturants-8547d` (v2 convention: `.env.<PROJECT_ID>`; gitignored — never commit):
   ```
   STRIPE_SECRET_KEY=sk_live_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```
4. Redeploy functions (step b). Confirm injection: after a test event, `firebase functions:log --project resturants-8547d` shows NO "Webhook Secret Missing" (the fail-closed 400 at `index.ts:1877-1879`).

### (d) Stripe webhook endpoint
1. Stripe dashboard → **Developers → Webhooks → Add endpoint**.
2. URL: `https://us-central1-resturants-8547d.cloudfunctions.net/stripeWebhook` (v2 default region — confirm against the URL printed by step (b)).
3. Subscribe the events the code consumes (`index.ts:1803-1841`): `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`. Extra events are safe (unknown types are acknowledged no-ops, `:1869-1870`).

### (e) Firebase App Check enforcement
The client already sends tokens (`app_bootstrap.dart:556-572`); the callables hard-enforce in code (`index.ts:60-68`). Remaining console work:

1. **App Check console** → register the app(s): `playIntegrity` (Android release), `appAttest` (iOS), `reCAPTCHA v3` key via `RECAPTCHA_WEB_KEY` (web). For debug builds add the debug-token stream.
2. Enable **App Check enforcement** for **Functions** (start in *monitor*, then *enforced*), then **Firestore** and **Storage**.
3. **Claim probe before STRICT mode:** verify a live production ID token actually carries `app_id` and `firebase.app_check_token` (the rules logic is proven by the harness INJECTING those claims — `test/rules/firestore_rules_test.js:32-33`; production emission must be observed, not assumed). Only after the probe passes: set `settings/featureFlags.strongAppCheck = true` (STRICT AND-mode, `firestore.rules:22-35`). Flag absent/false = relaxed — the fail-safe design never bricks a platform.

### (f) Per-client Firebase project (white-label)
1. Create the client's own Firebase project + Blaze; register Android (client bundleId) and iOS apps; download `google-services.json` / `GoogleService-Info.plist` into the shell (`apps/<client>/android/app/`, `apps/<client>/ios/Runner/`).
2. Fill `assets/client_config.json` firebase identity: `firebase.projectId`, `firebase.androidAppId`, `firebase.iosAppId`, `firebase.messagingSenderId`, `firebase.storageBucket`, `environment.firebaseAndroidApiKey`, `environment.firebaseIosApiKey`.
3. Generate: `dart run core_app/tool/whitelabel.dart --config apps/<client>/assets/client_config.json` — emits `lib/firebase_options.dart` (stamped from the config) + the `backend/` bundle. `firebase_config_truth_test.dart` pins config ⇄ native files ⇄ emitted options (zero cross-brand leakage).
4. Deploy the client's backend (rules, indexes, storage, functions against the client project):
   ```bash
   cd core_app
   dart run tool/deploy_backend.dart --app <client>     # or: npm run deploy:backend -- --app <client>
   ```
   Preflight must PASS before anything deploys; the tool never deploys a half-provisioned bundle.

4. Copy the signing secret `whsec_...` into `.env.resturants-8547d` (step c) and redeploy.
5. Verify: Stripe dashboard → endpoint → **Send test webhook** (`payment_intent.succeeded`) → expect HTTP 200; functions log shows `Order ... successfully validated via Webhook.`

### (g) Seeds (fresh project — order is load-bearing)
Against the target project (service-account env `GOOGLE_APPLICATION_CREDENTIALS=<sa.json>`, or emulator env `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` + `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099`):
1. `npm run test:migrations` (from `core_app`) — proves the v003 lane end-to-end under emulators.
2. Migrations v001 → v002 → v003 (`core_app/functions/lib/migrations/*.js` — v001/v002 expose `migrate()`; v003 has a `require.main` guard). v003 seeds `settings/ownerInfo` — **the owner email gates owner features; skip it and every owner-gated surface is dead.**
3. Then, from `core_app/tool/`: `node seed_test_accounts.js` (owner/kitchen/delivery accounts), `node seed_menu_data.js`, `node seed_promotions.js`, `node seed_demo_data.js`.
4. Verify fail-closed: `node seed_demo_data.js` against a project WITHOUT `settings/ownerInfo` must abort with `settings/ownerInfo missing — run migrations v002 then v003 first`.

### (h) Pre-deploy smoke (all three must be green before every functions deploy)
```bash
cd core_app/functions && npm test                          # build + node --test
node scripts/money_emulator_check.js                       # with emulators running (or: cd .. && npm run test:money-emulator)
cd .. && npm run test:rules                                # Tier-4 command (emulator)
```
Expected: functions tests all pass; money check exit 0 (server re-pricing + tampered-total DENIED); rules suite 0 failed.

## 3. RELEASE ORDER (one client, condensed)

Blaze (a) → smoke (h) → functions deploy (b) → secrets (c) → webhook (d) → App Check (e) → seeds (g) → per-client loop (f) → on-device smoke (order, payment, webhook confirmation, cancel, GDPR erase).

## 4. HONEST RESIDUALS (flagged, NOT fixed — docs-only batch)

1. Seed SA path — CORRECTED (p33 T-4): `core_app/tool/seed_test_accounts.js:17-23` (PERF-6c) resolves the operator-held key `GOOGLE_APPLICATION_CREDENTIALS` → ADC → fail-closed abort with instructions; the seeder carries no machine-specific path. The previous wording of this row (a local service-account path at `:11`) was STALE docs, retired here — no tool fix is outstanding.
2. Secrets ride `.env.<project>` because `functions/src` declares no `defineSecret`. Secret Manager + `defineSecret` is the harder option but is a CODE change — out of territory, handoff note only.
3. Steps (a)/(d)/(e) require console access and a live Stripe account; none are executable from this repo. Each step lands with its own verification command so the operator's run is self-checking.
4. The emulator smoke in (h) uses the CI-pinned firebase-tools `15.15.0` (`carnama_ci.yml:26`) — keep operator installs in sync with the pin.


