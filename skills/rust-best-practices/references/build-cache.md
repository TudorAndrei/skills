# Shared Build Cache: mr boxington (mbx)

Source: https://mr-boxington.jdx.dev/

mbx is a shared cache for Cargo builds. It wraps `rustc` calls (no daemon), keys compiler outputs by their inputs, and replaces checkout-specific paths with portable placeholders. Because of this, one cache serves many projects, git worktrees, and CI runs. Standard Cargo commands continue to work.

Use it when the user builds the same dependencies in many worktrees or checkouts, or when CI rebuilds from zero on each run.

## Install

With mise (needs mise 2026.9.2 or later; omit `--global` for a project-scoped setup):

```sh
mise use --global --tool-option mr_boxington=true rust mr-boxington
```

Without mise:

```sh
cargo install mbx --locked
mbx setup          # connects mbx to Cargo
mbx setup --status # shows the current setup
```

No config file is necessary. See https://mr-boxington.jdx.dev/guide for the configuration reference.

## Verify

From the workspace root:

```sh
mbx doctor
mbx build
```

The first build fills the cache. To show reuse, build into two fresh target directories with the same command and options, then run:

```sh
mbx explain --last
mbx cache stats
```

## Storage

mbx removes target directories whose checkout no longer exists, or that were not used for 30 days. When the disk budget is exceeded, it removes the least recently used entries.

## GitHub Actions

```yaml
permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: jdx/mr-boxington-action@v1
      - run: mbx test --workspace
```

- Pushes to the main branch fill the cache. Pull requests only restore it. mbx never publishes cache entries from pull requests, for all backends.
- If the project pins a toolchain, install it before the action and pass it through the action's `toolchain` input.
- For parallel steps (for example `mbx clippy` and `mbx test`), give each step its own `CARGO_TARGET_DIR`.
- For a remote cache, set `backend: remote` with `remote-url` and `namespace`, or an S3-compatible bucket URL with credentials from `aws-actions/configure-aws-credentials` (OIDC).

Details: https://mr-boxington.jdx.dev/github-action
