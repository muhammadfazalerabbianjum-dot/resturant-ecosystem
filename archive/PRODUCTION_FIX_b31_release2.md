# BATCH RELEASE-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W11.4, W11.5.**

## 31. BATCH RELEASE-2 - FULL GATE BATTERY + RE-AUDIT + OVERALL PASS DECISION

**Predecessor:** ALL code batches + RELEASE-1. **Emulator-gated:** all emulator suites. **Master:** W11.4, W11.5. **Report-only final pass.**

### 31.1 Purpose

Prove the whole tree is green, re-run every audit verdict, and make the OVERALL PASS decision honestly.

### 31.2 Acceptance contract (from master W11.4/W11.5)

1. Run the FULL gate battery: `flutter analyze --fatal-infos` (core_app, halal_boyz); `dart analyze` (both packages); `flutter test` all four (0 fail, 0 skip); functions `npm run lint` + `npx tsc --noEmit` + `npm test`; emulator battery `npm run test:rules` (extended total), `npm run test:money-emulator`, GDPR emulator suite; `dart format --output=none --set-exit-if-changed .` exit 0; ALL grep gates; `git status` clean apart from intentional docs/ledger.
2. Re-run each of the 9 audit prompts' verdict steps against the fixed tree (report-only). Update each verdict row in `PRODUCTION_READINESS_AUDIT_MASTER.md` to PASS with a one-line evidence pointer to its batch addendum.
3. OVERALL = PASS only when (a) all 9 rows PASS and (b) the master section-12 VERIFY-IN-CONSOLE checklist is done OR explicitly scheduled with an owner. If (b) is not done, OVERALL stays FAIL with the checklist noted as the sole remaining gate - do NOT falsely mark PASS.
4. Append the final `## REMEDIATION RELEASE-2 - FINAL CLEARANCE - VERIFICATION REPORT`.

### 31.3 Tests / evidence

| # | What it asserts | How |
|---|---|---|
| E-1 | Full battery green | All commands above exit 0 |
| E-2 | Every audit verdict re-run | 9 sections -> PASS rows with evidence pointers |
| E-3 | OVERALL decision honest | PASS only if (a) AND (b); else FAIL with the single remaining blocker named |
| E-4 | Ledger complete | Every batch addendum present (B0..RELEASE-1) + final addendum |

### 31.4 Proof gates

- [ ] Full battery green (E-1)
- [ ] Master verdict rows updated (E-2)
- [ ] OVERALL decision recorded with the checklist state (E-3)
- [ ] Final addendum appended (E-4)
- [ ] Universal Gate Set U (index Section 1)

### 31.5 Honest residuals

- The VERIFY-IN-CONSOLE checklist (master section 12) is NOT executable from the repo: App Check production claims, per-client backend provisioning, Stripe live, index deployment, ownerInfo seeding, alerting sink, store presence, Remote Config. If any is unscheduled, OVERALL stays FAIL - that is the honest state, not a shortcut.
- Runtime device profiling (cold start, scroll, memory) is a RELEASE-2 evidence item that requires hardware - schedule it with an owner.

**END OF BATCH RELEASE-2 SPEC - this is the final batch. The OVERALL decision is the deliverable.**