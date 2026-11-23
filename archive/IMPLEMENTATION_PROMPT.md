# CARNAMA PRODUCTION-FIX PROMPT — INDEX (the master spec)

**Spec date:** 2026-08-27 · The single authoritative, batched implementation spec for every
VERIFIED problem in `verification_report.md` (§2, §6, §8).

**Source of truth = the CURRENT codebase + `verification_report.md`. `potato*.md` are stale
history.** Re-verify every `file:line` against current source before editing.

**Contract**
- This document is a SPEC. It performs NO code changes.
- One executor session = ONE batch (B0 first). Never advance on a red gate.
- Each batch: run ALL gates, then append its verified addendum to `FIX_VERIFICATION.md`
  (rule 9) BEFORE starting the next batch.
- B6 runs LAST on a clean checkout; its verdict is the ONLY authority on production readiness.

## 0. HARD GATES — any violation fails the batch
1. **Truth over documents.** Done ONLY when code AND a behavior-asserting test prove it.
   Never mark a batch verified from this spec. Code differs → re-verify, cite, amend.
2. **One command per tool call.** PowerShell/cmd-safe. NEVER chain with `&&`/`;`/`|`.
   Grep = `findstr`/`Select-String`. No interactive pagers; emulators only via
   `firebase emulators:exec`.
3. **No stubs / fake success / AI slop.** No placeholder/tautological tests, no silent
   `catch (_)`, no dead code kept, no skipped counts. Delete a weak test only when a
   stronger one replaces it in the same batch.
4. **No hallucination.** Every claim cites `file:line` of CURRENT source; every fix's
   proof cites the exact command + exit code + output line.
5. **Greps = 0** for the batch scope: `FirebaseFirestore.instance` (feature code),
   `FirebaseAuth.instance` (screens), inline `LoggerService()`, `Color(0xFFFF6B35)`,
   literal `$`, `// ignore` (hand-written), `'customerId'` (reservations queries),
   `carnama_unsigned`, `dcqf9qpsq`, `192.168.1.100`, `sk_test_`/`ReplaceMe` (functions/src).
6. **Money/Auth/GDPR/Security FAIL-CLOSED.** In doubt → throw + log + show a clean error.
   NEVER silently succeed, fake a result, or "charge $0".
7. **ZERO skip escapes, ever.** Any new test with `skip:`/`@Skip`/`markTestSkipped` is a
   batch failure. (The pre-existing 2 @Skip patrol files are Batch B4.)
8. **Nothing breaks.** Every batch leaves ALL pre-existing suites green; a regression
   anywhere = fail + revert.

## 1. BATCH MAP (one batch = one agent session, nothing more)
| Batch | Domain | Blocking? | Core outcome |
|---|---|---|---|
| B0 | Firestore rules completeness + REAL rules emulator suite | **P0 RELEASE-BLOCKER** | rules for `reservation_counters`/`waitlist_counters`/`locations`/`settings.restaurantConfig` AND a real `@firebase/rules-unit-testing` suite proves every collection allow/deny |
| B1 | Money integrity + currency | **P0 RELEASE-BLOCKER** | server re-derives tax, server validates promo, currency config-driven (no literal `'usd'`); hostile client impossible |
| B2 | GDPR erasure emulator integration | **P0 RELEASE-BLOCKER** | `gdpr_erasure_test.js` harness fixed → exit 0, 24/24 assertions green |
| B3 | DI hygiene + dead code + suppressions + demo collections | Major/Minor | direct Firestore removed, `// ignore` removed, dead `submitOrderAtomically` gone/aligned, demo collections get rules |
| B4 | Replace skipped tests | Major | zero `@Skip` repo-wide; checkout + reservation flows have real always-run tests |
| B5 | Panic switch DB enforcement | Major | orders write rule refuses when `ordersAccepting == false` + rules-test proof |
| B6 | FINAL CLEARANCE GATE | GO / NOT-GO | full re-verify on a clean run, production-clearance matrix incl. deploy-time (not-provable) items, formal assurance statement + sign-off |

**Order is mandatory:** B0 → B1 → B2 → B3 → B4 → B5 → B6, one batch per session, a
FIX_VERIFICATION.md addendum per batch, report-first, codebase is the final judge. **B5
explicitly DEPENDS on B0's emulator rules suite — never run B5 before B0 is green.**

## 2. MASTER PROBLEM REGISTER (verification_report.md findings → batch)
| finding | Severity | Solved by |
|---|---|---|
| 2.1 counters collections have no rules (booking/waitlist dead) | P0 | B0 |
| 2.2 no real emulator rules test | P0 | B0 |
| 6.2 locations collection no rules | P0 | B0 |
| 8.7 settings/restaurantConfig read+write denied | P0 | B0 |
| 6.1 createPaymentIntent trusts client tax/discount; promo client-only | P0 | B1 |
| 2.6 literal 'usd' in money path | Major | B1 |
| 2.3 GDPR erasure emulator integration RED | P0 | B2 |
| 2.5 direct FirebaseFirestore.instance ×3 | Major | B3 |
| 2.7 three hand-written `// ignore` | Minor | B3 |
| 6.4 dead test-only submitOrderAtomically | Minor | B3 |
| 6.3 demo collections (notifications/notification_queue/audit_logs) no rules | Minor | B3 |
| 2.4 8 skipped tests (2 @Skip patrol files) | Major | B4 |
| 8.9 panic switch not enforced at DB layer | Major | B5 |
| 3.x deploy-time / not-provable (App Check enrollment, live Stripe, fleet, FCM, 500-user load) | gate | B6 decision record |

## 3. UNIVERSAL GATE SET U — EVERY batch applies ALL of these PLUS its own gates
- **U-ANALYZE** `flutter analyze --fatal-infos` (core_app, apps/halal_boyz) + `dart analyze`
  (packages/core, packages/core_ui) → "No issues found!". functions: FN-TSC → exit 0.
- **U-TESTS** ALL pre-existing suites stay green at the end of the batch (core, core_ui,
  halal_boyz, core_app, functions FN-TEST). Zero `skip:`/`@Skip`.
- **U-GREPS** rule-5 list = 0 for the batch scope.
- **U-EMUL** the batch's emulator gates (RULES-EMUL / GDPR-EMUL) GREEN on THIS run (exit 0, no ×).
- **U-REPORT** addendum appended to `FIX_VERIFICATION.md` before the next batch.
- **U-NOBREAK** nothing outside the batch's scope changed; a regression anywhere = fail + revert.

## 4. CANONICAL COMMANDS (CWD column replaces any `cd X;` prefix; copy verbatim into addenda)
| id | CWD | Command | Expected |
|---|---|---|---|
| RULES-EMUL | `core_app/` | `firebase emulators:exec --only firestore "node test/rules/firestore_rules_test.js"` | exit 0, 0 failures |
| GDPR-EMUL | `core_app/` | `firebase emulators:exec --only firestore "node test/functions/gdpr_erasure_test.js"` | exit 0 + `PASSED: 24 FAILED: 0` |
| FN-TEST | repo root | `npm --prefix core_app/functions test` | green |
| FN-TSC | `core_app/functions/` | `tsc --noEmit` | exit 0 |

## 5. FILE LAYOUT (token-lean execution model — load ONLY this index + the current batch)
| File | Contents |
|---|---|
| `IMPLEMENTATION_PROMPT.md` | THIS index: gates (§0), batch map (§1), register (§2), gate set U (§3), commands (§4). No batch bodies. |
| `IMPLEMENTATION_B0..B6.md` | one batch spec each — Problem → Solution → Tests → Gates → Residuals (titles in §1). |
| `FIX_VERIFICATION.md` | append-only verified-addendum ledger (report-only). |

**END OF INDEX.** Load this index + the current batch file per session.

