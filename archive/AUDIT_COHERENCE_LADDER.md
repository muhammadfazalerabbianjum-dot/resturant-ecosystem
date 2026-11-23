# AUDIT — COHERENCE / MISSING-STAIR + VISUAL-WIDGET GAP (owner-commissioned recheck)

**Method:** P1 inventory of every presentation surface + the library's class inventory + the config guard tests. Question asked: does every idea have a rung — or is something unassigned?

## §1 Rungs that ARE connected (verified)

| Chain | Status |
|---|---|
| fleet (p11–p15) → library → client inheritance | ✅ path deps `core`/`core_ui`/`labs` (halal_boyz pubspec) — automatic |
| tokens (b10) → client config → theme engine | ✅ receipts in the halal_boyz audit (Playfair/Inter, ctaRadius 100, nav, dark) |
| locale → delegates → supportedLocales | ✅ `app_bootstrap.dart:788-802` (ar+en) |
| analytics → consent gate → events | ✅ gate at `telemetry_service.dart:59` (fail-closed) |
| delivery adapters → idempotency → money authority | ✅ p19 contract (LEDGER:PERF-8/10 machinery) |
| adoption waves → visual review → judge | ✅ p16/p20 gate design |

## §2 MISSING STAIRS — surfaces with NO owning wave

Inventory: **39 presentation files** (P1: full listing this session). Waves own **13** (p16: 5 · p20: 8). The rest are unassigned:

| # | Severity | Unassigned surface | Size receipt | Why it matters |
|---|---|---|---|---|
| M-1 | **CRITICAL** | **`checkout_screen.dart` + `tip_selector_widget.dart`** | **921 + 106 lines** | The most money-critical customer screen — and the LARGEST hand-rolled UI in the app. No wave, no spec. |
| M-2 | **HIGH** | `splash_screen.dart` + `onboarding_screen.dart` + `tour_overlay.dart` | 148 + 74 + overlay | First impression = brand impression; every client user sees these before anything else. |
| M-3 | HIGH | `login_screen.dart` + `signup_screen.dart` + `terms_of_service_screen.dart` | 505(+2) | The auth funnel — second-most-visited surfaces. |
| M-4 | MED | `location_screen.dart` + `pin_drop_map_screen.dart` | — | Customer location flow (map widgets exist in core_ui: `live_map_picker_widget`). |
| M-5 | MED | `delivery_tracker_screen.dart` | 201 | Customer-facing delivery tracking (customer journey tail). |
| M-6 | LOW | `delete_account_screen.dart`, admin `privacy_policy_screen.dart` | — | Compliance surfaces (presentation-level only). |
| M-7 | **HIGH (queue hole)** | **ALL staff surfaces:** `kitchen_dashboard` (430), `delivery_dashboard`, `manager_dashboard` (134), `admin_menu_manager` (86), `dead_letter_screen`, `admin_gateway_screen`, `role_router_screen`, setup ×3, `admin_reservations_tab` | receipts above | p20 §6 DEFERRED these to "candidate p21" — but no such spec exists. And p19's platform orders land in the kitchen view. A deferred item with no spec is a ladder with a missing rung. |
| M-8 | MED | `order_tracker_steps_widget.dart` | 81 | Hand-rolled status timeline — a library component does not exist (see W-2). |

## §3 VISUAL-WIDGET GAPS — library components the uncovered surfaces need

Verified against the library's actual class inventory (P1: 26 exported classes). These do NOT exist:

| # | Missing component | Needed by | Evidence |
|---|---|---|---|
| W-1 | `SegmentSelector`/`TipSelector` | checkout tip picker | `tip_selector_widget.dart` (106 hand-rolled lines) |
| W-2 | `OrderTimeline` (steps indicator) | order tracker | `order_tracker_steps_widget.dart` (81 hand-rolled lines) |
| W-3 | Chart family (`BrandChart`) | owner/manager dashboards | `revenue_chart_widget.dart` + `top_items_chart_widget.dart` are APP-side only — no library chart exists for future clients |
| W-4 | `BrandSheet`/`BrandDialog` wrappers | every feature with dialogs | library has only the GDPR dialog; no generic brand sheet/dialog |
| W-5 | `BrandedSplash` / `OnboardingShell` | first-run | splash 148 + onboarding 74 hand-rolled |
| W-6 | `BrandDataTable` | staff dashboards | kitchen 430 / manager 134 lines hand-roll table-ish layouts |
| W-7 | (absent feature, not a gap) | — | No ratings/reviews feature exists anywhere; recording as absent-by-design, not a missing component |

## §4 Cross-cutting constraint found (must be honored by p16.5 and every config edit)

`core_app/test/ui/accessibility_guidelines_test.dart:203-232` (P1, read this session) loads the `theme` section of **BOTH** client configs and asserts the AA-passing palette values (`AppColors.primary == 0xFFC84F00`, `textSecondary`, `success`). Consequence: **any brand-hue edit** (the p16.5 confetti/input/chip polish) must be checked against that guard — a new hue that breaks AA fails a red gate, correctly. Also verified: there is NO config-vs-config *theme-key completeness* test — that belongs in the p25 (F-8) family.

## §5 Verdict — the logic holds; the LADDER has three real holes

1. **Coverage hole:** waves own 13 of 39 surfaces. The unassigned set contains the checkout (921 lines, money-critical), first-run, auth, maps, tracking, compliance, and ALL staff screens.
2. **Component hole:** six visual-widget families the uncovered surfaces need do not exist in the library (W-1..W-6) — checkout/tracker/dashboards hand-roll them per screen (duplication the fleet exists to kill).
3. **Queue hole:** p20 deferred staff screens to a "candidate p21" that was never written while p21+ got assigned to other things — the deferred rung went missing.

Everything else lines up: no contradictory assumptions found between specs (consent gate, money authority, locale wiring, config validation, inheritance all receipted and consistent).

## §6 Corrected queue (renumbered, no hole left unassigned)

| Spec | Owns | Depends on |
|---|---|---|
| `p16_adoption1` | menu, dish detail, home, cart (+ **p16.5 config polish: F-1..F-4/F-6, AA-guard-aware**) | running |
| `p17_analytics1` | events + dashboard | p16 |
| `p18_arabic1` | plurals + RTL + locale currency | p16 |
| `p19_delivery1` | adapters v1 | independent |
| `p20_adoption2` | orders, tracker, profile, reservations, loyalty, waitlist, owner stats | p16 |
| **`p21_adoption3`** (NEW) | **M-1 checkout+tip · M-2 splash/onboarding/tour · M-3 auth · M-4 locations · M-5 delivery tracker · M-6 compliance presentation** | p16/p20 (reuses W-1/W-2 once p23 lands — or hand-rolls temporarily with a documented seam) |
| **`p22_staff`** (NEW) | **M-7 all staff/admin surfaces** (kitchen, delivery, manager, admin menu, dead-letter, gateway, role router, setup ×3, admin reservations tab) | p20 (+p19's ingested orders appear here) |
| **`p23_widgets`** (NEW) | **W-1..W-6 library components** (own red→green, 100% line coverage, same fleet laws; lands BEFORE p21/p22 consume them) | independent |
| **`p24_locale_toggle`** (NEW) | F-5 config `locale.default` + in-app language switcher | p18 |
| **`p25_generator_completeness`** (NEW) | F-8 warning pass + config theme-key completeness test | independent |

**Sequencing recommendation:** p23 (widgets) → p21/p22 (adoption 3 + staff) → p24 → p25; p17/p18/p19 can interleave as already planned. This closes all three holes with named owners.