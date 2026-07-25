# Hook recipes by stack

Bodies for `.config/wt.toml`, one section per row of the inventory table. Copy the sections that apply, merge them into a single set of stage tables, and adapt the commands to what the repo actually runs (read its `package.json` scripts, `Justfile`, `Makefile`, or README rather than assuming).

Two rules carry across every recipe:

- Anything that binds a port gets `{{ branch | hash_port }}`.
- Anything named outside the worktree — container, database, volume, socket — gets `{{ branch | sanitize_db }}` and an explicit teardown.

## Contents

- [Node](#node) · [Python](#python) · [Rust](#rust) · [Go](#go) · [Ruby / Rails](#ruby--rails)
- [Docker Compose](#docker-compose) · [Database per branch](#database-per-branch)
- [Env files and secrets](#env-files-and-secrets) · [direnv and mise](#direnv-and-mise)
- [Copying gitignored artifacts](#copying-gitignored-artifacts) · [Long-running processes](#long-running-processes)
- [Monorepos](#monorepos) · [Verification gates](#verification-gates) · [Agent launching](#agent-launching)

## Node

Match the package manager to the lockfile: `pnpm-lock.yaml` → `pnpm install --frozen-lockfile`, `bun.lock` → `bun install --frozen-lockfile`, `yarn.lock` → `yarn install --immutable`, `package-lock.json` → `npm ci`.

```toml
[pre-start]
deps = "pnpm install --frozen-lockfile"

[[post-start]]
copy = "wt step copy-ignored"

[[post-start]]
dev = "wt step tether -- pnpm dev --port {{ branch | hash_port }}"
```

Copying `node_modules` first and installing after is often faster than a cold install, at the cost of a pipeline:

```toml
[[post-start]]
copy = "wt step copy-ignored"

[[post-start]]
deps = "pnpm install --frozen-lockfile"
```

Next.js, Vite, and friends read `PORT` or `--port`; check which before choosing.

## Python

```toml
[pre-start]
deps = "uv sync --frozen"

[[post-start]]
dev = "wt step tether -- uv run uvicorn app.main:app --reload --port {{ branch | hash_port }}"
```

`uv` creates `.venv/` inside the worktree, so each worktree is naturally isolated. With poetry-in-project or a plain venv, the same holds. For a shared cache, `UV_CACHE_DIR` or `PIP_CACHE_DIR` pointing at one location speeds up every worktree.

Django:

```toml
[[post-start]]
migrate = "uv run python manage.py migrate"

[[post-start]]
dev = "wt step tether -- uv run python manage.py runserver {{ branch | hash_port }}"
```

## Rust

`target/` is large and gitignored; sharing it across worktrees is the single biggest win.

```toml
[post-start]
copy = "wt step copy-ignored"
```

A shared `CARGO_TARGET_DIR` avoids the copy entirely, at the cost of cross-worktree rebuild churn — put it in the user's environment or `mise.toml`, not in a hook:

```toml
# mise.toml
[env]
CARGO_TARGET_DIR = "{{ config_root }}/../.cargo-target-shared"
```

```toml
[pre-merge]
test = "cargo test"
```

## Go

```toml
[pre-start]
deps = "go mod download"

[pre-merge]
test = "go test ./..."
```

The module cache is already global (`GOMODCACHE`), so no copying is needed.

## Ruby / Rails

```toml
[pre-start]
deps = "bundle install"

[[post-start]]
db = "bin/rails db:prepare"

[[post-start]]
dev = "wt step tether -- bin/rails server -p {{ branch | hash_port }}"
```

Set `DATABASE_URL` per branch — see [Database per branch](#database-per-branch).

## Docker Compose

`COMPOSE_PROJECT_NAME` is what keeps two worktrees' stacks from colliding: it namespaces containers, networks, and volumes. Pair it with per-branch host ports.

```toml
[post-start]
stack = "COMPOSE_PROJECT_NAME={{ branch | sanitize_db }} APP_PORT={{ branch | hash_port }} docker compose up -d"

[post-remove]
stack = "COMPOSE_PROJECT_NAME={{ branch | sanitize_db }} docker compose down -v"
```

`post-remove` (not `pre-remove`) is the right stage when the teardown does not need the worktree's files — though `docker compose down` does read the compose file, so if the file lives in the worktree use `pre-remove` instead. Have the compose file read `${APP_PORT:-3000}` for its host port mapping.

## Database per branch

Store the derived names as per-branch vars in a `post-start` pipeline, then later hooks and `wt list` columns can read them back with `{{ vars.<key> }}`.

```toml
[[post-start]]
dbname = "wt config state vars set db={{ branch | sanitize_db }}"

[[post-start]]
create = "createdb {{ vars.db }} && psql -d {{ vars.db }} -f db/schema.sql"

[pre-remove]
dropdb = "dropdb --if-exists {{ vars.db }}"
```

A containerized database instead of a local one:

```toml
[[post-start]]
vars = "wt config state vars set db={{ branch | sanitize_db }} && wt config state vars set port={{ branch | hash_port }}"

[[post-start]]
up = "docker run -d --name {{ vars.db }} -p {{ vars.port }}:5432 -e POSTGRES_PASSWORD=dev postgres:17"

[post-remove]
down = "docker rm -f {{ vars.db }}"
```

`sanitize_db` yields lowercase `[a-z0-9_]`, never leading with a digit, capped at 48 characters with a hash suffix — safe for Postgres identifiers and Docker names alike.

## Env files and secrets

`.config/wt.toml` is committed, so it templates _structure_, never secret values.

Generate from an example file, overlay the developer's real local values, then append the values that must differ per branch. Each step writes a file the next one reads, so they go in separate `[[pre-start]]` blocks — inside one block they would run concurrently and clobber each other:

```toml
[[pre-start]]
env = "cp {{ worktree_path }}/.env.example {{ worktree_path }}/.env"

[[pre-start]]
local = "cp {{ primary_worktree_path }}/.env.local {{ worktree_path }}/.env.local"

[[pre-start]]
port = "printf 'PORT=%s\\nDATABASE_URL=postgres://localhost/%s\\n' {{ branch | hash_port }} {{ branch | sanitize_db }} >> {{ worktree_path }}/.env.local"
```

When the source file may be absent, guard it so a fresh clone still creates worktrees:

```toml
[pre-start]
local = "test -f {{ primary_worktree_path }}/.env.local && cp {{ primary_worktree_path }}/.env.local {{ worktree_path }}/ || true"
```

Pulling from a secret manager keeps secrets off disk entirely — `op inject`, `doppler run`, `aws secretsmanager get-secret-value`, `vault kv get`. That needs the developer's own credentials, so it belongs in a hook only if every teammate is authenticated; otherwise document it and let them run it.

`{{ primary_worktree_path }}` is the source worktree to copy from. The docs also describe a `worktree_path_of_branch('main')` function, which v0.69.2 renders under `--dry-run` but rejects during an actual create — confirm it against the installed version before relying on it.

## direnv and mise

Both activate on `cd`, so a committed `.envrc` or `mise.toml` gives every worktree its own environment with no hook at all — except for the trust step, which is per-directory:

```toml
[pre-start]
trust = "mise trust {{ worktree_path }}"
```

```toml
[pre-start]
trust = "direnv allow {{ worktree_path }}"
```

To make the per-branch port available to every shell in the worktree rather than only to hooks, write it into the file direnv/mise already loads:

```toml
[pre-start]
port = "printf 'PORT=%s\\n' {{ branch | hash_port }} >> {{ worktree_path }}/.env.local"
```

`wt step eval '<template>'` renders any template from a shell, which is the escape hatch when a value is needed outside a hook: `PORT=$(wt step eval '{{ branch | hash_port }}')`.

## Copying gitignored artifacts

`wt step copy-ignored` copies gitignored files from the main worktree (`--from` to choose another). VCS metadata and tool-state directories are excluded automatically.

```toml
[post-start]
copy = "wt step copy-ignored"
```

Trim what is expensive and worthless to copy:

```toml
[step.copy-ignored]
exclude = [".cache/", ".turbo/", "*.log", "tmp/"]
```

Or invert the default with a `.worktreeinclude` file listing only what to copy, plus `wt step copy-ignored --require-include`. Check the copy with `--dry-run` before committing the hook.

## Long-running processes

`wt step tether -- <cmd>` ties a process group's lifetime to the worktree and kills it — SIGTERM then SIGKILL — when the worktree disappears, including on a manual `git worktree remove` or an `rm -rf` that no hook would ever see.

```toml
[post-start]
dev = "wt step tether -- npm run dev -- --port {{ branch | hash_port }}"
watch = "wt step tether -- npm run watch"
```

Everything after `--` runs directly without a shell, so a command needing pipes or `&&` goes through `bash -lc`:

```toml
[post-start]
dev = "wt step tether -- bash -lc 'npm run build && npm run dev -- --port {{ branch | hash_port }}'"
```

Surface the resulting URL in `wt list`:

```toml
[list]
url = "http://localhost:{{ branch | hash_port }}"
```

## Monorepos

Install once at the root; start only the packages the branch touches, or all of them on distinct ports:

```toml
[pre-start]
deps = "pnpm install --frozen-lockfile"

[post-start]
web = "wt step tether -- pnpm --filter web dev --port {{ branch | hash_port }}"
api = "wt step tether -- pnpm --filter api dev --port {{ (branch ~ '-api') | hash_port }}"
```

Concatenating a suffix before `hash_port` is how you get several stable, distinct ports from one branch.

## Verification gates

Split by cost: fast checks where they run on every commit, slow ones where they run once per merge.

```toml
[pre-commit]
fmt = "pnpm biome check --write ."
types = "pnpm tsc --noEmit"

[pre-merge]
test = "pnpm test --run"
build = "pnpm build"
```

If the repo already runs these through a hook manager (hk, lefthook, pre-commit), call that instead of duplicating the command list — one source of truth for what "clean" means.

## Agent launching

`-x` replaces the `wt` process with the command after the worktree is ready, giving it the terminal:

```sh
alias wsc='wt switch --create -x claude'
wsc feat/login -- 'Implement the login form from #322'
```

Tokens after `--` are appended to the command, so the agent starts with a prompt. To have the agent work inside its tmux session instead of the current terminal, send it to the session created by the bridge:

```toml
[post-start]
agent = "tmux send-keys -t \"$(bash .config/wt-tmux.sh name {{ branch }} {{ repo }}):\" claude Enter"
```

Asking the bridge script for the name keeps this in step with its flattening rules instead of duplicating them. The trailing `:` makes it a window target; unlike session targets, pane targets reject the `=` exact-match prefix.

`wt config plugins claude install` adds worktrunk's own Claude Code plugin, which marks branches in `wt list` as working (🤖) or waiting (💬).
