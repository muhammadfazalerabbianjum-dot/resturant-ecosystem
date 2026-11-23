# BATCH PUSH-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W5.5, W5.6.**

## 16. BATCH PUSH-2 - END-TO-END PUSH CHAIN + FCM TIMING (REQUIRES ROUTER-1)

**Predecessor:** ROUTER-1 AND PUSH-1. **Emulator-gated:** no. **Master:** W5.5, W5.6. **MIRROR: main.dart startup + handler in shell copy.**

### 16.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `packages/core/lib/src/network/push_notification_service.dart:9-52` | NEVER instantiated anywhere - `onMessage`/`onMessageOpenedApp`/`getInitialMessage` listeners never register -> taps navigate nowhere, foreground pushes do nothing, cold-start taps do nothing | P1 (02-P1-PUSH) |
| P-2 | `notification_service.dart:7-20` | Local-notification taps unwired | P1 (02-P1-PUSH) |
| P-3 | `push_notification_service.dart:27,36,46` | `_onNavigate` untyped passthrough - zero tenant/payload validation | P1 (02-P1-PUSH) |
| P-4 | `main.dart:210-225` | FCM permission requested at launch, not in-context | P2 (04-P2-10, 06-P2-5) |

### 16.2 Solution - design principle + acceptance contract

**Design principle:** the server already sends pushes (`index.ts:805-876`); the client must consume them through the ACTIVE router with tenant validation.

**Acceptance contract (from master W5.5/W5.6):**
1. In `main.dart` (Firebase init block ~:210-225): instantiate `PushNotificationService` via DI, register listeners.
2. App-layer navigation handler: validates `data['clientId'] == clientId` (drop on mismatch), resolves `data['route']`/`data['orderId']` ONLY against ACTIVE config routes (W2 map / RouteNames), role-redirects inherit the router redirect, logs via `loggerProvider`. Wire `LocalNotificationService` taps into the same handler. Defensive payload validation (known keys only).
3. Move notification permission request to in-context (first checkout/tracker entry), keep denied-degrades (`fcm_service.dart:26-30`), keep token upload after grant.

### 16.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | remote message -> expected route | Widget: fake `RemoteMessage` with `route` + `orderId` -> correct screen |
| T-2 | Tenant mismatch ignored | `data['clientId']` != current -> no navigation |
| T-3 | Role-not-allowed falls through to redirect | Push target restricted -> router redirect (not direct screen) |
| T-4 | Permission moved in-context | Code read: no cold-start request; launch path clean |
| T-5 | Local notification tap wired | Fake local-notification tap -> handler -> route |

### 16.4 Proof gates

- [ ] Widget tests T-1..T-5 green
- [ ] grep `PushNotificationService(` instantiation in main present (was 0)
- [ ] `flutter analyze` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 16.5 Honest residuals

- Cold-start tap `getInitialMessage` requires an actual FCM push on a device to validate - add to the RELEASE-2 device smoke checklist.
- Push payload schema is server-owned (`index.ts:805-876`); the handler validates defensively but the server keys are the contract.

**END OF BATCH PUSH-2 SPEC** - do not proceed until these gates pass and the PUSH-2 addendum is appended to FIX_VERIFICATION.md.