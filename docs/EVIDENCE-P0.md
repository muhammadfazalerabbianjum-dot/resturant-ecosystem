# EVIDENCE-P0 — the repo's ACTUAL health

Measured 2026-11-07/08 on `cline/p32-golden-gates` @ `7c139d5c`, working tree as
described at the end of this file. Before this document, the only verified fact
about the repo was that `flutter analyze` was clean. Everything below was run,
not inferred.

## Verdict

| # | Command | Result | Wall time | Exit |
|---|---|---|---|---|
| 1 | `flutter analyze --no-pub` (core_app) | PASS, 0 issues | 304.7s | 0 |
| 2 | `flutter test --exclude-tags=e2e,nightly,needs-emulator` | **+2541 tests, "All tests passed"** | 4m35s | 0 |
| 3 | `npm test` (functions: `tsc` + `node --test`) | **172 tests, 172 pass, 0 fail** | ~60s | 0 |
| 4 | `npm run build` (functions) | PASS | 46.4s | 0 |
| 5 | Firestore emulator + rules probe | PASS (see caveat G1) | 8.7s | 0 |
| 6 | `dart run tool/whitelabel.dart … --dry-run` | PASS | 2.6s → 1.3s | 0 |
| 7 | stub scan over changed code | PASS (10 files) | 0.0s | 0 |

**No test failure, build failure or analyzer finding exists in this repo today.**
That is a stronger baseline than the handoff assumed, and it is the single most
important fact P1 will be written against: there is nothing to repair before
adding features.

Raw logs: `checkpoints/logs/baseline-flutter-test.log`,
`checkpoints/logs/baseline-functions-test.log`,
`checkpoints/logs/gate-full-2.log`, plus the gate receipts in `checkpoints/`.

## What each result actually covers

1. **Analyze** — whole `core_app` package including tests. Clean.
2. **Dart tests** — the repo's own documented standard run: everything EXCEPT
   the `e2e`, `nightly` and `needs-emulator` tags (declared in
   `core_app/dart_test.yaml`). 2541 tests, all passing, no skips reported.
   The excluded tiers were **not** run — see G2.
3. **Functions tests** — 172 assertions through `node --test` after a clean
   `tsc` build. This exercises the money guard, idempotency and mapping paths.
4. **Functions build** — `tsc` only; no bundling, no deploy.
5. **Emulator** — the emulator binary IS available on this machine and boots
   (`--project demo-carnama-gate`, no real project touched). It confirms the
   rules file compiles, loads and is enforced (200 on `/menus`, 403 on
   `/users`). It does **not** test rule semantics — G1.
6. **Whitelabel dry-run** — the real Halal Boyz config passes generation
   validation without writing a byte.
7. **Stub scan** — no placeholder markers in any code file changed during P0.

## What was NOT run (and is therefore still unknown)

- `e2e` / `nightly` / `needs-emulator` tagged Dart tests, and any `patrol` suite.
- Any Android/iOS build or release artifact assembly.
- Any Firebase deployment, rules deployment or emulator-based functions test.
- Functions coverage (P0-9 wires the tooling).
- Anything against a real Firebase project or a live Stripe account (forbidden
  by L10, not merely skipped).

## Tree state this reflects

The baseline was taken after P0-1 (`@Tags` + `library;` on seven test files,
`dart_test.yaml`) and P0-3 (doc banners), and **before** P0-5 and P0-6. The code
those two cards added was verified separately afterwards: gate (h) PASS,
gate (e) PASS, targeted validator tests PASS (5 files), and gate (a) PASS.
Nothing in P0-5/P0-6 touched a money path or a widget, so results 2 and 3 above
are not invalidated by them.
