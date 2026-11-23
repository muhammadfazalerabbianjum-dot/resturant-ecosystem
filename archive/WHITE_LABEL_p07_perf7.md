# WHITE_LABEL_p07_perf7.md — PERF-7 (feature-floor coverage wave, phase 2)

Status: EXECUTING 2026-09-16 · Base: `d1bd8e3` · Predecessor: PERF-6a phase 1 (DONE — dish/router)
Mandate: the remainder of the original PERF-6a scope — per-feature behavioral coverage on the audited uncovered masses.

## Window → territory (B-2 disjoint; all extension of EXISTING suites)
| Window | Target file (unc) | Deliverable |
|---|---|---|
| cline-1 | `owner_dashboard.dart` (166) | Role-update success/failure logging, branch-editor save, panic-banner render — extends `owner_dashboard_tabs_test.dart` pattern |
| cline-2 | `delivery_dashboard.dart` (101) | no-branch guard, available-orders cards + Assign-to-me (doc mutation asserted), my-orders tab — extends `delivery_dashboard_test.dart` |
| cline-3 | `reservation_screen.dart` (60) | party-size validator boundaries, capacity fallback (missing doc/field), branch fail-closed, submit success — extends `reservation_screen_test.dart` |
| cline-4 | `cart_screen.dart` (59) | empty state, item rows, quantity stepper (provider save asserted), remove, pending-sync badge, checkout navigation — capturing cart repo (dish-test pattern) |
| cline-5 | `menu_screen.dart` (33) + `menu_provider.dart` (8) + `dish_detail_screen.dart` (29) | search/category/popular/vegan filters, add-to-cart from menu, provider error path — extends `menu_screen_test.dart` |

## Explicit scope-outs (recorded)
- `menu_repository.dart` (34%) — needs an Isar test harness that does not exist (batch2 is model-only). Registered as its own spike; NOT faked here.
- `app_bootstrap.dart` (63%) — init composition; partially covered by main_test/bootstrap_states tests; deeper coverage = separate batch.
- 6e mutation spike + 6f product features — unchanged standing items.

## Acceptance
Standard per-window gates (format/analyze/targeted suites) + merge cadence + consolidated addendum + post-merge full battery + **per-feature lcov deltas reported** (target: measurable lift on all five features; floors re-checked).
