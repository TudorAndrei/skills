# A curated skills list

Single source of truth for every [agent skill](https://skills.sh) I use — the
ones I author and the ones I vendor from other people's repos.

Install the whole set into your agents:

```bash
npx skills add TudorAndrei/skills
```

## Layout & scope

| Location                     | Scope                                    | Holds                                       | Synced by           |
| ---------------------------- | ---------------------------------------- | ------------------------------------------- | ------------------- |
| `skills/<name>/`             | **global** (every project on my machine) | skills I author here                        | `mise run sync`     |
| `skills/<publisher>/<name>/` | **global**                               | vendored snapshots, grouped by who wrote it | `mise run sync`     |
| `.agents/skills/<name>/`     | **project-only** (this repo)             | skills used only while working in this repo | not synced globally |

Vendored skills sit under their publisher, so a directory listing shows at a
glance whose work is in here:

```
skills/
  advisor/                  # authored here, stays flat
  plan/
  mattpocock/               # vendored, grouped by publisher
    tdd/
    grilling/
  anthropics/frontend-design/
  jakubkrehel/better-ui/
```

The publisher directory organizes the tree; it does not namespace the skill.
Agents load a skill by the `name` in its frontmatter, so names still have to be
globally unique — `mise run verify` fails if two directories share one.

Project-only skills in `.agents/skills/` are tracked by the `skills` CLI
lockfile (`skills-lock.json`) and refreshed with `mise run update-project`.

## Vendored external skills

External skills are **committed into this repo** at a pinned commit, so the set
is self-contained, reviewable and reproducible. Three files describe each one:

| File                                    | Role                                                           |
| --------------------------------------- | -------------------------------------------------------------- |
| `skills/sources.json`                   | declared intent — repo, upstream path, tracked branch, license |
| `skills/sources.lock.json`              | resolved state — pinned commit + deterministic snapshot hash   |
| `skills/<publisher>/<name>/UPSTREAM.md` | generated provenance, alongside `LICENSE.upstream` attribution |

The publisher directory is the slug of the manifest's `author` (the repo owner
unless `--author` says otherwise), so re-attributing a skill relocates it on the
next `mise run update`. The snapshot hash covers content and relative paths only,
so moving a snapshot never invalidates its lock entry.

Snapshot directories are generated. Don't hand-edit them — `mise run verify`
notices, and the next update would discard the change anyway. To customize a
vendored skill, use an overlay (below).

Vendoring talks to `git` directly. The `skills` CLI is only used to install and
sync what lands here.

### Overlays

A local change to a vendored skill lives in `vendor-overlays/<name>/` and is
re-applied on top of every fetch, so it survives updates:

```text
vendor-overlays/ast-grep/tool-metadata.patch   # applied with patch -p1
vendor-overlays/<name>/files/<path>            # copied over the snapshot
```

Patches apply first, then `files/`. A patch that stops applying is a hard error
rather than a silent drop — upstream moved under the customization and that
needs a look. Changing an overlay changes the snapshot. Use
`mise run relock <name>` to keep the pinned upstream commit and refresh the
snapshot hash. Use `mise run update <name>` when you also want a new upstream
commit.

## Skill tools

A skill that owns an external CLI declares it in `SKILL.md` frontmatter:

```yaml
metadata:
  tools:
    - source: mise
      command: ast-grep
      spec: ast-grep@0.45.1
```

`command` is the executable that the skill runs. `spec` is the complete,
fixed-version mise specification. Do not declare the target project's runtime,
package manager, database, system service, or an optional alternative.

Run `mise run install-skill-tools` to collect these entries, reject version
conflicts, and add the tools to the global mise config after one confirmation.
`mise run sync` does not change the global config. It reports missing declared
tools and recommends the install task.

## Tasks

```bash
mise run add <owner/repo[@skill]>   # vendor an external skill as a pinned snapshot
mise run update [name...]           # advance to tracked branch heads (previews, asks once)
mise run relock [name...]           # keep pinned commits; refresh hashes after overlay changes
mise run restore [name...]          # re-fetch at pinned commits, discarding local edits
mise run verify                     # offline: manifest, lock, hashes, locations, licenses
mise run hk-excludes                # regenerate hk-vendored.pkl
mise run sync                       # symlink every skill globally (Codex + Claude Code)
mise run install-skill-tools        # install declared skill CLIs through the global mise config
mise run update-project             # refresh .agents/skills via the skills CLI

npx skills add <owner/repo[@skill]> # add a remote skill for THIS repo only (.agents/skills)
```

Examples:

```bash
mise run add shadcn/improve                              # -> skills/shadcn/improve
mise run add heygen-com/hyperframes --skill gsap         # one skill from a multi-skill repo
mise run add jakubkrehel/skills --skill better-ui,better-colors
mise run add github/awesome-copilot@postgresql-optimization
```

`add` resolves the tracked branch, locates the skill upstream, captures the
license, writes provenance and records the commit and hash. Every operation
stages and validates all snapshots before replacing anything, so a failure
part-way through leaves the working tree untouched. A copy of the same skill
left at an older path — flat, or under a previous attribution — is moved in the
same transaction, and `mise run verify` reports one that was moved by hand.

## Generated files

`hk-vendored.pkl` is generated from the lock and keeps hk's formatters off the
vendored snapshots — an auto-fix there would drift the hash on every commit.
`mise run verify` fails if it no longer matches the snapshot paths.
