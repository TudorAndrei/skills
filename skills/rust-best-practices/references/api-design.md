# API Design

Source: https://github.com/hexuria/impeccable-rust (MIT)

Make incorrect use inexpressible instead of documenting "do not do that". Treat public surface as a liability.

## Misuse resistance

- Newtypes for distinct units, not type aliases: `Meters(u64)` and `Miles(u64)`.
- Two-phase structs: a raw `TomlConfig` parsed from input, then a validated `ResolvedConfig` the rest of the code takes.
- One enum for linked arguments, so a `bool` plus an `Option` that must agree cannot hold conflicting states.

State-machine ladder. Stop at the first rung that rules out the illegal states:

1. Keep `bool` for independent flags that are not a lifecycle (`verbose`, `color`).
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
- Leave a value-producing `match` or `if` arm as an expression (`0 => "zero"`); a trailing semicolon turns it into `()`.
- For a `dyn` plugin trait with an async method, return `Pin<Box<dyn Future<Output = T> + Send + 'a>>`. Without `dyn`, use `async fn` in the trait. In a public trait, write `fn run(&self) -> impl Future<Output = T> + Send` so callers can rely on `Send`.
- Deny `unsafe_op_in_unsafe_fn` (see [clippy.md](clippy.md)), so each unsafe operation inside an `unsafe fn` still needs its own `unsafe` block.

## Compatibility

Keep a small, stable core and document semver expectations for callers. Prefer:

- `-> impl Trait` over a named concrete return type you may change. Auto traits such as `Send` still leak through it.
- Private fields with accessors or builders over `pub` fields.
- No public-dependency types (hyper, serde, tokio) in arguments, returns, trait impls, or re-exports, unless that coupling is intended.
- Private inherent methods over blanket `impl From` or other always-public trait impls when the coupling is accidental.

Automate, and state what each run cannot see:

- `cargo-semver-checks` gates the breaks it has lints for. A clean run is not proof of compatibility; it can pass a changed parameter or return type.
- `cargo public-api diff` shows changed public items and signatures, including breaks semver-checks misses. Review it before each release ([release.md](release.md)).

## Documentation

Write down decisions in short ADRs or design notes: alternatives discarded and why, downsides accepted and why.

Write down what is not there:

- Corner cases the code does not handle. Tell callers what it cannot do; the `todo` and `unimplemented` lints in [clippy.md](clippy.md) keep these out of the code.
- Known future optimizations.
- Deliberately absent impls, for example no `From<&str>` and the reason.
