# P5 EMPIRE LAYER — DECISION-COMPLETE BACKLOG (FROZEN 2026-11-12)
Owner rulings: Tier 1 + Tier 2 committed EXCEPT aggregators (deferred). Marketing = PUSH ONLY (FCM).
Attendance = clock-in geofence + branch-device PIN. No continuous tracking. No aggregator builds.
## MoSCoW
MUST: M1 Accountant Corner, M2 Stats Corner, M3 Clock-in/out, M4 Smart Alerts, M5 Review Corner,
M6 Marketing Corner (push-only, 5 automations). SHOULD: S1 Labor forecast (deterministic v1).
WON'T (frozen): aggregator/platform integrations; AI phone answering; dynamic pricing; continuous
employee location; SMS/WhatsApp channels (later adapters, same ConsentGate); non-actionable
"AI suggestion" dashboards.
## STANDING ADRs FOR P5
ADR-P5-0: every P5 feature reads ONLY derived data (daily_rollups, transactions, order_events,
staff_shifts, stock_moves); zero features touch the hot orders path or money logic; all are
client-read-only or callable-gated; nothing widens the rules write surface.
ADR-P5-1: every outbound customer message passes ONE ConsentGate(capability, consentRecord,
quietHours, weeklyRateLimit) — server-side, no bypass path. Consent = explicit in-app marketing
opt-in with timestamp + source on the customer profile; opt-out instant (in-app + deep-link in every
message), server-authoritative.
ADR-P5-2: location evidence is clock-in-event-only (coords + geofence verdict logged once).
Continuous tracking is structurally absent: no listener, no schema field, no permission request.
ADR-P5-3: forecasts/suggestions are ADVISORY; nothing auto-publishes schedules, prices, campaigns.
ADR-P5-4: exports/reports derive from the LEDGER (single source of truth), never from orders.
ADR-P5-5: every P5 collection follows the tenancy law (tenantId + tenantOk + registry row + gate j
case); alerts/exports are client write-denied, Admin SDK writes only.
## FEATURES (build order within P5)
M4 SMART ALERTS (first; everything reuses its dispatch): CF listeners on order_events/stock_moves →
auto-86 at zero stock, low-stock threshold, order delay > tenant-configured minutes, cash variance
at Z-report, overtime/no-show (with M3). Dispatch = FCM to tenant-scoped owner/manager tokens.
Dedupe + rate-limit per alert-type/day. alerts: client write-denied, acknowledgedAt/By.
M1 ACCOUNTANT CORNER: scheduled monthly + on-demand owner callable → QBO/Xero-compatible CSV of
ledger rows, tax summary by rate, Z-report reconciliation (till vs ledger variance). Cloud Storage
per tenant, signed URL, owner-only. Re-run = byte-identical (pure derivation, tested).
M2 STATS CORNER: owner dashboard extensions — 30/90-day time series (rollups), channel mix, item
profitability (price vs P4 recipe cost), staff-vs-sales (staff_shifts). Responsive 390/1024 px.
M3 CLOCK-IN/OUT: clockIn/clockOut callables (capability shift.clock). Proof-of-presence = ALL of:
App Check + caller branchId == target branch; per-staff PIN (server-hashed, brute-force capped);
optional geofence check at clock-in ONLY (coords sent once, server validates vs branch radius,
verdict logged as evidence). Overtime + no-show flags feed M4. Extends staff_shifts (P3).
M5 REVIEW CORNER: post-completion (+2h) one push, 1–5 stars. 4–5 → Google review deep link;
1–3 → private feedback → owner alert. Max one prompt per order; ConsentGate applies; never
incentivized (Google policy). Feedback lands in alerts, owner-only readable.
M6 MARKETING CORNER (last in P5 — most compliance surface): 5 automations, tenant-configurable,
trigger engine = daily scheduled CF + order_events listeners: win-back (≥2 lifetime orders, 30d
lapsed), birthday (profile DOB), first-order thank-you (+24h), loyalty milestone, slow-day promo
(tenant sets day + offer). Channel v1 = FCM push only (tokens already tenant-scoped). Per-customer
weekly cap + local quiet hours + ConsentGate. Templates per tenant (name/offer slots); all fixed UI
strings in both .arb locales. Measurement: campaignId in push payload → attributed order via
order_events within 72h → results in Stats Corner. One-tap launch/pause per automation.
S1 LABOR FORECAST: deterministic weekday/hour averages from ≥8 weeks of rollups → suggested staffing
per daypart (owner-configurable ratios) + overtime flags. No ML. Advisory only (ADR-P5-3).
## P5 ACCEPTANCE (per feature, all test-mapped)
Every feature: tenancy gate-j case ACTIVE; functions coverage ≥90% on new code; both locales.
M1: export byte-identical on re-run; variance report catches a seeded discrepancy.
M3: wrong-branch denial; wrong-PIN lockout; geofence-fail logged not blocked (owner-configurable);
no location field anywhere in schema — grep-provable.
M6: ConsentGate negative suite (no-consent denied; post-opt-out denied; quiet-hours deferred; cap
suppressed) — every automation × every rule; attribution test with seeded order; opt-out latency
< 1 send-cycle.
M5: one-prompt-per-order idempotency; negative feedback never reaches the Google link.
DONE WHEN per card = feature + negative tests + zero stubs + gate.cmd green + commit.

---

# P6 CANDIDATES — owner-listed 2026-11-13 (NOT authorised, NOT scheduled)

Recorded verbatim in intent, with the standing law each one must satisfy. These
are candidates the owner asked to keep; they do **not** amend the P5 freeze and
none is a commitment until it becomes a card in `ROADMAP.md` with an acceptance
criterion.

1. **Daily Owner Digest (S — owner wants it early).** 7am WhatsApp/email to the
   owner: "Yesterday: 47 orders, $1,240, top item: short ribs, 2 staff late, 1
   item 86'd." Pure rollups → a scheduled message.
   *Constraint:* numbers come from the ledger/rollups (ADR-P5-4), never from a
   recount of orders. Email/WhatsApp is an **outbound channel** — ADR-P5-1's
   ConsentGate governs customers; an owner digest is a different consent surface
   (the owner's own number) and must be designed as such, not bypassed. A
   provider is an external service: RESEARCH DRAFT → owner approval → verify →
   build (handoff §5). Message copy is owner-only.
2. **Halal/dietary trust layer (S — owner wants it early).** Certification
   badges, allergen filters, cross-contamination notes on the menu.
   *Constraint:* menu metadata on the existing `menus` documents — no new
   collection, no client-writable badge (owner/admin writes only, `tenantOk`
   already covers the collection). Nothing here touches money.
3. **Kiosk mode (S–M).** The counter iPad in fullscreen self-order.
   *Constraint:* depends on the shell and Counter/POS (P2-1a/P2-1); same
   `createOrder` callable, no new money path; a kiosk session must not reach any
   admin surface (`RoleGate` stays).
4. **Google Business Profile "Order" link (S).** Point the free listing's order
   button at the client's own app.
   *Constraint:* it is a **link**, not a marketplace integration — the P5 freeze
   on aggregators is untouched. The listing is the owner's identity: they change
   it in Google's console; we supply the URL and the claim.
5. **Arabic/Urdu localisation (S for Gulf).** Customer app + kitchen screens in
   the owner's language.
   *Constraint:* `ar` already exists; `ur` is a new locale and is RTL — it must
   enter the l10n parity gate (en/ar/ur), not ship as a second hardcoded table.
6. **Waitlist/reservations (M — later, dine-in clients only).**
   *Constraint:* the app already has `WaitlistScreen` and `AdminReservationsTab`;
   the work is depth, not a build from zero. Owner explicitly deprioritised it
   until there are dine-in-heavy clients.
7. **Offline mode for the POS (M — Canada).** Queue-and-sync when the internet
   drops.
   *Constraint:* this is the one item that needs the browser cache seam the shell
   deliberately does not have (D-049/P2-1). It is safe to queue creates **because**
   the ledger row id is derived (`sale_<orderId>`, D-030): replaying a queued
   create cannot double the ledger. Any queue design that mints its own ids
   would break that, so that is the invariant to pin first.

## P6-1 follow-ups — registered 2026-11-14, NOT authorised

Both came out of the P6-1 card (`checkpoints/P6-01-MODEL-UI.md`) and are listed
so they cannot be lost or silently assumed.

1. **tags→codes backfill (needs owner consent).** D-054 removed the tag-based
   `Vegan` chip in favour of the `dietary` claim, so items whose only vegan
   marker is the free-text `tags: ['vegan']` string are no longer reachable via
   the chip. The fix is a one-off, idempotent migration that reads each `menus`
   document, maps recognised tag strings to vocabulary codes, and writes
   `dietary` — **it rewrites stored documents, so it is owner-authorised work,
   never a code change bundled into a later card.** Any mapping must be
   conservative: an unmapped tag is left alone and reported, never guessed.
2. **Certification expiry reminder (owner-visible).** An expired halal claim
   stops rendering (correct, fail-closed) but nothing tells the owner it lapsed;
   they only see `halalClaimExpired` when they reopen the item. A reminder is an
   outbound channel and therefore subject to ADR-P5-1's consent surface — decide
   the channel before building anything.
