# WHITE_LABEL_p05_perf5.md — PERF-5 (UI variant system — config-driven screen variants)

Status: PLANNED · Predecessors: PERF-3 (DONE `0b0178f`), TOKENS (DONE — the pattern to extend), ARCH-2 (DONE) · Emulator: not required
Executing window: `cline-2` (synced to `0b0178f`, format gate clean)

## 0. THE PATTERN (do not invent a new one)
TOKENS proved the house pattern for client-driven UI: **validated config vocabulary → engine → per-key behavior with byte-for-byte default**. PERF-5 extends it from skin (colors/shape/motion/backdrop) and flow (tabs/hiddenRoutes) to **structure**: per-screen variants chosen by config.

## 1. PROVEN PROBLEMS
| # | Problem | Proof |
|---|---|---|
| P-1 | The screens registry carries only `id`+`route` (`AppConfig.screens`, 26 whitelisted + DLQ; generator-validated `whitelabel.dart:2413-2462`). Two clients wanting structurally different screens (e.g. grid vs showcase home) have NO mechanism — the route set is fixed. | config schema read 2026-09-15 |
| P-2 (hazard) | Without a sanctioned axis, per-client forks would bypass the fleet machine — exactly what the TOKENS/ARCH-2 architecture forbids. | WHITE_LABEL_BATCHES.md §3.6 |

## 2. TERRITORY (this window OWNS the generator collision slot: `whitelabel.dart` + emitted shell files + `apps/halal_boyz/**`)
`core_app/lib/app/config/client_config.dart` (schema+validate) · `core_app/lib/app/config/app_config.dart` (parse) · `core_app/tool/whitelabel.dart` (validate() extension; emitted surfaces only if needed) · NEW registry provider file in `core_app/lib/` · ONE pilot variant widget + wiring · tests + goldens · `apps/halal_boyz/assets/client_config.json` **UNCHANGED** (default-proof).

## 3. ACCEPTANCE CONTRACT
1. **Validated vocab, fail-closed:** per-screen `variant` key (pilot: `home`); unknown value → `ConfigException` → the W6.5 schema gate blocks boot (same as required-field violations today).
2. **Default is byte-for-byte:** a config with no variant keys renders today's screens unchanged — assert via existing golden/home tests staying green + an explicit no-variant test (TOKENS acceptance-3 precedent).
3. **ONE pilot variant end-to-end** (mechanism, not 28 screens): e.g. HomeScreen `variant: "showcase"` rendering a distinct layout — resolved through the registry provider, widget-tested, golden'd.
4. Generator `validate()` rejects unknown variant names; the emitted router test (`whitelabel.dart:2451-2462`) still passes.
5. Gate Set U + per-package floors ≥80% + goldens + full battery + addendum.

## 4. T-x TABLE
| T-x | Action | Files |
|---|---|---|
| T-1 | Schema + fail-closed validation (client_config, app_config, generator validate) | `client_config.dart`, `app_config.dart`, `tool/whitelabel.dart` |
| T-2 | Registry provider: resolve variant per screen id, default = today | new `core_app/lib/app/config/screen_variants.dart` |
| T-3 | Pilot variant widget + wiring through the registry | `core_app/lib/features/home/presentation/**` |
| T-4 | Unit + widget tests, goldens, drift guards (screens-registration test untouched) | `core_app/test/**` |
| T-5 | Default-proof: halal_boyz config renders zero visual change | `apps/halal_boyz/assets/client_config.json` (must stay byte-identical) |

## 5. EXECUTION NOTES (both windows — the §3.5 cadence)
1. FIRST STEPS in your worktree: `flutter pub get` → `flutter analyze --fatal-infos` (touched packages) → `dart format --output=none --set-exit-if-changed .` (B-4; format already verified clean at sync).
2. Work ONLY inside your §2 territory. Cross-territory need ⇒ STOP, record, re-serialize.
3. Batch end: Gate Set U green → addendum to **`FIX_VERIFICATION.md`** (append; you are the only window touching it if PERF-4 is docs-only — reconcile in the merge commit if you collide) → `git commit` on your `cline/task-N` branch → **merge into `main`** → re-run post-merge gates on main → report back for verification.
4. Merge order: territories are disjoint — either order; second window syncs main before its merge (B-3 re-run).
