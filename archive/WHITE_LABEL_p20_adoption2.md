# WHITE_LABEL_p20_adoption2 — UI-10: LIBRARY ADOPTION WAVE 2 (orders + profile + reservations/loyalty/waitlist) — MAIN, SINGLE EXECUTOR

**Purpose:** adoption wave 2 — wire the library into the remaining high-visibility customer surfaces (orders list, order tracker, profile) and the owner/manager dashboard, completing the customer journey. Predecessor: UI-6 (p16) merged — same laws, same visual-floor mechanics. Admin staff screens NOT in the delivery/kitchen flow (kitchen_dashboard, delivery_dashboard, dead_letter) stay a later wave if still needed — p17 already upgrades the analytics surface.

## §0 Rules (inherited from p16 §0 verbatim — 0.8–0.10 + L12–L15)

Carried from `WHITE_LABEL_p16_adoption1.md`: main-only single executor; read-mostly (`core_ui` seams only as receipted red→green fallout); presentation-only (no provider/logic changes); **L12 visual floor** (token colors, Gap spacing, entrance motion, skeletons, 48×48 dp + 8 dp targets, before/after golden pairs → owner visual review); **L13 money-display parity** (positive prices byte-identical; divergences = DECISIONS + goldens; order totals display-only, never recomputed); **L14 behavior preservation** (Semantics, Hero, Cloudinary thumbs, haptics, l10n en+ar, tracking flows); **L15 no new deps**. Plus: **L16 REAL-TIME STATE SANCTUARY — every live-state mechanism is untouchable: order-state logic, order/tracking timers, Firestore listeners/streams, reservation seat decrements and waitlist ordinals (LEDGER:PERF-9 W1/W2), sync-queue paths. Wiring may touch presentation widgets ONLY.**

## §1 Baseline (P1)

- p16 wave 1 merged (menu/dish/home/cart wired; visual-review pack approved by owner — dispatch only after that approval).
- Surfaces this wave: `features/orders/presentation/**` (orders list, order tracker), `features/profile/presentation/**`, `features/reservations/presentation/**`, `features/loyalty/presentation/**`, `features/waitlist/presentation/**` (exact files enumerated at SYNC into the report's territory table).
- Reuse-ready components: `StatTile` (order stats), `StatusTile`/`BrandBadge` (order states), `SectionHeader`, `EmptyStateWidget`, `SkeletonLoader`, `PriceTag`, `InfoBanner`, `Gap`.

## §2 Territory (exclusive)

MODIFIED (presentation only, enumerated at SYNC): `core_app/lib/features/orders/presentation/**`, `profile/presentation/**`, `reservations/presentation/**`, `loyalty/presentation/**`, `waitlist/presentation/**` — named per file in the report
MODIFIED (additive fallout only): `packages/core_ui/lib/src/ui/**` seams + their tests
NEW: tests + goldens per touched surface · `tool_uilib/p20/**`
FORBIDDEN: order-state/timer/listener logic, providers, money derivation, `theme/**`, `FIX_VERIFICATION.md`, `pubspec.*`, functions/rules, apps/**, admin flow dashboards beyond the owner dashboard stat surfaces.

## §3 Phases → T-x table (each phase: red→green + goldens; commit per phase)

| Phase | Tasks | Acceptance |
|---|---|---|
| **A — orders list** | A1: order rows → tile composition (`StatusTile`/`BrandBadge` for state, `PriceTag` for totals via L13 parity, `SectionHeader` for status groups). A2: empty history → `EmptyStateWidget`; loading → skeletons. A3: entrance motion per L12.3. | orders tests green; goldens pair; l10n untouched. |
| **B — order tracker** | B1: tracker surface presentational upgrade ONLY (L16 sanctuary: state logic/timers/listeners untouched — status header → `InfoBanner` tone mapping, progress visuals tokenized). B2: a11y preserved (live-region announcements if present stay). | tracker tests green; goldens pair; state-machine tests untouched and green. |
| **C — profile** | C1: profile sections → `SettingTile` rows (leading icon, trailing chevron where tappable), `SectionHeader` groups, `BrandDivider` separators. C2: GDPR/delete-account surface keeps its compliance wording verbatim (presentation-only restyle). | profile tests green; goldens pair. |
| **D — reservations + loyalty + waitlist** | D1: reservation cards → `BrandCard` + `StatusTile`; loyalty points → `StatTile`; waitlist position → `StatTile`/`Badge`. D2: each surface's empty/loading states per L12. | feature tests green; goldens pairs. |
| **E — owner dashboard stats** | E1: `owner_dashboard.dart` stat surfaces → `StatTile`/`SectionHeader` (DISPLAY ONLY — dashboard data reads untouched; p17 owns the analytics surface). E2: visual-review pack assembly (all before/after pairs). | owner-dashboard tests green; pack complete. |
| **F — close** | F1: full battery (analyze ×3, format, all suites, rules/functions untouched via git). F2: coverage floors (core_ui 100% × fleet files; core_app ≥ baseline). F3: report §4. | every §5 item green. |

## §4 Deliverable

`tool_uilib/p20/p20_report.md`: territory table (every touched file enumerated); per-T evidence; visual-review pack index; six-way classification; DECISIONS-NEEDED-FROM-OWNER; UNVERIFIED (non-empty allowed); DRIFT; paste-ready `## APP COMPLETION UI-10 (p20)` block.

## §5 Acceptance

Identical gate set to p16 §5: analyze ×3 + format 0 · all suites green **0 skip** no drop · l10n en+ar parity · W9 a11y suite · ban test · coverage floors · goldens deliberately re-captured (inventory in report; no forced greens) · tracking state-machine tests untouched · `git status` proves zero forbidden paths.

## §6 Judge + close

Coordinator re-runs the battery; reviews the visual-review pack WITH the owner (appeal verdict = owner's); spot-checks ≥3 (B1 sanctuary proof — state-machine test files untouched, L13 parity on order totals, A1 status mapping); appends the ledger block. This wave completes the customer journey — remaining admin flow dashboards (kitchen/delivery/dead-letter) and the owner dashboard's structural split are owned by the later batch named in the corrected queue: **`WHITE_LABEL_p22_staff.md`** (owner recorded 2026-09-24 by the Stage-3 triage register `AUDIT_TRIAGE_STAGE3.md` §2.2/§2.3, closing `AUD4-C5-01` — this line previously deferred to an unwritten "candidate p21").

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-10 (p20), ADOPTION WAVE 2 (orders, tracker, profile, reservations/loyalty/waitlist, owner dashboard stats), MAIN ONLY.
Read <repo>\WHITE_LABEL_p20_adoption2.md IN FULL — binding contract. Carries p16 §0 (0.8-0.10 + L12-L15) + L16 order-tracking sanctuary.
Predecessor: UI-6 (p16) merged AND its visual pack owner-approved.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts. BLOCKER: analyze x3 + format + all suites green 0 skip BEFORE any edit. Failure => STOP.
2. ENUMERATE territory: list every presentation file per §2 into the report's territory table (P1).
3. RED per phase: phase tests first, captured to tool_uilib/p20/red_phase<X>.txt.
4. GREEN per phase (A orders -> B tracker -> C profile -> D res/loyalty/waitlist -> E owner stats): visual floor at every seam; commit after EACH phase; never end on red.
5. L16 SANCTUARY: zero edits to order-state logic/timers/listeners; state-machine tests untouched and green.
6. L13 PARITY: order totals display-only; parity tests green.
7. GATES (F1): analyze x3 + format + ALL suites 0 skip; l10n + a11y + ban tests; coverage floors; goldens inventory; forbidden paths 0.
8. REPORT: tool_uilib/p20/p20_report.md per §4 (territory table, visual pack index, six-way, UNVERIFIED, DECISIONS, DRIFT, paste-ready UI-10 ledger block). NEVER touch FIX_VERIFICATION.md.
9. COMMIT final + battery on the tip; push only if credentials cached; owner reviews the visual pack before close.
DoD: §5 green + visual pack ready + receipts committed + green committed tip + nothing uncommitted.
```

**END OF UI-10 SPEC — adoption wave 2.**