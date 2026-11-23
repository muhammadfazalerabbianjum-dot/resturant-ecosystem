# BATCH CI-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W1.1 + W1.6.**

## 1. BATCH CI-1 - CI PIPELINE RELOCATE + REPAIR

**Predecessor:** B0. **Emulator-gated:** no. **Master:** W1.1, W1.6.

### 1.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/.github/workflows/carnama_ci.yml` | Workflow under `core_app/.github/` never triggers - GitHub only discovers `<repo-root>/.github/workflows/` | P0 (07-P0-1) |
| P-2 | yml:10 | `flutter-version: 3.32.0` = Dart 3.8 < workspace `^3.11.0` -> pub get impossible | P0 (07-P0-1) |
| P-3 | yml steps | Root-CWD paths; `test/` doesn't exist at root; `tool/` is under core_app | P0 (07-P0-1) |
| P-4 | yml:23 | Format gate would fail (215/402 files) - fixed by CI-2's commit, but the job must exist | P1 (07-P1-2) |
| P-5 | yml:64 | unit-tests selects only 95/231 core_app files; test/features (87) + packages + shell have ZERO coverage | P1 (07-P1-1) |
| P-6 | yml:25-45 | `pub outdated` major-blocking step will hard-block once reachable | P2 (07-P2-5) |
| P-7 | yml | No pub/Gradle caching, no concurrency group, 3rd-party actions unpinned | P2/P3 (07-P2-6, 07-P3-1, 07-P3-2) |
| P-8 | `core_app/dart_test.yaml` | Tags (integration/emulator/golden) never passed via `--tags` | P2 (07-P2-8) |

### 1.2 Solution - design principle + acceptance contract

**Design principle:** the tier design (analyze -> unit -> golden -> rules -> permissions -> android-smoke -> integration -> functions -> gate) matches the repo's constitution; the fix is location + CWD + SDK + coverage, not redesign.

**Acceptance contract (from master W1.1/W1.6):**
1. Move the workflow to `<repo>\.github\workflows\carnama_ci.yml` (create dirs; delete the old file).
2. `flutter-version: 3.41.2` (matches every recorded session run; satisfies Dart `^3.11.0`).
3. Every step gets `working-directory:` (core_app / packages/core / packages/core_ui / apps/halal_boyz).
4. Jobs: (1) analyze - pub get + `dart format --output=none --set-exit-if-changed .` + `flutter analyze --fatal-infos` (core_app) + `dart analyze` (both packages); (2) unit-tests - `flutter test --coverage` in core_app over the FULL `test/` tree (explicitly incl. test/features, test/app, test/config, test/golden) + full `flutter test` in packages/core, packages/core_ui, apps/halal_boyz; aggregate lcov, 80% floor over per-package totals; (3) golden-tests - `flutter test test/ui test/golden`; (4) firestore-rules - `firebase emulators:exec --only firestore,auth "npm run test:rules"` (node setup); (5) audit-permissions - `dart tool/audit_permissions.dart`; (6) android-release-smoke - `flutter build appbundle --debug`; (7) integration-test - KVM + api-33 emulator + `flutter test integration_test/` under emulators; (8) functions - `npm ci`, `npm run lint`, `npx tsc --noEmit`, `npm test`; (9) ci-gate - `needs:` all.
5. Hardening: SHA-pin every third-party action; `concurrency:` + `cancel-in-progress: true`; `actions/cache` (pub + gradle); `pub outdated` as NON-blocking report step.
6. W1.6: pass explicit `--tags` per job matching `core_app/dart_test.yaml`.

### 1.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Workflow is discoverable at repo root | `Test-Path <repo>\.github\workflows\carnama_ci.yml` = True; old file absent |
| T-2 | YAML parses | `npx js-yaml .github\workflows\carnama_ci.yml` exits 0 |
| T-3 | SDK pin satisfies workspace | grep yml `3.41.2` present; root pubspec `^3.11.0` satisfied |
| T-4 | Full-estate test dirs referenced | grep yml for `test/features`, `packages/core`, `apps/halal_boyz` |
| T-5 | Local gates still green | `flutter analyze --fatal-infos` (core_app) + `flutter test` green (CI files must not break them) |

### 1.4 Proof gates

- [ ] `Test-Path <repo>\.github\workflows\carnama_ci.yml` = True
- [ ] Old `core_app/.github/workflows/carnama_ci.yml` absent
- [ ] YAML parses (T-2)
- [ ] `dart format --output=none --set-exit-if-changed .` exits 0 at the existing worktree state
- [ ] core_app `flutter analyze --fatal-infos` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 1.5 Honest residuals

- A real green GitHub run is a RELEASE-2 final-clearance item (needs the repo pushed + Actions enabled); local gates are the completion proof here.
- Annotate B6's "GO" in `FIX_VERIFICATION.md` with one line: `SUPERSEDED 2026-09 by the 9-audit production-readiness FAIL - see PRODUCTION_READINESS_AUDIT_MASTER.md`.

**END OF BATCH CI-1 SPEC** - do not proceed to CI-2 until these gates pass and the CI-1 addendum is appended to FIX_VERIFICATION.md.