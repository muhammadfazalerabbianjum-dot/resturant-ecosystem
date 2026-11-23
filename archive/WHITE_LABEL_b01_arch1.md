# WHITE-LABEL BATCH ARCH-1 SPEC - SHELL IMPORTS REAL SCREENS (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (RULES §0, Gate Set U §1, Environment §2, Batch Map §3). Gap analysis: `PROJECT_STATUS.md` §5-Gap1.**

## 1. BATCH ARCH-1 - SHELL IMPORTS REAL SCREENS

**Predecessor:** RELEASE-2. **Emulator-gated:** yes (flow verification). **Territory:** shell (`apps/halal_boyz`) + core_app (barrel export only — never touch features/).

### 1.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `apps/halal_boyz/lib/features/*/` (4 files, 320 lines) | Every screen is a `TODO_DEPLOY: hardcoded placeholder` — static tiles, 6 hardcoded dishes, 3 hardcoded cart lines, disabled checkout | P0 (architecture gap) |
| P-2 | `apps/halal_boyz/lib/app/app.dart` (85 lines) | Own route builder with 4 routes, importing local placeholders — not the real 42-route config-driven router from `core_app/lib/app/app_router.dart` (600 lines) | P0 (architecture gap) |
| P-3 | `apps/halal_boyz/lib/l10n/` (3 files, 322 lines) | Own simple l10n (219+51+52) — different from core_app's full version (6,360 lines, complete en+ar) | P1 (duplication) |
| P-4 | `apps/halal_boyz/lib/app/client_config.dart` (234 lines) | Own config validation — copy of core_app's `app/config/client_config.dart` but simpler | P1 (duplication) |
| P-5 | `apps/halal_boyz/pubspec.yaml` | Does NOT path-dep on `labs` (core_app's package name) — cannot import the real screens | P0 (missing dependency) |
| P-6 | `core_app/lib/` (no barrel) | No `labs.dart` export barrel — `labs` package has no importable surface even if path-depped | P0 (missing barrel) |

### 1.2 Solution — design principle + acceptance contract

**Design principle:** the shell becomes a THIN WRAPPER — config + Firebase init + `MaterialApp` → real screens imported from `package:labs/`. The 28,059 lines of real app code live in ONE place (core_app) and serve every client. The generator's placeholder screen templates become obsolete (deleted from `whitelabel.dart` in ARCH-2).

**Acceptance contract:**
1. **Create `core_app/lib/labs.dart`** — a barrel export that exposes the public surface: `AppRouter`, `RouteNames`, `AppConfig`, `CoreApp`, `ConfigErrorScreen`, `ConfigValidationErrorScreen`, `ForceUpdateGuard`, `GdprConsentDialog`, `CurrencyFormat`, `status_role_labels`, the feature screens (home, menu, dish detail, cart, checkout, order tracker, order history, profile, waitlist, locations, reservation, loyalty, delivery tracker, admin dashboards, auth screens, compliance screens), and the key providers. Follow Dart barrel conventions (`export 'src/...' hide/show` for private internals).
2. **Add `labs` as path dependency** in `apps/halal_boyz/pubspec.yaml`: `labs: { path: ../../core_app }` (same pattern as the existing `core:` and `core_ui:` path deps).
3. **Replace placeholder screens** — delete `apps/halal_boyz/lib/features/` (all 4 files) and `apps/halal_boyz/lib/l10n/` (all 3 files). Replace `apps/halal_boyz/lib/app/app.dart`'s route builder with one that imports from `package:labs/` and builds the REAL 42-route router (or delegates to core_app's router with the shell's config injected).
4. **Preserve the shell's config wiring** — `main.dart`'s config gate (WL-1's fail-fast), `client_config.dart`'s validation (or delegate to core_app's), and the Halal Boyz palette/fonts (WL rebrand) must survive the migration.
5. **Preserve the shell's entry point** — `main.dart` stays (it's the client-specific Firebase init + config loading), but the screens come from `package:labs/`.
6. **Verify all flows on the emulator** — boot + seed (Phase 0's `seed_demo_data.js`), then walk: splash → login (all 4 accounts) → role-gates → owner dashboard → menu browse (REAL Firestore streams) → cart with modifiers → checkout UI → admin menu manager → offline queue → GDPR. Record PASS/FAIL per flow.

### 1.3 Tests

| Test | Asserts | How |
|---|---|---|
| T-1 | Shell resolves real screens | Widget test: halal_boyz's router builds `HomeScreen` from `package:labs/`, not a local placeholder |
| T-2 | Config flows through | Real config palette renders on the real screens (BrandColors from Halal Boyz config) |
| T-3 | All 42 routes registered | Route walker test (from ROUTER-3's pattern) |
| T-4 | Emulator flows pass | Flow driver (Phase 0's `verify_demo_flows.js` pattern) |
| T-5 | No placeholder markers | grep `TODO_DEPLOY|hardcoded placeholder` in shell = 0 |
| T-6 | Analyzers + format | U-ANALYZE + U-FORMAT |

### 1.4 Proof gates

- [ ] T-1..T-6 green
- [ ] All flows PASS on emulator (Phase 0 flow driver)
- [ ] `grep TODO_DEPLOY|hardcoded placeholder apps/halal_boyz/lib` = 0
- [ ] Shell's l10n/config duplication deleted (no `apps/halal_boyz/lib/l10n/`)
- [ ] `labs` path dep present in halal_boyz pubspec
- [ ] `core_app/lib/labs.dart` barrel exists and exports the public surface
- [ ] Universal Gate Set U (index §1)

### 1.5 Honest residuals

- core_app's `main.dart` init sequence is NOT parameterized yet (that's ARCH-2) — the shell still boots via its own init, just with real screens.
- The shell's own `client_config.dart` (234 lines) may be replaced by core_app's version in ARCH-2 (when the init sequence is shared). For now, if the shell's config validation still works, keep it.
- Some core_app screens may reference core_app's `firebase_options.dart` — the shell needs its own (already exists) or the barrel needs to parameterize it.
- `_merchantConfigured` checkout honesty (shell's current pattern) must survive — the real checkout respects it.

**END OF BATCH ARCH-1 SPEC** - do not proceed to ARCH-2 until these gates pass and the ARCH-1 addendum is appended to `FIX_VERIFICATION.md`.