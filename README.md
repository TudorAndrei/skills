# A curated skills list

Single source of truth for every [agent skill](https://skills.sh) I use — the
ones I author and the ones I vendor from other people's repos.

Install the whole set into your agents:

```bash
npx skills add TudorAndrei/skills
```

The installer presents two groups: **Essentials** (skills I maintain here) and
**Third-Party** (pinned snapshots of skills maintained upstream).

## Layout & scope

| Location                 | Scope                                    | Holds                                                      | Synced by           |
| ------------------------ | ---------------------------------------- | ---------------------------------------------------------- | ------------------- |
| `skills/<name>/`         | **global** (every project on my machine) | my authored skills **and** vendored external skills I like | `mise run sync`     |
| `.agents/skills/<name>/` | **project-only** (this repo)             | skills used only while working in this repo                | not synced globally |

Project-only skills in `.agents/skills/` are tracked by the `skills` CLI
lockfile (`skills-lock.json`) and refreshed with `mise run update-project`.

## Vendored external skills

External skills are **committed into this repo** at a pinned commit, so the set
is self-contained, reviewable and reproducible. Three files describe each one:

| File                        | Role                                                           |
| --------------------------- | -------------------------------------------------------------- |
| `skills/sources.json`       | declared intent — repo, upstream path, tracked branch, license |
| `skills/sources.lock.json`  | resolved state — pinned commit + deterministic snapshot hash   |
| `skills/<name>/UPSTREAM.md` | generated provenance, alongside `LICENSE.upstream` attribution |

Snapshot directories are generated. Don't hand-edit them — `mise run verify`
notices, and the next update would discard the change anyway. To customize a
vendored skill, use an overlay (below).

Vendoring talks to `git` directly. The `skills` CLI is only used to install and
sync what lands here.

### Overlays

A local change to a vendored skill lives in `vendor-overlays/<name>/` and is
re-applied on top of every fetch, so it survives updates:

```
vendor-overlays/ast-grep/files/mise.toml       # copied over the snapshot
vendor-overlays/ast-grep/setup-block.patch     # applied with `patch -p1`
```

Patches apply first, then `files/`. A patch that stops applying is a hard error
rather than a silent drop — upstream moved under the customization and that
needs a look. Changing an overlay changes the snapshot, so re-lock it with
`mise run update <name>`.

## Tasks

```bash
mise run add <owner/repo[@skill]>   # vendor an external skill as a pinned snapshot
mise run update [name...]           # advance to tracked branch heads (previews, asks once)
mise run restore [name...]          # re-fetch at pinned commits, discarding local edits
mise run verify                     # offline: manifest, lock, hashes, licenses, catalog
mise run catalog                    # regenerate .claude-plugin/marketplace.json
mise run sync                       # symlink everything in skills/ globally (Codex + Claude Code)
mise run update-project             # refresh .agents/skills via the skills CLI

npx skills add <owner/repo[@skill]> # add a remote skill for THIS repo only (.agents/skills)
```

Examples:

```bash
mise run add shadcn/improve                              # -> skills/improve
mise run add heygen-com/hyperframes --skill gsap         # one skill from a multi-skill repo
mise run add github/awesome-copilot@postgresql-optimization
```

`add` resolves the tracked branch, locates the skill upstream, captures the
license, writes provenance and records the commit and hash. Every operation
stages and validates all snapshots before replacing anything, so a failure
part-way through leaves the working tree untouched.

## Catalog

`.claude-plugin/marketplace.json` is generated, never hand-edited. Group
membership is derived: a skill with a lock entry is Third-Party, anything else
with a `SKILL.md` is Essentials. `mise run verify` fails on drift.

`hk-vendored.pkl` is generated from the same lock and keeps hk's formatters off
the vendored snapshots — an auto-fix there would drift the hash on every commit.
