# WHITE_LABEL_p18_arabic1 — UI-8: ARABIC HARDENING (plurals + RTL + locale currency) — MAIN, SINGLE EXECUTOR

**Purpose:** make the two-language promise production-grade for a Gulf/Middle-East client. Research: `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` Track 2 — primary sources: CLDR Language Plural Rules chart (`ar` row, fetched), Flutter i18n/RTL framework behavior.

## §0 Rules (inherited p10 §0 0.1–0.7 + fleet laws)

0.8 Main-only, single executor. 0.9 **Fail-closed l10n:** every numeric ARB message must be plural-COMPLETE for `ar` (six CLDR categories) — incomplete = test failure, never a fallback guess. 0.10 **Display-only:** locale-aware currency is rendering; integer cents + money math untouched.

### Batch laws

L1 **Six-form plurals (CLDR `ar`, fetched & quoted in the research doc):** zero (n=0) · one (n=1) · two (n=2) · few (n%100 = 3–10, 103–110…) · many (n%100 = 11–99) · other. Every message with a numeric placeholder adopts the six-way ICU form in **both** en and ar ARBs (en uses the forms it needs; ar requires ALL of zero/one/two/few/many/other where the grammar applies — audit decides per message).
L2 **Money-display parity (p16 L13 lineage):** `en` rendering stays byte-identical for the current behavior; the new locale-aware path must agree with `formatCurrencyCents` for `en` on all supported codes (parity test) while adding correct `ar` rendering (e.g. "SAR 12.50" per CLDR `ar` patterns).
L3 **RTL correctness over hacks:** no `Directionality.override` to fake it; fix the layout assumptions; RTL golden variants are the proof.
L4 **No new dependencies** (`intl` present via flutter_localizations; Arabic font families via existing `google_fonts`).
L5 **Typography without touching the frozen engine:** Arabic-capable families (Cairo/Tajawal/Almarai cover Latin too) are set per client through the EXISTING b10 `typography.headingFont/bodyFont` config keys — `packages/core_ui/lib/src/theme/**` stays untouched.

## §1 Baseline (P1, verified this session)

- ARB pair: `app_en.arb` 36.1 KB / `app_ar.arb` 45.6 KB (real content); **only 3 plural usages total** — the six-form gap is real and large.
- Parity test exists: `core_app/test/app_localizations_parity_test.dart` (+ getters test) — the upgrade target.
- `formatCurrencyCents` (`core_app/lib/app/config/currency_format.dart`) is locale-agnostic (fixed symbol list, Latin digits, `$` fallback).
- p16 adoption wave 1 lands the library components these screens use; this batch hardens AFTER p16 (predecessor: UI-6 merged).

## §2 Territory (exclusive)

MODIFIED: `core_app/lib/l10n/app_en.arb`, `app_ar.arb` (+ regenerated `app_localizations*.dart` via gen-l10n — generated files updated by the GENERATOR, not hand-edited) · `core_app/lib/app/config/currency_format.dart` (+ parity test) · `core_app/test/app_localizations_parity_test.dart` · RTL fixes in `core_app/lib/features/**` presentation files AS FOUND by the audit (each named in the report) · RTL fixes in `packages/core_ui/lib/src/ui/**` AS FOUND (receipted red→green fallout — e.g. a hand-painted divider or baseline Row with a hidden LTR assumption; `theme/**` still forbidden) · RTL golden variants under the existing golden dirs
NEW: `core_app/test/l10n_plural_completeness_test.dart` · `core_app/test/rtl_goldens_test.dart` · `tool_uilib/p18/**`
FORBIDDEN: `packages/core_ui/lib/src/theme/**` (L5), `FIX_VERIFICATION.md`, `pubspec.*`, `packages/core/**`, `functions/**`, rules, generated *.g.dart outside the l10n generator's own outputs.

## §3 T-x table

| Task | Deliverable | Acceptance |
|---|---|---|
| T-1 | Numeric-message audit → six-form plurals | Inventory of every ARB message containing a number (mechanical grep + manual grammar pass); each becomes `{count, plural, =0{…} =1{…} =2{…} few{…} many{…} other{…}}` per CLDR ar rules; gen-l10n regenerates. Red→green: `l10n_plural_completeness_test.dart` fails on the OLD ARBs, passes after. |
| T-2 | Parity-test upgrade | `app_localizations_parity_test.dart` gains: every numeric en message must have an ar counterpart with the SAME plural categories present (fail-closed on future additions). |
| T-3 | Locale-aware currency | `formatCurrencyCents` (or a locale-aware wrapper used at call sites) renders per ambient locale: `en` byte-identical to today (L2 parity test across supported codes), `ar` correct per CLDR (e.g. SAR symbol rules, Arabic-Indic digits where the locale demands). Red→green table-driven tests per code × locale. |
| T-4 | RTL audit + fixes | Mechanical inventory (`Alignment.*Left/Right`, `EdgeInsets.only(left:/right:)`, `TextDirection.ltr`, custom painters) across `core_app/lib/features/**` + `core_ui` components; each hit dispositioned: fix (real bug) / documented safe (symmetric or intentional). Each fix receipted. |
| T-5 | RTL goldens | `rtl_goldens_test.dart`: the p16-wired screens (menu, dish detail, home, cart) + component samples pumped under RTL directionality; goldens captured once, verified. Visual review pack for the owner (Arabic screenshots). |
| T-6 | Native-review checklist | `tool_uilib/p18/ARABIC_REVIEW_CHECKLIST.md`: the exact strings/screens for a native Arabic speaker to vet (per CLDR minimal-pairs philosophy); owner schedules the reviewer — machine parity ≠ native quality (honest residual). |

## §4 Deliverable

`tool_uilib/p18/p18_report.md`: the numeric-message audit table (message → categories required); per-T evidence; RTL sweep disposition table; visual-review pack (RTL goldens); six-way classification; DECISIONS-NEEDED-FROM-OWNER (native reviewer scheduling; any grammar choice per message); UNVERIFIED (non-empty allowed: native Arabic quality judgment is human); DRIFT; paste-ready `## APP COMPLETION UI-8 (p18)` block.

## §5 Acceptance

- analyze ×3 exit 0 · format root 0 · suites core_app/core/core_ui/shell/rules/functions green **0 skip**, counts recorded at SYNC, no drop · **l10n en+ar parity green with the UPGRADED parity test** · plural-completeness test green · currency locale tests green (en parity byte-identical) · RTL goldens captured + green · coverage floors held · greps 0 · red→green receipts (T-1 fails on old ARBs) · forbidden paths 0.

## §6 Judge + close

Coordinator re-runs gates; spot-checks ≥3 (a six-form ar message renders per CLDR ranges — 0/1/2/3/11/25 samples; en currency parity; an RTL golden pair); appends the ledger block. Native-review checklist handed to the owner — Arabic sign-off is an owner-gated residual, honestly UNVERIFIED until a native speaker approves.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-8 (p18), ARABIC HARDENING, MAIN ONLY.
Read <repo>\WHITE_LABEL_p18_arabic1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + L1-L5.
Predecessor: UI-6 (p16) merged — its library-wired screens are the RTL golden targets.
1. SYNC (fail-closed): tracked tree clean; record tip + suite counts. BLOCKER: analyze x3 + format + suites green 0 skip BEFORE any edit. Failure => STOP.
2. RED: l10n_plural_completeness_test.dart FAILS on the current ARBs (only 3 plurals exist) — capture to tool_uilib/p18/red_suite.txt.
3. GREEN T-1/T-2: audit every numeric ARB message (table in the report); six-form ICU plurals in en+ar per CLDR ar rules; gen-l10n regenerate; parity test upgraded to enforce plural completeness — green.
4. GREEN T-3: locale-aware currency (en byte-identical parity test + ar CLDR-correct rendering) — table-driven red→green.
5. GREEN T-4/T-5: RTL sweep (inventory + fixes receipted) + rtl_goldens_test.dart captured once, verified; visual-review pack for the owner.
6. T-6: ARABIC_REVIEW_CHECKLIST.md for the native reviewer.
7. GATES: analyze x3 + format + all suites 0 skip + parity + coverage floors + greps 0; forbidden paths 0 (theme/** FORBIDDEN — Arabic fonts go through EXISTING b10 config keys).
8. REPORT: tool_uilib/p18/p18_report.md per §4 (six-way, UNVERIFIED, DECISIONS, DRIFT, paste-ready UI-8 ledger block). NEVER touch FIX_VERIFICATION.md.
9. COMMIT + battery on the tip; push only if credentials cached.
DoD: §5 green + report + receipts + green committed tip + nothing uncommitted.
```

---

## §2 Amendment A2 (coordinator, 2026-09-29) — concurrent-wave carve-out + three carried items

**Why:** this batch now runs beside **UI-14 (p25)**. The two territories were checked against the tree, not assumed.

### A2.1 Carve-out (binding, both directions)

- **p18 must not touch:** `tool_guard/**`, `core_app/tool/**` (the whitelabel generator),
  `apps/halal_boyz/assets/client_config.json`, `.gitignore` — those are p25's files.
- **p25 must not touch:** `core_app/lib/l10n/**` (ARB pair + generated l10n), `core_app/lib/features/**`,
  `packages/**` — those are p18's (recorded in `WHITE_LABEL_p25_generator_completeness.md` §2b).
- Any change needed in the other lane's files is a **handoff row**, never an edit.
- No shared file exists between the two territories as written; if one appears, STOP and report.

### A2.2 Carriage C-1 — the two onboarding keys (from the p21 ruling)

`trackerStepOfTotal` was a **temporary** reuse: `WHITE_LABEL_p21_adoption3.md` §2 Amendment A1 (`6d16a84`) wired
`pageLabelBuilder` + `pageDotLabelBuilder` from it and assigned the real keys here. Deliver:
1. Add to **both** ARBs: `onboardingPage(int page, int total)` and `onboardingPageDot(int page)`, en + ar,
   `int` placeholders, ICU-correct (no string coercion; the six-form work in T-1 applies to any plural wording
   you choose to use).
2. Swap the two builders at `core_app/lib/features/onboarding/presentation/onboarding_screen.dart:110-111` to the
   new keys and **delete** the `trackerStepOfTotal` reuse.
3. Proof: a semantics test asserting the live-region label equals the new key in **en AND ar**; a grep receipt
   showing zero remaining `trackerStepOfTotal` uses in `features/onboarding/**`.
This edit to one `features/**` presentation call site is **granted** (it is the recorded successor of Amendment A1),
and it is the only `features/**` write the carriage authorises beyond RTL fixes as found.

### A2.3 Carriage C-2 — `BrandDataTable` pager copy (record, do not fix)

`dead_letter_screen.dart:98` passes no `pageIndex`/`pageSize`/`totalRows`, so `brand_data_table.dart:202-203`
renders no pager today and the English fallbacks (`kTablePreviousPage`/`kTableNextPage`) are unreachable.
Localising them requires new component wiring (`pageLabelBuilder`-style seam) — **a widget change, not an l10n
change**. Deliver a **handoff row only** (report + register): owner `p23b` (unscheduled), latent with zero
user-visible effect until pagination is enabled on that surface. Do not edit `brand_data_table.dart`.

### A2.4 Carriage C-3 — the orphan `enterReferralCode` key

`enterReferralCode` exists in both ARBs + generated l10n with **zero** consumers repo-wide (verified; `referrals`
was removed by p21/D-2, and p25 removes the last config occurrence). Deliver: **remove the key from both ARBs**,
regenerate via gen-l10n, and prove (a) the parity tests stay green, (b) zero remaining references
(`git grep enterReferralCode` → only the removal diff), (c) no generated file is hand-edited. If the executor finds
a genuine consumer, STOP that task and report it as a BLOCKER instead of removing.

**END OF UI-8 SPEC — Amendment A2 (concurrent carve-out + carriages C-1/C-2/C-3) is the last binding section.**

