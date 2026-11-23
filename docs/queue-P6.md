# QUEUE — P6 (candidate pulled forward by the owner, 2026-11-13)

Item #2 of the P6 register (`ROADMAP.md`, `docs/BACKLOG-P5.md` §P6): the
halal/dietary trust layer. Promoted to a card by the owner; it is menu metadata
and touches no money path, which is why it can run ahead of the shell work.

Card discipline is unchanged from P0/P1/P2: `DONE WHEN` below must be true **and**
the evidence must be in a checkpoint from the same session.

**Progress 2026-11-14 — CARD CODE-COMPLETE.** All acceptance items are green:

| Item | State | Evidence |
|---|---|---|
| 1 model fields (both projections) | **DONE** | `dietary_codes.dart` + `CertExpiryConverter`; codegen WITH `--build-filter` (D-055), 25.9 s, only 4 files touched |
| 2 vocabulary + validation | **DONE** | 13/6 codes pinned; `DietaryCodeException`; boundary validation in `saveMenuItem`; 19/19 tests |
| 3 rules (owner-only claim) | **DONE** (2026-11-13) | `checkpoints/P6-01-RULES.md`, RED→GREEN, 170/56 harness |
| 4 badges + expired claim | **DONE** | `DietaryBadges`; expired ⇒ no badge (`+19` tests, incl. Arabic) |
| 5 allergen filter | **DONE** | 3 dietary chips + 13-code sheet, applies live; menu tests 9–10 |
| 6 l10n en/ar | **DONE** | 29 keys per locale, `gen-l10n` clean, parity suite green |
| 7 no money/order path change | **DONE** | only menu metadata + presentation; `+488` tests across menu/l10n/admin |
| 8 tenancy unchanged | **DONE** | gates (i)/(j) from the battery cited in `ledger.md` |

Full record: `checkpoints/P6-01-MODEL-UI.md`. Codegen blocker resolved: the
generator was never broken, only misused (D-055). Two real defects were found and
fixed on the way — a Timestamp/UTC drift and a 348 px editor overflow.

**Registered follow-up (not part of this card):** items carrying only the legacy
`tags: ['vegan']` string are no longer reachable through the chip (D-054). The
tags→codes backfill is listed in `docs/BACKLOG-P5.md` §P6 and needs owner
consent, because it rewrites stored menu documents.

---

## P6-1 — Halal/dietary trust layer

**Deliverable.** Menu items carry machine-readable dietary facts and an
owner-only halal certification claim; the customer menu shows badges and filters
by allergen; the admin item editor sets them.

### Measured starting state (2026-11-13, before the card)

- **No such field exists.** `grep -rniE "allergen|halal|dietary|vegetarian|vegan|gluten"`
  over `core_app/lib` and `packages/core/lib` returns only `tenantId` examples
  (`halal_boyz`), a `Vegan` category chip and one l10n key. There is nothing to
  migrate.
- **Two menu projections, both needing the fields:**
  `core_app/lib/features/menu/domain/menu_item_model.dart` (customer:
  `id, name, description, priceCents, imageUrl, category, tags[], isAvailable,
  quantityRemaining, modifiers`) and
  `core_app/lib/features/admin/domain/menu_item_model.dart` (admin: adds
  `branchId`, modifiers as maps, `mergeWith` for branch overrides).
  *Their duplication is real and out of scope here; it is a C-8 audit finding.*
- **`tags` is free text and must NOT become the badge store.** The admin editor
  takes a comma-separated string (`menu_item_editor.dart:25`,
  `loc.tagsCommaSeparated`), splits it into a list, and matching is
  case-sensitive on the raw value (`menu_screen.dart:165`,
  `home_service.dart:43`). Anyone who can edit an item can type `halal` into a
  field nothing validates. A trust claim cannot live there.
- **Rules today** (`firestore.rules:276-307`): `menus` reads are `tenantOk()`;
  writes are `isAppVerified() && isAuthenticated() && !isAnonymous() &&
  tenantOkCreate()/tenantOk()` and either `isOwner()` or a `manager` scoped to
  their own branch, with `name`/`priceCents` shape checks and `branchId`
  immutable. **No `keys().hasOnly`**, so new optional fields need no rules change
  to be *written* — which is precisely why a claim field needs one to be
  *restricted*.
- **l10n gate:** `core_app/test/l10n/app_localizations_parity_test.dart` requires
  every `app_en.arb` key in `app_ar.arb` **and** flags keys with zero consumers.

### Design (D-051)

- **Codes, never copy — on TWO axes.** `allergens: string[]` (13 codes — 12
  allergen groups plus `gluten` — what the item declares) and `dietary: string[]`
  (6 codes, who it suits) are separate
  lists: an item can be vegan and contain sesame, or gluten-free and not
  vegetarian, and "hide what contains milk" is not the same operation as "show
  only vegan". The exact codes, wording and filter exposure are fixed in
  `docs/DIETARY-VOCABULARY.md` and recorded as D-052.
  `allergenNotes: string` carries cross-contamination prose (owner's own words,
  rendered as written — it is a note, not a claim to translate).
- **The certification claim is flat and owner-only:**
  `halalCertified: bool`, `halalCertBody: string`, `halalCertExpiresAt: timestamp`.
  Flat because rules can name flat keys; nested maps make the write-restriction
  harder to read for no gain.
- **Authority split:** `dietary` and `allergenNotes` follow today's menus lane
  (owner, or manager on their own branch). The three `halal*` keys are
  **owner-only** in the rules — a manager may run a branch, but a certification
  claim is the business's word, not a shift decision.
- **An expired claim renders no badge.** `halalCertified == true` with
  `halalCertExpiresAt` in the past shows nothing to customers and a warning in
  the editor. Trust fails closed, matching the money renderer's T-5 posture.
- **Scope of the claim in v1 is the ITEM, not the branch.** Per-kitchen
  certification is real in the world, but it adds a schema and a rules surface
  before any client has asked for it; the item-level claim covers the menu as
  the customer sees it. Recorded as a deliberate v1 limit, not an oversight.

### Acceptance (DONE WHEN)

1. **Round-trip + backward compatibility.** Both projections parse and serialize
   every new field; a legacy document with none of them parses with defaults.
   Pinned by a test built from the pre-card document shape.
2. **One vocabulary, pinned and append-only.** The 13 declaration + 6 dietary codes
   live in a single Dart const list; a test asserts the exact code set, that the
   editor controls, the filter sheet and the model validation all read that one
   list, and that an unknown code is rejected at the repository boundary with a
   **named** error — never silently dropped, never coerced to a default. A rename
   or removal of a stored code fails the pin.
3. **Rules, both directions.** Gate (k) gains ALLOW+DENY pairs: manager sets
   `dietary`/`allergenNotes` on an own-branch item → ALLOW; manager sets
   `halalCertified` → DENY; owner sets it → ALLOW; a customer write → DENY. The
   DENY must be **shown failing before the rule lands** (planted assertion), then
   the gate green — a lockdown-only rule would fail the ALLOW half.
4. **Customer surface.** Badges render from data on the menu card and dish
   detail; an item certified but expired renders **no** badge, and a test pins
   that exact case.
5. **Filter exposure matches the vocabulary doc.** Three inline dietary chips
   (`vegan`, `vegetarian`, `gluten_free`) plus one "Allergens" control that opens
   a multi-select sheet offering **all 13** codes; selecting one hides items that
   declare it. A filter that offers only the common allergens fails the person
   with the uncommon one. When everything is filtered out the existing localised
   empty state shows. Widget test at 390 px and 1024 px with overflow captured as
   an error (the P1-07 harness, not a printed warning).
6. **l10n.** Every new string exists in `app_en.arb` and `app_ar.arb`;
   `app_localizations_parity_test` is green; no new key has zero consumers.
7. **No money movement.** `git diff` touches no payment, ledger, tax or
   `functions/src` file. The money parity matrix is therefore not re-run, and the
   checkpoint says so explicitly rather than implying coverage.
8. **Tenancy unchanged.** No new collection: gate (i) row count is unchanged and
   `menus` stays ACTIVE in gate (j). Both receipts cited from the same session.

### Out of scope (stated so it cannot creep in)

Certificate upload, expiry reminders, supplier/ingredient provenance,
per-branch certification, and any change to how `tags` behaves. Badge artwork
beyond an icon + localised label. Nothing here changes price, availability or
the order path.

**Also out of scope, and stated loudly:** compliance claims. The list itself is now
verified against CFIA and Health Canada (`docs/RESEARCH-DRAFT-dietary-regulatory.md`),
but the federal declaration duty applies to **prepackaged** food, not to food
served in a restaurant — so this feature is **voluntary trust, not compliance**,
and every badge is a declaration by the restaurant, never a safety guarantee.
Whether any province requires a printed menu statement is unverified (sampled,
not surveyed) and does not gate the card.

### Named risk

`dietary` is written by managers, so an allergen tag can be wrong. The card
mitigates what it can — one vocabulary, a visible editor, no silent default — but
it cannot verify a kitchen. The badge copy for allergens must therefore read as
"contains X" (a declaration by the restaurant), never as a safety guarantee,
and the checkpoint must state that limit.
