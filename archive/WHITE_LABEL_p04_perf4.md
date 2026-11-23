# WHITE_LABEL_p04_perf4.md — PERF-4 (CF deploy lane → OPERATOR RUNBOOK)

Status: PLANNED (re-scoped 2026-09-15, pre-execution) · Predecessor: PERF-3 (DONE, `0b0178f`) · Emulator: not required
Executing window: `cline-1` (synced to `0b0178f`, format gate clean)

## 0. RE-SCOPE (recorded — do NOT build what already exists)
The original PERF-4 proposal ("CI job for `npm run lint && npm test`") is **ALREADY AT HEAD**: CI **Tier 8 "Cloud Functions Gate"** (`carnama_ci.yml:347-374`) runs `npm ci` → `npm run lint` → `npx tsc --noEmit` → `npm test`, wired into the final `ci-gate` (`:388`). The remaining gap is KNOWLEDGE, not code: the deploy lane exists only as tribal knowledge. This batch is therefore **runbook-only** (class-(c) material executed as a batch so it enters the machine).

## 1. PROVEN PROBLEMS
| # | Problem | Proof |
|---|---|---|
| P-1 | No runbook for the functions deploy path: Blaze, deploy, secrets, App Check, webhook, per-client projects, seeds, emulator smoke — none documented anywhere in the repo. | repo-root md sweep 2026-09-15 |
| P-2 | Secret names are load-bearing: functions read `process.env.STRIPE_SECRET_KEY` (`index.ts:939,1098,1317,1520-1526`); `stripeWebhook` is an `onRequest` at `index.ts:1873`. A runbook with wrong names would be fiction. | grep 2026-09-15 |

## 2. TERRITORY
`RUNBOOK_DEPLOY.md` (new, repo root) · `WHITE_LABEL_BATCHES.md` §4 (one row). **NO `.dart`/`.yaml`/`.ts`/workflow changes — docs-only batch.**

## 3. ACCEPTANCE CONTRACT
1. `RUNBOOK_DEPLOY.md` gives exact, copy-pasteable operator steps for: (a) Blaze upgrade + billing; (b) `firebase deploy --only functions` from `core_app/functions` (node 20, v2); (c) `STRIPE_SECRET_KEY` provisioning (name MUST match the code) and the webhook secret consumed by `stripeWebhook`; (d) Stripe webhook endpoint registration → the deployed `stripeWebhook` URL; (e) Firebase App Check enforcement (Functions/Firestore/Storage) — the client already sends App Check tokens; (f) per-client Firebase project + `google-services.json`/`firebase_options` via the generator's outputs; (g) seeds: migrations v001–v003 + `seed_test_accounts.js` / `seed_menu_data.js` / `seed_promotions.js`; (h) pre-deploy smoke: `npm test`, `node scripts/money_emulator_check.js`, `npm run test:rules` (Tier-4 command).
2. **Self-verifying runbook:** it embeds the grep command proving every secret/flag name it documents exists in `functions/src` — the executor runs it and pastes the output in the addendum.
3. `git diff --name-only main..` = `.md` files ONLY (docs-only proof).
4. §4 map row + addendum per the standard cadence.

## 4. GATES
Standard Gate Set U (format must stay 0-changed) + the docs-only diff proof + the secret-name grep parity proof.

## 5. HONEST RESIDUALS
- The runbook documents; it does not EXECUTE the deploy (no Blaze project here). Operator items remain operator items until they run it — each step lands with its verification command so the operator's run is self-checking.
