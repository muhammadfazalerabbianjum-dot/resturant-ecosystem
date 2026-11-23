# BATCH STAFF-QUEUE SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W5.4.**

## 14. BATCH STAFF-QUEUE - QUEUED STAFF STATUS WRITES (REQUIRES RULES-1)

**Predecessor:** RULES-1 AND QUEUE-1. **Emulator-gated:** rules emulator. **Master:** W5.4. **MIRROR: kitchen/delivery/POD services are `core_app/features` - shell does not carry these; confirm, else mirror.**

### 14.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `kitchen_service.dart:43-46` | Direct Firestore update; on flaky networks the status mutation is LOST (UI error only) | P1 (02-P1-STAFF) |
| P-2 | `delivery_service.dart:68-71, 91-95` | Same for markDelivered + assignToMe | P1 (02-P1-STAFF) |
| P-3 | `proof_of_delivery_service.dart:54-61` | Same for proof-of-delivery write | P1 (02-P1-STAFF) |

### 14.2 Solution - design principle + acceptance contract

**Design principle:** reuse `IsarSyncQueue` `update` ops (already supported, `sync_queue.dart:150-158`); staff ops are idempotent by doc id + last-write-wins status - exactly the merge-safe shape the queue replays. REQUIRES RULES-1 landed (replays must be rules-legal).

**Acceptance contract (from master W5.4):**
1. `kitchen_service.dart:43-46`, `delivery_service.dart:68-71, 91-95`, `proof_of_delivery_service.dart:54-61`: enqueue op `'update'` on `orders/{id}` (only the RULES-1-legal fields `{status, updatedAt}` / POD shape) BEFORE the Firestore write; remove on success; mirror `checkout_screen.dart:354-355,427`.
2. Last-write-wins replays idempotent; duplicate status replays harmless.

### 14.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | update enqueued before write | Fake Firestore: service call -> queue op `'update'` present |
| T-2 | Replay uses set(merge:true) on orders/{id} | Fake Firestore: `processQueue` -> `set(merge:true)` on the order doc |
| T-3 | Rules-legal shape | Rules harness: staff update `{status, updatedAt}` ALLOW (RULES-1 case) |
| T-4 | Removed on success | Queue empty after successful write |

### 14.4 Proof gates

- [ ] Fake-Firestore test green (T-1, T-2, T-4)
- [ ] `npm run test:rules` still green (T-3)
- [ ] Universal Gate Set U (index Section 1)

### 14.5 Honest residuals

- Sequencing with RULES-1 is mandatory; if STAFF-QUEUE runs before RULES-1, replays DENY. The predecessor gate enforces this.
- Pending ops cap (Isar) still enforced at boot (STATE-4 owns the cap refinement).

**END OF BATCH STAFF-QUEUE SPEC** - do not proceed until these gates pass and the STAFF-QUEUE addendum is appended to FIX_VERIFICATION.md.