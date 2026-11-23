# Carnama Enterprise Platform — Deferred Backlog
> **Updated:** 2026-09-30 — p26 T-5 hygiene sweep: every row below was re-checked against the code (a deferral without evidence is a claim, not a record). Evidence is `path:line` per row; raw census: `tool_uilib/p26/receipts/t5_deferred_reconcile.txt`.
> **Rule:** Per Constitution Law 26, all deferred features must be explicitly tracked here.
> **Owners are ROLES** (`coordinator`, `next functions lane`, `release gate`) per the project's lane vocabulary — never an individual.

## Frontend rows — all five CLOSED (the 2026-05-25 statuses were stale)

| ID | Feature | Status | Evidence (`file:line`) |
|----|---------|--------|------------------------|
| D3 | Analytics / Revenue Dashboard | **Done** (was: Unstarted) | `core_app/lib/features/admin/domain/analytics_provider.dart`, `core_app/lib/features/admin/presentation/analytics_snapshot.dart`, `.../presentation/analytics/revenue_chart_widget.dart:3` (uses `fl_chart ^1.2.0`, `core_app/pubspec.yaml:46`), `core_app/tool/analytics_funnel_queries.sql`; receipts `tool_uilib/p17/RUNBOOK_ANALYTICS.md`, `archive/WHITE_LABEL_p17_analytics1.md` |
| D4 | Deep Linking / Universal Links | **Done** (was: Unstarted) | `packages/core/lib/src/navigation/deep_link_service.dart`; pins `packages/core/test/navigation/deep_link_service_test.dart`, `core_app/test/core/deep_link_test.dart` |
| D5 | Admin Gateway (tap entry + PIN) | **Done** (was: Unstarted) | `core_app/lib/features/admin/presentation/gateway/admin_gateway_screen.dart:13` ("secret PIN / 20-tap entry. The security decision is made SERVER-SIDE by …"); pins `core_app/test/features/admin/admin_gateway_test.dart`, golden `core_app/test/ui/goldens/p22_admin_gateway_denied.png` |
| D7 | Order History UI Overhaul | **Done** (was: Unstarted) | `core_app/lib/features/orders/presentation/order_history_screen.dart`; glassmorphism receipt `core_app/test/ui/goldens/p20_order_history.png`, adoption pin `core_app/test/features/orders/presentation/p20_order_history_adoption_test.dart` |
| D8 | Freezed Domain Migration | **Done** (was: In Progress) | census on this tip: **15/15** tracked `*model.dart` files carry a `.freezed.dart` sibling (Law 23 surface complete), e.g. `core_app/lib/features/loyalty/domain/loyalty_model.freezed.dart` |

---

## Awaiting Client Target Environment (Blaze Plan / Hardware)
> **Rule:** These features CANNOT be safely tested or deployed until the physical client application has a Blaze tier Firebase environment and/or physical integration hardware.

| ID | Feature | Status | Blocker / evidence (`file:line`) |
|----|---------|--------|----------------------------------|
| D1 | Loyalty & Rewards Backend | **Done** (was: Unstarted) | the server-side award already ships: `core_app/functions/src/index.ts:1652-1670` (transactional `loyalty/{customerId}` write on order completion), `totalPoints` is server-owned in the rules (harness probes `loyalty/customer-uid`, b10-T31..T33); receipts `tool_uilib/p15/p15_report.md`, `tool_uilib/p20/p20_report.md`; pin `core_app/test/wiring/loyalty_wiring_test.dart` |
| H1 | Stripe Tap-to-Pay (NFC) | **Stubbed — KEPT** (owner: release gate) | `packages/core/lib/src/payment/nfc_terminal_service.dart:3,28,37,48` (`TODO_DEPLOY`: Stripe Terminal SDK + native Bluetooth discovery) degrades with a clear error at `:53` instead of crashing; needs a physical device + Stripe Terminal account |
| H2 | Kitchen LAN Thermal Printing | **Unstarted — KEPT** (owner: release gate) | corrected from "Stubbed": there is no implementation in the tree — `git grep -i thermal` outside docs returns nothing; needs a physical ESC/POS printer on the LAN (the V2 scope note lives at `core_app/docs/carnama_dev_handbook.md:311`). **OWNER CLAIMS DONE — NO IMPLEMENTATION FOUND IN ANY WORKTREE OR BRANCH (handoff §7.3). Treated as UNBUILT. Blocked pending owner producing the implementation path/repo. Any 'thermal done' claim in code or docs is false until then.** |
| C1 | `calculateTax` Cloud Function | **Done** (was: Stubbed) | `core_app/functions/src/index.ts:147` (`export const calculateTax = onCall(…)`) with `enforceAppCheck` at `:148`; the single server tax lookup is `core_app/functions/src/payment.ts:83`. RESIDUAL DEBT still tracked (owner: next functions lane): the callable trusts the client-supplied `subtotalCents` and needs a server-side input guard, and the functions are on the deprecated v1 API pending the v2 move |
| C2 | Firebase App Check AppAttest | **Partially done — KEPT** (owner: coordinator, Stage-6 close) | client wiring SHIPPED: `core_app/lib/app_bootstrap.dart:649-655` (`playIntegrity`/`appAttest` in release, debug providers otherwise) — the M2 note below used to name `lib/main.dart`, which is stale; what remains is console enforcement (needs Blaze + Apple keys) |

---

## 🔴 Pre-Release Manual Gates (Week 4+)

### M2 — Firebase App Check Console Enforcement
> **Code:** already wired in `core_app/lib/app_bootstrap.dart:649-655` — `playIntegrity` (Android) + `appAttest` (iOS) in release (debug providers otherwise). (The 2026-05-25 revision of this file said `lib/main.dart`; the wiring moved into the bootstrap chain — path corrected in the p26 T-5 sweep.)
>
> **Manual step (requires Blaze plan):**
> 1. Firebase Console → App Check → Firestore → Enable enforcement
> 2. Firebase Console → App Check → Cloud Functions → Enable enforcement

### S2 — Firestore Composite Index (menus tag filtering)
**Status:** Done. Composite indexes strictly deployed in `firestore.indexes.json`.
**Action:** (Satisfied via Law 27 bounds).

### D1 — Flip `kDemoMode = false`
1. `firebase deploy --only functions`
2. `lib/core/config/demo_config.dart` → `kDemoMode = false`
3. Replace `pk_test_` Stripe key with `pk_live_` in `.env.production`
4. `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`

### D2 — Release APK No-Red-FAB Verification
```powershell
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
# Visually confirm: no red debug FAB on any screen
```

### D3 — Shorebird OTA Patch Test
```bash
shorebird patch android --release-version=1.0.0
# Verify patch downloads on device within 30s of launch
```

---

*S4 requirement satisfied — Constitution Law 26.*

---

## Test reliability — kept with an owner (2026-10-09)

| ID | Item | Status | Evidence (`file:line`) |
|----|------|--------|------------------------|
| T-FLAKE-1 | `app_bootstrap_states_test` STEP 16 boot-log race | **CLOSED 2026-10-15** (fixed: per-process boot-log isolation) | The DEFERRED hint above ("does not await `LoggerService.error()`") was STALE — every boot-chain `logger.error` call IS awaited (`app_bootstrap.dart` STEP 11/13/15 sites) and `LoggerService.error` awaits its file write. Real root cause: under `FLUTTER_TEST` the boot logger sank into the MACHINE-GLOBAL `%TEMP%/app_logs.txt`; each of the 4 harness test files is its own process, and each `install()`/`restore()` snapshot+delete+overwrite clobbered siblings' bytes between the write and `freshBootLog()` (~1 in 5 full-suite runs). Fix (Law 2 red→green): `bootLogDirectoryForTest()` in `app_bootstrap.dart` — a per-PID subdirectory used by the logger's `FLUTTER_TEST` branch, the `handleBootFailure` crash-log fallback (`dir.createSync(recursive: true)` for pre-logger-init crashes) and `BootHarness`'s `bootLogPathForTest`/`crashLogPathForTest` (single source of truth). Aligns with determinism law §0.7 / temp_log_guard; production path untouched (no `FLUTTER_TEST`). New contract test `test/boot_log_process_isolation_test.dart` (RED: compile-fail on missing symbols, receipt `tool_uilib/p35/t_flake1_red.txt` → GREEN 3/3, receipt `t_flake1_green.txt`). Proven: boot set (states+t1+t2+t3+isolation+temp_log_guard, 23 tests) ×5 pre-format + ×5 post-format, 10/10 EXIT=0 (`t_flake1_repeat.txt`, `t_flake1_repeat_postformat.txt`); full default tier +2538 All tests passed, TIER_EXIT=0 (`t_flake1_default_tier.txt`); `flutter analyze` No issues (`t_flake1_analyze2.txt`); `dart format --set-exit-if-changed` 0-changed. |

---

## p35 additions (2026-10-14)

| ID | Feature | Status | Blocker / evidence (`file:line`) |
|----|---------|--------|----------------------------------|
| D-P35-1 | Migrate all legacy components to the `AppSpacing` scale | **Deferred** (owner: coordinator) | Snapping inline `2`/`6` literals to the scale (xs4/sm8/md12/lg16/xl24/xxl32) is an intentional pixel change → golden drift (Law 17). Requires an owner-approved golden-regeneration pass. The scale ships additive now (`packages/core_ui/lib/src/theme/app_tokens.dart` `AppSpacing`); new components reference it. Deferred siblings (p35-B.2 nav 5+More, p35-C preset/font gallery, p35-D ScreenVariants catalog) live in `archive/WHITE_LABEL_p35_theme_engine.md` §7. |
| D-P35-2 | Designed dark surface ramp + non-flat default depth (scope-B B-2/B-3) | **Deferred** (owner: coordinator) | The visual audit (`tool_uilib/p35/VISUAL_AUDIT.md`) found dark mode shallow-but-functional (a single `#2A2A2A`-on-`#0F0F0F` surface step), NOT broken — so a richer designed dark + a non-flat default depth is an enhancement, not a fix. Changing the DEFAULT dark surfaces and/or defaulting depth to `soft` is an intentional pixel change → dark-golden drift (Law 17), requiring an owner-approved golden-regeneration pass. The `theme.depth` mechanism (B-1) SHIPS opt-in now (additive, golden-safe); the `theme.darkTheme.surfaces` config surface (B-2) and the dark AA foreground (B-3) are NOT implemented yet — both belong to this deferred, golden-gated pass. |


## p34 additions (2026-10-11)

| ID | Feature | Status | Blocker / evidence (`file:line`) |
|----|---------|--------|----------------------------------|
| D-P34-1 | `isar_community_generator` (in-workspace schema regeneration) | **Deferred — KEPT** (owner: coordinator) | `isar_community_generator` 3.3.2 requires `build ^4.0.0` / `source_gen >=4.0.0 <5.0.0`, incompatible with `flutter_stripe 11.5.0` → `stripe_platform_interface 11.5.0` → `freezed_annotation ^2.4.1` → freezed 2.x → `build ^2.x` (every in-workspace resolution fails: `tool_uilib/p34_e2e/pubget_fail.txt`). The 16 KB runtime swap shipped WITHOUT it (`isar_community` 3.3.2, ELF-verified `align=0x4000` on x86_64+arm64); `packages/core/lib/src/cache/isar_schemas.g.dart` was regenerated once via an out-of-workspace sandbox with the REAL community generator (`version: '3.3.2'`, all 4 schema ID hashes identical to the 3.1.0+1 file — existing device data stays readable). Unblocks when flutter_stripe ships a freezed_annotation ^3-compatible release. The repo-root `isar.dll` (old 3.1.0+1 core) is now unreferenced by code (test helpers resolve the lockfile-pinned binary via `package_config.json`); kept in tree until the owner confirms deletion. |

## p26 T-5 reconciliation summary (2026-09-30)

- **Closed on evidence (6):** D1, D3, D4, D5, D7, D8 — each was already shipped; the stale statuses were the defect.
- **Status corrected (1):** H2 `Stubbed` → `Unstarted` — there is no code to call stubbed.
- **Path corrected (1):** M2's App Check wiring (`lib/main.dart` → `lib/app_bootstrap.dart:649-655`).
- **Kept with an owner (3):** H1 (release gate), C2 (coordinator, Stage-6 close), C1's residual `subtotalCents` guard + functions v1→v2 move (next functions lane).
- **Unchanged on purpose:** the pre-release manual gates (S2 done, D1 flip, D2 APK check, D3 Shorebird patch) and the strike-through-free history above — this sweep corrects records, it does not delete scope.


