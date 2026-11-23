# STAGE 6 — DISPATCH QUEUE · WAVE 1: `p16` ‖ `p19` (parallel, territory-disjoint)

**Coordinator:** main worktree only. **Status entering this wave:** Stage 5 COMPLETE — `main` = `4fba146`, all four delta re-audits verified & merged (`AUD-1R`, `AUD-2R`, `AUD-3R`, `AUD-4R2`); register `AUDIT_TRIAGE_STAGE3.md` §19–§20.
**Gate state at dispatch (from the AUD-4R2 receipts, re-verified by the coordinator):** core **+329** · core_ui **+289** · core_app **+2002** · halal **+71** (0 skips) · functions `npm test` **124 pass / 0 fail / 0 skip** · `tsc` 0 · analyze ×3 clean · format **696/0**.

---

## §1 Why these two lanes, and why in parallel (territory proof, not assertion)

| lane | spec | worktree / branch | territory (§2 of the spec) |
|---|---|---|---|
| **A** | `WHITE_LABEL_p16_adoption1.md` (UI-6, adoption wave 1: menu · dish detail · home · cart) | `<repo>-worktree` / `cline/task-1` (clean, ff-able) | `core_app/lib/features/{menu,dish_detail,home,cart}/presentation/**` + **existing** `packages/core_ui/lib/src/ui/**` component seams (documented red→green fallout only) + their tests + golden re-captures + `tool_uilib/p16/**` |
| **B** | `WHITE_LABEL_p19_delivery1.md` (UI-9, delivery-platform adapters v1) | `<repo>-cline-2` / `cline/task-2` (clean, ff-able) | `packages/core/lib/src/delivery/**` (NEW) · `core_app/functions/src/**` (NEW files) · `core_app/lib/app/config/**` (new keys) · `core_app/tool/whitelabel.dart` `validate()` mirror · functions fixtures/tests · `tool_uilib/p19/**` |

**Disjointness proof:** no path appears in both territories. `p16` forbids `functions/**`, `pubspec.*`, `packages/core_ui/lib/src/theme/**` and all provider/logic files; `p19` forbids every presentation surface, `theme/**`, `pubspec.*` and money-derivation logic. The only shared location is the repo root (documentation), which neither lane writes except its own `tool_uilib/p<N>/**` directory.

**Why not the other waves yet (the sequencing is forced, not preferred):**
- `p20` requires *p16 merged AND its visual pack owner-approved* (p20 §1) → cannot start.
- `p23_widgets` would write `packages/core_ui/lib/src/ui/**` — the same directory `p16` holds a seam right in → the exclusive-territory law serializes it after `p16`.
- `p17`/`p18` declare `p16` as predecessor; `p21`/`p22` depend on `p16`/`p20` (and on `p23` for W-1/W-2); `p24` depends on `p18`.
- `p25` edits the generator + config tests that **`p19` is editing right now** → serialized after B merges.
- `p26` is the closing harness pass; it runs last by design.

---

## §2 Lane mechanics (binding on both lanes)

1. **W2 branch assert.** `git -C <worktree> rev-parse --abbrev-ref HEAD` must equal the branch in §1 before anything else.
2. **Sync (and the fetch-stall workaround).** `git fetch` → `git merge --ff-only main`. Then **floor proof:** `git merge-base --is-ancestor 4fba146 HEAD` must exit 0. Record the *actual* HEAD in the report (`tip=<hash>`); do not assume it equals `4fba146` — the coordinator commits docs while you sync. (No self-reference: this file never pins its own commit hash.)
   **Observed at dispatch:** this repo's `credential.helper = manager` (Git Credential Manager), so `git fetch`/`git push` can block in an interactive auth prompt. If `git fetch` stalls, interrupt it and proceed: the local `main` ref is authoritative for this dispatch (the worktrees share the repo's common dir, so `git merge --ff-only main` picks up the coordinator's newest commit without any network access). The floor check is the gate that matters, not the fetch.
3. **Blocker gate before any edit** — run it on your own tree and quote the output verbatim: `flutter analyze --fatal-infos` (core_app, core_ui) · `dart analyze` (core) · `dart format --output=none --set-exit-if-changed .` · suites core/core_ui/core_app/halal (0 skip) · functions `npx tsc --noEmit` + `npm test`. Any red ⇒ **STOP, change nothing, report with an evidence table** (p10 §0.3).
4. **Receipts (new laws R-X/R-Y, earned in Stage 5):** every number you state must cite the receipt file that contains it; every report claim must agree with your own receipts; run the gate yourself and paste its output. Reports that contradict their own receipts are rejected on sight.
5. **Commit per phase; never end a phase on red.** Push only if credentials are cached; a stalled push is not a failure — continue locally and retry at the end.
6. **Do NOT merge to `main`** and **never touch `FIX_VERIFICATION.md`** (coordinator-only). No new dependencies (both specs).
7. **Handoff, not drive-by.** Anything you find outside your §2 territory goes into the report's handoff table — never fixed in this lane.
8. **Coordinator-side artifacts you may see (verified, harmless).** This session's push was blocked by Git Credential Manager (see item 2), which left an empty, untracked `_pe.txt` **at the repo root**, still held open by a lingering shell process so it cannot be deleted yet. It is 0 bytes, untracked, and NOT part of the tree: if your SYNC sees `?? _pe.txt`, that is not a pre-existing tree violation — delete it if you can, otherwise ignore it and never commit it. Report it in your evidence table either way.
9. **Coordinator merge protocol (serialized):** the lane that finishes first is merged to `main` first; the second lane then runs `git merge main` and **re-runs the full battery on the merged tip** before *it* is merged. Two lanes are never merged into `main` in one batch without a re-gated tip.

---

---

## §3 LANE A — paste-ready prompt (`p16`, adoption wave 1)

```
You are the SINGLE EXECUTOR of UI-6 (p16), ADOPTION WAVE 1 (customer core: menu, dish detail, home, cart), MAIN ONLY.
WORKTREE: work ONLY in <repo>-worktree on branch cline/task-1 (keeps the coordinator's main worktree clean).
Read <repo>\WHITE_LABEL_p16_adoption1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + p11 L1-L5 + p16 §0.8-0.10 + L12-L15.
Also read <repo>\STAGE6_DISPATCH_W1.md §1-§2 (lane mechanics + the new laws R-X/R-Y).

1. SYNC (fail-closed): assert branch == cline/task-1; tracked tree clean; git fetch; git merge --ff-only main;
   PROVE the floor: `git merge-base --is-ancestor 4fba146 HEAD` must exit 0. Record the ACTUAL tip + suite counts in the report.
   BLOCKER: flutter analyze --fatal-infos (core_app + core_ui) + dart analyze (packages/core) + dart format root 0 changed
   + suites core_app/core/core_ui/halal/shell all green 0 skip + functions tsc 0 && npm test green, ALL BEFORE ANY EDIT.
   Quote each result; save to tool_uilib/p16/gate_baseline.txt. Failure => STOP, evidence table, no edits.
2. RED per phase: write the phase's tests FIRST (A2 money-parity test is MANDATORY and must fail before wiring);
   capture the failing output to tool_uilib/p16/red_phase<A|B|C|D>.txt.
3. GREEN per phase, in order: A menu (MenuTile + PriceTag + StaggeredEntrance + EmptyStateWidget) ->
   B dish detail (PriceTag large + QuantityStepper + InfoBanner) -> C home (BrandCard composition + SectionHeader,
   BOTH variants re-rendered) -> D cart (line items, totals DISPLAY-ONLY via PriceTag, EmptyStateWidget).
   Commit after EACH phase; never end a phase on red.
4. VISUAL FLOOR (L12) at every touched seam: token colors only (app_colors_theme_ban_test stays green), Gap/AppDimensions
   spacing, entrance motion, skeleton states, >=48x48dp targets with >=8dp separation, and before/after golden PAIRS into
   tool_uilib/p16/visual_review/ for the owner's verdict.
5. MONEY PARITY (L13): positive/known-code prices byte-identical to formatCurrencyCents; any negative/unknown-code
   divergence => DECISIONS-NEEDED-FROM-OWNER entry + before/after goldens, NEVER silent.
6. BEHAVIOR PRESERVATION (L14): Semantics labels, Hero tags, Cloudinary thumbs, add-to-cart haptic+snackbar, sold-out gating,
   search behavior, l10n en+ar parity — preserved verbatim or improved. Providers/logic/routes: ZERO edits.
   CORE_UI: existing component seams ONLY as documented red->green fallout. If a NEW library component is genuinely
   required, that is a HANDOFF to p23_widgets (report table) — do not author new components here.
7. GATES (E1) on your final tip: analyze x2 + dart analyze core + format + ALL suites 0 skip (no drop) + l10n + W9 a11y
   + ban test + coverage (core_ui 100% x 26 held; core_app aggregate >= baseline) + goldens inventory + `git status` proves
   zero forbidden paths. Save every gate output under tool_uilib/p16/receipts/.
8. REPORT: tool_uilib/p16/p16_report.md per §4 — territory table (every touched file), per-phase evidence, visual-review
   pack index, six-way classification, DECISIONS-NEEDED-FROM-OWNER, UNVERIFIED (non-empty is allowed), DRIFT, handoff table,
   and a paste-ready `## APP COMPLETION UI-6 (p16)` block. NEVER touch FIX_VERIFICATION.md.
9. Commit everything on cline/task-1. Do NOT merge to main (the coordinator merges). Push only if credentials are cached.
DoD: every p16 §5 item green on a committed tip + visual pack ready for owner review + receipts committed + nothing uncommitted.
```

---

## §4 LANE B — paste-ready prompt (`p19`, delivery-platform adapters v1)

```
You are the SINGLE EXECUTOR of UI-9 (p19), delivery-platform adapters v1, MAIN ONLY.
WORKTREE: work ONLY in <repo>-cline-2 on branch cline/task-2 (keeps the coordinator's main worktree clean).
Read <repo>\WHITE_LABEL_p19_delivery1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + L1-L6.
Also read <repo>\STAGE6_DISPATCH_W1.md §1-§2 (lane mechanics + the new laws R-X/R-Y).

1. SYNC (fail-closed): assert branch == cline/task-2; tracked tree clean; git fetch; git merge --ff-only main;
   PROVE the floor: `git merge-base --is-ancestor 4fba146 HEAD` must exit 0. Record the ACTUAL tip + suite counts.
   (The spec's "79+" functions baseline is STALE — record the real one: `npm test` in core_app/functions = 124 pass
   at dispatch; core_app +2002, core +329, core_ui +289, halal +71.)
   BLOCKER: functions lint + npx tsc --noEmit + npm test green AND analyze x3 + format 0 changed + all suites 0 skip,
   ALL BEFORE ANY EDIT; quote each and save to tool_uilib/p19/gate_baseline.txt. Failure => STOP, evidence table.
2. RED first (capture to tool_uilib/p19/red_suite.txt): config-validation tests (unknown platform id fails closed at the
   exact JSON path; absent = inert) + ingestion fixture tests (valid payload -> draft + ack; REPLAY -> no-op; bad signature
   -> reject + audit log) + a re-derivation assertion (a tampered platform total never persists).
3. GREEN: T-1 DeliveryPlatformAdapter contract in `core` (typed + validated platform_config) -> T-2 ingestPlatformOrder
   (verify -> idempotency key `platform:id` -> adapter map -> server-side re-derivation via the EXISTING money-authority
   path -> persist -> ack/reject -> DLQ on failure) -> T-3 syncMenuAvailability (mocked HTTP client seam; platform
   unavailable => retry/DLQ, never blocks our own availability writes) -> T-4 RUNBOOK_DELIVERY_PLATFORMS.md (per-platform
   credentials, go-live checklists incl. DH's quoted SLA clause, sandbox test plan, client-enablement keys) -> T-5 App-Check
   boundary note (webhooks are server-to-server: the signature verification IS the boundary; a test proves unverified
   external calls are rejected).
   Config keys land in core_app/lib/app/config/** AND the core_app/tool/whitelabel.dart validate() mirror — the
   whitelabel_schema_identity_test stays pinned green (W6.5 pattern).
4. FIXTURES (L5): every fixture cites the documented source it mirrors. Where a platform doc is gated, label the fixture
   best-effort + UNVERIFIED — never present it as a captured production payload.
5. MONEY (L2/L6): a platform order is a DRAFT through the existing re-derivation; platform totals are NEVER trusted; a price
   mismatch routes to the platform deny/fulfillment-issue flow (fail-closed). `orderSource: platform:<id>` is set on every
   ingested order; consumer order history filters by user, so platform orders never appear in a client user's own list.
6. GATES: functions battery + analyze x3 + format root 0 + suites 0 skip (no drop) + coverage (new files 100% lines)
   + greps 0 + `git status` proving zero forbidden paths + the schema-identity test green. Save outputs under
   tool_uilib/p19/receipts/.
7. REPORT: tool_uilib/p19/p19_report.md per §4 — per-T evidence, fixture provenance table, six-way classification,
   DECISIONS-NEEDED-FROM-OWNER (recommended first platform: the DeliveryHero program — one agreement -> Talabat +
   HungerStation), UNVERIFIED (live round-trips await credentials, an ops-class unknown — this section must be non-empty),
   DRIFT, handoff table, paste-ready `## APP COMPLETION UI-9 (p19)` block. NEVER touch FIX_VERIFICATION.md.
8. Commit everything on cline/task-2. Do NOT merge to main (the coordinator merges). Push only if credentials are cached.
DoD: p19 §5 green on a committed tip + report + receipts + nothing uncommitted.
```

---

## §5 Wave plan after W1 (so no rung is ever unowned)

| wave | lanes (worktree) | specs | prerequisite that forces the order |
|---|---|---|---|
| **W1 (now)** | A: `p16` (cline-1) · B: `p19` (cline-2) | `p16_adoption1`, `p19_delivery1` | both spec'd & approved; territories disjoint |
| **W2** | `p20` (cline-1) · `p23_widgets` (cline-2) · `p25_generator_completeness` (cline-3) | p20, p23, p25 | p20 needs p16 merged + pack approved; p23 needs p16's core_ui seam right released; p25 edits the generator/config tests p19 is editing |
| **W3** | `p21_adoption3` (cline-1) · `p22_staff` (cline-2) | p21, p22 | both need p16 + p20 merged; p21/p22 consume p23's W-1/W-2 components |
| **W4** | `p18_arabic1` (cline-1) · `p24_locale_toggle` (cline-2) | p18, p24 | p24 depends on p18 |
| **W5** | `p26_harness` (single lane) | p26 | closing battery/guard pass — runs last by design |

`p17_analytics1` may slot into any wave **after W1** whose lanes avoid `features/admin/presentation/analytics/**` (its territory).

**Spec status at the time of this dispatch (honest inventory — do not dispatch a wave whose spec is not on disk):** WRITTEN and approved → `p16`, `p19`, `p20`, `p22` (authored with this file; closes S5-01), `p23` (authored with this file), plus the library specs `p11`–`p15`. STILL TO BE AUTHORED BY THE COORDINATOR (scope already fixed by the coherence ladder §6 corrected queue, so no surface is unowned): `p17_analytics1` (exists — `WHITE_LABEL_p17_analytics1.md` is on disk), `p18_arabic1` (exists), `p21_adoption3`, `p24_locale_toggle`, `p25_generator_completeness`, `p26_harness`. A wave in the table above may only be dispatched once its spec file exists and its predecessor's merge is receipted in `AUDIT_TRIAGE_STAGE3.md`.

**Owner decision queue carried into these waves:** D-2 (remove the `referrals` flag → `p21`) · D-3 (wire the guided tour → `p21`). Open register rows **AUD2R-01/AUD2R-02** (guard repairs) are folded into **W2 lane `p25`**. **S5-01 is closed by `WHITE_LABEL_p22_staff.md`** (authored with this dispatch file); register row `AUD4-C5-01` closes when that wave ships.
