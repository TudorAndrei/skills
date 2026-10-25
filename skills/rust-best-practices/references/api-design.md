# API Design

Sources: https://github.com/hexuria/impeccable-rust (MIT), https://github.com/morganlinton/BeautifulRust (MIT)

Make incorrect use inexpressible instead of documenting "do not do that". Treat public surface as a liability.

## Misuse resistance

- Newtypes for distinct units, not type aliases: `Meters(u64)` and `Miles(u64)`.
- Two-phase structs: a raw `TomlConfig` parsed from input, then a validated `ResolvedConfig` the rest of the code takes.
- One enum for linked arguments, so a `bool` plus an `Option` that must agree cannot hold conflicting states.
- No `bool` parameters in public or shared function signatures. `report(true)` is unreadable at the call site and cannot grow a third mode. Use a two-variant enum (`Widget::new(Size::Small, Shape::Round)`, not `Widget::new(true, false)`) or two methods (`report()`, `report_verbose()`). A private helper whose call sites are a few lines away is the only exception.
- `NonZeroU32` and similar types inside the crate only; keep plain integers at API boundaries. Use the `bitflags` crate for a set of independent flags; an enum models exactly one choice.

State-machine ladder. Stop at the first rung that rules out the illegal states:

1. Keep `bool` struct fields for independent flags that are not a lifecycle (`verbose`, `color`).
2. Turn lifecycle bools and phase-only `Option`s into an enum, including multi-bool parameter lists. Put each field on the variant that owns it, so ghost data and states such as connected-but-not-open cannot be built.
3. Nest when a flat enum copies the same fields onto many variants. Share context on an orchestrator and delegate to a phase enum: `Session::Auth { ctx, phase }`, `Session::Work { ctx, phase }`.
4. Use typestate when the next call must be impossible until the transition runs (`Rocket<Ground>` vs `Rocket<Air>`), and consume `self` so the old state cannot be reused. Stay on a runtime enum when one `Vec` holds mixed states, or when the phase is outside data.

## Idioms

- Follow the Rust API Guidelines. Redesign OOP-style factories and inheritance trees toward builders, ownership-honest APIs, and shallow trait hierarchies.
- Return `Option<&T>`, not `&Option<T>`; use `as_deref` for a stored `Box<T>` or `String`. Callers can map or return a computed `None` without depending on storage, and `Option<&T>` is pointer-sized.
- Take `&mut Option<T>` only when the callee inserts or clears the value. Take `Option<&mut T>` to edit a present value, and `Option<T>` when the callee needs ownership.
- Return the value callers need (`&str`, `&[T]`, `T`, or `impl AsRef<_>`), not your `Deref` wrapper.
- Take `impl Into<T>` at a public edge where the conversion is the point. On a hot or internal path, take the concrete type so allocation and inference stay obvious.
- Store long-lived immutable shared data as `Arc<[T]>` or `Arc<str>` (`Rc<_>` on one thread, `Box<[T]>` for one owner): build in `Vec` or `String`, then freeze. `Arc<String>` and `Arc<Vec<_>>` carry a spare capacity field and an extra pointer hop.
- Use `Option` when absence is the whole story, and `Result` when the caller must branch on why. Short-circuit a fallible iterator with `collect::<Result<Vec<_>, _>>()`.
- Library code that only iterates takes `impl IntoIterator<Item = T>`; application code can take `&[T]`.
- Leave a value-producing `match` or `if` arm as an expression (`0 => "zero"`); a trailing semicolon turns it into `()`.
- For a `dyn` plugin trait with an async method, return `Pin<Box<dyn Future<Output = T> + Send + 'a>>`. Without `dyn`, use `async fn` in the trait. In a public trait, write `fn run(&self) -> impl Future<Output = T> + Send` so callers can rely on `Send`.
- Deny `unsafe_op_in_unsafe_fn` (see [clippy.md](clippy.md)), so each unsafe operation inside an `unsafe fn` still needs its own `unsafe` block.

## Compatibility

Keep a small, stable core and document semver expectations for callers. Prefer:

- `-> impl Trait` over a named concrete return type you may change. Auto traits such as `Send` still leak through it.
- Private fields with accessors or builders over `pub` fields.
- No public-dependency types (hyper, serde, tokio) in arguments, returns, trait impls, or re-exports, unless that coupling is intended.
- Private inherent methods over blanket `impl From` or other always-public trait impls when the coupling is accidental.
- `#[non_exhaustive]` on public enums and public-field structs that cross crate boundaries, unless the set is a stable ontology. When you match one, list the variants you handle and add a wildcard arm.
- Sealed traits for traits that downstream crates must not implement. Say so in the docs:

  ```rust
  pub trait TheTrait: private::Sealed { /* ... */ }
  mod private {
      pub trait Sealed {}
      impl Sealed for usize {}
  }
  ```

- One public path per item. Re-export each item by name (`pub use foo::{A, B};`), never with a glob. When a dependency's type must appear in your API, re-export it so callers can name the matching version.
- `const fn` only when the function will stay `const`; removing `const` is a break.

Breaking changes include: removing or renaming a public item, adding a variant to an enum that is not `#[non_exhaustive]`, adding a field to a publicly constructible struct, adding a trait bound, and making a trait not object-safe. Deprecate in a minor release before you remove in a major one.

Automate, and state what each run cannot see:

- `cargo-semver-checks` gates the breaks it has lints for. A clean run is not proof of compatibility; it can pass a changed parameter or return type.
- `cargo public-api diff` shows changed public items and signatures, including breaks semver-checks misses. Review it before each release ([release.md](release.md)).

## Refactoring someone else's code

- Fix every smell the request is about, not only the cheap ones: clones that only satisfy the borrow checker, `&String` / `&Vec<T>` parameters, `unwrap` on fallible paths, `Rc<RefCell<_>>` in signatures, `get_` getters, `bool` parameters, `+` string concatenation, `#![deny(warnings)]`, error types without `std::error::Error`, nondeterministic `HashMap` iteration in output. An existing `bool` parameter is a smell to remove, not a detail to keep.
- Keep public behavior identical unless the change is the point: the same operations, success and failure semantics, and output bytes. Turning a panic into an `Err` is a change callers want. Dropping an error variant, removing a derive, or changing what a constructor takes is not. When a signature must change, show the before and after and say why.
- Keep quirks you do not understand and flag them; do not silently fix them.
- When the module has no tests, pin the current behavior with a few tests before you change it.

## Documentation

Write down decisions in short ADRs or design notes: alternatives discarded and why, downsides accepted and why.

Write down what is not there:

- Corner cases the code does not handle. Tell callers what it cannot do; the `todo` and `unimplemented` lints in [clippy.md](clippy.md) keep these out of the code.
- Known future optimizations.
- Deliberately absent impls, for example no `From<&str>` and the reason.
