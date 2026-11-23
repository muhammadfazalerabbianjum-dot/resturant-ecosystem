# RESEARCH — Canadian allergen declarations, and what applies to a restaurant menu

**Status: RESEARCHED 2026-11-13, approved implicitly by the owner's instruction
to recheck.** The draft's "current belief" lines were wrong in two places; this
file now records what the sources actually say, with dates and confidence.

## 1. The Canadian priority allergen list — VERIFIED

CFIA and Health Canada publish the same list, and it is **11 groups**:

| # | Priority allergen |
| --- | --- |
| 1 | eggs |
| 2 | milk |
| 3 | mustard |
| 4 | peanuts |
| 5 | crustaceans and molluscs (one group) |
| 6 | fish |
| 7 | sesame seeds |
| 8 | soy |
| 9 | sulphites |
| 10 | tree nuts — almonds, Brazil nuts, cashews, hazelnuts, macadamia nuts, pecans, pine nuts, pistachios, walnuts |
| 11 | wheat and triticale |

**Gluten sources are a separate declaration**, not an allergen: barley, oats,
rye, triticale, wheat. "Like priority allergens, gluten sources must be
identified on prepackaged food labels."

Sources (all read 2026-11-13):
- CFIA, *Before you shop: food allergies and allergen labelling* —
  https://inspection.canada.ca/en/food-labels/labelling/consumers/food-allergies
- Health Canada, *Common food allergens* —
  https://www.canada.ca/en/health-canada/services/food-allergies-intolerances/food-allergies.html
- CFIA, *List of ingredients and allergens on food labels* —
  https://inspection.canada.ca/en/food-labels/labelling/industry/list-ingredients-and-allergens
- Health Canada mustard pamphlet (lists the same 11, notes sulphites are grouped
  with allergens because sulphite-sensitive people react) —
  https://www.canada.ca/en/health-canada/services/food-nutrition/reports-publications/food-safety/mustard-priority-food-allergen.html

**Confidence: high.** Five independent government pages agree, and the industry
page names the prescribed source names.

### Two errors this corrected in my draft

1. I had conflated "wheat" (a priority allergen) with "cereals containing
   gluten" (a gluten declaration covering barley, oats, rye, triticale, wheat).
   Those are different obligations with different source lists.
2. I had included **celery** and **lupin**. Neither is on the Canadian list —
   they are EU obligations. They are now dropped.

## 2. Does a Canadian restaurant menu have to declare allergens? — VERIFIED ENOUGH

**No federal requirement found.** Every government page located frames the duty
as applying to **prepackaged** food labels ("prepackaged food labels must
identify priority allergens"). No primary source was found imposing allergen
declarations on food served unpackaged in a restaurant.

Secondary sources agree explicitly, e.g. a 2026-10-26 practitioner article
("No Canadian law requires allergen labelling on restaurant menus") and a
2025 venue-compliance page ("the cited federal labelling requirements concern
most prepackaged foods… they do not create a single federal rule requiring every
restaurant menu to list each allergen"). Both are secondary and neither is
authoritative on its own.

Provincial/local public-health guidance does expect a food premises to be able to
**give accurate allergen information on request** (e.g. Ottawa Public Health
enforcement summarised by a secondary source).

**Confidence: high** that the federal labelling regime is prepackaged-only.
**Medium** that no province imposes a menu-declaration duty — I sampled, not
surveyed, and "not found" is not "does not exist". The P6-1 checkpoint must carry
that distinction.

### What this means for the feature

The halal/dietary layer is **voluntary trust**, not a compliance feature. That
has two consequences already reflected in the card:
- the badge is a declaration by the restaurant, never a safety guarantee;
- **negligence is the exposure, not labelling law** — a wrong badge can be worse
  than no badge, which is why an expired certification renders nothing and why
  unknown codes are rejected rather than ignored.

## 3. Side finding worth keeping: Quebec

A secondary source notes Quebec's Bill 96 French-language obligations extend to
allergen notices. The app ships `en` + `ar`; a Quebec tenant would need `fr`
before any customer-facing notice is lawful. Not a P6-1 item — recorded so the
l10n roadmap does not treat "en + ar" as complete for the Canadian market.

## 4. What remains unverified

- Species-level naming obligations for **menus** (the species rule is a
  prepackaged-label rule; whether a menu that names "tree nuts" is exposed is a
  negligence question, not a labelling one).
- Whether any province requires printed allergen statements on menus. Needs a
  province-by-province check if a tenant asks.
- French-language obligations in detail (Bill 96 scope for menus).

Those stay as open questions; none blocks P6-1, because the feature is voluntary
and its badge wording is a declaration.
