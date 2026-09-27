# Releases with Cocogitto

Source: https://docs.cocogitto.io/ and https://github.com/cocogitto/cocogitto-action

Cocogitto (`cog`) is the recommended release manager for Rust projects on GitHub Actions. It checks that commits follow Conventional Commits, calculates the next SemVer version from the commit history, writes `CHANGELOG.md`, makes the version commit and tag, and runs hooks around the bump.

Version rules for `cog bump --auto`: `fix` gives a patch, `feat` gives a minor, and `BREAKING CHANGE` (or `!` after the type) gives a major.

## cog.toml

Put `cog.toml` in the repository root. Example for a single-crate project (needs `cargo-edit` for `cargo set-version`):

```toml
#:schema https://docs.cocogitto.io/cog-schema.json
tag_prefix = "v"
branch_whitelist = ["main"]
ignore_merge_commits = true

# Changes made by these commands go into the version commit.
pre_bump_hooks = [
    "cargo set-version {{version}}",
    "cargo clippy --all-targets --all-features",
    "cargo test",
]

post_bump_hooks = [
    "git push",
    "git push origin --tags",
]

[commit_types]
chore = { omit_from_changelog = true }
test = { omit_from_changelog = true }

[changelog]
path = "CHANGELOG.md"
template = "remote"
remote = "github.com"
owner = "<owner>"
repository = "<repo>"
```

- Add `"cargo publish"` to `post_bump_hooks` only for crates that go to crates.io, and give the job a `CARGO_REGISTRY_TOKEN` secret.
- For a workspace, use `[monorepo]` with `resolver = "Cargo"`, declare each crate under `[monorepo.packages.<name>]` with its `path`, and set versions with `post_package_bump_hooks = ["cargo set-version --package {{package}} {{version}}"]`.
- Preview with `cog bump --auto --dry-run`. Check history locally with `cog check`.

## GitHub Actions

Use `cocogitto/cocogitto-action@v4`. It runs only on x86 Linux runners. The inputs are `command`, `args`, `git-user`, `git-user-email`, and `install-only`. The outputs are `version` and `stdout`. The v3 inputs (`check: true`, `release: true`) no longer exist; do not copy them from older docs.

Checkout must use `fetch-depth: 0`, or cog cannot read the full history.

### Check commits on pull requests

```yaml
on: [pull_request]

jobs:
  cog-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: ${{ github.event.pull_request.head.sha }} # PR head, not the merge commit
      - uses: cocogitto/cocogitto-action@v4
        with:
          command: check
```

If the history before adoption is not conventional, add `args: --from-latest-tag`.

### Release on demand

```yaml
name: release

on:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: cocogitto/cocogitto-action@v4
        id: release
        with:
          command: bump
          args: --auto
          git-user: "github-actions[bot]"
          git-user-email: "github-actions[bot]@users.noreply.github.com"
      - run: cog changelog --at ${{ steps.release.outputs.version }} > RELEASE_NOTES.md
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.release.outputs.version }}
          body_path: RELEASE_NOTES.md
```

- The job pushes a commit and a tag, so it needs `contents: write`. If branch protection blocks the push, use a deploy key or a GitHub App token in `actions/checkout`.
- Tags pushed with `GITHUB_TOKEN` do not start other workflows. Build release binaries in the same workflow, or push with a different token if a tag-triggered workflow must run.
- The `version` output is the full tag name, including `tag_prefix` (for example `v1.2.0`).
- After the action step, `cog` is on the `PATH` for later steps.
