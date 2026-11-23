# WHITE_LABEL_p13_ui3_tiles — UI-3: TILES — SINGLE EXECUTOR, WORKTREE cline-1

**Fleet:** p11 shapes (DONE, `b024e82`) → p12 motion (running, main) → **p13 tiles (this spec)** → p14 layouts → p15 proof. Inherits `WHITE_LABEL_p10_t78.md` §0 0.1–0.7 verbatim and `WHITE_LABEL_p11_ui1_shapes.md` batch laws L1–L5 (tokens READ-only; zero money math; no hardcoded strings; no new deps; fail-safe cosmetics). Runs under `WHITE_LABEL_BATCHES.md` §3.5/§3.6 (blocker gate B-1..B-5, per-worktree ledger, rolling merge-back).

## §0 Worktree rules (binding, additive to the inherited §0)

0.8 **Worktree:** work ONLY in `<repo>-worktree` on branch `cline/task-1`.
0.9 **B-1..B-5 first (fail-closed).** Sync = `git -C <repo>-worktree merge main` (then `flutter pub get`); gates green in the worktree BEFORE any edit; any blocker ⇒ stop, record, do not fake work.
0.10 **Self-contained territory (the B-2 guarantee).** Do NOT import any p12 (motion) or p14 (layout) component — this batch is file-disjoint from them by construction. Ink/press feedback comes from native Material (InkWell/InkResponse), never from a p12 wrapper.
0.11 **Per-worktree ledger.** Append the addendum to `<repo>-worktree\FIX_VERIFICATION_cline-task-1.md` (create if absent) — NEVER the main `FIX_VERIFICATION.md`.
0.12 **Merge-back duty.** After DONE + commit: (1) re-sync the worktree against main; (2) from `<repo>` (clean tree, anchor check), `git merge cline/task-1`; conflicts MUST be limited to `packages/core_ui/lib/core_ui.dart` (barrel) → resolve as the UNION of both export blocks, alphabetized; ANY other conflict ⇒ `git merge --abort`, report, stop; (3) re-run the FULL §5 battery on merged main; (4) commit the merge; (5) push attempt only if credentials are cached — otherwise leave push to the owner (known trap) and record it.
0.13 **Serialization gate.** Before merge-back, if main moved past your recorded anchor (p12 merged mid-flight), re-run the §5 gates on the re-synced worktree first. Battery runs on main are staggered: never concurrently with another window's battery.

## §1 Baseline

- Main tip: `2e21b10` (UI-1 `b024e82` + p12 spec). core_ui suite **141**, 0 skip; analyze/format 0; UI-1 coverage 100% on its 10 files.
- Frozen inputs (P1, prior sessions): `money_text.dart` (`moneyCents`), `skeleton_loader.dart` (factories), `brand_colors.dart`, `price_tag.dart` (UI-1), `app_tokens.dart`.

## §2 Territory (exclusive — B-2 mechanical check: zero shared paths with p12/p14)

NEW in worktree: `packages/core_ui/lib/src/ui/{stat_tile,setting_tile,menu_tile,status_tile,tile_grid,tile_skeletons}.dart`
NEW: `packages/core_ui/test/ui3_tiles_batch_test.dart` · `tool_uilib/p13/**` · `FIX_VERIFICATION_cline-task-1.md` (worktree root)
MODIFIED (additive export lines ONLY): `packages/core_ui/lib/core_ui.dart`
FORBIDDEN: `FIX_VERIFICATION.md` (main), `DECISIONS_LOG.md`, `packages/core_ui/lib/src/theme/**`, `packages/core_ui/lib/src/ui/transitions.dart` (p12's), every existing test file, `pubspec.*`, `core_app/**`, `apps/**`, `functions/**`, `packages/core/**`, generated files.

## §3 T-x table (all red→green; red receipt `tool_uilib/p13/red_suite.txt` BEFORE any component file)

| Task | Component | Acceptance |
|---|---|---|
| T-1 | `StatTile` | Label + value (+ optional icon, optional delta string); value prominent (w800), label secondary; colors via `BrandColors.of`; card shape = large radius; optional `onTap` = exactly one InkWell path; no tap ⇒ inert. |
| T-2 | `SettingTile` | Leading icon + title (+ optional subtitle) + trailing slot (caller widget) defaulting to a chevron when `onTap != null`; tap fires once; disabled (no onTap) ⇒ no chevron, no tap path; semantics native. |
| T-3 | `MenuTile` | Title + optional subtitle + `PriceTag`-rendered price (moneyCents delegation asserted — L2) + optional `imageUrl` with `errorBuilder` fallback to a caller icon (cosmetic fail-safe, L5); long text ellipsized; tap-once. |
| T-4 | `StatusTile` | `TileStatus {ok, pending, failed}` → pure static `toneFor()` mapping to `BadgeTone` {positive, neutral, negative} (asserted distinct) + status label; badge rendered via `BrandBadge`. |
| T-5 | `TileGrid` | Layout wrapper over `GridView`: `crossAxisCount`, `childAspectRatio`, `spacing`, children order preserved; shrinkWrap+NeverScrollable default (embeddable, L5). |
| T-6 | `TileSkeletons` | Loading counterparts: `TileSkeletons.stat/setting/menu()` delegating to `SkeletonLoader` with the DOCUMENTED dimensions of each live tile (asserted widths/heights/radii). |

## §4 Deliverable

`tool_uilib/p13/p13_report.md` in the worktree: summary; per-T evidence; six-way classification; residuals; DECISIONS-NEEDED-FROM-OWNER; UNVERIFIED (non-empty allowed); DRIFT; paste-ready `## APP COMPLETION UI-3 (p13)` block (also mirrored into the per-worktree ledger per 0.11).

## §5 Acceptance

- analyze --fatal-infos (core_ui) + dart analyze (core) exit 0 · format (repo root) 0 · core_ui suite **141 + new (≥ 30)** green 0 skip, existing tests untouched · coverage **100% lines per new file** · greps TODO/FIXME/@Skip/skip:/expect(true = 0 · red→green receipt · after merge-back: full battery green on MERGED MAIN (staggered per 0.13).

## §6 Judge + close

The coordinator (main session/owner) spot-checks ≥3 claims (T-3 moneyCents delegation, T-4 distinct mapping, T-6 dimension parity), verifies forbidden paths 0, ratifies the merge-back, and owns the final ledger + push.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-3 (p13), tiles batch, in worktree <repo>-worktree (branch cline/task-1).
Read <repo>\WHITE_LABEL_p13_ui3_tiles.md IN FULL — binding contract. It inherits p10 §0 0.1-0.7 + p11 laws L1-L5 + WL_BATCHES §3.5/§3.6.
1. SYNC (B-3): git -C <repo>-worktree merge main; cd <repo>-worktree; flutter pub get. Record the main tip you synced (=anchor).
2. BLOCKER (B-4): flutter analyze --fatal-infos (core_ui) + dart analyze (core) + dart format check (root) + flutter test (core_ui, 141/141, 0 skip) — all green BEFORE any edit.
3. RED: test/ui3_tiles_batch_test.dart to the T-1..T-6 contract; capture failure to tool_uilib/p13/red_suite.txt.
4. GREEN: implement the six files; dart fix --apply; dart format; suite green 0 skip; analyze 0; coverage 100% new files; greps 0.
5. REPORT: tool_uilib/p13/p13_report.md per §4 + append the addendum to FIX_VERIFICATION_cline-task-1.md (0.11). NEVER touch main's FIX_VERIFICATION.md.
6. COMMIT (in the worktree): git add <territory files> && git commit -m "ui3(p13): tiles batch".
7. MERGE-BACK (0.12): re-sync; merge cline/task-1 into main from <repo> (clean tree, anchor check); barrel conflicts = UNION of export blocks, alphabetized; any other conflict = abort + report; full battery on merged main (stagger); commit the merge; push only if cached credentials allow.
DoD: §5 green + report + per-worktree ledger + commit + merge-back battery green + nothing left uncommitted.
```

**END OF UI-3 SPEC.**

