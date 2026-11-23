# Fixture provenance (UI-9 / p19, law L5)

Every fixture in this directory mirrors a **documented** payload/response shape.
Where the platform's documentation is gated behind an approval program, the
fixture is a **best-effort** reconstruction and is marked `UNVERIFIED` — it is
NEVER presented as a captured real payload. `test/platform_ingestion.test.js`
asserts that each `*.json` file here appears in this table with a source and a
verification status (a fixture without provenance fails the suite).

| Fixture | Platform | Documented source | Status |
|---|---|---|---|
| `uber_eats_orders_notification.json` | Uber Eats | `developer.uber.com/docs/eats/guides/order_integration` — webhook `orders.notification` → Get Order Details (cited in `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` Track 3 §1) | best-effort (API access requires written approval → **UNVERIFIED**) |
| `uber_eats_order_details.json` | Uber Eats | same guide — the order document fetched after `orders.notification` (`cart.items[]`, integer minor-unit `amount` + `currency_code`) | best-effort (gated doc → **UNVERIFIED**) |
| `delivery_hero_order_push.json` | DeliveryHero (Talabat / HungerStation) | `developers.deliveryhero.com/documentation/pos.html` — Integration Middleware order push to an HTTPS plugin (order id, store id, products with options, 2-decimal currency strings) | best-effort (credentials/PGP are requested per-representative; doc gated → **UNVERIFIED**) |
| `malformed_order_push.json` | DeliveryHero | negative fixture — a documented field carrying the wrong type (the DLQ path) | synthetic (locally authored negative case, never a captured payload) |
| `platform_http_responses.json` | both | Catalog Import (DH) / Menu API (Uber) response envelopes: 2xx accepted, 409 conflict, 503 unavailable | synthetic (locally authored envelope from the documented status codes → **UNVERIFIED**) |
| `delivery_platforms_config.json` | n/a (our schema) | the L3 `deliveryPlatforms` config-section parity fixture shared by the Dart runtime validator, the generator mirror and the server selector | synthetic (our own locally authored schema fixture — not a captured payload) |