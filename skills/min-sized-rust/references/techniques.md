# Rust Binary Size Techniques

This reference distills the `johnthagen/min-sized-rust` README into an agent workflow.
Source: https://github.com/johnthagen/min-sized-rust

Prefer stable Cargo profile settings first, then escalate only when the target size justifies more fragility.

## Stable Cargo Profile

| Technique | Minimum Rust | Config or command | Main tradeoff |
| --- | --- | --- | --- |
| Release build | 1.0 | `cargo build --release` | Optimized build takes longer than debug. |
| Strip symbols | 1.59 for Cargo profile | `strip = true` under `[profile.release]` | Removes symbol/debug information from final binary. |
| Optimize for size | 1.28 | `opt-level = "z"` or test `"s"` | Can reduce runtime speed; either value may be smaller. |
| Link-time optimization | 1.0 | `lto = true` | Slower compile, often smaller output. |
| One codegen unit | stable | `codegen-units = 1` | Slower compile, enables broader optimization. |
| Abort panics | 1.10 | `panic = "abort"` | Removes unwinding, changes panic behavior. |

Recommended starting profile:

```toml
[profile.release]
strip = true
opt-level = "z"
lto = true
codegen-units = 1
```

Optional behavior-changing addition:

```toml
[profile.release]
panic = "abort"
```

For Rust before 1.59, strip manually after building on Unix-like platforms:

```bash
strip target/release/<binary-name>
```

## Diagnostics

Use these before making invasive changes:

```bash
cargo install cargo-bloat
cargo bloat --release --crates
cargo bloat --release --functions
```

Useful tools:

- `cargo-bloat`: identify large crates and functions in native executables.
- `cargo-llvm-lines`: find monomorphization and generic-code growth.
- `cargo-unused-features`: detect enabled features that may be pruned.
- `twiggy`: inspect Wasm code size.
- Container tools such as `dive` can identify oversized image layers.

## Nightly And Aggressive Options

Use these only after stable options have been measured.

### Remove Panic Location Details

Nightly-only:

```bash
RUSTFLAGS="-Zlocation-detail=none" cargo +nightly build --release
```

This removes file, line, and column metadata used by panic and caller-location reporting.

### Disable Debug Formatting

Nightly-only:

```bash
RUSTFLAGS="-Zfmt-debug=none" cargo +nightly build --release
```

This turns generated `Debug` formatting into no-ops. It can break useful output from `dbg!`, asserts, unwrap panic messages, and code that relies on debug formatting.

### Rebuild The Standard Library For Size

Install nightly and `rust-src`:

```bash
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly
```

Find the target triple:

```bash
rustc -vV
```

Build `std` with size-focused options:

```bash
RUSTFLAGS="-Zlocation-detail=none -Zfmt-debug=none" cargo +nightly build \
  -Z build-std=std,panic_abort \
  -Z build-std-features="optimize_for_size" \
  --target <target-triple> --release
```

Use `std,panic_abort` when the Cargo profile has `panic = "abort"` and the target should rebuild panic support accordingly.

### Remove Panic Formatting

Nightly-only, very aggressive:

```bash
RUSTFLAGS="-Zunstable-options -Cpanic=immediate-abort" cargo +nightly build \
  -Z build-std=std,panic_abort \
  -Z build-std-features= \
  --target <target-triple> --release
```

This disables more panic formatting and backtrace-related standard library features. Verify behavior carefully.

## Extreme Code Changes

### Avoid `core::fmt`

For binaries under roughly tens of kilobytes, normal formatting often dominates size. Consider `#![no_main]`, a C entry point, direct stdio calls, and strict avoidance of formatting paths. This is low-level, platform-sensitive, and likely to require `unsafe`.

### Remove `libstd`

Use `#![no_std]` and usually `#![no_main]` when C-like binary size matters more than ergonomics and crate compatibility. Expect manual panic handlers, `unsafe` FFI, and limited dependency support.

Minimal shape:

```rust
#![no_std]
#![no_main]

extern crate libc;

#[no_mangle]
pub extern "C" fn main(_argc: isize, _argv: *const *const u8) -> isize {
    const HELLO: &str = "Hello, world!\n\0";
    unsafe {
        libc::printf(HELLO.as_ptr() as *const _);
    }
    0
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

## Compression And Containers

UPX can reduce distribution size:

```bash
upx --best --lzma target/release/<binary-name>
```

Caveats: startup cost can change, some environments dislike packed binaries, and heuristic antivirus tools may flag UPX-packed executables.

For containers:

- Build a small release binary first.
- Prefer static linking when the runtime image needs no libc or dynamic dependencies.
- Use minimal runtime images such as distroless or scratch-compatible setups when operationally appropriate.
- Inspect final images with tools such as `dive`.

## Legacy Note

Rust 1.32 removed jemalloc as the default allocator. Only Rust 1.28 through 1.31 may need an explicit `std::alloc::System` global allocator to avoid jemalloc size overhead.
