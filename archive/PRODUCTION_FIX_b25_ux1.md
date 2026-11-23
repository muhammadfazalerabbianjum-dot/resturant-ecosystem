# BATCH UX-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W9.1, W9.2, W9.3.**

## 25. BATCH UX-1 - AA CONTRAST + ARB MIGRATION + MONEY FORMATTER

**Predecessor:** any (distinct files; after BACKEND-2 is cleanest for linked goldens). **Emulator-gated:** no. **Master:** W9.1, W9.2, W9.3. **MIRROR: configs + core_ui shared; shell regenerated carries both.**

### 25.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `brand_button.dart:74-77` + config `theme.colors` | White-on-#FF6B00 = 2.86:1 (AA fail) on the ENTIRE ordering path; textSecondary 2.68:1; success 2.78:1 | P1 (05-P1-A11Y-CONTRAST) |
| P-2 | ~118 literal sites (audit-05 inventory) | Hard-coded strings bypass `AppLocalizations` (drawer 10, GDPR 4, force-update 2, ErrorWidget 2, router fallback 4, restaurant_setup 48, admin hub/gateway/role-router 8, tracker status names, loading semantics) | P1 (05-P1-L10N-STRINGS) |
| P-3 | `menu_screen.dart:168,196`, `home_screen.dart:437,777`, `admin_menu_manager.dart:32,36` | 3 formatter families + literal `$`; default-USD foot-gun for AED/SAR clients | P1 (05-P1-L10N-MONEY) |

### 25.2 Solution - design principle + acceptance contract

**Design principle:** one palette, one formatter, one l10n path. Decision 1 in the index applies (DEFAULT = Option A: darken primary to ~#C84F00, 4.57:1).

**Acceptance contract (from master W9.1/W9.2/W9.3):**
1. Contrast: land the chosen option byte-synced in `AppColors`/`AppTheme` AND BOTH `client_config.json` `theme` blocks; `textSecondary` + `success` reach >= 4.5:1; extend `accessibility_guidelines_test.dart` to compute WCAG ratios from the REAL palette (>=4.5 normal / >=3.0 large); re-capture affected goldens AFTER.
2. ARB: migrate ALL ~118 literal sites to `app_en.arb` + `app_ar.arb`; regenerate (`flutter gen-l10n`); parity test stays 532/532 -> N/N; delete dead `genericError` if unused; status/role `.name` leaks x6 -> localized maps.
3. Money: extend `currency_format.dart` `formatCurrencyCents` with thousands grouping + config currency; replace literal `$` (menu/home), inline non-grouped (home), pass config currency at `admin_menu_manager:32,36`; retire the USD-default `formatAmount` (explicit currency param required).

### 25.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Parity N/N | `flutter test` l10n parity suite |
| T-2 | Contrast from real palette | `accessibility_guidelines_test.dart` computes ratios >= 4.5/3.0 |
| T-3 | No literal `$` | grep `\$[0-9{]` in lib = 0 |
| T-4 | Money grouping | Unit: `formatCurrencyCents(1234567)` -> grouped string with config currency |
| T-5 | Goldens re-captured | Golden suite green post-palette |

### 25.4 Proof gates

- [ ] Parity test green (532/532 -> N/N)
- [ ] Contrast test green (T-2)
- [ ] grep `\$[0-9{]` in lib = 0
- [ ] `flutter analyze` + `flutter test` green
- [ ] Goldens re-captured post-palette
- [ ] Universal Gate Set U (index Section 1)

### 25.5 Honest residuals

- Contrast ratios are mathematically exact for the hex pairs; derived/alpha-composited pairs are marked approx in the audit - the test asserts the real-palette pairs.
- The ARB migration is large (~118 sites); the parity test + analyze are the safety net. If a string has no AR translation yet, add it (never leave English-only in a migrated site).

**END OF BATCH UX-1 SPEC** - do not proceed until these gates pass and the UX-1 addendum is appended to FIX_VERIFICATION.md.