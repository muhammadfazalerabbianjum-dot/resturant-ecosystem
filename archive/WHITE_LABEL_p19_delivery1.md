# WHITE_LABEL_p19_delivery1 — UI-9: DELIVERY-PLATFORM ADAPTERS v1 — MAIN, SINGLE EXECUTOR

**Purpose:** build the per-client delivery-platform adapter layer — availability sync + webhook order ingestion — ready for credentials, on the fleet's proven fail-closed/idempotent machinery. v1 ships CODE + RUNBOOK; activation per client is an ops step (credentials are business-side). Research: `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` Track 3 (sources fetched: Uber Eats order-integration guide, DeliveryHero POS integration, Talabat developer portal, Deliverect/UrbanPiper).

## §0 Rules (inherited p10 §0 0.1–0.7 + fleet laws)

0.8 Main-only, single executor. 0.9 **Fail-closed security:** a platform webhook WITHOUT valid verification (per-platform signature/PGP scheme) is rejected + logged; no trust boundary shortcuts. 0.10 **Money authority preserved:** an ingested platform order is a DRAFT that goes through the existing server-side re-derivation path; platform totals are NEVER trusted (the PERF-8/PERF-10 pattern — platform pricing lives on the platform's ledger, ours on ours).

### Batch laws

L1 **Adapter contract, platform-agnostic:** `DeliveryPlatformAdapter` in `core` — `syncAvailability(dishes)`, `mapInboundOrder(payload) → OrderDraft`, `acknowledge/reject(status)` — so each platform is an implementation, and a client's config picks theirs (white-label DNA: we ship adapters; clients enable theirs).
L2 **Idempotency:** the idempotency key for an ingested order = the PLATFORM's order id (namespaced, e.g. `uber_eats:ORDER123`) — replays are no-ops, never double-orders (the PERF-8 W3 pipeline, LEDGER).
L3 **Config-gated:** `deliveryPlatforms` config section (per platform: id, enabled, credentialRef, storeId) validated fail-closed (W6.5 pattern: schema + parser + generator `validate()` mirror — the screen_variants/TOKENS pattern); disabled/absent = adapters inert.
L4 **No new dependencies; no secrets in code:** credentials via config/secret refs (Firebase env config), never literals.
L5 **Fixture-tested against DOCUMENTED payload shapes:** fixtures mirror the fetched public docs (Uber `orders.notification` example shape, DH order push shape); where a platform doc is gated, the fixture is labeled best-effort and marked UNVERIFIED — never presented as a captured real payload.
L6 **Order-source isolation + price-mismatch fail-closed:** every ingested platform order carries `orderSource: platform:<id>` — consumer order-history queries filter by user, so platform orders NEVER appear in a client app user's own list; kitchen dashboards DO see them. Re-derivation compares platform line items against OUR menu prices; any mismatch routes to the platform's fulfillment-issue/deny flow (fail-closed) — an order is never persisted with prices we cannot re-derive.

## §1 Baseline (P1/receipts)

- Idempotency pipeline + concurrency proofs: LEDGER:PERF-8 W3; money authority: server-side re-derivation + tamper denial (LEDGER:PERF-10, 26/26 mutants on the money path); App Check enforced (PERF-10).
- No platform integration exists today. Config surfaces: `client_config.json` (validated, W6.5 schema gate, generator mirror pinned by `whitelabel_schema_identity_test.dart`).
- Platform facts (external, fetched — see research doc): Uber Eats written-approval gate + webhook/accept/deny/menu APIs; DeliveryHero plugin model (PGP credentials, HTTPS plugin, Indirect/Direct flows, Catalog Import API); Talabat Partner API + SFTP option.

## §2 Territory (exclusive)

NEW: `packages/core/lib/src/delivery/` — `delivery_platform_adapter.dart` (contract), `platform_config.dart` (typed config + validation), `ingested_order.dart` (draft mapping incl. `orderSource`)
NEW: `core_app/functions/src/` — the established FLAT layout (P1: `index.ts`, `payment.ts`, `access.ts`, `ddos.ts` are siblings): `platform_ingestion.ts` (verify → idempotency → draft → re-derive → persist), `platform_availability.ts` (adapter-driven push), `platform_mappers/` (per-platform mappers `uberEats.ts`/`deliveryHero.ts`, fixture-shaped)
NEW: config keys in `core_app/lib/app/config/**` (parser + schema) + `core_app/tool/whitelabel.dart` `validate()` mirror (the W6.5 pattern) · config schema fixtures/tests
NEW: fixtures + tests (`functions/**/test/**` per the functions test layout) · `tool_uilib/p19/**` incl. `RUNBOOK_DELIVERY_PLATFORMS.md`
FORBIDDEN: `FIX_VERIFICATION.md`, theme/**, `pubspec.*` deps (functions/package.json deps frozen — use existing runtime), money-derivation logic files (call the existing re-derivation, never fork it), apps/**.

## §3 T-x table

| Task | Deliverable | Acceptance |
|---|---|---|
| T-1 | `DeliveryPlatformAdapter` contract in `core` (`platform_config.dart` typed + validated: id ∈ documented vocabulary, enabled, credentialRef, storeId; unknown platform id = violation) | Red→green config-validation tests (present-but-invalid = violation at exact JSON path; absent = inert — the screen_variants STRICTLY-WHEN-PRESENT pattern); generator `validate()` mirror test stays pinned (`whitelabel_schema_identity_test.dart` extended). |
| T-2 | `ingestPlatformOrder` HTTPS function: (1) per-platform verification (signature scheme per platform docs — DH PGP/HMAC, Uber webhook verification; unverified ⇒ reject + audit log), (2) idempotency key = `platform:orderId` (L2), (3) map via adapter to `OrderDraft`, (4) server-side re-derivation via the EXISTING money-authority path, (5) persist + accept/reject callback per platform protocol, (6) failure → DLQ (existing dead-letter pattern) | Fixture-driven red→green per platform: valid payload → order draft persisted + ack; replay → no-op; bad signature → 4xx + log; out-of-stock item → fulfillment-issue/deny path; malformed → DLQ. Fixtures labeled per L5 (documented shapes; gated docs = best-effort + UNVERIFIED). |
| T-3 | `syncMenuAvailability` function: dish availability changes (existing triggers) → adapter → platform catalog API shape (DH Catalog Import / Uber Menu API payload shapes) | Red→green with fixture HTTP responses (mocked client seam); fail-safe: platform unavailable ⇒ retry/DLQ, never blocks the app's own availability writes. |
| T-4 | `RUNBOOK_DELIVERY_PLATFORMS.md`: per-platform credential acquisition (DH = local representative + PGP key request; Uber = written approval + sandbox; Talabat = portal access), go-live checklists (incl. DH's post-production maintenance-agreement + SLA clauses quoted), test plans (Uber's documented sandbox flow: test store → test order → webhook → accept/deny), client-enablement steps (config keys) | Self-verifying markers (RUNBOOK_DEPLOY precedent); each platform section cites its fetched source. |
| T-5 | App-Check/verification boundary documentation: platform webhooks are server-to-server (no App Check token) — the function's own signature verification IS the boundary; App Check stays enforced for app traffic | Design note in the report + a test proving unverified external calls are rejected. |

## §4 Deliverable

`tool_uilib/p19/p19_report.md`: per-T evidence; fixture provenance table (which fixture = which documented source); six-way classification; DECISIONS-NEEDED-FROM-OWNER (which platform/contract to pursue first — recommendation: DeliveryHero program, one agreement → Talabat + HungerStation); UNVERIFIED (non-empty allowed: live round-trips need real credentials — production/ops class, DEEP_PROOF §4.2 pattern); DRIFT; paste-ready `## APP COMPLETION UI-9 (p19)` block.

## §5 Acceptance

- functions lint + tsc + tests green (existing 79+ → new, 0 skip) · analyze ×3 exit 0 · format root 0 · suites core_app/core/core_ui/shell green 0 skip, no drop · coverage floors (new files 100% lines) · greps 0 · config-validation red→green receipts · forbidden paths 0 · schema-identity test (generator mirror) green.

## §6 Judge + close

Coordinator re-runs gates; spot-checks ≥3 (replay idempotency, bad-signature rejection, re-derivation call — the platform totals are never trusted); appends the ledger block. Honest UNVERIFIED: live platform round-trips await credentials (ops); documented as the deploy-day/ops class.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-9 (p19), delivery-platform adapters v1, MAIN ONLY.
Read <repo>\WHITE_LABEL_p19_delivery1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + L1-L5.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts (functions 79+ baseline). BLOCKER: functions lint+tsc+test + analyze x3 + format + suites green 0 skip BEFORE any edit. Failure => STOP.
2. RED: config-validation tests (unknown platform id fails closed) + ingestion fixture tests (replay no-op, bad signature rejected) — capture to tool_uilib/p19/red_suite.txt.
3. GREEN: T-1 contract + config keys (parser + schema + generator validate mirror); T-2 ingestion function (verify -> idempotency -> draft -> re-derive via EXISTING path -> persist -> ack/reject -> DLQ); T-3 availability sync (mocked client seam).
4. T-4 RUNBOOK_DELIVERY_PLATFORMS.md (per-platform credentials, go-live, SLA clauses, client enablement).
5. GATES: functions battery + analyze x3 + format + suites 0 skip; coverage floors; greps 0; forbidden paths 0 (functions/package.json deps FROZEN).
6. REPORT: tool_uilib/p19/p19_report.md per §4 (fixture provenance table, six-way, UNVERIFIED, DECISIONS, DRIFT, paste-ready UI-9 ledger block). NEVER touch FIX_VERIFICATION.md.
7. COMMIT + full battery on the tip; push only if credentials cached.
DoD: §5 green + report + receipts + green committed tip + nothing uncommitted.
```

**END OF UI-9 SPEC.**