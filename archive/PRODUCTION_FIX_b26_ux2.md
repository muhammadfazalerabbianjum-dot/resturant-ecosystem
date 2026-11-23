# BATCH UX-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W9.4, W9.5, W9.6, W9.7.**

## 26. BATCH UX-2 - SEMANTICS + LABELS + POPSCOPE + A11Y P2 BATCH

**Predecessor:** UX-1. **Emulator-gated:** no. **Master:** W9.4, W9.5, W9.6, W9.7. **MIRROR: shell carries the badge/checkout - mirror.**

### 26.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `animated_cart_badge.dart:25-58` | Unlabeled cart button + raw count digit, no item-count phrase | P1 (05-P1-A11Y-CART) |
| P-2 | `owner_dashboard.dart:495,525,529,730,771,780`, `home_screen.dart:688`, cart badge | 8 tooltip-less icon-only buttons (incl. 2 destructive deletes) | P1 (05-P1-A11Y-ICONS) |
| P-3 | `order_tracker_steps_widget.dart:26-58` | No step semantics / current-step announcement / English status names | P1 (05-P1-A11Y-TRACKER) |
| P-4 | `checkout_screen.dart` | Back press during payment unguarded -> charge-without-result risk | P1 (05-P1-UX-POPSCOPE) |
| P-5 | a11y P2 set | 48dp add button; home-search hint-only; charts color-only; no textScaler clamp; no autofill/textInputAction; haptics BrandButton-only; empty-state CTAs; RTL dismiss bg; pseudo-plurals; locale-blind DateFormat; raw Colors in 8 files; guideline tests use mocks | P2 (05-P2) |

### 26.2 Solution - design principle + acceptance contract

**Design principle:** label everything interactive; announce state; never lose a charge to a back-press.

**Acceptance contract (from master W9.4/W9.5/W9.6/W9.7):**
1. Cart badge: `tooltip:` + `Semantics(label: loc.cartXItems(n))` + `ExcludeSemantics` on the raw count.
2. Label the 8 icon buttons with loc keys; destructive deletes get confirmation (P2-UX-CONFIRM).
3. Tracker: per-step `Semantics(header: true, selected: isActive, label: loc.orderStatusX(step))` + live region announcing the current step; status names from loc maps (not `.name`).
4. Checkout: `PopScope(canPop: !_isProcessing && !_promoApplying)` + in-flight dialog (mirror `home_screen.dart:41`).
5. P2 set: 48dp add button; home-search `Semantics`; chart value semantics + color-independent encoding; `textScaler` clamp + 2.0x test; `AutofillHints`+`textInputAction`+`onFieldSubmitted` on the 5 forms; haptic on add-to-cart; empty-state CTAs (locations/checkout); RTL mirror on cart dismiss background; pluralized `itemsCount` x3; locale-aware `DateFormat` (pass `loc.localeName`, 5 sites); raw `Colors.*` in 8 files -> theme tokens; real-screen guideline scans replacing mock-only tests (P2-A11Y-ENFORCE).

### 26.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Cart badge semantics | Widget: badge has tooltip + item-count label; count excluded from semantics |
| T-2 | Tracker announcement | Widget: current step has live-region + selected semantics |
| T-3 | PopScope blocks during processing | Widget: processing -> back does not pop; in-flight dialog shown |
| T-4 | textScaler 2.0x | Widget: 2.0x scale -> no overflow (clamped) |
| T-5 | Autofill present | Widget: login/signup fields have AutofillHints + textInputAction |
| T-6 | Real-screen guideline scan | Guideline test pumps real screens (not mocks) |

### 26.4 Proof gates

- [ ] New widget tests green (T-1..T-6)
- [ ] `flutter analyze` + `flutter test` green
- [ ] Goldens re-captured if affected
- [ ] Universal Gate Set U (index Section 1)

### 26.5 Honest residuals

- TalkBack/VoiceOver were not run on device (static audit) - the semantics tests are code-level; a device screen-reader pass is a RELEASE-2 item.
- The 8 icon-button list is from the audit inventory; grep `IconButton(` again to catch any stragglers the audit may have missed.

**END OF BATCH UX-2 SPEC** - do not proceed until these gates pass and the UX-2 addendum is appended to FIX_VERIFICATION.md.