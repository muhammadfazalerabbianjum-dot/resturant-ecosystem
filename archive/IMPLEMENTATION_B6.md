# BATCH 6 — FINAL CLEARANCE GATE (GO / NOT-GO)

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST. **Must run LAST on a clean checkout. No new fixes.**

## SCOPE
Re-verify everything once, close the master register, and produce the AUTHORITATIVE
production-readiness verdict. Any red box → NOT-GO with the exact list; do not advance.

## CLOSURE CHECKLIST (every item must PASS; 0 pending)
- [ ] **B0** — rules for `reservation_counters`/`waitlist_counters`/`locations`/
      `settings.restaurantConfig` present + RULES-EMUL green.
- [ ] **B1** — server re-derives tax, `applyPromo` server-validates, currency config-driven;
      `'usd'` grep = 0; money-equality + refund intact.
- [ ] **B2** — GDPR-EMUL green (exit 0; 24/24).
- [ ] **B3** — `FirebaseFirestore.instance` in feature code = 0; hand-written `// ignore` = 0;
      dead `submitOrderAtomically` gone/aligned; demo collections have rules.
- [ ] **B4** — zero `@Skip`/`skip:`/`markTestSkipped`; checkout + reservation have real
      always-run tests.
- [ ] **B5** — orders accepted gate at DB; rules test proof.
- [ ] **Full monorepo suites green on ONE clean run** — `flutter analyze --fatal-infos`
      (core_app, halal_boyz), `dart analyze` (core, core_ui), FN-TSC, `flutter test`
      (core 14 / core_ui 20 / halal_boyz 6 / core_app all + 0 skipped), FN-TEST (17/17).
- [ ] **All greps 0** (rule 5 list + `'usd'` + skip search).
- [ ] **Deploy audit** — `package.json:7 main:lib/index.js` matches a fresh `tsc` build;
      `firebase.json` predeploy builds; no stale root `functions/index.js`; emulator suites
      are the ones CI runs.
- [ ] **Fallbacks register CURRENT** — every `// TODO_DEPLOY:` / `OFFLINE_FALLBACK`
      (dispatchToFleet, tax fallback table, NFC, panic-server-guard decision) documented with
      its gate; NONE fakes success.

## PRODUCTION-CLEARANCE MATRIX (deploy-time / NOT-PROVABLE statically)
One line each: status + owner decision. NONE may be silently assumed fixed.
- App Check enrollment on EVERY shipped platform + `strongAppCheck` flag decision (rules
  currently relaxed OR-mode, `firestore.rules:30-35`; callables strict).
- Live Stripe webhook smoke on a real test API key; confirm idempotency + refund in prod.
- Real fleet dispatch (dispatchToFleet is a TODO_DEPLOY fallback today — not production).
- FCM push delivery on real devices for all localized keys.
- **500-user load/capacity test — NONE exists. MUST be planned + executed before any "500 users"
  claim.** Record target RPS/concurrency + actual measured numbers.
- Multi-currency decision (B1 done; record which currencies + tax tables are seeded).

## FORMAL ASSURANCE STATEMENT (GO only)
> I have verified, by reading the code and running the suites on a clean checkout, that every
> P0 and Major in verification_report.md is closed and proven by behavior tests; money/auth/
> GDPR/security paths are fail-closed; the real rules + erasure emulator suites and all
> package/app suites are green on this run; deploy entry matches source; and residuals are
> limited to the recorded deploy-time items above (App Check enrollment, live Stripe smoke,
> fleet, FCM, 500-user load test), which do not silently fake success.

## SIGN-OFF
- [ ] **GO** — all boxes above green on THIS run; assurance statement signed, dated.
- [ ] **NOT-GO** — list every red box (P0/Major) with file:line + the exact failing command;
      a red box ⇒ the owning batch is not closed and B6 is not re-run until it is.

**END OF BATCH 6 — END OF SPEC.** B6's verdict is the only authority on production readiness.