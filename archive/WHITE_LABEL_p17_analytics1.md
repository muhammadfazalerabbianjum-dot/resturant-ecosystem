# WHITE_LABEL_p17_analytics1 — UI-7: CLIENT ANALYTICS (events + dashboard) — MAIN, SINGLE EXECUTOR

**Purpose:** the owner's analytics feature — dish engagement, abandoned-cart funnels, top dishes — on GA4's canonical ecommerce vocabulary, surfaced in an admin dashboard built from our own library. Research: `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` Track 1 (source fetched: Firebase GA4 ecommerce docs).

## §0 Rules (inherited p10 §0 0.1–0.7 + fleet laws)

0.8 Main-only, single executor. 0.9 **Consent-gated by construction:** every new analytics call is a no-op unless GDPR analytics consent is granted (`kGdprAnalyticsConsentKey` — the existing W9.8 gate; L1). 0.10 **No PII, no money math:** events carry dish ids/names and cents-derived values only; totals are read from providers/orders, never recomputed (L2 lineage).

L1 **Consent gate in ONE place — RECEIPTED LOCATION:** the gate already exists and is fail-closed: `telemetry_service.dart:59` reads `kGdprAnalyticsConsentKey ?? false` (P1, verified this session). New ecommerce events MUST route through that same gated telemetry path (or read consent identically at the single service point) — the red→green consent test (consent=false ⇒ ZERO calls) proves it. Call sites stay gate-free. **Predecessor: UI-6 (p16) merged** — p16 owns the menu/cart/dish/checkout presentation files this batch adds event lines to.
L6 **Event vocabulary coexistence:** existing `logOrderPlaced` (checkout_screen call site, P1) REMAINS the internal lifecycle event; the new GA4 `purchase` event is the ecommerce-standard layer with `items[]`. Both fire from the same order-success point; the taxonomy table documents the pairing — no replacement, no double-meaning. Test seams already exist (`core_app/test/core/analytics/analytics_service_test.dart`, `telemetry_service_test.dart`) and are extended, not recreated.
L2 **Zero money math:** `value` params read from order/cart models (integer cents → double for GA4); formatting untouched.
L3 **GA4 limits respected:** ≤ 25 params/event; lowercase_snake event names; param names ≤ 40 chars; values ≤ 100 chars — the §3 taxonomy is the enforcement, pinned by a unit test.
L4 **No new dependencies** (firebase_analytics present; BigQuery/Looker are console/ops, not code).
L5 **Fail-safe dashboard UI:** loading → skeleton, error → degrade (GlobalErrorWidget/EmptyStateWidget patterns), never throw on missing aggregates.

## §1 Baseline (P1, verified this session)

- `AnalyticsService` today has exactly `logOrderPlaced`, `logOrderCancelled`, `logAdminAction` — the ecommerce set is purely additive.
- Dashboard exists: `features/admin/presentation/analytics_snapshot.dart` — `RoleGate({owner, manager})`, `analyticsProvider` (todaysOrders, todaysRevenue), hand-built Texts + `revenue_chart_widget.dart` + `top_items_chart_widget.dart`. p17 upgrades THIS surface (not a from-scratch build).
- Firebase Analytics observer on named routes (UX-4) active; GDPR consent key active; `cloud_firestore ^6.3.0` (aggregate queries available).

## §2 Territory (exclusive)

MODIFIED: `packages/core/lib/src/analytics/analytics_service.dart` (+ its test fake/seam) · event call sites: `core_app/lib/features/menu/presentation/{dish_detail_screen,menu_screen}.dart`, `cart_screen.dart`, `checkout/**` (coordinates with p16 — p16 owns the presentation rewrite, p17 adds ONLY the event lines or lands after p16) · `core_app/lib/features/admin/presentation/analytics_snapshot.dart` + `analytics_provider.dart`
NEW: `packages/core/lib/src/analytics/ecommerce_events.dart` (typed params) · tests per touched file · `core_app/tool/analytics_funnel_queries.sql` · `tool_uilib/p17/**` (incl. `RUNBOOK_ANALYTICS.md`)
FORBIDDEN: `theme/**`, `FIX_VERIFICATION.md`, `pubspec.*`, money/logic providers, `functions/**` (no roll-up function in v1), rules, `apps/**`.

## §3 T-x table

| Task | Deliverable | Acceptance |
|---|---|---|
| T-1 | Ecommerce taxonomy in `AnalyticsService` (consent-gated): `logViewItem(dish)`, `logAddToCart(dish)`, `logBeginCheckout(cart)`, `logAddPaymentInfo`, `logPurchase(order)` (transaction_id = order id) — each with `items[]` (item_id, item_name, price, quantity) + `currency`/`value`; typed params in `ecommerce_events.dart` | Red→green with a consent fake: consent=false ⇒ **zero** analytics calls (the L1 proof); consent=true ⇒ exact event name + params asserted per the GA4 docs; L3 limits pinned by a unit test over the taxonomy table. |
| T-2 | Call-site instrumentation: dish_detail → view_item (GA4 auto-attaches engagement time — the dwell-time source, documented inline); menu add-to-cart → add_to_cart; checkout start → begin_checkout; payment step → add_payment_info; order success → purchase; existing `logOrderCancelled` kept | Call sites use the typed API; existing feature suites green; l10n untouched; event lines coordinated with p16 (land after or additive-only). |
| T-3 | Abandoned-cart funnel SQL: `core_app/tool/analytics_funnel_queries.sql` — sessions with add_to_cart/begin_checkout and NO purchase, dish ranking by `items.item_id` count (GA4 BigQuery export schema: `event_params`, `items` repeated field) | SQL written against the documented export schema; committed as the operator query set; each query header states the business question it answers. |
| T-4 | `tool_uilib/p17/RUNBOOK_ANALYTICS.md`: GA4→BigQuery link steps, export schedule + daily-freshness note, Looker Studio optional path, data-limit notes (L3), consent-gate reminder (analytics only fires post-consent) | Runbook self-verifying (grep-able step markers, RUNBOOK_DEPLOY precedent). |
| T-5 | Dashboard upgrade: `analytics_snapshot.dart` → `StatTile` (todaysOrders, todaysRevenue) + `SectionHeader` sections (charts kept); NEW per-dish order counts via a Firestore **aggregate** query (cloud_firestore 6.3 `aggregate`) rendered as `StatTile` rows; abandoned-cart section links to the BigQuery/Looker console (deep-link constant) with an honest "external data, daily freshness" note | Red→green with a fake aggregate; RoleGate({owner, manager}) preserved; visual floor per p16 L12 (tokens, Gap, skeleton loading, 48 dp); l10n strings via ARB. |

## §4 Deliverable

`tool_uilib/p17/p17_report.md`: per-T evidence; six-way classification; DECISIONS-NEEDED-FROM-OWNER (GA4 property/BigQuery wiring is operator console work); UNVERIFIED (non-empty allowed — the live GA4 round-trip and BigQuery export are production/ops-only); DRIFT; paste-ready `## APP COMPLETION UI-7 (p17)` block.

## §5 Acceptance

- `flutter analyze --fatal-infos` (core_app + core_ui) · `dart analyze` (core) exit 0 · format root 0 · suites core_app/core/core_ui/shell/rules/functions green **0 skip**, counts recorded at SYNC, no drop · consent-gate red→green receipt · new-file coverage 100% lines · greps 0 · l10n parity green · forbidden paths 0.

## §6 Judge + close

Coordinator re-runs gates; spot-checks ≥3 (the zero-call consent proof, a purchase-event params snapshot, dashboard RoleGate + aggregate fake); appends the ledger block. Honest UNVERIFIED carried: live GA4/BigQuery round-trip happens at deploy-day/ops with owner console access.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-7 (p17), analytics events + dashboard, MAIN ONLY.
Read <repo>\WHITE_LABEL_p17_analytics1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + L1-L5.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts. BLOCKER: analyze x3 + format + suites (core_app/core/core_ui/shell/rules/functions) green 0 skip BEFORE any edit. Failure => STOP, evidence table.
2. RED: consent-gate test (consent=false => zero calls) + taxonomy-limits test + dashboard aggregate test — capture to tool_uilib/p17/red_suite.txt.
3. GREEN: T-1 taxonomy (typed, consent-gated, single-gate), T-2 call sites (coordinate with p16), T-5 dashboard upgrade (StatTile/SectionHeader + Firestore aggregate; RoleGate preserved; visual floor); dart fix; format; suites green 0 skip; analyze 0.
4. T-3 funnel SQL file + T-4 self-verifying runbook.
5. GATES + COVERAGE: new files 100% lines; greps 0; l10n parity; forbidden paths 0.
6. REPORT: tool_uilib/p17/p17_report.md per §4 (six-way, UNVERIFIED non-empty allowed, DECISIONS, DRIFT, paste-ready UI-7 ledger block). NEVER touch FIX_VERIFICATION.md.
7. COMMIT + battery on the tip; push only if credentials cached.
DoD: §5 green + report + receipts + green committed tip + nothing uncommitted.
```

**END OF UI-7 SPEC.**