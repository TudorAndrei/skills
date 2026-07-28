---
name: hk-init
description: Initialize hk (https://hk.jdx.dev) git hooks in a repository with mise integration. Use when the user asks to set up hk, add pre-commit hooks via hk, initialize git hooks with mise, or migrate a repo to hk. Adds hk to mise.toml, analyzes the codebase to pick relevant builtin linters (always including the conventional-commit check), installs the required tools via mise, and runs the checks.
---

# hk-init

Set up [hk](https://hk.jdx.dev/) — a git hook and linter runner configured in Pkl — in the current repository, using [mise](https://mise.jdx.dev/) as the source of truth for tool versions.

## Workflow

Follow these steps in order. Do not skip the codebase analysis — the value of the skill is picking the _right_ builtins, not all of them.

### 1. Preconditions

- Confirm the directory is a git repository (`git rev-parse --git-dir`). If not, ask before running `git init`.
- Confirm `mise` is installed (`mise --version`). If not, stop and tell the user to install it first.
- If an `hk.pkl` already exists, ask the user whether to regenerate or extend it.

### 2. Add hk to mise.toml

Edit (or create) `mise.toml` in the repo root. hk requires `pkl` to evaluate its config, and `HK_MISE=1` wraps the git hooks with `mise x` so hooks run with mise-managed tools on PATH even if the developer hasn't activated mise:

```toml
[tools]
hk = "latest"
pkl = "latest"

[env]
HK_MISE = 1

[hooks]
postinstall = "hk install --mise"
```

Preserve any existing content in `mise.toml` — merge these entries, don't overwrite. Prefer pinning `hk` to the current latest version (check with `mise latest hk`) instead of `"latest"` if the repo pins its other tools.

Then run `mise install` so `hk` and `pkl` are available.

### 3. Analyze the codebase and select builtins

hk ships 140+ builtins (`hk builtins` lists them all; sources live in hk's repo under `pkl/builtins/`). Inspect the repo — file extensions, manifests, config files — and select only the builtins that match.

**Default to the modern subset** — the fast, single-binary, mostly Rust/Go tools that replace the older Node/Python-runtime linters. Use a legacy tool only when the repo already commits to it.

**Read `references/modern-builtins.md` before choosing steps.** It holds the full selection tables — always-on steps, the evidence → builtin mapping, the legacy → modern swap list, per-tool caveats, formatter-overlap rules, and the exact `mise.toml` install lines (including the handful of tools that need a `cargo:`/`npm:` backend).

The short version of the defaults:

| Domain     | Use                          | Not                                 |
| ---------- | ---------------------------- | ----------------------------------- |
| JS/TS      | `ox_lint` + `oxfmt`          | `eslint` + `prettier`               |
| Python     | `ruff` + `ruff_format`, `ty` | `black`, `flake8`, `isort`, `mypy`  |
| Markdown   | `rumdl` + `rumdl_format`     | `markdown_lint`                     |
| YAML       | `ryl`                        | `yamllint`                          |
| TOML       | `tombi` + `tombi_format`     | `taplo`                             |
| Go         | `golangci_lint`, `go_fumpt`  | `go_fmt` + `go_vet` + `staticcheck` |
| Spelling   | `typos`                      | codespell / cspell                  |
| GH Actions | `actionlint` + `zizmor`      | `actionlint` alone                  |

Plus, always: `check_conventional_commit` (commit-msg), `check_merge_conflict`, `trailing_whitespace`, `newlines`, `check_added_large_files`, `gitleaks`, `detect_private_key`.

Two rules that decide most of the hard cases:

- **Existing config wins.** If the repo already has `.eslintrc*`/`eslint.config.*` with custom plugins, `.prettierrc`, `.markdownlint*`, `.yamllint`, `mypy.ini`, `biome.json`, or `.golangci.yml`, use the matching builtin instead of swapping it out underneath the team. Name the modern alternative in your final report and let them decide. (oxlint in particular does not yet cover type-aware `@typescript-eslint` rules.)
- **One formatter per file type.** `oxfmt` also claims markdown, YAML, TOML, JSON, CSS and HTML by default — narrow its `glob` when `rumdl_format`/`tombi_format`/`ryl` are also selected. See the reference for the exact override.

Don't add linters for languages that appear only incidentally (a single script, vendored code). Builtin names in Pkl are snake_case (`Builtins.ruff_format`, `Builtins.ox_lint`).

### 4. Write hk.pkl

Run `hk init --mise` to scaffold, or write `hk.pkl` directly. Pin the version in the package URLs to the installed hk version (`hk --version`). Template:

```pkl
amends "package://github.com/jdx/hk/releases/download/vX.Y.Z/hk@X.Y.Z#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/vX.Y.Z/hk@X.Y.Z#/Builtins.pkl"

local linters = new Mapping<String, Step> {
    // selected builtins, e.g.:
    ["ruff"] = Builtins.ruff
    ["ruff-format"] = Builtins.ruff_format
    ["oxlint"] = Builtins.ox_lint
    ["oxfmt"] = Builtins.oxfmt
    ["rumdl"] = Builtins.rumdl_format
    ["typos"] = Builtins.typos
    ["gitleaks"] = Builtins.gitleaks
    ["check-merge-conflict"] = Builtins.check_merge_conflict
    ["trailing-whitespace"] = Builtins.trailing_whitespace
}

hooks {
    ["pre-commit"] {
        fix = true       // auto-fix staged files where the tool supports it
        stash = "git"
        steps { ...linters }
    }
    ["commit-msg"] {
        steps {
            ["conventional-commit"] = Builtins.check_conventional_commit
        }
    }
    ["check"] {
        steps { ...linters }
    }
    ["fix"] {
        steps { ...linters }
    }
}
```

Customize a builtin by amending it, e.g. `["prettier"] = (Builtins.prettier) { glob = List("*.ts", "*.tsx") }`.

### 5. Add the linter tools to mise.toml

For every selected builtin that needs an external tool, add it to `[tools]` in `mise.toml`, then run `mise install`. The exact install lines — including which tools need a `cargo:`/`npm:` backend because they aren't in the mise registry — are in `references/modern-builtins.md` under "mise install lines".

Skip tools already provided by the project (e.g. eslint/prettier in `package.json` devDependencies — hk will find them via the project's node_modules when run through mise).

Verify each tool resolves before writing it into `hk.pkl`: `mise x -- <tool> --version`. If a tool won't install on the user's platform, drop that step rather than shipping a hook that fails for everyone.

### 6. Install the hooks and run the checks

```sh
hk install --mise   # writes .git/hooks/* wrapped with `mise x`
hk check --all      # run every linter across the whole repo
```

- If `hk check --all` reports fixable issues, run `hk fix --all`, show the user the diff, and re-run `hk check --all`.
- If a specific linter fails due to missing project config or an unfixable pre-existing issue, report it; offer to either fix the findings or narrow/remove that step rather than leaving a hook that blocks every commit.
- Test the commit-msg hook without committing: `echo "bad message" | hk util check-conventional-commit /dev/stdin` should fail, `feat: example` should pass.

### 7. Report

Summarize for the user: which builtins were selected and why, which tools were added to `mise.toml`, and the result of `hk check --all`. Remind them that teammates only need `mise install` (the `postinstall` hook installs the git hooks automatically).
