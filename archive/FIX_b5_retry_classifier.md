# FIX-B5 — QUEUE-3: ONE retry classifier + one documented backoff contract (`packages/core` only)

**Batch:** `B5` · **Findings:** `AUD1-03` (MED-HIGH), `AUD1-17` (LOW) · **Authority:** `AUDIT_TRIAGE_STAGE3.md` §2.2/§3 + §9 (wave-3 territory adjustment).
**Worktree:** `<repo>-cline-4` (`cline/task-4`). May run ∥ `B3`. **No `functions/**` file is touched** → no collision with `B4`/`B12`.

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`); UNVERIFIED section mandatory if non-empty. 0.3 Red→green per task, receipt **before** the fix. 0.4 Ledger single-writer. 0.5 Territory exclusivity (§2) + the §9 standing rule (an unlisted call site ⇒ STOP, never a silent extension). 0.6 Never end on red; commit per task. 0.7 **Fail-closed, both directions:** a **permanent** error must never be retried (it burns budget and hammers the backend), a **transient** error must never be dropped to the DLQ prematurely, and an **unknown** error is transient but always bounded by `kMaxRetries` (never an infinite retry). 0.8 No new dependencies. 0.9 Git strictly serialized.

## §1 Research receipts (verified at `1f38508`)

| Fact | Evidence |
|---|---|
| **Twin A:** `class NetworkRetry` + `static bool isRetryable(Object error)` ("batch QUEUE-2, contract 1"); ladder **1000 → 2000 → 4000 ms**, default `maxRetries` 3 ⇒ 4 attempts | `packages/core/lib/src/network/network_retry.dart:10`, `:29`, `:40`; AUD-1 `c3_parity_run.log` TWIN-3 |
| **Twin B:** `class IsarSyncQueue`, `kMaxRetries = 5`, `static bool isPermanentFailure(Object error)`; ladder `1 << op.retryCount.clamp(0, 5)`; DLQ move at `retryCount >= kMaxRetries` | `packages/core/lib/src/network/sync_queue.dart:78`, `:84`, `:99`, `:261-269`; consumer `pending_sync_provider.dart:48` |
| **Divergence (TWIN-2): 5 codes** — `not-found`, `invalid-argument`, `unauthenticated`, `failed-precondition`, `already-exists` ⇒ `NetworkRetry` says permanent, `IsarSyncQueue` retries them | `tool_audit/aud1/receipts/c3_parity_run.log` (9-row matrix, 5 DIVERGE) |
| `NetworkRetry.withExponentialBackoff` consumers (12 sites): checkout ×5, promo, menu repo, order repo, auth repo, gdpr, data-export, panic-switch | coordinator grep at `1f38508` |
| Existing pinned behaviour: `packages/core/test/sync_queue_test.dart` (DLQ boundary, classification), `core_app/test/core/network/sync_queue_test.dart`, plus `network_retry_test.dart` (both trees) and `core_app/test/core/retry_logic_test.dart` | coordinator grep at `1f38508` |

## §2 Territory

**MODIFIED:** `packages/core/lib/src/network/network_retry.dart` · `packages/core/lib/src/network/sync_queue.dart` (both route through the single classifier) · **only if a signature changes**, the enumerated call sites: `pending_sync_provider.dart`, `data_export_service.dart`, `panic_switch_service.dart`, `checkout_service.dart` (**classification call only — no money logic**), `promo_code_service.dart`, `menu_repository.dart`, `order_repository.dart`, `auth_repository.dart`, `gdpr_service.dart`.
**CREATED:** parity/regression tests under `packages/core/test/**` (+ the `core_app` mirror only where a mirrored test for the same subject already exists) · receipts in `tool_fix/b5/**`.
**FORBIDDEN:** `core_app/functions/**` · any money/tax/total file · DLQ schema/column changes · theme · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — one classifier.** A single canonical predicate (`NetworkRetry.isRetryable` as source of truth) used by **both** entry points; `IsarSyncQueue.isPermanentFailure` becomes a delegating shim (public signature kept so existing callers/tests compile). The 5 divergent codes are resolved by an **explicit table with a per-code rationale** citing Firebase/gRPC error-code semantics — never by picking a side arbitrarily.

**T-2 — the parity matrix (the red).** Assert the 9-code TWIN-2 matrix through **both** entry points. RED today = the 5 divergent rows. GREEN = 9/9 AGREE with the rationale table alongside.

**T-3 — the backoff ladder pinned (`AUD1-17`).** Either unify the ladders or keep them distinct **with the relationship stated and pinned by a test** (attempt counts + delay sequences for both), so a future edit to one cannot silently diverge. If unifying, every `kMaxRetries` semantic that a test pins must be preserved.

**T-4 — DLQ semantics preserved.** The `kMaxRetries` boundary and the DLQ move behave exactly as today; `sync_queue_test.dart` (both copies) **byte-unchanged** and green.

**T-5 — fail-closed both directions.** Tests: unknown error ⇒ retried but bounded; permanent error ⇒ never consumes the retry budget; transient error ⇒ not dropped to the DLQ before `kMaxRetries`.

## §4 Deliverable

`tool_fix/b5/b5_report.md`: T-table (red → green), the 9-row matrix before/after, the per-code rationale table, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B5` ledger block. Receipts in `tool_fix/b5/`.

## §5 Acceptance

red→green per T · `dart analyze` core 0 · `flutter analyze --fatal-infos` core_ui + core_app 0 · format 0 · suites core + core_ui + core_app green **0 skip** no drop · existing `sync_queue_test.dart`/`network_retry_test.dart` files **byte-unchanged** · TWIN-2 matrix **9/9 AGREE** · ladder pinned (T-3) · **zero diff in `functions/**`** · greps 0 · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery on the committed tip; spot-checks ≥3 (the red matrix shows exactly the 5 divergent codes; the rationale table covers all 9; no existing queue/retry test modified); merges; appends the ledger block; flips `AUD1-03` + `AUD1-17` → **CLOSED-WITH-RECEIPT** and re-runs the C3 TWIN-2/TWIN-3 detectors.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B5 (QUEUE-3: one retry classifier + pinned backoff contract). Worktree <repo>-cline-4 (branch cline/task-4). May run beside B3; touch NO functions/ file.
Read <repo>\FIX_b5_retry_classifier.md IN FULL — binding contract; fail-closed both directions (§0.7).
1. SYNC (fail-closed): assert branch == cline/task-4; git merge main; flutter pub get; BLOCKER gate: analyze core/core_ui/core_app, format root, suites core/core_ui/core_app green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: write the 9-row TWIN-2 matrix (both entry points) + the ladder test first; capture failures to tool_fix/b5/red_*.txt (expect 5 DIVERGE rows).
3. GREEN: implement T-1..T-5; keep the shim so existing callers compile; commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. PROOF: sync_queue/network_retry tests byte-unchanged (git diff); functions/** diff EMPTY; territory + grep evidence.
5. REPORT: tool_fix/b5/b5_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-4; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + matrix 9/9 + DLQ semantics unchanged + nothing uncommitted.
```

