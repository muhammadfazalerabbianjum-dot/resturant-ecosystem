# BATCH CI-3 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W1.5.**

## 3. BATCH CI-3 - FUNCTIONS LINT TOOLING + FIX

**Predecessor:** CI-2. **Emulator-gated:** no. **Master:** W1.5.

### 3.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/functions/package.json` | `npm run lint` -> `Missing script: "lint"`; no eslint config/devDeps | P1 (09-P1-FB-7) |
| P-2 | `core_app/functions/src/**` | 591-line rules + 17 functions deployed with zero lint coverage | P1 (09-P1-FB-7) |
| P-3 | `core_app/functions/package.json` | Verify default `npm test` targets the real money tests (B1's suite) | P2 (09-P2 vacuous test script) |

### 3.2 Solution - design principle + acceptance contract

**Design principle:** style-level lint only; zero behavior change; the lint gate becomes part of CI (CI-1 job 8).

**Acceptance contract (from master W1.5):**
1. Add devDeps: `eslint`, `@typescript-eslint/parser`, `@typescript-eslint/eslint-plugin`, `eslint-config-google`.
2. Create `eslint.config.mjs` (flat config, TS parser, google base, no type-check).
3. Add `"lint": "eslint src --ext .ts"` to `package.json`.
4. Fix all lint errors in `functions/src` (style-level only; zero behavior changes).
5. Verify `npm test` runs the real money tests (B1's `test/money.test.js` + emulator check); if the default script is vacuous, point it at the real suite.

### 3.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Lint runs and passes | `npm run lint` exit 0 |
| T-2 | No behavior change | `npx tsc --noEmit` green; `npm test` green (same pass count as pre-lint) |
| T-3 | Lint wired into CI | grep `carnama_ci.yml` for `npm run lint` in the functions job |

### 3.4 Proof gates

- [ ] `npm run lint` exit 0
- [ ] `npx tsc --noEmit` green
- [ ] `npm test` green (record pass count; must match pre-lint)
- [ ] `eslint.config.mjs` present; `lint` script present
- [ ] Universal Gate Set U (index Section 1)

### 3.5 Honest residuals

- eslint-config-google is opinionated (2-space, JSDoc); if a rule conflicts with the codebase's existing style, record the override in the addendum (do not silently disable rules).
- No type-check linting (no `parserOptions.project`) - deliberate to keep lint fast; type safety is `tsc`'s job.

**PARALLEL MODE (§3.5):** if running in a `cline/task-N` worktree, append the addendum to `FIX_VERIFICATION_cline-task-N.md` in YOUR worktree (never the shared `FIX_VERIFICATION.md`), commit everything in your worktree, and STOP at the end of this spec — predecessor-gating and merge-back are performed on `main` by the operator per §3.5. In sequential mode the line below applies unchanged.

**END OF BATCH CI-3 SPEC** - do not proceed to ROUTER-1 until these gates pass and the CI-3 addendum is appended to FIX_VERIFICATION.md.