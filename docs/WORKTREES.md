# WORKTREES — census and recommendations

**Status: awaiting owner ruling. Nothing was deleted, merged or pruned.** Law L5
allows no destructive action in P0, so every `SAFE-PRUNE` row below is a
*recommendation*, not an action.

Census taken 2026-11-07 against `cline/p32-golden-gates` @ `7c139d5c`.

## 1. The finding that drives everything else

```text
$ git branch --merged cline/p32-golden-gates
cline/p32-golden-gates  cline/task-1  cline/task-2  cline/task-3  cline/task-4
cline/task-5  cline/w3-p21  cline/w3-p22  cline/w4-p18  cline/w4-p25
cline/w5-p17  cline/w5-p24  cline/w6-p26  hotfix/app-check-cast
impeccable/ui-three-recs  main  p28/lane-a  p28/lane-b  p29/security-debt
p33/config-deadkeys
```

**Every one of the 20 local branches is already merged into the current HEAD.**
Confirmed independently by `git rev-list --left-right --count` for each worktree
branch: the ahead count is `0` in all eleven cases. There is no unmerged commit
anywhere in this repository.

The consequence is that "unique work" can only exist as **uncommitted files**,
which is why the dirty column below is the only interesting one.

## 2. Worktrees

Diff numbers are `git -C <path> diff --shortstat cline/p32-golden-gates`, i.e.
the working tree of that checkout versus today's HEAD.

| # | Path | Branch | Last commit | Dirty | vs HEAD | Recommendation | Reason |
|---|---|---|---|---|---|---|---|
| 1 | `<repo>` | `cline/p32-golden-gates` | `7c139d5c` 2026-10-16 | 88 | 14 files, +40/−8 | **KEEP** | The truth root. The dirt is the owner's and is deliberately excluded from gate judgement (L11). |
| 2 | `<repo>-worktree` | `cline/w6-p26` | `266e931f` 2026-10-02 | 0 | 742 files, +1119/−192,788 | SAFE-PRUNE | Merged, clean, 92 commits behind. |
| 3 | `<repo>-cline-2` | `cline/w5-p24` | `266e931f` 2026-10-02 | 0 | 742 files, +1119/−192,788 | SAFE-PRUNE | Merged, clean, 92 behind. |
| 4 | `<repo>-cline-3` | `cline/task-3` | `266e931f` 2026-10-02 | 0 | 742 files, +1119/−192,788 | SAFE-PRUNE | Merged, clean, 92 behind. |
| 5 | `<repo>-cline-4` | `cline/task-4` | `564c0337` 2026-10-02 | 0 | 714 files, +1119/−191,531 | SAFE-PRUNE | Merged, clean, 87 behind. |
| 6 | `<repo>-cline-5` | `cline/task-5` | `266e931f` 2026-10-02 | 0 | 742 files, +1119/−192,788 | SAFE-PRUNE | Merged, clean, 92 behind. |
| 7 | `<repo>-p28a` | `p28/lane-a` | `c1d96136` 2026-10-01 | 0 | 817 files, +1121/−200,590 | SAFE-PRUNE | Merged, clean, 102 behind. |
| 8 | `<repo>-p28b` | `p28/lane-b` | `b8a78aeb` 2026-10-02 | 0 | 781 files, +1119/−198,222 | SAFE-PRUNE | Merged, clean, 96 behind. |
| 9 | `<repo>-p29` | `p29/security-debt` | `49bd8409` 2026-10-02 | 0 | 660 files, +994/−168,441 | SAFE-PRUNE | Merged, clean, 78 behind. |
| 10 | `<repo>-p33` | `p33/config-deadkeys` | `e24f949b` 2026-10-05 | 1 | 523 files, +853/−153,029 | **REVIEW** | One untracked file, `archive/WHITE_LABEL_p33_config_deadkeys.md` (11,468 B), which exists nowhere else. Preserve it, then prune. |
| 11 | `<repo>-shots` | `hotfix/app-check-cast` | `a105a05e` 2026-10-04 | 4 | 571 files, +848/−153,600 | **REVIEW** | Four uncommitted tracked-file edits, one of them in `core_app/lib/app_bootstrap.dart` — a frozen-area file. Read before deleting anything. |

### Why the deletion columns are enormous

They measure **staleness, not lost work**. Each branch was cut weeks before
files that now exist were added, so the diff reports those files as deletions.
The authoritative uniqueness test is `--merged` plus an ahead-count of `0`, both
of which are clean. Do not read "−192,788" as "someone's work was thrown away".

### The two worktrees that hold uncommitted work

| Path | File | Size of change |
|---|---|---|
| `<repo>-shots` | `apps/halal_boyz/android/app/build.gradle.kts` | +3 |
| | `apps/halal_boyz/android/app/src/main/kotlin/labs/carnama/halal_boyz/MainActivity.kt` | +7/−2 |
| | `apps/halal_boyz/android/app/src/main/res/values/styles.xml` | +8/−2 |
| | `core_app/lib/app_bootstrap.dart` | +15/−5 |
| `<repo>-p33` | `archive/WHITE_LABEL_p33_config_deadkeys.md` (untracked) | 11,468 B |

`app_bootstrap.dart` is the boot chain — law L9 forbids P0 from touching it, and
this edit predates P0. It may be the App Check cast hotfix that the branch name
implies. **Owner decision required:** keep it (move the patch onto the truth
root deliberately, with a test) or discard it.

## 3. Branch refs with no worktree

All merged, therefore no unique commits:

| Branch | Last commit | Recommendation |
|---|---|---|
| `cline/task-1` | 2026-09-27 | SAFE-PRUNE (after ruling) |
| `cline/task-2` | 2026-09-27 | SAFE-PRUNE (after ruling) |
| `cline/w3-p21` | 2026-09-29 | SAFE-PRUNE (after ruling) |
| `cline/w3-p22` | 2026-09-28 | SAFE-PRUNE (after ruling) |
| `cline/w4-p18` | 2026-09-29 | SAFE-PRUNE (after ruling) |
| `cline/w4-p25` | 2026-09-29 | SAFE-PRUNE (after ruling) |
| `cline/w5-p17` | 2026-09-30 | SAFE-PRUNE (after ruling) |
| `impeccable/ui-three-recs` | 2026-10-03 | SAFE-PRUNE (after ruling) |
| `main` | 2026-10-04 | **KEEP** — merged but it is the nominal default branch |
| `origin` (HEAD ref) + 7 `origin/*` | 2026-09-17 … 2026-10-16 | KEEP — remote-tracking refs; deleting them is a remote operation |

Ref count: 28 by `git branch -a` (20 local + 1 remote HEAD + 7 remote-tracking).

## 4. Commands used (reproducible)

```text
git worktree list
git worktree list --porcelain
git branch --merged cline/p32-golden-gates
git branch -a --format='%(refname:short)|%(committerdate:short)'
git -C <path> log -1 --format='%h|%ad' --date=short
git -C <path> status --porcelain
git -C <path> diff --shortstat cline/p32-golden-gates
git -C <path> rev-list --left-right --count cline/p32-golden-gates...<branch>
```

## 5. Recommendation to the owner

1. Approve pruning the eight clean merged worktrees (rows 2–9). This removes the
   "which folder is real?" question that the handoff scored 4/10 on hygiene.
2. Decide on `<repo>-shots`' four edits **before** any prune, because a
   prune deletes uncommitted work without asking.
3. Preserve `archive/WHITE_LABEL_p33_config_deadkeys.md` somewhere tracked, then prune
   `<repo>-p33`.
4. Do the deleting in a single session with a single record, not incrementally —
   and only after this P0 pack is signed off.

## Disposition — 2026-11-09 (P1-2a, owner ruling D-029)

Sequence executed per D-029. Branch list re-proved with
`git branch --merged cline/p32-golden-gates` **before** any removal; all eight
SAFE-PRUNE branches appeared in it. A verified bundle now exists for each:

| Branch | Bundle | Verify |
|---|---|---|
| `cline/w6-p26` | `backups/cline-w6-p26.bundle` | ok |
| `cline/w5-p24` | `backups/cline-w5-p24.bundle` | ok |
| `cline/task-3` | `backups/cline-task-3.bundle` | ok |
| `cline/task-4` | `backups/cline-task-4.bundle` | ok |
| `cline/task-5` | `backups/cline-task-5.bundle` | ok |
| `p28/lane-a` | `backups/p28-lane-a.bundle` | ok |
| `p28/lane-b` | `backups/p28-lane-b.bundle` | ok |
| `p29/security-debt` | `backups/p29-security-debt.bundle` | ok |

**Pruned (worktree removed + `branch -d`, never `-D`):**
`cline/w6-p26` (`<repo>-worktree`), `cline/w5-p24` (`<repo>-cline-2`,
whose checkout directory was still on disk after metadata removal and was
deleted with the verified bundle in place), `cline/task-3`
(`<repo>-cline-3`).

**Pruned on resume (2026-11-10), one worktree per command, exit code checked
each time:** `cline/task-4`, `cline/task-5`, `p28/lane-a` (its branch had also
been merged into `main`), `p28/lane-b`, `p29/security-debt`. **All eight
SAFE-PRUNE branches are now pruned; zero worktrees remain outside the main tree
and the two REVIEW trees. Nothing was forced, no branch was deleted without a
verified bundle and a merge proof, and no `-D` was used anywhere.**

Per-branch logs: `backups/p12a-*.log` (gitignored, alongside the bundles).

**Preserved (owner reviews personally, D-027):** `<repo>-shots`
(`hotfix/app-check-cast`, 4 uncommitted files) and `<repo>-p33`
(`p33/config-deadkeys`, 1 untracked file). Untouched.
