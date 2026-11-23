# CARNAMA LABS — PERFORMANCE & RESPONSIVENESS AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify startup time, build efficiency,
image strategy, list virtualization, jank sources, and memory behavior in the Carnama Labs
template (`core_app`) and domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Should be fast" is not evidence; measure or cite code.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every screen, every list, every image, every rebuild path. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A 3-second cold start or a janky menu scroll is an
   uninstall on the spot. Mid-range Android hardware is the baseline, not an iPhone 15 Pro.

---

## 1. SCOPE

### 1.1 Cold Start & App Boot

**Files to audit:**
- `core_app/lib/main.dart` (full boot sequence)
- `core_app/lib/app/config/app_config.dart` (`loadConfig`)
- `core_app/lib/features/splash/presentation/splash_screen.dart`
- `packages/core/lib/src/**` init calls invoked from main
- `core_app/android/app/src/main/AndroidManifest.xml` (Application class, splash theme)

**Verify:**
- [ ] Boot timeline: list EVERY `await` before first `runApp` frame (config load, Firebase init,
  Isar open, FCM token, dotenv) with file:line — anything over ~50ms must be lazy or parallel
- [ ] Is Isar opened lazily or at boot? If at boot: on the UI isolate? (blocking = FINDING)
- [ ] Firebase.initializeApp: only once; await ordering documented
- [ ] Splash has a hard timeout: if config/auth resolution hangs, does the user escape?
  (splash with unbounded await = FINDING)
- [ ] First frame: is Home rendering the full menu synchronously, or loading progressively?
- [ ] Any `WidgetsFlutterBinding.ensureInitialized()` ordering bugs

### 1.2 Rebuild Hygiene

**Files to audit:**
- EVERY screen in `core_app/lib/features/**/presentation/*.dart`
- `core_app/lib/app/brand_drawer.dart`, `core_app/lib/app/animated_cart_badge.dart`

**Verify:**
- [ ] `ref.watch` inside `build` of huge widgets: is the WHOLE screen rebuilding on cart tick?
  List watch scopes that are too broad (e.g. watching whole cart list when only count needed)
- [ ] `.select(` usage: verify granular selectors where heavy providers are watched
- [ ] ListView vs Column: any scrollable list built with `Column` inside `SingleChildScrollView`
  (no virtualization) — list EVERY instance with expected item counts
- [ ] `ListView.builder` used for menus/orders — verify `itemExtent` or prototype item where
  lists are large (100+ items)
- [ ] const constructors on screens rebuilt per frame (spot-check the 10 hottest: home, menu,
  cart, checkout, order tracker, kitchen, owner)
- [ ] AnimatedBuilder/AnimatedContainer misuse causing continuous rebuilds
- [ ] Any `Timer.periodic` at high frequency driving UI (polling interval documented + justified)

### 1.3 Image Strategy

**Files to audit:**
- EVERY image call site (`Image.network(`, `CachedNetworkImage(`, `Image.asset(`, `FadeInImage(`)
- `packages/core/lib/src/upload/cloudinary_service.dart` (image transform params)
- Menu item thumbnails (the highest-traffic images in the app)

**Verify:**
- [ ] Menu thumbnails request Cloudinary transform params (resize + quality) — full-res originals
  in list rows = FINDING
- [ ] `cacheWidth`/`cacheHeight` (ResizeImage) set for asset images in lists
- [ ] `CachedNetworkImage` with `memCacheWidth` for list thumbnails
- [ ] Every network image has placeholder + errorBuilder
- [ ] Image disk cache config: bounded size? (unbounded = device storage fill)
- [ ] Hero animations: image sizes matched to avoid double-decode

### 1.4 Memory & Leak Behavior

**Files to audit:**
- Cross-reference AUDIT_STATE_DATAFLOW.md §1.2 findings (leaks are perf issues too)
- `packages/core/lib/src/cache/isar_service.dart` (unbounded collections?)

**Verify:**
- [ ] Isar collections that grow unboundedly (sync queue DLQ, presence, analytics events) —
  list retention/TTL policy per collection; missing = FINDING
- [ ] Firestore `.snapshots()` with `includeMetadataChanges: true` (extra rebuilds)
- [ ] Pagination: every Firestore-backed list uses limit + startAfter (or equivalent) —
  full-collection fetch = FINDING. List every query with its limit.
- [ ] Large JSON parse on UI isolate (menu sync payload) — does it move to an isolate?
- [ ] `precacheImage` usage sane (not pre-caching every image)

### 1.5 Navigation Performance Under Config Mode

**Files to audit:**
- `core_app/lib/app/app_router.dart` (config-mode route table build)

**Verify:**
- [ ] All screen builders are LAZY (routes build widgets on demand, not a map of instances)
- [ ] No work in route builder closures beyond widget construction
- [ ] Guard/redirect logic (auth, force update) is O(1) per navigation — no Firestore read on
  every navigation hop (verify with code: what reads happen in redirects?)

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). Static findings are mandatory; runtime claims (measured ms, jank) REQUIRE a test or
profiler run, otherwise mark "NOT PROVEN — needs profiling on mid-range device".

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] Boot-sequence await chain fully enumerated?
- [ ] Every scrollable list classified (virtualized / not) with expected item count?
- [ ] Every Firestore query's limit documented?
- [ ] Every image call site classified (transform / full-res)?
- [ ] No perf claim without code citation or explicit NOT-PROVEN marker?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**