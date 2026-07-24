# Command cookbook

Copy-paste recipes for the four phases. Adapt paths, thresholds, and branch names to the repo.

## Measuring size

```bash
du -sh .git                 # on-disk history size
git count-objects -vH       # object count + pack size (human units)
```

## Finding the largest blobs

### Preferred: git-filter-repo's analyzer

```bash
git filter-repo --analyze
```

Reports land in `.git/filter-repo/analysis/`:

- `path-all-sizes.txt` — total bytes each path has cost across all of history (best for "what's worth deleting").
- `path-deleted-sizes.txt` — sizes for paths that no longer exist at HEAD (dead weight still in history).
- `blob-shas-and-paths.txt` — every blob SHA, its size, and the path(s) it lived at.
- `directories-all-sizes.txt` — same, aggregated per directory.

### Dependency-free one-liner (no filter-repo needed)

Lists the 20 largest blobs by size, then resolves each SHA to its path(s):

```bash
git rev-list --objects --all \
| git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
| awk '/^blob/ {print $2, $3, $4}' \
| sort -k2 -n \
| tail -20 \
| numfmt --field=2 --to=iec-i --suffix=B --padding=8 --round=nearest
```

Resolve a single SHA to the paths it ever occupied:

```bash
git rev-list --objects --all | grep <sha>
```

### List packed objects by size (fast, on a repacked repo)

```bash
git verify-pack -v .git/objects/pack/*.idx \
| sort -k3 -n | tail -20
```

## Deleting stale branches

List by last-commit date:

```bash
git for-each-ref --sort=committerdate refs/heads/ \
  --format='%(committerdate:short)  %(refname:short)'          # local
git for-each-ref --sort=committerdate refs/remotes/origin/ \
  --format='%(committerdate:short)  %(refname:short)'          # remote
```

Delete a reviewed list (always review before deleting the remote):

```bash
git push origin --delete branch-a branch-b branch-c    # remote (batchable)
git branch -D branch-a branch-b                         # local
```

Delete every remote branch except a keep-list (review the printed list first — pipe to `cat` before piping to the delete):

```bash
git for-each-ref --format='%(refname:short)' refs/remotes/origin/ \
| sed 's#^origin/##' \
| grep -vxE 'main|master|HEAD|release/.*' \
| xargs -r -n50 git push origin --delete
```

Delete all tags locally (do this only after archiving anything the tags/releases reference):

```bash
git tag | xargs -r git tag -d
git push origin --delete $(git ls-remote --tags origin | awk '{print $2}' | sed 's#refs/tags/##')
```

## git-filter-repo path selection

`git-filter-repo` runs on a fresh clone (add `--force` to override its freshness check, only if you understand why it's complaining). It removes the `origin` remote after running.

| Goal                             | Command                                                     |
| -------------------------------- | ----------------------------------------------------------- |
| Strip all blobs over a size      | `git filter-repo --strip-blobs-bigger-than 10M`             |
| Delete specific paths everywhere | `git filter-repo --path a --path b --invert-paths`          |
| Delete by glob                   | `git filter-repo --path-glob '*.mp4' --invert-paths`        |
| Delete by regex                  | `git filter-repo --path-regex '.*/cache/.*' --invert-paths` |
| Keep only certain paths          | `git filter-repo --path keep/this` (no `--invert-paths`)    |
| Read many paths from a file      | `git filter-repo --paths-from-file junk.txt --invert-paths` |

Notes:

- `--invert-paths` flips "keep these" into "delete these." Without it, the listed paths are the _only_ ones kept.
- Combine `--path`, `--path-glob`, and `--path-regex` in one invocation; they union.
- Globs/regex are the right tool for files that moved across many locations or have awkward names (control characters, spaces) — you match a pattern instead of enumerating every historical path.
- Several passes are normal for messy histories. Re-run as needed.

## Reclaim space after rewriting

```bash
git reflog expire --expire=now --all
git gc --prune=now --aggressive
du -sh .git      # compare to baseline
```

## Deploy the rewrite

```bash
git remote add origin <url>            # filter-repo removed it
git push --force origin main           # or --force-with-lease; repeat per kept branch
git push --force origin --tags         # only if tags were intentionally kept/rewritten
```

Force-pushing rewritten history breaks all existing clones — collaborators must re-clone. On GitHub a base-branch rewrite usually auto-closes open PRs, and server-side storage only shrinks after their own repack (or a support request), though clone size drops immediately.
