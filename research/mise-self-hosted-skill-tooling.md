# Skill tools with mise

Date: 2026-08-20

## Recommendation

Use one central, opt-in setup task for this personal skill repository. The task
must add the required tools to the user's global mise config. After this setup,
skills can run the normal tool commands. They do not need a `mise.toml` file or
a mise wrapper in each skill.

Do not make `mise run sync` change the global config without notice. Add a
separate task, such as `mise run install-skill-tools`. Make `mise run sync`
print a short recommendation when a required tool is not available. You can
also add a `mise run setup` task that runs both tasks after one clear user
request.

This design is a good fit for your local, personal skill set. A portable skill
that other users install alone cannot depend on this repository setup task. For
such a skill, keep a per-skill mise config or give normal install instructions.

## Why the global config is necessary

The root `mise.toml` can install tools into the shared mise store. This action
does not select these tools when a skill runs in a different project. Mise
selects tools from the config for the current directory and from the user global
config.

The command `mise use --global --pin TOOL@VERSION` does two actions:

1. It installs the tool.
2. It writes the exact selected version to the user global mise config.

The tool is then available in other directories when the user has mise shims or
shell activation set up. The official [configuration guide](https://mise.jdx.dev/configuration.html#global-config-miseconfigmiseconfigtoml)
explains the global config. The official [`mise use` guide](https://mise.jdx.dev/cli/use.html)
explains `--global` and `--pin`.

## Tool declaration

Each skill that owns an external CLI declares it in `SKILL.md` frontmatter:

```yaml
metadata:
  tools:
    - source: mise
      command: ast-grep
      spec: ast-grep@0.45.1
```

`command` is the executable that the skill runs. `spec` is the complete,
fixed-version mise specification. The installer scans all skills, removes
duplicate entries, and stops if two skills request different specifications for
one command.

Do not declare the target project's runtime, package manager, database, system
service, or an optional alternative. A declaration means that the skill owns
the tool and that the central task can safely add it to the user global config.

The task changes a file outside this repository. The confirmation is important.
Do not use `--yes` in this task. Do not remove or replace other global tools.

## Version and update policy

Use fixed versions for skill tools. Do not use `latest` in `metadata.tools`.
Test an update in this repository, and then change the version in one scoped
commit.

The global config is user state. A repository lockfile cannot control it after
the install task copies the version there. The fixed version in the task is the
source value. Run the task again after a version change.

Mise keeps installed binaries in a shared store. Different configs can select
different versions without a second copy when the version is the same. See the
official [mise directory guide](https://mise.jdx.dev/directories.html).

## Install task

`mise run install-skill-tools` reads the declarations and runs one
`mise use --global --pin` command. The task asks for confirmation because it
changes the user global mise config. `mise run sync` only checks commands and
recommends the install task when a declared command is missing.

## Repository fit

The [ast-grep skill](../skills/ast-grep/ast-grep/SKILL.md) now uses the central
declaration. It does not need a per-skill config or a repository-relative mise
command.

The repository also vendors external skills. Do not edit a generated vendor
snapshot. Put a change to its `SKILL.md` in `vendor-overlays/<name>/`, as the
[repository README](../README.md) requires.

## Alternative for portable skills

Use a per-skill `mise.toml` only when the skill must carry its tool definition
to another machine without this full repository. In that case, use a fixed
version, commit `mise.lock`, and call mise with the physical skill path. The
`-C` option changes the process directory, so the skill must also preserve the
target project path. The official [task guide](https://mise.jdx.dev/tasks/)
documents `MISE_ORIGINAL_CWD` for this case.

## Result

For your local workflow, use frontmatter declarations and one central global
install task. Keep installation separate from normal sync. This gives the skills
normal tool commands and removes most per-skill mise work.
