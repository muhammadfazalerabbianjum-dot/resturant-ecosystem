# CLIENT ACQUISITION PLAYBOOK - Carnama Labs (ONE document to know everything)

**Read this first. It points to the three artifacts that hold the detail. You are never lost if you start here.**

- Detail #1 - `docs/CLIENT_BACKEND_RUNBOOK.md` - the exact per-client Firebase console click-through (created by BACKEND-1).
- Detail #2 - `archive/PRODUCTION_READINESS_AUDIT_MASTER.md` - the 9-domain verdicts (all rows PASS; Sec-12 console checklist is the one open gate).
- Detail #3 - `archive/FIX_VERIFICATION.md` - the append-only ledger: all 32 batches (B0, CI-1, 28 window batches, RELEASE-1, RELEASE-2) + 1 micro-fix, each with proof gates + residuals.

---

## 1. WHERE YOU ARE (verified 2026-09)

| Question | Answer |
|---|---|
| Is the code done? | **YES.** All 32 batches merged into `main`, gates green at merge point, 0 per-branch ledgers left, all 5 worktrees merged back. |
| Are critical flows covered? | **YES (logic).** Money (charge, verify, refund, cancel), routing, offline queue + DLQ, Firestore rules + App Check, GDPR erasure/export/consent, admin surfaces, a11y/l10n/theme - each re-proven by red-green tests + emulator suites. |
| Bugs found & fixed? | Real ones: webhook `serverTimestamp`-in-array (MONEY-3 gate), 2 security holes in rules (RULES-1), fallback-auth masking goldens (ROUTER-2), 3-way identity drift (WL-2), crash-prone lock screen (STATE-3). The gates worked. |
| Coverage? | **53.11%** (was 46.77% at CI-1). The 80% CI floor stays RED by design until the debt is paid. |
| Conflicts / data loss? | **None.** One real content conflict (UX-2 x STATE-2) resolved by hand + proven by full suite; all others benign ledger-file resurrections. No source lost. |
| Is it "production"? | **Code: yes. Deployed: no.** RELEASE-2 honestly says FAIL until the Sec-12 console checklist is executed or owner-scheduled. |

---

## 2. THE HONEST ANSWER TO "CAN I FIND A CLIENT WITHOUT THE CHECKLIST?"

**YES - and it is the right order.** The checklist literally requires a client's Firebase project + billing, so it belongs AFTER a client signs, not before. What you can honestly pitch today:

> "The app is fully built and proof-tested (emulator-proven money, security rules, GDPR, offline queue). Going live needs your Firebase project + billing (Blaze) + Stripe keys - a 2-3 day ops task, which we run the moment we have them."

What you must NOT promise:
- "Ready today" - the Sec-12 deploy is still open.
- "Zero bugs" - ~47% of lines are still uncovered by tests; real-device behavior is unverified.
- "Any customization" - an off-generator standard brand only.

---

## 3. THE 6-WEEK CLIENT DEADLINE - FEASIBILITY

**Feasible and honestly generous** for a standard single-brand app:

| Week | Work | Est. |
|---|---|---|
| 1 | Client signs, Firebase project created, Blaze on, Stripe account + keys | 1-3 days (mostly waiting on client) |
| 1-2 | Run `docs/CLIENT_BACKEND_RUNBOOK.md` end-to-end: Auth, App Check, functions deploy, rules+indexes, seed v002/v003, Stripe webhook, Remote Config, alert sink | 2-3 days |
| 2 | Generate the shell via `core_app/tool/whitelabel.dart` (or reuse halal_boyz), fill config, real API keys | 1-2 days |
| 3 | Real-device smoke: order, payment, push, GPS, cancel, GDPR on 1 Android + 1 iOS; fix whatever surfaces | 2-3 days |
| 3-6 | **Buffer + coverage hardening** (see Sec 5) + minor client polish | slack |

Two hard risk factors: (a) the Sec-12 checklist MUST actually get done (by you or the client's admin), (b) no major re-scope. If both hold, 6 weeks is comfortable.

---

## 4. PLAIN-ENGLISH GLOSSARY (so you're never lost)

- **Blaze (Firebase plan):** the paid tier where Cloud Functions/Storage actually run beyond the free quota. Required for anything real. It's the client's cost, pay-as-you-go, pennies at low volume.
- **Webhook:** Stripe calls a special URL on your server (`stripeWebhook` function) whenever a card is charged/refunded/fails, so the server records it. Setup = 1 config entry in Stripe's dashboard + a secret, done AFTER deploy. It is the LAST thing configured - automated refund-record keeping is what depends on it.
- **App Check:** Firebase's "prove this is really our app, not a script" token. Enforced on callables already; console must register the Android/iOS apps and toggle enforcement.
- **Backend bundle:** the `firestore.rules` + indexes + `.firebaserc` + deploy script the generator now writes into every app folder (BACKEND-1). `deploy_backend.dart` runs it; preflight checks each PASS/FAIL.
- **Seed migrations v002/v003:** small scripts that provision the first branches + the owner email so owner-gated features aren't dead on a fresh backend.
- **Sec-12 VERIFY-IN-CONSOLE:** the 12-item checklist inside `archive/PRODUCTION_READINESS_AUDIT_MASTER.md` - the only thing between RELEASE-2 FAIL and PASS.

---

## 5. THE COVERAGE PLAN (your "find the bugs" idea - do this WHILE pitching)

Honest framing: **pursue critical-path coverage, not the raw 80% number.**

| Tier | What | Why |
|---|---|---|
| 1 (do first) | Emulator-integration on money/orders/auth/queue/rules/GDPR | Highest-risk, already dense, highest bug-yield per hour |
| 2 (do second) | Widget tests on main user journeys (home, menu, cart, checkout, tracker; admin dashboards) | Where users actually click; ROUTER-2's fallback-auth bug would never have been caught by pure unit tests |
| 3 (optional) | Long-tail screens | Diminishing returns; the 80% CI floor is a symptom gate, not a ship-gate |

**Rule 9 already makes every future batch add real tests in its territory** - so any client-fix work automatically raises coverage. The 80% floor flipping green is a milestone, not the definition of done.

---

## 6. YOUR EXACT NEXT MOVES (numbered, in order)

1. **Start pitching.** You are safe to. Use the Sec-2 pitch.
2. While pitching, run the **Tier-1 + Tier-2 coverage hardening** above (one batch a day, Rule 9, ledger appended - you already know the drill, or hand it to a Cline session with this doc).
3. **Before ANY push to GitHub:** purge the `.env` values from git history (`git filter-repo`/`filter-branch`) - they exist in old commits and your `origin` is a stale pre-fleet orphan 772 files behind. Then push + enable Actions. This is the one irreversible mistake left.
4. When a client signs: execute `docs/CLIENT_BACKEND_RUNBOOK.md` (2-3 days), provision Stripe, deploy bundle, seed, webhook, one real $1 test charge, one device smoke.
5. When the Sec-12 checklist is done or owner-scheduled, RELEASE-2 flips to **PASS**, and the app is formally production.

---

## 7. WHAT I'M DELIBERATELY NOT PROMISING YOU

- 100% bug-freedom (the 47% uncovered surface is real; the gates find bugs when run - real users find the rest).
- iOS build verification (no macOS runner - a RELEASE-2 item needing a Mac).
- That a client with a wildly non-standard config won't need generator work (off-template = new work).
- That REGENERATING a client shell won't surface a brand-new edge (start each client with a dry-run in a scratch dir - BACKEND-1 proved the generator can regress).

**END - when confused, come back here. This file is the map.**

---

## 8. FEATURE & PER-CLIENT UI MODEL (the architecture that makes "one codebase, many brands" work)

**Ground rule (non-negotiable):** code lives in the SHARED layers (`packages/core`, `packages/core_ui`, the `core_app` template). The ONLY things that vary per client are: (1) the client's `client_config.json`, (2) the generated thin shell, (3) flag values. Never hand-edit a generated shell's structure - regeneration wipes it (WL-1's validator warns about hand-edited platform files for the same reason).

### 8A. Per-client UI = config + shared VARIANTS (supported today)
- Palette / typography / currency / navigation / screen whitelist / bool flags -> `client_config.json` (schema-validated since WL-2; `BrandColors` theme chain since COLOR-1).
- A client's "look" = a config swap, NOT code.
- **Circle vs pill vs square shapes, animation styles, a screen that "doesn't click"** -> add a config key (`theme.shape`, `features.flags.<layoutVariant>`, etc.), make the SHARED widget render the variant from that key, regenerate that shell. A few variants in shared code = every client picks one from config. This is the ONLY way your time scales.
- Honest limit: a wholly novel screen layout no config can express = a new SHARED variant (a feature) or a conscious fork (8D). Not a silent shell edit.

### 8B. Global feature (ALL clients) - checklist
1. Implement in shared layers (`packages/*` logic, `core_ui` components, `core_app` template).
2. Add real tests (Rule 9) + ledger entry.
3. Regenerate every existing shell (`core_app/tool/whitelabel.dart`); new clients get it from the template.
4. Pure `packages/*` changes auto-inherit via path deps (no regen needed for those).

### 8C. Client-specific feature (ONE client) - checklist
1. Implement in the SAME shared code, gated behind `features.flags.<name>: true` in ONLY that client's `client_config.json`.
2. Everyone else: `unknownFlagDefault: false` -> off.
3. Built-in runtime toggling: `FeatureFlagsService.isEnabled` reads Firestore `settings/featureFlags` overrides; admin `TierFlagManagerScreen` flips flags live, no redeploy.
4. Regen that client's shell to propagate the wiring.

### 8D. The fork decision (LAST resort - explicit owner approval + ledger entry required)
Choose only when a feature is so structural it cannot be a clean flag:
- **(a) Generalize into a shared variant** (recommended): every client can later adopt it; regen stays safe.
- **(b) Fork the generated app**: that app stops being regenerable; EVERY future shared change needs manual merge-forward; maintenance tax forever. Record the decision + price it into the deal.

### 8E. Rules that keep you alive
1. Don't hand-edit generated shell structure. Ever.
2. No orphan flags - a flag must have a consumer + a test (validator enforces parse; you enforce consumption).
3. A new config key must be added to parser + schema + `validate()` together (WL-2 pattern) so a typo fails fast, never silently degrades.
4. Every feature = shared code + flag + test + ledger entry, both kinds.
5. Experiment with "how good can the UI go" on the TEMPLATE or as shared variants - when you're happy, one regeneration propagates it to every client.

---

## 9. HALAL_BOYZ TO THE FULLEST (test + make it beautiful) — GAME PLAN

**Goal:** wring every flow out of the demo brand and turn it into a gorgeous showcase — without breaking the "one codebase" model or spending a client's Blaze money early.

**Phase 0 — EMULATOR (free, no Blaze, ~1 hour, today):** `firebase emulators:start`; seed throwaway data (branches, menus, owner/admin accounts — the v002/v003 seeds or manual). Proven here: home → menu → cart → checkout UI → admin login → role-gates → dashboards → offline queue (QUEUE-1) → DLQ → rules (142/142) → GDPR erasure UI. Real device not needed.

**Phase 1 — MAKE IT BEAUTIFUL — ON THE TEMPLATE, NEVER THE SHELL (the whole game):**
- Edit `core_app/lib/features/...` (screens) + `packages/core_ui` (shared components/theme) to your dream design. Colors/fonts/layout live behind config keys + `BrandColors` (COLOR-1).
- Then ONE `core_app/tool/whitelabel.dart` regeneration ports the design into halal_boyz.
- Never hand-edit `apps/halal_boyz/lib` structure — regen wipes it (ground rule 8).
- Experiment with animations/layout variants as SHARED config-keyed variants (8A) so they become reusable per-client ingredients.

**Phase 2 — THE HONEST LIMIT (needs a real Firebase project + Blaze)** — cannot be validated free:
- Live payment (Stripe charge) — MONEY-1/2 logic is emulator-proven; the live charge needs deployed functions + a real key.
- Real push on a device — PUSH-2 logic proven; live FCM needs deployed functions.
- Real device GPS/GDPR — same.
- Run `docs/CLIENT_BACKEND_RUNBOOK.md` here (2-3 days) when a client funds it.

**Phase 3 — THE SHOWCASE PITCH:** regenerate a fresh shell with a client-like config (animated vs minimal) to demo "same codebase, totally different brand" — the whole value prop in one screen.

**TL;DR:** emulator today, beautiful-template tomorrow, regen to port, and the real-device money/push/GDPR pass is a funded-client task — never promise it free.