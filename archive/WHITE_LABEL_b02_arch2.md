# WHITE-LABEL BATCH ARCH-2 SPEC - SHARED APP BODY (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (RULES §0, Gate Set U §1, Environment §2, Batch Map §3, WORKTREE OPS §3.5 + territory §3.6 — the blocker gate B-1..B-5 runs BEFORE you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap1.**

## 2. BATCH ARCH-2 - SHARED APP BODY: PARAMETERIZED INIT + SHELL CALLS IT

**Predecessor:** ARCH-1. **Emulator-gated:** yes (boot verify). **Territory:** core_app (`lib/main.dart` → new `lib/app_bootstrap.dart`; the generator template in `tool/whitelabel.dart`).

### 2.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/lib/main.dart` (519 lines) | The ENTIRE init sequence (dotenv, config, logger, schema check, Firebase, Auth emulator, AppCheck, Analytics consent, FCM, Push, Stripe, Isar, heartbeat, queue triggers, runApp) lives inside `Future<void> main()` — impossible to import or call from a shell | P0 (architecture gap) |
| P-2 | `core_app/lib/main.dart:36` `import 'firebase_options.dart';` | The shell needs ITS OWN `firebase_options.dart` (different project/keys), but core_app's is imported directly — the init sequence is not parameterized | P0 (architecture gap) |
| P-3 | `core_app/tool/whitelabel.dart` (15 screen templates) | The generator still emits 4 placeholder screen templates + own l10n/config templates that ARCH-1 made obsolete — must be updated to emit the THIN shell | P1 (generator hygiene) |
| P-4 | `apps/halal_boyz/lib/main.dart` (205 lines) | The shell's init sequence DUPLICATES core_app's (config gate + Firebase init + FCM + push) — two init paths to maintain | P1 (duplication) |

### 2.2 Solution — design principle + acceptance contract

**Design principle:** ONE init sequence, parameterized by config. core_app's `main()` becomes a thin wrapper calling `initCarnamaApp(bootstrap)`. Every generated shell calls the SAME function with ITS config. The 16-step init chain lives in ONE place.

**Acceptance contract:**
1. **Create `core_app/lib/app_bootstrap.dart`** — exports `initCarnamaApp({required CarnamaBootstrap bootstrap})` containing the ENTIRE init sequence, parameterized by `FirebaseOptions` (caller's), `AppConfig` (caller's), brand config. Also export the `CarnamaBootstrap` input class.
2. **core_app's `main.dart`** becomes a thin wrapper: load its `firebase_options.dart` + config, call `initCarnamaApp`. 519 lines drops to ~50.
3. **The generator's shell template** (`tool/whitelabel.dart` `_mainTemplate()`) becomes a thin wrapper: load shell's options + config, call `initCarnamaApp`, import real screens from `package:labs/` (ARCH-1 barrel). Shell drops from 205 to ~50 lines.
4. **Delete obsolete templates** from whitelabel.dart: the 4 placeholder screen templates, `_appEnArbTemplate`, `_appArArbTemplate` (replaced by core_app l10n), and the old standalone test templates. Shell emits: `main.dart` (thin), `app/app.dart` (thin router delegate), `firebase_options.dart` (per-project), `client_config.json` (per-client).
5. **Preserve every init behavior** — the sequence's ORDER and semantics survive: logger BEFORE Firebase, schema check BEFORE runApp, error widget builder BEFORE Firebase init, heartbeat + queue triggers AFTER Isar, push AFTER FCM, consent AFTER Firebase. Record the order in a comment block.
6. **Preserve the config-inputs** — every step that reads config reads the PARAMETERIZED config (not core_app's hardcoded one).

---

## 2.3 Tests

| Test | Asserts | How |
|---|---|---|
| T-1 | core_app boots identically | core_app's full test suite + boot tests green after the main.dart refactor |
| T-2 | Shell boots identically | halal_boyz's boot tests + firebase-gate + app-launch tests green after the init refactor |
| T-3 | The 16-step order is preserved | Test asserting the init-order comment block matches the actual call sequence |
| T-4 | Emulator boot verify | `firebase emulators:start` + seed → halal_boyz boots against the emulator with all flows PASS (Phase 0 flow driver) |
| T-5 | Generator produces a working shell | `whitelabel.dart --dry-run` into a scratch dir → scratch shell compiles + boots (BACKEND-1's dry-run pattern) |
| T-6 | No duplication | grep for duplicate init sequences: only 1 shared `app_bootstrap.dart` |
| T-7 | Analyzers + format | U-ANALYZE + U-FORMAT |

### 2.4 Proof gates

- [ ] T-1..T-7 green
- [ ] `core_app/lib/app_bootstrap.dart` exists and exports the parameterized init
- [ ] `core_app/lib/main.dart` is a thin wrapper (~50 lines)
- [ ] The shell's main template is a thin wrapper (~50 lines)
- [ ] The 4 placeholder screen templates are DELETED from whitelabel.dart
- [ ] All flows PASS on emulator (Phase 0 flow driver)
- [ ] Universal Gate Set U (index §1)

### 2.5 Honest residuals

- The init sequence's dependencies (firebase_core, firebase_auth, etc.) must be in the shell's pubspec as well — ARCH-2 must verify the shell's pubspec covers everything `app_bootstrap.dart` imports (or the barrel re-exports them).
- Some init steps may have core_app-specific constants (e.g., the Analytics consent check, the FCM channel description) that need parameterizing from config.
- The generator's scratch-dir dry-run (T-5) must be cleaned up afterward (BACKEND-1's pattern).
- If any test depends on core_app's main.dart structure, it needs updating to reference app_bootstrap.dart instead.
- firebase_options.dart stays per-project (core_app's + each shell's own) — it is NOT extracted into the shared bootstrap (it's generated per-project by the FlutterFire CLI).

**END OF BATCH ARCH-2 SPEC** - do not proceed to COV-1 until these gates pass and the ARCH-2 addendum is appended to `FIX_VERIFICATION.md`.