# BASELINE-GAP — what the green baseline does NOT cover

Zero tests failed in the P0 baseline (`docs/EVIDENCE-P0.md`). This file records
the opposite risk: everything that is green **without proving anything**, so no
later card mistakes silence for safety.

Triage tags: `P1-FIX` (should be fixed in Phase 1) · `DEFER-TO-PHASE` (belongs
to a named later phase) · `BLOCKS-P1` (Phase 1 cannot be honest until resolved).

---

## G1 — There is no real Firestore rules test in this repo
- **Command involved:** the card's emulator gate (d).
- **Suspected cause:** `core_app/test/firestore_emulator_rules_test.dart` builds
  documents with `fake_cloud_firestore`. It never contacts the emulator and never
  evaluates a rule. Its own header says so: *"we will simulate the rules tests by
  constructing our local logic tests … For true rule testing, a node.js script
  with @firebase/rules-unit-testing is recommended."*
- **Proof it proves nothing:** a deliberately invalid `match` block appended to
  `core_app/firestore.rules` left that suite green in 32.2s
  (run `20261108T170157Z`).
- **What replaced it:** gate (d) now runs `tool/rules_probe.mjs` — 200 on
  `/menus`, 403 on `/users` — which fails in 11.4s on the same plant.
- **Still missing:** any test of rule *semantics* — tenant isolation, field
  allowlists, role/branch scoping.
- **Tag:** `BLOCKS-P1`. Phase 1 touches rules; P0-8 builds the cross-tenant case
  generator, and the `@firebase/rules-unit-testing` harness has to exist before
  a rules change can be called verified.

## G2 — The e2e / nightly / needs-emulator tiers are unmeasured
- **Command involved:** the standard Dart run excludes all three tags.
- **Suspected cause:** by design — those tiers need an emulator, a device or a
  Patrol driver, none of which the baseline run used.
- **Impact:** 2541 green tests say nothing about the excluded files. Their real
  state is UNKNOWN, not "passing".
- **Tag:** `DEFER-TO-PHASE` — re-measure when a device/emulator lane exists.

## G3 — `test/rules/firestore_rules_test.js` is never executed by anything
- **Command involved:** none — that is the problem.
- **Suspected cause:** it is a JavaScript file in a Dart test tree; `flutter
  test` ignores it and no npm script points at it.
- **Impact:** an unrun test is worse than no test: it looks like coverage.
- **Tag:** `P1-FIX` — either wire it into a gate or delete it, with the decision
  recorded.

## G4 — Gate (b) covers 7 of ~2541 tests
- **Command involved:** `flutter test --tags gate_fast`.
- **Suspected cause:** deliberate — the card's smoke set is config-schema and
  money-path contracts so a per-card gate costs ~5 minutes, not ~5+ minutes of
  everything.
- **Impact:** a regression outside those seven files is caught only at a phase
  boundary, not per card. This is a known, accepted trade rather than a defect.
- **Tag:** `DEFER-TO-PHASE` (re-tune at the P1 kickoff).

## G5 — Nothing verifies the deployed rules of any Firebase project
- **Command involved:** none, by law L10.
- **Impact:** `core_app/firestore.rules` could be correct and
  `demo-tenant` could still be running last month's rules. Gate (h) proves
  the *files* agree with each other, not with production.
- **Tag:** `BLOCKS-P1` for any claim of the form "the client is secure" — it
  needs a deploy-time comparison, which P0 must not do.

## G6 — Thermal printing is claimed done and does not exist
- **Command involved:** `git grep -i thermal` across all branches and worktrees.
- **Suspected cause:** the implementation lives somewhere outside this repo or
  does not exist.
- **Impact:** Phase 2 receipts cannot be planned as "already built".
- **Tag:** `BLOCKS-P1` — tracked as Q-001 for the owner; `DEFERRED.md` H2 now
  says UNBUILT until the path is produced.
