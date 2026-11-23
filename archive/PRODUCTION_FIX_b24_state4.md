# BATCH STATE-4 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W8.9, 03-P3, 02-P2.**

## 24. BATCH STATE-4 - PERF/STATE P2 BATCH + ISAR VERSIONING

**Predecessor:** STATE-3. **Emulator-gated:** no. **Master:** W8.9, 03-P3, 02-P2.

### 24.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `isar_service.dart:19` + `main.dart:245` | Double-open race (constructor + explicit openDB concurrently; loser swallowed) | P2 (04-P2-1) |
| P-2 | `home_screen.dart:33-39,70` | `IndexedStack` eagerly builds all 5 tabs | P2 (04-P2-2) |
| P-3 | `sync_queue.dart:125-137` | `IsarDeadLetter` unbounded (no cap/TTL/reaper) | P2 (04-P2-5) |
| P-4 | `home_screen.dart:165-175` | Hero `Timer.periodic` not lifecycle-aware | P2 (04-P2-6) |
| P-5 | `brand_drawer.dart`, `firestore_paginator.dart` | Dead code (0 callers) | P2 (04-P2-8) |
| P-6 | `proof_of_delivery_service.dart:103` | POD raw `Image.network` no placeholder/error | P2 (04-P2-9) |
| P-7 | `cart_provider.dart:51-62` + `dish_detail_screen.dart:44-57` | Cart business-rule exceptions collapse into generic message | P3 (03-P3-MSG-LOSS) |
| P-8 | `isar_service.dart:7-30` | Vestigial `_instance` singleton + public per-call constructor | P3 (03-P3-ISAR) |
| P-9 | Isar schema | No schema versioning/migration -> `SchemaException` on schema change | P2 (02-P2) |

### 24.2 Solution - design principle + acceptance contract

**Design principle:** never wipe pending ops; cache collections resync; loud log on schema change.

**Acceptance contract (from master W8.9/03-P3/02-P2):**
1. Isar: remove the double-open race (constructor no longer auto-opens; `instanceNames` guard stays as backstop); unify construction on the public path, delete the vestigial `_instance` singleton; add schema-version int + `SchemaException` recovery (wipe-and-resync CACHE collections only, never pending ops - loud log).
2. Home: `IndexedStack` -> build-on-first-visit lazy tabs (state kept).
3. `IsarDeadLetter`: cap 200, FIFO-evict on enqueue.
4. Hero carousel timer lifecycle-aware (pause via `TickerMode`/lifecycle observer).
5. DELETE dead `BrandDrawer` + `FirestorePaginator` (+ their tests).
6. POD image -> `cached_network_image` with placeholder/error.
7. Typed cart-limit exceptions -> localized copy (`dish_detail_screen.dart:44-57`).

### 24.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Isar resync preserves pending ops | Unit: schema change -> cache wiped, pending ops intact, loud log |
| T-2 | Dead code gone | grep `BrandDrawer|FirestorePaginator` in lib = 0 |
| T-3 | DLQ capped | Unit: >200 dead letters -> FIFO eviction |
| T-4 | Lazy tabs | Widget: home builds only visited tabs |
| T-5 | Cart error localized | Widget: limit exception -> specific localized message |

### 24.4 Proof gates

- [ ] `flutter analyze` + full `flutter test` green (0 skip)
- [ ] Dead-code grep = 0
- [ ] Isar resync unit test green (T-1)
- [ ] Universal Gate Set U (index Section 1)

### 24.5 Honest residuals

- Isar `SchemaException` behavior is platform-version knowledge (Isar 3.1.0+1) - the recovery path is code-proven, not runtime-reproduced (no migration harness exists; the new versioning int is the harness going forward).
- `cached_network_image` is a new dependency - verify it is already in the tree (it is used by the image cache layer per audit-04); if not, it is a sanctioned addition (record in addendum).

**END OF BATCH STATE-4 SPEC** - do not proceed until these gates pass and the STATE-4 addendum is appended to FIX_VERIFICATION.md.