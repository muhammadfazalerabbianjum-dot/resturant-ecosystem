# DIETARY VOCABULARY — the fixed code list for P6-1

Status: **verified against Canadian federal sources on 2026-11-13** (D-052).
Full citations: `docs/RESEARCH-DRAFT-dietary-regulatory.md` §1.

**What "verified" covers:** the allergen and gluten-source list matches CFIA and
Health Canada. **What it does not cover:** that a restaurant menu must carry these
declarations — it need not; the federal duty applies to prepackaged labels. This
feature is voluntary trust, and every badge is a *declaration by the restaurant*,
never a safety guarantee or a legal claim.

Two axes, because the filter has two different meanings:

- **`allergens: string[]`** — what the item **declares the presence of**.
- **`dietary: string[]`** — who the item **suits**. A positive claim.

One combined list would make "hide what contains milk" and "show only vegan" the
same operation, and an item can be vegan *and* contain sesame, or gluten-free
*and* not vegetarian.

---

## 1. Declarations (`allergens`) — 13 codes

Twelve allergen groups (Canada's 11, with crustaceans and molluscs split for
filter value) plus gluten, which Canada requires declared alongside them without
being an allergen.

| Code | Renders as | Source obligation |
| --- | --- | --- |
| `eggs` | Contains egg | priority allergen |
| `milk` | Contains milk | priority allergen |
| `mustard` | Contains mustard | priority allergen |
| `peanuts` | Contains peanuts | priority allergen |
| `crustaceans` | Contains crustaceans | "crustaceans and molluscs" is ONE Canadian group; split here so a shellfish filter is usable |
| `molluscs` | Contains molluscs | same group, split for the filter |
| `fish` | Contains fish | priority allergen |
| `sesame` | Contains sesame | priority allergen |
| `soybeans` | Contains soy | priority allergen |
| `sulphites` | Contains sulphites | grouped with priority allergens; sulphite sensitivity, not a true allergy |
| `tree_nuts` | Contains tree nuts | priority allergen; the nine species go in `allergenNotes` |
| `wheat_triticale` | Contains wheat/triticale | priority allergen — **this is the allergen, not gluten** |
| `gluten` | Contains gluten | gluten-source declaration: barley, oats, rye, triticale, wheat |

**Two modelling points that the research corrected:**

1. `wheat_triticale` and `gluten` are **different codes with different source
   lists**. Wheat is a priority allergen; gluten is a declaration covering five
   grains, of which only wheat/triticale are also allergens. Collapsing them into
   one "cereals" code would tell a coeliac nothing useful about barley.
2. `celery` and `lupin` were in the earlier proposal and are **removed** — they
   are EU obligations, not Canadian ones. Nothing is stored yet, so this is a
   correction, not a migration. The append-only rule below starts at the first
   stored code.

## 2. Dietary suitability (`dietary`) — 6 codes

| Code | Renders as | Filter? |
| --- | --- | --- |
| `vegan` | Vegan | chip |
| `vegetarian` | Vegetarian | chip |
| `pescatarian` | Pescatarian | badge only |
| `gluten_free` | Gluten-free | chip |
| `dairy_free` | Dairy-free | badge only |
| `nut_free` | Nut-free | badge only |

`gluten_free`, `dairy_free` and `nut_free` are **declarations**, not
certifications: the wording never says "safe for", and `allergenNotes` is where
cross-contamination is stated. The halal claim is not in this list — it is the
separate owner-only triple (`halalCertified`, `halalCertBody`,
`halalCertExpiresAt`, D-051).

## 3. What the customer menu filter exposes

A 390 px chip row cannot hold 19 codes, so the two axes get different affordances:

- **Dietary chips (3, inline):** `vegan`, `vegetarian`, `gluten_free`.
- **Allergen exclusion (1 button → sheet, all 13):** multi-select; selecting a
  code **hides** items declaring it. Every code must be reachable — a filter that
  offers only the common ones fails the person with the uncommon one.
- **Badges only:** `pescatarian`, `dairy_free`, `nut_free`, plus all 13
  declarations on the card and dish detail.

## 4. Stability contract

1. **Append-only from the first stored code.** Never renamed, never removed; a bad
   code is superseded by a new one plus a migration.
2. **One definition.** A single Dart `const`; editor, filter sheet, validation and
   l10n keys all read it. A second copy is a defect.
3. **Pinned by a test** asserting the exact 13 + 6 codes, so adding one is a
   deliberate two-place diff.
4. **l10n per code.** `allergenContains_<code>` / `dietary_<code>` in
   `app_en.arb` **and** `app_ar.arb`; the parity gate's zero-consumer check means
   an unrendered key is removed.
5. **Rejection is named.** An unknown code is refused at the repository boundary
   with an error naming the field and the code — never dropped, never defaulted.

## 5. Deliberately not decided here

- Whether any province requires a printed menu statement (unverified; the feature
  does not depend on it — see the research file §2).
- Whether species-level naming is required on menus (a prepackaged-label rule as
  written).
- French for Quebec tenants (Bill 96) — recorded in the research file §3 as an
  l10n gap for the Canadian market, not a P6-1 item.
