# WHITE-LABEL RELEASE-2R SPEC - RE-RUN ON THE FINAL TREE (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. §3.5/§3.6 — RELEASE-2R is NOT window work: it runs on `main` only, after the final merge; its verdict is the only clearance authority).**

## RELEASE-2R - FINAL BATTERY + RE-AUDIT + OVERALL VERDICT (take 2)

**Predecessor:** ALL (ARCH-1, ARCH-2, COV-1..5). **Emulator-gated:** yes (full battery). **Territory:** main only (report-only + verdict updates).

### Acceptance contract
1. Run the FULL gate battery on the post-fleet tree: analyze ×4, format, all test suites (core_app / packages / shell — 0 fail, 0 skip), functions lint+tsc+test, emulator battery (rules + money + GDPR + migrations, serialized), all G0 greps.
2. Measure coverage (was 53.11%) — record the new number.
3. Re-run the 9-audit verdict rows in `PRODUCTION_READINESS_AUDIT_MASTER.md` with evidence pointers to the new addenda (ARCH-1/2, COV-1..5).
4. OVERALL decision per RELEASE-2 §31.2: PASS only if all rows pass AND §12 is done/owner-scheduled. Otherwise FAIL naming the sole blocker.
5. **PRODUCT GAP REGISTER (mandatory):** extract EVERY handoff / feature gap / honest residual recorded across `FIX_VERIFICATION.md` (all batch addenda) into one consolidated, actionable table appended to the RELEASE-2R addendum — columns: `# | Gap | Where documented (ledger line) | Class (batch-closeable · new feature · operator decision) | Owner | Suggested fix`. Known seed entries: waitlist `leaveWaitlist` flow absent (COV-3 H-1), login errors silently swallowed (COV-4 H-1), tour dismiss persistence not implemented (COV-2), loyalty display clamp + `~/` precision (COV-4), W9.1 palette byte-sync (TOKENS/CORE-COV handoffs), GH001 origin-push history rewrite (operator). Nothing may be silently dropped: every ledger handoff must appear in the register as fixed, scheduled, or explicitly accepted.
6. **ANOMALY HARVEST (§3.7.1):** every class-(a)/(b) register row is spawned as an anomaly batch spec (`WHITE_LABEL_anom_<NN>_<tag>.md`, standard skeleton) and executed through the §3.7.2 loop-to-fixed-point (full battery re-run after each wave; max 3 loops, then FAIL naming blockers); class-(c) rows become operator runbook entries with exact steps.
7. **A–Z ATTESTATION (§3.7.3):** the final addendum carries the attestation matrix (aspect | rerunnable proof command | result at final tip | ledger line) and is signed with the final tip hash.
8. Append `## APP COMPLETION RELEASE-2R - ...` to `FIX_VERIFICATION.md`; commit on main.

### Honest residuals (expected, carried forward)
- §12 console checklist (needs client Blaze/Stripe) — the likely sole remaining blocker.
- Real-device verification, iOS/macOS build, live Stripe — unchanged.

**END OF RELEASE-2R SPEC.**