---
name: rust-best-practices
description: Rust project best practices - strict lints, verification, misuse-resistant APIs, benchmarks, dependency vetting, build caching, releases, and binary size. Use when setting up or auditing a Rust project, configuring Clippy, `[lints]`, or clippy.toml, removing unwrap/expect/panic/indexing/`as` casts, hardening or reviewing high-stakes Rust, verifying `unsafe`, concurrent, or rewritten code (Miri, sanitizers, Loom, Kani, proptest, fuzzing, cargo-mutants, TLA+), designing a public API or keeping semver, benchmarking or optimizing working Rust, vetting dependencies (cargo deny, cargo-vet, cargo auditable), speeding up Cargo builds across worktrees or CI (mbx, Swatinem/rust-cache, sccache), setting up versioning, changelogs, or releases (cog, cog.toml, cocogitto-action), or reducing binary size (release profile, LTO, panic strategy, build-std, no_std, UPX, cargo-bloat, container images).
---

# Rust Best Practices

Pick the sections that match the request. Inspect the project before editing: `Cargo.toml`, workspace layout, `.cargo/config.toml`, `rust-toolchain*`, `clippy.toml`, and existing lint and profile settings.

## Strict Clippy lints

Deny panicking code paths in production code and allow them in tests.

1. Add the `[lints.clippy]` and `[lints.rust]` tables to `Cargo.toml` (or `[workspace.lints.*]` in a workspace root, with `[lints] workspace = true` in each member).
2. Add `clippy.toml` with the `allow-*-in-tests` settings.
3. Run `cargo clippy --all-targets --all-features` and fix findings. Do not silence them with a blanket `#[allow]`.

Read [references/clippy.md](references/clippy.md) for the exact config, the reason for each lint, and how to apply it to an existing codebase.

## Verification

For high-stakes or long-lived crates, "it compiles and the tests pass" is the start of the job. Give each real failure class one **owner** (fuzzing for untrusted input, Miri for `unsafe`, Loom for lock-free code, differential tests against the retained old code for a rewrite), and name the **oracle** that would catch the code being wrong. Read the workspace and map the verifiers already in CI before you recommend a tool. A verification review is a read-only audit first.

End the work with the Evidence, Documented, Deferred, Compat/deps, and Verification report. Name each claim with its narrowest term and bounds; a bounded check, fuzz run, or test suite is never a proof.

Read [references/verification.md](references/verification.md) for the testing checklist, sanitizer commands, the risk-to-owner table, formal tools, anti-drift rules, CI shape, and the report format.

## API design

Make misuse inexpressible with newtypes, validated two-phase structs, enums, and typestate, and keep the public surface small. Read [references/api-design.md](references/api-design.md) for the state-machine ladder, everyday API idioms, semver tooling, and what to document.

## Enums over strings

Parse, don't validate: turn a string into a typed value once, where it enters the program, and carry the type from there.

- Model every closed set of values (mode, status, kind, command, unit, format, event name) as an enum. Parse it at the input boundary with `#[derive(Deserialize)]` and `#[serde(rename_all = "...")]`, `clap::ValueEnum`, or `FromStr` / `TryFrom<&str>`.
- Pass the enum through functions, struct fields, and map keys, and `match` on it exhaustively, so adding a variant makes the compiler list every site to update.
- Turn it back into a string only at the output boundary (`Serialize`, `Display`, or `fn as_str(&self) -> &'static str`). Keep the string mapping in one place; `strum` derives (`EnumString`, `Display`, `IntoStaticStr`) generate both directions from the variant names.
- Put data that belongs to one kind on that variant (`enum Shape { Circle { r: f64 }, Rect { w: f64, h: f64 } }`), with `#[serde(tag = "type")]` for tagged JSON, instead of a `kind` string beside loosely related fields.
- Keep a `String` or newtype only for an open set, such as user-defined names. For an external set that can grow, add `#[non_exhaustive]` on a public enum, or an `Other(String)` variant when unknown values must round-trip.

In review, treat these as a string carrying an enum's job: `match s.as_str()` or `== "literal"` past the input boundary, a `&str` or `String` parameter that takes a fixed set of values, `to_string()` on a variant followed by a parse elsewhere, and a `HashMap<String, _>` keyed by a fixed set.

## Performance

A speed claim compares equal work under a frozen **benchmark contract**, and an optimization keeps the old implementation as the oracle. Read [references/performance.md](references/performance.md) to benchmark, to change data layout, or to run the optimization loop until gains converge.

## Dependencies

Ship binaries built with `cargo auditable`, gate on `cargo deny`, vet with `cargo-vet`, scan workflows with `zizmor`, and keep upgrades flowing. Read [references/dependencies.md](references/dependencies.md) for the supply-chain steps and the anti-stagnation practices.

## Shared build cache

Use mr boxington (`mbx`) when builds repeat across projects, git worktrees, or CI. It wraps `rustc`, needs no daemon, and works with standard Cargo commands. Install it with mise, confirm with `mbx doctor`, and check reuse with `mbx explain --last`.

Read [references/build-cache.md](references/build-cache.md) for install, verification, storage, and the GitHub Actions setup.

If the project cannot use mbx in CI, use `Swatinem/rust-cache@v2` or `mozilla-actions/sccache-action`. Use only one cache layer per job, and save the cache only from the default branch. Read [references/ci-cache.md](references/ci-cache.md) to choose between them, for the workflow files, and for GitHub cache limits.

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
