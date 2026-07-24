# A curated skills list

Single source of truth for every [agent skill](https://skills.sh) I use — the
ones I author and the ones I vendor from other people's repos.

Install the whole set into your agents:

```bash
npx skills add TudorAndrei/skills
```

## Layout & scope

| Location                 | Scope                                    | Holds                                                      | Synced by           |
| ------------------------ | ---------------------------------------- | ---------------------------------------------------------- | ------------------- |
| `skills/<name>/`         | **global** (every project on my machine) | my authored skills **and** vendored external skills I like | `mise run sync`     |
| `.agents/skills/<name>/` | **project-only** (this repo)             | skills used only while working in this repo                | not synced globally |

Vendored external skills are **cloned into this repo** (not referenced) so the
set is self-contained and versioned. Each carries a one-line `.skill-source`
marker recording where it came from, so it can be refreshed:

```
skills/improve/.skill-source   ->  shadcn/improve
```

Project-only skills in `.agents/skills/` are tracked instead by the `skills`
CLI lockfile (`skills-lock.json`).

## Tasks

```bash
mise run add <owner/repo[@skill]>   # clone a remote skill into skills/ (global scope)
mise run update                     # refresh every vendored external skill from source
mise run sync                       # symlink everything in skills/ globally (Codex + Claude Code)

npx skills add <owner/repo[@skill]> # add a remote skill for THIS repo only (.agents/skills)
```

Example:

```bash
mise run add shadcn/improve         # -> skills/improve, synced globally
```

`mise run add` / `update` use `scripts/vendor-skill.sh`: they let the `skills`
CLI clone and locate the skill, relocate the copy into `skills/<name>/`, drop
the `.skill-source` marker, and remove the CLI's lock entry (global skills are
tracked by marker, not by the lockfile).
