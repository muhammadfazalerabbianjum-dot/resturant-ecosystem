# QUESTIONS — owner input required

Only questions that cannot be answered from the repository belong here. A
question whose answer is discoverable in the code is a failure of research, not
a question — find it instead.

**Entry format**

```
## Q-00N — <short title>
- **Raised:** YYYY-MM-DD · **Card:** P0-x · **Severity:** blocks-P1 | blocks-phase-2 | advisory
- **Question:** the decision only the owner can make.
- **Why the repo cannot answer it:** what was checked and what it showed.
- **Provisional answer being built against:** what P0/P1 assumes meanwhile, so
  work does not stall. Changing it later costs what this field says.
```

---

## Q-001 — Where is the thermal printing implementation?
- **Raised:** 2026-11-07 · **Card:** P0-3 · **Severity:** blocks-phase-2
- **Question:** the owner states thermal printing is done. Which repository,
  branch, path or vendor integration contains it?
- **Why the repo cannot answer it:** searched every branch (~28 refs) and all 11
  worktrees for `thermal`, `escpos`, `esc/pos`, `printer`, `printing`, `esc_pos`
  — zero implementation hits, zero uncommitted matches in any worktree, no
  printing package in any `pubspec.yaml`, and `core_app/DEFERRED.md` H2 still
  records the feature as unstarted. Handoff §7.3 records this as a contradiction
  rather than a correction.
- **Provisional answer being built against:** receipts are treated as **unbuilt**
  (on-screen summary + system print dialog + Stripe email receipt) until the
  implementation is identified. If printing already exists outside this repo,
  Phase 2 loses roughly one card of work; if it does not exist, the plan is
  already correct.
- **RULED 2026-11-09 (D-024):** the owner has **not** produced a path; thermal
  stays a blocked claim, Phase 2 receipts are on-screen + system print + Stripe
  email, and nothing may claim thermal printing until a path is handed over.

## Q-002 — Which Stripe reader, in which market?
- **Raised:** 2026-11-07 · **Card:** P0-10 · **Severity:** blocks-phase-2
- **Question:** which Terminal reader model is being bought, and is card-present
  Terminal supported in the operating country?
- **Why the repo cannot answer it:** this is account and geography data. The code
  contains only `packages/core/lib/src/payment/nfc_terminal_service.dart`, a
  placeholder with a `TODO_DEPLOY` marker, and no reader or location ids.
- **Provisional answer being built against:** server-driven Terminal with the
  WisePOS E / S700 family, one Stripe Location per branch. The integration shape
  is identical for every smart reader, so this choice does not block schema work;
  it blocks only the first live demo.

## Q-003 — Where is `docs/EXPANSION_BLUEPRINT.md`?
- **Raised:** 2026-11-09 · **Card:** P1 rulings · **Severity:** advisory
- **Question:** the owner's ruling cites `docs/EXPANSION_BLUEPRINT.md` §3.1 as the
  frozen authority for A1/A2/A8/Q-001. That file is not in this tree. Which path
  holds it — another repo, a worktree, or was it never written?
- **Why the repo cannot answer it:** `find . -iname "*blueprint*"` (excluding
  `.git` and `node_modules`) returns nothing; `docs/` contains
  `ORCHESTRATOR_BRIEF.md`, `ORCHESTRATOR_HANDOFF.md`, `PLATFORM_EXPANSION_PLAN.md`
  and `PLATFORM_EXPANSION_EVIDENCE.md`, none of which carry that name or a §3.1
  with these rulings.
- **RESOLVED 2026-11-12 (owner directive):** the file was authored outside
  the repository and never copied in. `docs/DECISIONS.md` is now the in-repo
  citation authority (D-038's citation note, plus the backfilled programme
  ADR section). No substitute file is created and no `§3.1` is claimed.
- **Provisional answer being built against:** the rulings are logged as OPTIMAL in
  D-021…D-029 citing the handoff sections that carry the same content, **not** the
  absent file. No work is blocked: the rulings themselves are unambiguous. If the
  blueprint exists elsewhere, the citations in those entries should be repointed
  once it is added here.
- **RULED 2026-11-09 (D-025):** Canada first; WisePOS E primary, WisePad 3
  fallback; Tap-to-Pay is demo-grade only; all development runs on Stripe's
  simulated reader in test mode — no real Stripe calls, no hardware ordering.

## Q-004 — How does an UNAUTHENTICATED menu/branch read get a tenant?  — ANSWERED
- **Answer (2026-11-11, D-035): design 1.** Guest clients carry a tenant claim
  minted server-side from the app's attested `app_id`; no collection is exempt
  from `tenantOk()`. See `docs/DECISIONS.md` D-035 for the binding, the guest
  claim shape and the deploy order.
- **Raised:** 2026-11-10 · **Card:** P1-4 · **Severity:** blocks-P1-4 (not the run)
- **Question:** with one shared Firebase project and `tenantId` on every document,
  what must `tenantOk()` require for the collections that are public today —
  `menus`, `branches`, `promotions`, `locations`, `branches/*/config`,
  `branches/*/menu_overrides`, `settings/restaurantConfig`? Two coherent designs:
  1. **Every client carries a tenant claim, including guests.** Each tenant's app
     signs in anonymously at boot and the server mints a `tenantId` claim (P1-5's
     `buildUserClaims` would need an anonymous branch, since guests have no
     `users/{uid}` document). Public reads become
     `resource.data.tenantId == request.auth.token.tenantId`. Strict: no leak is
     possible, but a rules deploy before the client change makes the app unable
     to load its own menu.
  2. **Public collections stay `allow read: if true`** and are excluded from the
     cross-tenant denial suite. Simple, ships now, but two tenants' menus are
     readable by anyone — acceptable for public marketing data, NOT acceptable if
     a menu carries prices/availability that differ per client and matter.
- **Why the repo cannot answer it:** it is a product/security decision, not code.
  The handoff (§7.1) says "every rule path must check it" but does not say what an
  unauthenticated client presents. Today's app signs in anonymously
  (`isAnonymous()` exists in the rules) and sets no tenant claim anywhere.
- **Provisional answer being built against:** **design 1** — guest clients carry a
  tenant claim, so no collection is exempt. Consequence recorded as deploy
  ordering: `migrate_v004_tenancy` (P1-6) + the client's tenant-claim sign-in must
  ship BEFORE the P1-4 rules, exactly like D-032's trigger ordering.
- **Also blocked by this card's harness:** the generated suite
  (`test/security/tenant_isolation_support.dart`) has no bootstrap — it never
  connects to the emulator, never signs in as tenant A, and never seeds a tenant-B
  document, because all 28 rows are PENDING today. Flipping rows to ACTIVE without
  that bootstrap would produce 56 red tests, not proofs. The bootstrap needs an
  auth-emulator sign-in carrying custom claims (create user + custom attributes →
  `signInWithPassword` → ID token), which is new machinery in this repo.
