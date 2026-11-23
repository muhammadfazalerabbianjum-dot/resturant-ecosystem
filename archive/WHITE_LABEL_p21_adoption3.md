# WHITE_LABEL_p21_adoption3 — UI-13: ADOPTION WAVE 3 (checkout+tip, splash/onboarding/tour, auth, locations, delivery tracker, compliance) — MAIN, SINGLE EXECUTOR

**Purpose:** the written owner of the last unwritten adoption rung. `AUDIT_COHERENCE_LADDER.md` §2 rows **M-1..M-6 + M-8** are this wave's territory; **M-7 (every staff/admin surface) is `p22_staff`**. It also owns register row **F3-07** ("10 of 81 surfaces UNASSIGNED"), the customer-facing residue of the adoption-gap family (**F3-09** spinner · **F3-10/-11/-12/-15** ListTile/Card/raw-TextField/decorated-Container), and the two owner decisions routed here by the Stage-3 triage register: **D-2** (delete the `referrals` flag — a flag with no surface is a false promise) and **D-3** (wire the guided tour that was built and left unwired).

**Predecessors:** UI-6 (`p16`) merged **and** UI-10 (`p20`) merged **and** UI-11 (`p23`) merged. Every component this wave adopts exists as of `c838d7e`; the **binding API contract is `tool_uilib/p23/p23_report.md` §8** — read that section before writing a line of adoption code. `p17_analytics1` owns the analytics surfaces and also writes event lines inside `checkout/**`: **p17 must never run concurrently with this wave** (it lands before or after, never beside).

## §0 Rules (inherited p16 §0 verbatim — 0.8..0.10 + L12..L15 — plus p20 L16, plus L28..L32)

Carried from `WHITE_LABEL_p16_adoption1.md`: main-only single executor; read-mostly (`core_ui` seams only as receipted red->green fallout); presentation-only. **L12 visual floor** (token colors, `Gap`/`AppDimensions` spacing, entrance motion, skeletons, >=48x48 dp with >=8 dp separation, before/after golden pairs -> owner visual review) · **L13 money-display parity** (positive/known-code strings byte-identical; divergences = DECISIONS + goldens; totals display-only) · **L14 behaviour preservation** (Semantics, l10n en+ar parity, existing flows) · **L15 no new dependencies** · **L16 live-state sanctuary** (order-state logic, timers, Firestore listeners/streams, seat decrements, waitlist ordinals, sync-queue paths untouchable).

### Customer-journey laws

**L28 TIP-CHAIN CHARGE PARITY (the consumer half of p23's L24).** `TipSelector` computes NOTHING (`p23_report.md` §8 W-1): it receives `List<TipOption<T>>` carrying **caller-preformatted** strings and returns the caller's own selection. The tip amount that reaches the order must be derived through the SAME provider/service path as today — adoption changes what the customer SEES, never what is CHARGED. Required receipt: a red->green test proving the tip value handed to the checkout path is **byte-identical** before/after the rewrite, plus a source scan proving ZERO new arithmetic on cents in the presentation layer.

**L29 CHECKOUT WRITE-PATH SANCTUARY.** `checkout_service.dart`, the idempotency path (`IdempotencyConflictException` and its user-facing rendering), promotion application, tax and order creation are **untouchable**. `checkout_screen.dart` (927 lines — M-1, the largest hand-rolled UI in the app) is the ONLY checkout file this wave may rewrite. The `LiveMapPickerWidget` composed at `checkout_screen.dart:87` is preserved, never re-implemented.

**L30 FIRST-RUN WIRING WITHOUT BEHAVIOUR CHANGE (D-3).** The guided tour is built, tested and l10n-complete, but `tour_overlay.dart:8-13` self-documents that no gate presents it. D-3 = **present it at the documented decision point** (`TourManager.shouldShowTour`, `features/tour/domain/tour_manager.dart:8`), never re-invent the tour, never change `shouldShowTour` semantics, never fake a first-run flag. The wiring is receipted by a red->green test proving (a) the tour is presented when the decision point says yes, (b) nothing is presented when it says no, (c) the first-run flag is written exactly once (idempotent, Law 9).

**L31 LOCATION / PERMISSION PRESERVATION.** `location_screen.dart`, `pin_drop_map_screen.dart` and the geolocation permission flows keep their behaviour and error handling exactly as-is. The library's `LiveMapPickerWidget` is the single map implementation — no second map widget, no new dependency.

**L32 CUSTOMER-ONLY SWEEP BOUNDARY (the F3-09..F3-15 partition).** The adoption-gap sweeps split by AUDIENCE, not by convenience: this wave owns every **customer-facing** occurrence; every occurrence inside `features/admin/**` (staff/operator surfaces) belongs to `p22_staff` and is **out of bounds here** — record it as a handoff row, never edit it. Dispatch-time measurement (2026-09-28, `core_app/lib`): `CircularProgressIndicator` **73 occurrences / 30 files** · `ListTile` **27 / 13** · raw `TextField(` **12 / 4** · `BoxDecoration` **7 / 6** · `showModalBottomSheet` **5 / 2** (F3-13's adoption half — `BrandSheet` exists now). The executor re-measures at SYNC and reports before/after counts **split by audience**.

## §1 Baseline (P1 — measured at dispatch 2026-09-28, re-measure at SYNC)

| Surface | Lines at dispatch | Register row / note |
|---|---|---|
| `features/checkout/presentation/checkout_screen.dart` | **927** | M-1 CRITICAL — money-critical, largest hand-rolled UI; contains `LiveMapPickerWidget` (L29, L31) |
| `features/checkout/presentation/tip_selector_widget.dart` | 106 | M-1 / W-1 — superseded by library `TipSelector` (L28) |
| `features/splash/presentation/splash_screen.dart` | 148 | M-2 — first impression; already routed (`app_router.dart:53-54, 347`) |
| `features/onboarding/presentation/onboarding_screen.dart` | 74 | M-2 / W-5 — routed (`app_router.dart:55-56, 355`) |
| `features/tour/presentation/tour_overlay.dart` | 115 | M-2 / D-3 — **built but unwired** (self-documented at line 8) |
| `features/auth/presentation/login_screen.dart` | **505** | M-3 — second-most-visited surface |
| `features/auth/presentation/signup_screen.dart` | 299 | M-3 |
| `features/auth/presentation/terms_of_service_screen.dart` | 100 | M-3 — wording is compliance, verbatim |
| `features/locations/presentation/location_screen.dart` | 79 | M-4 (note: **`locations/` plural** here) |
| `features/location/presentation/pin_drop_map_screen.dart` | 137 | M-4 (note: **`location/` singular** here) |
| `features/tracking/presentation/delivery_tracker_screen.dart` | 201 | M-5 — customer tracking tail; NOT the staff `admin/.../delivery/delivery_dashboard.dart` (p22) |
| `features/compliance/presentation/delete_account_screen.dart` | 124 | M-6 — GDPR wording verbatim |
| `features/admin/presentation/privacy_policy_screen.dart` | 103 | M-6 — the ONLY `features/admin/**` file in this wave's territory |
| `features/orders/presentation/order_tracker_steps_widget.dart` | 81 | M-8 / W-2 — superseded by library `OrderTimeline` (`order_tracker_screen.dart` itself stays p20's) |

**Verified-reachable, adoption-audit-only (F3-07 tail):** `LogsScreen` (`app_router.dart:112-113, 524, 626`) and `BugReporterOverlay` (`app_bootstrap.dart:904`) are **already wired** — F3-07 lists them as "unassigned surfaces"; this wave's job is a red->green reachability test + `core_ui` token conformance, not a rebuild.

**Separate ownership inside checkout:** `p17` adds analytics event lines to `checkout/**`; this wave rewrites `checkout_screen.dart`. **They must not run concurrently.**

## §2 Territory (exclusive)

MODIFIED (presentation only; every file enumerated in the report's territory table at SYNC):
`core_app/lib/features/checkout/presentation/{checkout_screen.dart, tip_selector_widget.dart}` · `features/splash/presentation/splash_screen.dart` · `features/onboarding/presentation/onboarding_screen.dart` · `features/tour/presentation/tour_overlay.dart` (+ the presentation gate that presents it; `features/tour/domain/tour_manager.dart` is read-only) · `features/auth/presentation/{login_screen.dart, signup_screen.dart, terms_of_service_screen.dart}` · `features/locations/presentation/location_screen.dart` · `features/location/presentation/pin_drop_map_screen.dart` · `features/tracking/presentation/delivery_tracker_screen.dart` · `features/compliance/presentation/delete_account_screen.dart` · `features/admin/presentation/privacy_policy_screen.dart` · `features/orders/presentation/order_tracker_steps_widget.dart` · customer-facing sweep files per L32 (named individually in the report) · `app/config/feature_flags_service.dart` + `core_app/assets/client_config.json` + `core_app/test/core/config/feature_flags_service_test.dart` + `core_app/test/core/feature_flags_test.dart` (D-2 only).

NEW: tests under `core_app/test/**` named per phase · goldens under the existing golden dirs (en+ar, light+dark variants where the surface is first-run or money-facing) · `tool_uilib/p21/**`.

MODIFIED (additive fallout only, red->green receipted): `packages/core_ui/lib/src/ui/**` seams + their tests, **only** where a p23 component genuinely needs a documented seam. `p23`'s contract is frozen (`p23_report.md` §8); a seam here is a DECISIONS entry, not a convenience.

FORBIDDEN: every other `features/admin/**` file (p22) · `features/admin/presentation/analytics/**` (p17) · staff surfaces `kitchen/**`, `admin/presentation/delivery/**`, `manager/**`, `setup/**`, `gateway/**`, `dead_letter_screen.dart`, `admin_menu_manager.dart`, `role_router_screen.dart`, `role_gate.dart`, `reservations/presentation/admin_reservations_tab.dart` (p22) · `features/orders/presentation/order_tracker_screen.dart` + `order_history_screen.dart` (p20, shipped) · `features/profile/**`, `loyalty/**`, `waitlist/**`, `reservations/presentation/reservation_screen.dart` (p20, shipped) · `checkout/domain/**`, `checkout_service.dart`, all `*_provider.dart`, services, repositories, sync-queue paths (L16, L29) · `theme/**` · `packages/core_ui/lib/src/theme/**` · `FIX_VERIFICATION.md` · `pubspec.*` · `functions/**`, `firestore.rules`, `storage.rules` · `apps/**` · `l10n/app_en.arb` / `app_ar.arb` (p18 owns ARB; this wave reuses existing keys — a missing string is a BLOCKER + handoff, never an inline literal).

### §2 Amendment A1 (coordinator ruling, 2026-09-28) — the W-5 page-announcement key

**Ruling: `AppLocalizations.onboardingPage(page, total)` DOES NOT EXIST and p23 §8 W-5 is defective on that point. Wire BOTH builders from the existing, en+ar-parity key `trackerStepOfTotal(int step, int total)`. This is not a blocker; the wave proceeds.**

Verified basis (coordinator, this session, repo-wide `git grep`):
- `p23_report.md:192` (the binding contract) mandates `AppLocalizations.of(context).onboardingPage(page, total)`.
- `onboardingPage` appears **nowhere**: zero hits in `core_app/lib/l10n/app_en.arb`, `app_ar.arb`, the generated `app_localizations.dart`, or any test/package. The mandate references a key that has never existed.
- The whole `onboarding*` ARB family is `onboardingWelcome` (`app_en.arb:116`) and `onboardingDescription` (`app_en.arb:117`) — a single-page Welcome screen today (`onboarding_screen.dart:74`). There is **no** `*page*` key of any kind in `app_en.arb`.
- p21 may not add it: `§7` line 92 ("p18 owns the ARB files - reuse existing keys, never inline a literal").

PERMITTED (and nothing more):
1. `core_app/lib/features/onboarding/presentation/onboarding_screen.dart` — adopt `OnboardingShell` (W-5) and wire **both** caller-owned builders from one existing localized key:
   - `pageLabelBuilder: (page, total) => loc.trackerStepOfTotal(page, total)` (`app_en.arb:721` "Step {step} of {total}", `app_ar.arb:736` "الخطوة {step} من {total}"; both `int` placeholders — the signature matches the 1-based `page`/`total` exactly, with no string coercion).
   - `pageDotLabelBuilder: (page) => loc.trackerStepOfTotal(page, total)` — `pageDotLabelBuilder` receives only `page`, so close over `total = pages.length`. It MUST be wired too: `kOnboardingPageDotLabel` (`core_ui/lib/src/ui/onboarding_shell.dart:17`) is English-only and `p23_report.md:193` says a localized call site must pass it. Omitting it puts English "Go to page N" on the Arabic hot path — the same defect as omitting the page label.
2. Routing/timing/flag logic is untouched (§3 C1/C3 boundaries unchanged). No ARB file may be edited.

WHY NOT THE ALTERNATIVES:
- **Omit `pageLabelBuilder` (accept the fallback):** `kOnboardingPageAnnouncement` (`onboarding_shell.dart:6-12`) is documented *"never this English fallback on a localized hot path"*, and §5's gate is l10n en+ar parity. Rejected outright.
- **`tourStepCounter(current, total)`:** String/String placeholders, semantically bound to the guided-tour overlay (`tour_overlay.dart:37`), so it would misname a first-run pager as a tour step and needs `toString()` coercion. Not chosen.
- **Pause the wave until p18 adds the key:** p18 has not been dispatched; an existing fully-localized key satisfies the accessibility contract today. Stalling buys nothing and the ARB gap is recorded below as a Law 26 handoff instead.

ACCEPTED COUPLING (disclose it, do not hide it): `trackerStepOfTotal` is shared with the order-tracker announcement (`order_tracker_steps_widget.dart:38`). If p18 ever rewords it for the tracker, onboarding wording changes silently — that is p18's obligation to split (handoff row below).

REQUIRED RECEIPTS (beyond the §4 list):
- a semantics test asserting the live-region label equals `trackerStepOfTotal(1, N)` in **en AND ar** for an N-page carousel, plus an assertion that it is **not** `kOnboardingPageAnnouncement`/`kOnboardingPageDotLabel` (proves the wire, not the prose);
- the two builder wires shown in the `onboarding_screen.dart` diff;
- a `git status`/`git diff` proof that no ARB file and no generated `app_localizations*.dart` was touched;
- the `git grep onboardingPage` receipt (the basis for this ruling) pasted into the report's BLOCKER section.

BLOCKER RECORD (report it, do not fix it): the defect is in **p23 §8 W-5**, not in p21 — it mandates a nonexistent key. p23's contract text is superseded by this amendment for adoption purposes. Owner: p18 (key creation) with the p23 contract line corrected in the same change.

HANDOFF ROW (owner **p18**): add `onboardingPage(int page, int total)` and `onboardingPageDot(int page)` to **both** `app_en.arb` and `app_ar.arb` (identical placeholder types), then swap the two builders in `onboarding_screen.dart` to the dedicated keys and delete this reuse.


## §3 Phases -> T-x table (each phase: red->green receipt + goldens; commit per phase, never end on red)

| Phase | Tasks | Acceptance |
|---|---|---|
| **A — checkout + tip (M-1)** | A1: `checkout_screen.dart` -> library composition (`BrandCard`/`SectionHeader`/`Gap`, token spacing, entrance motion) with the screen's structure preserved while the hand-rolled presentation is replaced. A2: `tip_selector_widget.dart` -> **deleted in favour of** `TipSelector`/`SegmentSelector` (W-1) with caller-preformatted option labels and `selectedSummaryLabel` (L28). A3: the `LiveMapPickerWidget` composition is preserved verbatim (L31). A4: failure surfaces rendered through `InfoBanner`/`BrandDialog` — the `IdempotencyConflictException` message path itself is unchanged (L29). | checkout suite green; **L28 charge-parity test green** (tip value byte-identical); source scan shows zero new cents arithmetic; goldens pair (light+dark); `checkout_service`/`checkout/domain` untouched (git-diff proof). |
| **B — order tracker timeline (M-8)** | B1: `order_tracker_steps_widget.dart` -> `OrderTimeline` (W-2) with `TimelineStepState` mapping and caller-localized timestamps; the current-step semantics announcement is preserved. | tracker step tests green; tracking state-machine tests untouched and green; goldens pair; `order_tracker_screen.dart` (p20's) unmodified. |
| **C — first run: splash + onboarding + tour (M-2, D-3)** | C1: `splash_screen.dart` -> `BrandedSplash` (W-5), routing/timing logic untouched. C2: `onboarding_screen.dart` -> `OnboardingShell` (W-5) with the **1-based** `pageLabelBuilder` **and** `pageDotLabelBuilder` wired from `trackerStepOfTotal` — the `onboardingPage` key that `p23_report.md` §8 W-5 mandates does not exist in the ARB files; see **§2 Amendment A1** for the ruling, the en+ar parity proof, the required receipts and the p18 handoff. C3: **D-3 wire the tour** at the `shouldShowTour` decision point, exactly once and idempotent, and update the now-stale self-documenting comment at `tour_overlay.dart:8-13` to state the new reality (Law 19). | first-run tests green (present / not-present / flag-written-once); goldens pair (en+ar); `tour_manager.dart` semantics unchanged (git-diff proof). |
| **D — auth funnel (M-3)** | D1: `login_screen.dart` (505) -> library composition (`BrandCard`, `BrandTextField`, `BrandButton`, `InfoBanner` for errors, skeletons). D2: `signup_screen.dart` (299) same treatment. D3: `terms_of_service_screen.dart` -> brand shell with the **wording byte-identical** (compliance copy is not a style choice). | auth suite green (validation/auth-flow tests untouched); goldens pairs; TOS string-parity test green. |
| **E — locations + maps (M-4)** | E1: `location_screen.dart` (79) -> `SettingTile`/`SectionHeader`/`EmptyStateWidget` composition. E2: `pin_drop_map_screen.dart` (137) -> brand chrome around the existing `LiveMapPickerWidget`; permission and error paths byte-identical (L31). | location tests green (permission-denied + unavailable paths covered); goldens pair; no new dependency (L15). |
| **F — delivery tracker (M-5)** | F1: `delivery_tracker_screen.dart` (201) -> `OrderTimeline` for the customer-facing progress model + `StatusTile`/`BrandBadge` states + skeletons; **tracking/listener logic untouched** (L16). F2: every error path renders `GlobalErrorWidget`/`InfoBanner`, never a raw trace. | tracking tests green (live-state/timer suites untouched and green — git-diff proof); goldens pair. |
| **G — compliance + the F3-07 tail (M-6)** | G1: `delete_account_screen.dart` (124) -> brand shell with **GDPR wording verbatim**; the destructive-action confirmation uses `BrandDialog(moneyConfirming: false)` — an explicit, deliberate `false` because this is not a money action (record it in DECISIONS). G2: `privacy_policy_screen.dart` (103) -> readable brand typography. G3: `LogsScreen` + `BugReporterOverlay` reachability red->green tests (already wired — prove it, do not rebuild). | compliance tests green (wording parity); reachability tests green; goldens pairs. |
| **H — D-2 + the customer-side adoption sweep (F3-05, F3-09..F3-15)** | H1: **remove the `referrals` flag** (`feature_flags_service.dart:12`, `core_app/assets/client_config.json:42`) and update `feature_flags_service_test.dart` / `feature_flags_test.dart` to assert its absence; verify the parser tolerates the orphan key still present at `apps/halal_boyz/assets/client_config.json:43` (`apps/**` is forbidden — record it as a **p25 handoff row**, do not edit it). H2: sweep every **customer-facing** `CircularProgressIndicator` (F3-09), raw `ListTile` (F3-10), raw `Card` (F3-11), raw `TextField` (F3-12), decorated `Container` (F3-15) and `showModalBottomSheet` (F3-13's adoption half -> `BrandSheet`) per L32, with every file named in the report. | sweep counts before/after reported with the audience split; flag-removal tests green; every touched file's suite green 0 skip; goldens pairs wherever a visual change is claimed. |
| **I — close** | I1: full battery (analyze ×3, format, all suites 0 skip, rules/functions untouched-verification via git). I2: coverage floors (core_ui 100% held; core_app aggregate >= baseline). I3: the visual-review pack (before/after pairs per surface; every `before` re-rendered from `git show <pre-commit>:<path>` and hash-matched — the p20 DRIFT-5 standard). I4: report §4. | every §5 item green. |

## §4 Deliverable

`tool_uilib/p21/p21_report.md`: territory table (every touched file with line count before/after); per-phase evidence; **L28 charge-parity proof** (tip value byte-identical + the zero-new-arithmetic scan); **L29 sanctuary proof** (git-diff showing zero edits under `checkout/domain`, services, providers); **D-3 wiring proof** (present / not-present / written-once); **D-2 flag-removal proof**; the F3-09..F3-15 sweep table with the customer/staff audience split **and the p22 handoff rows**; visual-review pack index; six-way classification; DECISIONS-NEEDED-FROM-OWNER; UNVERIFIED (non-empty allowed); DRIFT; handoff table; paste-ready `## APP COMPLETION UI-13 (p21)` block.

## §5 Acceptance

Identical gate set to p20 §5: analyze ×3 + format 0 · all suites green **0 skip**, no drop · l10n en+ar parity · W9 a11y suite · ban test · coverage floors · goldens deliberately re-captured (inventory in the report; no forced greens) · tracking/state-machine tests untouched and green · `git status` proves zero forbidden paths.

Additionally for this wave: the L28 charge-parity test green · the L29 sanctuary diff empty · the D-3 three-case test green · the D-2 flag-absence test green · the sweep reported with the audience split.

## §6 Judge + close

Coordinator re-runs the battery; reviews the visual-review pack WITH the owner (appeal verdict = owner's); spot-checks >=3 (the L28 charge-parity test, the D-3 present/not-present proof, the checkout `LiveMapPickerWidget` preservation, the D-2 flag absence); appends the ledger block. **This wave closes register rows `F3-05` (D-2), `F3-06` (D-3), `F3-07` (the 10 unassigned customer surfaces), `F3-09`, and the customer-facing halves of `F3-10/-11/-12/-13/-15`, plus coherence-ladder rows `M-1..M-6` and `M-8`.** Scope note (verified against the register, not assumed): the staff/operator halves of the same gaps (`M-7`, `F3-14`) are `p22_staff`'s; the analytics surfaces are `p17`'s; the ARB/locale work is `p18`/`p24`'s.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-13 (p21), ADOPTION WAVE 3 (checkout+tip, tracker timeline, splash/onboarding/tour, auth, locations/maps, delivery tracker, compliance, referrals-flag removal, customer-side sweep), MAIN ONLY.
Read <repo>\WHITE_LABEL_p21_adoption3.md IN FULL - binding contract. Inherits p16 §0 (0.8-0.10 + L12-L15) + p20 L16 + L28-L32.
ALSO READ tool_uilib/p23/p23_report.md §8 - the frozen consumer contract for every component you adopt.
Predecessors: p16 merged AND p20 merged AND p23 merged (dispatch floor: `git merge-base --is-ancestor c838d7e HEAD` == 0).
DO NOT run while p17 is running (both write checkout/**). p18 owns the ARB files - reuse existing keys, never inline a literal.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts + the §1 line counts + the F3-09/-10/-11/-12/-15 counts. BLOCKER: analyze x3 + format + all suites green 0 skip BEFORE any edit. Failure => STOP, evidence table.
2. ENUMERATE territory (§2) into the report's territory table (P1) - including the audience split for every sweep row and the handoff rows you will NOT touch.
3. RED per phase; GREEN in order A checkout/tip -> B timeline -> C first-run+tour -> D auth -> E locations -> F tracker -> G compliance -> H flag+sweep; commit after EACH phase; never end on red.
4. L28: the tip selector computes nothing - prove the charged tip value is byte-identical and that no new cents arithmetic exists in presentation.
5. L29: git-diff proof of zero edits under checkout/domain, checkout_service, providers, services, queue paths.
6. L30 (D-3): present the EXISTING tour at the documented decision point; three-case red->green proof; never change shouldShowTour semantics.
7. L31/L32: no second map implementation; every features/admin/** occurrence is a handoff row, never an edit.
8. GATES (I1): analyze x3 + format + ALL suites 0 skip; l10n + a11y + ban; coverage floors; goldens inventory; forbidden paths 0.
9. REPORT: tool_uilib/p21/p21_report.md per §4 (territory table, L28/L29/D-2/D-3 proofs, sweep table + handoffs, pack index, six-way, UNVERIFIED, DECISIONS, DRIFT, paste-ready UI-13 ledger block). NEVER touch FIX_VERIFICATION.md.
10. COMMIT final + battery on the tip; push only if credentials cached; owner reviews the visual pack before close.
DoD: §5 green + visual pack ready + receipts committed + green committed tip + nothing uncommitted.
```

**END OF UI-13 SPEC — the customer journey is now owned end-to-end.**



