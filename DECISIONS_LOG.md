# DECISIONS LOG — PERF-10 freeze

Owner decisions recorded per `tool_archive/perf2_cited/tool_perf2/DECISIONS-NEEDED-FROM-OWNER.md`. Decided **2026-09-19** post-freeze; executed or scheduled as noted. Any change ships red→green through the standard gates.

| # | Decision | Owner pick | Disposition |
|---|---|---|---|
| O-1 | `allergenDisclaimerEnabled` no-op: wire banner (A) or remove (B) | **B — remove** | **EXECUTED** (micro-batch this commit) — removed at TRUE scope: `RestaurantConfigModel` field + freezed regen, `RestaurantSetupScreen` toggle + load/save, 3 dead l10n keys ×2 locales + regen, tests updated, banned-identifier pin extended. Rules shape needed no change (per-key optional style; no live docs exist pre-deploy) |
| O-2 | Migrations `lib/migrations/**` (compiled, never imported): wire or leave | **Leave as-is** | No change — operator-run node scripts per archive/RUNBOOK_DEPLOY.md §2(f); the compiled-uncalled bundle is harmless |
| O-3 | Storage-rules POD runtime proof (U-1): accept pin or schedule device check | **Schedule on deploy day** | Runs as part of the on-device smoke (order → proof-of-delivery upload) — closes U-1 |
| P-1 | NFC in-person payments | **Not now** | Graceful degradation held; typed error, no fake. Post-launch product call |
| P-2 | DoorDash/Uber auto-dispatch | **Not now** | Internal dispatch works; drop-in interface (`dispatchToFleet`) waits |
| P-3 | Onboarding tour auto-routing | **Leave off for launch** | Tour built + 100% covered; activation is a config flip when wanted |

Post-freeze rule in force: **no further waves unless production usage reports a bug** — bug-driven fixes only, red→green, receipted.

## p27 batch ratifications — coordinator, 2026-10-01 (single writer, METHOD §0)

```text
D-p27-1 | Redundant-import fail-safe (applied): when core's auth export makes a test file's
  package:firebase_auth/cloud_firestore import an unnecessary_import INFO, drop the import
  (types arrive via package:core; firebase_auth_mocks is a different package and keeps working).
  Inventory first; applied to 54 core files (49 core_app + 5 packages/core) <= the 60-file
  escalation ceiling, +1 halal harness line as the same class (A2). Default if >60 files or a
  file needs anything beyond line deletion: STOP, escalate to owner, do not mass-edit.

D-p27-2 | verify_constitution Law 4 pattern change (applied): TODO|FIXME (whole line) +
  code-portion `Placeholder(` + `throw UnimplementedError`; bare prose `placeholder` and
  `REPLACE_ME` are dropped as false-positive classes. Default: keep v1's bare `placeholder`
  substring ONLY if a planted fixture proves it fires on real stubs and silent on prose —
  measured 49 prose hits vs 0 real (spec §1), so the stronger net pattern is held.

D-p27-3 | Core auth export show-list (applied): `show FirebaseAuthException, FirebaseException,
  User` — FirebaseException added beyond the spec's two because signup_screen.dart:59 runs
  `e is FirebaseException` on its generic catch (same element firebase_core exports; no
  ambiguity for files importing both). Default if rejected: import package:firebase_core in
  signup_screen.dart (adds an SDK import to a feature screen — worse under Law 12).

D-p27-4 | OWNER DECISION 2026-10-01 — PATH (A) RECOVERY ON MERIT (no waiver, no floor edits).
  tool_fix/b7/coverage_baseline.json pins (core >= 84.24, core_ui >= 92.76, core_app >= 86.87)
  are IMMUTABLE for every batch in this program. Recovery = cover real code until
  powershell -File tool_fix/b7/coverage_floor.ps1 exits 0 (batch p28). Findings-§9 options
  (a) allowlist grandfather and (c) ledger waiver are REJECTED; only option (b), a coverage
  wave, is ratified. Red-proof for the defect: tool_uilib/p27/receipts/g_coverage_floor_final.txt
  (12 violations, all pre-existing at base — findings A1).
```

## p28 batch ratifications — coordinator, 2026-10-01 (single writer, METHOD §0)

```text
D-p28-1 | Receipt path conflict (dispatch text vs acceptance spec §2): SPEC §2 WINS — every p28
  lane receipt lives under tool_uilib/p28/receipts/lane_a|lane_b/. The dispatch text said
  tool_uilib/p27/receipts/lane_* — a typo against the per-phase convention (p26/p27/p28/p29 each
  own their receipts dir; tool_uilib/p27/receipts/ is frozen p27 evidence cited BY p28 spec §1).
  Precedent: p29 spec §79 = tool_uilib/p29/receipts/. Lane A followed the typo (its H2) and
  flagged it; coordinator normalises at merge time:
  git mv tool_uilib/p27/receipts/lane_a tool_uilib/p28/receipts/lane_a — receipt FILES are
  byte-unchanged; the stale index path is corrected by a coordinator addendum in the findings
  file, never by rewriting the lane's own text. LANE B: write to
  tool_uilib/p28/receipts/lane_b/ (dispatch typo superseded).

D-p28-2 | Lane A SYNC base b445ff35 (its H1) ACCEPTED, no rebase. Spec §6.1's audit command is
  literal `git diff --name-only b445ff35..HEAD`; the b445ff35 base is exactly what makes that
  audit byte-clean (a bb9e7e3a base would list T-0's 3 files as lane-touched). The --no-ff merge
  into main (which holds T-0 = bb9e7e3a) is clean and the merged diff stays lane-territory-only.
  Rebasing would rewrite reviewed lane history for zero evidence gain.

D-p28-3 | Lane A commit subjects `p28/lane-a T-N: ...` (its H3) ACCEPTED as-is: cosmetic
  dispatch-vs-spec drift. The artifacts + receipts + ledger block are the contract; no history
  rewrite.

D-p28-4 | Lane A findings doc drift (judge-found, adjudicated 2026-10-01): the findings header and
  V8 report "core suite 394 >= 387"; the artifacts say 396 (g_test_core_final.txt, "+396: All
  tests passed!" = the T-2 final incl. the 2 new lat_lng_parse tests; 394 was the T-1-era count).
  The coordinator's independent re-run = +396, exit 0, 0 fail, 0 skip. VERIFIED NUMBER = 396. The
  lane's original text is preserved verbatim; a coordinator addendum in the findings file records
  the reconciliation and the ledger/register carry 396.
```

## p37 batch decisions — coordinator, 2026-10-08 (single writer, METHOD §0)

```text
D-P37-1 | Owner decision 2026-10-08 — BRANCH A: wire all six Firestore feature flags
  (smartReorder, waitlist, promoCode, deliveryTracking, loyaltyPoints, tourMode) through
  featureFlagsProvider in p37 T-2, default-true (shipped configs keep flags enabled, behavior
  and goldens unchanged). Flips the inherited D-P33-1 fail-safe; branch B (DEFERRED truth-pin)
  does NOT apply. Recorded here because archive/WHITE_LABEL_p37_nine_push.md §0-4/§7 read the flip
  from this log.

D-P37-2 | Owner decision 2026-10-08 — T-4 SCOPE A: inverse matrix + fail-closed
  validate() on unknown top-level keys; inert schema keys (navigation.*, features,
  app.store*) STAY in both shipped configs with register-written allowlist reasons.
  The spec's original clause (c) (remove dead keys) conflicted with validate()'s required
  navigation/features sections and the disposition register's "every INERT row names a key
  the shipped configs really carry" contract — removal is deferred to a later owner wave.
  Spec §3 T-4 amended in the same session; no assertions weakened.
```

