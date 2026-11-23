# BATCH ROUTER-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W2.4, W2.5, W2.6, W2.9.**

## 5. BATCH ROUTER-2 - WIRING + ORPHAN SURFACING + ROLE GATING

**Predecessor:** ROUTER-1. **Emulator-gated:** no. **Master:** W2.4, W2.5, W2.6, W2.9. **MIRROR: yes for router/role surfaces the shell carries.**

### 5.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/lib/features/menu/presentation/menu_screen.dart:170-242` | Menu items have NO onTap - dish detail unreachable from menu (only via home) | P1 (00-P1-1) |
| P-2 | `core_app/lib/features/menu/presentation/merged_menu_provider.dart:78` | `setBranch()` has ZERO callers - LocationScreen cannot select a branch | P1 (00-P1-2) |
| P-3 | LocationScreen | `PinDropMapScreen` unreachable | P2 (00-P2-1) |
| P-4 | `admin_gateway_screen.dart` | Doc comment describes 20-tap/PIN entry that does not exist (implementation is role-based) | P2 (00-P2-2) |
| P-5 | 10 admin surfaces | No client-side role invariant (defense-in-depth); wrong-role users see screen chrome | P2 (01-P2-1) |

### 5.2 Solution - design principle + acceptance contract

**Design principle:** wire to EXISTING providers/routes (additive taps, no new logic); role gating is defense-in-depth (rules remain the real guard).

**Acceptance contract (from master W2.4/W2.5/W2.6/W2.9):**
1. `menu_screen.dart`: each menu card `onTap` -> `context.pushNamed(RouteNames.dishDetail, pathParameters: {'id': item.id})` (route `/dish/:id` already exists). Do NOT touch `$` price strings (UX-1 owns money literals).
2. Branch picker: per-branch `onTap` -> `setBranch(branch.id)` through the provider's StateNotifier API; confirm branch-scoped menu streams re-scope.
3. LocationScreen: one icon button -> `pushNamed` to `PinDropMapScreen`.
4. `admin_gateway_screen.dart`: fix doc comment to describe the ACTUAL role-based entry (comment-only).
5. One-line comment per static-mode-only orphan (AdminMenuManager/AdminDashboard/LogsScreen) - do not route them in config mode.
6. W2.9: add a shared `RoleGate` widget (or `roleGateProvider`-checked builder) rendering `_NoPermissionRedirect` (pattern from `role_router_screen.dart:68-78`) when the signed-in role is not the surface's allowed set; apply to the 10 unguarded admin surfaces (owner/manager/kitchen/delivery dashboards + AdminMenuManager + TierFlags + RestaurantSetup + OperatingHours + Analytics + AdminReservationsTab).

### 5.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Menu item tap navigates to dish detail | Widget test: tap menu card -> `DishDetailScreen` with correct id |
| T-2 | Branch selection re-scopes menu | Widget test: tap branch -> `currentBranchIdProvider` updated + menu stream re-queries |
| T-3 | PinDropMapScreen reachable | Widget test: LocationScreen button -> screen present |
| T-4 | Wrong-role admin surface redirects | Widget test per surface: signed-in wrong role -> `_NoPermissionRedirect` (not the dashboard) |
| T-5 | Correct-role admin surface renders | Widget test: owner role -> dashboard renders |

### 5.4 Proof gates

- [ ] T-1..T-5 green
- [ ] `flutter analyze --fatal-infos` green
- [ ] grep `setBranch(` has >= 1 caller in lib
- [ ] Universal Gate Set U (index Section 1)

### 5.5 Honest residuals

- Role-gate is client-side only; rules remain the authoritative guard (RULES-1). A wrong-role user with a modified client can still hit data-layer denials - that is the intended fail-closed design.
- The 10 surfaces' exact role sets must be read from the existing role-router mapping (`role_router_screen.dart`) - do not invent new role semantics.

**END OF BATCH ROUTER-2 SPEC** - do not proceed until these gates pass and the ROUTER-2 addendum is appended to FIX_VERIFICATION.md.