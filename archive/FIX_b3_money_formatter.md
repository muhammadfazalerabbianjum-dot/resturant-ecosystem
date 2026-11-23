# FIX-B3 — MONEY-5: ONE money formatter, CLDR-conformant (client-side only)

**Batch:** `B3` · **Finding:** `AUD1-02` (**HIGH**) · **Owner decision D-1:** adopt the CLDR negative form `-$1.50` · **Authority:** `AUDIT_TRIAGE_STAGE3.md` §2.1/§3 + §9.
**Worktree:** `<repo>-cline-3` (`cline/task-3`). May run ∥ `B5`. **`AUD1-05` (rounding) is NOT here** — it moved to `B4` (node↔dart tax rounding).

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`). 0.3 Red→green per task, receipt **before** the fix. 0.4 Ledger single-writer. 0.5 Territory exclusivity (§2) + the §9 standing rule (unlisted call site ⇒ STOP). 0.6 Never end on red; commit per task. 0.7 **Display-only:** money **math** (`moneyCents`, totals, tax) is READ-ONLY — this batch changes rendering, never a computed amount. 0.8 No new dependencies. 0.9 Git strictly serialized.

## §1 Research receipts (verified at `1f38508`)

| Fact | Evidence |
|---|---|
| **THREE formatters exist.** (1) `moneyCents` (library, CLDR-style); (2) `formatCurrencyCents` — composes **symbol-first then sign** → `$-1.50`, fixed symbol list; (3) `formatAmount` — admin-side, emits `dh12.50` / `Riyal12.50` and **JPY `¥13`** | (1) `packages/core_ui/lib/src/ui/money_text.dart:14` (`_kCurrencySymbols`), `:26` (`_moneySymbol`) · (2) `core_app/lib/app/config/currency_format.dart:12` (`currencySymbolFor`), `:46` (`formatCurrencyCents`), `:51` (the compose) · (3) `core_app/lib/features/orders/domain/amount_formatter.dart:8` (`String formatAmount(int cents, String currencyCode)`) |
| **AUD-1 parity table: 8 of 14 rows diverge** — `-150/USD`, `1250/CAD`, `1250/AUD`, `1250/JPY`, `1250/AED`, `1250/SAR`, `1250/XYZ`, `1250/usd` (positive USD/EUR/GBP and `null` code AGREE) | `tool_audit/aud1/receipts/c3_parity_run.log` TWIN-1 |
| Public surface exported and used by screens: `formatCurrencyCents`, `currencySymbolFor` | `core_app/lib/labs.dart:61` |
| Call sites: `formatCurrencyCents` 16 calls / 12 files (cart 3, home 2, dish_detail 2, menu 2, home_feed_showcase 2, revenue_chart 2, labs 2, itself 1); `formatAmount` call sites are the **admin dashboards** (owner ×3, delivery ×3, manager ×2, kitchen 1, admin_menu_manager 2, analytics_snapshot 1) | coordinator grep at `1f38508` |
| External standard: CLDR currency patterns place the minus **before** the symbol (negative sub-pattern) | `RESEARCH_ANALYTICS_ARABIC_DELIVERY.md` §2 (CLDR, primary source fetched) |

## §2 Territory

**MODIFIED:** `packages/core_ui/lib/src/ui/money_text.dart` (**the single source of truth**) · `core_app/lib/app/config/currency_format.dart` (delegate to it) · `core_app/lib/features/orders/domain/amount_formatter.dart` (delegate to it) · `core_app/lib/labs.dart` (export line only) · the enumerated call sites, only where a signature changes: `cart_screen.dart`, `home_screen.dart`, `home_feed_showcase.dart`, `menu_screen.dart`, `dish_detail_screen.dart`, `revenue_chart_widget.dart`, `owner_dashboard.dart`, `delivery_dashboard.dart`, `manager_dashboard.dart`, `kitchen_dashboard.dart`, `admin_menu_manager.dart`, `analytics_snapshot.dart`.
**CREATED:** the parity/regression suite (core_ui + core_app tests) · receipts + golden pack under `tool_fix/b3/**`.
**FORBIDDEN:** `core_app/functions/**` · any tax/total-computation file · `checkout_service.dart` (B2, closed) · money **math** helpers (read-only) · theme files · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — one source of truth.** Exactly ONE implementation renders money: `money_text.dart` implements the CLDR rules (negative = minus **before** the symbol; symbol map corrected for CAD/AUD/AED/SAR; **JPY/KRW 0 decimals**; unknown code ⇒ `"CODE "` prefix). `formatCurrencyCents` **and** `formatAmount` both delegate to it — duplicate logic deleted or reduced to a thin deprecated delegate (the report must justify the choice and prove no second rule set remains, by grep of both symbol maps).

**T-2 — CLDR conformance matrix (the red).** Assert the **14-row** AUD-1 matrix (positives/zero/negative, JPY/KRW 0-dec, CAD, AUD, EUR, GBP, AED, SAR, unknown `XYZ`, lowercase `usd`, `null`) against the target: RED today = the **8** divergent rows; GREEN = 14/14 conformant.

**T-3 — positive-amount byte-identity (protect the owner's screens).** Every positive, known-code amount the app renders must be **byte-identical** to today — a change here is a defect, not a migration.

**T-4 — goldens accounted for.** Inventory every golden/picture containing money; re-capture **only** where T-1 changes pixels, with before/after packed for the owner (`tool_fix/b3/visual_review/`). No silent re-baseline.

**T-5 — fail-closed display.** Never emit NaN/infinity/empty; a malformed cents value yields an explicit placeholder — never a fabricated number.

## §4 Deliverable

`tool_fix/b3/b3_report.md`: T-table (red → green), the 14-row matrix before/after, the call-site inventory (all 12 files), six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B3` ledger block. Receipts + golden pack in `tool_fix/b3/`.

## §5 Acceptance

red→green per T · `flutter analyze --fatal-infos` core_app + core_ui 0 · `dart analyze` core 0 · format 0 · suites core_app + core + core_ui green **0 skip** no drop · positive-amount byte-identity green (T-3) · matrix 14/14 (T-2) · **zero diff in money-math files** (git proof) · **zero diff in `functions/**`** · greps 0 · goldens accounted for · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery on the committed tip; spot-checks ≥3 (matrix shows 8 red rows before the fix; `-$1.50` actually rendered; call-site grep completeness vs §2); reviews the golden pack with the owner; merges; appends the ledger block; flips `AUD1-02` → **CLOSED-WITH-RECEIPT** and re-runs the C3 money-detector.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B3 (MONEY-5: one money formatter, CLDR-conformant). Worktree <repo>-cline-3 (branch cline/task-3).
Read <repo>\FIX_b3_money_formatter.md IN FULL — binding contract (D-1 = adopt CLDR `-$1.50`; display-only; three formatters must become one).
1. SYNC (fail-closed): assert branch == cline/task-3; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core/core_ui, format root, suites core_app/core/core_ui green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: write the 14-row CLDR matrix + the byte-identity test first; capture failures to tool_fix/b3/red_*.txt (expect the 8 divergent rows).
3. GREEN: implement T-1..T-5 (money_text = source of truth; the other two delegate); commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. GOLDENS: inventory money-bearing goldens; re-capture ONLY if changed; pack before/after into tool_fix/b3/visual_review/.
5. PROOF: money-math files and functions/** diffs must be EMPTY; territory + grep evidence.
6. REPORT: tool_fix/b3/b3_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
7. COMMIT locally on cline/task-3; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + matrix 14/14 + positives byte-identical + nothing uncommitted.
```

