# BATCH STATE-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W8.5, W8.7.**

## 22. BATCH STATE-2 - FAMILY STREAM PROVIDERS + UNCAPPED-QUERY CAPS

**Predecessor:** STATE-1 (or parallel, distinct files). **Emulator-gated:** rules emulator. **Master:** W8.5, W8.7.

### 22.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `kitchen_dashboard.dart:140-152, 300-315`, `manager_dashboard.dart:65-79`, `revenue_chart_widget.dart:25-34`, `admin_reservations_tab.dart:50-53` | Firestore streams constructed inside `build()` -> every rebuild re-subscribes -> spinner flash + listener churn | P1 (04-P1-STREAM / 03-P2-STREAM-BUILD) |
| P-2 | `admin_data_service.dart:238-241` | `streamOrdersByBranch` streams the ENTIRE branch order history live into the manager dashboard | P1 (04-P1-QUERY) |
| P-3 | `kitchen_service.dart:27-37`, `delivery_service.dart:28-58`, `merged_menu_provider.dart:120-141`, owner global menu stream | Uncapped live streams (menus, kitchen, driver, owner) | P1 (04-P1-QUERY) |

### 22.2 Solution - design principle + acceptance contract

**Design principle:** the repo's dominant convention is `StreamProvider.autoDispose.family` (precedents `delivery_dashboard.dart:15-22,196`, `order_tracker_screen.dart:11-14`); caps mirror existing in-repo precedents.

**Acceptance contract (from master W8.5/W8.7):**
1. Convert the 4 build-built stream sites to `StreamProvider.autoDispose.family` (key = branchId + statuses / branchId + window).
2. Named caps/windows beside precedents (`menu_repository.dart:16` style): manager history `streamOrdersByBranch` -> 24 h window + `orderBy('createdAt', descending: true)` + `limit(200)` (24 h precedent `admin_data_service.dart:70-73`); kitchen streams -> `orderBy('createdAt')` + `limit(200)`; driver streams -> `limit(100)`; menu streams -> reuse `kMenuMaxItemsSafetyCap=500`; owner global menu stream -> `limit(500)`.
3. Add any needed rules-harness cases so orderBy+limit queries remain provable.

### 22.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | ONE subscription per family key | Widget: tab-switch pumps -> single subscription per key (mock Firestore) |
| T-2 | `.limit` present per provider | Query-fixture corpus test asserting limit on each provider query |
| T-3 | Rules still provable | `npm run test:rules` green (orderBy+limit shapes) |
| T-4 | No loading-flash on rebuild | Widget: rebuild -> no `waiting` reset |

### 22.4 Proof gates

- [ ] T-1..T-4 green
- [ ] `npm run test:rules` green
- [ ] grep `.limit(` on the 5 provider queries present
- [ ] Universal Gate Set U (index Section 1)

### 22.5 Honest residuals

- Caps truncate pathological days (kitchen FIFO pairs `orderBy createdAt` with its cap; manager window drops older history - matching `streamOverviewStats` precedent). Documented, not a bug.
- The 24 h window is a product decision from the audit's precedent; if a client needs deeper history, pagination (owner-dashboard pattern) is the follow-up.

**END OF BATCH STATE-2 SPEC** - do not proceed until these gates pass and the STATE-2 addendum is appended to FIX_VERIFICATION.md.