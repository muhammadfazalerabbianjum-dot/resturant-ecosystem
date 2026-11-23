# WHITE_LABEL p24 — UI-15: SETTINGS SURFACE (language choice, appearance, notification preference)

**Batch:** UI-15 (p24). **Closes:** `F3-01` (locale switcher: code-supported, 0 UI controls), `F3-02` (theme mode:
`toggle()` has 0 external callers), `F3-04` (end-user notification settings: only merchant tone/opt-in text exists)
— register §2.3, owner column `p24_settings`.
**Predecessors:** UI-8 (p18, merged) — p18 hardened the `ar` *quality*; p24 supplies the *choice*. UI-6 (p16) and the
widget libraries are merged, so `SettingTile` and the token layer are stable.
**Floor:** `git merge-base --is-ancestor 765874c HEAD` must exit 0 (rule W2b: a sync claim is valid only with this
proof quoted).
**Runs concurrently with UI-7 (p17)** — §5.7 carries the disjointness proof. `p17` owns
`features/{menu,cart,checkout,admin}/**` event lines; p24 owns `features/profile/**`, the `app_bootstrap.dart`
locale wiring and `packages/core_ui` settings state.

## §0 Rules (inherited p10 §0 0.1–0.7 + fleet laws W1–W7 + R-W/R-X/R-Y)

### Batch laws
- **L-P1 (a preference the user cannot reach is a defect; a preference that lies is worse).** Every control added
  here must change the running app *in that session* and survive a restart. A tile that writes a key nothing reads
  is `F3-01` all over again — the red→green test must assert the **consumer**, not the write.
- **L-P2 (fail-safe defaults, never a new boot path).** No setting may introduce a new boot failure mode. With no
  stored value the behaviour is exactly today's: `ThemeMode.light` (`theme_provider.dart:6`) and **system/device
  locale** (no `locale:` argument — `app_bootstrap.dart:888-902`). A stored value applies only when valid for
  `AppLocalizations.supportedLocales`; unknown/removed locale falls back to system.
- **L-P3 (the crash path stays dumb).** `buildGracefulErrorWidget` (`app_bootstrap.dart:296-304`) is the
  `ErrorWidget` fallback. It **must not** gain provider, prefs or locale dependencies; it keeps rendering under the
  device locale and a test pins that. Recorded residual: the crash fallback is English on an Arabic device.
- **L-P4 (persistence lives where the dependency already is).** `shared_preferences` is already declared in
  `packages/core_ui/pubspec.yaml`, `packages/core/pubspec.yaml` and `core_app/pubspec.yaml`; **no pubspec change is
  allowed in this batch**. State both clients need (core_app *and* apps/halal_boyz, which inherits via `CoreApp`)
  belongs in `packages/core_ui`; app-only state stays in `core_app/lib/app/`.
- **L-P5 (no first-frame lie, no blocking boot).** Hydration of a stored preference is **non-blocking**: no new
  `await` in the boot sequence, and it must not be able to throw into boot. A stored `dark`/`ar` value may therefore
  apply one frame after first paint — the accepted cost, asserted by a test (first frame = L-P2 default, then the
  stored value).
- **L-P6 (RTL and goldens).** New rows render correctly under `ar` (logical edges only) and must not shift the
  existing golden inventory. A legitimately changed golden is regenerated **explicitly** and every regenerated file
  is listed in the report; goldens are never regenerated just to make a diff disappear.
- **L-P7 (single source of truth for strings).** All new user-visible text comes from the ARB pair
  (`core_app/lib/l10n/app_en.arb` + `app_ar.arb`) with real Arabic for `ar` (p18's `ARABIC_REVIEW_CHECKLIST.md`
  applies); no literal, no concatenation. `apps/halal_boyz/lib/l10n/**` stays untouched (19-key shell parity).


## §1 Baseline (P1 — verified on `765874c` this session, file:line)

- **Locale:** `core_app/lib/app_bootstrap.dart:896-902` registers `AppLocalizations.delegate` +
  `GlobalMaterial/Widgets/Cupertino` delegates and `supportedLocales: AppLocalizations.supportedLocales`
  (`Locale('ar')`, `Locale('en')`). There is **no `locale:` argument anywhere** and **no locale notifier class
  exists** repo-wide (`class .*Locale.*(Provider|Notifier|Controller)` → 0 hits), so language follows the device
  only. A second, unrelated `MaterialApp` sits at `app_bootstrap.dart:302-304` — the crash fallback (L-P3).
- **Theme:** `packages/core_ui/lib/src/theme/theme_provider.dart` — `ThemeModeNotifier extends Notifier<ThemeMode>`
  (`:4`), `build() => ThemeMode.light` (`:6`), `void toggle()` (`:7-8`), `themeModeProvider` (`:11`). Exactly **one**
  consumer in shipped code: `app_bootstrap.dart:886` (`ref.watch(themeModeProvider)` → `themeMode:` at `:894`). No UI
  control calls `toggle()` and nothing persists the choice, so `ThemeMode.dark` is unreachable in a release build:
  that is `F3-02`.
- **Settings host:** `core_app/lib/features/profile/presentation/profile_screen.dart` (178 lines) already hosts the
  privacy-adjacent settings block and its own comment names it the host — `:142-145`: "This privacy-adjacent surface
  (same block as the Art.20 export/delete) is the settings host for it." Rows are
  `Semantics(... button: true, child: SettingTile(icon:, title:, onTap:))` (`:146-161` clear-logs, `:164-172`
  delete-account). `SettingTile` is `packages/core_ui/lib/src/ui/setting_tile.dart:15`, reached through the barrel
  (`profile_screen.dart:4` → `import 'package:core_ui/core_ui.dart';`).
- **Preference I/O precedent (copy it, do not invent a new mechanism):** direct
  `await SharedPreferences.getInstance()` inside the feature that owns the value —
  `app/compliance/gdpr_consent_dialog.dart:31/:38/:43`, `features/onboarding/presentation/onboarding_screen.dart:26`,
  `features/checkout/domain/checkout_service.dart:162/:234`. No preference-provider abstraction exists today; if one
  is introduced it is introduced **once** and reused, never per screen.
- **l10n parity gate:** `core_app/test/l10n/app_localizations_parity_test.dart` requires en == ar key-for-key
  (measured 655/655 at the post-p18 wave-5 base `61ff5a9`; the earlier "532" was a placeholder). `enterReferralCode` was removed by p18 C-3 and must not reappear in either ARB.
- **Notifications today:** `PushNotificationService.initialize()` (`app_bootstrap.dart:700`), its `navigationHandler`
  bridge (`:767`) and the cold-start tap consumer (`:871-878`); the only end-user-facing copy is the generic FCM
  description `AppConfig._kDefaultFcmDescription` (`app/config/app_config.dart:52`), plus the **merchant-side**
  `notificationTone` in `app/models/restaurant_config_model.dart:32`. No end-user notification preference exists
  anywhere — that gap is `F3-04`.
- **GDPR consent is not a notification setting:** `kGdprAnalyticsConsentKey` (read fail-closed at
  `telemetry_service.dart:59`) gates **analytics only**. p24 must not conflate the two; consent is not a preference
  this surface may toggle.
- **Suites/limits:** CI tier is `flutter test --exclude-tags=e2e,nightly,needs-emulator`; the plain-tier count on
  merged main is **2262** and must not drop. Fleet requirement: 100% line coverage on every file this batch adds.

## §2 Non-goals (do NOT build these here)

- **No new settings screen or route.** Rows go into the existing profile settings block
  (`profile_screen.dart:142-172`); `RouteNames`/`app_router.dart` are untouched. `F3-01` is a *reachability*
  finding, not a request for a redesign.
- **No currency control.** `F3-03` is closed as by-design white-label (register `D-4`): no UI, no config key.
- **No server-side notification unsubscribe.** See D-P24-1: option (a) only.
- **No referrals surface and no guided tour.** `F3-05` was closed by removal (p18 C-3 + p25 T-4); the tour
  (`F3-06`) is p21's decision.
- **No `ar` quality edits.** p18's plurals, locale-aware currency and RTL sweep are merged; p24 adds only its own
  new keys and never rewrites existing Arabic values.
- **No consent toggle.** GDPR analytics consent keeps its own dialog and fail-closed read (`telemetry_service.dart:59`).


## §3 T-x tab (each task: RED receipt → GREEN receipt, one commit per task)

| Task | Scope | Acceptance evidence |
|---|---|---|
| **T-1** | **Language row.** New locale state in `packages/core_ui/lib/src/settings/` holding `Locale?` where `null` = follow system; `setLocale(Locale?)` persists (SharedPreferences, L-P4) and notifies. Wired into the **one** `MaterialApp.router` as `locale:` (`app_bootstrap.dart:888-902`) and surfaced as a `SettingTile` row pair (English / العربية) in the profile settings block. Hydration per L-P5. | RED then GREEN: tapping العربية flips `Directionality` to RTL and `Localizations.localeOf` to `ar`; a persisted `ar` survives re-creation of the container (restart proof); an unsupported stored value falls back to system (L-P2). |
| **T-2** | **Appearance row.** `ThemeModeNotifier` (`theme_provider.dart:4`) gains `setMode(ThemeMode)`; `toggle()` is removed or re-pointed so no dead API remains — F3-02's "0 external callers" must become "1 real control". `build()` keeps `ThemeMode.light` (L-P2); the chosen mode is persisted and re-hydrated. Row offers Light / Dark / System. | RED then GREEN: `setMode(ThemeMode.dark)` changes the live `MaterialApp.themeMode`; the stored value is re-read after restart; with nothing stored the mode is `light`. `test/widget/dark_mode_test.dart` stays green **untouched**. |
| **T-3** | **Notification preference row** (`F3-04`), conservative scope: one stored boolean consumed in **exactly one** shipped place — the foreground local-echo path `packages/core/lib/src/network/push_notification_service.dart:205-208` → `_onForegroundMessage` (`:206`). When off, the local echo is skipped. Background/tap paths (`:211`, `:218-223`) and delivery are **untouched**; no token unregistration; nothing under `functions/**`. | RED then GREEN using the existing injectable seams (`foregroundMessages:` stream `:191`, `localNotifications:` `:190`): a pushed `RemoteMessage` produces **0** local-notification `show()` calls with the preference off and exactly **1** with it on. The report states plainly that this is a client-side courtesy switch, **not** a server unsubscribe. |
| **T-4** | **ARB pair + generated l10n** for every string T-1..T-3 adds, in real Arabic, then `flutter gen-l10n`. | Parity test green (en == ar key-for-key: measured 655/655 at the wave-5 base `61ff5a9`, 672/672 after the lane = +5 p17 keys, +12 p24 keys, none removed; the earlier "532 -> 532+n" was a placeholder); no `enterReferralCode` resurrection; no literal in any widget. |
| **T-5** | **Reachability proof (the closer for `F3-01`/`F3-02`/`F3-04`).** A test that fails if a setting is unreachable or writes a key nothing reads (L-P1): asserts the three `SettingTile`s exist in the profile subtree and that each write has a named consumer. | The guard is shown to FIRE on a mutated tree (mutation receipt) and PASS on the correct tree. |
| **T-6** | **Docs + report:** `tool_uilib/p24/p24_report.md`, `tool_uilib/p24/RUNBOOK_SETTINGS.md` (what each preference does and does **not** do — including "no server unsubscribe" and L-P3's English crash fallback), paste-ready `## APP COMPLETION UI-15 (p24)` block. | Report carries per-T receipts, six-way classification, DECISIONS, honest UNVERIFIED, DRIFT. |

## §4 Deliverable

`tool_uilib/p24/p24_report.md`: per-task evidence, six-way classification (fixed / deferred / accepted /
false-positive / decision-needed / drift), DECISIONS-NEEDED-FROM-OWNER, honest UNVERIFIED, DRIFT, paste-ready
`## APP COMPLETION UI-15 (p24)` ledger block. **Never edit `FIX_VERIFICATION.md`** — the coordinator appends blocks.


## §5 Acceptance gates (all green on the batch tip, receipts in `tool_uilib/p24/`)

- `dart analyze` (packages/core, packages/core_ui) + `flutter analyze --fatal-infos` (core_app, apps/halal_boyz)
  → 0 issues, exit 0. `dart format --output=none --set-exit-if-changed .` → 0 changed.
- Suites, default tier: core_app **≥ 2262, no drop**, core_ui **≥ 391**, core **≥ 364**, halal_boyz **≥ 71** — all
  exit 0, **0 skip markers**. Functions: `npx tsc --noEmit` exit 0, `npm test` 169/169 (a change there is a scope
  violation, not a win).
- New-file coverage 100% lines. Every new ARB key in **both** ARBs. Forbidden paths (`functions/**`,
  `firestore.rules`, `*.rules`, `FIX_VERIFICATION.md`, `pubspec.*`, `tool_guard/**`) → 0 hits.
- **halal_boyz inheritance proof:** the shell gains the settings rows with **zero shell edits** (it renders
  `CoreApp`); record it as a receipt. If the shell needs an edit, STOP and report — that contradicts the whitelabel
  contract and means the state was put in the wrong package (L-P4).
- **Golden inventory unchanged**; any legitimately changed golden is regenerated explicitly and listed.

### §5.6 Owner decision carried with this spec — **D-P24-1**

**Question:** does the end-user notification setting (a) suppress only the client-side foreground echo, as T-3
specifies, or (b) also unsubscribe the device from server-sent pushes once a server-side preference exists?
**Default = (a).** Option (b) needs a Cloud Function write plus a rules change (both outside p24's territory) and
would contradict the "delivery untouched" acceptance. The executor implements (a), records (b) as the owner's
follow-up, and the tile copy must not promise more than (a) delivers (L-P1).

### §5.7 Territory (exclusive) + the p17 disjointness proof

MODIFIED: `core_app/lib/app_bootstrap.dart` (locale argument + hydration only) ·
`core_app/lib/features/profile/presentation/profile_screen.dart` (three rows) · `core_app/lib/l10n/app_en.arb` +
`app_ar.arb` + generated `core_app/lib/l10n/app_localizations*.dart` · `packages/core_ui/lib/src/theme/theme_provider.dart` ·
`packages/core/lib/src/network/push_notification_service.dart` (the single foreground gate) ·
`packages/core_ui/lib/core_ui.dart` (barrel, only if a new file is exported).
NEW: `packages/core_ui/lib/src/settings/**` · tests per touched file · `tool_uilib/p24/**`.

FORBIDDEN: `core_app/lib/features/{menu,cart,checkout,admin}/**` (p17's files), other `features/**` screens,
`theme/**` token files, `functions/**`, rules, `pubspec.*`, `FIX_VERIFICATION.md`, `apps/**`.

**Disjointness proof vs UI-7 (p17).** p17's declared territory: `packages/core/lib/src/analytics/analytics_service.dart`,
`packages/core/lib/src/analytics/ecommerce_events.dart`,
`core_app/lib/features/menu/presentation/{menu_screen,dish_detail_screen}.dart`, `cart_screen.dart`,
`features/checkout/**`, `features/admin/presentation/{analytics_snapshot,analytics_provider}.dart`. p24 touches
`packages/core/lib/src/**network**` (not `analytics`), `packages/core_ui` (p17 touches neither), and
`features/profile/**` (not in p17's list). **Intersection = ∅.** Re-verify with `git diff --name-only main...HEAD` in
both worktrees before merging; a real overlap means STOP and report, not a hand-edited compromise.

## §6 Judge + close

Coordinator re-runs the battery, spot-checks ≥3 (language flip RTL + restart persistence, theme mode live change,
the foreground-echo red→green with the injected stream), and appends the ledger block. Honest UNVERIFIED allowed:
on-device *visual* quality of the new rows beyond goldens, and real FCM behaviour (no live FCM in tests).

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-15 (p24), settings surface, in worktree <repo>-cline-2 on branch cline/w5-p24.
Read <repo>\WHITE_LABEL_p24_settings.md IN FULL - binding contract. Inherits p10 §0 0.1-0.7 + L-P1..L-P7.
1. SYNC (fail-closed): git merge --ff-only main; quote `git merge-base --is-ancestor 765874c HEAD` (exit 0 required);
   record tip + suite counts. BLOCKER: analyze x4 = 0, format 0 changed, core_app/core/core_ui/halal green 0 skip
   BEFORE any edit. Failure => STOP with an evidence table.
2. RED per task (T-1..T-5) into tool_uilib/p24/red_t*.txt, each failing for the right reason.
3. GREEN per task; one commit per task; receipts green_t*.txt. dart fix; format; suites green 0 skip; analyze 0.
4. T-4 ARB pair + flutter gen-l10n; parity green. T-6 report + runbook + paste-ready ledger block.
5. GATES: new files 100% lines; forbidden paths 0; goldens unchanged; halal shell inheritance proof.
6. REPORT: tool_uilib/p24/p24_report.md per §4. NEVER touch FIX_VERIFICATION.md. NEVER merge or push.
```


