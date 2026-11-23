# BATCH B0 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST - it holds the RULES (Section 0), the Universal Gate Set U (Section 1), environment/decisions (Section 2), and the batch map (Section 3). This file is batch B0's self-contained spec.**

## 0. BATCH B0 - PREFLIGHT BASELINE (no code)

**Predecessor:** none. **Emulator-gated:** no. **Master:** none (baseline only).

### 0.1 Purpose

Establish a clean, re-verified baseline so every later batch diff is attributable. Confirm the repo state still matches the audit corpus BEFORE any fix lands.

### 0.2 Problems to solve (baseline verification - all must still be RED)

| # | Probe | Expected (buggy) state | Command |
|---|---|---|---|
| P-1 | Config routes named by screen-ID | `screen['id']` registration present | `Select-String -Path core_app\lib\app\app_router.dart -Pattern "screen\['id'\]"` |
| P-2 | Broken Navigator API on go_router | `pushNamed`/`pushReplacementNamed` present | `Select-String -Path core_app\lib\main.dart -Pattern 'pushNamed|pushReplacementNamed'` |
| P-3 | Queue enqueues unpaid `confirmed` | `status: OrderStatus.confirmed` + `enqueue('create'` | `Select-String -Path core_app\lib\features\checkout\presentation\checkout_screen.dart -Pattern 'OrderStatus.confirmed|enqueue'` |
| P-4 | Rules deny staff payloads | `hasOnly(['status'])` present | `Select-String -Path core_app\firestore.rules -Pattern "hasOnly\(\['status'\]\)"` |
| P-5 | Client-priced charge | `computeItemsSubtotalCents` sums client `priceCents` | `Select-String -Path core_app\functions\src\payment.ts -Pattern 'computeItemsSubtotalCents'` |
| P-6 | Empty Firebase keys ship | `validate()` has no key gate | `Select-String -Path core_app\tool\whitelabel.dart -Pattern 'firebaseAndroidApiKey'` |
| P-7 | CI undiscoverable | root `.github` absent | `Test-Path <repo>\.github` = False |
| P-8 | No per-client backend | `apps/halal_boyz` has no rules/indexes | `Get-ChildItem apps\halal_boyz -Recurse -Filter 'firestore.rules'` = none |

### 0.3 Additional baseline checks

1. The 136-file `dart format` worktree modification is still present and uncommitted (CI-2 will commit it). `git status --porcelain` count it.
2. Record the current `FIX_VERIFICATION.md` last addendum (B6) and its "GO" line so you can locate the SUPERSEDED annotation to add in CI-1.

### 0.4 Proof gates

- [ ] All P-1..P-8 probes report the expected (buggy) state.
- [ ] Working tree matches the audit description (no post-audit fixes landed).
- [ ] No file modified by this batch.

### 0.5 Honest residuals

- None (baseline only). If any probe is GREEN (bug already fixed), STOP and report - the audit corpus is stale and later batches must be re-derived.

**END OF BATCH B0 SPEC** - do not proceed to CI-1 until these gates pass and the B0 addendum is appended to FIX_VERIFICATION.md.