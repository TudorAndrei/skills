# Caching Rust Compilation in GitHub Actions

Sources:

- https://github.com/Swatinem/rust-cache
- https://github.com/Mozilla-Actions/sccache-action
- https://github.com/mozilla/sccache/blob/main/docs/Rust.md
- https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching

Pick one compile-cache layer per job. Do not combine `Swatinem/rust-cache` with `sccache` on the GitHub Actions cache backend: both write to the same 10 GB repository budget and store the same dependency outputs twice.

| Tool                             | Stores                                        | Use when                                                                                        |
| -------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| mr boxington (`mbx`)             | Per-rustc-call outputs, path-portable         | Default for this skill. See [build-cache.md](build-cache.md).                                   |
| `Swatinem/rust-cache@v2`         | `~/.cargo` and `target/` dependency artifacts | Simple drop-in, no wrapper, one job or a few jobs with a shared key.                            |
| `mozilla-actions/sccache-action` | One cache entry per compiled object           | Mixed Rust and C/C++ builds, or a remote backend (S3, GCS, Redis) shared with other CI systems. |

## GitHub cache rules that affect every option

- Each repository has a 10 GB cache budget. GitHub removes entries not used for 7 days, and removes the least recently used entries when the budget is exceeded.
- A run can restore caches from its own branch, the default branch, and (for pull requests) the base branch. It cannot restore caches from sibling or child branches.
- Save the cache only from the default branch. Pull-request caches are scoped to the PR ref, so other branches cannot use them, and they push useful main-branch entries out of the budget.
- Install the toolchain before the cache step. The cache key includes the `rustc` version.

## Swatinem/rust-cache

```yaml
permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
        with:
          save-if: ${{ github.ref == 'refs/heads/main' }}
      - run: cargo test --workspace --locked
```

What it does:

- Caches `~/.cargo` (bin, registry index and archives, git deps) and `target/`. It does not cache `~/.cargo/registry/src`, because Cargo unpacks it faster than the cache restores it.
- Sets `CARGO_INCREMENTAL=0`. Incremental artifacts are large and CI builds from a clean state.
- Before save, removes workspace crates, incremental data, unused dependencies, and files older than one week. By default only dependencies stay in the cache.
- Builds the key from the job ID, `rustc` version and host, hashes of `Cargo.lock`, `Cargo.toml`, `rust-toolchain*`, `.cargo/config.toml`, and the values of env vars that start with `CARGO`, `CC`, `CFLAGS`, `CXX`, `CMAKE`, or `RUST`.

Useful inputs:

| Input              | Default       | Use                                                                                               |
| ------------------ | ------------- | ------------------------------------------------------------------------------------------------- |
| `save-if`          | `true`        | Set to a main-branch expression so PRs only restore.                                              |
| `shared-key`       | empty         | Share one cache across jobs that build the same thing (replaces the job ID in the key).           |
| `key`              | empty         | Add a discriminator, for example the target triple in a matrix.                                   |
| `workspaces`       | `. -> target` | Set for nested workspaces or a custom target dir, for example `crates/app -> target`.             |
| `cache-on-failure` | `false`       | Keep a cache when tests fail after a long compile.                                                |
| `cache-all-crates` | `false`       | Keep crates that the current build did not use, for example tools installed with `cargo install`. |
| `cache-bin`        | `true`        | Set to `false` if another step installs tools into `~/.cargo/bin`.                                |
| `prefix-key`       | `v0-rust`     | Change to force a full cache reset.                                                               |

Matrix jobs: keep the default job-ID key, or set `key: ${{ matrix.target }}`. Jobs that build different targets or features with one `shared-key` overwrite each other's entries.

## sccache

```yaml
permissions:
  contents: read

env:
  SCCACHE_GHA_ENABLED: "true"
  RUSTC_WRAPPER: "sccache"
  CARGO_INCREMENTAL: "0"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dtolnay/rust-toolchain@stable
      - uses: mozilla-actions/sccache-action@v0.0.11
      - run: cargo test --workspace --locked
```

Limits (from the sccache Rust docs):

- Incremental compilation must be off. Set `CARGO_INCREMENTAL=0` or `incremental = false` in the profile.
- Crates that call the system linker are not cached: `bin`, `dylib`, `cdylib`, and `proc-macro`. The final binary always links again.
- Proc macros that read files from disk may produce stale hits.
- Needs sccache v0.11.0 or later; the action installs a current version unless `version` is set.
- The action adds a post step that prints hit and miss stats. Check them; a low hit rate usually means absolute paths or env vars differ between runs.

For a shared remote cache, drop `SCCACHE_GHA_ENABLED` and set the backend variables instead (for example `SCCACHE_BUCKET` and `SCCACHE_REGION` with credentials from OIDC).

## Other ways to cut CI build time

These are not caches, but they often matter more than the cache:

- Add `[profile.dev] debug = "line-tables-only"` or `debug = 0` for CI builds. Debug info is a large part of `target/` size and cache restore time.
- Use `cargo nextest` or split `cargo clippy` and `cargo test` into jobs with separate caches, because Clippy (check metadata) and test builds (full codegen) share few artifacts.
- Use `--locked` so the `Cargo.lock` hash in the key matches what builds.
- Install prebuilt tools with `taiki-e/install-action` instead of `cargo install` in every run.
