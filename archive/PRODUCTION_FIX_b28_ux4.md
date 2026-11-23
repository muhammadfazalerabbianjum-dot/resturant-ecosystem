# BATCH UX-4 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W9.12.**

## 28. BATCH UX-4 - ANALYTICS FUNNEL + DEAD ANALYTICS METHODS

**Predecessor:** UX-3 (consent wired so funnel is meaningful). **Emulator-gated:** no. **Master:** W9.12. **MIRROR: analytics are `packages/core` shared - shell inherits.**

### 28.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `packages/core/lib/src/analytics/analytics_service.dart` | 13 typed methods, ZERO call sites in production code; `FirebaseAnalyticsObserver` count = 0 | P1 (07-P1-7) |
| P-2 | `packages/core/lib/src/analytics/telemetry_service.dart` | 6 funnel events, 1 call site (`login_screen.dart:69`) - begin_checkout/checkout_abandon/order_completed never emitted | P1 (07-P1-7) |
| P-3 | both stacks | No failure events (`order_failed`, `payment_declined`, `offline_queue_depth`) | P1 (07-P1-7) |

### 28.2 Solution - design principle + acceptance contract

**Design principle:** the checkout funnel must be visible; one facade; delete-or-wire every dead method.

**Acceptance contract (from master W9.12):**
1. Wire `TelemetryService` events at the funnel boundaries: `begin_checkout` (checkout open), `checkout_abandon` (PopScope-blocked exit/payment fail), `order_completed` (createOrder success), + failure events `order_failed`, `payment_declined`, `offline_queue_depth`.
2. Register `FirebaseAnalyticsObserver` on the ACTIVE router.
3. Wire-or-DELETE the 13 dead `AnalyticsService` methods (decision: DELETE unused, keep `logOrderPlaced`/`logOrderCancelled`/`logAdminAction` wired where natural).
4. Single facade: `TelemetryService` delegates to `AnalyticsService` where both exist (P3-4).

### 28.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Funnel events have call sites | Reverse grep: each event method referenced in lib |
| T-2 | No dead self-references | grep: deleted methods absent |
| T-3 | Observer registered | Code read: `FirebaseAnalyticsObserver` on the router |
| T-4 | Facade delegates | Unit: Telemetry call -> Analytics call recorded |

### 28.4 Proof gates

- [ ] Reverse-grep: funnel events wired (T-1)
- [ ] `flutter analyze` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 28.5 Honest residuals

- Analytics events are fire-and-forget; a failure to emit must never break the checkout path (wrap in `unawaited` + try/catch-log, never throw).
- Consent gating stays client-side (UX-3); server-side uid-consent enforcement in `logFunnelEvent` is a recorded backlog item (master section 13).

**END OF BATCH UX-4 SPEC** - do not proceed until these gates pass and the UX-4 addendum is appended to FIX_VERIFICATION.md.