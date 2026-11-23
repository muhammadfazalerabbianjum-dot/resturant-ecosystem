# WHITE_LABEL_p22_staff — UI-12: STAFF / ADMIN SURFACE WAVE (kitchen, delivery, manager, setup, gateway) — MAIN, SINGLE EXECUTOR

**Purpose:** the LAST unassigned rung of the ladder. `WHITE_LABEL_p20_adoption2.md:43` deferred every staff/admin surface to a "candidate p21" that was never written; the Stage-3 triage register ratified **this spec** as the owner (`AUDIT_TRIAGE_STAGE3.md` §2.2/§2.3, decision **D-5**) and Stage 5's delta re-audit independently confirmed the orphan (`AUD-4R2` Task 2, finding **S5-01** / register row `AUD4-C5-01`). This file is the written owner that deferral was pointing at — with it, the class-5 orphan is closed.
**Predecessors:** UI-6 (`p16`) merged **and** UI-10 (`p20`) merged (p20 §1 gates the owner-dashboard stat surfaces this wave structurally splits) **and** `p23_widgets` merged (`BrandDataTable` W-6 + `BrandSheet`/`BrandDialog` W-4 are consumed here). **Dispatch floor: `git merge-base --is-ancestor c838d7e HEAD` == 0** (2026-09-28). `p17_analytics1` owns the analytics surfaces — **not this wave**. Read `tool_uilib/p23/p23_report.md` §8 before wiring any adopted component: that section is the frozen API contract.

## §0 Rules (inherited p16 §0 verbatim — 0.8–0.10 + L12–L15 — plus p20 L16)

Carried from `WHITE_LABEL_p16_adoption1.md`: main-only single executor; read-mostly (`core_ui` seams only as receipted red→green fallout); presentation-only. **L12 visual floor** (token colors, `Gap`/`AppDimensions` spacing, entrance motion, skeletons, ≥48×48 dp with ≥8 dp separation, before/after golden pairs → owner visual review) · **L13 money-display parity** (positive/known-code strings byte-identical; divergences = DECISIONS + goldens; totals display-only) · **L14 behavior preservation** (Semantics, l10n en+ar parity, existing flows) · **L15 no new dependencies** · **L16 live-state sanctuary** (order-state logic, timers, Firestore listeners/streams, seat decrements, waitlist ordinals, sync-queue paths untouchable).

### Staff-specific laws

**L17 WRITE-PATH SANCTUARY (the money-adjacent version of L16).** Staff screens *mutate* order status through the `IsarSyncQueue` `update` path (`BATCH STAFF-QUEUE`: `kitchen_service.dart`, `delivery_service.dart`, `proof_of_delivery_service.dart`). This wave touches **presentation only**: no service call, queue op, status value, POD shape, or replay semantic may change. Any status write you see that still bypasses the queue is a **handoff note**, never a drive-by fix.

**L18 SOURCE VISIBILITY (earned from p19 L6).** `p19` ingests platform orders carrying `orderSource: platform:<id>`; kitchen/delivery views DO receive them (consumer order history does not). Every order-bearing staff row must render its source as a `BrandBadge` when `orderSource` is a platform value — an operator must never have to guess whether a ticket came from the app or from Uber Eats. Absent `orderSource` renders exactly as today (byte-identical golden).

**L19 OPERATOR DENSITY CEILING.** Kitchen/delivery screens are read at arm's length, often one-handed, often with wet hands: **no interactive target below 48×48 dp inside a scrolling ticket list, and no hover-only affordance.** Where a surface is too dense to satisfy L12 and L19 at once, the fix is **structural extraction** (split the file, extract a widget) — never smaller targets. The structural split of `owner_dashboard.dart` (register row `F3-14`; **1152 lines at dispatch 2026-09-28** — it was 1107 at authoring, 1159 when audited, and p20's scroll wrapper added the rest; re-measure at SYNC) is part of this wave. **L19 governs the operator half of the adoption-gap family too:** `CircularProgressIndicator` (F3-09), raw `ListTile` (F3-10), raw `Card` (F3-11), raw `TextField` (F3-12), decorated `Container` (F3-15) and `showModalBottomSheet` (F3-13 adoption half) are swept here **only** inside this wave's files — the customer half is `p21`'s (see §2 Sweep partition).

**L20 CONCURRENT-WAVE BOUNDARY.** `p21_adoption3` runs beside this wave and owns the **entire customer journey** — `checkout/**`, `splash/**` + `onboarding/**` + `tour/**`, `auth/**`, `locations/**` + `location/**`, `tracking/presentation/delivery_tracker_screen.dart`, `orders/presentation/order_tracker_steps_widget.dart`, `compliance/**` + `privacy_policy_screen.dart`, `app/config/feature_flags_service.dart` + `core_app/assets/client_config.json`. **Never edit those files**; if a staff surface needs a customer-owned widget, record a handoff row instead. `p17_analytics1` owns `features/admin/presentation/analytics/**` and adds event lines to `checkout/**`: it must not be editing `analytics_snapshot.dart` / `analytics_provider.dart` while you run — treat those two as read-only and record any needed change as a handoff.

## §1 Baseline (P1 — re-measured at dispatch 2026-09-28 at `c838d7e`; re-measure again at SYNC)

| Surface | Lines at dispatch | Note |
|---|---|---|
| `features/admin/presentation/owner/owner_dashboard.dart` | **1152** | densest + largest surface on the ladder (`F3-14`); it was 1107 at authoring and p20 added a scroll wrapper — **p20 already restyled its stat surfaces**, so this wave does the STRUCTURAL SPLIT only |
| `features/admin/presentation/setup/restaurant_setup_screen.dart` | **896** | the second-largest hand-rolled surface in the app |
| `features/admin/presentation/delivery/delivery_dashboard.dart` | **503** | holds the sync-queue write path (L17) |
| `features/admin/presentation/kitchen/kitchen_dashboard.dart` | **430** | receives p19's platform tickets (L18) |
| `features/reservations/presentation/admin_reservations_tab.dart` | **376** | **p20 owns `reservation_screen.dart`** — this wave touches the ADMIN tab only |
| `features/admin/presentation/setup/operating_hours_screen.dart` | **229** | |
| `features/admin/presentation/manager/manager_dashboard.dart` | **134** | |
| `features/admin/presentation/dead_letter_screen.dart` | **134** | the DLQ observability surface (p19 writes into it) |
| `features/admin/presentation/setup/tier_flag_manager_screen.dart` | **123** | |
| `features/admin/presentation/gateway/admin_gateway_screen.dart` | **119** | |
| `features/admin/presentation/admin_menu_manager.dart` | **86** | |
| `features/admin/presentation/role_router_screen.dart` + `role_gate.dart` | **81 + 76** | role routing: ZERO logic edits (routing is not presentation) |

**Adoption-gap counts for the operator half of `F3-09..F3-15`** (dispatch-time, `core_app/lib`, to be re-measured at SYNC and split by audience per L19 — the customer half is `p21`'s per its L32): `CircularProgressIndicator` 73 occurrences / 30 files · `ListTile` 27 / 13 · raw `TextField(` 12 / 4 (9 of them in `owner_dashboard.dart`) · `BoxDecoration` 7 / 6 · `showModalBottomSheet` 5 / 2 (F3-13's adoption half — `BrandSheet`/`BrandDialog` exist as of `c838d7e`).


## §2 Territory (exclusive)

MODIFIED (presentation only; every file enumerated in the report's territory table at SYNC): `core_app/lib/features/admin/presentation/{owner/owner_dashboard.dart, kitchen/**, delivery/**, manager/**, setup/**, gateway/**, dead_letter_screen.dart, admin_menu_manager.dart, role_router_screen.dart, role_gate.dart}` · `core_app/lib/features/reservations/presentation/admin_reservations_tab.dart`
NEW: extracted presentational widgets under `features/admin/presentation/**` (the structural split's product) · tests under `core_app/test/**` named per phase · golden re-captures under the existing golden dirs · `tool_uilib/p22/**`
MODIFIED (additive fallout only, red→green receipted): `packages/core_ui/lib/src/ui/**` seams + their tests, only where p23's components need a documented seam
FORBIDDEN: `features/admin/presentation/analytics/**` and `features/admin/presentation/privacy_policy_screen.dart` (p17 / p21) · all `*_provider.dart`, services (`kitchen_service`, `delivery_service`, `proof_of_delivery_service`), repositories, sync-queue paths (L17) · `theme/**` · `FIX_VERIFICATION.md` · `pubspec.*` · `functions/**`, `firestore.rules`, `storage.rules` · `apps/**`.

**Boundaries (do not cross) — re-measured at dispatch 2026-09-28, not assumed:** `features/admin/presentation/analytics/**` (`revenue_chart_widget` 200, `top_items_chart_widget` 184, `analytics_snapshot` 110) = **p17** · `features/admin/presentation/privacy_policy_screen.dart` (**103**, was 95 at authoring) + `features/compliance/**` = **p21** (M-6 compliance presentation) · the whole customer journey — `checkout/**` (M-1), `splash/**` + `onboarding/**` + `tour/**` (M-2), `auth/**` (M-3), `locations/**` + `location/**` (M-4), `tracking/presentation/delivery_tracker_screen.dart` (M-5, the CUSTOMER tracker — not `admin/presentation/delivery/delivery_dashboard.dart`, which is ours), `orders/presentation/order_tracker_steps_widget.dart` (M-8), and `app/config/feature_flags_service.dart` + `core_app/assets/client_config.json` (p21's D-2) = **p21** · the ARB files `l10n/app_en.arb` / `app_ar.arb` + `currency_format.dart` = **p18/p24** (reuse existing keys; a missing string is a BLOCKER + handoff, never an inline literal) · `packages/core_ui/lib/src/ui/**` except a receipted, documented seam = **p23's frozen contract** (`tool_uilib/p23/p23_report.md` §8 is binding for every component you adopt) · provider/service/domain files everywhere = forbidden.

**Sweep partition (L19 + p21 L32):** this wave owns the **operator half** of the adoption-gap family (`F3-09` spinner, `F3-10` raw `ListTile`, `F3-11` raw `Card`, `F3-12` raw `TextField`, `F3-15` decorated `Container`, and the `F3-13` adoption half) for every file inside `features/admin/**` + `admin_reservations_tab.dart`; every customer-facing occurrence belongs to `p21`. Report the before/after counts split by audience, and never edit a file outside this wave's territory to "finish the sweep".

### §2 Amendment A1 (coordinator ruling, 2026-09-28) — the L18 domain seam

**Ruling: L18 is unsatisfiable without a model field; the field is GRANTED as a single, scoped, receipted seam. The presentation-only rule is waived for exactly one file and one field — nothing else.**

Verified basis (coordinator, receipts in this session): `orderSource` **is** persisted on the order document by the Cloud Function (`core_app/functions/src/platform_ingestion.ts:528` → `buildOrderSource(platformId)`; client vocabulary `OrderSource` already lives in `packages/core/lib/src/delivery/ingested_order.dart:25-46` and is exported). `OrderModel` (`features/orders/domain/order_model.dart:94-118`) has no field for it, and `tryFromDoc:126-162` passes the raw map straight into `fromJson` — json_serializable ignores the unknown key, so the value is present in the snapshot and unreachable in Dart. Kitchen reads `List<OrderModel>` (`kitchen_dashboard.dart:24-29`), so no `DocumentSnapshot` reaches presentation and **no presentation-only plumbing exists**.

PERMITTED (and nothing more):
1. `core_app/lib/features/orders/domain/order_model.dart` — add ONE nullable, read-only field `String? orderSource` to the freezed factory, normalised through a `@OrderSourceConverter()` (the file's own sanctioned pattern, `order_model.dart:66-88`: a `JsonConverter` avoids the `invalid_annotation_target` lint that a `@JsonKey` on a freezed parameter raises — there is ZERO `@JsonKey` in any hand-written lib file today, and lint suppression is banned). Malformed/absent/non-string values MUST fail closed to `null`, never throw (`json['orderSource'] as String?` would throw on an int — the converter is why).
2. Regenerate with `dart run build_runner build --delete-conflicting-outputs`; **never** hand-edit `*.freezed.dart` / `*.g.dart`.

ACCEPTED CONSEQUENCE (disclose it, do not hide it): `OrderModel.toJson()` gains `'orderSource': null` for locally-created orders. This is **not** a new serialization behaviour — `order_model.g.dart:37-56` already emits five null keys (`updatedAt`, `branchId`, `assignedDriverId`, `customerLat`, `customerLng`). L17 is intact: the staff queue payload is the hand-built two-key map `buildKitchenStatusUpdatePayload` (`kitchen_service.dart:151-166`, "must stay EXACTLY these two keys"), which never touches `toJson()`; and the orders **create** rule (`firestore.rules:465-472`) has **no** `affectedKeys().hasOnly(...)` clause, so the offline create replay (`order_offline_payload.dart:22`) still lands — the `hasOnly` verdicts at `firestore.rules:483-530` are update-time only.

REQUIRED RECEIPTS (beyond the §4 list):
- byte-diff of `buildOfflineOrderPayload(...)` output before vs after (the added key shown, not implied);
- `git diff` proof that `buildKitchenStatusUpdatePayload` and every service/queue/provider file is untouched;
- Law 24 roundtrip test incl. the malformed case (`orderSource: 12345` → `null`, no throw), the absent case, and the platform case;
- a test proving the client create path yields `orderSource == null` (the client can never forge the tag);
- consumer-isolation re-verification: a platform order still cannot appear in a customer's history (the p19 L6 query is unchanged);
- L18 badge reads `OrderSource.isPlatformOrder(...)` / `OrderSource.platformOf(...)`; `null` renders **byte-identical** to today's golden.

HANDOFF ROW (record it, do not fix it): if the create rule is ever hardened with `hasOnly`, the offline create payload's `orderSource: null` key must be dropped — owner **p26** (rules hardening / generator completeness).



## §3 Phases → T-x table (each phase: red→green receipt + goldens; commit per phase, never end on red)

| Phase | Tasks | Acceptance |
|---|---|---|
| **A — kitchen + delivery (the live-ticket rung)** | A1: ticket cards → `BrandCard` + `StatusTile`/`BrandBadge` composition (L18 source badge; L19 target sizes). A2: status-action affordances → library buttons with token sizing, haptics preserved; the SERVICE CALLS are untouched (L17). A3: empty/loading → `EmptyStateWidget`/`SkeletonLoader`; entrance motion per L12.3. A4: `delivery_dashboard`'s assign/POD affordances re-skinned only. | kitchen + delivery tests green (status-write tests untouched & green); goldens pair; L17 diff proof = zero edits in service/queue files. |
| **B — manager + dead-letter (the observability rung)** | B1: `manager_dashboard` → `StatTile`/`SectionHeader`/`BrandCard` (display-only). B2: `dead_letter_screen` → `BrandDataTable` (W-6, from p23) with token row density, tone-mapped `InfoBanner` for failure classes, `EmptyStateWidget` for the healthy case. | tests green; goldens pair; DLQ behavior (retry/discard actions) unchanged — actions re-skinned only. |
| **C — setup ×3 + menu manager + gateway (the configuration rung)** | C1: `restaurant_setup_screen` (896) → `SectionHeader` groups + `SettingTile`/field composition + `BrandSheet` for pickers (W-4); validation messages verbatim (wording is compliance). C2: `operating_hours_screen` → tile rows + time affordances tokenized. C3: `tier_flag_manager_screen` → switch/tile rows. C4: `admin_menu_manager` → `MenuTile`-family rows. C5: `admin_gateway_screen` + `role_router_screen` + `role_gate` → brand surfaces; **routing/branch logic untouched** (presentation only). | setup/menu-manager/gateway tests green; goldens pairs; zero config-write logic changes. |
| **D — owner dashboard structural split (`F3-14`) + reservations tab** | D1: split `owner_dashboard.dart` (**1152** at dispatch) into extracted presentational widgets by section (target: no file > 400 lines), **behavior-identical**: same widgets, same keys, same Semantics; goldens must match the p20-restyled look (this phase must NOT re-style what p20 already approved — split only). D2: `admin_reservations_tab.dart` (376) → `StatusTile`/`BrandCard` rows; reservation state/seat logic untouched (L16). | owner-dashboard + reservations tests green; **before-split/after-split goldens byte-identical** (the split is provably presentational); reservations seat tests untouched & green. |
| **E — operator adoption sweep (the operator half of `F3-09..F3-15`)** | E1: sweep `CircularProgressIndicator` (F3-09 — the 9 raw `TextField(` in `owner_dashboard.dart` are part of this), raw `ListTile` (F3-10), raw `Card` (F3-11), raw `TextField` (F3-12), decorated `Container` (F3-15) and `showModalBottomSheet` → `BrandSheet`/`BrandDialog` (F3-13 adoption half) **inside this wave's files only** (L19 tail + §2 Sweep partition), with an explicit `moneyConfirming` choice recorded in DECISIONS for every sheet/dialog conversion. | before/after counts reported **split by audience** with the untouched customer-side occurrences listed as `p21` handoffs; every touched file's suite green 0 skip; goldens pairs wherever a visual change is claimed. |
| **F — close** | F1: full battery (analyze ×3, format, all suites, rules/functions untouched-verification via git). F2: golden re-capture inventory + the visual-review pack (before/after pairs per surface; every `before` re-rendered from `git show <pre-commit>:<path>` and hash-matched — the p20 DRIFT-5 standard) for owner approval. F3: coverage floors (core_ui 100% held; core_app aggregate ≥ baseline); every new extracted widget covered. F4: report §4. | every §5 item green. |

## §4 Deliverable

`tool_uilib/p22/p22_report.md`: territory table (every touched file, with line counts before/after for the split); per-phase evidence; **L17/L16 sanctuary proof** (git-diff receipt showing zero edits under services/queue/providers); **L18 source-badge proof** (both cases: platform present + absent, with the absent-case golden byte-identical); L19 target-size audit table (minimum target per scrolling surface); **the operator sweep table with before/after counts split by audience + the `p21` handoff rows**; `moneyConfirming` decisions per converted sheet/dialog; visual-review pack index; six-way classification; DECISIONS-NEEDED-FROM-OWNER; UNVERIFIED (non-empty allowed); DRIFT; handoff table; paste-ready `## APP COMPLETION UI-12 (p22)` block.

## §5 Acceptance

Identical gate set to p20 §5: analyze ×3 + format 0 · all suites green **0 skip**, no drop · l10n en+ar parity · W9 a11y suite · ban test · coverage floors · goldens deliberately re-captured (inventory in report; no forced greens) · **status-write/service tests untouched and green** · `git status` proves zero forbidden paths.

## §6 Judge + close

Coordinator re-runs the battery; reviews the visual-review pack WITH the owner (appeal verdict = owner's); spot-checks ≥3 (the split's byte-identical goldens, the L17 diff proof, the L18 badge on an ingested platform order); appends the ledger block. **This wave closes register rows `AUD4-C5-01`/`S5-01` (the staff rung now has a written owner AND a shipped wave), `F3-14`, the operator half of `F3-09..F3-13` and `F3-15`, and the M-7 family.** Scope note (verified against the register, not assumed): `F3-07` ("10 of 81 surfaces UNASSIGNED") lists **customer** surfaces only — delivery tracker, splash, pin-drop map, delete-account, terms, onboarding, live-map picker, logs screen, bug reporter — and its register owner is `p21_adoption3`; none of them belong to this wave.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-12 (p22), STAFF/ADMIN SURFACE WAVE (kitchen, delivery, manager, setup x3, dead-letter, gateway/role, menu manager, owner-dashboard split, admin reservations tab), MAIN ONLY.
Read <repo>\WHITE_LABEL_p22_staff.md IN FULL — binding contract. Inherits p16 §0 (0.8-0.10 + L12-L15) + p20 L16 + L17 write-path sanctuary + L18 source visibility + L19 operator density ceiling.
Predecessors: p16 merged AND p20 merged AND p23_widgets merged (BrandDataTable / BrandSheet consumed). Dispatch floor: `git merge-base --is-ancestor c838d7e HEAD` == 0.
ALSO READ tool_uilib/p23/p23_report.md §8 - the frozen API contract for every component you adopt.
YOU RUN BESIDE p21 (customer journey: checkout/splash/onboarding/tour/auth/locations/tracking/order-tracker-steps/compliance/feature-flags) - NEVER edit those files (L20); record handoffs instead.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts + re-measure every §1 line count + the adoption-gap counts. BLOCKER: analyze x3 + format + all suites green 0 skip BEFORE any edit. Failure => STOP, evidence table.
2. ENUMERATE territory (§2) into the report's territory table (P1) — including the forbidden-path boundary table (p17 analytics, p21 customer journey, p18/p24 ARB) and the operator/customer sweep partition.
3. RED per phase; GREEN in order A kitchen/delivery -> B manager/dead-letter -> C setup/menu-manager/gateway -> D owner split + reservations tab -> E operator sweep; commit after EACH phase; never end on red.
4. L17 SANCTUARY: zero edits to services, queue paths, providers; capture the git-diff proof. L16: reservation/seat logic untouched.
5. L18: every order-bearing row renders the platform source badge when orderSource is a platform value; absent => byte-identical golden.
6. L19: no interactive target below 48x48dp in scrolling ticket lists; structural extraction instead of shrinking targets. The operator sweep (E) covers ONLY this wave's files.
7. GATES (F1): analyze x3 + format + ALL suites 0 skip; l10n + a11y + ban; coverage floors; goldens inventory; forbidden paths 0.
8. REPORT: tool_uilib/p22/p22_report.md per §4 (territory table with before/after line counts, sanctuary proofs, L19 audit, operator sweep table + p21 handoffs, moneyConfirming decisions, visual pack index, six-way, UNVERIFIED, DECISIONS, DRIFT, handoff, paste-ready UI-12 ledger block). NEVER touch FIX_VERIFICATION.md.
9. COMMIT final + battery on the tip; push only if credentials cached; owner reviews the visual pack before close.
DoD: §5 green + visual pack ready + receipts committed + green committed tip + nothing uncommitted.
```

**END OF UI-12 SPEC — the last unanswered rung of the ladder is now owned and written.**

