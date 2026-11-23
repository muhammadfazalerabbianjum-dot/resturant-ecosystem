# AUDIT — HALAL BOYZ CLIENT APP vs THE FLEET (anomaly hunt, owner-commissioned)

**Method:** every claim P1 (file:line opened this session). Scope: `apps/halal_boyz/**` + its config + the inheritance graph into `core_app`/`packages/*`.

## §1 VERIFIED — the client inherits the fleet correctly (the good news, receipted)

1. **Automatic inheritance of everything we built.** Shell deps are path/workspace: `core`, `core_ui` (`../../packages/…`), `labs` (`../../core_app`) — so p16 adoption, p17 analytics, p18 Arabic hardening, p20 wave 2 flow into halal_boyz with **zero shell changes** (P1: `apps/halal_boyz/pubspec.yaml`).
2. **Production localization wiring is correct:** `MaterialApp.router` in `core_app/lib/app_bootstrap.dart:788-802` carries `localizationsDelegates` (App + Global Material/Widgets/Cupertino) + `supportedLocales: AppLocalizations.supportedLocales` = **`Locale('ar')`, `Locale('en')`** (generated file). RTL mirrors from the locale; shell lib has **zero** hand-coded LTR hazards (grep empty).
3. **Token consumption that IS configured:** typography split (`headingFont: PlayfairDisplay`, `bodyFont: Inter`), **CTA stadium (`ctaRadius: 100`)**, maroon palette (`primary 0xFF900000`, secondary/accent orange), navigationBar theming (`0xFF1A1A1A` bg / `0xFFFFA500` active), darkTheme neutrals — the b10 contract delivered.
4. **Demo mode is fail-safe:** `kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false)` (`demo_config.dart:37`) — production unless explicitly opted in via dart-define.
5. **Admin dev-PIN empty = fail-closed:** `admin_access_service.dart:45` — empty/absent pin disables the dev-PIN path; access falls back to Firebase role auth (covered by `app_config_no_pin_test.dart`).
6. **Shell test armor present:** 11 test files incl. checkout-honesty, constitution-guard, firebase-gate, demo-mode-wiring, core-config-adapter.

## §2 ANOMALIES FOUND (the "severely lacking" list — every item ends FIXED / OPERATOR-ACCEPTED / spec'd)

| # | Severity | Anomaly | Evidence | Fix path |
|---|---|---|---|---|
| F-1 | **HIGH (visual)** | **Confetti palette is the GENERIC default** (red/navy/peach/teal `E63946/1D3557/F4A261/2A9D8F`) — not the client's maroon/orange brand. Order-success celebration is brand-mismatched. | `apps/halal_boyz/assets/client_config.json` `theme.confettiOverlay.colors` = the default quartet | CONFIG-ONLY: set the palette to brand hues in the client config (+ golden re-capture). Candidate for the p16 visual-review round. |
| F-2 | MEDIUM (visual) | **`components.input` unconfigured** → the menu search field, checkout and auth inputs render Material-default chrome, not brand theming (b10 built the input token; this client doesn't consume it). | config `theme.components.input` = all null/absent | CONFIG-ONLY (b10 key exists and is fail-safe). |
| F-3 | MEDIUM (visual) | **`components.chip` + `shape.smallRadius` unconfigured** → category filter chips use default radius/style. | config `theme.components.chip`, `theme.shape.smallRadius` absent | CONFIG-ONLY. |
| F-4 | MEDIUM (visual) | **`background.color`/`overlayAsset` unconfigured** → no branded scaffold backdrop, although the `ScaffoldBackground` mechanism (b10) is live in every screen. | config `theme.background` absent | CONFIG-ONLY (client supplies the art asset — ops decision). |
| F-5 | **MEDIUM-HIGH (product, Gulf-critical)** | **No in-app language switcher and no configured default locale.** Language follows the DEVICE locale only — an Arabic-first Gulf client's English-phone users can never see Arabic (and vice versa). p18 hardens *quality*; the *toggle/default* is a product feature that does not exist yet. | repo-wide grep: no `Locale('ar')` override / language-toggle UI outside the generated file; config has no `locale` section | Small feature batch: config `locale.default` key + settings-row toggle (uses `themeModeProvider`-style state), fail-safe default = system locale. Owner decision required. |
| F-6 | LOW | **`animationStyle` unconfigured** → silently `full` (the b10 default). Fine, but it is an unreviewed per-client choice. | config `theme.animationStyle` absent | CONFIG-ONLY (deliberate choice per client). |
| F-7 | LAUNCH (known family) | **`stripePublishableKey: "pk_test_REPLACE_ME_USE_DART_DEFINE"`** placeholder in the client config; `devAdminPin` empty (fail-closed, fine). The W6.1 shell gate (`_placeholderKeyPattern = REPLACE_ME\|changeme\|<your`, `client_config_loader.dart:11-12`) and the checkout-honesty test govern fakes; the real key lands at deploy day. | config `environment` block; loader gate | Already owned by `RUNBOOK_DEPLOY.md` (Stripe step) — U-2 family. |
| F-8 | PROCESS (prevents recurrence) | **Nothing audits config *visual completeness*.** F-1..F-4, F-6 all exist because the validator checks *validity*, not *brand completeness* — the next client will silently inherit the same gaps. | generator `validate()` = fail-closed on INVALID, silent on MISSING optional visual keys | Recommend: a WARNING-level completeness pass in the generator (`validate()` emits warnings for unset optional visual keys: input/chip/smallRadius/background/animationStyle/confetti palette ≠ default) — surfaces gaps at stamping time. New tool batch, no behavior change. |

## §3 Verdict

The shell is architecturally CLEAN — thin wrapper, correct inheritance, fail-safe gates, zero stubs. The lacking parts are exactly where the owner suspected: **brand-expression gaps in the client's config** (F-1..F-4, F-6 — all config-only, all invisible until you look) and **one missing product feature** (F-5 language toggle). F-8 is the systemic fix that stops these recurring for every future client.

## §4 Disposition proposal (owner picks)

- **p16.5 (config polish, tiny):** F-1..F-4 + F-6 for halal_boyz — one config edit + goldens + owner visual review; fold into p16's visual-review round.
- **p21 (language toggle feature):** F-5 — config `locale.default` + settings toggle + tests.
- **p22 (generator completeness warnings):** F-8 — tool batch.
- F-7 remains deploy-day (RUNBOOK_DEPLOY).