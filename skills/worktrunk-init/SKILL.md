---
name: worktrunk-init
description: Initialize worktrunk (https://worktrunk.dev) in a repository — project hooks in .config/wt.toml plus a tmux bridge that opens one session per worktree. Use when the user asks to set up worktrunk or `wt`, wants a tmux session spawned per worktree or per branch, wants each git worktree to get its own env files, ports, services, or database, or wants parallel-agent worktrees that clean themselves up.
---

# worktrunk-init

Set up [worktrunk](https://worktrunk.dev) — `wt`, a git worktree manager built for running agents in parallel — so that a worktree is **disposable**: one command creates it with everything it needs to run, one command removes it with nothing left behind.

Two halves, both worth building:

- **Lifecycle hooks** in `.config/wt.toml` — env files, dependencies, ports, services, teardown.
- **A tmux bridge** — `wt switch --create` opens a detached tmux session named after the branch, `wt remove` kills it.

The failure this skill exists to prevent is a **leak**: a dev server, container, database, or tmux session that outlives the worktree it belonged to. Every setup step you write earns a matching teardown.

## Workflow

### 1. Preflight

- `wt --version` — if missing, install with `mise use -g worktrunk` (or point the user at https://worktrunk.dev). Note the version; hook behavior tracks it.
- `git rev-parse --git-common-dir` — confirm a git repo, and note whether this is already a worktree.
- `wt config show` — read the resolved config and the **project identifier** (`<host>/<owner>/<repo>`); you need it if you later touch user config.
- `tmux -V` — the bridge needs tmux ≥ 2.1 for exact-match targets.
- If `.config/wt.toml` already exists, read it and extend it. Existing hooks are the user's working setup; add alongside them and say what you added.

Shell integration (`wt config shell install`) is what lets `wt switch` change directory. It edits the user's shell rc, so ask before running it — and if the user declines, note that `wt switch` will print the path instead of cd-ing.

Done when you can state the wt version, the project identifier, and whether config already exists.

### 2. Inventory the repo

This is the legwork the skill lives on: hooks that fit _this_ repo beat a generic template. Read the repo and build a table of what a fresh worktree needs before anyone can work in it.

| Evidence in repo                                                                           | What a new worktree needs                                  | Stage                        |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | ---------------------------- |
| `package.json` + lockfile (`pnpm-lock.yaml`, `bun.lock`, `package-lock.json`, `yarn.lock`) | install with the matching package manager                  | `pre-start`                  |
| `uv.lock` / `poetry.lock` / `requirements*.txt`                                            | `uv sync` / `poetry install` / venv create                 | `pre-start`                  |
| `Cargo.toml`, `go.mod`, `Gemfile`, `mix.exs`, `composer.json`                              | fetch/build deps                                           | `pre-start`                  |
| `.env.example`, `.env.template`, `env.sample`                                              | generate `.env`/`.env.local` from it                       | `pre-start`                  |
| `.env`, `.env.local` present but gitignored                                                | copy from the primary worktree — never re-template secrets | `pre-start`                  |
| `.envrc` (direnv) / `mise.toml`                                                            | `direnv allow` / `mise trust` in the new worktree          | `pre-start`                  |
| Heavy gitignored artifacts (`node_modules/`, `.venv/`, `target/`, `.next/`, `vendor/`)     | `wt step copy-ignored` to skip the cold start              | `post-start`                 |
| Migrations dir, `docker-compose.yml` with a db, `schema.prisma`                            | an isolated database or schema per branch                  | `post-start` + teardown      |
| `docker-compose.yml` / `compose.yaml`                                                      | `COMPOSE_PROJECT_NAME` per branch so stacks don't collide  | `post-start` + teardown      |
| A dev server script binding a fixed port                                                   | a per-branch port, run under `wt step tether`              | `post-start`                 |
| `Procfile`, `Justfile`/`Makefile` dev targets, `devenv.nix`                                | the project's own start command, tethered                  | `post-start`                 |
| Test / lint / typecheck commands                                                           | verification gates                                         | `pre-commit`, `pre-merge`    |
| Generated artifacts, caches, sockets outside the worktree                                  | explicit removal                                           | `pre-remove` / `post-remove` |

Two things to resolve explicitly, because they are where collisions bite:

- **Every port that a service binds.** Give each one `{{ branch | hash_port }}` (stable per branch, range 10000–19999), or record that it stays shared and why.
- **Every named external resource** — container, volume, database, socket path. Name it with `{{ branch | sanitize_db }}` (or `| sanitize`) so two worktrees never fight over one, and note what deletes it.

Read `references/recipes.md` for ready hook bodies per stack (node, python, rust, go, compose, per-branch database, direnv/mise, monorepo) once you know which rows apply.

Show the user the filled table and let them cut rows before you write anything. Done when every row has both a setup command and — where it creates state outside the worktree — a teardown command.

### 3. Write `.config/wt.toml`

Create it with `wt config create --project` (writes a commented starter) or write it directly. It is committed, so teammates inherit the lifecycle.

Stage placement drives everything, so pick deliberately:

| Stage         | Behavior                                                | Belongs here                                                                                               |
| ------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `pre-start`   | blocks worktree creation; delays `--execute` until done | env files, dependency install, the tmux session — anything the agent or dev needs on their first keystroke |
| `post-start`  | background, output to a log file                        | dev servers, `copy-ignored`, long builds, containers                                                       |
| `pre-commit`  | during `wt merge`, before the commit                    | format, lint, typecheck                                                                                    |
| `pre-merge`   | after rebase, before merge                              | tests, build verification                                                                                  |
| `pre-remove`  | in the worktree being removed                           | teardown that needs the files present                                                                      |
| `post-remove` | in the primary worktree, worktree already gone          | teardown that needs the directory gone                                                                     |

Three forms: a string is one command, a table runs its commands **concurrently**, `[[stage]]` blocks run in sequence. Concurrency is the sharp edge — two commands in one table that write the same file race, so a chain like copy-an-env-file → append-a-port needs its own `[[stage]]` block per step.

```toml
# .config/wt.toml
[[post-start]]
copy = "wt step copy-ignored"

[[post-start]]
dev = "wt step tether -- npm run dev -- --port {{ branch | hash_port }}"

[pre-start]
deps = "npm ci"
env = "cp {{ primary_worktree_path }}/.env.local {{ worktree_path }}/.env.local"

[pre-merge]
test = "npm test"

[list]
url = "http://localhost:{{ branch | hash_port }}"
```

Templating rules that decide whether a hook works on the first try:

- Variables are shell-escaped already — write `{{ worktree_path }}`, not `"{{ worktree_path }}"`.
- An undefined variable is an error. Guard optional ones: `{% if upstream %}git fetch{% endif %}`, or `{{ vars.port | default('3000') }}`.
- `{{ branch }}`, `{{ worktree_path }}`, `{{ repo }}`, `{{ primary_worktree_path }}`, `{{ default_branch }}`, `{{ base }}`, `{{ target }}` cover most hooks; `wt hook <stage> -v --dry-run` prints the resolved set for a real invocation.
- Hooks run with cwd at the worktree root, so relative paths like `.config/wt-tmux.sh` resolve.
- Keep secrets out of this file — it is committed. Copy them in from the primary worktree instead.

`wt step tether -- <cmd>` runs a long-lived process in its own process group and kills the whole group when the worktree disappears. Prefer it over a bare `npm run dev` plus a `post-remove` kill: it also covers the paths worktrunk never sees, like a manual `git worktree remove` or a crash.

Done when `wt hook pre-start --dry-run` and the same for each stage you wrote render every command with no template errors.

### 4. Install the tmux bridge

Copy `scripts/wt-tmux.sh` from this skill into the repo at `.config/wt-tmux.sh` and commit it — untracked files don't reach new worktrees, and the hooks call it by relative path.

```toml
[pre-start]
tmux = "bash .config/wt-tmux.sh start {{ branch }} {{ worktree_path }} {{ repo }}"

[pre-remove]
tmux = "bash .config/wt-tmux.sh stop {{ branch }} {{ repo }}"
```

How it behaves, so you can explain it rather than re-derive it:

- Sessions are named `wt/<repo>/<branch>` with `.`, `:`, `/`, and spaces flattened — `feat/login` in repo `acme` becomes `wt/acme/feat-login`. `bash .config/wt-tmux.sh name <branch> <repo>` prints the name.
- One detached session, one window, cwd = the worktree. Detached means creating a worktree never steals the terminal, so it composes with `wt switch --create -x claude`.
- `start` is idempotent, and exits 0 when tmux is absent. A failing `pre-start` aborts worktree creation, and losing the worktree over a missing multiplexer is the worse trade.
- `stop` refuses to kill the session out from under its own caller: if you run `wt remove` from inside the target session it switches your client away first, and if that session is the only one it leaves it alone and says so.
- The session gets `WT_BRANCH` and `WT_WORKTREE_PATH` in its environment.

Attaching is a separate act from creating, since a hook that grabbed the terminal would break background creation. Offer the user a shell alias:

```sh
alias wta='wt switch --no-cd -x "bash {{ worktree_path }}/.config/wt-tmux.sh attach {{ branch }} {{ worktree_path }} {{ repo }}"'
```

`-x` replaces the `wt` process with the command and hands it the terminal, so this picks a worktree (interactive picker when no branch is given) and drops the user into its session. `--no-cd` keeps worktrunk from also moving the outer shell.

Done when the hooks are in `.config/wt.toml`, the script is committed, and `bash .config/wt-tmux.sh name <branch> <repo>` prints the expected name.

### 5. Prove it on a throwaway branch

Hooks that render are not hooks that work — `--dry-run` renders in a different context than a real create, and will happily expand a template the create then rejects. Run the whole lifecycle once:

```sh
wt switch --create wt-smoke-test          # approve the hooks when prompted
wt list                                   # branch, path, and url column
tmux list-sessions | grep wt-smoke-test
wt remove wt-smoke-test
```

Then check for **leaks**, which is the part that gets skipped:

```sh
tmux list-sessions | grep wt-smoke        # gone
docker ps -a | grep wt-smoke              # gone, if the stack uses containers
lsof -nP -iTCP:<hash_port> -sTCP:LISTEN   # nothing still listening
git worktree list                         # no stale entry
```

Project hooks need approval on first run, and the prompt is the user's decision to make. Run the smoke test where they can answer it; if you are non-interactive, ask them to run `wt config approvals add` or the command themselves rather than reaching for `--yes`. A `post-start` hook runs in the background, so its output lands in a log rather than the terminal — `wt config state logs get` lists the files under `.git/wt/logs`.

Done when the smoke test creates a working worktree, `wt remove` leaves no session, process, container, or worktree entry behind, and any failure you hit is either fixed or reported.

### 6. Report

Tell the user: which rows of the inventory became hooks and at which stage; the per-branch port and resource naming scheme; the tmux session naming scheme and the attach alias; what the smoke test proved; and anything you deliberately left out (a service that must stay shared, a teardown that needs their credentials). Mention that teammates get the whole lifecycle from the committed `.config/wt.toml` plus one approval prompt.

## Optional: per-user settings

Keep the repo's lifecycle in `.config/wt.toml`. A few things are personal rather than shared, and belong in `~/.config/worktrunk/config.toml` — worktree layout (`worktree-path`), LLM commit messages (`[commit.generation]`), and any hook the user wants for this repo only, scoped under `[projects."<host>/<owner>/<repo>"]` from step 1.

That file is the user's own; ask before editing it, and show the exact addition.
