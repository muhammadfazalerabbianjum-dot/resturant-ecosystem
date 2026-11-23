# WHITE_LABEL_p06_perf6.md — PERF-6 wave (5 parallel worktree batches)

Status: EXECUTING 2026-09-15 · Base: `15caf2c` · Worktrees: cline-1..5 (all synced, format-clean)

## Sub-batch → worktree → territory (B-2 verified disjoint)
| Window | Batch | Territory |
|---|---|---|
| cline-1 | **PERF-6b tax-rates admin surface** | `lib/app/config/tax_rates_repository.dart` (new), `restaurant_setup_screen.dart` (7th tab), l10n arb en/ar + regen, `firestore.rules` ONLY if owner write missing, tests under `test/app/config/` + `test/features/admin/presentation/setup/` |
| cline-2 | **PERF-6c cleanup** | DELETE `apps/halal_boyz/lib/app/client_config.dart` (0 precise imports, verified), `tool/seed_test_accounts.js:11` (hardcoded SA path → env/applicationDefault fail-closed), ledger addendum incl. goldens-count correction (27 on-disk baselines is the real number; ledger "68" was wrong) |
| cline-3 | **PERF-6d secrets hardening** | `functions/src/index.ts` (declare `defineSecret('STRIPE_SECRET_KEY')` + `('STRIPE_WEBHOOK_SECRET')` — runtime `process.env` reads unchanged, v2 injects declared secrets as env), `RUNBOOK_DEPLOY.md` §(c) note |
| cline-4 | **PERF-6a-1 menu coverage** | `test/features/menu/**` only (dish_detail 49%, repository catch/TTL/cap branches; extend existing suites) |
| cline-5 | **PERF-6a-2 router+driver coverage** | `test/app/**`, `test/features/driver/**` only (app_router 58%, proof_of_delivery 55%) |

## Key verified facts the builders rely on
- `clientId` = bundle id via `CoreConfigHolder.instance.clientId` (checkout forwards it at `checkout_service.dart:188`); tax doc shape `settings/taxRates.clients[id] = {stateRates{...}, defaultRate, currency?}`.
- `calculateTax` fallback = CA .0725 / NY .08 / TX .0625 / FL .06 / 5% default; unknown state throws (fail-closed). The comment claiming RestaurantSetupScreen writes this table was FALSIFIED (zero taxRates code in admin lib, zero tests) — this wave builds the real surface.
- Editor pattern = mirror `RestaurantConfigRepository` (injected firestore, provider, fake_cloud_firestore tests; `_formPopulated` guard on the screen).
- Functions tests run compiled pure modules (`lib/payment.js`) — no env mocking; `deploy_guard.test.js` rejects secret values in source.
- PERF-6e (mutation testing) and 6f (NFC/fleet/tour) are NOT in this wave: 6e's per-mutant suite runs are hours-long; 6f awaits operator product decisions + external credentials.

## Acceptance per sub-batch
Standard Gate Set U per worktree + merge cadence into main (sequential, post-merge gates each) + addendum to FIX_VERIFICATION.md in each batch's commit. 6b adds: fail-closed validation (rate ∈ [0,1], default ∈ [0,1]), merge-true write preserving other clients' rows, owner-only UI (RoleGate owner), en+ar l10n keys.
