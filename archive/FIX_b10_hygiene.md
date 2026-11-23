# FIX-B10 — HYGIENE: untracked litter, tracked artifacts, ignore + pre-commit guards

**Batch:** `B10` · **Findings:** `AUD4-C12-02` (212 untracked files, 11.5 MB), `AUD4-C12-03` (215 tracked `*.log` + 3 tracked lcov `*.info` + root litter), `AUD4-C12-05` (`.gitignore` ignores nothing useful; `check-ignore` exit 1), `AUD4-D1` close-out, owner decision **D-6**.
**Worktree:** `<repo>-worktree` (`cline/task-1`). May run ∥ `B11`.

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law — every deletion/keep decision needs a receipt (path, size, classification). 0.3 **Nothing is deleted without proof it is unreferenced**: for every removed path, grep the tree (code, tests, CI, docs, tooling) for readers; a reader ⇒ STOP and report. 0.4 Ledger single-writer. 0.5 Territory (§2). 0.6 Commit per task; never end on red. 0.7 **History is never rewritten** — no `filter-branch`/`rebase`/force-push; removal = a normal commit. 0.8 No new dependencies. 0.9 Git strictly serialized. 0.10 **Foreign artifacts are not mine to judge**: anything produced by another window (e.g. `tool_perf2/**`) is archived or left strictly per D-6, never silently destroyed.

## §1 Research receipts (verified at `15fac44`)

| Fact | Evidence |
|---|---|
| Untracked litter: **212** files / **11,505,001 B** — 200 `tool_perf2/**` + 12 root `perf2_*` logs | AUD-4 C12 (`tool_audit/aud4/**`); re-verify count + size at HEAD |
| Tracked artifacts: **215** `*.log`, **3** lcov `*.info`, root litter, `isar.dll`, 17 `potato*.md`, 15 `tool_audit/aud1/scratch/*.dart` (the last is the AUD-1 W3 breach that also made the format gate red until `6350d8c`) | AUD-4 C12 |
| `.gitignore` gap: `git check-ignore` exits 1 for the litter paths | AUD4-C12-05 |
| `build/`, `coverage/`, `.dart_tool/`, `node_modules/` = **0 tracked** (already clean) | AUD-4 C12 |
| D-6 (owner): archive `tool_perf2/**` receipts, delete root `perf2_*.log`, keep audit receipts, add ignore + guard list | register §5/§6 |

## §2 Territory

**MODIFIED:** `.gitignore` · tracked-artifact removals (the exact list your census receipts name) · a committed guard script (`core_app/tool/*` or `tool_*/`) · `AUDIT_TRIAGE_STAGE3.md` **only** if the coordinator asks (it is the ledger-adjacent register — default: not yours).
**CREATED:** census + classification receipts in `tool_fix/b10/**` · the archive of `tool_perf2/**` (a receipts-branch/tarball per D-6, **not** a deletion) · a pre-commit guard that rejects new litter.
**FORBIDDEN:** any source/test file · `pubspec.*` · `functions/**` · `packages/**` · generated goldens · `FIX_VERIFICATION.md` · `tool_audit/**` (keep those receipts) · history rewriting.

## §3 Tasks (each starts red where a detector exists)

**T-1 — the census, red first.** Committed re-runnable script that prints, at any commit: untracked count/size by directory, tracked-artifact list (`*.log`, `*.info`, `*.dll`, stray root files), and `check-ignore` verdicts. RED: it must currently report the ~212/11.5 MB litter and the 215 tracked logs (that is the finding, machine-readable).

**T-2 — archive the foreign receipts (D-6).** `tool_perf2/**` + root `perf2_*.log` → archive per D-6 (a tarball committed under `tool_archive/` or a receipts branch), then remove from the working tree. Prove: the archive contains the same file count/bytes as the source; the source paths are gone; nothing else changed.

**T-3 — untrack the artifacts that are not fixtures.** For each tracked `*.log` / `*.info` / stray root file: classify (fixture used by a test ⇒ **keep + document**; output ⇒ remove). Remove only the output class, with the unreferenced-grep receipt (§0.3). Record before/after tracked counts.

**T-4 — `.gitignore` + pre-commit guard.** Add the ignore rules that would have prevented the litter (per AUD4-C12-05's proposed list); add a committed pre-commit hook (or `tool/` script the installer wires) that rejects: new untracked litter paths, committed `build/`/`coverage/` artifacts, `*.log` outside the allowlist, and any `git add -A`-style stray (documented). Prove the guard fires on each case and passes on a clean tree.

## §4 Deliverable

`tool_fix/b10/b10_report.md`: census before/after, the archive manifest, the keep/remove classification table, the guard's red/green receipts, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B10` ledger block. Receipts in `tool_fix/b10/`.

## §5 Acceptance

census script committed and re-runnable · archive byte-count proof · every removal backed by an unreferenced grep · `.gitignore` + guard committed with firing proofs · format 0 · analyze ×3 0 · suites core + core_ui + core_app + halal green **0 skip** no drop · no history rewrite · forbidden paths untouched · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the census (expect near-zero litter), the guard (expect it fires), spot-checks the archive manifest against the source listing, verifies no source/test file moved, merges, appends the ledger block, flips `AUD4-C12-02`, `-03`, `-05`, `D-6` → **CLOSED-WITH-RECEIPT**.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B10 (HYGIENE: litter, tracked artifacts, ignore + guard). Worktree <repo>-worktree (branch cline/task-1). May run beside B11.
Read <repo>\FIX_b10_hygiene.md IN FULL — binding contract; the unreferenced-deletion proof (§0.3) and the no-history-rewrite rule (§0.7) apply.
1. SYNC (fail-closed): assert branch == cline/task-1; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core + core_ui, format root, suites core + core_ui + core_app + apps/halal_boyz green 0 skip. Red => STOP + report.
2. T-1 RED: write the census script; capture its first output (the 212/11.5MB + tracked artifacts) to tool_fix/b10/red_census.txt.
3. T-2/T-3/T-4 per §3 (archive foreign receipts; untrack artifact-class files with grep proof; ignore + guard with firing proofs).
4. PROOF: count/byte tables before/after; greps for readers of every removed path; guard fires on all 4 cases.
5. REPORT: tool_fix/b10/b10_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-1 (explicit paths, one commit per task); do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + archive proof + guard proofs + zero unreferenced deletions + nothing uncommitted.
```

