---
name: min-sized-rust
description: Optimize Rust projects for smaller release binaries. Use when Codex is asked to reduce, audit, explain, or configure Rust binary size, including Cargo release profile tuning, strip/LTO/codegen settings, panic strategy tradeoffs, nightly build-std or no_std tactics, UPX compression, cargo-bloat investigation, and container image size for Rust binaries.
---

# Min-Sized Rust

## Workflow

1. Establish the target: native executable, Wasm module, embedded binary, or container image. Ask for size constraints only if they affect tradeoffs such as panic behavior, portability, or nightly-only features.
2. Inspect the project before editing: `Cargo.toml`, workspace profile ownership, `.cargo/config.toml`, `rust-toolchain*`, target triple, enabled features, and existing release settings.
3. Create a baseline with `cargo build --release` and measure the produced artifact. Use the platform's normal file-size tool, and keep the number so changes can be compared.
4. Apply stable, low-risk release profile changes first:

```toml
[profile.release]
strip = true
opt-level = "z"
lto = true
codegen-units = 1
```

5. Test both `opt-level = "z"` and `opt-level = "s"` when size matters; either can win depending on the project.
6. Treat `panic = "abort"` as a behavior change. Use it when the user accepts immediate process aborts instead of stack unwinding and backtraces:

```toml
[profile.release]
panic = "abort"
```

7. Rebuild, remeasure, and run the project's existing tests or smoke checks. Report the before/after sizes and any behavior tradeoffs.
8. If size is still too large, diagnose instead of guessing. Prefer tools such as `cargo bloat`, `cargo llvm-lines`, feature pruning, dependency review, and target-specific inspection.
9. Use nightly, `build-std`, `panic=immediate-abort`, `#![no_main]`, `#![no_std]`, or UPX only when the user needs aggressive reduction and accepts the added portability, maintenance, or runtime tradeoffs.

## Editing Guidance

- Put `[profile.release]` in the workspace root when the repository is a Cargo workspace; package-level profile sections are ignored for workspace members.
- Preserve existing profile keys unless they conflict with size optimization. Explain any change that can slow the program or alter panic behavior.
- Avoid recommending `prefer-dynamic` as a general solution. Rust has no stable ABI, deployment requires exact shared library matches, and static linking is usually the reliable default.
- Do not force nightly-only flags into stable projects unless the user explicitly accepts nightly toolchains.
- For libraries, avoid adding release profile settings unless the repository also builds binaries; consumers control final release profiles.
- For containers, shrink the compiled binary first, then choose a small runtime image such as distroless, scratch-compatible static builds, or Alpine/musl when appropriate.

## Reference

Read [references/techniques.md](references/techniques.md) when selecting advanced tactics, writing exact commands, or explaining tradeoffs.
