# Publishing this repository

**Public home:**
`https://github.com/muhammadfazalerabbianjum-dot/resturant-ecosystem` — published
2026-11-23 as a single snapshot commit. §3 records the steps that created it, so
they can be repeated for a rebuild.

One repository, one README, one deep dive. The public code is published from a
branch that contains no history and no live identifiers; the full history and the
real configuration stay in this working repository.

---

## 1. Two folders, one project

| Folder | Contains | Where it goes |
| --- | --- | --- |
| `A:\resturant` (this working repo) | the whole tree, the full history, the **real** client configuration | stays local / private. This is where the work happens and where you build from |
| `A:\carnama-public` | the same tree, scrubbed, as **one commit with no parents** | pushed to the public repository as `main` |

Why a separate repository rather than deleting the keys in a new commit: git
keeps every version of every file, so a scrubbed tree on top of a history that
still contains `client_config.json` with a live project id is not scrubbed —
anyone can `git log -p` it back. The public copy starts at zero.

Why a separate folder rather than a branch here: this repository installs a
pre-commit guard that deliberately refuses a commit touching `tool_audit/`
alongside other files, which a whole-tree snapshot always does. Rather than
disabling the guard, the snapshot is assembled outside this repo, where no hook
applies.

Cost, stated plainly: the public repository shows one commit, not the 119 that
built the project. The evidence for the work is still public in `checkpoints/`
and `docs/DECISIONS.md`; the commit history is not.

## 2. What the scrub changes

| Kind of value | Public value |
| --- | --- |
| Firebase API keys (mobile + web, both platforms) | `AIzaSyDEMO…` placeholder, not key-shaped |
| the primary project id | `demo-restaurant` |
| the reference tenant's project id | `demo-tenant` |
| the FCM sender id / app-id prefix | `000000000000` |
| the Cloudinary cloud name | `demo-cloudinary` |
| the owner's mailbox (hardcoded owner check + emulator seed) | `owner@example.com` |
| a second mailbox found in an archive note (CLI login line) | `owner@example.com` |
| a second project number found in older configs | `000000000000` |
| absolute machine paths (working repo, worktrees, snapshot folder, audit
folder, a second project folder) | `<repo>`, `<snapshot>`, `<repo>-worktree`,
`<audit-folder>`, `<other-project>` |
| the Windows profile folder in `C:\Users\…` | `C:\Users\user` |

The values themselves are deliberately **not written in this document**: this
file is published, and a scrub list that names the secrets is the leak it is
supposed to prevent. `tool/_public_scrub.mjs` holds them as fragments, which is
why it can be published safely.

Kept deliberately: the `google-services.json`, `GoogleService-Info.plist`,
`firebase_options.dart` and `.firebaserc` files **as scrubbed placeholders**. They
are deleted in most public repos; here they stay so the tree still compiles and
the shape of a real Firebase setup is visible, with nothing live in them.

Removed from the public snapshot: `.github/skills/`, `.github/copilot-instructions.md`,
and the assistant-tooling dot directories (`.claude`, `.cursor`, `.clinerules`,
`.continue`, `.gemini`, `.kimi-code`, `.impeccable`, `.gortex`, `.windsurfrules`,
`.clineignore`, `.aiderignore`). They are how this repository was operated, not
what it is. `core_app/.agents/` goes with them.

Also pruned, because they are machine output rather than project content:
`core_app/emulators_log.txt` (a captured emulator run, full of `C:\Users\…`
paths) and `core_app/docs/archive/stdout.txt` (a captured build log). The scrubber
deletes both, so a rebuilt snapshot cannot reintroduce them.

Two further items are dropped rather than repaired. The root `isar.dll` is a 1.1 MB native Isar 3.1.0 binary that nothing references any more: the current test helpers resolve the lockfile-pinned core through `package_config.json`, as `core_app/DEFERRED.md` (D-P34-1) records. `.github/workflows/carnama_ci.yml` is real CI and runs in the private repository, but against a scrubbed snapshot it would report every job red on each push, so the public copy ships without it. Both are on the scrubber's prune list, so a rebuild cannot add them back.

This document is the one file exempt from path replacement: it is instructions
to run on this machine, so its folder names are the point of it. It is still
scrubbed for keys, project ids and the owner's mailbox.

## 3. Publishing (done; kept as the repeatable procedure)

The public repository was created empty on that account, then pushed from the
snapshot folder. The same steps apply to a rebuild:

1. Sign in to GitHub as `muhammadfazalerabbianjum-dot` — that account only; the
   public copy is not published from any other login.
2. Create a repository named `resturant-ecosystem`, **Public**, with **no**
   README, no `.gitignore` and no licence file — a push cannot create a
   repository, and an initialised one makes the first push a non-fast-forward.

Then push from the snapshot folder. That folder is the only one with a public
destination:

```bash
cd "A:/carnama-public"                        # the scrubbed snapshot
node tool/_public_scrub.mjs --check           # must print CLEAN, exit 0
git remote -v                                 # origin must be .../resturant-ecosystem
git push -u origin main
```

If GitHub asks for credentials, sign in as `muhammadfazalerabbianjum-dot`.

Do **not** run `git push` from `A:\resturant`: that is the working repository —
its history still contains the live identifiers, and it has no public remote.

### 3.1 Rebuilding the snapshot after new work

Nothing is edited in `A:\carnama-public`; it is rebuilt. From the working repo:

```bash
rm -rf "A:/carnama-public" && mkdir -p "A:/carnama-public"
git archive HEAD | tar -x -C "A:/carnama-public"
cd "A:/carnama-public"
git init -q -b main
git add -A                       # BEFORE the scrub: it reads `git ls-files`
node tool/_public_scrub.mjs
rm -rf .github/skills .github/copilot-instructions.md .claude .cursor \
       .clinerules .continue .gemini .kimi-code .impeccable .gortex \
       .windsurfrules .clineignore .aiderignore _agents
git add -A && git commit -m "Carnama: multi-tenant, white-label restaurant ordering platform"
node tool/_public_scrub.mjs --check
```

The order matters: the scrub walks `git ls-files`, and in a fresh repository
nothing is listed until the first `git add`. Running it before staging reports a
false **CLEAN** because it scanned an empty list.

### 3.2 The scrub

`tool/_public_scrub.mjs` is intentionally tiny and readable — a reader can verify
that it only replaces the values in §2 and touches no logic:

```bash
node tool/_public_scrub.mjs --check   # fails if any live value remains
```

Run `--check` before every push. A non-zero exit means do not push.

## 4. Before the first push

```bash
cd "A:/carnama-public"
node tool/_public_scrub.mjs --check      # must print CLEAN and exit 0
git ls-files | grep -Ei 'serviceAccount|\.env$|dev\.vars|keystore|\.jks'   # must be empty
git log --oneline                        # must be exactly one commit
```

Then, on GitHub, in the public repository's settings:

1. **Secret scanning + push protection: on.**
2. **Dependabot alerts: on** (the lockfiles are committed).
3. Branch protection on `main`: no force-push, require a pull request for
   changes, but allow the owner to push directly if you prefer a single-maintainer
   flow.
4. Add the description and topics: `flutter`, `firebase`, `multi-tenant`,
   `white-label`, `restaurant`, `cloud-functions`, `firestore-rules`.

## 5. If a live identifier is ever pushed

Rotate first, delete second. For Firebase: create a new web API key, restrict it
to your domains, and enforce App Check on Firestore, Storage and Functions. For
Stripe: roll the key. Deleting the commit does not un-publish anything.

The project already has the tools for the other half of this: `assertCapability`
on every privileged callable, tenant-claim rules, and a webhook signature check.
Those protect the backend even if the code is public — that is the real defence,
not the file list.

## 6. Taking the work to a new industry

A config is cheaper than a fork, and the project is built that way: the shared
body is one thing, a brand is one validated JSON file.

```bash
cp apps/halal_boyz/assets/client_config.json apps/<new_brand>/assets/client_config.json
# edit: tenantId, app.*, firebase.*, environment.*, theme.*, navigation.*
cd core_app
dart run tool/whitelabel.dart --config ../apps/<new_brand>/assets/client_config.json --dry-run
dart run tool/whitelabel.dart --config ../apps/<new_brand>/assets/client_config.json
node ../tool/gate.mjs check          # gate (e) now validates the new config too
```

The human-only half is in `docs/CLIENT_BACKEND_RUNBOOK.md`: create the Firebase
project, register the apps, download the client configs, enable App Check,
provision Stripe. No script can create those accounts.

A second **repository** is only right for a different **product** (a lead scraper,
an outreach system), never for a different brand. If that happens: do not fork the
money path, do not fork `firestore.rules`, carry `tool/gate.mjs` with the code,
and drop the old tenant's config.
