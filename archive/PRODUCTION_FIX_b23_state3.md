# BATCH STATE-3 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W8.8, W8.6.**

## 23. BATCH STATE-3 - THUMBNAILS + FIRST-FRAME BOOT

**Predecessor:** STATE-2. **Emulator-gated:** no. **Master:** W8.8, W8.6.

### 23.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `home_screen.dart:380,748`, `menu_screen.dart:174-188`, `cart_screen.dart:125-138` | List sites download FULL-RES Cloudinary originals (decode capped via memCacheWidth but network bytes + disk cache = originals) | P1 (04-P1-IMG) |
| P-2 | `dish_detail_screen.dart:90-104` | Hero uncapped + Hero flight from 50 px rows -> double decode | P2 (04-P2-3) |
| P-3 | `main.dart:252` + `force_update_guard.dart:61-65` | Cold-start first frame blocked behind `fetchAndActivate()` (<=10 s spinner, no retry affordance) | P1 (04-P1-BOOT) |

### 23.2 Solution - design principle + acceptance contract

**Design principle:** transform at the CDN (Cloudinary) via a pure helper; never block the first frame on a network fetch.

**Acceptance contract (from master W8.8/W8.6):**
1. New pure helper `String cloudinaryThumb(String url, {required int width})` in `packages/core` (beside `cloudinary_upload_service.dart`): inserts `w_<w>,q_auto,f_auto` after the FIRST `/upload/` segment only when no transform segment already follows it; passthrough for signed/non-Cloudinary URLs.
2. Wire the 4 list sites (400/150/100/100); dish-detail hero gets `memCacheWidth` + scoped Hero decode.
3. Move the version check into `splashInitProvider` as a parallel future (splash already bounds 30 s + fail-open + retry, `splash_screen.dart:18-33,63-70`); the labs `ForceUpdateGuard` renders `child` immediately, re-checks on mount non-blocking, shows the lock ONLY when `required`.

### 23.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Thumb URL corpus | Unit: double-insert guard (URL already transformed), signed passthrough, non-Cloudinary passthrough |
| T-2 | Thumb bytes < original | Integration assert: fetched thumbnail bytes << original |
| T-3 | First frame is the app | Boot widget test: no spinner; app renders immediately |
| T-4 | Lock renders when required | Widget: RC says required -> lock screen |
| T-5 | Hero decode capped | Code read: `memCacheWidth` on dish-detail hero |

### 23.4 Proof gates

- [ ] Thumbnail URL unit tests green (T-1)
- [ ] Boot widget test green (T-3, T-4)
- [ ] `flutter analyze` + `flutter test` green
- [ ] Affected goldens re-captured
- [ ] Universal Gate Set U (index Section 1)

### 23.5 Honest residuals

- Cold-start ms is NOT measured here (no device profiling) - a mid-range Android profile is a RELEASE-2 evidence item.
- Cloudinary console-side eager transforms (option B) compose with the helper later (zero code needed) - not required for this batch.

**END OF BATCH STATE-3 SPEC** - do not proceed until these gates pass and the STATE-3 addendum is appended to FIX_VERIFICATION.md.