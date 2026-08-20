---
name: shrink-git-repo
description: Shrink a bloated git repository by deleting stale branches and stripping large or binary blobs out of history with git-filter-repo. Use whenever a repo is huge or slow to clone, `.git` has ballooned, someone committed large binaries / build caches / model weights / videos that are still bloating history, there are hundreds of stale branches, or the user asks to reduce repo size, clean up git history, or remove a file from all past commits. This rewrites history destructively, so it always backs up first and confirms before deleting.
compatibility: Requires git and git-filter-repo (install via `pipx install git-filter-repo`, `pip install git-filter-repo`, or `brew install git-filter-repo`). For deleting remote branches / archiving on GitHub, the `gh` CLI is convenient but not required.
metadata:
  tools:
    - source: mise
      command: git-filter-repo
      spec: pipx:git-filter-repo@2.47.0
---

# Shrink a Git Repository

A repository gets big for two reasons that this skill targets: **stale branches** that each carry unique large objects nobody ever merged, and **large or binary blobs baked into history** — checked-in build caches, compiled model output, videos, images, vendored dependencies. Text compresses well in git; binaries do not, and every version of every large file lives forever in history until you rewrite it out.

The goal is to reduce clone size and remove the bloat while preserving the history that actually matters, and to do it without ever losing the ability to recover the original.

## The one rule that matters most: this is destructive and irreversible

Deleting branches and running `git-filter-repo` **rewrite or discard history permanently**. Every commit SHA downstream of a change is rewritten, which means:

- The rewrite cannot be undone once the old objects are garbage-collected.
- Force-pushing the result **breaks every existing clone** — collaborators must delete their copy and re-clone. Trying to rebase old work onto rewritten history is miserable.
- Open pull requests may auto-close when the base branch is rewritten.

Because of this, **never start the destructive steps without a backup and explicit confirmation.** Treat the deploy like air-traffic-control: state each destructive command, confirm it makes sense, then run it. Work the whole process on a **fresh clone**, never on the user's working copy — `git-filter-repo` refuses to run on a non-fresh clone by default for exactly this reason.

### Back up before touching anything

1. Make a complete mirror that is never rewritten:
   ```bash
   git clone --mirror <url> repo-backup.git
   ```
   On GitHub, an alternative is to fork the repo, then immediately detach the fork (unfork) and archive it read-only — that leaves the full original history retrievable forever.
2. If tags/releases will be deleted and any release assets matter, download them first (they are not in git — GitHub stores them separately). `gh release download` per release, or loop over the releases API.
3. Confirm with the user that a re-clone by all collaborators after the rewrite is acceptable before proceeding.

## Workflow

Do this on a fresh clone: `git clone <url> repo-slim && cd repo-slim`.

### 1. Measure and find what is big

Establish a baseline so you can show the before/after, and find the heaviest objects so you target the biggest wins first.

```bash
du -sh .git                 # on-disk size of history
git count-objects -vH       # object count and pack size
```

Find the largest blobs still anywhere in history. The cleanest tool is `git-filter-repo`'s own analyzer:

```bash
git filter-repo --analyze
# writes a report under .git/filter-repo/analysis/
#   path-all-sizes.txt        — cumulative size per path across all history
#   blob-shas-and-paths.txt   — every blob, its size, and the paths it lived at
```

`references/recipes.md` also has a dependency-free shell one-liner for the same job if `--analyze` isn't available.

What you are looking for is almost always a **short list of huge offenders** — a checked-in `webpack` cache, compiled PyTorch/model output committed many times, MP4s and GIFs, large PNGs (sometimes hiding inside SVGs), a vendored dependency tree, `poetry.lock`-style churn. A handful of paths usually accounts for most of the size. Note them; they are the targets for step 3.

Also list branches, since bloat frequently lives on unmerged ones (step 2).

### 2. Delete stale branches

Hundreds of long-abandoned branches each may carry unique large blobs that were committed but never merged. Deleting those branches makes their unique objects unreferenced, so they drop out on the next gc and — importantly — are never sent on a clone. This alone can be a large, low-risk win.

List branches by how recently they were touched so you can pick a cutoff:

```bash
# local
git for-each-ref --sort=committerdate refs/heads/ \
  --format='%(committerdate:short)  %(refname:short)'
# remote
git for-each-ref --sort=committerdate refs/remotes/origin/ \
  --format='%(committerdate:short)  %(refname:short)'
```

Decide what to keep — typically just the primary branch plus any genuinely active release branches. A date cutoff (e.g. nothing untouched for N days) is a reasonable heuristic, but **show the user the list of branches you intend to delete and confirm before deleting**, especially on the remote.

```bash
git push origin --delete <branch>     # delete a remote branch (GitHub, etc.)
git branch -D <branch>                # delete a local branch
```

If the intent is "keep only main," it is safer to enumerate the branches to delete than to script a blanket deletion — review the list first.

### 3. Strip large blobs and dead paths out of history

Now rewrite history to remove the bloat itself. `git-filter-repo` is the tool. Run it on the fresh clone.

**First pass — a blanket size threshold.** This is the fastest way to kill the obvious giants:

```bash
git filter-repo --strip-blobs-bigger-than 10M
```

Every blob over the threshold is removed from every commit in all of history. Pick a threshold above your legitimate large files (check the analyzer output) so you don't strip something load-bearing.

**Targeted removal by path.** To delete specific files or directories everywhere they ever existed:

```bash
git filter-repo --path path/to/junk --path other/junk --invert-paths      # delete these
git filter-repo --path-glob '*.mp4' --path-glob '*.gif' --invert-paths     # delete by pattern
git filter-repo --path-regex '.*/__pycache__/.*' --invert-paths           # delete by regex
```

`--invert-paths` flips the selection from "keep only these" to "delete these." Prefer a glob or regex when a file **moved around a lot** or has an awkward name (control characters, spaces) — matching a pattern is far easier than enumerating every historical location it lived at.

**Dropping an entire dead subtree of history.** If a whole directory was introduced and later deleted, and nothing surviving depends on it, removing that path across all history is often the single biggest reduction available — one dead subtree can be the bulk of a repo. It's just a path deletion:

```bash
git filter-repo --path dead/subdir --invert-paths
```

Notes:

- `git-filter-repo` **removes the `origin` remote** after rewriting (a deliberate guardrail against accidentally pushing). You'll re-add it in step 4.
- It's fine to run it several times for successive passes; complex histories often need more than one invocation.
- Deleting all tags first (`git tag | xargs git tag -d`) simplifies rewrites, since tags pointing into rewritten history otherwise have to be rewritten too — do this only if you've archived anything the tags/releases reference (see backup step).

### 4. Reclaim space, verify, and deploy

Force git to drop the now-unreferenced objects, then confirm the win:

```bash
git reflog expire --expire=now --all
git gc --prune=now --aggressive
du -sh .git          # compare against the baseline from step 1
```

Then push the rewritten history. This is a force overwrite of the remote:

```bash
git remote add origin <url>          # filter-repo removed it
git push --force origin <branch>     # repeat for each branch you kept; --force-with-lease is safer if others may have pushed
git push --force origin --tags       # only if you intentionally kept/rewrote tags
```

After deploying:

- Announce that everyone must **delete their clone and re-clone** — the history changed and their old clones are incompatible.
- On GitHub, a base-branch rewrite typically auto-closes open PRs; expect that.
- GitHub does not shrink server-side storage instantly — clone size drops right away, but repacking on their end (or a support request) may be needed to reclaim their storage. The clone-size and re-clone-speed win is immediate regardless.
- Keep the mirror backup (and any archived original) around read-only so the pre-rewrite contents stay retrievable.

## Command cookbook

`references/recipes.md` collects the copy-paste commands: blob-finding one-liners (including a dependency-free alternative to `--analyze`), the full `git-filter-repo` path-selection flag reference, and branch bulk-deletion snippets. Read it when you need the exact incantation for an edge case.
