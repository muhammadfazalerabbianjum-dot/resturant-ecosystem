# DEMO PHASE 0 LOG — halal_boyz on the Firebase emulator (no Blaze, no Stripe)

**Session:** demo-prep on `<repo>`, branch `main`, tip `315e4ba`.
**Scope:** Playbook §9 Phase 0 — boot the entire backend in the emulator, seed complete
demo data, prove every halal_boyz flow end-to-end, record everything. Reference-only
doc: `docs/CLIENT_BACKEND_RUNBOOK.md` (per-client production provisioning — NOT executed;
this is a demo, no real project, no keys).

**Ground rules honored:** Rule 0 (models + migrations inspected before seeding — sources
cited in `seed_demo_data.js` header) · Rule 2 (no stubs / no fake greens — every PASS
below carries a reproducible command + exit code; the Stripe stop is recorded as the
honest boundary, not faked) · Rule 5 (fail-closed — seed refuses to run without the
migrations, checkout refuses to "succeed" without Stripe) · Rule 9 (the new seed has a
real test: `test/tool/seed_demo_data_test.js`, 12/12 green, red-proven by construction
against an unseeded project) · §3.6 (stay in lane: canonical `archive/FIX_VERIFICATION.md`
untouched, nothing pushed, main-only commit of the reusable seed artifacts).

---

## 1. Environment (all local, free tier)

| Tool | Version |
|---|---|
| Flutter / Dart | 3.41.2 stable / 3.11.0 (matches PRODUCTION_FIX_BATCHES §2 pin) |
| Node | v24.13.1 (functions `engines.node=20` — emulator runs node@24 from host, warning only) |
| npm | 11.8.0 |
| Firebase CLI | 15.15.0 |
| Project (emulator namespace) | `resturants-8547d` (from `core_app/.firebaserc`) |

Emulator suite booted from `core_app/` (`firebase emulators:start`), auto-loading
`firestore.rules` + `storage.rules` + compiled functions + Auth. UI: **http://localhost:4000**.
Ports: Firestore 8080, Auth 9099, Storage 9199, Functions 5001, UI 4000.

---

## 2. Exact commands + exit codes (in execution order)

| # | Command (cwd) | Result | Exit |
|---|---|---|---|
| 1 | `cd core_app\functions ; npm run build` | tsc clean | **0** |
| 2 | `firebase emulators:start` (from `core_app`) | UI/Firestore/Auth HTTP 200 probed | 0 (bg) |
| 3 | `npm run test:rules` (from `core_app`) | **PASSED: 142 FAILED: 0 TOTAL: 142** | **0** |
| 4 | `npm run test:money-emulator` (from `core_app`) | **PASSED: 29 FAILED: 0 TOTAL: 29** | **0** |
| 5 | `npm run test:gdpr` (from `core_app`) | **PASSED: 30 FAILED: 0** | **0** |
| 6 | `npm run test:migrations` (from `core_app`) | **PASSED: 5 FAILED: 0 TOTAL: 5** | **0** |
| 7 | migrations v001 → v002 → v003 (see §4) | seeded branches / owner / ownerInfo | **0 / 0 / 0** |
| 8 | `node tool/seed_demo_data.js` (from `core_app`) | 7 steps ok (branches, staff, menus, flags) | **0** |
| 9 | `node tool/seed_demo_data.js` with `GCLOUD_PROJECT=demo-empty` | **RED proof:** `settings/ownerInfo missing — run migrations v002 then v003 first (fail-closed)` | **1** |
| 10 | `node test/tool/seed_demo_data_test.js` | **PASSED: 12 FAILED: 0** | **0** |
| 11 | `node tool/verify_demo_flows.js` | **PASSED: 28 FAILED: 0** | **0** |
| 12 | `flutter test` batch 1 — splash, login, app_config ×2, menu_screen, merged_menu_provider | **+27, All tests passed!** | **0** |
| 13 | `flutter test` batch 2 — cart_calculator, variant_aware_cart, cart_screen, checkout_screen | **+14, All tests passed!** | **0** |
| 14 | `flutter test` batch 3 — role_router, admin_gateway, owner_dashboard, admin_menu_manager | **+31, All tests passed!** | **0** |
| 15 | `flutter test` batch 4 — sync_queue ×2, sync_queue_auto_trigger, delete_account_screen, data_export | **+28, All tests passed!** | **0** |

Gate-order note (honest deviation, recorded): the four `npm run test:*` suites use
`firebase emulators:exec`, which boots its OWN emulator suite — it CANNOT share ports
with an already-running `emulators:start` (see Bug #1). Execution order actually used:
boot → discover conflict (exit 1, `Could not start Firestore Emulator, port taken`) →
stop long-lived suite → run all four suites hermetically (each still a full
against-the-emulator proof) → reboot the long-lived suite → migrations/seed/flows
against it. All exit codes above are from those real runs.

---

## 3. Credentials (DEMO ONLY — emulator accounts, no real project)

| Account | Password | role claim | users/{uid}.role | uid |
|---|---|---|---|---|
| `admin@carnama.com` | `AdminPass123` | `owner` | `owner` (tier `enterprise`) | `EKSf0rxsyYJepK2t3z6J18njucBp` |
| `kitchen@carnama.com` | `KitchenPass123` | `kitchen` | `kitchen`, branch `branch_main` | `PUaTjNyIbwItkC1NMhFRP3Yt05YB` |
| `delivery@carnama.com` | `DeliveryPass123` | `delivery` | `delivery`, branch `branch_main` | `Kjx0p9fUtvHZ0GaXgX3TTZHCWoR5` |
| `customer@carnama.com` | `CustomerPass123` | `customer` | `customer` | `meAbysLG3QzNvPSbbI9jzh30tXMX` |

Admin account created by migration v002 (auth user + `role=owner` claim + users doc);
kitchen/delivery/customer by `tool/seed_demo_data.js` (same three-part shape — the
rules' `userRole()` reads the **users-doc** field, firestore.rules:54-59, so the doc is
mandatory, not optional). The GDPR flow check created + erased a throwaway
`e2e_gdpr@carnama.com` (auth user deleted; `deletion_requests` marker retained by design,
rules:353-357 `allow delete: if false`).

---

## 4. Migrations run against the running emulator

Runbook Step 8 equivalent, adapted to file shapes (see Bug #2 — v001/v002 have no
direct-execution guard, so their exported `migrate()` is invoked as modules; v003 owns a
`require.main` guard but was driven identically for symmetry). Env per invocation:
`FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`, `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099`,
`initializeApp({projectId:'resturants-8547d'})` before `require` (money-script convention).

| Migration | Output | Exit |
|---|---|---|
| `v001__seed_branches` | `[v001] Seeded main branch document.` | 0 |
| `v002__seed_admin_user` | `[v002] Created admin user: EKSf0rxsyYJepK2t3z6J18njucBp` + owner claim + users doc | 0 |
| `v003__seed_settings_owner_info` | `[v003] Seeded settings/ownerInfo { ownerEmail: admin@carnama.com }.` | 0 |

Order v001→v002→v003 is mandatory (v003 fails closed without the v002 owner-claim user —
proven independently by `test:migrations` T-4a).

---

## 5. Seeded demo data (Rule 0 — every field from the models)

**Branches (2):** `branch_main` (isDefault + isMainBranch, geo 25.2048/55.2708, radius 5.0)
· `branch_downtown` (25.2102/55.2829, radius 3.5). Shapes = v001 + `isMainBranch`
(the primary read in `merged_menu_provider.dart:46-56`).

**Menus (13 items, 5 categories, both branches)** — every item carries: `name`,
`description`, integer `priceCents`, `category`, `imageUrl: ''` (placeholder/empty —
operator uploads later; domain model maps '' → null, `_mapToDomain`),
`tags[]`, bool `isAvailable`, `quantityRemaining` int|null, `branchId`:

| id | Category | priceCents | isAvailable | quantityRemaining | Modifiers |
|---|---|---|---|---|---|
| `demo_smash_burger` | Burgers | 1099 | true | null | **Size (required single-choice)** |
| `demo_double_smash` | Burgers | 1599 | true | null | — |
| `demo_crispy_chicken_burger` | Burgers | 1249 | true | 12 (limited) | — |
| `demo_mushroom_swiss` | Burgers | 1399 | **false** | null | — |
| `demo_chicken_overload_wrap` | Wraps & Gyros | 1199 | true | null | **Extras (optional multi-select)** |
| `demo_beef_gyro` | Wraps & Gyros | 1299 | true | null | — |
| `demo_falafel_wrap` | Wraps & Gyros | 999 | true | 8 (limited) | — |
| `demo_truffle_fries` | Sides | 749 | true | null | — |
| `demo_loaded_fries` | Sides | 899 | true | **0 (sold out)** | — |
| `demo_mango_lassi` | Drinks | 549 | true | null | — |
| `demo_mint_lemonade` | Drinks | 449 | true | null | — |
| `demo_lava_cake` | Desserts | 899 | true | null | — |
| `demo_baklava` | Desserts | 649 | true | null | — |

**Modifier groups** (`menu_modifier_model.dart:57-82` shape — `{id, name, isRequired,
allowMultiple, options[{id, name, upchargeCents, isDefault}]}`):
- **Size** on `demo_smash_burger` — `isRequired: true`, `allowMultiple: false`;
  Small +0 (**isDefault**) / Large +150.
- **Extras** on `demo_chicken_overload_wrap` — `isRequired: false`, `allowMultiple: true`;
  Extra cheese +100 (**isDefault**) / Garlic sauce +75 / Jalapeños +50.

**Feature flags** — `settings/featureFlags`, all bools (11):
`smartReorder: true, promoCode: true, deliveryEnabled: true, deliveryTracking: true,
loyaltyPoints: true, liveTracking: true, reservations: true, waitlist: true,
referrals: true, tourMode: true, strongAppCheck: false` (App Check STRICT stays off —
relaxed OR mode, firestore.rules:30-35).

**Checkout config the server re-reads** (required for the money path, mirrors
`money_emulator_check.js:96-118`): `settings/taxRates.clients['labs.carnama.halalboys']`
(`{stateRates:{CA:0.0725, DEFAULT:0.08}, currency:'usd'}`) ·
`settings/restaurantConfig` (`{restaurantName:'Halal Boyz', currency:'USD',
ordersAccepting:true, deliveryFeeCents:299}`).

---

## 6. Per-flow verification (halal_boyz flows) — PASS/FAIL with proof

Two proof layers: **(D)** = live data/rules/functions drive via
`tool/verify_demo_flows.js` (28/28, exit 0 — real Auth-emulator logins, real SDK under
the deployed rules, rules-unit-testing contexts with the production App-Check claim
shape, real compiled functions); **(T)** = targeted `flutter test` screen suite
(100 tests, exit 0 across 4 batches). No real device needed (Playbook §9 Phase 0).

| Flow | Verdict | Proof |
|---|---|---|
| splash/config | **PASS** | (D) guest reads `settings/featureFlags` + `branches` publicly; (T) `splash_screen_test`, `app_config_test`, `app_config_flags_test` (27-test batch 1) |
| login — all 3 accounts (+customer) | **PASS** | (D) real Auth-emulator sign-ins; ID tokens carry `role` ∈ {owner, kitchen, delivery, customer}; (T) `login_screen_test` |
| role-gates | **PASS** | (D) kitchen: pending-order read DENIED, confirmed read ALLOW, `confirmed→preparing→ready` {status,updatedAt} ALLOW, totalCents write DENIED, menu write DENIED; delivery: claim unassigned ready order → pickedUp ALLOW, menu write DENIED; customer: foreign cart read DENIED, foreign user read DENIED |
| owner dashboard | **PASS** | (D) owner reads any order/user ALLOW, staff `branchId` assign ALLOW; (T) `owner_dashboard_test` (incl. STATE-1 dispose-safety T-5), `admin_gateway_test`, `role_router_screen_test` |
| menu browse | **PASS** | (D) guest menu read ≥12 items; (T) `menu_screen_test` (categories, search, badge), `merged_menu_provider_test` |
| cart (modifiers exercised) | **PASS** | (D) cart doc written with Size=Large selection (+150) and read back; server re-price of the SAME modifier line accepted (tampered price `failed-precondition`); (T) `cart_calculator_test` + `variant_aware_cart_test` + `cart_screen_test` (upcharge math, variant-exact removal) |
| checkout UI (Stripe boundary = expected stop) | **PASS (expected stop)** | (D) valid modifier line reaches the Stripe seam and fails closed: `Neither apiKey nor config.authenticator provided` — no `STRIPE_SECRET_KEY` in the emulator; order create (pending) under real rules ALLOW; (T) `checkout_screen_test` |
| admin menu manager | **PASS** | (D) owner menu create ALLOW (`demo_flow_special`), owner `featureFlags` write ALLOW (TierFlagManagerScreen path); (T) `admin_menu_manager_test` |
| offline queue + DLQ | **PASS** | (T) `sync_queue_test` (enqueue/replay/DLQ entry + dismissDeadLetter), `sync_queue_retry_test`, `sync_queue_auto_trigger_test` (28-test batch 4). Server-side replay shapes proven by the rules suite (unpaid-pending regressions) |
| GDPR screens | **PASS** | (D) customer `deletion_requests` marker create ALLOW; real `eraseUserData` drive: users doc + carts doc erased, auth user deleted, marker retained (audit proof); (T) `delete_account_screen_test`, `data_export_service_test`; suite: `test:gdpr` 30/30 |

Flow table = **10/10 PASS** (checkout's Stripe stop is the designed fail-closed
boundary, not a failure — Playbook §9 Phase 2 lists live payment as Blaze-gated).

---

## 7. Bugs found (file:line + repro)

1. **`emulators:exec` cannot run beside a live `emulators:start`** —
   `core_app/package.json:8-11` (all four `test:*` scripts hardcode
   `firebase emulators:exec`). **Repro:** boot `firebase emulators:start`, then
   `npm run test:rules` → `Error: Could not start Firestore Emulator, port taken.`
   exit 1 (Firestore 8080 / Hub 4400 / Logging 4500 all collide). **Workaround used:**
   run the suites while the long-lived suite is stopped, then reboot for seeding.
   **Suggested fix (window-owner territory, NOT changed here):** document the serial
   discipline next to the scripts or add an attach-mode variant.
2. **v001/v002 migrations have no `require.main` direct-run guard** —
   `core_app/functions/src/migrations/v001__seed_branches.ts:49` (file ends without a
   guard), `v002__seed_admin_user.ts:61` (same); v003 has one
   (`v003__seed_settings_owner_info.ts:69-78`). **Repro:** `node
   lib/migrations/v002__seed_admin_user.js` (the
   `docs/CLIENT_BACKEND_RUNBOOK.md` Step 8 command shape) loads the module and
   silently exits — no user is created. **Already recorded** as a W3 handoff in
   `archive/FIX_VERIFICATION.md` (BACKEND-2 addendum); re-confirmed live here. Workaround:
   invoke the exported `migrate()` as a module (§4). Not fixed cross-territory.
3. **`tool/seed_menu_data.js` targets LIVE Firestore with a service-account file** —
   `core_app/tool/seed_menu_data.js:4` requires
   `<repo>/resturants-8547d-firebase-adminsdk-fbsvc-*.json` and its output
   says "into live Firestore" (:94). **Repro:** any run with that file present
   writes 6 menu items straight into the real project. **Mitigation this session:**
   not used; superseded by `tool/seed_demo_data.js`, which is emulator-env-only by
   construction and refuses to run without migrations. Deleting/retargeting the old
   script is an owner decision outside this session's lane.
4. **Firebase JS SDK requires an `apiKey` even against the Auth emulator** —
   `getAuth()` throws `auth/invalid-api-key` with only `{projectId}`.
   `tool/verify_demo_flows.js:70-72` documents the placeholder pattern
   (`apiKey:'demo-api-key'` + `connectAuthEmulator`) — no security impact, all
   traffic stays on 127.0.0.1.
5. **Client money-line contract gotcha (documented, not a bug):**
   `functions/src/payment.ts:811-820` — a charge line's `priceCents` must be the
   BASE unit price; selected-option upcharges are re-derived server-side and added
   on top. Sending base+upcharges in `priceCents` fails closed
   (`price does not match the current menu price`). Verified in both directions live.
6. **Known-behavior note for the demo:** `merged_menu_provider.dart:167` filters
   `!isAvailable` items out of the live menu stream — the `isAvailable:false` demo
   item (`demo_mushroom_swiss`) is intentionally invisible in the browse grid (the
   sold-out `quantityRemaining:0` item still shows with its sold-out state). The item
   IS in Firestore and proven by `seed_demo_data_test.js`; recorded so nobody reads
   the missing card as a seed bug.

---

## 8. Explicitly NOT attempted (needs Blaze / Stripe / a real project — Playbook §9 Phase 2)

- **Live Stripe charge / refund / cancel-refund** — needs deployed functions +
  `STRIPE_SECRET_KEY` + webhook signing secret. The logic is emulator-proven
  (`test:money-emulator` 29/29) and the boundary is proven fail-closed (§6).
- **Real FCM push to a device** — needs deployed functions + project messaging.
- **App Check production enforcement** — needs console-registered apps + a live token
  probe BEFORE `strongAppCheck=true` (kept `false` here; runbook §12.1).
- **`firebase deploy` of anything** — requires a live project (runbook Steps 1-11);
  the demo ran rules/functions/indexes purely in the emulator.
- **Pub/Sub alert sink, Remote Config, store presence** — console-side runbook items.

---

## 9. How to re-run the demo from scratch

```powershell
cd <repo>\core_app\functions ; npm run build        # exit 0
cd .. ; firebase emulators:start                          # keep running; UI http://localhost:4000
# in a second shell (or stop/start for the four hermetic suites):
npm run test:rules ; npm run test:money-emulator ; npm run test:gdpr ; npm run test:migrations
node tool/seed_demo_data.js                               # seeds branches/staff/menus/flags (idempotent)
node test/tool/seed_demo_data_test.js                     # 12/12
node tool/verify_demo_flows.js                            # 28/28
flutter test test/features/splash/splash_screen_test.dart test/features/auth/presentation/login_screen_test.dart test/app/config/app_config_flags_test.dart test/core/config/app_config_test.dart test/features/menu/presentation/menu_screen_test.dart test/features/menu/presentation/merged_menu_provider_test.dart
```

Migrations (once per fresh emulator): v001 → v002 → v003 via module-invoked
`migrate()` (§4; seed fails closed without them). Emulator data persists until the
suite is stopped; `seed_demo_data.js` can be re-run safely.

**Commit scope (step 11):** `core_app/tool/seed_demo_data.js`,
`core_app/test/tool/seed_demo_data_test.js` (Rule 9),
`core_app/tool/verify_demo_flows.js` (reusable flow prover), this log. No config fix
was needed — `core_app/firebase.json` already boots rules+storage+functions+auth+UI.
Nothing pushed; `archive/FIX_VERIFICATION.md` untouched.



