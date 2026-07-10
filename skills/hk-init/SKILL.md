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

hk ships 140+ builtins (`Builtins.pkl`). Inspect the repo — file extensions, manifests, config files — and select only the builtins that match. Reference table of the most useful mappings:

| Evidence in repo                   | Builtin(s)                                                                                        | mise tool                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------- |
| _(always)_                         | `check_conventional_commit`                                                                       | — (uses `hk util`, no extra tool) |
| _(always)_                         | `check_merge_conflict`, `trailing_whitespace`, `newlines`, `check_added_large_files`              | — (built into hk)                 |
| Any code, secrets risk             | `gitleaks`, `detect_private_key`                                                                  | `gitleaks`                        |
| `*.py`, `pyproject.toml`           | `ruff`, `ruff_format` (prefer over black/flake8/isort)                                            | `ruff`                            |
| `pyproject.toml` with mypy config  | `mypy`                                                                                            | `mypy`                            |
| `*.ts`/`*.js`, `package.json`      | `prettier` (or `biome` if `biome.json` exists), `eslint` if `.eslintrc*`/`eslint.config.*` exists | `npm:prettier`, `npm:eslint`      |
| `tsconfig.json`                    | `tsc`                                                                                             | (project-local, via package.json) |
| `Cargo.toml`                       | `cargo_fmt`, `cargo_clippy`                                                                       | — (uses rustup toolchain)         |
| `go.mod`                           | `go_fmt`, `go_vet` (or `golangci_lint` if `.golangci.yml` exists)                                 | `golangci-lint` if used           |
| `*.sh`, shebang scripts            | `shellcheck`, `shfmt`                                                                             | `shellcheck`, `shfmt`             |
| `Dockerfile*`                      | `hadolint`                                                                                        | `hadolint`                        |
| `.github/workflows/`               | `actionlint`                                                                                      | `actionlint`                      |
| `*.tf`                             | `terraform` or `tofu`, `tf_lint`                                                                  | `terraform`/`opentofu`, `tflint`  |
| `*.yaml`/`*.yml` (beyond a couple) | `yamllint`                                                                                        | `yamllint`                        |
| `*.toml`                           | `taplo`                                                                                           | `taplo`                           |
| `*.md` (docs-heavy repo)           | `markdown_lint`                                                                                   | `npm:markdownlint-cli2`           |
| `*.lua`                            | `stylua`, `luacheck`                                                                              | `stylua`, `luacheck`              |

Rules:

- **Always include `check_conventional_commit`** in the `commit-msg` hook. It needs no extra tool (`hk util check-conventional-commit`).
- Respect existing config: if the repo already has `.prettierrc`, `ruff.toml`, `.golangci.yml`, etc., include the matching builtin; don't add a competing tool.
- Don't add linters for languages that appear only incidentally (a single script, vendored code).
- Builtin names in Pkl use snake_case (`Builtins.ruff_format`); the full list is in hk's repo under `pkl/builtins/`.

### 4. Write hk.pkl

Run `hk init --mise` to scaffold, or write `hk.pkl` directly. Pin the version in the package URLs to the installed hk version (`hk --version`). Template:

```pkl
amends "package://github.com/jdx/hk/releases/download/vX.Y.Z/hk@X.Y.Z#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/vX.Y.Z/hk@X.Y.Z#/Builtins.pkl"

local linters = new Mapping<String, Step> {
    // selected builtins, e.g.:
    ["ruff"] = Builtins.ruff
    ["ruff-format"] = Builtins.ruff_format
    ["prettier"] = Builtins.prettier
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

For every selected builtin that needs an external tool (third column of the table), add it to `[tools]` in `mise.toml`, then run `mise install`. Skip tools already provided by the project (e.g. eslint/prettier in `package.json` devDependencies — hk will find them via the project's node_modules when run through mise).

Verify each tool resolves: `mise x -- <tool> --version`.

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
