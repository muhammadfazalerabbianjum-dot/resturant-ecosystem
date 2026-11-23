# P6-1 — dietary trust layer: model, vocabulary, badges, filter, editor

Date: 2026-11-14. Card: `docs/queue-P6.md` P6-1 items 1–6 (item 3 was already
green from the rules slice). Preceding evidence: `checkpoints/P6-01-RULES.md`.

## 1. Codegen question, settled by measurement (D-055)

| Run | Command | Result |
|---|---|---|
| 1 | unfiltered `build_runner build --delete-conflicting-outputs` | **CODEGEN_EXIT=1** — my own directive-order error (`library;` after imports); 1 540 actions; **20 unrelated generated files rewritten and `loyalty_model.g.dart` deleted** |
| 2 | same, after fixing the directive and reverting all 20 files, with four `--build-filter` flags | **CODEGEN_EXIT=0** — `Succeeded after 25.9s with 702 outputs`; `git status` showed exactly the 4 intended files |

Verdict: codegen works; it must be filtered. Nothing about the generator stack
was unpinned, and `freezed_annotation/build_runner/freezed/json_serializable`
stay `any` (D-P34-1 untouched).

## 2. What was added

- `core_app/lib/features/menu/domain/dietary_codes.dart` — the ONE definition:
  13 declaration codes, 6 dietary codes, 3 filter chips, `validateDietaryCodes`
  (named `DietaryCodeException`, names field and code), `isHalalClaimLive`,
  `kHalalClaimFields`, and `CertExpiryConverter`.
  - It is a **leaf** file, not part of `packages/core`: the menu model must stay
    importable by the thin shell (D-050, no Isar), and the core barrel re-exports
    Isar. Its only dependency is `cloud_firestore` (web-safe).
- Both projections (`menu/domain/menu_item_model.dart`,
  `admin/domain/menu_item_model.dart`) gained `allergens`, `dietary`,
  `allergenNotes`, `halalCertified`, `halalCertBody`, `halalCertExpiresAt`.
- `AdminMenuItemModel.mergeWith` — facts (allergens/dietary/notes) inherit from
  the global item when the branch override is empty; **the certification claim
  does not inherit**. A branch override has its own kitchen, so showing a global
  claim there would assert a certification about premises nobody certified.
- `AdminDataService.saveMenuItem` validates both code lists at the write
  boundary (`_validateDietaryMetadata`) — unknown code ⇒ throw, not a dropped
  badge.
- `menu/domain/dietary_filter.dart` — pure `filterByDietary` (dietary = AND,
  exclusions = exhaustive).
- `menu/presentation/widgets/dietary_badges.dart` — halal / dietary / "Contains
  X" chips + optional cross-contamination note.
- Menu row: badges under the row (indented past the thumbnail).
- Dish detail: badges + note (`showNotes: true`).
- Menu screen: 3 dietary `FilterChip`s + an `Allergens` chip opening a 13-code
  sheet (`CheckboxListTile`, applies immediately, `Clear`, real close tooltip).
- Editor: 6 dietary chips, 13 allergen chips, notes field, and — **owner only** —
  the halal section (switch, body, expiry date picker, expired warning). A
  manager's save omits the three claim keys entirely, so correcting a price can
  never silently revoke a certification.
- l10n: **29 new keys in both locales** (`app_en.arb`, `app_ar.arb`), then
  `flutter gen-l10n` ⇒ 13 `allergenName*` getters generated. Arabic `vegan`
  refined to "نباتي صرف" (fully plant-based) so it is distinguishable from the
  new `dietaryVegetarian` "نباتي"; no test pinned the old value.

## 3. Two defects the work surfaced (both fixed, not papered over)

1. **Timestamp timezone drift.** `Timestamp.toDate()` returns a LOCAL
   `DateTime`, so a stored expiry round-tripped back to an offset-bearing ISO
   string (`2026-06-01T05:00:00.000` for a UTC instant). The converter now
   normalises everything to UTC. Caught by
   `a Firestore Timestamp is normalised on the way in` (RED: `Expected
   DateTime:<2026-06-01 00:00:00.000Z> Actual DateTime:<2026-06-01 05:00:00.000>`).
2. **Editor overflow.** With the new controls the editor's `Column` overflowed by
   **348 px** (and 208 px in the p22 harness) on a 600 px viewport. The body now
   scrolls (`SingleChildScrollView`). Caught by the p28 image-URL test, whose
   exception was `A RenderFlex overflowed by 348 pixels`.

## 4. Test-integrity note (assertions that had to change)

These are contract updates, not weakenings — each still pins an exact value:

| File | Before | After | Why |
|---|---|---|---|
| `p28_menu_item_editor_flow_test.dart` | `findsNWidgets(4)` BrandTextField | `5` | the notes field is the fifth |
| `p28_owner_menu_flow_test.dart` | `findsNWidgets(4)` | `5` | same |
| `p22_phase_e_adoption_test.dart` | `findsNWidgets(4)` + test name | `5`, renamed | same |
| `menu_screen_test.dart` test 6 | fixture `tags: ['vegan']`, `tap(find.text('Vegan'))` | fixture `dietary: ['vegan']`, `tap(find.widgetWithText(FilterChip, 'Vegan'))` | D-054: vegan is a claim now, and the row badge also renders the word |

No assertion was deleted, skipped or loosened; no gate was disabled.

## 5. Numbers from the runs that produced them (D-044)

- `flutter test test/features/menu/dietary_codes_test.dart` → **+19 All tests passed**
  (1 RED first: the Timestamp case).
- `flutter test test/features/menu test/l10n test/features/admin` → **+488 All
  tests passed** (after the three count updates and the D-054 fixture change;
  intermediate runs: `+479 -9`, then `-3`, then `-1`, each traced to a named
  cause above).
- `flutter analyze --no-pub` (whole `core_app`) → **No issues found! (ran in 193.3s)**.
- `flutter test test/features/menu` (existing menu suites incl. p16 adoption) →
  **+113 pass** at the final state.
- **Full battery PASS** — `checkpoints/gate-20261114T134809Z.md`, `GATE_EXIT=0`:
  a 21.2 s, b 373.3 s, c 16.2 s, d 29.8 s, e 4.8 s, f 0.0 s (23 files),
  i 1.4 s, g 22.8 s, h 1.8 s, j 106.0 s, k 27.0 s — **11/11 PASS**.
  Gate (f) stub-scan covers the new files; (h) backend parity passes with the
  rules copy already refreshed; (j)/(k) prove tenancy paths and the 56-failure
  harness baseline are unchanged.

## 6. Known limits (stated, not hidden)

- **Voluntary trust, not compliance.** Federal declaration duty applies to
  prepackaged food; restaurant menu statements are not federally required
  (`docs/RESEARCH-DRAFT-dietary-regulatory.md`). Every badge is the
  restaurant's declaration, never a safety guarantee.
- **Legacy `tags: ['vegan']` items lose the chip** (D-054). The tags→codes
  backfill is registered in `docs/BACKLOG-P5.md` §P6.
- **Expiry has no reminder** (out of scope by the card): an expired claim simply
  stops rendering, and the owner sees `halalClaimExpired` in the editor only
  when they open the item.
- **UI not visually inspected this session** — verification is analysis, widget
  tests and the p16/p28/p22 suites, not a device screenshot.
