# RESEARCH — Analytics · Arabic (RTL) · Delivery-Platform Integration

**Method:** in-repo receipts first (P1 file:line), then primary external sources fetched this session (each quoted). Owner directive: best possible methods only, nothing suboptimal.

## Track 1 — Client analytics (dwell-time dishes, abandoned carts, more)

**Where we stand (P1):** Firebase Analytics already wired — `packages/core/lib/src/analytics/analytics_service.dart` + `telemetry_service.dart`, observer in `app_bootstrap.dart` (UX-4 named-route screen views). GDPR analytics-consent gate exists (`kGdprAnalyticsConsentKey`, W9.8) — analytics is consent-gated BY DESIGN already. Admin-gated routes + our own StatTile/SectionHeader/BrandCard components = the dashboard can be built with our library.

**Findings (sourced):**
1. **Adopt GA4's canonical ecommerce event vocabulary** — `firebase.google.com/docs/analytics/measure-ecommerce` (fetched): `view_item`, `add_to_cart`, `begin_checkout`, `add_payment_info`, `purchase`, `refund` with `items[]` (item_id, item_name, price, quantity) + `currency`/`value`/`coupon`/`transaction_id`. The Flutter SDK ships typed helpers (`FirebaseAnalytics.instance.logAddPaymentInfo(currency: …, items: […])`). Standard vocabulary = free funnels + BigQuery SQL patterns + no bespoke taxonomy to maintain.
2. **Dwell time per dish** — GA4 records `engagement_time_msec` with events automatically; `view_item` on the dish screen yields per-dish engagement time in GA4/BigQuery without custom timers (custom `dish_dwell` event only if sub-second precision is ever needed).
3. **Abandoned carts** — the funnel is `add_to_cart → begin_checkout → purchase`; abandonment = sessions with `add_to_cart`/`begin_checkout` but no `purchase`, decomposable BY ITEM because the `items[]` array rides on all cart events → "dishes most common in abandoned carts" is a BigQuery GROUP BY on `items.item_id`.
4. **BigQuery export** is the standard raw-data path (GA4 → BigQuery, configurable) → SQL for per-client questions; aggregate roll-ups scheduled into Firestore for cheap reads; Looker Studio or an admin screen for visuals. Known limits: custom params ≤ 25/event, names ≤ 40 chars, values ≤ 100 chars; daily export freshness.
5. **Privacy posture:** consent gate already exists; dishes referenced by id (no personal data in item fields); App Check already enforced. GDPR erasure flow already covers user identity.

**Recommended build:** spec `p17_analytics1` = (a) event taxonomy + instrumentation in dish/cart/checkout flows (typed helpers, consent-gated), (b) BigQuery export enablement + funnel SQL for abandoned-cart dish ranking, (c) `/admin/analytics` screen built FROM our library components reading pre-aggregated Firestore docs.

## Track 2 — Arabic for a Gulf/Middle East client (two languages)

**Where we stand (P1):** real ARB pair — `core_app/lib/l10n/app_ar.arb` (45.6 KB, LARGER than `app_en.arb` 36.1 KB — genuine Arabic content, not stubs); en+ar parity tests (W9 l10n batches); `ClampedTextScale` a11y; typography tokens (b10) accept per-client `headingFont`/`bodyFont` — an Arabic family (e.g. Cairo/Tajawal/Almarai via the already-present `google_fonts` dep) is a CONFIG value, not a code change.

**Findings (sourced):**
1. **Arabic plurals are SIX-form, not two** — CLDR Language Plural Rules chart (unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html, `ar` row fetched): **zero (n=0) · one (n=1) · two (n=2) · few (n%100 = 3–10, also 103–110 …) · many (n%100 = 11–99) · other** (everything else incl. fractions). English has two. Any ARB string rendering "N dishes/orders/items" as a two-form plural is grammatically wrong for parts of the range. **Action:** audit every numeric message to six-way ICU plurals; upgrade the parity test to require complete plural forms for `ar`.
2. **RTL:** Flutter mirrors layouts automatically from the locale's direction (Directionality from the resolved locale; `MaterialApp` + localizationsDelegates; ARB `@@locale`). Real risks are hand-coded LTR assumptions: `Alignment.centerLeft`, `EdgeInsets.only(left:)`, asymmetric swipe/padding, custom painters. **Action:** RTL audit sweep + RTL golden variant (pump under RTL Directionality) per wired screen — pairs with p16's golden infra.
3. **Digits & currency:** CLDR `ar` uses Arabic-Indic digits (٠١٢) in several regions while others use Latin; `formatCurrencyCents` is locale-AGNOSTIC today (fixed symbol list, Latin digits). Gulf clients need "SAR 12.50"-style locale-aware rendering. **Action:** locale-aware currency formatting (`intl` `NumberFormat.currency`) as a specced fix; SAR/AED/KWD symbol rules per CLDR.
4. **Mixed-direction text:** Latin dish names inside Arabic sentences (ubiquitous in Gulf menus) — Unicode bidi handles most; boundary punctuation/parentheses need review. **Action:** native Arabic review of `app_ar.arb` once (CLDR's minimal-pairs philosophy implies vetted strings, not just parity); machine parity ≠ native quality.
5. **Dates:** Gregorian is default; Hijri is a per-client option only if demanded (extra package) — record, don't build speculatively.

## Track 3 — Delivery-platform integration (per-country brands)

**Where we stand (P1):** NO platform integration today; but the hard prerequisites already exist from the fleet: Cloud Functions money-authority pattern (server-side re-derivation), **idempotency-key pipeline** (PERF-8 W3), App Check, fail-closed rules, feature flags + per-client config, kitchen/order dashboards.

**Findings (sourced):**
1. **Uber Eats** — developer.uber.com/docs/eats/guides/order_integration (fetched): *"Access to These APIs May Require Written Approval From Uber."* Once approved: webhook `orders.notification` → `Get Order Details` → **Accept/Deny within the required time window**; Menu API (`Retrieve/Upsert Menu`, webhook `store.menu_refresh_request`); store status/holiday-hours; documented sandbox testing (test store → test order → webhook → accept/deny).
2. **DeliveryHero POS Integration** — developers.deliveryhero.com/documentation/pos.html (fetched): one program covers **Talabat (Kuwait, UAE, Bahrain, Oman, Qatar, Jordan), HungerStation (Saudi), foodpanda, PedidosYa, foodora, eFood…** — the dominant Gulf brands behind ONE integration. Flow: request credentials (PGP-encrypted) → build an HTTPS "Plugin" → Integration Middleware forwards orders (Indirect flow: their Vendor App accepts first) → **Catalog Import API** for menu/availability sync (legacy Menu Import API deprecated — new implementations barred). SLAs enforced: "The integration might get disabled by Delivery Hero whenever there is a technical issue… and provided contact is not responding."
3. **Talabat's own developer portal** — developer.talabat.com (fetched): Partner API (Catalog, Promotions, Orders via Partner Picking or their Pelican device app) + an **SFTP low-lift option** ("faster to launch — standardized file templates"); "One connection for multiple services."
4. **Middleware aggregators** — Deliverect ("**1000+ integrations**", "Powering ~7% of food delivery worldwide", dedicated Middle East site) and **UrbanPiper** ("Swiggy, Zomato, UberEats, **Talabat** and others… from your existing POS", "40,000+ restaurants", sites for **Saudi Arabia, UAE, Kuwait, Qatar, Bahrain, Egypt**, Arabic UI). These exist precisely because platform-by-platform integration is heavy — one commercial agreement covers many markets.

**Recommended architecture (the "different per client" answer):** a **per-client adapter layer**, config-gated:
- `DeliveryPlatformAdapter` contract in `core`: availability sync (dishes → platform catalog), order ingestion (platform webhook → Functions → **idempotency key = platform order id** → server-side re-derivation → Firestore order → existing kitchen dashboards), status updates.
- Per-client config (existing `features`/config pattern) enables the client's dominant platform with their credentials. White-label DNA: WE ship adapters; CLIENTS switch theirs on.
- **Sequencing (nothing suboptimal, nothing premature):** v0 link-out/marketplace-native menus (zero code), v1 availability-sync only (Talabat claims integrated partners see ~3.5× fewer out-of-stock failures), v2 order ingestion for the ONE platform that dominates the client's country, v3 aggregator (Deliverect/UrbanPiper) for multi-platform clients. Each step is a spec-driven batch with our fail-closed/idempotent machinery.

## Track 4 — Other suggestions (owner-decision menu)

1. **WhatsApp ordering/notifications** (Business API) — the dominant comms channel in MENA; natural per-client config opt-in.
2. **Local payment methods** — Stripe supports country-specific methods (mada in KSA, Apple Pay widely); payment localization per client country.
3. **Analytics dashboard dogfooding** — build `/admin/analytics` with our own library (StatTile, SectionHeader, BrandCard) — proves the library in-product while shipping the analytics feature.
4. **Hijri date option** — config-gated per client only if requested.
5. **Housekeeping:** the 212-file `tool_perf2/**` untracked litter → receipts branch or delete (owner call).

## Suggested spec queue

`p17_analytics1` (events + BigQuery + dashboard) → `p18_arabic_hardening` (six-form plurals, RTL audit + goldens, locale currency) → `p19_delivery_adapters_v1` (availability sync for ONE platform, webhook ingestion on the idempotency pipeline) → `p20_adoption2` (admin/staff screens). Each runs the same spec-driven cadence; p16 (customer-core adoption) should land first so the dashboard and analytics screens are built on wired, proven components.