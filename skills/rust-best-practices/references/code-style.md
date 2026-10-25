# Code Style

Source: https://github.com/morganlinton/BeautifulRust (MIT), a synthesis of the Google Rust Style Guide, the Rust API Guidelines, Effective Rust, Rust Design Patterns, and Microsoft's Pragmatic Rust Guidelines.

Use this when you write or review Rust code. Library code (anything with external users) follows every rule. Application code favors concrete types, `anyhow`-style errors, `Vec` return values, and no speculative generality. Panicking shortcuts stay denied as in [clippy.md](clippy.md).

## Naming

| Item                                | Case                   | Notes                                       |
| ----------------------------------- | ---------------------- | ------------------------------------------- |
| Types, traits, enum variants        | `UpperCamelCase`       | Acronyms are one word: `Uuid`, `HttpClient` |
| Functions, methods, modules, locals | `snake_case`           |                                             |
| Constants, statics                  | `SCREAMING_SNAKE_CASE` |                                             |
| Type parameters                     | short, from the bound  | `T`, `R: Read`, `W: Write`                  |
| Lifetimes                           | short lowercase        | descriptive on a type: `'src`, `'conn`      |

- No `get_` prefix on getters: `fn name(&self) -> &str`, `fn name_mut(&mut self)`. Use bare `get` only when there is one obvious thing to get (`Cell::get`). Related: `set_foo(T)`, `take_foo()`, `with_foo(|f| ..)`, and `_unchecked` siblings for checked accessors.
- Conversion prefixes signal cost and ownership: `as_` (free, borrow to borrow), `to_` (expensive, or borrow to owned), `into_` (consumes `self`). Put `mut` in type order: `as_mut_slice`, not `as_slice_mut`.
- Constructors: `new` (primary), `with_capacity` / `new_with_foo` (variants), `try_new` (fallible), `from_foo` (conversion; pair important ones with a `From` impl). I/O resources use domain verbs: `File::open`, `TcpStream::connect`.
- `iter` / `iter_mut` / `into_iter` return `Iter` / `IterMut` / `IntoIter`; `keys()` returns `Keys`.
- Error types read verb-object-error: `ParseBoolError`, not `BoolParseError`.
- Do not repeat the module name in the type (`foo::Id`, not `foo::FooId`). Avoid abbreviations an outsider would not know.
- If you implement `len()`, implement `is_empty()`.
- Feature names are bare: `std`, `serde`, `alloc`, `test-util`. Never `use-std` or `no-std`.

## Standard traits

Downstream crates cannot add std traits to your types (orphan rule), so derive them whenever every field supports them:

- `Debug` on every public type; write it by hand to redact secrets.
- `Clone`, except for unique resources and key material.
- `Copy` only for small bitwise-copyable types, because the compiler copies silently.
- `PartialEq` / `Eq`, `PartialOrd` / `Ord` (never `PartialOrd` alone when a total order exists), `Hash` consistent with `Eq`, and `Default`.
- `Display` for anything people read: error types, string-like wrappers.
- `#[must_use]` on pure functions and on types whose discarding is a bug, such as errors and lazy values.

Implement `From` / `TryFrom`, never `Into` / `TryInto` directly. Implement `FromIterator` and `Extend` on collections, and `IntoIterator` for both owned and borrowed forms. Overload operators only for their mathematical meaning.

Put derivable trait bounds on `impl` blocks, not on struct definitions: `#[derive(Clone)] struct Good<T>`, not `struct Bad<T: Clone + Debug>`.

If you write `Ord` by hand, write `PartialEq`, `PartialOrd`, and `Hash` by hand too, so they compare and ignore the same fields. A derived `PartialEq` next to a custom `Ord` breaks the std contract and misbehaves in `BTreeMap`, `sort`, and `dedup`. Say in the docs which fields equality ignores.

## Constructors and builders

- Provide `new()` even when `Default` exists, and make them agree (one delegates to the other). Bag-of-options structs with public fields always implement `Default` so callers can write `..Default::default()`.
- Up to two optional parameters: inherent constructors (`new`, `with_a`, `with_b`). Beyond that, or when construction validates or has side effects, add a builder: `Foo::builder()` returns `FooBuilder`, setters are named after fields (`timeout(d)`, not `set_timeout`) and infallible, and `build() -> Result<Foo, Error>` does all validation, including cross-field checks. Prefer `&mut self -> &mut Self` setters unless `build` must move a value out.
- Group four or more loose arguments into semantic types: `Deposit::new(account, amount)`, not four `&str` / `u64` parameters.

## Traits and generics

- Define a trait only for generic code (`T: Trait`, `impl Trait`, `dyn Trait`) or as an extension trait (`FooExt`), not to organize code. Put essential behavior in inherent methods and have trait impls forward to them, so callers need no import.
- Prefer, in order: concrete types; generics; `dyn Trait`, ideally wrapped in your own struct (`struct DynStore(Arc<dyn Store>)`). Do not nest generics on service-level types (`Service<Backend>`, not `Service<Backend<Store>>`).
- Decide early whether a trait must be object-safe. Generic methods or `Self` outside the receiver break it; exclude such methods with `where Self: Sized`.
- Keep required methods few and give defaults for everything derivable from them, as `Iterator` does from `next`.
- A function with a clear receiver is a method. A computation with no receiver is a free function, not `Database::check(params)`. Associated functions are for construction.
- Closures: use the most general bound that works (`FnOnce`, then `FnMut`, then `Fn`), prefer `Fn*` bounds to `fn` pointers, and put one closure parameter last.
- Keep parameter order consistent: call-specific first, ubiquitous context (loggers, allocators) last.
- Write a macro only when functions, generics, and traits cannot do the job. Prefer `macro_rules!` to proc macros, make macro input look like its output, and never let a macro change a type's kind or a function's signature.

## Errors

| Situation                                    | Use                                                   |
| -------------------------------------------- | ----------------------------------------------------- |
| Absence is normal (`first()`, `checked_add`) | `Option<T>`                                           |
| The caller may need to know what went wrong  | `Result<T, E>`                                        |
| A violated internal invariant                | a type that makes the state impossible, else `Result` |

- Pattern-match instead of check-then-unwrap: `if let Some(v) = opt` or `let Some(v) = opt else { return .. };`.
- Library error types implement `std::error::Error`, are `Send + Sync + 'static`, and implement `source()` for wrapped causes. Never use `()`, `String`, `Box<dyn Error>`, or `anyhow::Error` as a library's public error type.
- `Display` messages are lowercase, concise, and have no trailing punctuation: `"invalid header length"`.
- Implement `From<Upstream>` so `?` converts. Use `map_err` only for foreign errors or to add context.
- Two sound shapes: an enum with one variant per cause (`thiserror`), or a struct per situation with a private `kind` plus `is_xxx()` methods. Do not make one crate-wide enum of every failure, and do not expose details callers cannot act on.
- If a fallible function consumes an argument, return it inside the error so the caller can retry without a clone (`FromUtf8Error::into_bytes`).
- Applications use `anyhow` or `eyre` with `.context("opening config")`, one app-level error type, and `main` returning `Result<(), anyhow::Error>`.
- Destructors never fail, panic, or block. Provide `close(self) -> Result<()>` for fallible teardown and let `Drop` do best-effort cleanup.
- Never use `catch_unwind` for control flow; it does nothing under `panic = "abort"`.

## Idioms

- Iterators over hand loops when the pipeline is short and reads top-down. Collect fallible steps into `Result<Vec<_>, E>` and apply `?`. Bind a long chain to a named variable instead of putting it in a `for` header, and prefer `for x in it` to `.for_each(..)`.
- `Option` / `Result` combinators (`map`, `and_then`, `ok_or_else`, `as_deref`) when they are clearer than `match`, and `match` when they are not.
- `format!` / `write!` with inline args (`format!("{name}: {count}")`), not chained `+` or `str::replace`. `write!` into an existing buffer in hot paths.
- Explicit types where inference hides intent: on `.into()`, `.parse()`, `.collect()`. Prefer `let x: Vec<u32> = ..` to a turbofish.
- Bind drop guards to a name (`let _guard = ..`); `let _ = ..` drops at once.
- Freeze after setup: build with `let mut`, then rebind `let data = data;`.
- For closures that capture mixed ownership, rebind in a block, then `move`:

  ```rust
  let job = {
      let cfg = cfg.clone();
      move || run(cfg, data)
  };
  ```

- Imports: one `use` per module path (`use foo::bar::{Bar, Baz};`); types and traits used unqualified; free functions qualified by their module (`mem::take`, `fs::read`). No glob imports except `use super::*` in test modules and `use Enum::*` inside a function that matches on it.
- Magic numbers become named `const`s with a doc comment that says where the value comes from.
- Log through `tracing` or `log`, not `println!` / `dbg!`, except for a CLI's own stdout output.

## Concurrency and async

- Public types, and the futures they return, are `Send` (and usually `Sync`). Pin it with a compile-time check:

  ```rust
  const _: () = {
      const fn assert_send<T: Send>() {}
      assert_send::<MyClient>();
  };
  ```

  An `Rc` or a `RefCell` borrow held across an `.await` makes a future `!Send`.

- Prefer channels to shared state. When you share: keep linked invariants under one lock, keep lock scopes to a few lines, never call user closures while you hold a lock, and never return a `MutexGuard` from a public method.
- Write `async fn` rather than `fn -> impl Future`, except in traits or when setup must run outside the async block.
- Long CPU-bound work inside async yields (`tokio::task::yield_now().await`) or moves to `spawn_blocking`.
- Libraries do not spawn raw threads or assume a runtime; take an executor, a spawn function, or `impl AsyncRead` / `impl Read` from the caller.

## Unsafe and FFI

- Write `unsafe` for one of three reasons only: a new abstraction safe code cannot express, a benchmarked performance need, or FFI and platform calls. Use std and well-reviewed crates first.
- Keep `unsafe` in the smallest module that can uphold its invariant and wrap it in a safe API; the module boundary is the soundness boundary. A safe function that can cause undefined behavior through any sequence of safe calls is unsound.
- Mark a function `unsafe` only when misuse can cause undefined behavior, not because it is dangerous (`delete_database()` is safe).
- No `transmute` to cast enums or dodge lifetimes, and no `unsafe impl Send` to silence the compiler.
- Every `unsafe fn` has a `# Safety` doc section. [verification.md](verification.md) covers Miri and the other checks.
- FFI: `#[repr(C)]` on shared structs, sized integer types, `CString` / `CStr` for strings, allocate and free on the same side, wrap C-owned pointers in an RAII type whose `Drop` frees them, check for null and return `Result`, and stop panics at the boundary with `catch_unwind`. Generate bindings with `bindgen` in a `foo-sys` crate and keep logic in a safe core crate.

## Crates and modules

- Prefer small, single-purpose crates in a flat `crates/` workspace; never nest a crate in another crate's `src/`. Share versions and lints through `[workspace.dependencies]` and `[workspace.lints]`.
- Name a leaf module after its primary item (`Foo` lives in `foo.rs`). Non-leaf modules hold only `mod` declarations and re-exports. Group by use case (`account`, `network`), not by kind (`traits`, `errors`). Do not define a prelude.
- Use the latest stable edition for new crates and set an MSRV on purpose. Do not use unstable features on a stable toolchain.

## Documentation

- `///` on every public item; `//!` at the top of the crate root and every public module. The first sentence is one line of about fifteen words, because it becomes the summary in listings.
- Sections, in this order, as applicable: `# Examples`, `# Errors`, `# Panics`, `# Safety`. Examples use `?` with the `fn main` hidden behind `# ` lines, never `unwrap()`, because users copy them. Describe parameters in prose, not a table.
- Document what the signature cannot say: preconditions, side effects, ownership transfer, complexity. `/// Removes an element.` on `remove_element` is noise.
- Link items with ``[`Type`]``. Hide impls users never trigger with `#[doc(hidden)]`.
- `//` comments explain why, not what: `// SAFETY:`, `// TODO(issue-123):`, non-obvious values, workarounds with a link. Document the end state, not the design history.
- Run `cargo doc --no-deps` on libraries to catch broken links and missing docs.

## Tests

- Unit tests in `#[cfg(test)] mod tests { use super::*; .. }` for private internals. Integration tests in `tests/` for anything reachable through the public API; prefer that location when either works.
- Test observable behavior and properties (monotonic, round-trips, idempotent), not restated constants or mirrored branches.
- Write a failing test before you fix a bug. Cover each feature combination and each platform-specific path.
- Code that does I/O, time, randomness, or network is mockable: `new_mocked() -> (Self, MockCtrl)` behind a `test-util` feature, not a `Default` that does I/O.
- Give assertions context: `assert_eq!(got, want, "input {input:?}")`.
