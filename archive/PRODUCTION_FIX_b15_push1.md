# BATCH PUSH-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W5.3.**

## 15. BATCH PUSH-1 - KITCHEN HEARTBEAT SCHEDULING + EMPTY-ENDPOINT FAIL-CLOSED

**Predecessor:** QUEUE-2. **Emulator-gated:** no. **Master:** W5.3. **MIRROR: main startup block mirrored to shell.**

### 15.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `kitchen_offline_service.dart:53-84` | `initialize()`/`scheduleHeartbeat()` have ZERO callers in lib - 15-min LAN sync never runs | P1 (02-P1-KITCHEN) |
| P-2 | `kitchen_task_dispatcher.dart:11-22` | Dispatcher correct + tested but never registered | P1 (02-P1-KITCHEN) |
| P-3 | `kitchen_offline_service.dart:110` + `core_config_adapter.dart:39` | Heartbeat would `Uri.parse('')` on an empty endpoint (generated shell may yield `''`); inverts to push only when connectivity down | P1 (02-P1-KITCHEN) |

### 15.2 Solution - design principle + acceptance contract

**Design principle:** one composition call in `main.dart` startup (matching how FcmService is initialized); fail-closed on empty endpoint.

**Acceptance contract (from master W5.3):**
1. In `main.dart` startup (after `IsarService().openDB()`): `KitchenOfflineService(orderPayloadParser: OrderPayloadAdapter.fromJson).initialize(kitchenTaskDispatcher)` + `scheduleHeartbeat()` ONCE (guarded bool; `existingWorkPolicy: keep` prevents duplicate registration).
2. `kitchen_offline_service.dart:110`: if `kitchenLanEndpoint` empty/absent -> log-and-skip (never `Uri.parse('')`).
3. Unit test for the empty-endpoint guard.

### 15.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Empty endpoint fails closed | Unit: service with `''` endpoint -> log-and-skip, no throw |
| T-2 | Scheduled exactly once | Guarded bool + `existingWorkPolicy: keep` (unit test at `kitchen_offline_service_test.dart` precedent) |
| T-3 | Startup wires it | Widget/unit: main launches initialize + scheduleHeartbeat |

### 15.4 Proof gates

- [ ] Empty-endpoint unit test green
- [ ] grep `initialize(` + `scheduleHeartbeat(` in lib has callers (was 0)
- [ ] `flutter analyze` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 15.5 Honest residuals

- Workmanager background execution is platform-scheduled; exact 15-min cadence is best-effort on Android (Doze) - documented.
- The LAN endpoint value itself is config data (ops checklist, master section 12).

**END OF BATCH PUSH-1 SPEC** - do not proceed to PUSH-2 until these gates pass and the PUSH-1 addendum is appended to FIX_VERIFICATION.md.