---
name: rust-best-practices
description: Rust project best practices - strict Clippy lints that deny panics, shared Cargo build caching with mr boxington (mbx), Cocogitto releases in GitHub Actions, and smaller release binaries. Use when setting up or auditing a Rust project, configuring Clippy or `[lints]` in Cargo.toml, writing clippy.toml, removing unwrap/expect/panic/indexing/`as` casts, speeding up Cargo builds across worktrees or CI, setting up versioning, changelogs, tags, or a release workflow (cog, cog.toml, cocogitto-action), or reducing Rust binary size (release profile tuning, strip/LTO/codegen settings, panic strategy, build-std, no_std, UPX, cargo-bloat, container image size).
---

# Rust Best Practices

Pick the sections that match the request. Inspect the project before editing: `Cargo.toml`, workspace layout, `.cargo/config.toml`, `rust-toolchain*`, `clippy.toml`, and existing lint and profile settings.

## Strict Clippy lints

Deny panicking code paths in production code and allow them in tests.

1. Add the `[lints.clippy]` table to `Cargo.toml` (or `[workspace.lints.clippy]` in a workspace root, with `[lints] workspace = true` in each member).
2. Add `clippy.toml` with the `allow-*-in-tests` settings.
3. Run `cargo clippy --all-targets --all-features` and fix findings. Do not silence them with a blanket `#[allow]`.

Read [references/clippy.md](references/clippy.md) for the exact config, the reason for each lint, and how to apply it to an existing codebase.

## Shared build cache

Use mr boxington (`mbx`) when builds repeat across projects, git worktrees, or CI. It wraps `rustc`, needs no daemon, and works with standard Cargo commands. Install it with mise, confirm with `mbx doctor`, and check reuse with `mbx explain --last`.

Read [references/build-cache.md](references/build-cache.md) for install, verification, storage, and the GitHub Actions setup.

## Releases

Use Cocogitto (`cog`) as the release manager in GitHub Actions. It checks Conventional Commits, calculates the next SemVer version, writes `CHANGELOG.md`, and makes the version commit and tag. Configure it in `cog.toml` and run it with `cocogitto/cocogitto-action@v4` (`command: check` on pull requests, `command: bump` with `args: --auto` for releases).

Read [references/release.md](references/release.md) for `cog.toml`, the Cargo version hooks, and the workflow files.

## Binary size

1. Establish the target: native executable, Wasm module, embedded binary, or container image. Ask for size constraints only if they affect tradeoffs such as panic behavior, portability, or nightly-only features.
2. Create a baseline with `cargo build --release` and measure the produced artifact. Use the platform's normal file-size tool, and keep the number so changes can be compared.
3. Apply stable, low-risk release profile changes first:

```toml
[profile.release]
strip = true
opt-level = "z"
lto = true
codegen-units = 1
```

4. Test both `opt-level = "z"` and `opt-level = "s"` when size matters; either can win depending on the project.
5. Treat `panic = "abort"` as a behavior change. Use it when the user accepts immediate process aborts instead of stack unwinding and backtraces:

```toml
[profile.release]
panic = "abort"
```

6. Rebuild, remeasure, and run the project's existing tests or smoke checks. Report the before/after sizes and any behavior tradeoffs.
7. If size is still too large, diagnose instead of guessing. Prefer tools such as `cargo bloat`, `cargo llvm-lines`, feature pruning, dependency review, and target-specific inspection.
8. Use nightly, `build-std`, `panic=immediate-abort`, `#![no_main]`, `#![no_std]`, or UPX only when the user needs aggressive reduction and accepts the added portability, maintenance, or runtime tradeoffs.

### Editing guidance

- Put `[profile.release]` in the workspace root when the repository is a Cargo workspace; package-level profile sections are ignored for workspace members.
- Preserve existing profile keys unless they conflict with size optimization. Explain any change that can slow the program or alter panic behavior.
- Avoid recommending `prefer-dynamic` as a general solution. Rust has no stable ABI, deployment requires exact shared library matches, and static linking is usually the reliable default.
- Do not force nightly-only flags into stable projects unless the user explicitly accepts nightly toolchains.
- For libraries, avoid adding release profile settings unless the repository also builds binaries; consumers control final release profiles.
- For containers, shrink the compiled binary first, then choose a small runtime image such as distroless, scratch-compatible static builds, or Alpine/musl when appropriate.

Read [references/techniques.md](references/techniques.md) when selecting advanced size tactics, writing exact commands, or explaining tradeoffs.
