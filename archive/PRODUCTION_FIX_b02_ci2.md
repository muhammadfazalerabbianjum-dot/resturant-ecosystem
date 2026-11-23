# BATCH CI-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W1.2, W1.3, W1.4.**

## 2. BATCH CI-2 - FORMAT COMMIT + SECRETS HYGIENE + GOLDEN RE-CAPTURE

**Predecessor:** CI-1. **Emulator-gated:** no. **Master:** W1.2, W1.3, W1.4.

### 2.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | 136 tracked `.dart` files (worktree) | Mechanical `dart format` changes uncommitted; format gate red | P1 (07-P1-2) |
| P-2 | `core_app/.env` | Tracked in git, NOT gitignored - one `git add .` from leaking | P2 (07-P2-3, 08-P2-7) |
| P-3 | `core_app/android/key.properties` | Gitignored but no committed `.template`/`.example` | P2 (07-P2-3) |
| P-4 | `test/golden/failures/**` | Committed golden-failure artifacts (CI pollution) | P2 (07-P2-2) |
| P-5 | `test/goldens/{kitchen,delivery}_dashboard.png` | Byte-identical MD5 (757C33B4AD5B...) - one asserts nothing | P2 (07-P2-1) |

**DRIFT NOTE (2026-09-01 spec audit, post CI-1):** CI-1 already applied the mechanical `dart format` to the worktree (276 files, incl. the pre-existing 137-file set; root format gate now exits 0). P-1 is therefore: COMMIT the format-only worktree changes as ONE format-only commit — count is 276, not 136 — split from the pre-existing substantive deltas per the B0-preflight note in `FIX_VERIFICATION.md` (generated `*.g.dart`/`*.freezed.dart` changes are formatter-only re-wraps; regeneration may re-drift). T-1 must remain exit 0 after the commit.

### 2.2 Solution - design principle + acceptance contract

**Design principle:** mechanical, zero-behavior commits; secrets never committed; goldens must assert something real.

**Acceptance contract (from master W1.2/W1.3/W1.4):**
1. Commit the existing 136-file `dart format` worktree changes as ONE format-only commit (do NOT hand-edit generated files). `dart format --output=none --set-exit-if-changed .` must exit 0 after.
2. Add to BOTH `.gitignore` (root + core_app): `*.env`, `!.env.example`, `*.keystore`, `*.jks`, `key.properties`, `**/failures/`. `git rm --cached core_app/.env`. Create `core_app/.env.example` (key names only, empty values) + `core_app/android/key.properties.template`.
3. Delete committed `test/golden/failures/**`.
4. Re-capture `test/goldens/kitchen_dashboard.png` OR `test/goldens/delivery_dashboard.png` so the MD5 pair diverges (pump the REAL dashboard widgets; add golden tests under `test/golden/` if none reference them).

### 2.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Format gate green | `dart format --output=none --set-exit-if-changed .` exit 0 |
| T-2 | `.env` ignored | `git check-ignore core_app/.env` = True |
| T-3 | No secrets committed | grep committed files for `sk_|AIza|key.properties` values = 0 |
| T-4 | Golden pair diverges | `Get-FileHash test\goldens\kitchen_dashboard.png` != `Get-FileHash test\goldens\delivery_dashboard.png` |
| T-5 | Golden tests run green | `flutter test test/golden` |

### 2.4 Proof gates

- [ ] T-1..T-5 all green
- [ ] `git status --porcelain` shows no `.env` tracked
- [ ] `test/golden/failures/` absent
- [ ] Universal Gate Set U (index Section 1)

### 2.5 Honest residuals

- The format commit is large (136 files) but mechanical; review it as whitespace-only (no logic diff).
- Golden re-capture may shift pixels on CI vs local (font rendering); if a golden flakes on CI, re-capture on the CI runner and commit - record in addendum.

**PARALLEL MODE (§3.5):** if running in a `cline/task-N` worktree, append the addendum to `FIX_VERIFICATION_cline-task-N.md` in YOUR worktree (never the shared `FIX_VERIFICATION.md`), commit everything in your worktree, and STOP at the end of this spec — predecessor-gating and merge-back are performed on `main` by the operator per §3.5. In sequential mode the line below applies unchanged.

**END OF BATCH CI-2 SPEC** - do not proceed to CI-3 until these gates pass and the CI-2 addendum is appended to FIX_VERIFICATION.md.